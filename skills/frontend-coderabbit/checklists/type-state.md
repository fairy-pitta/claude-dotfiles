# Frontend Review: Type Safety + State Management

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Type Safety `[型: 40回 - 最多頻出]`

- [ ] **`any`型禁止** — `any`は禁止。`unknown`/`never`/ジェネリクス/型ガードで代替
- [ ] **`enum`禁止** — TypeScriptの`enum`は禁止。`const + as const + typeof`で代替（→ `references/code-examples.md`）
- [ ] **型アサーション原則禁止** — `as`キャスト・`!`(non-null assertion)は原則禁止。「必殺技」であり最終手段。`?? デフォルト値`/型ガード/`unknown`+narrowing/ジェネリクスで代替。`as unknown as X`は絶対NG。許容されるのはライブラリが型を提供していない等の回避不能なケースのみ
- [ ] **`console.*`禁止** — `console.log/warn/error`等の直接使用は禁止。`shared/lib/logger.ts`経由で出力する（DEV環境のみ出力）。エラーは4層パイプライン経由
- [ ] **`<script setup lang="ts">`必須** — `lang="ts"`の省略禁止

### State Management

- [ ] **composable singletonのreadonly保護** — module-levelのrefをそのまま公開しない。`readonly()`でラップして外部から直接書き込まれないようにする（→ `references/code-examples.md`）
- [ ] **Composable/Hookの単一責務** — Composable/Hookに複数の責務（データ取得・状態管理・UI制御等）が混在していないか。責務ごとに分離すること
- [ ] **バックエンド/フロントエンド間のスキーマ不一致** — APIレスポンスのフィールド名・型・構造がバックエンドの実際のレスポンスと一致しているか確認する。スキーマ不一致はサイレントなバグの原因になる
- [ ] **同一型の重複定義禁止** — 型の中身が既存の型と同一なのに別名で新たに定義していないか確認する。既存の型定義を検索し、同等の構造がすでにあれば再利用すること

---

## Extended Checklist

### Type Safety（詳細）

- **型アサーション`as`/`!`の残存チェック** — Core観点の原則禁止に加え、テストコードも含めて`as`/`!`が残っていないか確認。テストでは`?? []`/`?? ''`等のフォールバックで代替可能なケースが多い
- **toEntity()でsnake_case→camelCase変換必須** — APIレスポンスのsnake_caseをそのまま使わず、必ず`toEntity()`でドメイン型（camelCase）に変換する。Backend型は`entities/*/api/*ApiTypes.ts`、ドメイン型は`entities/*/model/*Types.ts`に定義
- **型定義の配置** — ドメインモデル型は`entities/*/model/`、APIスキーマは`entities/*/api/`、フォームバリデーションは`features/*/model/`、汎用型は`shared/types/`に配置
- **Zodによるruntime validation** — 認証・権限・金額等のクリティカルなAPIは本番でもZod検証必須。検証はAPI層で1回のみ、UI層に生データを持ち込まない
- **typeをデフォルト使用** — `type`をデフォルト使用。`interface`は拡張前提の公開契約のみ
- **金額にFloat演算禁止** — 金額に浮動小数点演算を直接使わない。`Amount`型（branded integer）経由
- **エンティティ型との型ドリフト防止** — features層でentities層の型フィールドと一致するインライン型定義（例: `{ key: string; label: string }`）がないかチェックする。Pick/Omitで元のエンティティ型を参照すべき。インライン型はエンティティ型の変更に追従できずドリフトの原因になる
- **新規entity作成時のapi/schema.tsの有無チェック** — 新規entityを作成する際、`api/schema.ts`にZodスキーマが定義されているか確認する。権限・認証系APIレスポンスを含め、全てのAPIレスポンスにランタイム検証（Zodスキーマ）を設けること。CODING_STANDARDS.mdのスキーマ規約違反になる
- **内部関数の引数型の広さ** — 内部関数でも引数型が実際の使用パターンより広くないかチェック。callerが特定のサブタイプのみ渡す関数は `Extract` で型を絞る。

### State Management（詳細）

