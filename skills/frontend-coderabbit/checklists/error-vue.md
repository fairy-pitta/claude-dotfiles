# Frontend Review: Error Handling + Vue.js Patterns

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Error Handling `[エラー: 25回]`

- [ ] **エラーメッセージ直書き禁止** — 文字列リテラルで直書きせず、カタログ定数経由（→ `references/code-examples.md`）
- [ ] **メッセージ定数の文字列連結前提を排除** `[新観点 from PR#519]` — メッセージ定数が呼び出し側の前置/後置連結を前提としている場合（例: `"を削除します"` で始まる文字列）、テンプレート関数化（`(userName: string) => \`...\``）して自己完結させる。連結漏れによる文言崩れを防止する

### Vue.js Patterns

- [ ] **`v-for`の`:key`安定性** — `:key`にarray indexを使用していないか。`id`等の安定した識別子を使用（→ `references/code-examples.md`）
- [ ] **Floating Promises** — `async`関数を`await`も`void`もなしに呼び出していないか。意図的なfire-and-forgetは`void`を明示
- [ ] **Vue Router push() の戻り値確認** - router.push() を try/catch だけでハンドリングしていないか確認する。Vue Router 4.5.x では NavigationFailure はrejectではなくresolveで返るため、`result === undefined`（成功）または `isNavigationFailure(result)` による明示的判定が必要。try/catchのみではナビゲーションガードによる阻止を検出できない。
- [ ] **既存エラーパターンの無視** — 既存のエラーハンドリングパターン（共通のエラーハンドラ・AppError正規化等）を無視して独自実装を作っていないか。プロジェクトの既存パターンに従うこと
- [ ] **不要な条件分岐（フレームワーク自動処理）** — Vue/Axios等のフレームワークが自動的に処理する部分に不要な条件分岐を追加していないか。例: Axiosが自動的にundefinedフィールドをJSONから除外する場合の手動チェック
- [ ] **エッジケースの考慮** — 境界値・ゼロ・空文字・undefined・null等のエッジケースが考慮されているか。`<=` vs `<`の取り違え、off-by-oneエラー等に注意

---

## Extended Checklist

### Error Handling（詳細）

- **非対称なdisabled状態** — 同一フローで複数ボタンがある場合、ローディングガードが全ボタンに対称に付いているか（→ `references/code-examples.md`）
- **try-catch漏れ** — 非同期処理に適切なエラーハンドリングがあるか。エラーがサイレントに握りつぶされていないか
- **localStorage.getItem/setItemのtry-catch** — localStorage.getItem/setItemには必ずtry-catchを付ける。同一機能内で一部だけガードされている不整合がないか確認する。
- **entities/api層のmutationFnでAxiosError正規化** — `useMutation` の `mutationFn` が try/catch なしで httpClient を直接呼び出すと、AxiosError（"Request failed with status code 500" 等）がそのままページ層に伝播する。全 mutationFn に try/catch を入れ、`isAxiosError(error)` で判定後 `toAppError(error).message` で正規化してから throw すること
- **repositoryのcatchブロックでAxiosErrorを素通りさせない** — repository の catch で特定条件（メールエラー等）のみ変換し、残りを `throw error` で素通りさせていないか確認する。`throw error` が残っている場合は AxiosError を `toAppError` で変換してから throw すること
- **ユーザー向けエラーメッセージ** — エラー時にユーザーへの通知（toast等）が適切に行われているか
- **entities層のエラー文字列定数化** `[新観点 from PR#480]` — `throw new Error("...")` の生文字列をエラーコード定数経由に変更しているか確認。エラーパイプライン（コード化→意味付け→表示）を迂回してはならない
- **SSEバッファ残り処理** `[新観点 from PR#486]` — ReadableStreamのdone時にbufferに未処理データが残っていないかチェック。最後のチャンクが改行で終わらない場合にデータ欠落する。
- **配列の境界外アクセスパターン** `[新観点 from PR#569]` — `array[index]` がundefinedになるケースでサイレントに失敗する実装をチェック。配列要素の存在チェック時に「要素がまだ存在しないケース」も考慮しているか確認する。未存在時はcreate/pushすべきか検討。
- **try/catch スコープの肥大化** `[新観点 from PR#569]` — 複数の非同期操作が1つのtry/catchに入っていないかチェック。後続操作の失敗が先行操作の失敗として誤報告される。各操作のエラーハンドリングをスコープ分離する。
- **mutation エラー型の一貫性** `[新観点 from PR#571]` — 同一ファイル内のmutationでerror型（Error vs AppError）が混在していないかチェックする。normalizeAxiosErrorの適用漏れがあると、呼び出し側のisAppError判定が機能しなくなる。新規mutation追加時は既存パターンに合わせてAppError + normalizeAxiosErrorを使用する。

