---
name: frontend-architecture
description: フロントエンドコーディング規約（CODING_STANDARDS.md）の全項目を並列チェックし、違反があれば修正プランを作成する
---

# Frontend Architecture Check

フロントエンドの `CODING_STANDARDS.md` に定義された全17セクションのルールを並列でチェックし、違反があれば Plan Mode で修正プランを作成する。

**Announce at start:** "フロントエンドアーキテクチャチェックを開始します。CODING_STANDARDS.md の全ルールを並列で検証します。"

## 対象ファイルの決定

引数の有無で対象を切り替える:

- **引数なし**: `git diff --name-only origin/dev...HEAD` で変更ファイルを取得し、`frontend/src/` 配下の `.vue`, `.ts`, `.tsx` ファイルのみ対象
- **引数あり**: 指定されたディレクトリ or ファイルを対象（例: `frontend/src/features/auth/`）

```bash
# 変更ファイル取得
git diff --name-only origin/dev...HEAD -- 'frontend/src/**/*.vue' 'frontend/src/**/*.ts' 'frontend/src/**/*.tsx'
```

対象ファイルが0件の場合は「チェック対象のフロントエンドファイルがありません」と報告して終了。

## チェックカテゴリ（並列実行）

**MUST: 以下の7カテゴリを Task tool で並列に起動すること。**
各カテゴリは `subagent_type=Explore` で起動し、対象ファイルを読み取ってルール違反を検出する。

各サブエージェントへの共通指示:
- 対象ファイルを読み取り、該当するルールへの違反を検出せよ
- 違反が見つかった場合は `ファイルパス:行番号` と違反内容を返せ
- 違反がなければ「違反なし」と返せ
- コードの修正は行わず、検出のみ行え

---

### Category 1: FSD アーキテクチャ & レイヤー依存（Section 1, 14, 17）

以下を検出する:

**FSD レイヤー依存違反 (1.5) [MUST]**
- `features/` 内のファイルが `@features/` を import していないか（features 間依存禁止、type-only 含む）
- `entities/` 内のファイルが `@features/` や `@pages/` を import していないか
- `shared/` 内のファイルが `@entities/`, `@features/`, `@pages/` を import していないか
- レガシーディレクトリ（`@/presentation/`, `@/application/`, `@/domain/`, `@/infrastructure/`）からの import がないか

依存方向の許可表:

| from | 許可先 | 備考 |
|------|--------|------|
| `app` | `pages`, `features`, `entities`, `shared` | エントリポイント |
| `pages` | `features`, `entities`, `shared` | オーケストレーション層 |
| `features` | `entities`, `shared` | **features 間の依存は禁止** |
| `entities` | `shared` | `@x` type-only 例外あり |
| `shared` | `shared` | 自己参照のみ |

**UI 配置の判定フロー (1.2) [MUST]**
コンポーネントが正しい層に配置されているか、以下の短絡判定フローで確認:
1. 業務操作（承認・保存・アップロード等）を起こすか？ → Yes: `features/*/ui/`
2. 単一エンティティの表現（アバター・バッジ等）か？ → Yes: `entities/*/ui/`
3. 特定画面専用のレイアウト・構成か？ → Yes: `pages/*/`
4. 上記いずれでもない → `shared/ui/`

**shared 層の性質定義 (1.3) [MUST]**
- shared に配置されたコードがビジネスロジックを含んでいないか（会社・仕訳・ユーザーなどの概念を知らない）
- shared が他の FSD レイヤー（entities, features 等）に依存していないか
- **例外**: `shared/ui/` のデザインシステム基盤部品（`Button`, `Input`, `Modal` 等）は利用箇所数に関わらず shared に配置可

**Public API パターン (1.4) [MUST]**
- 外部スライスからの import が `index.ts` 経由でなく内部構造を直接参照していないか
  - 例: `@entities/user/api/userQueries` のように内部パスを直接 import している
- `index.ts` で `export *` による全公開をしていないか（公開 API のみ明示的に export すること）
- **例外**: 同一スライス内のテスト（`*.spec.ts`）・Storybook（`*.stories.ts`）は `index.ts` を経由せず相対パスで直接 import してよい

**Cross-Slice 違反 (1.6) [MUST]**
- `entities/` 間の cross-slice import が `@x` パターンのルールに従っているか:
  - `import type` 限定（実行時値のエクスポート禁止）
  - consumer 指名ファイル（`@x/<consumer名>.ts`）で管理
  - `index.ts` の公開 API とは別に管理
