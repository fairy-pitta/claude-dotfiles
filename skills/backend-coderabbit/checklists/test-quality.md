# Backend Review: Test Quality

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイル（特にテストファイル）に対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Test Quality（テストファイルが変更されている場合）

- [ ] **関数ベーステスト必須** — `class TestXxx:`禁止。すべて`def test_xxx():`のモジュールレベル関数
- [ ] **テスト名は英語・命名順序** — `test_<動作>_<条件>_<期待結果>`の順序が必須。日本語禁止（→ `references/code-examples.md`）
- [ ] **正常系カバレッジ** — 異常系テストのみで正常系が抜けていないか
- [ ] **テストアサーションのフィルタ一致** `[新観点 from PR#537]` — テストのアサーションで使用するフィルタ条件が本番の削除/検索ロジックと同等か確認する。テストデータが1パターンのみだとフィルタ不足でも偽陽性が出ない。テストのフィルタは本番ロジックのキー条件と一致させる
- [ ] **削除キー要素ごとの分離性テスト** `[新観点 from PR#537]` — 複合キー（company_id, year, month等）による削除ロジックをテストする際、各キー要素の分離性を個別に検証しているか確認する。会社間分離テストだけでは不十分で、同一会社・別年度の同月データが影響を受けないことも検証する
- [ ] **Result型エラー分岐のロールバック検証テスト** `[新観点 from PR#537]` — transaction.atomic内でResult型（failure返却）を使う複数ステップ処理で、途中ステップ失敗時にset_rollback(True)で先行ステップの変更がロールバックされることを結合テストで検証しているか確認する。成功系テストだけでは部分コミットバグを検出できない。monkeypatchで中間ステップをfailureに差し替え、全テーブルが元のまま残ることをアサートする
- [ ] **異常系テストのエラー種別検証** `[新観点 from PR#546]` — 異常系テストで「エラーが返ること」だけでなく「正しいエラー種別が返ること」まで検証しているか。error_response is not Noneのみでは分岐の取り違えを検出できない
- [ ] **ページネーション境界値の片側超過テスト** `[新観点 from PR#546]` — pagination helper / validator に上限チェックがある場合、ちょうど境界だけでなく「1件超過」の失敗系テストがあるか確認する。`>` と `>=` の取り違えを検出する。
- [ ] **Presentation parser の非数値入力テスト** `[新観点 from PR#546]` — `int()` 変換を行う query/body parser に対し、ゼロや負数だけでなく `"abc"` 等の非数値入力で `ValueError` 分岐を通すテストがあるか確認する。
- [ ] **成功系 parser テストのデフォルト値固定** `[新観点 from PR#546]` — parser の成功系テストで主要変換だけでなく、同時に返るデフォルト値（page/page_size等）も固定しているか確認する。暗黙のデフォルト変更を検出するため。
- [ ] **再利用APIの省略可能フィールドテスト漏れ** `[新観点 from PR#570]` — assignment_id等で既存リソースを再利用するAPIで、省略可能フィールドを含めたテストしか存在しないか確認。省略時にも正常動作することを検証する回帰テストが必要

---

## Extended Checklist

### Test Quality（詳細）

