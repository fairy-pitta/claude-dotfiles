# Backend Review: Database Performance + Migration

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Database Performance

- [ ] **N+1クエリ** — ループ内でDBクエリを実行していないか。`select_related()`/`prefetch_related()`の適用漏れ
- [ ] **SELECT *禁止・カラム絞り込み** — 全カラム取得を避け`.only()`/`.values()`/`.defer()`で必要フィールドのみ明示列挙する。JOIN先テーブルにも適用され、`select_related(...).get()`やprefetch_relatedでJOINした関連テーブルも対象（→ `references/code-examples.md`）
- [ ] **QuerySetのorder_by明示と安定ソート** — `.all()`等でorder_byを指定しないとDB依存で順序が揺れ、APIレスポンスやテスト再現性が損なわれる。常に明示し、単一カラムだと同値タイブレーカー不在で重複・取りこぼしが起きるためPKを副キーに追加して安定ソートにする
- [ ] **インデックスカバレッジ確認** — フィルタ条件を変更した場合、対象テーブルの Meta.indexes が新しいクエリパスをカバーしているか確認する。追随しないとフルスキャンになるため、EXPLAIN で確認するかインデックス定義を目視チェックする

---

## Extended Checklist

### Database Performance（詳細）

- **Bulk操作** — 複数レコードの作成・更新時に`bulk_create()`/`bulk_update()`を使用しているか。例: Admin `list_display`に集計表示がある場合は`get_queryset()`で`annotate(Count(...))`してN+1を回避する
- **大量データのDB側処理** — management commandでも大量データの可能性を考慮し、DB側フィルタリング（Exists subquery等）を優先する。Python側でset差分を取る前にSQLレベルで絞り込めないか検討し、`iterator(chunk_size)`で逐次取得してメモリ圧迫を回避する
- **management commandの外部参照事前検証** — CSV等の外部データからDB参照（Role, Permission等）を行う管理コマンドで、参照先の存在をループ内で個別チェック（try/except DoesNotExist + WARNING）していないか確認する。部分適用で不完全な状態がコミットされるため、ループ前に一括取得＋欠落チェック→CommandErrorでfail-fastすべき
- **filter().first()よりget()で一意性を保証** — ビジネスルール上一意であるべきレコードの取得に`.filter().first()`を使うと、重複データが存在しても最初の1件を返してサイレントに成功する。`.get()`を使い`DoesNotExist` → `success(None)`, `MultipleObjectsReturned` → `failure(...)`で明示的にハンドリングすること
- **select_relatedとonly()のIDフィールド競合** — `select_related("relation")`と`.only("relation_id")`を併用すると、Django 5.2で`FieldError`（deferred field と select_related の競合）が発生する。IDフィールド（`_id`サフィックス）のみ必要な場合は`select_related()`を削除し`.only()`のみ使用すること
- **QuerySet.update()とauto_nowの非互換** — `QuerySet.update()`は`save()`をバイパスするため`auto_now=True`の`updated_at`が更新されない。bulk update時は常に`updated_at=timezone.now()`の明示セットを確認する

### Migration & DB Schema（マイグレーションファイルが変更されている場合）

- **インデックス追加はConcurrentlyで無停止化** — 本番稼働中テーブルへの`migrations.AddIndex`はDDLロックで本番停止を招くため、`AddIndexConcurrently` + `atomic = False`を使用する（`from django.contrib.postgres.operations import AddIndexConcurrently`が必要）
- **リバースマイグレーション実装** — `reverse_code`がnoopではなくロールバック可能な実装か。特に`RunSQL`でConstraintをDROPする場合、`reverse_sql=RunSQL.noop`だとロールバック時に元の制約が復元されないため、`reverse_sql`に元の制約を再作成するSQLを明示すること
- **ロールバックリスク評価** — データ破壊的なマイグレーション（カラム削除、型変更等）にデータ保全策があるか
- **マイグレーション内のBulk操作** — 大量データ更新時に`bulk_update()`やiteratorの`chunk_size`指定を使用しているか
- **複合インデックスで代替可能な単一`db_index`** — `['company', 'year', 'month']`のような複合インデックスが存在する場合、`year`・`month`への個別`db_index=True`は冗長
- **一意制約追加前の重複データ検証** — `unique=True`を追加するmigrationで、既存の重複データを事前チェックする`RunPython`がないと本番適用時に`IntegrityError`が発生する。`RunPython`で重複を検出して`RuntimeError`で停止するか、重複解消ロジックを含めること
- **DB側での制約強制** — `update_or_create()`は`full_clean()`を呼ばないため、`Meta.constraints`に`CheckConstraint`を追加してDB側でも制約すること。特に`CharField`の正規表現バリデーションや`IntegerField`の範囲バリデーションが対象（→ `references/code-examples.md`）
- **Python/JS間の数値精度不整合** — Pythonの任意精度整数をそのまま許可すると、JSの`Number.MAX_SAFE_INTEGER`(2^53-1)を超える値がフロントエンドで丸められデータ破損する。数値バリデーションではJS安全整数範囲チェックを追加すること
- **Migration インポート位置** — `django.db.models`の汎用クラス（Count など）は関数内ではなくモジュールトップでインポートする。モデル取得（`apps.get_model()`）は関数内が必須だが、汎用クラスはトップレベルでOK