- `features/` 間の直接 import がないか（type-only 含め禁止）
  - 正しい解決策: ドメイン概念は `entities` に昇格させる

**features 間共有の昇格ルール (1.6.3) [MUST]**
- 3つ以上の consumer slice で必要になった関数・型が feature 内に残っていないか
- 1-2 consumer での共有:
  - 非業務ユーティリティ → 各 feature に重複実装してよい [SHOULD]
  - 業務ロジック（税計算、金額導出等）→ 重複は避ける。即座に entities に昇格を検討 [SHOULD NOT]
- カウント単位: 1 consumer = 1 slice、同一 slice 内の複数ファイルは1、`*.spec.ts`/`*.stories.ts` は対象外

**features 間依存の解決フロー (1.6.4) [MUST]**
features 間依存が発生した場合、以下で解決されているか:
1. 型の共有 → 業務概念: `entities/*/model/`、非業務: `shared/types/`
2. API キャッシュの共有 → `entities/*/api/` の QueryKey を共有し、pages で orchestrate
3. 関数・composable の共有 → 単一エンティティ帰属: `entities/*/lib/`、複数エンティティ調停: owner feature を新設、非業務: `shared/composables/` or `shared/lib/`
4. UI コンポーネントの共有 → エンティティ表現: `entities/*/ui/`、汎用: `shared/ui/`

**entities 昇格の境界（肥大化防止）(1.6.5) [MUST/MUST NOT]**
- entities に置けるのは**単一エンティティ中心**のロジックのみ（不変条件、導出値計算、正規化・変換）
- entities に置いてはいけないもの:
  - 画面遷移・route/query・UI 状態 → `features/*/` or `pages/*/`
  - 複数 feature をまたぐ業務フロー → `pages/*/`
  - 複数エンティティの調停ロジック → UI なしの policy feature を新設

**pages 層のオーケストレーション (1.7) [MUST]**
- 複数 features を跨ぐ連携が pages 層で行われているか
- features 同士が直接 import せず、pages が emits を受け取り route/query 経由で別 feature に伝播しているか
- 連携手段の優先度 [SHOULD]:
  1. Route params/query（URL に残すべき状態）
  2. TanStack Query cache（entities の QueryKey 経由）
  3. Props/emits（親子間の即時 UI 連携）
  4. provide/inject（深いツリーの局所文脈、最終手段）

**サブスライス内部設計 (1.8) [MUST]**
- 同一 feature 内のサブスライス間が `model/` または `lib/` を介して連携しているか
- サブスライス間の直接相互参照がないか
- 循環依存がないか（`import/no-cycle` で CI 検知）

**import 順序 (14.2) [MUST]**
- 外部ライブラリ → `@shared/` → `@entities/` → `@features/` → `@pages/` → `@app/` → 相対パスの順になっているか

**パスエイリアス (14.3) [MUST]**
- 2階層以上の相対パス（`../../`）を使用していないか（FSD レイヤーは alias 必須）

---

### Category 2: 状態管理 & TanStack Query（Section 2, 3）

以下を検出する:

**状態の 3 分類 (2.1) [MUST]**
- 状態が適切なカテゴリで管理されているか:
  - サーバー状態 → TanStack Query v5
  - クライアント状態（グローバル）→ composable singleton
  - ローカル UI 状態 → コンポーネント内 ref

**Pinia 不採用 (2.2) [SHOULD]**
- Pinia の `defineStore` が使用されていないか
- **例外**: 以下の3条件を**全て**満たす場合のみ導入を検討してよい:
  - 離れた複数ツリーから読み書きされる（3 箇所以上）
  - 状態遷移が複雑（アクション、ロールバック、派生状態が多い）
  - DevTools / プラグイン（永続化等）活用が必要

**Composable Singleton パターン (2.3) [MUST]**
- グローバルなクライアント状態が module-level ref + composable で管理されているか
- 外部に公開する ref が `readonly()` で保護されているか
- singleton の取得は setup 外でも可。副作用の開始は setup 内でのみ行うルールに従っているか

**Props バケツリレー防止 (2.4) [SHOULD]**
- 3階層以上の props 受け渡しがないか
- 解決手段の判定:
  1. 同一サブツリー内の共有 → provide/inject
  2. アプリ全体で横断的 → composable singleton
  3. それ以外 → props/emits で十分

