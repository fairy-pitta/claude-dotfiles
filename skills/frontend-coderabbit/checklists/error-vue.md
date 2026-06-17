# Frontend Review: Error Handling + Vue.js Patterns

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Error Handling `[エラー: 25回]`

- [ ] **エラー識別子・メッセージのハードコード禁止** — エラーコード・メッセージ・識別子を文字列リテラルで直書きせず、定数ファイル経由で参照する（規約 MUST）。`shared/lib/errors/` 共通・`entities/*/model/errors/` ドメイン固有。UIレベルの重複チェック用IDやwatcher内のローカル変数も対象。`throw new Error("...")` の生文字列もエラーコード定数化し、エラーパイプライン（コード化→意味付け→表示）を迂回しない（→ `references/code-examples.md`）
- [ ] **メッセージ定数の文字列連結前提を排除** — メッセージ定数が呼び出し側の前置/後置連結を前提とする場合（例: `"を削除します"` で始まる文字列）、テンプレート関数化（`(userName: string) => \`...\``）して自己完結させ、連結漏れによる文言崩れを防止する
- [ ] **エラーの握りつぶし・サイレント失敗の禁止** — 非同期処理に適切なエラーハンドリングがあり、エラーがサイレントに握りつぶされていないか。`.catch(() => {})` や `catch {}` で潰す箇所は、UI上でエラー状態が適切に処理され、本当にログ不要かを検討する（console.* 禁止、`shared/lib/logger` 経由で Sentry 送信）。テンプレートの v-else 等がエラー状態を想定しているか確認
- [ ] **AxiosError の正規化（層をまたぐ前に変換）** — repository / `useMutation` の `mutationFn` が try/catch なしで httpClient を直接呼ぶと AxiosError（"Request failed with status code 500" 等）がページ層へ素通りする。`isAxiosError(error)` 判定後に `toAppError`/`normalizeAxiosError` で正規化してから throw する。catch で一部条件のみ変換し残りを `throw error` で素通りさせない（→ `references/code-examples.md`）
- [ ] **ユーザー向けエラーメッセージへの内部情報露出禁止** — catch でバックエンドの生エラー（`appError.details`・`error.message` 等）をユーザーに直接表示しない（情報露出のセキュリティリスク）。pages 層はカタログ定数のみ表示する（4層パイプライン）。`toErrorMessage` のような汎用ヘルパーを pages 層で使うと生エラーがリークする。`isAppError(e) ? e.message : FALLBACK` パターンでも、バックエンドが返す具体的メッセージは適切にユーザーへ届ける（過度な汎用化で潰さない）
- [ ] **既存エラーパターンの踏襲** — 共通エラーハンドラ・AppError 正規化等の既存パターンを無視して独自実装を作らない。同一ファイル内で error 型（Error vs AppError）が混在しないよう、新規 mutation 追加時も既存パターンに合わせる

### Vue.js Patterns

- [ ] **`v-for` の `:key` 安定性** — `:key` に array index を使用しない。ネストした v-for で親 ID と組み合わせる場合でも index は使わず、`id` 等の安定した一意識別子を使用する。データ特性上一意でない値も DOM 再利用の不整合の原因になる（→ `references/code-examples.md`）
- [ ] **Floating Promises** — `async`関数を`await`も`void`もなしに呼び出していないか。意図的なfire-and-forgetは`void`を明示
- [ ] **同期関数に渡す async callback の未処理 Promise 拒否** — 同期関数（BroadcastChannel の onmessage、`v-for` で直接呼ぶコールバック等）に async callback を渡す場合、内部 await 失敗時の未処理 Promise 拒否を防ぐ try-catch を入れる。特に router.push 等の失敗しうる非同期操作
- [ ] **Vue Router push() の戻り値確認** — router.push() を try/catch だけでハンドリングしていないか。Vue Router 4.5.x では NavigationFailure は reject ではなく resolve で返るため、`result === undefined`（成功）または `isNavigationFailure(result)` による明示的判定が必要。try/catch のみではナビゲーションガードによる阻止を検出できない
- [ ] **エッジケース・暗黙の truthy チェック** — 境界値・ゼロ・空文字・undefined・null 等のエッジケースが考慮されているか。`<=` vs `<` の取り違え、off-by-one、`if (value)` の暗黙チェックで null・undefined・空文字が意図通り処理されるかに注意
- [ ] **二重送信・保存中の操作無効化** — 非同期処理（保存・送信）中に矛盾する操作（キャンセル・他ボタン）が有効なまま残らないよう `:disabled="isSaving"` 等で無効化する。同一フローで複数ボタンがある場合はローディングガードを全ボタンに対称に付ける。フォーム送信成功後も UI 状態（ボタン disabled 等）を制御し、成功メッセージ表示中の再送信を防ぐ
- [ ] **UIガードとビジネスロジックガードの一致** — UIレベルのガード（`isClickable` computed 等）だけでなく、イベントハンドラのビジネスロジック層でも同じ制約を担保しているか