### Component & Composable Design

- **コンポーネントサイズ制限** — `<template>` 100行(soft)/140行(hard)、`<script setup>` 80行(soft)/120行(hard)、Props 7(soft)/10(hard)、Emits 5(soft)/8(hard)。Hard超過は🔴違反
- **Props/Emitsは型定義形式** — `defineProps({ title: String })`のランタイム宣言禁止。`defineProps<{ title: string }>()`の型定義形式を使用
- **v-model は defineModel()** — Vue 3.5の`defineModel()`を使用。`set`内で非同期副作用を行わない
- **useTemplateRef() 使用** — DOM参照は`useTemplateRef()`(Vue 3.5)を使用。`ref()`でのDOM参照禁止
- **render関数禁止** — `shared/ui/`のheadlessラッパーのみ例外で許可
- **Composable命名** — 通常: `useXxx`、Factory DI版: `createUseXxx`
- **Composable返り値のreadonly保護** — 可変stateを`readonly()`なしで直接公開しない
- **Composableサイズ制限** — 行数120(soft)/180(hard)、公開API数5(soft)/7(hard)
- **emit命名はkebab-case** — emit名はkebab-caseで統一
- **非同期イベントは親が制御** — 子コンポーネントは通知のみ、親がAPI呼び出し等の副作用を実行。子でasync副作用を直接実行しない
- **event bus禁止** — mitt/event bus原則禁止。`app/`層の外部イベントアダプタのみ例外
- **provide/inject使用条件** — 深い受け渡しなら`provide/inject`、アプリ横断なら`composable singleton`、浅いなら`props/emits`。InjectionKey<T>型安全必須

### Performance & Accessibility

- **v-if/v-for同一要素禁止** — `v-if`と`v-for`を同一要素に併用禁止
- **大量データのvirtual scrolling** — 200行超 or 2,000 DOMノード超でvirtual scrolling必須
- **computed内の副作用禁止** — computed内でAPI呼び出し・DOM操作・状態変更等の副作用を行わない
- **watchのonWatcherCleanup** — watch内の非同期処理で`onWatcherCleanup`によるabortを実装
- **route-level code splitting** — 全ページがlazy importされているか
- **a11y: label-input紐付け** — `<label>`と`<input>`を`for`/`id`で紐付け
- **a11y: キーボードナビゲーション** — Tab, Enter, Escape対応
- **a11y: モーダルにフォーカストラップ** — モーダルダイアログにフォーカストラップ実装
- **a11y: 画像にalt属性** — 画像に`alt`属性必須（装飾的な場合は`alt=""`）

### Vue.js Patterns（詳細）