**activeCompanyId (2.5) [MUST]**
- `route.params.companyId` を Single Source of Truth としているか
- localStorage は補助（初期リダイレクト用のみ）

**QueryKey Factory パターン (3.1) [MUST]**
- QueryKey が文字列リテラル直書きになっていないか（Factory パターン必須）
- QueryKey の形式: `['entity', 'action', params?]`

**キャッシュ戦略 (3.2) [MUST]**
- データの性質に応じた `staleTime` / `gcTime` が設定されているか:

| データ種別 | staleTime | gcTime |
|-----------|-----------|--------|
| デフォルト | 1 min | 5 min |
| マスターデータ（勘定科目・地域） | 24 h | 7 d |
| トランザクション（仕訳一覧） | 30 s - 2 min | 10 - 30 min |
| セッション情報 | 5 min | 30 min |
| リアルタイム | 0 - 5 s | 1 - 5 min |

- retry 戦略: 4xx はリトライしない（408/429 を除く）、5xx / ネットワークエラーは1回リトライ

**マスターデータの QueryKey prefix (3.2.1) [MUST]**
- マスターデータ（勘定科目・地域・業種など）の QueryKey に `['master', ...]` prefix が含まれているか
- `setQueryDefaults` の登録順序が generic → specific の順になっているか

**QueryKey のルール (3.2.2) [MUST]**
- QueryKey に含める値がシリアライズ可能か:
  - 許可: `string`, `number`, `boolean`, `null`, プレーンオブジェクト, 配列
  - 禁止: `Date`, クラスインスタンス, `function`, `undefined`, `Symbol`
- オプショナルな `params` にデフォルト値が設定されているか（`undefined` と `{}` でキャッシュが分離する問題を防止）

**enabled / queryKey のリアクティブルール (3.2.3) [MUST]**
- Query の依存パラメータが `queryKey` に含まれているか
- `enabled` は実行可否のゲートに限定されているか

**queryFn の signal 対応 (3.3) [MUST]**
- `queryFn` が `signal` を受け取りキャンセルに対応しているか

**Mutation パターン (3.4) [MUST]**
- `invalidateQueries` は prefix 一致をデフォルトとしているか
- exact 一致が必要な場合は明示されているか

**QueryClient シングルトン (3.5) [MUST]**
- アプリ全体で単一の QueryClient インスタンスを使用しているか

---

### Category 3: コンポーネント & Composable 設計（Section 4, 5, 6, 11）

以下を検出する:

**基本ルール (4.1) [MUST]**
- `<script setup lang="ts">` でない Vue SFC がないか（Options API 禁止）

**サイズ制限 (4.2) [MUST/SHOULD]**

| 対象 | Soft 上限 | Hard 上限 | 超過時 |
|------|-----------|-----------|--------|
| `<template>` 行数 | 100 | 140 | Soft超過: PR に分割理由1行必須 / Hard超過: 🔴 違反 |
| `<script setup>` 行数 | 80 | 120 | Soft超過: composable 抽出を検討 / Hard超過: 🔴 違反 |
| Props 数 | 7 | 10 | Soft超過: オブジェクト型に集約 or 分割検討 / Hard超過: 🔴 違反 |
| Emits 数 | 5 | 8 | Soft超過: イベント設計見直し / Hard超過: 🔴 違反 |

**Props / Emits (4.3) [MUST]**
- Props/Emits にランタイム宣言（`defineProps({ title: String })` 形式）を使用していないか
- 型定義（`defineProps<{ title: string }>()` 形式）を使用しているか

**v-model (4.4) [MUST]**
- `defineModel()` (Vue 3.5) を使用しているか
- `defineModel` の `set` 内で非同期副作用を行っていないか

**Slots (4.5) [MUST]**
- slot が表示カスタマイズ専用になっているか（業務ロジックを受けていないか）

**render 関数 (4.6) [MUST]**
- render 関数を使用していないか
- **例外**: `shared/ui/` の headless ラッパーのみ許可

**useTemplateRef (4.7) [MUST]**
- DOM 参照に `useTemplateRef()` (Vue 3.5) を使用しているか（`ref()` で DOM 参照していないか）

**Composable 命名 (5.1) [MUST]**
- 通常の composable: `useXxx`
- Factory DI 版: `createUseXxx`（依存注入が必要な場合のみ使用）

