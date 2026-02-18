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

**FSD レイヤー依存違反 (1.5)**
- `features/` 内のファイルが `@features/` を import していないか（features 間依存禁止）
- `entities/` 内のファイルが `@features/` や `@pages/` を import していないか
- `shared/` 内のファイルが `@entities/`, `@features/`, `@pages/` を import していないか
- レガシーディレクトリ（`@/presentation/`, `@/application/`, `@/domain/`, `@/infrastructure/`）からの import がないか

**Cross-Slice 違反 (1.6)**
- `entities/` 間の cross-slice import が `import type` 以外で行われていないか
- `features/` 間の直接 import がないか（type-only 含め禁止）

**Public API パターン (1.4)**
- 外部スライスからの import が `index.ts` 経由でなく内部構造を直接参照していないか
  - 例: `@entities/user/api/userQueries` のように内部パスを直接 import している

**import 順序 (14.2)**
- 外部ライブラリ → @shared → @entities → @features → @pages → @app → 相対パスの順になっているか

**パスエイリアス (14.3)**
- 2階層以上の相対パス（`../../`）を使用していないか（FSD レイヤーは alias 必須）

**barrel export (14.1)**
- `index.ts` で `export *` による全公開をしていないか

---

### Category 2: 状態管理 & TanStack Query（Section 2, 3）

以下を検出する:

**状態管理 (2.1-2.5)**
- Pinia の `defineStore` が使用されていないか（SHOULD NOT）
- composable singleton で `readonly()` なしで ref を外部に公開していないか（MUST）
- `route.params.companyId` 以外で activeCompanyId を管理していないか

**TanStack Query (3.1-3.5)**
- QueryKey が文字列リテラル直書きになっていないか（Factory パターン必須）
- `queryFn` で `signal` を受け取っていないか（キャンセル対応必須）
- マスターデータの QueryKey に `['master', ...]` prefix がないケース
- QueryKey に `undefined` が含まれる可能性がないか（デフォルト値必須）
- `invalidateQueries` の使い方が適切か

---

### Category 3: コンポーネント & Composable 設計（Section 4, 5, 6, 11）

以下を検出する:

**コンポーネント (4.1-4.7)**
- `<script setup lang="ts">` でない Vue SFC がないか（Options API 禁止）
- Props/Emits にランタイム宣言（`defineProps({ title: String })` 形式）を使用していないか（型定義必須）
- `v-model` で `defineModel()` を使わず手動実装していないか
- render 関数を使用していないか（shared/ui 以外禁止）
- DOM 参照に `useTemplateRef()` でなく `ref()` を使っていないか

**サイズ制限 (4.2, 5.4)**
- `<template>` が 140 行超、`<script setup>` が 120 行超でないか（Hard 上限）
- Props が 10 個超、Emits が 8 個超でないか（Hard 上限）
- composable が 180 行超、公開 API が 7 個超でないか

**Composable (5.1-5.5)**
- composable が可変 state を `readonly()` なしで返していないか
- setup 同期フェーズ外（`await` 後）で composable を呼んでいないか

**provide / inject (6.1-6.3)**
- `InjectionKey<T>` なしで `provide/inject` を使っていないか（型安全性必須）

**イベントハンドリング (11.1-11.3)**
- emit 名が kebab-case でないケース
- 子コンポーネント内で async 副作用を直接実行していないか（親が制御すべき）
- mitt / event bus を使用していないか（原則禁止）

---

### Category 4: 型安全 & セキュリティ（Section 7, 12）

以下を検出する:

**型管理 (7.1-7.6)**
- `any` 型の使用がないか（MUST 禁止）
- `as unknown as T` の使用がないか（原則禁止）
- 手書きコードで `enum` を使用していないか（SHOULD NOT、コード生成は例外）
- `as const` を使わず enum を手書きしていないか

**セキュリティ (12)**
- `v-html` を使用していないか（sanitizeHtml 経由のみ例外）
- `VITE_*` 環境変数に秘密情報が含まれていないか
- API endpoint が文字列直書きになっていないか（定数/関数化必須）
- `console.log` / `console.error` / `console.warn` を直接使用していないか（logger 経由必須）

---

### Category 5: パフォーマンス & アクセシビリティ（Section 8, 16）

以下を検出する:

**パフォーマンス (8.1-8.4)**
- `v-for` に `:key` がない、または `index` を key に使っていないか
- `v-if` と `v-for` を同一要素に併用していないか
- `computed` 内で副作用（API コール、DOM 操作等）を行っていないか
- ページコンポーネントが route-level code splitting されているか（lazy import）

**アクセシビリティ (16)**
- `<label>` と `<input>` の `for`/`id` 紐付けが漏れていないか
- `<img>` に `alt` 属性がないケース
- モーダルコンポーネントにフォーカストラップがあるか
- キーボードナビゲーション（Tab, Enter, Escape）への対応漏れ

---

### Category 6: エラーハンドリング & 会計固有 & テスト & 命名（Section 9, 10, 13, 15）

以下を検出する:

**エラーハンドリング (10.1-10.6)**
- エラーメッセージが関数内にハードコードされていないか（カタログ定数経由必須）
- `console.log`/`console.error`/`console.warn` を直接使用していないか（logger 経由必須）
- AppError 4層パイプラインに沿っているか

**会計システム固有 (15.1-15.5)**
- 金額を `number` で直接演算していないか（Amount 型関数必須）
- 仕訳系 Mutation で楽観更新（optimistic update）を使っていないか（禁止）
- 物理削除 API を呼んでいないか（論理削除のみ）
- 丸めが明細単位で行われているか

**テスト (9.1-9.6)**
- `data-testid` が `scope-element-action` の kebab-case でないケース
- テストで `console.*` を直接使用していないか

**命名規約 (13.1-13.4)**
- Vue SFC ファイル名が PascalCase でないケース
- TypeScript ファイル名が camelCase でないケース
- ディレクトリ名が kebab-case でないケース
- 定数が UPPER_SNAKE_CASE でないケース
- composable 名が `use` + PascalCase でないケース

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
- 検出が曖昧な場合（例: shared/ui/ 内の render 関数は許可）は、例外条件を考慮して誤検知を避ける
- 対象外のファイル（`*.spec.ts`, `*.stories.ts`, `*.test.ts`）はテスト系ルールのみ適用し、本体コード向けルールは除外する
- `CODING_STANDARDS.md` の原文を正とし、解釈に迷ったら厳しい方（MUST 寄り）を採用する
