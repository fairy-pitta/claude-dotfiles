# Backend Review: Security & Authorization + Error Messages & Constants

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Security & Authorization

- [ ] **permission_classes明示設定** — DRF ViewにPermissionが必ず明示されているか。デフォルト依存禁止（→ `references/code-examples.md`）
- [ ] **認可バイパス経路** — Result型の誤用やエラーハンドリング不備により認可チェックがスキップされる経路がないか
- [ ] **write_only on sensitive fields** — パスワード等の機密フィールドに`write_only=True`が設定されているか
- [ ] **冪等キー実装のTOCTOUチェック** — cache.get/setの分離パターンは並行リクエストで競合する。冪等制御にはcache.add()等の原子的操作を使い、エラーパスでのロック解放漏れがないか確認
- [ ] **冪等キーのスコープ** — 認証必須APIのcache keyにユーザーIDが含まれているか確認する。ユーザーIDなしだと異なるユーザー間で冪等キーが衝突し、正当なリクエストが拒否される
- [ ] **スコープ付き権限の対象リソース検証** `[新観点 from PR#519]` — REGION/COMPANYスコープの権限チェックで「操作者が権限を持つか」だけでなく「対象リソースがそのスコープに属するか」も検証しているか確認する。操作者の権限チェックのみだと、スコープ外のリソースを操作できる権限過大が発生する
- [ ] **APIレスポンスキー名の統一** `[新観点 from PR#519]` — 手動構築のエラーレスポンス（`_validation_error_response`等）とApiResponse共通メソッドでキー名（camelCase/snake_case）が統一されているか確認する。不統一だとフロントエンドのエラーコード判定が分岐漏れしやすくなる

### Error Messages & Constants

- [ ] **エラーメッセージ定数化** — 文字列リテラルでエラーメッセージを直接記述していないか。`app/shared/constants/`で管理（→ `references/code-examples.md`）
- [ ] **`logger`/`print`禁止** — `logger`・`print`（マイグレーションbackward含む）の使用禁止
- [ ] **ユーザー向け/内部向けメッセージの混在チェック** — Msg/InternalMsgの分離が不十分だとAPIレスポンスに内部メッセージが露出するリスクがある。メッセージ定数を追加する際、用途（ユーザー向け/内部向け）を確認して適切なクラスに配置すること
- [ ] **定数ファイルの責務分離** — メッセージ定数ファイルに設定値（TTL, 閾値等）を混在させていないか確認する。文言定数と運用設定値は別ファイルに分離すること。混在すると責務が曖昧になり保守性が低下する
- [ ] **except Exceptionで例外情報の保持** `[新観点 from PR#654]` — `except Exception:` でcatchしてResult failureに変換する際、`except Exception as e` として `str(e)` を `ValidationError` の `details` に含めているか確認する。例外情報を握りつぶすとデバッグ困難になる
- [ ] **DRFフィールド制約のエラーメッセージ定数化** — DRFフィールドにmax_length/min_length/min_value/max_value等の制約を追加する際、error_messagesもセットでMsg定数化されているか確認する。DRFビルトインメッセージはプロジェクトの「エラーメッセージ定数化」ルールの対象外と見落としやすい。error_messagesパラメータで明示的に定数を指定すること
- [ ] **DRF IntegerFieldのnullエラーメッセージ漏れ** `[新観点 from PR#519]` — `IntegerField`等でerror_messagesに`required`/`invalid`/`min_value`を定数化していても、`null`キーが漏れているとDRFデフォルト文言にフォールバックする。`allow_null=False`（デフォルト）のフィールドには`"null"`キーも必ず追加すること
- [ ] **開発者向けエラーメッセージの定数化漏れ** — RuntimeErrorなど開発者向けエラーもエラーメッセージ定数化ルールの対象。ユーザー向けエラーだけでなく、Repository契約違反等の内部エラーも定数化されているかチェック。
- [ ] **同一内部契約違反の定数再利用** — 複数usecaseで同じ契約違反（`Result` が error なしで `None`、Repository が `None` を返す等）を扱う場合、メッセージを raw 文字列で複製せず既存の共通定数を再利用しているか確認する。文言の分岐を防ぎテスト保守性を上げる。

---

## Extended Checklist

### Security（詳細）

- **トークン無効化** — パスワード変更・ログアウト時にトークンが適切に無効化されているか
- **デフォルト拒否原則** `[新観点 from PR#622]` — `dict.get()` は「キー不在」と「値がNone」を区別できない。認可コードでは `key in dict` で明示的にチェックし、不在はデフォルト拒否とすべき。dict.get() を認可ロジックで使用していないか確認する
- **エラーメッセージの定数化漏れ** `[新観点 from PR#624]` — 新しいエラーメッセージを追加する際、リテラル文字列ではなく定数ファイル（`PermissionErrors` 等）に定義して参照する。
- **str(e) のエラー契約混入** `[新観点 from PR#659]` — except ブロックで `str(e)` をユーザー向けレスポンスや Result の details に含めていないか確認する。内部例外テキストは不安定（ライブラリ更新で変わる）であり、テストも壊れやすくなる。デバッグ情報が必要なら structured logging に出力し、API 契約には定数メッセージのみ含める。