**Composable 返り値 (5.2) [MUST]**
- 可変 state を外部に `readonly()` なしで直接公開していないか
- 返り値パターン: `readonly(ref)` で保護、`computed` で派生値、command 関数で操作

**setup 同期フェーズルール (5.3) [MUST]**
- Vue ライフサイクル依存の composable が setup 同期フェーズでのみ呼ばれているか
- `await` の後で composable を呼んでいないか

**Composable サイズ制限 (5.4) [MUST/SHOULD]**

| 指標 | Soft | Hard |
|------|------|------|
| 行数 | 120 | 180 |
| 公開 API 数 | 5 | 7 |

**Factory + DI パターン (5.5) [SHOULD/SHOULD NOT]**
- 分岐ロジックが多く依存差し替えが必要な composable に適用されているか [SHOULD]
- 単純な TanStack Query ラッパーに適用されていないか [SHOULD NOT]（MSW で十分）

**provide / inject 使用条件 (6.1) [MUST]**
判定フロー:
1. 同一サブツリー内で深い受け渡しがあるか？ → No: props/emits で十分
2. 複数インスタンスを同時に持ちたいか？ → Yes: provide/inject
3. アプリ全体で横断的に共有するか？ → Yes: composable singleton → No: provide/inject

**InjectionKey (6.2) [MUST]**
- 型安全な `InjectionKey<T>` を使用しているか（文字列キーの直接使用禁止）

**必須 vs オプショナル inject (6.3)**
- 必須注入: 未 provide なら throw するパターンになっているか
- オプショナル注入: null 返却のパターンになっているか

**emit 命名 (11.1) [MUST]**
- emit 名が kebab-case で統一されているか

**非同期イベント (11.2) [MUST]**
- 子コンポーネントが「通知」のみで、親が「副作用実行」を制御しているか
- 子コンポーネント内で async 副作用（API コール等）を直接実行していないか
- 親が loading 制御（`saving` ref パターン等）を行っているか

**event bus (11.3) [MUST]**
- mitt / event bus を使用していないか（原則禁止）
- **例外**: `app/` 層で外部イベント（WebSocket, BroadcastChannel）を受けるアダプタのみ [MAY]

---

### Category 4: 型安全 & セキュリティ（Section 7, 12）

以下を検出する:

**基本型ルール (7.1) [MUST/SHOULD]**
- `any` 型の使用がないか [MUST]（外部入力は `unknown` で受けて絞り込む）
- `as unknown as T` の使用がないか [MUST]（原則禁止）
- 手書きコードで `enum` を使用していないか [SHOULD NOT]
  - **例外**: コード生成（OpenAPI 等）による `enum` は許容 [MAY]
- `type` をデフォルト使用しているか [SHOULD]
- `interface` は拡張前提の公開契約のみに使用しているか [SHOULD]

**型定義の配置 (7.2) [MUST]**

| 配置場所 | 内容 |
|----------|------|
| `entities/*/model/{entity}Types.ts` | ドメインモデル型（`User`, `Company`, `Journal`） |
| `entities/*/model/errors/` | ドメイン固有エラーコード・カタログ |
| `entities/*/api/{entity}Schema.ts` | API 入出力 Zod スキーマ |
| `entities/*/api/mapBackendError.ts` | バックエンドエラーコード変換 |
| `features/*/model/{feature}Schema.ts` | フォームバリデーション Zod スキーマ |
| `shared/types/` | 汎用型（`Paged<T>`, `AppError`, `ApiResult<T>`） |
| `shared/lib/errors/` | 共通エラーコード・カタログ |
| `shared/lib/validation/` | 共通プリミティブ Zod スキーマ |

**文字列リテラル Union と as const (7.3)**
- リテラル Union or `as const` オブジェクトを使用しているか
- 手書きの `enum` を使用していないか

**ジェネリック型 (7.4) [SHOULD]**
- 2箇所以上で再利用し、ドメイン非依存な場合のみジェネリック化しているか

**Zod による runtime validation (7.5) [MUST/SHOULD]**
- 認証・権限・金額などクリティカルなエンドポイントは本番でも Zod で検証しているか [MUST]
- 大量リスト系は開発時のみ検証 [SHOULD]
- 検証は API 層で1回だけ行い、UI 層に生データを持ち込んでいないか [MUST]

**型 assertion の許可範囲 (7.6) [MAY]**
- assertion は以下の場合のみ許可:
  - DOM API（`useTemplateRef<HTMLInputElement>`）
  - ライブラリ境界で runtime check 後の最小 assertion

