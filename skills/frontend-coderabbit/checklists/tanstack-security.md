# Frontend Review: TanStack Vue Query + Security

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### TanStack Vue Query

- [ ] **QueryKey Factoryパターン** — QueryKeyは必ずFactoryパターンで定義。マスターデータは`['master', ...]` prefix必須（→ `references/code-examples.md`）
- [ ] **Pinia非推奨** — サーバー状態をPiniaとTanStack Queryの両方で管理しない。サーバー状態はTanStack Queryに集約

---

## Extended Checklist

### TanStack Vue Query（詳細）

- **QueryKeyに`undefined`を渡さない** — キャッシュ汚染の原因。デフォルト値を設定
- **楽観的更新禁止（仕訳Mutation）** — 仕訳関連のMutationで楽観的更新は禁止。冪等キー必須
- **Mutation後のinvalidateQueries** — Mutationの`onSuccess`で関連QueryKeyを`invalidateQueries`しているか
- **invalidateQueries 後の重複 refetch** `[新観点 from PR#437]` — `onSuccess` で `invalidateQueries` が行われているのに、さらに手動で `await query.refetch()` を呼び出していないか。`invalidateQueries` だけで TanStack Query が自動再フェッチするため、追加の `refetch()` は二重更新になる
- **Promise.allSettled + AbortSignal チェック** `[新観点 from PR#437]` — `Promise.allSettled` はキャンセルシグナルを無視してすべて待つ。`signal` を渡している場合は `Promise.allSettled` の前後で `if (signal?.aborted) throw new DOMException("Aborted", "AbortError")` を入れているか確認する
- **フォールバックデータソースのローディング状態反映** `[新観点 from PR#472]` — context依存でデータソースが切り替わるcomposableで、フォールバック先のローディング状態も統合して返却しているか確認する

### Security（セキュリティ）

- **XSS対策** — `v-html`の使用時にサニタイズされているか。ユーザー入力を直接DOMに渡していないか
- **依存ライブラリの脆弱性** — 既知の脆弱性を持つライブラリ（例: `xlsx`）を使用していないか
- **機密情報のログ出力** — `console.*`等でAPIキー・トークン・パスワードを出力していないか
- **列挙攻撃対策とUI文言の整合性** `[新観点 from PR#536]` — バックエンドが列挙攻撃対策で常にsuccessを返す場合、フロントエンドの文言が「送信しました」と断定していないか確認する。「該当するアカウントが存在する場合」等の条件付き表現を使用する
- **パスワード強度表示とバリデーションの乖離** `[新観点 from PR#536]` — パスワード強度のスコア計算にボーナスポイントがある場合、必須要件（isValid）を満たさないのに「強い」と表示されないか確認する。強度表示ロジックでisValidを考慮する
- **クロスオリジン環境でのCookie読み取り安全性** `[新観点 from PR#523]` — `document.cookie`は現在のoriginのCookieのみ返すため、APIが別originの場合にそのCookie値をCSRFトークンとして信頼してはいけない。Cookie読み取りにはAPI originと`window.location.origin`の一致チェックをセットで実装すること
- **権限判定のデータソース一貫性チェック** `[新観点 from PR#526]` — 権限判定で使用するregionIdが表示対象エンティティの所属地域と一致しているか確認する。selectedRegion等のグローバル状態に依存していると、ユーザーが地域を切り替えた際に表示中エンティティとは無関係な権限判定になる。エンティティ自身が持つregionIdを使用すること
