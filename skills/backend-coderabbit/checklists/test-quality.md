# Backend Review: Test Quality

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイル（特にテストファイル）に対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Test Quality（テストファイルが変更されている場合）

- [ ] **関数ベーステスト必須** — `class TestXxx:` 禁止。すべて `def test_xxx():` のモジュールレベル関数
- [ ] **テスト名は英語・命名順序** — `test_<動作>_<条件>_<期待結果>` の順序が必須。日本語禁止（→ `references/code-examples.md`）
- [ ] **正常系カバレッジ** — 異常系テストのみで正常系が抜けていないか
- [ ] **バリデーション・分岐追加時の失敗系テスト** — UseCase/Repository層にバリデーションやガード条件を追加した際、失敗パス・全ガード条件・各分岐に対応する回帰テストを同時に追加しているか。正常系だけではバリデーションの実効性が保証されない。例: 入力バリデーション（`user_id <= 0`）、複数条件の組み合わせ（GLOBAL only / COMPANY only / GLOBAL+COMPANY）、Result型サービスの error 分岐
- [ ] **異常系テストのエラー種別・型・値の明示検証** — エラー系テストで「エラーが返ること」だけでなく、正しいエラー種別・型・値まで検証しているか。`error is not None` のみでは分岐の取り違え・型退行を検出できない。例: `isinstance(error, ValidationError)`、`str(error) == ErrorConstants.XXX`、`error.details["cause"]`、`int()` 変換 parser の `"abc"` 等で `ValueError` 分岐を通す
- [ ] **副作用の不在検証** — エラー系・拒否系・早期リターン・「再利用」系テストで、副作用（`save`/`delete`/外部API・後続依存メソッド）が実行されないことを `assert_not_called()` / `assert mock.mock_calls == []` で検証しているか。さらに件数の不変（before/after count、`Model.objects.count()`）やDB不変性、状態の未変更（パスワード未変更等）もアサートする。エラー返却やID一致のアサーションだけでは退行を見逃す
- [ ] **トランザクション失敗パスの rollback 検証** — `transaction.set_rollback(True)` を呼ぶ実装の失敗系テストで、呼び出しを `mock.set_rollback.assert_called_once_with(True)` で検証しているか。戻り値のエラーだけ見ると rollback 漏れ（部分コミットバグ）を見逃す。Result型の多段処理では monkeypatch で中間ステップを failure に差し替え、全テーブルが元のまま残ることを結合テストでアサートする。create/delete 等同種テスト間で検証項目の一貫性を保つ
- [ ] **Mock は spec_set / autospec 必須** — `Mock()` に `spec_set` または `autospec` を付けているか。無制約Mockは存在しないメソッド・属性アクセスやシグネチャ不一致を見逃し、リファクタ退行を検出できない。例: `Mock(spec_set=TargetClass)`、ABC/Protocol リポジトリは `create_autospec(Repository, instance=True)`、外部ライブラリ（boto3等）は `autospec=True`
- [ ] **Mock 戻り値の明示設定と契約整合** — Mock メソッドの戻り値を明示設定しているか。デフォルト truthy で偶然通る成功パスは `return_value = True` を明示する。Result型は型パラメータと整合させる（`Result[list[T]]` の成功は `([], None)`、`(None, None)` は契約違反の温床）
- [ ] **Mock 呼び出しの引数・下流値検証** — Mock/UseCase 依存の呼び出しを `assert_called_once_with(expected_arg)` で引数検証しているか。`assert_called_once()` だけでは引数の取り違えを検出できない。例: リポジトリ lookup（find_by_id 等）の引数、変換後の値を返すモックの下流呼び出し（`call_args[0][0]`）、View テストの UseCase 引数DTO（call_args からフィールド値を検証）。エラー系テストでも同様に検証する
- [ ] **N+1クエリ数アサーション** — DB走査するエンドポイント／リポジトリのテストで `django_assert_num_queries` / `django_assert_max_num_queries` によるクエリ数上限アサーションがあるか。一覧・詳細・空結果含め全エンドポイントに統一して適用し、N+1回帰を検出する。POSTリクエスト部分のみをラップし、DB検証の `get()` は含めない。同ファイル内の類似テストのパターンを grep で確認する
- [ ] **テストのマジックストリング・ハードコード禁止** — Enum値の文字列リテラル直書きや固定IDを使っていないか。Enum経由（`ScopeType.COMPANY.value`）、エラーメッセージは定数参照（`UserErrors`/`NotFoundError(Msg.CONSTANT)`、`pytest.raises(match=...)`）、IDは fixture/factory 経由の値を使う。リテラル直書きは定義変更に追従せず偽陽性を生み、固定ID（`region_id=1`）は自動採番と不整合になる
- [ ] **テストアサーションのフィルタ一致** — テストのアサーションで使うフィルタ条件が本番の削除/検索ロジックのキー条件と一致しているか。テストデータが1パターンのみだとフィルタ不足でも偽陽性が出ない
- [ ] **削除キー要素ごとの分離性テスト** — 複合キー（company_id, year, month等）の削除ロジックは各キー要素の分離性を個別に検証しているか。会社間分離だけでは不十分で、同一会社・別年度の同月データが影響を受けないことも検証する
- [ ] **リソース所有権不一致の異常系テスト** — 外部からリソースIDを受け取るAPIで、他社/他ユーザーのIDを指定した拒否テストがあるか。別会社を明示的に作成して所有者不一致を保証し、所有権チェックの退行を検知する

---

## Extended Checklist

### Test Quality（詳細）

