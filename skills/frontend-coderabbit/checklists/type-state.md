# Frontend Review: Type Safety + State Management

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Type Safety `[型: 40回 - 最多頻出]`

- [ ] **`any`型禁止** — `any`は禁止。`unknown`/`never`/ジェネリクス/型ガードで代替
- [ ] **`enum`禁止** — TypeScriptの`enum`は禁止。`const + as const + typeof`で代替（→ `references/code-examples.md`）
- [ ] **型アサーション原則禁止** — `as`キャスト・`!`(non-null assertion)は原則禁止の最終手段。`?? デフォルト値`/型ガード/`unknown`+narrowing/ジェネリクスで代替し、`as unknown as X`は絶対NG。許容はライブラリが型を提供していない等の回避不能なケースのみ。テストコードも含め残存していないか確認（テストは`?? []`/`?? ''`等で代替可能なケースが多い）。`as`で型を上書きしている箇所は元の型定義が誤っている可能性があり、型定義を修正してキャストを除去する
- [ ] **`console.*`禁止** — `console.log/warn/error`等の直接使用は禁止。`shared/lib/logger.ts`経由で出力する（DEV環境のみ出力）。エラーは4層パイプライン経由
- [ ] **`<script setup lang="ts">`必須** — `lang="ts"`の省略禁止
- [ ] **スキーマ不一致の防止** — APIレスポンスのフィールド名・型・構造がバックエンドの実際のレスポンスと一致しているか確認する。スキーマ不一致はサイレントなバグの原因になる

### State Management

- [ ] **composable singletonのreadonly保護** — module-levelのrefをそのまま公開しない。`readonly()`でラップして外部から直接書き込まれないようにする（→ `references/code-examples.md`）
- [ ] **Composable/Hookの単一責務** — Composable/Hookに複数の責務（データ取得・状態管理・UI制御等）が混在していないか。責務ごとに分離すること
- [ ] **同一型の重複定義禁止** — 型の中身が既存の型と同一なのに別名で新たに定義していないか確認する。既存の型定義を検索し、同等の構造がすでにあれば再利用すること

---

## Extended Checklist

### Type Safety（詳細）

- **型定義の配置と新規entity作成時のスキーマ配置** — 型の配置が規約どおりか確認する: ドメインモデル型は`entities/*/model/{entity}Types.ts`、APIスキーマは`entities/*/api/`、フォームバリデーションZodは`features/*/model/{feature}Schema.ts`、汎用型は`shared/types/`（規約 5.2）
- **toEntity()でsnake_case→camelCase変換必須** — APIレスポンスのsnake_caseをそのまま使わず、必ず`toEntity()`でドメイン型（camelCase）に変換する。Backend型は`entities/*/api/*ApiTypes.ts`、ドメイン型は`entities/*/model/*Types.ts`に定義
- **Zodによるruntime validation** — 認証・権限・金額等のクリティカルなAPIは本番でもZod検証必須。検証はAPI層で1回のみ、UI層に生データを持ち込まない
- **typeをデフォルト使用** — `type`をデフォルト使用。`interface`は拡張前提の公開契約のみ
- **金額にFloat演算禁止** — 金額に浮動小数点演算を直接使わない。`Amount`型（branded integer）経由
- **エンティティ型との型ドリフト防止** — features層でentities層の型フィールドと一致するインライン型定義（例: `{ key: string; label: string }`）がないかチェックする。Pick/Omitで元のエンティティ型を参照すべき。インライン型はエンティティ型の変更に追従できずドリフトの原因になる
- **内部関数の引数型の広さ** — 内部関数でも引数型が実際の使用パターンより広くないかチェック。callerが特定のサブタイプのみ渡す関数は`Extract`で型を絞る
- **インライン型importの禁止** — `import('@playwright/test').Page`のようなインライン型指定を使わない。可読性が低く他ファイルと一貫しない。トップレベルで`import type { Page } from '@playwright/test'`のように`type`キーワード付きimportを使うこと
- **unknown/nullableの暗黙文字列変換禁止** — `String(unknown)`は`[object Object]`を、`String(null)`は`"null"`、`String(undefined)`は`"undefined"`を生む。unknown型は`typeof`ガードで文字列化し、router.pushのquery params等にnullableフィールドを`String()`で渡す場合は事前にnull/undefinedチェックを入れ欠損時はqueryごと省略する。`String()`/`.toString()`にunknown/object/nullableが渡される箇所をgrepで検出すべき
- **外部ストレージ復元値のas禁止と非信頼** — sessionStorage/IndexedDB等からの復元時に`as`キャストで型安全性を無視せず、常にtype guardでバリデーションする。さらにcompanyIdのようなセキュリティ境界に関わる値は復元値を信頼せず、現在のルートコンテキストをSingle Source of Truthとする
- **文字列入力のtrim()判定** — query paramsやフォーム入力の空文字チェックで`!value`だけでなく`!value.trim()`で空白のみの文字列も不正値として扱う。`"   "`はfalsyではないため`!value`をすり抜ける
- **比較時の正規化一貫性** — 2つの値を比較する際、片方だけ正規化していないか確認する。`normalizeTargetHeader`等の正規化関数を一方にのみ適用すると、空白やケースの違いで不一致が生じる。比較の両辺に同じ正規化を適用すること
- **DropdownOption.id変換の可逆性** — DropdownOption.id(string)へ変換→元の型に戻すパターンでは、変換が可逆であることを確認する。Number()ヒューリスティックによる型推定は避け、元データからの逆引きまたはtype-prefixed IDを使う