**セキュリティ (12) [MUST]**

| ルール | 検出方法 |
|--------|----------|
| `v-html` 原則禁止（`sanitizeHtml()` 経由のみ例外） | テンプレート内の `v-html` を検索 |
| CSRF トークンは unsafe method (`POST/PUT/PATCH/DELETE`) のみ自動付与 | httpClient のインターセプター実装を確認 |
| `VITE_*` に秘密情報を置かない（公開情報のみ） | `.env*` ファイルの内容を確認 |
| API endpoint は定数 / 関数化（文字列直書き禁止） | `api.get('/api/...` のような直書きを検索 |
| Open Redirect 対策（遷移先 URL のホワイトリスト） | `window.location`, `router.push` の遷移先を確認 |
| アップロード時の MIME / type / size チェック | ファイルアップロード処理を確認 |
| PII（個人識別情報）のログ出力禁止 | logger 呼び出しの引数を確認 |
| `console.log`/`console.error`/`console.warn` 直接使用禁止 | `console.` を検索（`shared/lib/logger.ts` 経由必須） |
| セッション Cookie: `Secure` + `HttpOnly` + `SameSite` | バックエンド責務だがフロント設定に矛盾がないか確認 |

---

### Category 5: パフォーマンス & アクセシビリティ（Section 8, 16）

以下を検出する:

**テンプレート (8.1) [MUST/SHOULD]**
- `v-for` に一意な安定 `:key` 必須、`index` を key に使用していないか [MUST]
- `v-if` と `v-for` を同一要素に併用していないか [MUST]
- `v-once` で静的コンテンツの再描画を防止しているか [SHOULD]

**大量データ表示 (8.2) [MUST/SHOULD]**
- 行リスト > 200行 or DOM ノード > 2,000 の場合に virtual scrolling を使用しているか [MUST]
- マトリクス rows × cols > 10,000 の場合に行・列両方の仮想化をしているか [MUST]
- 大規模テーブルの行に `v-memo` で再描画最適化をしているか [SHOULD]

**リアクティビティ最適化 (8.3) [MUST/SHOULD]**
- `computed` 内で副作用（API コール、DOM 操作、状態変更等）を行っていないか [MUST]
- watch 内の非同期処理で `onWatcherCleanup` による abort をしているか [MUST]
- 100件超の配列・深いオブジェクトに `shallowRef` / `shallowReactive` を使用しているか [SHOULD]
- マスターデータ（更新しない参照データ）に `markRaw` を使用しているか [SHOULD]
- `watch` の `immediate` は必要時のみ使用しているか（デフォルトは lazy）[SHOULD]

**コード分割 (8.4) [MUST/SHOULD]**
- 全ページが route-level code splitting されているか（lazy import）[MUST]
- 初期表示不要かつ重い UI に `defineAsyncComponent` を使用しているか [SHOULD]
  - `timeout: 15000`, `suspensible: true` の設定
- `manualChunks` で vendor 分離（vue/vue-router, @tanstack/vue-query 等）しているか [SHOULD]
- バンドル予算: 初期 JS gzip 250 KB 以内 [SHOULD]

**アクセシビリティ (16) [MUST/SHOULD]**

| ルール | 強度 |
|--------|------|
| `<label>` と `<input>` を `for` / `id` で紐付け | MUST |
| `<table>` に `scope` 属性 | SHOULD |
| キーボードナビゲーション対応（Tab, Enter, Escape） | MUST |
| 動的コンテンツに `aria-live` | SHOULD |
| モーダルにフォーカストラップ | MUST |
| 画像に `alt` 属性（装飾的な場合は空文字 `alt=""`） | MUST |
| テスト: role / text 優先、data-testid は補助 | SHOULD |

---

### Category 6: エラーハンドリング & 会計固有 & テスト & 命名（Section 9, 10, 13, 15）

以下を検出する:

**エラーハンドリング 4層パイプライン (10.1) [MUST]**
各層の責務が守られているか:

| レイヤー | 責務 | 例 |
|----------|------|-----|
| `shared/api` | Axios 例外を `AppError` に正規化 | `normalizeAxiosError()` |
| `entities` | API エラーをドメイン意味に変換 | `toUserDomainError()` |
| `features` | リトライ / ロールバック制御 | optimistic update rollback |
| `pages/app` | Toast / Dialog / エラーページ表示 | `AppErrorBoundary.vue` |

