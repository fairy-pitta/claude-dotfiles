# Frontend Review: FSD Architecture + Code Organization + Unused Code + Syntax

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### FSD Architecture `[最多頻出: FSD 21回, import 15回]`

- [ ] **公開API（index.ts）経由のimport必須** — 外部スライスの内部パス（`shared`/`entities`/`features`）への直接importは絶対NG。リファクタリング耐性を下げ公開境界を崩す。`@entities/company` 経由で import する（例: `@entities/company/api/companyApi` ではなく `@entities/company`）。一方、同一スライス内部のコード同士は必ず直接パスで import する（index.ts経由は循環依存の原因）（→ `references/code-examples.md`）
- [ ] **features間の直接import禁止** — features間の直接import（型importも含む）は禁止。共有したい型・ロジックは `entities/` または `shared/` に昇格
- [ ] **依存方向** — `app → pages → features → entities → shared`（上位→下位のみ）。pages層はfeatures内部（`model/`, `lib/` 等）を直接参照禁止。app層（main.ts等）もfeatures内部ではなく公開API（index.ts）のみに依存する（reset/cleanup関数もindex.tsからre-export）
- [ ] **FSDエイリアス必須** — 相対パスではなく `@app/`, `@pages/`, `@features/`, `@entities/`, `@shared/` のエイリアスを使用。2階層以上の相対パス（`../../`）禁止。各層内（pages層なら `@pages/` 等）も同様
- [ ] **import順序** — 外部ライブラリ → `@shared/` → `@entities/` → `@features/` → `@pages/` → `@app/` → 相対パスの順
- [ ] **barrel export混在チェック** — 同一ファイル内で `@shared/ui` 等の barrel export と `.vue` ファイル直接参照が混在していないか確認。barrel export に既に含まれるコンポーネントの直接参照は公開境界を崩す。barrel export 経由に統一する
- [ ] **`export *` 禁止** — 各スライスの `index.ts` では公開APIを明示エクスポートする。`export *` は禁止
- [ ] **Widgets/Processes層は不使用** — 本PJではWidgets層・Processes層は不使用。層構成は `app → pages → features → entities → shared`

### Unused Code Detection

- [ ] **未使用の関数・composable・コンポーネント・import** — 呼び出されていない定義、export されているが import されていないシンボル、定義されたがどのテンプレートからも使われていないコンポーネントが残っていないか
- [ ] **会話文脈・実装履歴コメントの削除** — 次のコメントは削除を指摘する。①AIエージェントとの会話内でしか得られない文脈（「指摘により修正」「リクエスト通り」等）、②以前の実装との比較・変更経緯（「旧実装ではuseState」「前回のレースコンディションを解消」等）、③コード単体を読んでも意図が伝わらない（PR/diff/会話に依存する）コメント。コメントは将来の読者に「なぜこうあるか」を説明するものに限る（意図を説明する有用なコメントは保持し、誤って削除指摘しないこと）

### Syntax & Basic Quality

- [ ] **TypeScript構文エラー・型不一致**
- [ ] **マージコンフリクトマーカー** — `<<<<<<<` が残っていないか
- [ ] **SFCの構造** — `<template>` → `<script setup lang="ts">` → `<style scoped>` の順

---

## Extended Checklist

### FSD Architecture（詳細）

