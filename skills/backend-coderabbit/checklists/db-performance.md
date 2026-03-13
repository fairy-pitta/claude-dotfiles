# Backend Review: Database Performance + Migration

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Database Performance

- [ ] **N+1クエリ** — ループ内でDBクエリを実行していないか。`select_related()`/`prefetch_related()`の適用漏れ
- [ ] **`SELECT *`禁止** — `select_related(...).get()`は全カラム取得になる。`.only()`/`.values()`で絞り込む（→ `references/code-examples.md`）
- [ ] **select_related使用時の.only()適用** `[新観点 from PR#472]` — select_relatedやprefetch_relatedで関連テーブルをJOINしている箇所で.only()/.defer()によるカラム制限が付いているかチェックする。SELECT \*禁止ルールはJOIN先テーブルにも適用される。必要フィールドのみ明示的に列挙する
- [ ] **QuerySetのorder_by明示** `[新観点 from PR#472]` — Django の QuerySet で `.all()` を使用する際、`order_by` を指定しないとDB依存で順序が揺れる。APIレスポンスの安定性・テスト再現性のため、`order_by` は常に明示すべき
- [ ] **インデックスカバレッジ確認** `[新観点 from PR#537]` — フィルタ条件を変更した場合、対象テーブルの Meta.indexes が新しいクエリパスをカバーしているか確認する。条件変更でインデックスが追随しないとフルスキャンになる。フィルタ条件変更時は EXPLAIN で確認するか、対象テーブルのインデックス定義を目視チェックする
- [ ] **マイグレーションのAddIndexConcurrently使用** `[新観点 from PR#537]` — 本番稼働中のテーブルにインデックスを追加するマイグレーションで `migrations.AddIndex` を使っていないか確認する。DDLロックで本番停止を招くため、`AddIndexConcurrently` + `atomic = False` を使用する。`from django.contrib.postgres.operations import AddIndexConcurrently` が必要

---

## Extended Checklist

### Database Performance（詳細）

- **Bulk操作** — 複数レコードの作成・更新時に`bulk_create()`/`bulk_update()`を使用しているか
- **Admin list_displayでのN+1** — `list_display`に集計表示がある場合、`get_queryset()`で`annotate(Count(...))`しているか
- **ページネーションの副キー** `[新観点 from PR#480]` — `order_by` が単一カラムの場合、同値タイブレーカー不在で重複・取りこぼしが起きる。PKを副キーに追加して安定ソートにする
- **management commandでのDB側フィルタリング** `[新観点 from PR#510]` — management commandでも大量データの可能性を考慮し、DB側フィルタリング（Exists subquery等）を優先する。Python側でset差分を取る前に、SQLレベルで絞り込めないか検討する。iterator(chunk_size)で逐次取得してメモリ圧迫を回避する
- **management commandの外部参照事前検証** `[新観点 from PR#526]` — CSV等の外部データからDB参照（Role, Permission等）を行う管理コマンドで、参照先の存在をループ内で個別チェック（try/except DoesNotExist + WARNING）していないか確認する。部分適用で不完全な状態がコミットされるため、ループ前に一括取得＋欠落チェック→CommandErrorでfail-fastすべき

### Migration & DB Schema（マイグレーションファイルが変更されている場合）

- **リバースマイグレーション実装** — `reverse_code`がnoopではなく、ロールバック可能な実装か
- **`RunSQL.noop` reverse後に制約消失** `[新観点 from PR#469]` - `RunSQL`でConstraintをDROPする場合、`reverse_sql=RunSQL.noop`だと、ロールバック時に元の制約が復元されない。`reverse_sql`に元の制約を再作成するSQLを明示すること。
- **ロールバックリスク評価** — データ破壊的なマイグレーション（カラム削除、型変更等）にデータ保全策があるか
- **マイグレーション内のBulk操作** — 大量データ更新時に`bulk_update()`やiteratorの`chunk_size`指定を使用しているか
- **複合インデックスで代替可能な単一`db_index`** — `['company', 'year', 'month']`のような複合インデックスが存在する場合、`year`・`month`への個別`db_index=True`は冗長
- **一意制約追加前の重複データ検証** `[新観点 from PR#480]` — `unique=True` を追加する migration で、既存の重複データを事前チェックする `RunPython` がないと本番適用時に `IntegrityError` が発生する。`RunPython` で重複を検出して `RuntimeError` で停止するか、重複解消ロジックを含めること
- **`update_or_create()`はfull_clean()を呼ばない** → `Meta.constraints`に`CheckConstraint`を追加してDB側でも制約すること。特に`CharField`の正規表現バリデーションや`IntegerField`の範囲バリデーションが対象（→ `references/code-examples.md`）
- **Migration インポート位置** `[新観点 from PR#480]` - `django.db.models` の汎用クラス（Count など）は関数内ではなくモジュールトップでインポートする。モデル取得（`apps.get_model()`）は関数内が必須だが、汎用クラスはトップレベルで OK。
- **Python/JS間の数値精度不整合** `[新観点 from PR#560]` — Python の任意精度整数をそのまま許可すると、JS の `Number.MAX_SAFE_INTEGER` (2^53-1) を超える値がフロントエンドで丸められデータ破損する。数値バリデーションでは JS 安全整数範囲チェックを追加すること。