**AppError 型 (10.2) [MUST]**
- `AppError` 型が `kind`, `code`, `message`, `messageKey?`, `status?`, `retryable`, `cause?`, `details?` を持っているか
- `AppErrorKind` が `'network' | 'http' | 'auth' | 'validation' | 'domain' | 'unknown'` の6種類か

**エラー定数管理 (10.3) [MUST]**
- エラーメッセージが関数内にハードコードされていないか（カタログ定数経由必須）
- エラー定数のファイル配置が正しいか:
  - `shared/lib/errors/` - HTTP層・インフラ共通のエラー
  - `entities/*/model/errors/` - ドメイン固有のビジネスエラー
  - `entities/*/api/` - バックエンドコード → フロントコードの変換
  - `features/*/model/errors/` - 操作フロー固有のエラー
- エラーコードが `as const` オブジェクトで定義され、`SCOPE.ERROR_NAME` 形式の命名か [MUST]
- エラーカタログが `catalog.ts` に `messageKey` + `defaultMessage` + `retryable` を持つ形式で定義されているか [MUST]
- バックエンドエラーコードのマッピングが `entities/*/api/mapBackendError.ts` に配置されているか [MUST]
- 未知のバックエンドコードが `COMMON.UNKNOWN` にフォールバックしているか [MUST]

**正規化関数 (10.4) [MUST]**
- `normalizeAxiosError()` がカタログから `message` / `retryable` を取得しているか（ハードコード禁止）
- ステータスコードごとの分岐（401→auth, 403→auth, 422→validation 等）が適切か

**グローバルエラーバウンダリの表示方針 (10.5) [MUST]**
- `retryable = true` → toast
- `retryable = false` → dialog + fallback UI

**ログ (10.6) [MUST]**
- `console.log` / `console.error` / `console.warn` を直接使用していないか
- `shared/lib/logger.ts` 経由でのみ出力しているか

**会計 - 金額型 (15.1) [MUST]**
- 金額を `number` で直接演算（`+ - * /`）していないか（Amount 型関数必須）
- Amount 型が Branded type（`number & { readonly __brand: 'Amount' }`）として実装されているか
- `createAmount()` / `parseAmount()` / `addAmounts()` / `subtractAmounts()` / `multiplyAmount()` の関数経由で演算しているか
- 丸めルール（四捨五入 / 切上げ / 切捨て）が税計算含めて統一されているか

**会計 - 丸めタイミング (15.1.1) [MUST]**
- 丸めが明細単位で行われているか（伝票単位の一括丸め禁止）
- 正: 各明細で丸め済みの値を合計
- 誤: 合計後に丸め

**会計 - 日付規約 (15.2) [MUST]**
- `timestamp(UTC)` と `businessDate(会計日付)` を分離して扱っているか
- 会計日付が `YYYY-MM` 形式か（決算月は `YYYY-13`）

**会計 - 仕訳系 Mutation (15.3) [MUST]**
- 楽観更新 (optimistic update) を使用していないか（禁止）
- 冪等キー (idempotency key) が含まれているか（`Idempotency-Key: crypto.randomUUID()` ヘッダー）
- 二重送信防止が UI 側（`submitting` ref）+ API 側（idempotency key）の両方で実装されているか

**会計 - 監査証跡 (15.4) [MUST]**
- フロントエンドからの削除リクエストが論理削除のみか（物理削除 API を呼んでいないか）

**会計 - 締め処理 (15.5) [MUST]**
- 月次 / 年度締め後のデータ変更を UI で禁止しているか
- `JournalPeriodStatus` 型（`'open' | 'closed' | 'locked'`）に基づく制御があるか

**テスト 4分類 (9.1)**

| 分類 | 環境 | ファイル名 |
|------|------|-----------|
| 純関数 | Vitest (jsdom) | `*.spec.ts` |
| Composable | Vitest (jsdom) + MSW | `*.spec.ts` |
| VRT | Playwright (Docker) | `tests/visual/*.spec.ts` |
| E2E | Playwright | `tests/e2e/*.spec.ts` |

**テスト命名規約 (9.2)**
- `describe`: 対象 + 条件
- `it`: 期待結果を現在形で記述

**テストヘルパー (9.3) [MUST]**
- 共通ヘルパーが `tests/helpers/` に集約されているか
- `createTestQueryClient()` / `mountWithQuery()` の共通関数を使用しているか