---

## Extended Checklist

### Error Handling（詳細）

- **try/catch スコープの肥大化** — 複数の非同期操作を1つの try/catch に入れていないか。後続操作の失敗が先行操作の失敗として誤報告される。各操作のエラーハンドリングをスコープ分離する。分割した各 catch のエラーメッセージが対応するエラー種別を正しく反映しているかも検証する
- **localStorage の try-catch** — localStorage.getItem/setItem には必ず try-catch を付ける。同一機能内で一部だけガードされている不整合がないか確認する
- **SSEバッファ残り処理** — ReadableStream の done 時に buffer に未処理データが残っていないかチェック。最後のチャンクが改行で終わらない場合にデータ欠落する
- **配列の境界外アクセスパターン** — `array[index]` が undefined になるケースでサイレントに失敗する実装をチェック。「要素がまだ存在しないケース」も考慮し、未存在時は create/push すべきか検討する
- **再試行フロー時のエラー通知クリア漏れ** — 成功パスや再試行開始時に既存のエラー通知がクリアされているか確認する。前回のエラーバナーが成功後も残り成功モーダルと矛盾するバグを防ぐ。`setPageNotice(null)`/`clearNotice()` を成功パスの先頭に配置する
- **メッセージ定数の整合性** — (1) 同じエラー定数を異なるバリデーション文脈で使い回していないか（「値が空」と「値の数が不正」では異なるメッセージが必要。「この定数の文言はこの条件に対して正確か？」をチェック）。(2) `ERROR_CODES` に新定数を追加する際、`USER_ERROR_MESSAGES` と `ERROR_CODE_TO_STATUS` にも対応エントリを追加し3マップの整合性を確認する。(3) アイコン名や UI 要素名をメッセージ定数に含める場合、実際に使用しているコンポーネント（HeartIcon vs StarIcon 等）と照合する（乖離はユーザーへの誤案内になる）
- **バックエンドレスポンス形式の網羅性** — エラーコード抽出関数が camelCase/snake_case 両方のフィールド名をカバーしているか。バックエンドの `_serializer_error_response` と `ApiResponse._error_response` で形式が異なる場合がある。実際のレスポンス形式をバックエンドコードで確認し、パーサーが全形式に対応するか検証する
- **イベントファンアウトの例外隔離** — 複数コールバック呼び出し（`for...of` で直接呼ぶ等）で1件の例外が他を止めないか。try/catch による隔離がないと全体が止まる
- **不要な条件分岐（フレームワーク自動処理）** — Vue/Axios 等が自動処理する部分に不要な条件分岐を追加していないか。例: Axios が undefined フィールドを JSON から自動除外する場合の手動チェック

### Component & Composable Design

- **サイズ制限（コンポーネント / composable）** — コンポーネント: `<template>` 100行(soft)/140行(hard)、`<script setup>` 80行(soft)/120行(hard)、Props 7(soft)/10(hard)、Emits 5(soft)/8(hard)。Composable: 行数120(soft)/180(hard)、公開API数5(soft)/7(hard)。Hard超過は🔴違反
- **Vue 3.5 API / 宣言規約** — Props/Emits は型定義形式（`defineProps<{ title: string }>()`、ランタイム宣言 `defineProps({ title: String })` 禁止）。v-model は `defineModel()`（`set` 内で非同期副作用を行わない）。DOM 参照は `useTemplateRef()`（`ref()` での DOM 参照禁止）。render 関数禁止（`shared/ui/` の headless ラッパーのみ例外）
- **Composable 命名・公開API** — 通常 `useXxx`、Factory DI 版 `createUseXxx`、emit 名は kebab-case で統一。可変 state を `readonly()` なしで直接公開しない。テンプレートから公開 ref に `.value =` で直接代入せずメソッド経由で操作する
- **非同期イベントは親が制御** — 子コンポーネントは通知のみ、親が API 呼び出し等の副作用を実行。子で async 副作用を直接実行しない
- **event bus禁止** — mitt/event bus原則禁止。`app/`層の外部イベントアダプタのみ例外
- **provide/inject使用条件** — 深い受け渡しなら`provide/inject`、アプリ横断なら`composable singleton`、浅いなら`props/emits`。InjectionKey<T>型安全必須

