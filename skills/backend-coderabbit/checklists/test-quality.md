# Backend Review: Test Quality

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイル（特にテストファイル）に対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Test Quality（テストファイルが変更されている場合）

- [ ] **関数ベーステスト必須** — `class TestXxx:`禁止。すべて`def test_xxx():`のモジュールレベル関数
- [ ] **テスト名は英語・命名順序** — `test_<動作>_<条件>_<期待結果>`の順序が必須。日本語禁止（→ `references/code-examples.md`）
- [ ] **正常系カバレッジ** — 異常系テストのみで正常系が抜けていないか
- [ ] **テストアサーションのフィルタ一致** — テストのアサーションで使用するフィルタ条件が本番の削除/検索ロジックと同等か確認する。テストデータが1パターンのみだとフィルタ不足でも偽陽性が出ない。テストのフィルタは本番ロジックのキー条件と一致させる
- [ ] **削除キー要素ごとの分離性テスト** — 複合キー（company_id, year, month等）による削除ロジックをテストする際、各キー要素の分離性を個別に検証しているか確認する。会社間分離テストだけでは不十分で、同一会社・別年度の同月データが影響を受けないことも検証する
- [ ] **Result型エラー分岐のロールバック検証テスト** — transaction.atomic内でResult型（failure返却）を使う複数ステップ処理で、途中ステップ失敗時にset_rollback(True)で先行ステップの変更がロールバックされることを結合テストで検証しているか確認する。成功系テストだけでは部分コミットバグを検出できない。monkeypatchで中間ステップをfailureに差し替え、全テーブルが元のまま残ることをアサートする
- [ ] **異常系テストのエラー種別検証** — 異常系テストで「エラーが返ること」だけでなく「正しいエラー種別が返ること」まで検証しているか。error_response is not Noneのみでは分岐の取り違えを検出できない
- [ ] **ページネーション境界値の片側超過テスト** — pagination helper / validator に上限チェックがある場合、ちょうど境界だけでなく「1件超過」の失敗系テストがあるか確認する。`>` と `>=` の取り違えを検出する。
- [ ] **Presentation parser の非数値入力テスト** — `int()` 変換を行う query/body parser に対し、ゼロや負数だけでなく `"abc"` 等の非数値入力で `ValueError` 分岐を通すテストがあるか確認する。
- [ ] **成功系 parser テストのデフォルト値固定** — parser の成功系テストで主要変換だけでなく、同時に返るデフォルト値（page/page_size等）も固定しているか確認する。暗黙のデフォルト変更を検出するため。
- [ ] **再利用APIの省略可能フィールドテスト漏れ** — assignment_id等で既存リソースを再利用するAPIで、省略可能フィールドを含めたテストしか存在しないか確認。省略時にも正常動作することを検証する回帰テストが必要
- [ ] **N+1クエリ数アサーション** — 新規API追加時の結合テスト正常系に`django_assert_num_queries`でクエリ数上限アサーションがあるか確認。N+1回帰をテストで検出できないと本番パフォーマンス劣化に気づけない。POSTリクエスト部分のみをラップし、DB検証の`get()`は含めない。
- [ ] **リソース所有権不一致の異常系テスト** — 外部からリソースIDを受け取るAPIに、他社/他ユーザーのIDを指定した場合の拒否テストがあるか確認。ビジネス不変条件（所有権チェック）の退行を検知できない。別会社を明示的に作成してassertで所有者不一致を保証する。
- [ ] **副作用否定アサーション** — 「再利用」「拒否」など副作用がないことを検証するテストで、レコード件数の不変もアサートしているか確認。ID一致だけでは新規作成せず再利用したことを十分に保証できない。before/after countパターンを使う。
- [ ] **テストのマジックストリング禁止** `[新観点 from PR#601]` — テストデータでEnum値を文字列リテラルで直書きしていないか確認する。文字列リテラルはEnum定義変更時にテストが追従せず偽陽性を生む。`ScopeType.COMPANY.value`のようにEnum経由で参照する。
- [ ] **bare Mock()の禁止** `[新観点 from PR#601]` — `Mock()`に`spec_set`または`autospec`を付けているか確認する。無制約Mockは存在しないメソッド・属性へのアクセスを見逃し、リファクタ時の退行を検出できない。`Mock(spec_set=TargetClass)`または`create_autospec(TargetClass, instance=True)`を使う。
- [ ] **failure系テストのrollback検証（単体テスト）** `[新観点 from PR#601]` — failure系テストで`transaction.set_rollback(True)`の呼び出しをmockで検証しているか確認する。戻り値のエラーだけ見てrollback呼び出し漏れを見逃すリスクがある。`mock_set_rollback.assert_called_once_with(True)`で明示的に検証する。
- [ ] **エラー系テストの副作用未実行検証** `[新観点 from PR#601]` — エラー系テストで副作用（`save`、`delete`、外部API呼び出し等）が実行されていないことを`assert_not_called`で検証しているか確認する。エラー返却のアサーションだけでは、エラー前に実行された副作用の漏れを検出できない。