- **Feature = ロジック中心** — featuresの大半は `model/` のみでUIを持たない。UIの組み立てはpages層で行い、featureに `ui/` を持たせるのは例外的なケースのみ
- **Segments任意** — 全セグメント（ui, model, api, lib, config）の配置を強制しない。entitiesは `api/` + `model/`、featuresは `model/` が基本。必要なセグメントのみ作成する
- **サブスライス内部設計** — 同一feature内のサブスライス間は `model/` または `lib/` を介して連携。サブスライス間の直接相互参照・循環依存禁止
- **entities間の `@x` パターン** — entities間のcross-slice importは `import type` 限定（ランタイムimport禁止）、consumer指名ファイル（`@x/<consumer名>.ts`）で管理し `index.ts` の公開APIとは別管理。features間は `@x` 含め禁止。※現時点では実コードでは未使用。entities間の型共有が必要になった場合の最終手段
- **上位層への昇格ルール** — 3+スライス/consumerから参照されるコード・関数・型は上位層に昇格必須。業務ロジック（税計算等）は1-2 consumerでも即entities昇格を検討。逆に1つのfeatureからしか使われない型（例: InitialSelection）は `shared/types/` に置かず feature内の `model/` に配置し index.ts から `export type` で公開する
- **Composables→Repository IFを介さず実装に直結はNG** — ComposablesがhttpClient等に直結すると依存方向違反（→ `references/code-examples.md`）
- **UseCase/Application層のインフラライブラリ依存禁止** — `entities/model/` 配下のUseCaseに `import axios from "axios"` 等のインフラライブラリが含まれていないか。Axiosエラー変換はリポジトリ（Mutation/Infrastructure）層で行い、UseCaseはドメインエラー（プロジェクト定義のErrorサブクラス）のみを知るべき
- **pages層でのエラー正規化禁止** — pages層で `normalizeAxiosError` を直接使い生レスポンス構造 `details.error` に依存していないか。FSDエラー4層パイプライン違反。entities層に `mapBackendError` を配置する
- **Vue SFCからの型エクスポート禁止** — `.vue` ファイルから `export type` するのは避け、`model/types.ts` 等の純粋なTSファイルに型を定義する。`index.ts` からは `.vue` ではなく `./model/types` を参照してエクスポートする
- **UI配置の判定フロー** — 業務操作→`features/*/ui/`、単一エンティティ表現→`entities/*/ui/`、画面専用レイアウト→`pages/*/`、それ以外→`shared/ui/`
- **pages層のオーケストレーション** — 複数featuresを跨ぐ連携はpages層で。features同士が直接importせずpagesがemitsを受け取りroute/query経由で別featureに伝播。連携手段の優先度: Route params > TanStack Query cache > Props/emits > provide/inject
- **shared層の配置基準** — shared に置けるのは「ビジネスロジックを含まない」かつ「他FSDレイヤーに依存しない」ものに限る（規約 MUST）。shared配置のコードが会社・仕訳・ユーザー等の業務概念を知らず、shared→FSD上位層への依存がないこと。その上で `shared/utils` は純粋関数、DOM操作やブラウザAPI副作用を持つ関数は `shared/lib` に配置する。新規ユーティリティ追加時に副作用の有無を確認する

### Dead Code & Backward Compat

- **後方互換の残骸（禁止）** — `_oldName` 等のリネーム済み未使用変数、旧パスからの移行用shim、`// removed`/`// deprecated` コメント付き放置コード、互換用ラッパー関数。不要コードは完全削除
- **連鎖的デッドコード** — 関数削除に伴い連鎖的に未使用になったヘルパー・型・定数・未参照ローカル変数がそのまま残っていないか

### Code Organization & DRY（詳細）