- **非同期レースコンディション** — Composable内の非同期関数が連続呼び出しされた場合、古いレスポンスで状態が上書きされないか。requestIdガードパターンで対策（→ `references/code-examples.md`）
- **setTimeout/setInterval の cleanup 漏れ** — `setTimeout` を使う composable や SFC で、戻り値（timer ID）を変数に保存し `onBeforeUnmount` でクリアしているか確認する。`let timer: ReturnType<typeof setTimeout> | null = null` → `onBeforeUnmount(() => { if (timer) clearTimeout(timer) })`。再呼び出し前に `clearTimeout` がないと二重発火の原因にもなる
- **UIガードとビジネスロジックガードの一致** — UIレベルのガード（`isClickable` computed等）だけでなく、イベントハンドラのビジネスロジック層でも同じ制約を担保しているか
- **暗黙のtruthyチェック** — `if (value)`による暗黙チェックで`null`・`undefined`・空文字が意図通りに処理されるか
- **非同期propsに依存するローカルstateの整合性** `[新観点 from PR#472]` — propsの非同期データ（API結果等）に依存するローカルstateは、元データ変更時にstaleな値が残らないかwatchで同期する
- **ルートパラメータの正規表現制約** `[新観点 from PR#480]` — 数値IDルートパラメータに `:id(\\d+)` パターンを使用しているか確認。制約がないと非数値がNaNでコンポーネントに渡る
- **ローディング要素のアクセシビリティ** `[新観点 from PR#480]` — `v-if` で表示切替されるローディング要素に `role="status"` と `aria-live="polite"` があるか確認。スクリーンリーダー通知に必要
- **route.queryの数値バリデーション** `[新観点 from PR#486]` — route.query由来の値をNumber()変換する際に、NaN・負数・小数・Infinityが混入しないかチェック。Number.isIntegerと正数チェックを追加する。
- **composable refへのテンプレート直接代入禁止** `[新観点 from PR#486]` — composableが公開するrefにテンプレートから`.value =`で直接代入していないかチェック。メソッド経由で操作する。
- **CSS progressive enhancement フォールバック** `[新観点 from PR#496]` - 新しいCSSプロパティ（`word-break: auto-phrase`等）使用時に非対応ブラウザでのレイアウト崩れがないかチェックする。`@supports` クエリや代替プロパティでフォールバックを提供しているか確認する。
- **ドラッグ操作のviewport境界チェック** `[新観点 from PR#510]` — ドラッグ操作でDOM要素の位置を更新する場合、viewport境界を超えないようクランプ処理があるか確認する。EDGE_MARGINなどの定数を使い、画面外にパネルが出ないよう制約する。
- **mousedownイベントの左クリック限定** `[新観点 from PR#510]` — mousedownイベントハンドラではe.button === 0（左クリック）のガードを入れる。右クリック・中クリックでのドラッグ開始を防止する。
- **レスポンシブ時のリサイズUI非表示** `[新観点 from PR#510]` — レスポンシブ対応のmedia queryでサイズを固定する場合、リサイズ関連のUI要素（ハンドル等）も非表示にする。display: noneで操作不能にすること。
- **v-elseの防御的使用** `[新観点 from PR#528]` — union型の状態分岐で `v-else` を使う場合、将来の状態追加を考慮して `v-else-if` で明示的に条件を指定しているか確認する。`v-else` は未知の状態でもマッチしてしまう。
- **フォーム送信成功後の再送信防止** `[新観点 from PR#528]` — フォーム送信成功後にUI状態（ボタンdisabled等）を適切に制御し、再送信を防いでいるか確認する。成功メッセージ表示中に再送信可能な状態は意図しない二重処理を招く。
- **watch内のフォームリセット漏れ** `[新観点 from PR#536]` — watchでルートパラメータやトークン変更を監視する際、エラー状態だけでなくフォーム入力値（特にパスワード等の機密値）もリセットしているか確認する。
- **aria-disabled vs disabled の使い分け** `[新観点 from PR#555]` — disabled属性はフォーカスを奪うため、aria-describedby等のa11y情報が届かない。理由テキストを伝えたい場合はaria-disabledに切り替えてクリックガードを実装する。
- **Vue Transition + watch(flush:"post") でのフォーカスタイミング** `[新観点 from PR#497]` — Transition アニメーション中の watch コールバックでフォーカスを設定する場合、`nextTick + requestAnimationFrame` でラップしてレイアウト完了後に実行することを確認する。
- **モーダル/ダイアログのフォーカスフォールバック** `[新観点 from PR#497]` — フォーカス可能要素が存在しない場合（hideCloseButton=true + slot 内に focusable 要素なし）でもモーダルにフォーカスが当たるよう、コンテナに `tabindex="-1"` を付与してフォールバックフォーカスが設定されているか確認する。
- **watch の初期値対応（immediate または onMounted）** `[新観点 from PR#497]` — `watch(modelValue)` はデフォルトで変化時のみ動作するため、マウント時に既に `true` の場合はコールバックが実行されない。初期状態を考慮するなら `immediate: true` か `onMounted` でのフォールバック処理が必要か確認する。
- **フォーム入力watch漏れ** `[新観点 from PR#555]` - 新しい入力フィールドを追加したら、ruleFormErrorクリア用watchにも追加されているか確認する。watchの監視対象リストは全フォーム入力refを含む必要がある。
- **aria-disabled疑似クラス** `[新観点 from PR#555]` - aria-disabledに変更した場合、:hover/:focus等の疑似クラスが引き続き有効なため、無効状態のスタイルが正しく適用されるか確認する。`:not([aria-disabled='true']):hover`パターンを使用。
- **バックエンド正規化の一貫性** `[新観点 from PR#555]` - バックエンドで正規化するフィールド（trim等）はフロントエンドのビルダーでも同じ正規化を適用し、保存前後の一貫性を確保する。
- **テストバリエーション網羅** `[新観点 from PR#555]` - 新機能で複数バリエーション（digits/keyword等）がある場合、片方のみ深いテストで他方が浅いままだと回帰リスクがある。全バリエーションに同等のテストカバレッジを確保する。
- **async callback の未処理 Promise 拒否** `[新観点 from PR#571]` — 同期関数（BroadcastChannelのonmessage等）にasync callbackを渡す場合、内部のawaitが失敗した際の未処理Promise拒否を防ぐtry-catchがあるかチェックする。特にrouter.push等の失敗しうる非同期操作。
- **フォーム入力コンポーネントの aria-invalid 自動導出** `[新観点 from PR#571]` — errorMessage propがある入力コンポーネントでaria-invalidが自動連動しているかチェックする。呼び出し側の設定漏れを防ぐため、コンポーネント側でerrorMessageの有無からaria-invalidを自動導出すべき。
- **PageSkeleton show-title明示指定** `[新観点 from PR#539]` — PageSkeleton使用時に `:show-title` を省略しない。ページに既存タイトルがある場合は `:show-title="false"` を明示し、二重表示を防止する。
- **テンプレート表示分岐の隙間状態** `[新観点 from PR#571]` - 非同期状態フラグ（isReady, isRestoring, isParsing等）の全組み合わせで意図しないフォールスルーがないか確認する。v-if/v-else-if/v-else チェーンで初期化中の「隙間」状態が漏れると誤表示が発生する。条件を網羅的に列挙し、全状態パターンで正しい分岐に入ることを確認する。
- **v-forキー一意性** — v-for の :key がデータの特性上一意でない可能性のある値を使っていないか確認する。DOM再利用の不整合やレンダリングバグの原因になる。安定した一意キー（ID、index等）を使用する。
- **エラーメッセージの内部情報露出** — catchブロックでバックエンドの生エラーメッセージ（appError.details, appError.message）をユーザーに直接表示していないか確認する。内部情報が露出しセキュリティリスクになる。ユーザー向け定数メッセージにフォールバックする。
- **保存中の操作無効化** — 非同期処理（保存・送信）中に矛盾する操作（キャンセル・他のボタン）が有効なまま残っていないか確認する。二重送信や状態不整合の原因になる。:disabled="isSaving"等で無効化する。
- **モーダル確認後の遷移先整合性** — フローの文脈に合った遷移先が設定されているか確認する。異なるフローで同じモーダルを使用する場合に遷移先が不適切になる。navigateAfterConfirmパターンで遷移先を制御する。
- **非同期エラー握りつぶし検出** — `.catch(() => {})` でエラーを握りつぶす箇所がUI上でエラー状態を適切に処理しているか確認する。テンプレートの v-else 分岐がエラー状態を想定していない場合、ユーザーに誤解を与える。catch で握りつぶす前にエラー状態がUI上で適切にハンドルされるか確認すること。
- **async watch の onWatcherCleanup** — async watch コールバック内で非同期処理を行う場合、CODING_STANDARDS の MUST ルールに従い onWatcherCleanup で abort/cancel する。hasInitialized パターンが companyId 等の依存値の変更に対応しているか確認する。
- **watch immediate:true の oldValue 安全性** `[新観点 from PR#539]` — `watch(..., { immediate: true })` で `oldValue` を分割代入していないか確認。初回コールバックでは `oldValue` が `undefined` になるため、分割代入は TypeError を引き起こす。`oldValues?.[index]` またはガード付きアクセスを使用すること。
- **エラー識別子のハードコード禁止** `[新観点 from PR#590]` — UIレベルの重複チェック用IDも含め、文字列リテラルのエラー識別子は全て `as const` オブジェクトに定数化する。watcher内のローカル変数定義も対象。CODING_STANDARDS.md Section 10.3 MUST ルール。
- **querySelector null ガード** `[新観点 from PR#594]` — querySelector の結果が null になるケースで state がリセットされるか確認。DOM未描画時に stale value が残るバグを防ぐ。else ブランチでデフォルト値に戻す。
- **テーブルスペーサー行の colspan** `[新観点 from PR#594]` — 仮想スクロールのスペーサー `<tr>` で `<td>` が1個だけの場合、colspan でヘッダー/データ行のセル数と一致させているか確認。HTML テーブル仕様違反によるレイアウト崩れを防ぐ。
- **クリック要素のキーボード操作** `[新観点 from PR#594]` — `@click` を持つ非インタラクティブ要素（th, div等）に `tabindex="0"` + `@keydown.enter` + `@keydown.space.prevent` が付いているか確認。a11y要件。
- **hover/click 混在のインタラクション設計** `[新観点 from PR#606]` — クリックで開いた状態とモバイルモードを混同する設計は、デスクトップで hover が永久に無効化されるバグにつながる。状態フラグの意味（「何を表すか」）を明確にし、close 時にリセットすること。
- **position: fixed 要素のスクロール追従** `[新観点 from PR#606]` — Teleport + fixed ポジショニングでは、表示後のビューポート変化に対応する scroll/resize イベントリスナーが必要。tooltip/popover 実装時は必ずスクロール・リサイズ追従を確認すること。
- **インタラクティブ要素のセマンティクス** `[新観点 from PR#606]` — `<span tabindex="0">` ではなくネイティブ `<button>` を使う。WAI-ARIA tooltip パターンでは `aria-expanded` は不使用。アイコンのみのトリガーには `aria-label` を必ず付与すること。
- **バックエンドレスポンス形式の網羅性** `[新観点 from PR#519]` — エラーコード抽出関数が camelCase/snake_case 両方のフィールド名をカバーしているか確認する。バックエンドの `_serializer_error_response` と `ApiResponse._error_response` で形式が異なる場合がある。レスポンスの実際の形式をバックエンドコードで確認し、フロントのパーサーが全形式に対応していることを検証する。
- **UIの状態遷移パスの網羅確認** `[新観点 from PR#606]` — hover/click/close等の複合インタラクションで、全状態遷移パスが正しく動作するか確認する。特にhover表示中のクリック、click表示後のhover等、状態フラグの切り替えタイミングに注意。close時に全フラグがリセットされるか確認すること。
- **再試行フロー時のエラー通知クリア漏れ** `[新観点 from PR#519]` — try/catchでエラー通知を設定する操作において、成功パスや再試行開始時に既存のエラー通知がクリアされているか確認する。再試行可能な操作（削除・更新等）では、前回のエラーバナーが成功後も残り、成功モーダルと矛盾する表示になるバグを防ぐ。setPageNotice(null) やclearNotice()を成功パスの先頭に配置する。
- **エラーメッセージとバリデーション条件の整合性** `[新観点 from PR#614]` — 同じエラー定数を異なるバリデーション文脈で使い回していないか確認する。条件が「値が空」と「値の数が不正」では異なるメッセージが必要。セルフレビュー時に「この定数のメッセージ文言は、このバリデーション条件に対して正確か？」をチェックする。
- **novalidate と独自バリデーションの併用** `[新観点 from PR#616]` — form 要素に `required`/`type="email"` 等のネイティブ検証属性がある場合、独自バリデーションと競合しないか確認する。ネイティブ検証はテスト環境（jsdom）では動作しないためテストで見落としやすい。`novalidate` を付けて独自検証に一本化する。
- **v-for の key に index 使用禁止** `[新観点 from PR#616]` — CODING_STANDARDS.md で MUST ルール。ネストした v-for で親 ID と組み合わせる場合でも index は使わず、要素自体の値やIDを使う。
- **pages層での生Error.message表示禁止** `[新観点 from PR#491]` — pages層で `error.message` を直接UIに表示していないかチェック。4層パイプラインでは pages 層はカタログ定数のみ表示すべき。`toErrorMessage` のような汎用ヘルパーを pages 層で使うと生エラーがリークする。
