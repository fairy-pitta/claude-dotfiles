# Frontend Review: Test Quality

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイル（特にテストファイル）に対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Extended Checklist

### Test Quality（テストファイルが変更されている場合）

- **テストデータの独立性（テスト汚染防止）** — テスト間で共有される可変なオブジェクト（dict・array等）がないか。テスト間の暗黙の依存はテスト汚染の原因になる
- **MSW使用** — APIモックはMSWを使用しているか。`vi.fn()`の直接モック乱用は避ける
- **テスト期待値の文字列リテラル禁止** — `rejects.toThrow('エラーメッセージ')` 等の期待値に文字列リテラルを直書きしていないか。定数（`MESSAGES.VALIDATION.X`等）を参照する。定数側の変更に追従できず、テストの意図も不明確になる
- **FormDataを使うmutationテスト** — `FormData`を使うMutationのテストでAxiosアダプターをNode.js httpに設定しているか（`axios.defaults.adapter = 'http'`）（→ `references/code-examples.md`）
- **型安全なモック** — モック関数に適切な型が付いているか
- **テストケースの網羅性** — ローディング・エラー・成功状態のそれぞれをカバーしているか
- **テストデータの独立性** — テスト間で共有される可変なオブジェクトがないか
- **モックハンドラのAPIバリデーション再現** `[新観点 from PR#472]` — MSWモックハンドラがAPIの必須パラメータ組み合わせバリデーションを正しく再現しているか確認する。片方のみ指定時のエラーレスポンス等
- **Playwright ルートのクエリパラメータ対応** `[新観点 from PR#480]` — APIリクエストにクエリパラメータが付く場合（例: `?page=1&page_size=50`）、glob パターン `'**/api/endpoint/'` はマッチしない。`page.route()` のパターンは正規表現 `/\/api\/endpoint\//` を使うこと。ページネーションパラメータ追加後は既存テストの route パターンを見直す
- **E2E/VRTテストのセレクタ安定性とモックレスポンス整合性** `[新観点 from PR#480]` — CSS クラスセレクタはスタイル変更で壊れやすい。コンポーネントに `data-testid` を追加し `page.getByTestId()` を使うこと。また MSW/Playwright モックのレスポンス形式はAPIの実際のレスポンス形式（ページネーションフィールド `count`/`page`/`page_size` 等）と一致させること
- **ソートテストの non-null assertion** `[新観点 from PR#480]` - ループ範囲が保証されているソート検証テストで `data?.[i+1].createdAt.getTime() ?? 0` のパターンは false positive のリスク。`expect(data!.length).toBeGreaterThanOrEqual(2)` を追加し `data![i]`/`data![i+1]` の non-null assertion を使う。
- **テストモック正規表現の厳密化** `[新観点 from PR#480]` — Playwrightの `page.route()` やMSWの正規表現パターンに `$` アンカーを付けているか確認。広すぎるパターンは将来エンドポイント追加時に衝突する
- **実装追加時のテストケース同期** `[新観点 from PR#555]` — 既存の判定関数やユーティリティに新しいケース（例: concatColumns）を追加した場合、対応するテストファイルにもケースが追加されているか確認する。実装とテストの不一致は見落としやすい。
- **テストファイルのFSDインポートルール** `[新観点 from PR#569]` — テストファイルでも内部パス直接importではなくバレルエクスポート経由でimportしているかチェック。FSDの「内部直接import禁止」ルールはテストにも適用される。
- **timeout スコープの最小化** `[新観点 from PR#569]` — `describe` 全体に `{ timeout: N }` を設定していないか確認。遅いテストケースが1つだけなら、そのテストの `it` ブロックにのみ `{ timeout: N }` を設定する。describe全体への設定は他のテストの潜在的なタイムアウト問題を隠蔽する。
- **composable 初期分岐のテストカバレッジ** `[新観点 from PR#571]` — composableの同期的な早期リターンパス（例: インメモリ状態が既に存在する場合のスキップ）がテストされているか確認する。非同期パスだけテストすると同期パスのリグレッションを検出できない。早期リターン条件を明示的にテストする。
- **テスト前提条件の明示性** `[新観点 from PR#571]` — テストのArrangeセクションで、テスト成立に必要な前提値がbeforeEachの暗黙デフォルトに依存せず明示的に設定されているか確認する。暗黙依存はリファクタリング時に意図せずテストが壊れる原因になる。テスト内で前提条件を明示する。
- **MSW ハンドラーのインライン定義** `[新観点 from PR#571]` — MSWハンドラーがテストファイル内にインライン定義されていないか確認する。インライン定義はハンドラーの再利用を阻害し重複を生む。ドメイン別ハンドラーファイル（tests/mocks/handlers/）にファクトリ関数として分離する。
- **テストヘルパー共通化** — `createTestQueryClient()`/`mountWithQuery()`等の共通関数を`tests/helpers/`に集約して使用しているか
- **data-testidセレクタ優先順位** — role/text > data-testid の優先順位。`data-testid`は`scope-element-action`のkebab-case
- **テストヘルパー重複検出** — 同一ディレクトリ内のテストファイルで同じヘルパー関数（ファクトリ、スタブ等）が重複定義されていないか確認する。変更漏れやメンテナンス性低下の原因になる。共通ヘルパーファイルに抽出する。
- **mutation空入力ガード** `[新観点 from PR#571]` — mutation関数に空配列やnull入力が来た場合のガードがあるかチェック。呼び出し元の暗黙の仮定に依存せず、防御的にAPIを叩かないガードを入れること。
- **テストモック完全リセット** `[新観点 from PR#571]` — afterEach で全モックフィールドがリセットされているかチェック。新しいモックフィールド追加時にリセットリストへの追加漏れが多い。
- **Vue wrapper unmount** `[新観点 from PR#571]` — module-level ref を使うテストで mount した wrapper を afterEach で unmount しているかチェック。前テストの watcher が afterEach のモック書き換えに反応して次テストの呼び出しを汚染する。
- **data-testid使用** `[新観点 from PR#571]` — テストでテキストマッチ (`button.text() === "..."`) による要素取得を使っていないかチェック。i18n変更に弱い。`data-testid` を使うこと。
- **companyIdスコープテスト** `[新観点 from PR#571]` — マルチテナント系ロジックで他テナントのデータに影響するケースのテストがあるかチェック。境界条件テストとして重要。
- **wrapper teardown 漏れ検出** — mount した Vue コンポーネントは afterEach で unmount しないと watcher が残存しテスト間で干渉する。delay('infinite') やペンディング状態のテストでは特にコンポーネントの teardown を確実に行う。afterEach での wrapper.unmount() を標準パターンとする。
- **エラーコード定数参照** — テストコードでもエラーコード文字列はカタログ定数経由で参照する。文字列リテラルが変更された場合にテストが追従できず壊れるリスクがある。
- **data-testid 命名規約チェック** — テストハーネスの data-testid もCODING_STANDARDSの命名規約（scope-element-action kebab-case）に従う。
- **テストアサーションの具体性** `[新観点 from PR#590]` — テストアサーションは「何が起きたか」を具体的に検証する。件数チェック（`.length > 0`）だけでは別要因のエラー混入を検出できない。エラーIDやメッセージ内容で `some()` や `find()` を使って具体的な値を検証する。
- **nullish coalescing (`??`) フォールバックテスト** `[新観点 from PR#590]` — `?? []` のテストでは空配列 `[]` ではなく `undefined` を入力にしないと分岐が通らない。テスト名「データ未取得」と実際の入力値が一致しているか確認する。
- **新規composableには実挙動テストを必ず追加** `[新観点 from PR#606]` — モックヘルパーのみでは実際のロジックがテストされない。fake timersやeffectScopeを使い、タイマー制御・イベントハンドラ・状態遷移を検証するテストを追加すること。
- **類似型のテスト対称性** `[新観点 from PR#614]` — `fromTop`/`fromBottom` のように対になる型がある場合、一方に書いたプロパティ差分テストが他方にも存在するか確認する。新規サブタイプ追加時は統合テストの導線カバレッジも忘れず追加する。
- **プレビュー系テストのスモークアサーション** `[新観点 from PR#614]` — 「表示されたこと」だけでなく「表示内容が期待通りか」まで検証しているか確認する。最低限のスモークアサーション（要素数、主要なテキスト）を含めているかチェックする。
- **テスト名と実装内容の一致** `[新観点 from PR#616]` — テスト名は `test_<action>_<condition>_<expected>` 形式で、condition が実際のテスト入力と一致しているか確認する。"undefined" と "non_numeric" は異なる条件。
- **分岐網羅テストの漏れ** `[新観点 from PR#491]` — 条件分岐がある関数は各分岐パスに対応するテストを書く。特にフォールバック分岐（else/default/??）は忘れやすい。新規関数追加時に分岐数とテストケース数を対比して漏れを検出すること。

### Accounting（会計固有ルール）

- **金額をnumberで直接演算禁止** — Amount型関数（`createAmount()`/`addAmounts()`等）経由必須。丸めは明細単位
- **会計日付のYYYY-MM形式** — `timestamp(UTC)`と`businessDate(YYYY-MM)`を分離。決算月は`YYYY-13`
- **仕訳系Mutationの楽観更新禁止** — 冪等キー(Idempotency-Key)必須 + UI側submitting ref + API側冪等キーの二重防止
- **論理削除のみ** — フロントエンドからの削除リクエストは論理削除のみ（物理削除API禁止）
- **締め処理後のデータ変更禁止** — 月次/年度締め後のデータ変更をUIで禁止。`JournalPeriodStatus`型に基づく制御

### Naming（命名規約）

- **Vue SFCファイル名: PascalCase** — `LoginPage.vue`
- **TypeScriptファイル名: camelCase** — `userKeys.ts`
- **ディレクトリ名: kebab-case** — `journal-upload/`
- **変数/関数: camelCase、型/interface: PascalCase、定数: UPPER_SNAKE_CASE**
- **Composable: `use` + PascalCase** — `useCurrentUser`