---

## Extended Checklist

### Test Quality（詳細）

- **`@pytest.fixture`の活用** — `setup_method`ではなく`@pytest.fixture`を使って共通フィクスチャを切り出す。4箇所以上の重複はDRY違反
- **CSRFテスト有効化** — `csrf_protect`を使うViewのテストは`APIClient(enforce_csrf_checks=True)`で実運用と同条件に（→ `references/code-examples.md`）
- **テストデータの独立性** — テスト間で共有される可変なdict・listがないか
- **`interaction`検証テストで`execute()`の戻り値も確認** — `mock.assert_called_once()` だけでなく `result, error = usecase.execute()` でアンパックして `assert error is None` まで検証（→ `references/code-examples.md`）
- **`count()`のみのアサーションは不十分** — `assert Model.objects.count() == 1` だけでなく、特定行の存在も確認
- **異常系テストでDB不変性を検証** — 例外発生テストで `assert Model.objects.count() == 0` のようにDB不変性まで検証
- **セキュリティテストの副作用未検証** — 拒否系テスト（使用済みトークン、期限切れ等）で「操作が失敗した」だけでなく「副作用が発生していない」（パスワード未変更等）ことも検証する。エラー返却のみのアサーションは退行を見逃す
- **テストヘルパーの`conftest.py`共通化** — 3箇所以上で同一ヘルパーが重複しているなら`conftest.py`に共通化
- **リポジトリテストのクエリ数検証一貫性** — DBアクセスを伴うリポジトリテストでdjango_assert_num_queriesが統一的に使用されているか確認する。空結果テストでも省略しない
- **ファクトリのデフォルト値とモデル制約の整合性** — テストファクトリのデフォルト値がモデルの`CheckConstraint`に違反していないか確認する。特にpolymorphic FKパターン（category_type + FK）では、デフォルトの組み合わせが制約条件を満たすこと
- **バリデーション追加時の失敗系テスト** — UseCase/Repository層にバリデーションを追加した際、失敗パスのテストも同時に追加しているかチェックする。正常系テストだけではバリデーションの実効性が保証されない。各ガード条件に対応する回帰テストを作成する
- **Factory traitの活用** — テストでFactoryのフィールドを直接指定している場合、既存traitで同等の設定ができないかチェックする。trait（例: for_large_item=True）を使うことでFactory定義の変更に自動追従でき、テストの保守性が向上する
- **テストフィクスチャのCSRF設定** — 新規テストファイルでAPIClientフィクスチャを独自定義する際、conftest.pyの規約（enforce_csrf_checks=True + CSRFトークン設定）を踏襲しているかチェックする。GETのみのテストでも規約統一のためCSRFを有効化する
- **DIテスト配線検証** — DIテストでは型チェック（isinstance）だけでなく依存配線の検証まで含めるべき。同ファイル内の既存DIテストパターンとの一貫性をチェックし、resolve後のインスタンスが正しい依存を持つことまで確認する
- **APIコントラクトテスト網羅性** — APIコントラクトテストではレスポンスシリアライザの全フィールドをカバーすべき。新フィールド追加時に既存テストの更新漏れを検出するため、レスポンスbodyのキー一覧とシリアライザのfields定義を突合する
- **テストヘルパーMUSTルール準拠** — 新規テスト作成時にCODING_STANDARDS.md 9.3のテストヘルパー利用MUSTルールに準拠しているか確認する。既存のconftest.pyヘルパーやFactoryを使わず独自にセットアップしている箇所を検出する
- **テストモックの `create_autospec`** — ABCやProtocolが定義されたリポジトリを `Mock()` でモックしている場合、`create_autospec(Repository, instance=True)` に置換すべき。シグネチャ検証でリファクタ退行を検知
- **バリデーションテストのエラー値検証** — `assert error is not None` だけでなく `str(error) == ErrorConstants.XXX` で具体的な値を検証。別エラーへの退行を検知する
- **統合テストのクエリバジェット統一** — 一覧エンドポイントにクエリ上限があるなら詳細エンドポイントにも `django_assert_max_num_queries` を設定。N+1退行を検知するため全エンドポイントに統一して適用する
- **mock の autospec 設定** - テストで外部ライブラリ（boto3等）をmockする際に `autospec=True` が設定されているかチェックする。autospecにより実際のインターフェースと一致しない呼び出しを早期検出できる。
- **POST/PUT/DELETEエンドポイントのCSRFテスト** — 新規POST/PUT/DELETEエンドポイント追加時、未認証テストだけでなくCSRFトークンなし/あり双方のテストがあるかチェック
- **Falsy値の境界テスト** — `is not None`で分岐する箇所でfalsy値(0, "")が正しく処理されるかの回帰テスト追加を確認する
- **既存エンドポイントのCSRFテスト漏れ** — 新機能追加時に関連する既存テストファイルのCSRFカバレッジも確認する
- **複数条件の組み合わせテスト網羅** — 新しいビジネスロジックの分岐を追加した場合、各条件の組み合わせ（例: GLOBAL only / COMPANY only / GLOBAL+COMPANY）を網羅するテストを必ず用意する。単一条件のテストだけでは併有ケースのバグを見逃す。
- **Result型モック戻り値の型パラメータ整合** `[新観点 from PR#601]` — `Result[list[T]]` の成功時モック戻り値が `(None, None)` になっていないか確認。型パラメータが `list` なら `([], None)`、エンティティなら `(entity, None)` を返すべき。`(None, None)` は Result 契約違反の温床。
- **Mockデフォルトtruthy依存の排除** `[新観点 from PR#601]` — boolean戻り値のMockメソッドが明示設定されずにデフォルトtruthyで偶然テストが通っていないか確認。成功パスでも `return_value = True` を明示設定する。
- **トランザクション失敗パスのset_rollback検証** `[新観点 from PR#601]` — トランザクション内の失敗パステストで `set_rollback(True)` の呼び出し検証が漏れていないか確認。同種のcreate/deleteテスト間で検証項目の一貫性を保つ。
- **エラー型の明示検証** `[新観点 from PR#601]` — エラー系テストでは `isinstance(error, ValidationError)` 等で具体的な型も検証する。None/not Noneだけでは型の退行を検出できない。テスト追加時に必ず型検証を含める。
- **副作用の不在検証** `[新観点 from PR#601]` — エラー系テストでは `assert_not_called()` で副作用が発生しないことも検証する。他のエラー系テストとの一貫性を保つ。
- **入力バリデーション分岐の網羅** `[新観点 from PR#601]` — UseCaseの入力バリデーション（`user_id <= 0` 等）の全分岐をテストでカバーしているか確認する。
- **Result型サービスのerror分岐カバー** `[新観点 from PR#601]` — Result型を返すサービスメソッド（`can_access()` 等）のerror分岐を全てテストでカバーする。
- **呼ばれない処理の明示検証** `[新観点 from PR#601]` — 条件分岐で呼ばれないはずの処理が呼ばれないことを `assert_not_called()` で明示的に検証する。
- **モックのspec_set指定** `[新観点 from PR#601]` — モックには `spec_set=True` を指定してタイポによる偽陽性を防ぐ。
- **フィクスチャの不要依存削除** `[新観点 from PR#601]` — フィクスチャは実際に使用する依存のみ宣言する。未使用パラメータは削除する。
- **set_rollbackのrollback検証** `[新観点 from PR#601]` — `transaction.set_rollback(True)` を呼ぶ実装のエラー系テストでは必ず `mock_transaction.set_rollback.assert_called_with(True)` を検証する。
- **タイムゾーン対応datetime** `[新観点 from PR#601]` — テストデータでも `datetime.now(timezone.utc)` を使用する。`datetime.now()` はタイムゾーン非対応。
- **例外メッセージの検証** `[新観点 from PR#601]` — `pytest.raises()` では `match` パラメータまたは `exc_info.value` でメッセージ内容も検証する。
- **エラーメッセージの定数参照** `[新観点 from PR#601]` — テストのエラーメッセージ検証はハードコードせず、エラー定数（UserErrors, ValidationErrors等）を参照する。
- **同型テストのparametrize統合** `[新観点 from PR#601]` — 同じAssertパターンを持つ同型テストは `pytest.mark.parametrize` で統合する。
- **テスト内重複コードの抽出** `[新観点 from PR#601]` — テスト内でも3箇所以上の重複はヘルパー関数に抽出する。
- **認可サービスの単体テスト必須** `[新観点 from PR#519]` — 認可ロジックを持つサービス（SupportAdminAccessService等）をUseCaseテストで全面モックしている場合、サービス自体の単体テストが存在するか確認する。最低でも「許可パス」「拒否パス」「スコープ境界（GLOBAL/REGION一致/不一致）」を直接テストすること。モックで隠蔽された認可ロジックの回帰は検出できない。
- **リポジトリlookupの呼び出しアサーション** `[新観点 from PR#598]` — リポジトリのlookupメソッド（find_by_id, get_by_email等）を呼ぶUseCaseテストで、`assert_called_once_with(expected_arg)` による引数検証を必ず含める。result/errorのアサーションだけでは「正しい引数で呼ばれた」ことを保証できない。エラー系テストでも同様に検証する。
- **テストファイル間のインポートスタイル統一** `[新観点 from PR#598]` — 同一パターンのテストファイル間でインポート位置（モジュール先頭 vs 関数内ローカル）が統一されているか確認する。コピペ起因で一部ファイルだけローカルインポートになっている不統一を検出する。同一feature内のテストは同じスタイルに揃える。
- **Factoryのデフォルト値とdjango_get_or_create** `[新観点 from PR#622]` — `django_get_or_create` は初回作成時のみフィールド値を使用する。Factoryのデフォルト値がテストの意図と合っているか、特にスコープ・ステータス等のフィールドで確認する
- **テストヘルパーのdocstringと実装の一致** `[新観点 from PR#622]` — ヘルパー関数のdocstringが「デフォルト値を使用」等と記述している場合、実装が実際にそのデフォルトを適用しているか確認する
- **テストでのID固定値** `[新観点 from PR#622]` — テストでIDを固定値（例: `region_id=1`）で使用すると、fixture/factoryの自動採番値と不整合になる。fixture経由の値を使うべき
- **テストヘルパーの入力バリデーション** `[新観点 from PR#622]` — テストヘルパー関数が無効な状態（例: scope_id=None for REGION scope）を暗黙に許すと、テスト結果の信頼性が損なわれる。ヘルパーにも最低限のバリデーションを入れる
- **Mock依存の副作用不発生検証** `[新観点 from PR#622]` — Mock注入した依存は全て、失敗パスで呼ばれないことを明示的にassertする。`assert mock.mock_calls == []` で副作用の「発生しない」ことを検証する
