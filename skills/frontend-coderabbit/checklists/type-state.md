# Frontend Review: Type Safety + State Management

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Type Safety `[型: 40回 - 最多頻出]`

- [ ] **`any`型禁止** — `any`は禁止。`unknown`/`never`/ジェネリクス/型ガードで代替
- [ ] **`enum`禁止** — TypeScriptの`enum`は禁止。`const + as const + typeof`で代替（→ `references/code-examples.md`）
- [ ] **型アサーション原則禁止** — `as`キャスト・`!`(non-null assertion)は原則禁止。「必殺技」であり最終手段。`?? デフォルト値`/型ガード/`unknown`+narrowing/ジェネリクスで代替。`as unknown as X`は絶対NG。許容されるのはライブラリが型を提供していない等の回避不能なケースのみ
- [ ] **`console.*`禁止** — `console.log/warn/error`等は禁止。エラーは4層パイプライン経由
- [ ] **`<script setup lang="ts">`必須** — `lang="ts"`の省略禁止

### State Management

- [ ] **composable singletonのreadonly保護** — module-levelのrefをそのまま公開しない。`readonly()`でラップして外部から直接書き込まれないようにする（→ `references/code-examples.md`）
- [ ] **Composable/Hookの単一責務** — Composable/Hookに複数の責務（データ取得・状態管理・UI制御等）が混在していないか。責務ごとに分離すること
- [ ] **バックエンド/フロントエンド間のスキーマ不一致** — APIレスポンスのフィールド名・型・構造がバックエンドの実際のレスポンスと一致しているか確認する。スキーマ不一致はサイレントなバグの原因になる
- [ ] **同一型の重複定義禁止** — 型の中身が既存の型と同一なのに別名で新たに定義していないか確認する。既存の型定義を検索し、同等の構造がすでにあれば再利用すること

---

## Extended Checklist

### Type Safety（詳細）

- **型アサーション`as`/`!`の残存チェック** — Core観点の原則禁止に加え、テストコードも含めて`as`/`!`が残っていないか確認。テストでは`?? []`/`?? ''`等のフォールバックで代替可能なケースが多い
- **型定義の配置** — ドメインモデル型は`entities/*/model/`、APIスキーマは`entities/*/api/`、フォームバリデーションは`features/*/model/`、汎用型は`shared/types/`に配置
- **Zodによるruntime validation** — 認証・権限・金額等のクリティカルなAPIは本番でもZod検証必須。検証はAPI層で1回のみ、UI層に生データを持ち込まない
- **typeをデフォルト使用** — `type`をデフォルト使用。`interface`は拡張前提の公開契約のみ
- **金額にFloat演算禁止** — 金額に浮動小数点演算を直接使わない。`Amount`型（branded integer）経由
- **エンティティ型との型ドリフト防止** — features層でentities層の型フィールドと一致するインライン型定義（例: `{ key: string; label: string }`）がないかチェックする。Pick/Omitで元のエンティティ型を参照すべき。インライン型はエンティティ型の変更に追従できずドリフトの原因になる
- **新規entity作成時のapi/schema.tsの有無チェック** — 新規entityを作成する際、`api/schema.ts`にZodスキーマが定義されているか確認する。権限・認証系APIレスポンスを含め、全てのAPIレスポンスにランタイム検証（Zodスキーマ）を設けること。CODING_STANDARDS.mdのスキーマ規約違反になる
- **内部関数の引数型の広さ** — 内部関数でも引数型が実際の使用パターンより広くないかチェック。callerが特定のサブタイプのみ渡す関数は `Extract` で型を絞る。

### State Management（詳細）

- **状態の3分類** — サーバー状態→TanStack Query、クライアントグローバル状態→composable singleton、ローカルUI状態→コンポーネント内ref。混在禁止
- **Pinia非推奨** — Piniaの`defineStore`を使用していないか。3条件全て（3+箇所の読み書き、複雑な状態遷移、DevTools必須）を満たす場合のみ検討可
- **Props バケツリレー防止** — 3階層以上のprops受け渡しがないか。provide/inject、composable singleton等で解決
- **`computed`の使用** — テンプレート内の複雑な条件式は`computed`に切り出す
- **複数watcherの競合チェック** — 複数のwatcherが同じrefを操作する場合、モード切替（ドックモード等）時の優先順位が正しいか確認する。後続watcherが前のwatcherの設定を上書きしないこと。
- **module-level singletonのページ遷移時リセット** — module-level singleton（composable内のmodule-scope ref）の状態がページ遷移時に適切にリセットされるか確認する。onUnmountedでのクリーンアップを忘れないこと。
- **watcher間のエラークリア一貫性** — 複数フィールドにwatcherを設定する場合、エラー状態のクリア処理が一貫しているか確認する。片方のwatcherだけ `submitError` をクリアし、もう片方が漏れているケースがないか。
- **watch の deep オプションのスコープ** — 複数ソースのwatchで `{ deep: true }` を使う場合、プリミティブrefとオブジェクトrefが混在していないかチェック。混在時はwatcherを分離してdeepの適用範囲を最小化する。
- **モジュールレベルキャッシュの認証境界ライフサイクル** — メモリキャッシュ（module-level変数）を導入した際、ログアウト・セッション切れ・401/403エラー等の認証境界で適切にクリアされるかチェックする。キャッシュ追加時に無効化ポイントの洗い出しをセットで行わないと、古い値が残り続けてセキュリティ・機能バグになる。`invalidate`関数をexportし、認証境界で呼び出すこと
- **propsデフォルト値の一貫性** `[新観点 from PR#571]` — 同じ props を複数箇所で `??` でデフォルト値を設定していないかチェック。デフォルト値を定数として一箇所に集約すること。不一致バグの原因になる。
