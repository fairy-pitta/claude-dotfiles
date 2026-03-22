# Frontend Review: FSD Architecture + Code Organization + Unused Code + Syntax

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### FSD Architecture `[最多頻出: FSD 21回, import 15回]`

- [ ] **index.ts（公開API）経由のimport必須** — 外部スライスの内部モジュールへの直接importは絶対NG。`@entities/company/api/companyApi` ではなく `@entities/company` 経由（→ `references/code-examples.md`）
- [ ] **index.ts は外部公開用入口のみ** — 上位層からの import は index.ts 経由必須だが、同一スライス内部のコード同士は必ず直接パスで import する。内部コードが index.ts を経由すると循環依存の原因になる
- [ ] **features間の直接import禁止** — features間の直接import（型importも含む）は禁止。共有したい型・ロジックは`entities/`または`shared/`に昇格
- [ ] **依存方向** — `app → pages → features → entities → shared`（上位→下位のみ）。pages層はfeatures内部（`model/`, `lib/`等）を直接参照禁止
- [ ] **FSDエイリアス必須** — 相対パスではなく`@app/`, `@pages/`, `@features/`, `@entities/`, `@shared/`のエイリアスを使用。2階層以上の相対パス（`../../`）禁止
- [ ] **import順序** — 外部ライブラリ → `@shared/` → `@entities/` → `@features/` → `@pages/` → `@app/` → 相対パスの順
- [ ] **barrel export混在チェック** `[新観点 from PR#539]` — 同一ファイル内で `@shared/ui` 等の barrel export と `.vue` ファイル直接参照が混在していないか確認。barrel export に既に含まれるコンポーネントの直接参照は公開境界を崩す。barrel export 経由に統一すること
- [ ] **`export *` 禁止** — 各スライスの`index.ts`では公開APIを明示エクスポートする。`export *` は禁止
- [ ] **Widgets/Processes層は不使用** — 本PJではWidgets層・Processes層は不使用。層構成は `app → pages → features → entities → shared`

### Unused Code Detection

- [ ] **未使用の関数・composable・コンポーネント・import** — 呼び出されていない定義が残っていないか

### Syntax & Basic Quality

- [ ] **TypeScript構文エラー・型不一致**
- [ ] **マージコンフリクトマーカー** — `<<<<<<<`が残っていないか
- [ ] **SFCの構造** — `<template>` → `<script setup lang="ts">` → `<style scoped>`の順

---

## Extended Checklist

### FSD Architecture（詳細）

- **Feature = ロジック中心** — featuresの大半は`model/`のみでUIを持たない。UIの組み立てはpages層で行う。featureに`ui/`を持たせるのは例外的なケースのみ
- **Segments任意** — 全セグメント（ui, model, api, lib, config）の配置を強制しない。entitiesは`api/` + `model/`が基本、featuresは`model/`が基本。必要なセグメントのみ作成する
- **entities間の`@x`パターン** — entities間は`import type`のみ許可。ランタイムimportは禁止
- **3+スライスから使用される機能の昇格** — 3スライス以上から参照されるコードは上位層に昇格必須
- **Composables→Repository IFを介さず実装に直結はNG** — ComposablesがhttpClient等に直結すると依存方向違反（→ `references/code-examples.md`）
- **UseCase/Application層のインフラライブラリ依存禁止** — `entities/model/` 配下の UseCase に `import axios from "axios"` 等のインフラライブラリが含まれていないか確認する。Axios エラー変換はリポジトリ（Mutation/Infrastructure）層で行い、UseCase はドメインエラー（プロジェクト定義の Error サブクラス）のみを知るべき
- **Vue SFC からの型エクスポート禁止** — `.vue` ファイルから `export type` するのは避け、`model/types.ts` 等の純粋な TypeScript ファイルに型を定義する。`index.ts` からは `.vue` ではなく `./model/types` を参照してエクスポートする
- **Cross-Slice `@x`パターンのルール** — entities間のcross-slice importは`import type`限定、consumer指名ファイル（`@x/<consumer名>.ts`）で管理。`index.ts`の公開APIとは別管理。features間は`@x`含め禁止。※現時点では実コードでは未使用。entities間の型共有が必要になった場合の最終手段として定義
- **features間共有の昇格ルール** — 3+consumerで必要な関数・型がfeature内に残っていないか。業務ロジック（税計算等）は1-2 consumerでも即entities昇格を検討
- **pages層のオーケストレーション** — 複数featuresを跨ぐ連携はpages層で。features同士が直接importせずpagesがemitsを受け取りroute/query経由で別featureに伝播。連携手段の優先度: Route params > TanStack Query cache > Props/emits > provide/inject
- **shared層にビジネスロジック禁止** — shared配置のコードが会社・仕訳・ユーザー等の業務概念を知らないこと。shared→FSD上位層への依存禁止
- **UI配置の判定フロー** — 業務操作→`features/*/ui/`、単一エンティティ表現→`entities/*/ui/`、画面専用レイアウト→`pages/*/`、それ以外→`shared/ui/`
- **サブスライス内部設計** — 同一feature内のサブスライス間は`model/`または`lib/`を介して連携。サブスライス間の直接相互参照・循環依存禁止

