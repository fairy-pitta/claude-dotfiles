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
- [ ] **Vue Router push() の戻り値確認** `[新観点 from PR#461]` - router.push() を try/catch だけでハンドリングしていないか確認する。Vue Router 4.5.x では NavigationFailure はrejectではなくresolveで返るため、`result === undefined`（成功）または `isNavigationFailure(result)` による明示的判定が必要。try/catchのみではナビゲーションガードによる阻止を検出できない。

---

## Extended Checklist

### Error Handling（詳細）

- **非対称なdisabled状態** — 同一フローで複数ボタンがある場合、ローディングガードが全ボタンに対称に付いているか（→ `references/code-examples.md`）
- **try-catch漏れ** — 非同期処理に適切なエラーハンドリングがあるか。エラーがサイレントに握りつぶされていないか
- **localStorage.getItem/setItemのtry-catch** `[新観点 from PR#510]` — localStorage.getItem/setItemには必ずtry-catchを付ける。同一機能内で一部だけガードされている不整合がないか確認する。
- **entities/api層のmutationFnでAxiosError正規化** `[新観点 from PR#437]` — `useMutation` の `mutationFn` が try/catch なしで httpClient を直接呼び出すと、AxiosError（"Request failed with status code 500" 等）がそのままページ層に伝播する。全 mutationFn に try/catch を入れ、`isAxiosError(error)` で判定後 `toAppError(error).message` で正規化してから throw すること
- **repositoryのcatchブロックでAxiosErrorを素通りさせない** `[新観点 from PR#437]` — repository の catch で特定条件（メールエラー等）のみ変換し、残りを `throw error` で素通りさせていないか確認する。`throw error` が残っている場合は AxiosError を `toAppError` で変換してから throw すること
- **ユーザー向けエラーメッセージ** — エラー時にユーザーへの通知（toast等）が適切に行われているか
- **entities層のエラー文字列定数化** `[新観点 from PR#480]` — `throw new Error("...")` の生文字列をエラーコード定数経由に変更しているか確認。エラーパイプライン（コード化→意味付け→表示）を迂回してはならない
- **SSEバッファ残り処理** `[新観点 from PR#486]` — ReadableStreamのdone時にbufferに未処理データが残っていないかチェック。最後のチャンクが改行で終わらない場合にデータ欠落する。
- **配列の境界外アクセスパターン** `[新観点 from PR#569]` — `array[index]` がundefinedになるケースでサイレントに失敗する実装をチェック。配列要素の存在チェック時に「要素がまだ存在しないケース」も考慮しているか確認する。未存在時はcreate/pushすべきか検討。
- **try/catch スコープの肥大化** `[新観点 from PR#569]` — 複数の非同期操作が1つのtry/catchに入っていないかチェック。後続操作の失敗が先行操作の失敗として誤報告される。各操作のエラーハンドリングをスコープ分離する。
- **mutation エラー型の一貫性** `[新観点 from PR#571]` — 同一ファイル内のmutationでerror型（Error vs AppError）が混在していないかチェックする。normalizeAxiosErrorの適用漏れがあると、呼び出し側のisAppError判定が機能しなくなる。新規mutation追加時は既存パターンに合わせてAppError + normalizeAxiosErrorを使用する。

### Vue.js Patterns（詳細）

- **非同期レースコンディション** — Composable内の非同期関数が連続呼び出しされた場合、古いレスポンスで状態が上書きされないか。requestIdガードパターンで対策（→ `references/code-examples.md`）
- **setTimeout/setInterval の cleanup 漏れ** `[新観点 from PR#437]` — `setTimeout` を使う composable や SFC で、戻り値（timer ID）を変数に保存し `onBeforeUnmount` でクリアしているか確認する。`let timer: ReturnType<typeof setTimeout> | null = null` → `onBeforeUnmount(() => { if (timer) clearTimeout(timer) })`。再呼び出し前に `clearTimeout` がないと二重発火の原因にもなる
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
