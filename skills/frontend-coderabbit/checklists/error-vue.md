# Frontend Review: Error Handling + Vue.js Patterns

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Error Handling `[エラー: 25回]`

- [ ] **エラーメッセージ直書き禁止** — 文字列リテラルで直書きせず、カタログ定数経由（→ `references/code-examples.md`）

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
- **entities層のエラー文字列定数化** — `throw new Error("...")` の生文字列をエラーコード定数経由に変更しているか確認。エラーパイプライン（コード化→意味付け→表示）を迂回してはならない
- **SSEバッファ残り処理** — ReadableStreamのdone時にbufferに未処理データが残っていないかチェック。最後のチャンクが改行で終わらない場合にデータ欠落する。
- **配列の境界外アクセスパターン** — `array[index]` がundefinedになるケースでサイレントに失敗する実装をチェック。配列要素の存在チェック時に「要素がまだ存在しないケース」も考慮しているか確認する。未存在時はcreate/pushすべきか検討。
- **try/catch スコープの肥大化** — 複数の非同期操作が1つのtry/catchに入っていないかチェック。後続操作の失敗が先行操作の失敗として誤報告される。各操作のエラーハンドリングをスコープ分離する。

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
- **非同期propsに依存するローカルstateの整合性** — propsの非同期データ（API結果等）に依存するローカルstateは、元データ変更時にstaleな値が残らないかwatchで同期する
- **ルートパラメータの正規表現制約** — 数値IDルートパラメータに `:id(\\d+)` パターンを使用しているか確認。制約がないと非数値がNaNでコンポーネントに渡る
- **ローディング要素のアクセシビリティ** — `v-if` で表示切替されるローディング要素に `role="status"` と `aria-live="polite"` があるか確認。スクリーンリーダー通知に必要
- **route.queryの数値バリデーション** — route.query由来の値をNumber()変換する際に、NaN・負数・小数・Infinityが混入しないかチェック。Number.isIntegerと正数チェックを追加する。
- **composable refへのテンプレート直接代入禁止** — composableが公開するrefにテンプレートから`.value =`で直接代入していないかチェック。メソッド経由で操作する。
- **CSS progressive enhancement フォールバック** - 新しいCSSプロパティ（`word-break: auto-phrase`等）使用時に非対応ブラウザでのレイアウト崩れがないかチェックする。`@supports` クエリや代替プロパティでフォールバックを提供しているか確認する。
- **ドラッグ操作のviewport境界チェック** — ドラッグ操作でDOM要素の位置を更新する場合、viewport境界を超えないようクランプ処理があるか確認する。EDGE_MARGINなどの定数を使い、画面外にパネルが出ないよう制約する。
- **mousedownイベントの左クリック限定** — mousedownイベントハンドラではe.button === 0（左クリック）のガードを入れる。右クリック・中クリックでのドラッグ開始を防止する。
- **レスポンシブ時のリサイズUI非表示** — レスポンシブ対応のmedia queryでサイズを固定する場合、リサイズ関連のUI要素（ハンドル等）も非表示にする。display: noneで操作不能にすること。
- **v-elseの防御的使用** — union型の状態分岐で `v-else` を使う場合、将来の状態追加を考慮して `v-else-if` で明示的に条件を指定しているか確認する。`v-else` は未知の状態でもマッチしてしまう。
- **フォーム送信成功後の再送信防止** — フォーム送信成功後にUI状態（ボタンdisabled等）を適切に制御し、再送信を防いでいるか確認する。成功メッセージ表示中に再送信可能な状態は意図しない二重処理を招く。
- **watch内のフォームリセット漏れ** — watchでルートパラメータやトークン変更を監視する際、エラー状態だけでなくフォーム入力値（特にパスワード等の機密値）もリセットしているか確認する。
- **aria-disabled vs disabled の使い分け** — disabled属性はフォーカスを奪うため、aria-describedby等のa11y情報が届かない。理由テキストを伝えたい場合はaria-disabledに切り替えてクリックガードを実装する。
- **Vue Transition + watch(flush:"post") でのフォーカスタイミング** — Transition アニメーション中の watch コールバックでフォーカスを設定する場合、`nextTick + requestAnimationFrame` でラップしてレイアウト完了後に実行することを確認する。
- **モーダル/ダイアログのフォーカスフォールバック** — フォーカス可能要素が存在しない場合（hideCloseButton=true + slot 内に focusable 要素なし）でもモーダルにフォーカスが当たるよう、コンテナに `tabindex="-1"` を付与してフォールバックフォーカスが設定されているか確認する。
- **watch の初期値対応（immediate または onMounted）** — `watch(modelValue)` はデフォルトで変化時のみ動作するため、マウント時に既に `true` の場合はコールバックが実行されない。初期状態を考慮するなら `immediate: true` か `onMounted` でのフォールバック処理が必要か確認する。
- **フォーム入力watch漏れ** - 新しい入力フィールドを追加したら、ruleFormErrorクリア用watchにも追加されているか確認する。watchの監視対象リストは全フォーム入力refを含む必要がある。
- **aria-disabled疑似クラス** - aria-disabledに変更した場合、:hover/:focus等の疑似クラスが引き続き有効なため、無効状態のスタイルが正しく適用されるか確認する。`:not([aria-disabled='true']):hover`パターンを使用。
- **バックエンド正規化の一貫性** - バックエンドで正規化するフィールド（trim等）はフロントエンドのビルダーでも同じ正規化を適用し、保存前後の一貫性を確保する。
- **テストバリエーション網羅** - 新機能で複数バリエーション（digits/keyword等）がある場合、片方のみ深いテストで他方が浅いままだと回帰リスクがある。全バリエーションに同等のテストカバレッジを確保する。
- **v-forキー一意性** — v-for の :key がデータの特性上一意でない可能性のある値を使っていないか確認する。DOM再利用の不整合やレンダリングバグの原因になる。安定した一意キー（ID、index等）を使用する。
- **エラーメッセージの内部情報露出** — catchブロックでバックエンドの生エラーメッセージ（appError.details, appError.message）をユーザーに直接表示していないか確認する。内部情報が露出しセキュリティリスクになる。ユーザー向け定数メッセージにフォールバックする。
- **保存中の操作無効化** — 非同期処理（保存・送信）中に矛盾する操作（キャンセル・他のボタン）が有効なまま残っていないか確認する。二重送信や状態不整合の原因になる。:disabled="isSaving"等で無効化する。
- **モーダル確認後の遷移先整合性** — フローの文脈に合った遷移先が設定されているか確認する。異なるフローで同じモーダルを使用する場合に遷移先が不適切になる。navigateAfterConfirmパターンで遷移先を制御する。
- **非同期エラー握りつぶし検出** — `.catch(() => {})` でエラーを握りつぶす箇所がUI上でエラー状態を適切に処理しているか確認する。テンプレートの v-else 分岐がエラー状態を想定していない場合、ユーザーに誤解を与える。catch で握りつぶす前にエラー状態がUI上で適切にハンドルされるか確認すること。
- **async watch の onWatcherCleanup** — async watch コールバック内で非同期処理を行う場合、CODING_STANDARDS の MUST ルールに従い onWatcherCleanup で abort/cancel する。hasInitialized パターンが companyId 等の依存値の変更に対応しているか確認する。