- **`@pytest.fixture`の活用** — `setup_method`ではなく`@pytest.fixture`を使って共通フィクスチャを切り出す。4箇所以上の重複はDRY違反
- **CSRFテスト有効化** — `csrf_protect`を使うViewのテストは`APIClient(enforce_csrf_checks=True)`で実運用と同条件に（→ `references/code-examples.md`）
- **テストデータの独立性** — テスト間で共有される可変なdict・listがないか
- **`interaction`検証テストで`execute()`の戻り値も確認** — `mock.assert_called_once()` だけでなく `result, error = usecase.execute()` でアンパックして `assert error is None` まで検証（→ `references/code-examples.md`）
- **`count()`のみのアサーションは不十分** — `assert Model.objects.count() == 1` だけでなく、特定行の存在も確認
- **異常系テストでDB不変性を検証** — 例外発生テストで `assert Model.objects.count() == 0` のようにDB不変性まで検証
- **セキュリティテストの副作用未検証** `[新観点 from PR#536]` — 拒否系テスト（使用済みトークン、期限切れ等）で「操作が失敗した」だけでなく「副作用が発生していない」（パスワード未変更等）ことも検証する。エラー返却のみのアサーションは退行を見逃す
- **テストヘルパーの`conftest.py`共通化** — 3箇所以上で同一ヘルパーが重複しているなら`conftest.py`に共通化
- **リポジトリテストのクエリ数検証一貫性** `[新観点 from PR#469]` — DBアクセスを伴うリポジトリテストでdjango_assert_num_queriesが統一的に使用されているか確認する。空結果テストでも省略しない
- **ファクトリのデフォルト値とモデル制約の整合性** `[新観点 from PR#472]` — テストファクトリのデフォルト値がモデルの`CheckConstraint`に違反していないか確認する。特にpolymorphic FKパターン（category_type + FK）では、デフォルトの組み合わせが制約条件を満たすこと
- **バリデーション追加時の失敗系テスト** `[新観点 from PR#472]` — UseCase/Repository層にバリデーションを追加した際、失敗パスのテストも同時に追加しているかチェックする。正常系テストだけではバリデーションの実効性が保証されない。各ガード条件に対応する回帰テストを作成する
- **Factory traitの活用** `[新観点 from PR#472]` — テストでFactoryのフィールドを直接指定している場合、既存traitで同等の設定ができないかチェックする。trait（例: for_large_item=True）を使うことでFactory定義の変更に自動追従でき、テストの保守性が向上する
- **テストフィクスチャのCSRF設定** `[新観点 from PR#472]` — 新規テストファイルでAPIClientフィクスチャを独自定義する際、conftest.pyの規約（enforce_csrf_checks=True + CSRFトークン設定）を踏襲しているかチェックする。GETのみのテストでも規約統一のためCSRFを有効化する
- **DIテスト配線検証** `[新観点 from PR#472]` — DIテストでは型チェック（isinstance）だけでなく依存配線の検証まで含めるべき。同ファイル内の既存DIテストパターンとの一貫性をチェックし、resolve後のインスタンスが正しい依存を持つことまで確認する
- **APIコントラクトテスト網羅性** `[新観点 from PR#472]` — APIコントラクトテストではレスポンスシリアライザの全フィールドをカバーすべき。新フィールド追加時に既存テストの更新漏れを検出するため、レスポンスbodyのキー一覧とシリアライザのfields定義を突合する
- **テストヘルパーMUSTルール準拠** `[新観点 from PR#472]` — 新規テスト作成時にCODING_STANDARDS.md 9.3のテストヘルパー利用MUSTルールに準拠しているか確認する。既存のconftest.pyヘルパーやFactoryを使わず独自にセットアップしている箇所を検出する
- **テストモックの `create_autospec`** `[新観点 from PR#480]` — ABCやProtocolが定義されたリポジトリを `Mock()` でモックしている場合、`create_autospec(Repository, instance=True)` に置換すべき。シグネチャ検証でリファクタ退行を検知
- **バリデーションテストのエラー値検証** `[新観点 from PR#480]` — `assert error is not None` だけでなく `str(error) == ErrorConstants.XXX` で具体的な値を検証。別エラーへの退行を検知する
- **統合テストのクエリバジェット統一** `[新観点 from PR#480]` — 一覧エンドポイントにクエリ上限があるなら詳細エンドポイントにも `django_assert_max_num_queries` を設定。N+1退行を検知するため全エンドポイントに統一して適用する
- **mock の autospec 設定** `[新観点 from PR#496]` - テストで外部ライブラリ（boto3等）をmockする際に `autospec=True` が設定されているかチェックする。autospecにより実際のインターフェースと一致しない呼び出しを早期検出できる。
- **POST/PUT/DELETEエンドポイントのCSRFテスト** `[新観点 from PR#570]` — 新規POST/PUT/DELETEエンドポイント追加時、未認証テストだけでなくCSRFトークンなし/あり双方のテストがあるかチェック
- **Falsy値の境界テスト** `[新観点 from PR#570]` — `is not None`で分岐する箇所でfalsy値(0, "")が正しく処理されるかの回帰テスト追加を確認する
- **既存エンドポイントのCSRFテスト漏れ** `[新観点 from PR#570]` — 新機能追加時に関連する既存テストファイルのCSRFカバレッジも確認する
