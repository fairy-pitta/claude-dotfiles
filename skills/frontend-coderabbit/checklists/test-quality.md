# Frontend Review: Test Quality

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイル（特にテストファイル）に対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Test Quality（テストファイルが変更されている場合）

- [ ] **テスト名と入力・実装の一致** — テスト名は `test_<action>_<condition>_<expected>` 形式で、condition が実際のテスト入力と一致しているか。`"undefined"` と `"non_numeric"`、空配列 `[]` と `undefined` は別条件。テスト名が示す範囲（例:「全必須項目のバリデーション」）と実際の検証範囲も一致させる
- [ ] **テストケースの状態網羅性** — ローディング・エラー・成功状態のそれぞれをカバーしているか
- [ ] **MSW使用** — APIモックはMSWを使用しているか。`vi.fn()`の直接モック乱用は避ける
- [ ] **文字列リテラル禁止→定数参照** — 期待値（`rejects.toThrow('エラーメッセージ')`等）やエラーコードに文字列リテラルを直書きせず、カタログ定数（`MESSAGES.VALIDATION.X`、エラーコード定数等）を参照する。リテラル変更にテストが追従できず意図も不明確になる
- [ ] **data-testidセレクタ優先と命名規約** — 要素取得は role/text > data-testid の優先順位とし、テキストマッチ（`button.text() === "..."`）やCSSクラス直参照（`.class-name`）を使わない。i18n変更やスタイル変更に弱く偽陽性の原因になる。`data-testid` は `scope-element-action` の kebab-case 規約（MUST）に従う
- [ ] **テストデータの独立性（テスト汚染防止）** — テスト間で共有される可変なオブジェクト（dict・array等）がないか。暗黙の依存はテスト汚染の原因になる
- [ ] **テスト前提条件の明示性** — Arrangeセクションでテスト成立に必要な前提値がbeforeEachの暗黙デフォルトに依存せず明示的に設定されているか。暗黙依存はリファクタリング時に意図せずテストが壊れる原因になる
- [ ] **型安全なモック** — モック関数に適切な型が付いているか
- [ ] **アサーションの具体性** — 件数チェック（`.length > 0`）だけでなく「何が起きたか」を具体的に検証する。エラーIDやメッセージ内容で `some()`/`find()` を使い具体値を検証する。表示系テストも「表示されたこと」だけでなく主要なテキスト・要素数までスモークアサートする
- [ ] **モック定義とアサートの整合性** — モックを定義しているのにアサートしていない箇所がないか。モックを作る＝検証する意図があるはず。アサートなしのモックは意図が不完全
- [ ] **分岐網羅テストの漏れ** — 条件分岐がある関数は各分岐パスのテストを書く。特にフォールバック分岐（else/default/`??`）は忘れやすい。`?? []` の分岐は空配列ではなく `undefined` を入力しないと通らない。catch内の条件分岐（握りつぶす vs 再throw）やonSuccessの全分岐パス（一部スキップする分岐含む）も両方テストする。新規関数追加時は分岐数とテストケース数を対比する
- [ ] **テストヘルパー共通化と重複検出** — `createTestQueryClient()`/`mountWithQuery()` 等の共通関数を `tests/helpers/` に集約しているか。同一ディレクトリ内のテストファイルで同じヘルパー（ファクトリ、スタブ等）が重複定義されていないか確認し、共通ヘルパーに抽出する
- [ ] **MSWハンドラーの共通化と一貫性** — MSWハンドラーをテストファイル内にインライン定義せず、ドメイン別ファイル（`tests/mocks/handlers/`）にファクトリ関数として集約する。同一エンドポイントのハンドラーが複数箇所にある場合はAPIパスプレフィックス（`/api/`等）の一貫性をgrepで確認する。不一致は実APIと異なるパスでモックする偽陽性の原因
- [ ] **モックハンドラのバリデーション・レスポンス再現** — MSW/モックハンドラがAPIの必須パラメータ組み合わせバリデーション（片方のみ指定時のエラー等）を再現し、レスポンス形式（ページネーションフィールド `count`/`page`/`page_size` 等）を実APIと一致させているか
- [ ] **Vue wrapper の unmount/teardown** — mountしたコンポーネントは `afterEach` で `wrapper.unmount()` する（Vitestは自動クリーンアップしない）。残存watcherが afterEach のモック書き換えに反応し次テストを汚染する。module-level ref や delay('infinite')・ペンディング状態のテストでは特に確実に行う。mountヘルパー使用時は変数に保持して明示的にunmountする
- [ ] **テストモックの完全リセット** — `afterEach` で全モックフィールドがリセットされているか。新しいモックフィールド追加時にリセットリストへの追加漏れが多い
- [ ] **テストファイルのFSDインポートルール** — テストファイルでも内部パス直接importではなくバレルエクスポート経由でimportしているか。FSDの「内部直接import禁止」ルールはテストにも適用される
- [ ] **未使用importの残存** — import文に未使用のモック関数が残っていないか。コピペ作成時に残りやすい。テストファイルがlint対象から外れていないかも確認する
- [ ] **実装追加時のテストケース同期** — 既存の判定関数・ユーティリティ・watcher・computed に新しいケースや分岐（例: concatColumns）を追加した場合、対応するテストにも直接テストするケースを追加する。周辺テストの間接カバーだけでは回帰リスクが残る
- [ ] **mutation空入力ガードとガード未呼出検証** — mutation関数に空配列やnull入力が来た場合のガードがあるか。呼び出し元の暗黙の仮定に依存せず防御的にAPIを叩かない。ガード（companyId検証等）のテストではエラー表示だけでなくcallCount/スパイで「APIが呼ばれていないこと（送信回数0）」もアサートする

