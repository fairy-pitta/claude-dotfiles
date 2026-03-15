# Frontend Review: FSD Architecture + Code Organization + Unused Code + Syntax

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### FSD Architecture `[最多頻出: FSD 21回, import 15回]`

- [ ] **index.ts（公開API）経由のimport必須** — 外部スライスの内部モジュールへの直接importは絶対NG。`@entities/company/api/companyApi` ではなく `@entities/company` 経由（→ `references/code-examples.md`）
- [ ] **features間の直接import禁止** — features間の直接import（型importも含む）は禁止。共有したい型・ロジックは`entities/`または`shared/`に昇格
- [ ] **依存方向** — `app → pages → features → entities → shared`（上位→下位のみ）。pages層はfeatures内部（`model/`, `lib/`等）を直接参照禁止
- [ ] **FSDエイリアス必須** — 相対パスではなく`@app/`, `@pages/`, `@features/`, `@entities/`, `@shared/`のエイリアスを使用
- [ ] **barrel export混在チェック** `[新観点 from PR#539]` — 同一ファイル内で `@shared/ui` 等の barrel export と `.vue` ファイル直接参照が混在していないか確認。barrel export に既に含まれるコンポーネントの直接参照は公開境界を崩す。barrel export 経由に統一すること

### Unused Code Detection

- [ ] **未使用の関数・composable・コンポーネント・import** — 呼び出されていない定義が残っていないか

### Syntax & Basic Quality

- [ ] **TypeScript構文エラー・型不一致**
- [ ] **マージコンフリクトマーカー** — `<<<<<<<`が残っていないか
- [ ] **SFCの構造** — `<template>` → `<script setup lang="ts">` → `<style scoped>`の順

---

## Extended Checklist

### FSD Architecture（詳細）

- **entities間の`@x`パターン** — entities間は`import type`のみ許可。ランタイムimportは禁止
- **3+スライスから使用される機能の昇格** — 3スライス以上から参照されるコードは上位層に昇格必須
- **Composables→Repository IFを介さず実装に直結はNG** — ComposablesがhttpClient等に直結すると依存方向違反（→ `references/code-examples.md`）
- **UseCase/Application層のインフラライブラリ依存禁止** `[新観点 from PR#437]` — `entities/model/` 配下の UseCase に `import axios from "axios"` 等のインフラライブラリが含まれていないか確認する。Axios エラー変換はリポジトリ（Mutation/Infrastructure）層で行い、UseCase はドメインエラー（プロジェクト定義の Error サブクラス）のみを知るべき
- **Vue SFC からの型エクスポート禁止** `[新観点 from PR#437]` — `.vue` ファイルから `export type` するのは避け、`model/types.ts` 等の純粋な TypeScript ファイルに型を定義する。`index.ts` からは `.vue` ではなく `./model/types` を参照してエクスポートする

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
- **バリデーション正規表現の重複** `[新観点 from PR#528]` — バリデーションロジックの正規表現や条件を複数箇所（ユーティリティとコンポーネント等）で重複定義していないか確認する。共通の定数・関数にまとめてシングルソースオブトゥルースを維持する。
- **バリデーション関数のパラメータ網羅性** `[新観点 from PR#555]` — バリデーション関数が全入力パラメータ（特にインデックス系）の範囲チェックを実施しているか確認する。ヘッダー名の検証はするがインデックスの範囲チェックを忘れがち。入力値ごとにバリデーションの有無を対応表で確認する。
- **boolean XOR パターンの可読性** `[新観点 from PR#555]` — `a === b` で両方true/両方falseを除外するXORパターンは一見分かりにくい。排他入力チェック等で使用する場合はインラインコメントで意図を説明する。
- **条件分岐の等価性** `[新観点 from PR#569]` — ネストした条件分岐が単一条件と等価でないかチェック。複数のif文で同じ変数を分岐している場合、真理値表で等価性を確認する。
- **dialog アクセシブル名の確認** `[新観点 from PR#497]` — `role="dialog"` または `role="alertdialog"` の要素が `aria-labelledby` か `aria-label` のいずれかを持つことを確認。両方 `undefined` の場合はスクリーンリーダーが認識できない。共通コンポーネントのデフォルト値設定が必要か確認する。
- **短い行のパディング漏れ** `[新観点 from PR#560]` — 追加列を生成するルール（duplicateColumn, arithmeticColumns, arithmeticWithConstant等）で `sourceIndex >= row.length` の短い行を処理する際、行をそのまま返すと `maxColumnCount` との列数不整合が発生する。`maxColumnCount` まで null パディングしてから結果列を追加しているか確認する。
- **isSafeInteger チェックの除算後誤判定** `[新観点 from PR#560]` — 連鎖演算（divide→add等）で除算後の合法な小数結果に対して `Number.isSafeInteger` チェックが false を返し null になるバグ。オーバーフロー判定は `previousAccumulator` と `nextValue` がともに safe integer の場合のみに限定すべき。
- **成功パスのエラー状態クリア漏れ** `[新観点 from PR#560]` — プレビュー生成等で失敗時に `ruleFormError.value` を設定する場合、成功パスでも明示的に `null` にクリアしないとエラーメッセージが残り続ける。全分岐で状態遷移の対称性を確認する。
- **バックエンド上限のフロントエンド実行時ガード** `[新観点 from PR#560]` — バックエンドに配列長上限（例: `_MAX_LIST_LENGTH = 100`）がある場合、フロントエンドの実行時バリデーションでも同じ上限を検証する。`canExecuteRule` だけに依存せず、`handleExecuteRule` でも二重チェックする。
- **early return前の高コスト操作検出** `[新観点 from PR#569]` — early returnガードの前にdeep clone・大量データコピーなどの高コスト操作が配置されていないかチェック。バリデーション失敗時に無駄なメモリ確保が発生する。バリデーション通過後に移動する。
- **ガード条件不一致による不要リアクティブ更新** `[新観点 from PR#569]` — 配列要素の存在チェック後、チェック結果に関わらずリアクティブ変数へ代入するパターンを検出。早期リターンで不要な更新を回避する。