**MSW ハンドラー (9.4) [MUST]**
- ドメイン別にハンドラーが分離されているか
- `setupServer` / `resetHandlers` のセットアップが正しいか

**カバレッジ目標 (9.5) [MUST/SHOULD]**

| レイヤー | Lines | Branches | 強度 |
|----------|-------|----------|------|
| `shared/` | 90% | 85% | MUST |
| `entities/` | 80% | 75% | MUST |
| `features/` | 70% | 65% | SHOULD |
| `pages/` | 50% | 40% | SHOULD（E2E で補完） |

- diff coverage 80% 以上 [SHOULD]

**data-testid (9.6) [MUST/SHOULD]**
- セレクタ優先順位: role/text > data-testid [SHOULD]
- `data-testid` が `scope-element-action` の kebab-case か [MUST]

**命名規約 (13.1-13.4)**

| 種類 | 規約 | 例 |
|------|------|-----|
| Vue SFC ファイル名 | PascalCase | `LoginPage.vue` |
| TypeScript ファイル名 | camelCase | `userKeys.ts` |
| ディレクトリ名 | kebab-case | `journal-upload/` |
| テストファイル | `*.spec.ts` | `userApi.spec.ts` |
| 変数 / 関数 | camelCase | `fetchUser` |
| 型 / interface | PascalCase | `User` |
| 定数 | UPPER_SNAKE_CASE | `MAX_FILE_SIZE` |
| Composable | `use` + PascalCase | `useCurrentUser` |
| InjectionKey | camelCase + `Key` | `invoiceContextKey` |
| CSS class | kebab-case | `form-input` |
| QueryKey | Factory 経由 `['entity', 'action', params?]` | `companyKeys.detail(id)` |
| data-testid | `scope-element-action` kebab-case | `login-form-submit` |

---

### Category 7: デッドコード & 後方互換残骸検出

変更ファイルおよびその周辺（同一スライス内）を対象に、不要なコードの残存を検出する。

**IMPORTANT: 後方互換ハックは禁止。不要になったコードは完全に削除すること。**

**未使用エクスポート・関数・変数**
- 対象ファイルから export されているが、プロジェクト内のどこからも import されていない関数・型・定数がないか
- ファイル内で定義されているが一度も参照されていないローカル変数・関数がないか
- `index.ts` で re-export しているが、その先のシンボルがどこからも使われていないケース

**未使用コンポーネント**
- 定義された Vue コンポーネントがどのテンプレートからも使用されていないか
- `import` されているが `<template>` 内で使われていないコンポーネント

**後方互換の残骸（禁止）**
- リネームされた未使用変数（`_oldName`, `_deprecated` 等のアンダースコア付き変数）が残っていないか
- 型の re-export だけを目的としたファイル（旧パスからの移行用 shim）が残っていないか
- `// removed`, `// deprecated`, `// legacy`, `// TODO: remove` 等のコメントと共に放置されたコードがないか
- 古い関数名を新しい関数に委譲しているだけのラッパー関数（互換用）が残っていないか

**修正時の残骸**
- 条件分岐の片方が到達不能（常に true/false）になっているデッドブランチがないか
- コメントアウトされたコードブロックが放置されていないか
- 使われなくなった QueryKey, エラーコード定数, 型定義がそのまま残っていないか
- 削除された機能に紐づく MSW ハンドラー、テストヘルパー、モックデータが残っていないか

**連鎖的デッドコード**
- ある関数が未使用で、その関数内でのみ使われていたヘルパー・型・定数も連鎖的に未使用になっていないか
- 削除された export に依存していた `index.ts` のエントリが残っていないか

**検出方法:**
- 対象ファイルの export シンボルを一覧化し、`Grep` で import 元を検索して使用箇所がゼロのものを検出
- コメントアウトされたコード（連続3行以上のコメント内コード）をパターン検索
- `_` prefix 付きの未使用変数をパターン検索
- `// deprecated`, `// removed`, `// legacy`, `// TODO: remove`, `// FIXME: remove` 等のコメントを検索

---

## 結果の集約 & レポート出力

全カテゴリの結果を受け取った後、以下のフォーマットで報告する。

### 違反の重大度分類

| レベル | 対象 | 説明 |
|--------|------|------|
| 🔴 **MUST 違反** | MUST ルールへの違反 | マージ前に必ず修正 |
| 🟠 **SHOULD 違反** | SHOULD / SHOULD NOT ルールへの違反 | 修正推奨 |
| 🟡 **サイズ超過（Soft）** | Soft 上限超過 | PR に理由記載必須 |
| 🔵 **MAY / 改善提案** | MAY ルール、ベストプラクティス | 任意 |