### State Management（詳細）

- **状態の3分類** — サーバー状態→TanStack Query、クライアントグローバル状態→composable singleton、ローカルUI状態→コンポーネント内ref。混在禁止
- **Pinia使用禁止** — Piniaの`defineStore`を使用していないか。Piniaは使用しない。サーバー状態はTanStack Query、クライアントグローバル状態はcomposable singleton（module-level ref + `readonly()`）で管理
- **Props バケツリレー防止** — 3階層以上のprops受け渡しがないか。provide/inject、composable singleton等で解決
- **`computed`の使用** — テンプレート内の複雑な条件式は`computed`に切り出す
- **propsデフォルト値の一貫性** — 同じpropsを複数箇所で`??`でデフォルト値を設定していないかチェック。デフォルト値を定数として一箇所に集約すること。不一致バグの原因になる
- **module-level singletonのライフサイクル管理** — module-level singleton（composable内のmodule-scope ref）の状態がページ遷移時に適切にリセットされるか、onUnmountedでのクリーンアップを忘れていないか確認する。前画面からのstale stateが残る前提で、クエリの`enabled`ガードだけでなく引数レベルでもルート同期完了後にのみ値を渡すガードが必要か確認する（stale regionでクエリが発火するとキャッシュ汚染やUXバグの原因になる）
- **モジュールレベルキャッシュの認証境界ライフサイクル** — メモリキャッシュ（module-level変数）を導入した際、ログアウト・セッション切れ・401/403エラー等の認証境界で適切にクリアされるかチェックする。キャッシュ追加時に無効化ポイントの洗い出しをセットで行わないと古い値が残りセキュリティ・機能バグになる。`invalidate`関数をexportし認証境界で呼び出すこと
- **watcherの監視対象網羅性** — watcher内の分岐条件で参照する全てのリアクティブ値がwatch sourcesに含まれているか確認する。エラー状態（queryのerror ref等）を分岐で参照する場合はそのerror refも必ず含める。監視対象外の値が後から変更されるとwatcherが再実行されず条件分岐が陳腐化し、エラー発生時にpending状態を誤消費するとリトライ時に初期値が失われる
- **複数watcherの競合チェック** — 複数のwatcherが同じrefを操作する場合、モード切替（ドックモード等）時の優先順位が正しいか確認する。後続watcherが前のwatcherの設定を上書きしないこと
- **watcher間のエラークリア一貫性** — 複数フィールドにwatcherを設定する場合、エラー状態のクリア処理が一貫しているか確認する。片方のwatcherだけ`submitError`をクリアし、もう片方が漏れているケースがないか
- **watch の deep オプションのスコープ** — 複数ソースのwatchで`{ deep: true }`を使う場合、プリミティブrefとオブジェクトrefが混在していないかチェック。混在時はwatcherを分離してdeepの適用範囲を最小化する
- **状態フラグの初期化・リセット漏れ** — 新しいstateフラグ追加時に、関連するreset/clear系関数への反映を確認する。新規refを追加したらgrepでreset関数を探し漏れがないか確認すること。フロー破棄処理でも関連する全てのストア/状態（モーダルの表示状態を含む）をリセットし、破棄後にUIが正しい初期状態に戻るか検証する
- **モーダルキャンセル時の明示的閉じ処理** — `v-model`でモーダルの開閉を制御する場合、キャンセルハンドラで`v-model`バインド先を明示的に`false`に設定しているか確認する。関連データのクリアのみでモーダル閉じをコンポーネント側に依存すると、回帰時にモーダルが閉じない不具合が発生する
- **バリデーションの上下限対称性** — 数値の上限チェック（`> MAX`）を追加する際は、下限チェック（`< 1`や`!Number.isInteger()`）も対で追加されているか確認する。エラー定数がimportされているのに使用されていない場合はバリデーション漏れの兆候
- **ナビゲーションガードの相互排他** — 複数の遷移ハンドラーがある画面で、各ナビゲーション状態フラグが互いの抑止条件に含まれているか確認する
- **derived stateのソース不一致** — 同一画面内でroute-basedとcomposable-basedのderived stateが混在する場合、reset keyとdata sourceが異なるソースを参照していないか確認する。computedの依存チェーンを追って同期タイミングのズレを検出する
- **pending/initialSelection消費時の!errorガードと整合性** — initialSelection等のpending値を消費する分岐が複数ある場合、全分岐に`!error`ガードが入っているか確認する。「options空 + !isLoading」パスだけでなく「options有 + assignment未存在 + !isLoading」パスにも同じガードが必要で、片方だけだとエラー時にpendingを誤消費する。複数IDを伴う消費（assignmentId + mappingId等）は一方のIDだけの一致で消費せず、assignment AND target mappingの両方が存在する場合のみ消費し、片方だけ見つかった場合かつisLoading中は新データ到着まで待機すること
- **ユーザー手動操作時のpending初期選択破棄** — composableがinitialSelection等のpending状態を保持する場合、ユーザーが手動でsetterを呼んだ時点でpendingを破棄する。そうしないと後からデータが到着した際にユーザーの手動選択がpendingの自動適用で上書きされる。setterに`resolveInitialSelectionByUserAction()`を入れ、watcherにも`initialSelectionApplied`ガードを追加すること
- **初期選択query params消費後のURL残留** — query paramsで渡された初期選択値（assignmentId等）を消費した後、URLからquery paramsを除去するwatcherが必要。さらにユーザーが手動で選択を変更した場合にも旧query paramsをクリーンアップすること。リロード時に旧値が再適用されるバグの原因になる
- **非同期遷移・キャッシュ無効化のawait保証** — `queryClient.invalidateQueries()`や`router.push(...)`を`void`でfire-and-forgetしていないか確認する。保存後の画面遷移前など完了を保証すべき箇所では`await Promise.all([...])`/`await router.push(...)`で待機する。`void`は後続処理（状態リセット等）の前提条件を保証せず、遷移失敗時にも後続が実行されるため、成功に依存する処理は完了後に実行すること
