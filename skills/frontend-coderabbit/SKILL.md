---
name: frontend-coderabbit
description: Frontend専用 CodeRabbit-style code review - Vue 3 + TypeScript + FSD (Feature-Sliced Design) + TanStack Queryの観点で体系的・網羅的にレビュー。Djangoバックエンドは対象外。
---

# Frontend CodeRabbit Review

Vue 3 + TypeScript + FSD (Feature-Sliced Design)のフロントエンドコードをCodeRabbitスタイルで体系的にレビューする。

**Announce at start:** "I'm using the frontend-coderabbit skill to perform a comprehensive frontend code review."

**Data source:** 394 frontend inline comments from 33 PRs (recent 40 PRs analyzed)

**コード例示:** `references/code-examples.md` を参照

## Format & Severity

`references/review-format.md` を参照（Language, Comment Structure, Severity, Category Labels, Summary Template）。

## Review Personality

- Formal & systematic
- 重要度を必ず明記し、actionableな修正案（diffつき）を必ず提示
- ファイルパスと行番号を参照
- `<details>` collapsibleで修正案を展開

---

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^frontend/"
```

### 2. Core チェック（全PRで必ず実施）

変更ファイルを読んだ後、**Core Checklist** の全項目をチェックする。
見落としゼロを優先。ファイル数が多い場合でもCore観点は省略しない。

### 3. Extended チェック（変更内容に応じて実施）

変更内容がテスト・クエリ管理・セキュリティ等に関係する場合、
**Extended Checklist** の対応セクションをチェックする。

### 4. Generate Summary

`references/review-format.md` の Review Summary Template に従う。

---

## Core Checklist（全PRで必ずチェック）`[最頻出・最重要]`

### FSD Architecture `[最多頻出: FSD 21回, import 15回]`

- [ ] **index.ts（公開API）経由のimport必須** — 外部スライスの内部モジュールへの直接importは絶対NG。`@entities/company/api/companyApi` ではなく `@entities/company` 経由（→ `references/code-examples.md`）
- [ ] **features間の直接import禁止** — features間の直接import（型importも含む）は禁止。共有したい型・ロジックは`entities/`または`shared/`に昇格
- [ ] **依存方向** — `app → pages → features → entities → shared`（上位→下位のみ）。pages層はfeatures内部（`model/`, `lib/`等）を直接参照禁止
- [ ] **FSDエイリアス必須** — 相対パスではなく`@app/`, `@pages/`, `@features/`, `@entities/`, `@shared/`のエイリアスを使用

### Type Safety `[型: 40回 - 最多頻出]`

- [ ] **`any`型禁止** — `any`は禁止。`unknown`/`never`/ジェネリクス/型ガードで代替
- [ ] **`enum`禁止** — TypeScriptの`enum`は禁止。`const + as const + typeof`で代替（→ `references/code-examples.md`）
- [ ] **型アサーション原則禁止** — `as`キャスト・`!`(non-null assertion)は原則禁止。「必殺技」であり最終手段。`?? デフォルト値`/型ガード/`unknown`+narrowing/ジェネリクスで代替。`as unknown as X`は絶対NG。許容されるのはライブラリが型を提供していない等の回避不能なケースのみ
- [ ] **`console.*`禁止** — `console.log/warn/error`等は禁止。エラーは4層パイプライン経由
- [ ] **`<script setup lang="ts">`必須** — `lang="ts"`の省略禁止

### TanStack Vue Query

- [ ] **QueryKey Factoryパターン** — QueryKeyは必ずFactoryパターンで定義。マスターデータは`['master', ...]` prefix必須（→ `references/code-examples.md`）
- [ ] **Pinia非推奨** — サーバー状態をPiniaとTanStack Queryの両方で管理しない。サーバー状態はTanStack Queryに集約

### State Management

- [ ] **composable singletonのreadonly保護** — module-levelのrefをそのまま公開しない。`readonly()`でラップして外部から直接書き込まれないようにする（→ `references/code-examples.md`）

### Error Handling `[エラー: 25回]`

- [ ] **エラーメッセージ直書き禁止** — 文字列リテラルで直書きせず、カタログ定数経由（→ `references/code-examples.md`）

### Vue.js Patterns

- [ ] **`v-for`の`:key`安定性** — `:key`にarray indexを使用していないか。`id`等の安定した識別子を使用（→ `references/code-examples.md`）
- [ ] **Floating Promises** — `async`関数を`await`も`void`もなしに呼び出していないか。意図的なfire-and-forgetは`void`を明示
- [ ] **Vue Router push() の戻り値確認** `[新観点 from PR#461]` - router.push() を try/catch だけでハンドリングしていないか確認する。Vue Router 4.5.x では NavigationFailure はrejectではなくresolveで返るため、`result === undefined`（成功）または `isNavigationFailure(result)` による明示的判定が必要。try/catchのみではナビゲーションガードによる阻止を検出できない。

### Unused Code Detection

- [ ] **未使用の関数・composable・コンポーネント・import** — 呼び出されていない定義が残っていないか

### Syntax & Basic Quality

- [ ] **TypeScript構文エラー・型不一致**
- [ ] **マージコンフリクトマーカー** — `<<<<<<<`が残っていないか
- [ ] **SFCの構造** — `<template>` → `<script setup lang="ts">` → `<style scoped>`の順

---

## Extended Checklist（変更内容に応じてチェック）

### FSD Architecture（詳細）

- **entities間の`@x`パターン** — entities間は`import type`のみ許可。ランタイムimportは禁止
- **3+スライスから使用される機能の昇格** — 3スライス以上から参照されるコードは上位層に昇格必須
- **Composables→Repository IFを介さず実装に直結はNG** — ComposablesがhttpClient等に直結すると依存方向違反（→ `references/code-examples.md`）
- **UseCase/Application層のインフラライブラリ依存禁止** `[新観点 from PR#437]` — `entities/model/` 配下の UseCase に `import axios from "axios"` 等のインフラライブラリが含まれていないか確認する。Axios エラー変換はリポジトリ（Mutation/Infrastructure）層で行い、UseCase はドメインエラー（プロジェクト定義の Error サブクラス）のみを知るべき
- **Vue SFC からの型エクスポート禁止** `[新観点 from PR#437]` — `.vue` ファイルから `export type` するのは避け、`model/types.ts` 等の純粋な TypeScript ファイルに型を定義する。`index.ts` からは `.vue` ではなく `./model/types` を参照してエクスポートする

### Type Safety（詳細）

- **型アサーション`as`/`!`の残存チェック** — Core観点の原則禁止に加え、テストコードも含めて`as`/`!`が残っていないか確認。テストでは`?? []`/`?? ''`等のフォールバックで代替可能なケースが多い
- **金額にFloat演算禁止** — 金額に浮動小数点演算を直接使わない。`Amount`型（branded integer）経由
- **エンティティ型との型ドリフト防止** `[新観点 from PR#472]` — features層でentities層の型フィールドと一致するインライン型定義（例: `{ key: string; label: string }`）がないかチェックする。Pick/Omitで元のエンティティ型を参照すべき。インライン型はエンティティ型の変更に追従できずドリフトの原因になる

### TanStack Vue Query（詳細）

- **QueryKeyに`undefined`を渡さない** — キャッシュ汚染の原因。デフォルト値を設定
- **楽観的更新禁止（仕訳Mutation）** — 仕訳関連のMutationで楽観的更新は禁止。冪等キー必須
- **Mutation後のinvalidateQueries** — Mutationの`onSuccess`で関連QueryKeyを`invalidateQueries`しているか
- **invalidateQueries 後の重複 refetch** `[新観点 from PR#437]` — `onSuccess` で `invalidateQueries` が行われているのに、さらに手動で `await query.refetch()` を呼び出していないか。`invalidateQueries` だけで TanStack Query が自動再フェッチするため、追加の `refetch()` は二重更新になる
- **Promise.allSettled + AbortSignal チェック** `[新観点 from PR#437]` — `Promise.allSettled` はキャンセルシグナルを無視してすべて待つ。`signal` を渡している場合は `Promise.allSettled` の前後で `if (signal?.aborted) throw new DOMException("Aborted", "AbortError")` を入れているか確認する
- **フォールバックデータソースのローディング状態反映** `[新観点 from PR#472]` — context依存でデータソースが切り替わるcomposableで、フォールバック先のローディング状態も統合して返却しているか確認する

### State Management（詳細）

- **`computed`の使用** — テンプレート内の複雑な条件式は`computed`に切り出す
- **複数watcherの競合チェック** `[新観点 from PR#510]` — 複数のwatcherが同じrefを操作する場合、モード切替（ドックモード等）時の優先順位が正しいか確認する。後続watcherが前のwatcherの設定を上書きしないこと。
- **module-level singletonのページ遷移時リセット** `[新観点 from PR#510]` — module-level singleton（composable内のmodule-scope ref）の状態がページ遷移時に適切にリセットされるか確認する。onUnmountedでのクリーンアップを忘れないこと。
- **モジュールレベルキャッシュの認証境界ライフサイクル** `[新観点 from PR#523]` — メモリキャッシュ（module-level変数）を導入した際、ログアウト・セッション切れ・401/403エラー等の認証境界で適切にクリアされるかチェックする。キャッシュ追加時に無効化ポイントの洗い出しをセットで行わないと、古い値が残り続けてセキュリティ・機能バグになる。`invalidate`関数をexportし、認証境界で呼び出すこと

### Error Handling（詳細）

- **非対称なdisabled状態** — 同一フローで複数ボタンがある場合、ローディングガードが全ボタンに対称に付いているか（→ `references/code-examples.md`）
- **try-catch漏れ** — 非同期処理に適切なエラーハンドリングがあるか。エラーがサイレントに握りつぶされていないか
- **localStorage.getItem/setItemのtry-catch** `[新観点 from PR#510]` — localStorage.getItem/setItemには必ずtry-catchを付ける。同一機能内で一部だけガードされている不整合がないか確認する。
- **entities/api層のmutationFnでAxiosError正規化** `[新観点 from PR#437]` — `useMutation` の `mutationFn` が try/catch なしで httpClient を直接呼び出すと、AxiosError（"Request failed with status code 500" 等）がそのままページ層に伝播する。全 mutationFn に try/catch を入れ、`isAxiosError(error)` で判定後 `toAppError(error).message` で正規化してから throw すること
- **repositoryのcatchブロックでAxiosErrorを素通りさせない** `[新観点 from PR#437]` — repository の catch で特定条件（メールエラー等）のみ変換し、残りを `throw error` で素通りさせていないか確認する。`throw error` が残っている場合は AxiosError を `toAppError` で変換してから throw すること
- **ユーザー向けエラーメッセージ** — エラー時にユーザーへの通知（toast等）が適切に行われているか
- **entities層のエラー文字列定数化** `[新観点 from PR#480]` — `throw new Error("...")` の生文字列をエラーコード定数経由に変更しているか確認。エラーパイプライン（コード化→意味付け→表示）を迂回してはならない
- **SSEバッファ残り処理** `[新観点 from PR#486]` — ReadableStreamのdone時にbufferに未処理データが残っていないかチェック。最後のチャンクが改行で終わらない場合にデータ欠落する。

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

### Test Quality（テストファイルが変更されている場合）

- **MSW使用** — APIモックはMSWを使用しているか。`vi.fn()`の直接モック乱用は避ける
- **テスト期待値の文字列リテラル禁止** `[新観点 from PR#437]` — `rejects.toThrow('エラーメッセージ')` 等の期待値に文字列リテラルを直書きしていないか。定数（`MESSAGES.VALIDATION.X`等）を参照する。定数側の変更に追従できず、テストの意図も不明確になる
- **FormDataを使うmutationテスト** — `FormData`を使うMutationのテストでAxiosアダプターをNode.js httpに設定しているか（`axios.defaults.adapter = 'http'`）（→ `references/code-examples.md`）
- **型安全なモック** — モック関数に適切な型が付いているか
- **テストケースの網羅性** — ローディング・エラー・成功状態のそれぞれをカバーしているか
- **テストデータの独立性** — テスト間で共有される可変なオブジェクトがないか
- **モックハンドラのAPIバリデーション再現** `[新観点 from PR#472]` — MSWモックハンドラがAPIの必須パラメータ組み合わせバリデーションを正しく再現しているか確認する。片方のみ指定時のエラーレスポンス等
- **Playwright ルートのクエリパラメータ対応** `[新観点 from PR#480]` — APIリクエストにクエリパラメータが付く場合（例: `?page=1&page_size=50`）、glob パターン `'**/api/endpoint/'` はマッチしない。`page.route()` のパターンは正規表現 `/\/api\/endpoint\//` を使うこと。ページネーションパラメータ追加後は既存テストの route パターンを見直す
- **E2E/VRTテストのセレクタ安定性とモックレスポンス整合性** `[新観点 from PR#480]` — CSS クラスセレクタはスタイル変更で壊れやすい。コンポーネントに `data-testid` を追加し `page.getByTestId()` を使うこと。また MSW/Playwright モックのレスポンス形式はAPIの実際のレスポンス形式（ページネーションフィールド `count`/`page`/`page_size` 等）と一致させること
- **ソートテストの non-null assertion** `[新観点 from PR#480]` - ループ範囲が保証されているソート検証テストで `data?.[i+1].createdAt.getTime() ?? 0` のパターンは false positive のリスク。`expect(data!.length).toBeGreaterThanOrEqual(2)` を追加し `data![i]`/`data![i+1]` の non-null assertion を使う。
- **テストモック正規表現の厳密化** `[新観点 from PR#480]` — Playwrightの `page.route()` やMSWの正規表現パターンに `$` アンカーを付けているか確認。広すぎるパターンは将来エンドポイント追加時に衝突する

### Security（セキュリティ）

- **XSS対策** — `v-html`の使用時にサニタイズされているか。ユーザー入力を直接DOMに渡していないか
- **依存ライブラリの脆弱性** — 既知の脆弱性を持つライブラリ（例: `xlsx`）を使用していないか
- **機密情報のログ出力** — `console.*`等でAPIキー・トークン・パスワードを出力していないか
- **クロスオリジン環境でのCookie読み取り安全性** `[新観点 from PR#523]` — `document.cookie`は現在のoriginのCookieのみ返すため、APIが別originの場合にそのCookie値をCSRFトークンとして信頼してはいけない。Cookie読み取りにはAPI originと`window.location.origin`の一致チェックをセットで実装すること

### Code Organization & DRY（詳細）

- **DRY原則** — 同一・類似のロジックが複数コンポーネント/composableに存在しないか
- **コンポーネント分割** — 1コンポーネントが複数の責務を持ちすぎていないか
- **マジックストリング** — 複数ファイルで使われる文字列リテラルを共有定数化しているか（→ `references/code-examples.md`）
- **ゲッター関数の二重呼び出し** — `computed`内でゲッター関数を複数回呼び出していないか（→ `references/code-examples.md`）
- **computed内クロージャ生成** — `computed`スコープ内で関数オブジェクトを定義すると再評価のたびに再生成される。composable本体スコープに抽出（→ `references/code-examples.md`）
- **状態リセットの対称性** — ファイル削除・変更・差替等の全パスで関連状態が適切にリセットされているか
- **イベントハンドラの不要な再代入** — 高頻度イベントハンドラで状態が変化しない場合も毎回代入が走っていないか
- **`@pages/`エイリアスの使用** — pages層内では`@pages/`エイリアスを使用（相対パスは規約違反）
- **APIエンドポイント定数化** `[新観点 from PR#486]` — fetch/axiosのURL文字列が直書きされていないかチェック。定数として抽出してDRY原則を維持する。
- **dialog アクセシブル名の確認** `[新観点 from PR#497]` — `role="dialog"` または `role="alertdialog"` の要素が `aria-labelledby` か `aria-label` のいずれかを持つことを確認。両方 `undefined` の場合はスクリーンリーダーが認識できない。共通コンポーネントのデフォルト値設定が必要か確認する。
- **Vue Transition + watch(flush:"post") でのフォーカスタイミング** `[新観点 from PR#497]` — Transition アニメーション中の watch コールバックでフォーカスを設定する場合、`nextTick + requestAnimationFrame` でラップしてレイアウト完了後に実行することを確認する。
- **モーダル/ダイアログのフォーカスフォールバック** `[新観点 from PR#497]` — フォーカス可能要素が存在しない場合（hideCloseButton=true + slot 内に focusable 要素なし）でもモーダルにフォーカスが当たるよう、コンテナに `tabindex="-1"` を付与してフォールバックフォーカスが設定されているか確認する。
- **watch の初期値対応（immediate または onMounted）** `[新観点 from PR#497]` — `watch(modelValue)` はデフォルトで変化時のみ動作するため、マウント時に既に `true` の場合はコールバックが実行されない。初期状態を考慮するなら `immediate: true` か `onMounted` でのフォールバック処理が必要か確認する。

---

## Red Flags - Never Do This

- 重要度インジケーターを省略
- actionableな修正案なしにフィードバック
- Core Checklistの項目をスキップ
- FSD index.ts直接importを見逃す
- features間の直接importを見逃す
- `any`/`enum`/`console.*`/`as`/`!`の使用を見逃す
- composable stateのreadonly保護漏れを見逃す
- `v-for`のindex keyを見逃す
- Floating Promiseを見逃す
- コードdiffなしに修正案を提示