- **既存ファイル・パターンの再利用（不要な増殖防止）** — 既存と同等のパターンを持つ新ファイルを不必要に作成していないか。薄いラッパーやパススルーだけの中間ファイル（直接呼び出しで十分な場合）も作らない
- **既存の定数・型・変換関数の再利用** — 既存の定数・型定義・ヘルパーがあるのに同等の値・ロジックを独自に再定義していないか（例: props抽出ヘルパーをスプレッドで組み合わせ可能か、entities層の camelCase→snake_case 変換関数を各ページで手動再実装していないか）。既存定義を検索して再利用する
- **DRY原則** — 同一・類似のロジックが複数コンポーネント/composableに存在しないか
- **コンポーネント分割** — 1コンポーネントが複数の責務を持ちすぎていないか
- **マジックストリング・APIエンドポイントの定数化** — 複数ファイルで使われる文字列リテラル、fetch/axios/httpClient のURL文字列を直書きせず共有定数・定数オブジェクトに抽出しているか。エンドポイント変更時の漏れを防ぐ（→ `references/code-examples.md`）
- **バリデーションロジックの共通化** — バリデーションの正規表現・条件・正規化を複数箇所（ユーティリティとコンポーネント、複数関数、props側とmeta側等）で重複定義していないか。コピペで関数を作成した場合に発生しやすい。共通定数・ヘルパーに集約してシングルソースオブトゥルースを維持する
- **バリデーションのパラメータ網羅性・上限ガード** — バリデーション関数が全入力パラメータ（特にインデックス系の範囲チェック）を網羅しているか入力値ごとに対応表で確認する。バックエンドに配列長上限（例: `_MAX_LIST_LENGTH = 100`）がある場合、フロントの実行時バリデーション（`canExecuteRule` だけでなく `handleExecuteRule` でも二重チェック）で同じ上限を検証する
- **状態リセット・状態遷移の対称性** — ファイル削除・変更・差替等の全パスで関連状態が適切にリセットされ、成功/失敗パスでエラー状態（例: `ruleFormError.value`）のクリアが対称になっているか。成功パスでの `null` クリア漏れでエラーメッセージが残り続けるバグに注意
- **イベントハンドラの不要な再代入** — 高頻度イベントハンドラで状態が変化しない場合も毎回代入が走っていないか
- **ガード条件不一致による不要リアクティブ更新** — 配列要素の存在チェック後、結果に関わらずリアクティブ変数へ代入していないか。早期リターンで不要な更新を回避する
- **early return前の高コスト操作検出** — early returnガードの前にdeep clone・大量データコピー等の高コスト操作が配置されていないか。バリデーション失敗時に無駄なメモリ確保が発生する。バリデーション通過後に移動する
- **ゲッター関数の二重呼び出し** — `computed` 内でゲッター関数を複数回呼び出していないか（→ `references/code-examples.md`）
- **computed内クロージャ生成** — `computed` スコープ内で関数オブジェクトを定義すると再評価のたびに再生成される。composable本体スコープに抽出（→ `references/code-examples.md`）
- **条件分岐の等価性・XORパターン** — ネストした条件分岐が単一条件と等価でないか真理値表で確認する。`a === b` で両方true/両方falseを除外するXORパターンは分かりにくいのでインラインコメントで意図を説明する
- **単一情報源からの導出** — Record型のキーと同じ値をハードコード配列で二重定義していないか（subtype追加時の更新漏れリスク）。`Object.keys` から導出して単一情報源を維持する
- **isSafeInteger チェックの除算後誤判定** — 連鎖演算（divide→add等）で除算後の合法な小数結果に対し `Number.isSafeInteger` チェックが false を返し null になるバグ。オーバーフロー判定は `previousAccumulator` と `nextValue` がともに safe integer の場合のみに限定する
- **短い行のパディング漏れ** — 追加列を生成するルール（duplicateColumn, arithmeticColumns, arithmeticWithConstant等）で `sourceIndex >= row.length` の短い行を処理する際、行をそのまま返すと `maxColumnCount` との列数不整合が発生する。`maxColumnCount` まで null パディングしてから結果列を追加しているか確認する
- **v-forの:keyにIDを使用** — エンティティのIDフィールドが利用可能な場合、名前ベースの複合文字列キーではなくIDベースのキーを使用する
- **テンプレート内インラインハンドラの複雑さ** — @イベントハンドラが2文以上のインライン関数になっている場合はscript内に名前付き関数として抽出する。他ページとの一貫性を保つ
- **useTemplateRefパターンの使用** — テンプレート参照には `ref()` ではなく `useTemplateRef()`（Vue 3.5 導入の推奨API）を使用する。新規コンポーネントでは既存パターンとの整合性を確認する
- **dialog アクセシブル名の確認** — `role="dialog"` または `role="alertdialog"` の要素が `aria-labelledby` か `aria-label` を持つか確認。両方 `undefined` だとスクリーンリーダーが認識できない。共通コンポーネントのデフォルト値設定が必要か確認する
- **flex item 内の text-overflow: ellipsis** — flexコンテナ内の要素に省略表示を適用する場合 `min-width: 0` が必須。flex item の min-width デフォルト値 `auto` により縮小できず ellipsis が効かない
- **Teleportスタイルスコーピング** — `<Teleport to="body">` を使用すると `<style scoped>` のデータ属性スコーピングが効かずグローバルスタイルになる。クラス名にコンポーネント固有のプレフィックスを付与するか CSS Modules を使用する
- **Vue RouterのbeforeEnterと子ルート遷移** — 親ルートの `beforeEnter` は子→子遷移では再実行されない。権限ガードは保護対象の子ルート個別に `beforeEnter` を設定するか、グローバルガード `beforeEach` で `to.matched` を走査する
- **ルートガードとUI要素権限の整合** — ページ内UI要素の権限表で、ルートガードでブロックされるロールが付与ロール欄に含まれていないか確認。到達できないロールを含めると読者が混乱する。各ページのUI権限表を書く前にそのページのルートガード権限を確認し、ブロックされるロールを除外する
- **権限説明文の実装・マスターデータ照合** — 権限の説明文がバックエンドの permissions.csv 定義・`@require_permission` 使用箇所・実装上の用途と一致しているか確認する。コピペ時にずれやすく、権限の粒度変更時（例: manage → ページアクセスガード）は全ドキュメントで旧説明をテキスト検索して更新する
- **PR description と実装の整合性** — PR説明に「置換」「削除」と書かれている場合、元の要素が本当に除去されているか確認する。テンプレート内のアクションボタン一覧とスクリプトのアクション分岐が一致しているか
- **ドキュメント内の件数・集計値の整合性** — 数を記載する際は実際にカウントして一致を確認する。個別件数を修正した際はタイトルやサマリー行の合計値も連動して更新し、同じ数値を参照する他箇所もgrepで確認する
- **Markdownテーブル構造の保全** — テーブル行間に非テーブル要素（blockquote, 段落等）を挿入していないか。Markdownテーブルは行が連続していないとレンダリングが崩れる。注記はテーブル直後に配置する