- **`@pytest.fixture` の活用** — `setup_method` ではなく `@pytest.fixture` で共通フィクスチャを切り出す。4箇所以上の重複はDRY違反
- **テストヘルパー・Factory の共通化と再利用** — 新規テストで独自セットアップせず既存の `conftest.py` ヘルパー・Factory を再利用する。3箇所以上の同一ヘルパー（テスト内の重複も含む）は `conftest.py` やヘルパー関数に抽出する。Factory のフィールド直接指定は既存 trait（例: `for_large_item=True`）で代替できないか確認する
- **フィクスチャの重複定義・未使用依存** — フィクスチャ追加時に親 conftest.py に同名フィクスチャが存在しないか確認する（pytest はディレクトリ階層で解決するため暗黙オーバーライドの修正漏れリスク）。フィクスチャ・関数シグネチャは実際に使う依存のみ宣言し、未使用パラメータは削除する
- **テストデータの独立性** — テスト間で共有される可変な dict・list がないか
- **CSRFテストの実運用整合** — `csrf_protect` を使う View や新規 POST/PUT/DELETE エンドポイントのテストは `APIClient(enforce_csrf_checks=True)` + CSRFトークン設定で実運用と同条件にする。GETのみでも規約統一のため有効化し、独自定義時は conftest.py の規約を踏襲する。新機能追加時は関連既存テストの CSRF カバレッジも確認する（→ `references/code-examples.md`）
- **`interaction` 検証で `execute()` 戻り値も確認** — `mock.assert_called_once()` だけでなく `result, error = usecase.execute()` でアンパックして `assert error is None` まで検証（→ `references/code-examples.md`）
- **`count()` のみのアサーションは不十分** — `assert Model.objects.count() == 1` だけでなく、特定行の存在も確認する
- **認可サービスの単体テスト必須** — 認可ロジックを持つサービス（SupportAdminAccessService等）を UseCase テストで全面モックしている場合、サービス自体の単体テストが存在するか確認する。最低でも「許可パス」「拒否パス」「スコープ境界（GLOBAL/REGION 一致/不一致）」を直接テストする。モックで隠蔽された認可ロジックの回帰は検出できない
- **ファクトリのデフォルト値とモデル制約・get_or_create の整合性** — テストファクトリのデフォルト値がモデルの `CheckConstraint` に違反していないか（特に polymorphic FK パターン category_type + FK）。`django_get_or_create` は初回作成時のみフィールド値を使うため、スコープ・ステータス等のデフォルトがテスト意図と合っているか確認する
- **DIテスト配線検証** — DIテストでは型チェック（isinstance）だけでなく依存配線まで検証する。同ファイル内の既存パターンと一貫させ、resolve 後のインスタンスが正しい依存を持つことを確認する
- **APIコントラクトテスト網羅性** — レスポンスシリアライザの全フィールドをカバーする。レスポンス body のキー一覧とシリアライザの fields 定義を突合し、新フィールド追加時の更新漏れを検出する。`"key" in response.data` だけの弱い assertion ではなく値まで検証する
- **ページネーション境界値の片側超過テスト** — 上限チェックがある pagination helper / validator で、ちょうど境界だけでなく「1件超過」の失敗系テストがあるか。`>` と `>=` の取り違えを検出する
- **成功系 parser テストのデフォルト値固定** — parser の成功系テストで主要変換だけでなく、同時に返るデフォルト値（page/page_size等）も固定する。暗黙のデフォルト変更を検出する
- **再利用APIの省略可能フィールドテスト漏れ** — assignment_id 等で既存リソースを再利用するAPIで、省略可能フィールドを含めたテストしかないと省略時の正常動作の回帰を検出できない。省略ケースのテストを用意する
- **Falsy値の境界テスト** — `is not None` で分岐する箇所で falsy 値（0, ""）が正しく処理されるかの回帰テストを確認する
- **タイムゾーン対応datetime** — テストデータでも `datetime.now(timezone.utc)` を使用する。`datetime.now()` はタイムゾーン非対応
- **同型テストの parametrize 統合** — 同じ Assert パターンを持つ同型テストは `pytest.mark.parametrize` で統合する
- **テストファイル間のインポートスタイル統一** — 同一パターンのテストファイル間でインポート位置（モジュール先頭 vs 関数内ローカル）が統一されているか。コピペ起因で一部だけローカルインポートになっている不統一を検出し、同一 feature 内は揃える
- **テストヘルパーの入力バリデーション・docstring 整合** — テストヘルパー関数が無効な状態（例: REGION scope なのに region_id=None）を黙認しないよう最低限のバリデーションを入れる。docstring が「デフォルト値を使用」等と記述する場合、実装が実際にそのデフォルトを適用しているか確認する
- **テストヘルパーの戻り値型を dataclass で具体化** — `build_mock_*` 系ヘルパーは `type()` による動的クラス生成や `Protocol` ではなく `@dataclass(frozen=True, slots=True)` を使う。不変性・型安全性・IDE補完を同時に担保する
- **実装文言・非決定論への依存排除** — テストのアサーションが内部実装の文言（例外メッセージ、ログ文字列等）に依存していないか（定数・エラーコードでアサートする）。`assert x in (A, B)` のような非決定論的テストは mock side_effect で例外を固定し期待値を1つに絞る
- **テストの期待値と実装の整合性** — エンドポイントの入力バリデーション仕様を変更した際、既存テストの期待値も合わせて更新する
- **モック定義だけして呼び出し検証していないテストがないか** — `vi.fn()` 等で mock を定義したら `assert_called` / `toHaveBeenCalled` で呼び出しを検証する