- **状態の3分類** — サーバー状態→TanStack Query、クライアントグローバル状態→composable singleton、ローカルUI状態→コンポーネント内ref。混在禁止
- **Pinia使用禁止** — Piniaの`defineStore`を使用していないか。Piniaは使用しない。サーバー状態はTanStack Query、クライアントグローバル状態はcomposable singleton（module-level ref + `readonly()`）で管理
- **Props バケツリレー防止** — 3階層以上のprops受け渡しがないか。provide/inject、composable singleton等で解決
- **`computed`の使用** — テンプレート内の複雑な条件式は`computed`に切り出す
- **複数watcherの競合チェック** `[新観点 from PR#510]` — 複数のwatcherが同じrefを操作する場合、モード切替（ドックモード等）時の優先順位が正しいか確認する。後続watcherが前のwatcherの設定を上書きしないこと。
- **module-level singletonのページ遷移時リセット** `[新観点 from PR#510]` — module-level singleton（composable内のmodule-scope ref）の状態がページ遷移時に適切にリセットされるか確認する。onUnmountedでのクリーンアップを忘れないこと。
- **watcher間のエラークリア一貫性** `[新観点 from PR#528]` — 複数フィールドにwatcherを設定する場合、エラー状態のクリア処理が一貫しているか確認する。片方のwatcherだけ `submitError` をクリアし、もう片方が漏れているケースがないか。
- **watch の deep オプションのスコープ** `[新観点 from PR#569]` — 複数ソースのwatchで `{ deep: true }` を使う場合、プリミティブrefとオブジェクトrefが混在していないかチェック。混在時はwatcherを分離してdeepの適用範囲を最小化する。
- **モジュールレベルキャッシュの認証境界ライフサイクル** `[新観点 from PR#523]` — メモリキャッシュ（module-level変数）を導入した際、ログアウト・セッション切れ・401/403エラー等の認証境界で適切にクリアされるかチェックする。キャッシュ追加時に無効化ポイントの洗い出しをセットで行わないと、古い値が残り続けてセキュリティ・機能バグになる。`invalidate`関数をexportし、認証境界で呼び出すこと
- **watcher 監視対象の網羅性** `[新観点 from PR#571]` — watcher内の分岐条件で使用しているリアクティブ値が全て監視対象に含まれているか確認する。監視対象外の値が後から変更された場合、watcherが再実行されず条件分岐が陳腐化する。条件で参照する全てのリアクティブ値をwatch sourcesに含める。
- **propsデフォルト値の一貫性** `[新観点 from PR#571]` — 同じ props を複数箇所で `??` でデフォルト値を設定していないかチェック。デフォルト値を定数として一箇所に集約すること。不一致バグの原因になる。
- **状態フラグの初期化漏れ** `[新観点 from PR#606]` — 新しい state フラグ追加時に、関連する reset/clear 系関数への反映を確認する。新規 ref を追加したら grep で reset 関数を探し、漏れがないか確認すること。
- **モーダルキャンセル時の明示的閉じ処理** `[新観点 from PR#519]` — `v-model` でモーダルの開閉を制御する場合、キャンセルハンドラで `v-model` バインド先を明示的に `false` に設定しているか確認する。関連データのクリアのみでモーダル閉じをコンポーネント側に依存すると、回帰時にモーダルが閉じない不具合が発生する。
- **バリデーションの上下限対称性** `[新観点 from PR#614]` — 数値の上限チェック（`> MAX`）を追加する際は、下限チェック（`< 1` や `!Number.isInteger()`）も対で追加されているか確認する。エラー定数が import されているのに使用されていない場合はバリデーション漏れの兆候。
- **String(unknown)の暗黙変換禁止** `[新観点 from PR#491]` — `String(unknown)` の暗黙変換は `[object Object]` を生む。unknown 型の値を文字列化する場合は必ず `typeof` ガードを入れる。セルフレビューで `String()` や `.toString()` に unknown/object が渡される箇所を grep で検出すべき。
- **外部ストレージ復元時のasキャスト禁止** `[新観点 from PR#623]` — sessionStorage/IndexedDB からの復元時に `as` キャストで型安全性を無視していないかチェックする。外部ストレージからの入力は常にtype guardでバリデーションが必要。
- **復元値のcompanyIdを信頼しない** `[新観点 from PR#623]` — 外部ストレージから復元した値をそのまま信頼していないかチェックする。companyIdのようなセキュリティ境界に関わる値は、復元値ではなく現在のルートコンテキストをSingle Source of Truthとする。
- **インライン型importの禁止** `[新観点 from PR#637]` — `import('@playwright/test').Page`のようなインライン型指定を使わない。可読性が低く他ファイルと一貫しない。トップレベルで`import type { Page } from '@playwright/test'`のように`type`キーワード付きimportを使うこと。
- **型定義とas キャストの不一致** `[新観点 from PR#623]` — `as`キャストで型を上書きしている箇所がある場合、元の型定義が正しくない可能性がある。型定義を修正してキャストを除去する。
- **フロー破棄処理の状態リセット漏れ** `[新観点 from PR#623]` — 破棄処理では関連する全てのストア/状態をリセットしているか確認する。モーダルの表示状態も含めて、破棄後にUIが正しい初期状態に戻るか検証する。
- **ナビゲーションガードの相互排他** `[新観点 from PR#623]` — 複数の遷移ハンドラーがある画面で、各ナビゲーション状態フラグが互いの抑止条件に含まれているか確認する。
- **derived stateのソース不一致** `[新観点 from PR#586]` — 同一画面内でroute-basedとcomposable-basedのderived stateが混在する場合、reset keyとdata sourceが異なるソースを参照していないか確認する。computedの依存チェーンを追って同期タイミングのズレを検出する。
- **initialSelection消費時のstaleキャッシュ対策** `[新観点 from PR#654]` — query paramsやpropsで渡された初期選択値（assignmentId + mappingId等）を消費する際、一方のIDだけの一致で消費しない。assignment AND target mappingの両方が存在する場合のみ消費し、片方だけ見つかった場合かつisLoading中は新データ到着まで待機すること。
- **invalidateQueriesのawait漏れ** `[新観点 from PR#654]` — `queryClient.invalidateQueries()` を `void` で fire-and-forget していないか確認する。保存後の画面遷移前など、キャッシュ無効化完了を保証すべき箇所では `await Promise.all([...])` で完了を待機する。
- **composable singleton stale stateガード** `[新観点 from PR#642]` — module-level refを使うcomposable singletonでは、前画面からのstale stateが残る前提でクエリの`enabled`ガードだけでなく、引数レベルでもルート同期完了後にのみ値を渡すガードが必要か確認する。stale regionでクエリが発火するとキャッシュ汚染やUXバグの原因になる。
- **watch監視対象にエラー状態を含める** `[新観点 from PR#654]` — watchの分岐条件でエラー状態（queryのerror ref等）を参照する場合、そのerror refをwatch sourcesに含めているか確認する。エラー発生時にpending状態を誤って消費すると、リトライ時に初期値が失われる。