### Accounting（会計固有ルール）

- [ ] **金額をnumberで直接演算禁止** — Amount型関数（`createAmount()`/`addAmounts()`等）経由必須。丸めは明細単位
- [ ] **会計日付のYYYY-MM形式** — `timestamp(UTC)`と`businessDate(YYYY-MM)`を分離。決算月は`YYYY-13`
- [ ] **全Mutationの楽観更新禁止** — 楽観的更新は全Mutationで禁止。サーバーレスポンスを待ち`onSuccess`でキャッシュ無効化する。冪等キー(Idempotency-Key)必須 + UI側submitting ref + API側冪等キーの二重防止
- [ ] **論理削除のみ** — フロントエンドからの削除リクエストは論理削除のみ（物理削除API禁止）
- [ ] **締め処理後のデータ変更禁止** — 月次/年度締め後のデータ変更をUIで禁止。`JournalPeriodStatus`型に基づく制御

### Naming（命名規約）

- [ ] **Vue SFCファイル名: PascalCase** — `LoginPage.vue`
- [ ] **TypeScriptファイル名: camelCase** — `userKeys.ts`
- [ ] **ディレクトリ名: kebab-case** — `journal-upload/`
- [ ] **変数/関数: camelCase、型/interface: PascalCase、定数: UPPER_SNAKE_CASE**
- [ ] **Composable: `use` + PascalCase** — `useCurrentUser`

---

## Extended Checklist

### Test Quality（テストファイルが変更されている場合）

