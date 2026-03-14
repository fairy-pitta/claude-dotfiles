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

---

## Extended Checklist

### Type Safety（詳細）

- **型アサーション`as`/`!`の残存チェック** — Core観点の原則禁止に加え、テストコードも含めて`as`/`!`が残っていないか確認。テストでは`?? []`/`?? ''`等のフォールバックで代替可能なケースが多い
- **金額にFloat演算禁止** — 金額に浮動小数点演算を直接使わない。`Amount`型（branded integer）経由
- **エンティティ型との型ドリフト防止** `[新観点 from PR#472]` — features層でentities層の型フィールドと一致するインライン型定義（例: `{ key: string; label: string }`）がないかチェックする。Pick/Omitで元のエンティティ型を参照すべき。インライン型はエンティティ型の変更に追従できずドリフトの原因になる
- **新規entity作成時のapi/schema.tsの有無チェック** `[新観点 from PR#526]` — 新規entityを作成する際、`api/schema.ts`にZodスキーマが定義されているか確認する。権限・認証系APIレスポンスを含め、全てのAPIレスポンスにランタイム検証（Zodスキーマ）を設けること。CODING_STANDARDS.mdのスキーマ規約違反になる
- **内部関数の引数型の広さ** `[新観点 from PR#569]` — 内部関数でも引数型が実際の使用パターンより広くないかチェック。callerが特定のサブタイプのみ渡す関数は `Extract` で型を絞る。

### State Management（詳細）

- **`computed`の使用** — テンプレート内の複雑な条件式は`computed`に切り出す
- **複数watcherの競合チェック** `[新観点 from PR#510]` — 複数のwatcherが同じrefを操作する場合、モード切替（ドックモード等）時の優先順位が正しいか確認する。後続watcherが前のwatcherの設定を上書きしないこと。
- **module-level singletonのページ遷移時リセット** `[新観点 from PR#510]` — module-level singleton（composable内のmodule-scope ref）の状態がページ遷移時に適切にリセットされるか確認する。onUnmountedでのクリーンアップを忘れないこと。
- **watcher間のエラークリア一貫性** `[新観点 from PR#528]` — 複数フィールドにwatcherを設定する場合、エラー状態のクリア処理が一貫しているか確認する。片方のwatcherだけ `submitError` をクリアし、もう片方が漏れているケースがないか。
- **watch の deep オプションのスコープ** `[新観点 from PR#569]` — 複数ソースのwatchで `{ deep: true }` を使う場合、プリミティブrefとオブジェクトrefが混在していないかチェック。混在時はwatcherを分離してdeepの適用範囲を最小化する。
- **モジュールレベルキャッシュの認証境界ライフサイクル** `[新観点 from PR#523]` — メモリキャッシュ（module-level変数）を導入した際、ログアウト・セッション切れ・401/403エラー等の認証境界で適切にクリアされるかチェックする。キャッシュ追加時に無効化ポイントの洗い出しをセットで行わないと、古い値が残り続けてセキュリティ・機能バグになる。`invalidate`関数をexportし、認証境界で呼び出すこと
- **watcher 監視対象の網羅性** `[新観点 from PR#571]` — watcher内の分岐条件で使用しているリアクティブ値が全て監視対象に含まれているか確認する。監視対象外の値が後から変更された場合、watcherが再実行されず条件分岐が陳腐化する。条件で参照する全てのリアクティブ値をwatch sourcesに含める。