### Dead Code & Backward Compat

- **未使用エクスポート・関数・変数** — export されているが import されていないシンボル、ファイル内の未参照ローカル変数
- **未使用コンポーネント** — 定義されたがどのテンプレートからも使われていないコンポーネント
- **後方互換の残骸（禁止）** — `_oldName`等のリネーム済み未使用変数、旧パスからの移行用shim、`// removed`/`// deprecated`コメント付き放置コード、互換用ラッパー関数。不要コードは完全削除
- **連鎖的デッドコード** — 関数削除に伴い連鎖的に未使用になったヘルパー・型・定数がそのまま残っていないか

### Code Organization & DRY（詳細）

- **既存パターンと重複する新ファイル** — 既存のコードと同等のパターンを持つ新ファイルを不必要に作成していないか。既存のパターンに沿い、不要なファイル増殖を防ぐ
- **不要な中間ファイル・ラッパー** — 薄いラッパーやパススルーだけの中間ファイルが作られていないか。直接呼び出しで十分な場合は中間層を省く
- **既存の定数・型を使わず独自定義** — プロジェクトに既存の定数・型定義があるのに、同等の値を独自に再定義していないか。既存定義を検索して再利用すること
- **DRY原則** — 同一・類似のロジックが複数コンポーネント/composableに存在しないか
- **コンポーネント分割** — 1コンポーネントが複数の責務を持ちすぎていないか
- **マジックストリング** — 複数ファイルで使われる文字列リテラルを共有定数化しているか（→ `references/code-examples.md`）
- **ゲッター関数の二重呼び出し** — `computed`内でゲッター関数を複数回呼び出していないか（→ `references/code-examples.md`）
- **computed内クロージャ生成** — `computed`スコープ内で関数オブジェクトを定義すると再評価のたびに再生成される。composable本体スコープに抽出（→ `references/code-examples.md`）
- **状態リセットの対称性** — ファイル削除・変更・差替等の全パスで関連状態が適切にリセットされているか
- **イベントハンドラの不要な再代入** — 高頻度イベントハンドラで状態が変化しない場合も毎回代入が走っていないか
- **`@pages/`エイリアスの使用** — pages層内では`@pages/`エイリアスを使用（相対パスは規約違反）
- **APIエンドポイント定数化** — fetch/axiosのURL文字列が直書きされていないかチェック。定数として抽出してDRY原則を維持する。
- **バリデーション正規表現の重複** — バリデーションロジックの正規表現や条件を複数箇所（ユーティリティとコンポーネント等）で重複定義していないか確認する。共通の定数・関数にまとめてシングルソースオブトゥルースを維持する。
- **バリデーション関数のパラメータ網羅性** — バリデーション関数が全入力パラメータ（特にインデックス系）の範囲チェックを実施しているか確認する。ヘッダー名の検証はするがインデックスの範囲チェックを忘れがち。入力値ごとにバリデーションの有無を対応表で確認する。
- **boolean XOR パターンの可読性** — `a === b` で両方true/両方falseを除外するXORパターンは一見分かりにくい。排他入力チェック等で使用する場合はインラインコメントで意図を説明する。
- **条件分岐の等価性** — ネストした条件分岐が単一条件と等価でないかチェック。複数のif文で同じ変数を分岐している場合、真理値表で等価性を確認する。
- **dialog アクセシブル名の確認** — `role="dialog"` または `role="alertdialog"` の要素が `aria-labelledby` か `aria-label` のいずれかを持つことを確認。両方 `undefined` の場合はスクリーンリーダーが認識できない。共通コンポーネントのデフォルト値設定が必要か確認する。
- **短い行のパディング漏れ** — 追加列を生成するルール（duplicateColumn, arithmeticColumns, arithmeticWithConstant等）で `sourceIndex >= row.length` の短い行を処理する際、行をそのまま返すと `maxColumnCount` との列数不整合が発生する。`maxColumnCount` まで null パディングしてから結果列を追加しているか確認する。
- **isSafeInteger チェックの除算後誤判定** — 連鎖演算（divide→add等）で除算後の合法な小数結果に対して `Number.isSafeInteger` チェックが false を返し null になるバグ。オーバーフロー判定は `previousAccumulator` と `nextValue` がともに safe integer の場合のみに限定すべき。
- **成功パスのエラー状態クリア漏れ** — プレビュー生成等で失敗時に `ruleFormError.value` を設定する場合、成功パスでも明示的に `null` にクリアしないとエラーメッセージが残り続ける。全分岐で状態遷移の対称性を確認する。
- **バックエンド上限のフロントエンド実行時ガード** — バックエンドに配列長上限（例: `_MAX_LIST_LENGTH = 100`）がある場合、フロントエンドの実行時バリデーションでも同じ上限を検証する。`canExecuteRule` だけに依存せず、`handleExecuteRule` でも二重チェックする。
- **early return前の高コスト操作検出** — early returnガードの前にdeep clone・大量データコピーなどの高コスト操作が配置されていないかチェック。バリデーション失敗時に無駄なメモリ確保が発生する。バリデーション通過後に移動する。
- **ガード条件不一致による不要リアクティブ更新** — 配列要素の存在チェック後、チェック結果に関わらずリアクティブ変数へ代入するパターンを検出。早期リターンで不要な更新を回避する。
- **APIエンドポイント文字列直書き検出** — httpClient呼び出しでリテラル文字列を直接使用していないか確認する。メンテナンス性が低下しエンドポイント変更時に漏れが生じる。定数オブジェクトに抽出する。
- **FSD内部パス直接import検出** — shared/entities/features のスライス内部パスを直接importしていないか確認する。FSDの公開API原則に反しリファクタリング耐性が低下する。index.ts経由のimportに修正する。
- **pages層エラー正規化禁止** `[新観点 from PR#571]` — pages層で `normalizeAxiosError` を直接使い、生レスポンス構造 `details.error` に依存していないかチェック。FSD エラー4層パイプライン違反になる。entities層に `mapBackendError` を配置すること。
- **flex item 内の text-overflow: ellipsis** `[新観点 from PR#606]` — flex コンテナ内の要素に省略表示を適用する場合、`min-width: 0` が必須。flex item の min-width デフォルト値 `auto` により縮小できず ellipsis が効かない。
- **PR description と実装の整合性** `[新観点 from PR#519]` — PR説明に「置換」「削除」と書かれている場合、元の要素が本当に除去されているか確認する。テンプレート内のアクションボタン一覧とスクリプトのアクション分岐が一致しているか。
- **定数配列とRecord型の二重定義** `[新観点 from PR#614]` — Record型のキーと同じ値をハードコード配列で定義していないか確認する。subtype追加時の更新漏れリスクがある。Object.keysから導出して単一情報源を維持する。
- **同一ファイル内のバリデーション重複** `[新観点 from PR#614]` — 複数関数で同じバリデーションロジックをインラインで記述していないか確認する。特にコピペで関数を作成した場合に発生しやすい。共通ヘルパーに抽出する。
- **入力バリデーションの一貫性** `[新観点 from PR#619]` — 同一の外部入力（URLクエリパラメータ等）を複数箇所で処理する場合、バリデーション/正規化ロジックが統一されているかチェックする。props側とmeta側で異なる関数を使っていると許可リスト変更時に漏れが生じる。共通ヘルパーに集約すべき。
- **Vue RouterのbeforeEnterと子ルート遷移** `[新観点 from PR#624]` — 親ルートの `beforeEnter` は子→子遷移では再実行されない。権限ガードは保護対象の子ルート個別に `beforeEnter` を設定するか、グローバルガード `beforeEach` で `to.matched` を走査する。
- **ドキュメント内の件数と列挙の整合性** `[新観点 from PR#624]` — 数を記載する際は実際にカウントして一致を確認する。
- **app層のfeatures内部依存** `[新観点 from PR#623]` — app層(main.ts等)がfeatures内部のモジュールを直接importしていないか確認する。FSD依存方向ルールに従い、features層の公開API(index.ts)のみに依存すべき。resetやcleanup関数もfeature内のindex.tsからre-exportする。
- **ドキュメント集計値の連動更新** `[新観点 from PR#624]` — ドキュメント内の個別件数を修正した際、タイトルやサマリー行の合計値も連動して更新すること。部分修正だけでなく、同じ数値を参照している他の箇所もgrepで確認すべき。
- **ヘルパー関数の再利用** `[新観点 from PR#623]` — 既存のprops抽出ヘルパー関数がある場合にスプレッド構文で組み合わせ可能か確認する。同じロジックを手動で再実装していないか検証する。
- **camelCase→snake_case変換の重複** `[新観点 from PR#623]` — entities層の変換関数を使わずに各ページで直接マッピングしていないか確認する。2箇所以上で同じ変換を行っている場合は共通関数に抽出する。
- **v-forの:keyにIDを使用** `[新観点 from PR#623]` — エンティティのIDフィールドが利用可能な場合、名前ベースの複合文字列キーではなくIDベースのキーを使用する。
- **単一feature専用型のshared配置禁止** `[新観点 from PR#654]` — 1つのfeatureからしか使われない型（InitialSelection等）を `shared/types/` に配置しない。feature内の `model/` に配置し、featureの `index.ts` から `export type` で公開する。FSD規約に従い、3+スライスから使われない限りsharedへの昇格は不要。
- **権限説明文の実装照合** `[新観点 from PR#670]` — 権限の説明文がバックエンドCSV定義と @require_permission 使用箇所に一致しているか確認。コピペ時に説明が実態とずれやすい。各権限の説明を書く際にバックエンドの permissions.csv と実際のデコレータ使用箇所を確認する。
- **ルートガードとUI要素権限の整合** `[新観点 from PR#670]` — ページ内UI要素の権限表で、ルートガードでブロックされるロールが付与ロール欄に含まれていないか確認。ルートガード権限を持たないロールはページ内のUI要素に到達できないため、付与ロール欄に含めると読者が混乱する。各ページのUI権限表を書く際、そのページのルートガード権限を先に確認し、ルートガードでブロックされるロールを除外する。