- **FormDataを使うmutationテスト** — `FormData`を使うMutationのテストでAxiosアダプターをNode.js httpに設定しているか（`axios.defaults.adapter = 'http'`）（→ `references/code-examples.md`）
- **Playwright/MSW ルートパターンの厳密化** — クエリパラメータが付くAPI（例: `?page=1&page_size=50`）は glob `'**/api/endpoint/'` ではマッチしないため `page.route()` は正規表現 `/\/api\/endpoint\//` を使う。正規表現には `$` アンカーを付け広すぎるパターンを避ける（将来のエンドポイント追加時に衝突する）。ページネーションパラメータ追加後は既存テストのrouteパターンを見直す
- **同一URLパターンの複数route登録にJSDoc** — Playwrightの`page.route`で同一URLパターンに複数ハンドラを登録する場合、評価順序（後勝ち+fallback連鎖）をJSDocに明記する。暗黙の順序依存は保守性を損なう
- **VRT/E2E操作後の状態安定化と待機** — `check()`等のUI操作後やクリック後、スクリーンショット撮影・次操作の前に `toBeChecked()` 等の状態確認アサーションやDOM反映の待機を入れる。アクション完了とUIレンダリング完了は別でありフレーク防止に必須。同じ操作を行う他テストの待機パターンと整合させる
- **VRTのgoto直後のスクリーンショット禁止** — `page.goto` 直後に `toHaveScreenshot` を呼ばない。CI環境では描画完了前に撮影され不安定になる。代表要素の `toBeVisible` 待機を挟む
- **VRT複数要素待機にtoHaveCount使用** — 複数要素の表示を待つ場合 `first().toBeVisible()` ではなく `toHaveCount()` で全件の描画完了を待機する。1件だけ待つとレースコンディションで不安定になる
- **VRTヘルパー活用** — `page.mouse.move(0,0)` + `toHaveScreenshot` のような定型パターンが3箇所以上あればヘルパー関数に抽出する。`tests/helpers/vrt-utils.ts` の既存ヘルパーを確認し活用する
- **v-if要素の非存在検証** — `v-if`でDOM除去される要素は `not.toBeVisible()` ではなく `toHaveCount(0)` で検証する。`v-if`はDOM除去、`v-show`はCSS非表示でありアサーションを使い分ける。`not.toBeVisible()`は動作するが意図が不正確
- **E2Eセレクタの特異性** — セレクタが汎用要素（form, section, div等）に依存していないか。対象画面が壊れてもテストが通る偽陽性の原因になる。画面固有の見出し・ボタンラベル・data-testidで検証する
- **waitForURL後の冗長なURL assertion** — `waitForURL`は内部的にURLマッチを待機+検証するため、直後の`expect(page.url()).toContain()`は冗長。待機系APIが暗黙にアサーションを含むか意識し重複検証を避ける
- **nextTick vs flushPromises** — 「APIが呼ばれないこと」等を検証する場合、nextTick()は同期的DOM更新のみ待機しPromise chainは待機しない。flushPromises()で全非同期を完了させてからアサートする
- **fake timersのtry/finally保護** — `vi.useFakeTimers()` を使うテストで `vi.useRealTimers()` がテスト末尾にしかないと途中の `await`/`expect` 失敗時に後続テストまでフェイクタイマーのままになる。`try/finally` で `vi.useRealTimers()` を保護する
- **timeout スコープの最小化** — `describe` 全体に `{ timeout: N }` を設定していないか。遅いテストが1つだけなら該当 `it` ブロックのみに設定する。describe全体への設定は他テストの潜在的タイムアウト問題を隠蔽する
- **新規composableには実挙動テストを必ず追加** — モックヘルパーのみでは実ロジックがテストされない。fake timersやeffectScopeを使い、タイマー制御・イベントハンドラ・状態遷移を検証する実挙動テストを追加する
- **composable singletonの外部副作用モック** — composable singletonのテストで永続化・API呼び出し等の外部副作用がモックされているか。hydrate（復元）とset（ユーザー操作）で副作用の有無が異なる場合はその差分をテストで固定する。debounceやtimerが残るテストはflakyの原因
- **composable 同期早期リターンのカバレッジ** — composableの同期的な早期リターンパス（例: インメモリ状態が既に存在する場合のスキップ）がテストされているか。非同期パスだけでは同期パスのリグレッションを検出できない
- **nullable引数の遷移テスト** — composableテストで引数がnullableな場合に `null → 有効値` への遷移パスをテストしているか。特に TanStack Query の enabled 切り替えが絡む場合は必須
- **ソートテストの non-null assertion** — ループ範囲が保証されるソート検証で `data?.[i+1].createdAt.getTime() ?? 0` は false positive のリスク。`expect(data!.length).toBeGreaterThanOrEqual(2)` を追加し `data![i]`/`data![i+1]` の non-null assertion を使う
- **companyId/マルチテナントスコープテスト** — マルチテナント系ロジックで他テナントのデータに影響するケースのテストがあるか。境界条件テストとして重要
- **テストスタブの自動emit抑制** — テストスタブがコンポーネント内部ロジック（モーダル閉じ等）を自動bypassしていないか。スタブはイベントのみemitし副作用は実装側に委ねる
- **2段階保存・複数回呼び出しパスのカバレッジ** — 条件分岐で保存APIが複数回呼ばれるフローがある場合、主要分岐のテストケースを追加する
- **類似型・複数ビューのテスト対称性** — `fromTop`/`fromBottom` のように対になる型や、同一ロジックが複数ビュー/タブに適用される場合、一方に書いたテスト（プロパティ差分・導線カバレッジ）が他方にも存在するか。片方だけテストして他方を漏らすパターンに注意。新規サブタイプ追加時は統合テストの導線も追加する
- **Record<string>型パターンのファイル全体チェック** — 1箇所を `as const satisfies` に修正したら、同ファイル内の他の `Record<string, ...>` にも同じ問題がないか全件確認する。部分修正で別箇所を見落とすリスク
- **staleキャッシュのmapping不一致テスト** — initialSelectionを受けるcomposableで「assignmentは存在するがtarget mappingだけ古い（staleキャッシュ）」ケースのテストがあるか。assignment一致だけでは不十分でmapping一致も含めた全パスをテストする
- **空白文字列入力のテストケース** — 文字列バリデーションテストで空文字 `""` だけでなく空白のみ `"   "` やタブ `"\t"` のケースも追加する。`trim()` 判定の回帰を検出するため
- **テストモックデータの重複定義** — 同一テスト関数内で同じ値（ID, 名前等）が複数箇所に出現する場合、定数に抽出して一元管理する。重複は変更時に片方だけ修正するリスク
- **テストURLとモックデータのID整合** — テストのURL内のIDとモックデータのデフォルトIDが一致しているか。ワイルドカードモックで通っても意味的に不正確
- **テストファイルの構造順序** — 変数宣言 → setup/teardown → 前提テスト → 本テストの順序で配置する。参照される変数より前に前提テストが配置されると可読性が低下する