### レポートフォーマット

```markdown
# Frontend Architecture Check Report

**チェック対象ファイル数:** <N>
**検出された違反数:** <N>

## 違反サマリー

| カテゴリ | 🔴 MUST | 🟠 SHOULD | 🟡 Soft | 🔵 MAY | 計 |
|----------|---------|-----------|---------|--------|-----|
| FSD アーキテクチャ | <N> | <N> | <N> | <N> | <N> |
| 状態管理 & Query | <N> | <N> | <N> | <N> | <N> |
| コンポーネント設計 | <N> | <N> | <N> | <N> | <N> |
| 型安全 & セキュリティ | <N> | <N> | <N> | <N> | <N> |
| パフォーマンス & a11y | <N> | <N> | <N> | <N> | <N> |
| エラー & 命名 & 会計 | <N> | <N> | <N> | <N> | <N> |
| デッドコード & 残骸 | <N> | <N> | <N> | <N> | <N> |
| **合計** | **<N>** | **<N>** | **<N>** | **<N>** | **<N>** |

## 違反詳細

### 🔴 MUST 違反（マージ前に修正必須）

#### 1. <違反タイトル>
- **ファイル:** `<file_path>:<line_number>`
- **ルール:** Section <N>.<N> - <ルール名>
- **内容:** <違反の説明>
- **修正案:**
```diff
<修正前後の diff>
```

...（以下、違反ごとに繰り返し）

### 🟠 SHOULD 違反（修正推奨）

...

### 🟡 Soft 上限超過

...

### 🔵 MAY / 改善提案

...

## 判定

- 🔴 MUST 違反が **0件** → ✅ **PASS** - マージ可能
- 🔴 MUST 違反が **1件以上** → ❌ **FAIL** - 修正が必要
```

## 修正プランの作成（Plan Mode）

**MUST: 🔴 MUST 違反が 1件以上ある場合、レポート出力後に Plan Mode に入り修正プランを作成すること。**

### Plan Mode への遷移条件

| 条件 | アクション |
|------|-----------|
| 🔴 MUST 違反 1件以上 | Plan Mode に入り修正プランを作成 |
| 🔴 MUST 違反 0件、🟠 SHOULD 違反あり | レポートのみ出力し「SHOULD 違反の修正プランを作成しますか？」とユーザーに確認 |
| 違反 0件 | ✅ PASS を報告して終了 |

### 修正プランの内容

`EnterPlanMode` ツールで Plan Mode に入り、以下の構成でプランを作成する:

1. **修正対象の優先順位付け** - 🔴 Critical → 🟠 Major の順
2. **ファイルごとの修正手順** - 各ファイルで何をどう変更するか具体的に記述
3. **依存関係の考慮** - 修正 A を先にしないと修正 B ができない等の順序
4. **影響範囲の確認** - 修正によって他のファイルに波及する変更があるか
5. **検証手順** - 修正後に実行すべきコマンド（lint, type-check, test）

プランが承認されたら、プランに従ってコードを修正する。

## 重要な注意事項

- 検出フェーズではコードの修正は行わない（検出と報告のみ）
- 修正はプラン承認後に実施する
- 検出が曖昧な場合は、例外条件を考慮して誤検知を避ける。主な例外:
  - `shared/ui/` のデザインシステム基盤部品は shared に配置可 (1.3)
  - 同一スライス内のテスト・Storybook は `index.ts` 経由不要 (1.4)
  - `@x` パターンでの entities 間 `import type` は許可 (1.6.1)
  - Pinia は3条件全て満たす場合のみ導入検討可 (2.2)
  - コード生成による `enum` は許容 (7.1)
  - `shared/ui/` の headless ラッパーのみ render 関数許可 (4.6)
  - `app/` 層の外部イベントアダプタのみ event bus 許可 (11.3)
  - DOM API / ライブラリ境界での最小 assertion は許可 (7.6)
- 対象外のファイル（`*.spec.ts`, `*.stories.ts`, `*.test.ts`）はテスト系ルールのみ適用し、本体コード向けルールは除外する
- `CODING_STANDARDS.md` の原文を正とし、解釈に迷ったら厳しい方（MUST 寄り）を採用する