### Performance & Accessibility

- **v-if/v-for同一要素禁止** — `v-if`と`v-for`を同一要素に併用禁止
- **大量データのvirtual scrolling** — 200行超 or 2,000 DOMノード超でvirtual scrolling必須
- **computed内の副作用禁止** — computed内でAPI呼び出し・DOM操作・状態変更等の副作用を行わない
- **route-level code splitting** — 全ページがlazy importされているか
- **a11y: label/input・alt・キーボード** — `<label>`と`<input>`を`for`/`id`で紐付け、画像に`alt`必須（装飾は`alt=""`）、Tab/Enter/Escape 対応。`@click` を持つ非インタラクティブ要素（th, div 等）には `tabindex="0"` + `@keydown.enter` + `@keydown.space.prevent` を付ける
- **a11y: インタラクティブ要素のセマンティクス** — `<span tabindex="0">` でなくネイティブ `<button>` を使う。アイコンのみトリガーには `aria-label` 必須。WAI-ARIA tooltip パターンでは `aria-expanded` 不使用
- **a11y: disabled vs aria-disabled の使い分け** — disabled 属性はフォーカスを奪い aria-describedby 等が届かない。理由テキストを伝えたい場合は aria-disabled に切り替えクリックガードを実装。aria-disabled では `:hover`/`:focus` 等の疑似クラスが有効なため、`:not([aria-disabled='true']):hover` パターンで無効状態スタイルを正しく適用する
- **a11y: フォーカストラップとフォールバック** — モーダルダイアログにフォーカストラップを実装。フォーカス可能要素が存在しない場合（hideCloseButton=true + slot 内に focusable なし）でもコンテナに `tabindex="-1"` を付与してフォールバックフォーカスを設定する
- **a11y: 動的要素のスクリーンリーダー通知** — `v-if` で表示切替するローディング要素に `role="status"` と `aria-live="polite"` を付ける。errorMessage prop を持つ入力コンポーネントは errorMessage の有無から `aria-invalid` を自動導出し、呼び出し側の設定漏れを防ぐ
- **Vue Transition + watch(flush:"post") でのフォーカスタイミング** — Transition アニメーション中の watch コールバックでフォーカスを設定する場合、`nextTick + requestAnimationFrame` でラップしてレイアウト完了後に実行する
- **CSS progressive enhancement フォールバック** — 新しい CSS プロパティ（`word-break: auto-phrase` 等）使用時、非対応ブラウザでのレイアウト崩れがないか。`@supports` クエリや代替プロパティでフォールバックを提供する
- **レスポンシブ時のリサイズUI非表示** — media query でサイズ固定する場合、リサイズ関連 UI（ハンドル等）も `display: none` で非表示にし操作不能にする
- **テーブルスペーサー行の colspan** — 仮想スクロールのスペーサー `<tr>` で `<td>` が1個だけの場合、colspan でヘッダー/データ行のセル数に一致させ、テーブル仕様違反によるレイアウト崩れを防ぐ

### Vue.js Patterns（詳細）

- **非同期レースコンディション** — Composable 内の非同期関数が連続呼び出しされた場合、古いレスポンスで状態が上書きされないか。requestId ガードパターンで対策（→ `references/code-examples.md`）
- **非同期 props に依存するローカル state の整合性** — props の非同期データ（API 結果等）に依存するローカル state は、元データ変更時に stale な値が残らないよう watch で同期する
- **タイマー/リスナーの cleanup 漏れ** — `setTimeout`/`setInterval` の戻り値（timer ID）を変数に保存し `onBeforeUnmount` でクリアする（再呼び出し前の `clearTimeout` 漏れは二重発火の原因）。Teleport + `position: fixed` の tooltip/popover は表示後のビューポート変化に対応する scroll/resize リスナーを必ず追加する
- **watch の初期値・immediate 対応** — `watch(modelValue)` は既定で変化時のみ動作するため、マウント時に既に `true` の場合はコールバックが実行されない。初期状態を考慮するなら `immediate: true` か `onMounted` フォールバックを検討。`immediate: true` 使用時は (1) `oldValue` の分割代入を避ける（初回は undefined で TypeError、`oldValues?.[index]` 等ガード付きアクセス）、(2) 初期値が空のケースを想定する（非同期到着するデータソースで空状態の先行実行が後続復元フローを破壊しうる）
- **watch immediate + once の組み合わせ禁止** — Vue 3.5 では `{ immediate: true, once: true }` で immediate の即時実行が「最初のコールバック実行」と数えられ watcher が停止する。非同期データ到着待ちの watch では `once: true` を使わず、条件を満たしたら手動停止する（`watchEffect` + `stop()` パターン等）
- **async watch の onWatcherCleanup** — async watch コールバック内で非同期処理を行う場合、`onWatcherCleanup` で abort/cancel する。hasInitialized パターンが companyId 等の依存値変更に対応しているか確認する
- **watch 監視対象の網羅性** — watch 内の条件分岐で参照する値（例: `props.rows.length`）が watch 対象に含まれているか（外部要因による値変化時に条件が再評価されないバグを防ぐ。if に書いた値は watch 対象かチェックする習慣をつける）。エラークリア用 watch（`ruleFormError` クリア等）の監視対象に全フォーム入力 ref が含まれるか（新規入力フィールド追加時の漏れを防ぐ）。ルートパラメータ/トークン変更を監視する watch では、エラー状態だけでなくフォーム入力値（特にパスワード等の機密値）もリセットする
- **状態の網羅性（表示分岐・遷移パス）** — (1) v-if/v-else-if/v-else チェーンで非同期状態フラグ（isReady, isRestoring, isParsing 等）の全組み合わせに意図しないフォールスルー・初期化中の「隙間」状態がないか。union 型の状態分岐では `v-else` でなく `v-else-if` で明示し未知状態がマッチしないようにする。(2) hover/click/close 等の複合インタラクションで全状態遷移パス（hover 表示中のクリック、click 表示後の hover 等）が正しく動作するか。状態フラグの意味を明確にし close 時に全フラグがリセットされるか確認する（クリックで開いた状態とモバイルモードを混同するとデスクトップで hover が永久無効になるバグにつながる）
- **v-model 双方向バインディングのイベント二重発火** — 内部から値を変更すると `@update:model-value` ハンドラーも呼ばれることを意識する。モーダルの閉じ操作経路が複数ある場合、各経路からのイベント発火が重複しないか検証する
- **モーダル確認後の遷移先整合性** — フローの文脈に合った遷移先か。異なるフローで同じモーダルを使う場合に遷移先が不適切になる。navigateAfterConfirm パターンで遷移先を制御する
- **ドラッグ操作の境界・入力ガード** — ドラッグで DOM 要素位置を更新する場合、viewport 境界を超えないよう EDGE_MARGIN 等の定数でクランプする。mousedown ハンドラでは `e.button === 0`（左クリック）ガードを入れ、右/中クリックでのドラッグ開始を防ぐ
- **querySelector null ガード** — querySelector の結果が null になるケースで state がリセットされるか。DOM 未描画時に stale value が残るバグを防ぐ。else ブランチでデフォルト値に戻す
- **ルートパラメータの数値バリデーション** — 数値 ID ルートパラメータに `:id(\\d+)` パターンを使用しているか（制約がないと非数値が NaN で渡る）。route.query 由来の値を Number() 変換する際は NaN・負数・小数・Infinity の混入を `Number.isInteger` と正数チェックで防ぐ
- **状態クリア関数の副作用順序** — シングルトンストアの `reset()` が永続化をトリガーする副作用を持つか。reset → clear の順序で、clear が後続の persist タイマーをキャンセルする設計にする
- **バックエンド正規化の一貫性** — バックエンドで正規化するフィールド（trim 等）はフロントのビルダーでも同じ正規化を適用し、保存前後の一貫性を確保する
- **novalidate と独自バリデーションの併用** — form 要素に `required`/`type="email"` 等のネイティブ検証属性がある場合、独自バリデーションと競合しないか。ネイティブ検証は jsdom で動作せずテストで見落としやすいため、`novalidate` を付けて独自検証に一本化する
- **PageSkeleton show-title 明示指定** — PageSkeleton 使用時に `:show-title` を省略しない。ページに既存タイトルがある場合は `:show-title="false"` を明示し二重表示を防止する
- **テストバリエーション網羅** — 複数バリエーション（digits/keyword 等）がある場合、片方のみ深いテストで他方が浅いと回帰リスクがある。全バリエーションに同等のテストカバレッジを確保する
