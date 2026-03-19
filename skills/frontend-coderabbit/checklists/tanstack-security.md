# Frontend Review: TanStack Vue Query + Security

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### TanStack Vue Query

- [ ] **QueryKey Factoryパターン** — QueryKeyは必ずFactoryパターンで定義。マスターデータは`['master', ...]` prefix必須（→ `references/code-examples.md`）
- [ ] **Pinia使用禁止** — Piniaは使用しない。サーバー状態はTanStack Query、クライアントグローバル状態はcomposable singleton（module-level ref + `readonly()`）で管理

---

## Extended Checklist

### TanStack Vue Query（詳細）

- **キャッシュ戦略の適切性** — データの性質に応じた`staleTime`/`gcTime`が設定されているか（デフォルト: 1min/5min、マスタ: 24h/7d、トランザクション: 30s-2min/10-30min）
- **リトライ回数の遵守** — 4xx（408/429以外）→リトライ0、408/429→最大2、5xx/ネットワーク→最大1、Mutation→常に0
- **queryFnのsignal対応** — `queryFn`が`signal`を受け取りキャンセルに対応しているか
- **QueryKeyのシリアライズ可能性** — QueryKeyに`Date`,クラスインスタンス,`function`,`undefined`,`Symbol`を含めていないか。オプショナルparamsにデフォルト値を設定
- **QueryKeyに`undefined`を渡さない** — キャッシュ汚染の原因。デフォルト値を設定
- **楽観的更新禁止（全Mutation）** — 全Mutationで楽観的更新は禁止。サーバーレスポンスを待ち、`onSuccess`でキャッシュ無効化する
- **Mutation配置ルール** — entityのMutationは`entities/*/api/*Mutations.ts`、featureのMutationは`features/*/model/*Mutations.ts`に配置
- **enabledは`computed()`でゲート** — `useQuery`の`enabled`オプションは`computed()`でラップし、リアクティブにゲートする
- **ensureQueryData（ルートガード用）** — ルートガード等でキャッシュがあればそのまま使用、なければfetchするパターンには`queryClient.ensureQueryData()`を使用
- **Mutation後のinvalidateQueries** — Mutationの`onSuccess`で関連QueryKeyを`invalidateQueries`しているか
- **invalidateQueries 後の重複 refetch** `[新観点 from PR#437]` — `onSuccess` で `invalidateQueries` が行われているのに、さらに手動で `await query.refetch()` を呼び出していないか。`invalidateQueries` だけで TanStack Query が自動再フェッチするため、追加の `refetch()` は二重更新になる
- **Promise.allSettled + AbortSignal チェック** `[新観点 from PR#437]` — `Promise.allSettled` はキャンセルシグナルを無視してすべて待つ。`signal` を渡している場合は `Promise.allSettled` の前後で `if (signal?.aborted) throw new DOMException("Aborted", "AbortError")` を入れているか確認する
- **フォールバックデータソースのローディング状態反映** `[新観点 from PR#472]` — context依存でデータソースが切り替わるcomposableで、フォールバック先のローディング状態も統合して返却しているか確認する
- **keepPreviousData適用範囲** `[新観点 from PR#539]` — keepPreviousDataはリスト系クエリ（一覧取得）にのみ適用する。詳細系クエリ（ID指定の単一取得）に適用すると、パラメータ切替時に別エンティティの古いデータが表示されるリスクがある
- **keepPreviousDataの会社/テナント切替時staleデータリスク** `[from PR#539]` — `placeholderData: keepPreviousData`を使用しているクエリで、QueryKeyにcompanyId等のテナント識別子が含まれる場合、切替時に前のテナントのデータが一時表示されるリスクがないか確認する。マスターデータ（テナント非依存）以外でのkeepPreviousData使用は要注意
- **:key再マウントとkeepPreviousDataの無効な組み合わせ** `[from PR#539]` — `:key="$route.path"`等でコンポーネントが再マウントされるページでは、コンポーネント内の`keepPreviousData`は無効（再マウント時にクエリインスタンスが再作成されるため前のデータが参照されない）。無意味なkeepPreviousDataが残っていないか確認する
- **APIレスポンス必須フィールド検証** — 後続処理の前提となるレスポンスフィールド（ID等）の存在チェックが抜けていないか確認する。サーバーが予期しないレスポンスを返した場合に状態不整合やサイレント障害の原因になる。== null チェックでガードする。
- **watch + TanStack Query の immediate: true** `[新観点 from PR#590]` — watchでリアクティブな状態変化を監視する場合、初期値も処理対象かどうかを必ず検討し、必要なら `immediate: true` を付ける。特にキャッシュからの復元がありえるTanStack Queryとの組み合わせでは、マウント時に既にエラー状態の可能性がある。

### Error Handling Pipeline

- **エラーハンドリング4層パイプライン** — 各層の責務が守られているか: shared/api→AppError正規化、entities→ドメイン意味変換、features→リトライ/ロールバック、pages/app→Toast/Dialog表示
- **AppError型** — `kind`(network/http/auth/validation/domain/unknown)、`retryable`フラグ等を持つ統一エラー型を使用しているか
- **エラー定数のファイル配置** — shared/lib/errors/(共通)、entities/*/model/errors/(ドメイン固有)、entities/*/api/(バックエンドコード変換)、features/*/model/errors/(操作フロー固有)
- **retryableに基づく表示** — `retryable=true`→toast、`retryable=false`→dialog+fallback UI

### Security（セキュリティ）

- **v-html原則禁止** — `v-html`は`sanitizeHtml()`経由のみ例外で許可。ユーザー入力を直接DOMに渡していないか
- **APIエンドポイント定数化** — `api.get('/api/...'`のようなURL文字列直書き禁止。定数/関数化必須
- **VITE_*に秘密情報禁止** — `.env*`ファイルに公開情報以外を置いていないか
- **PII（個人識別情報）のログ出力禁止** — logger呼び出しの引数に個人情報を含めていないか
- **依存ライブラリの脆弱性** — 既知の脆弱性を持つライブラリ（例: `xlsx`）を使用していないか
- **機密情報のログ出力** — `console.*`等でAPIキー・トークン・パスワードを出力していないか
- **列挙攻撃対策とUI文言の整合性** — バックエンドが列挙攻撃対策で常にsuccessを返す場合、フロントエンドの文言が「送信しました」と断定していないか確認する。「該当するアカウントが存在する場合」等の条件付き表現を使用する
- **パスワード強度表示とバリデーションの乖離** — パスワード強度のスコア計算にボーナスポイントがある場合、必須要件（isValid）を満たさないのに「強い」と表示されないか確認する。強度表示ロジックでisValidを考慮する
- **クロスオリジン環境でのCookie読み取り安全性** — `document.cookie`は現在のoriginのCookieのみ返すため、APIが別originの場合にそのCookie値をCSRFトークンとして信頼してはいけない。Cookie読み取りにはAPI originと`window.location.origin`の一致チェックをセットで実装すること
- **権限判定のデータソース一貫性チェック** — 権限判定で使用するregionIdが表示対象エンティティの所属地域と一致しているか確認する。selectedRegion等のグローバル状態に依存していると、ユーザーが地域を切り替えた際に表示中エンティティとは無関係な権限判定になる。エンティティ自身が持つregionIdを使用すること
- **write API の二重送信防止ガード** `[新観点 from PR#616]` — mutation を呼ぶ関数には、UI の disabled 属性だけでなく関数側でも `isPending` / cooldown フラグによる早期 return を入れる。disabled はテンプレート側の制御であり、プログラム的な呼び出しを防げない。
- **queryFnでのsignal伝播漏れ** `[新観点 from PR#624]` — TanStack Queryの `queryFn` は常に `signal` を受け取り下流のfetch関数に伝播すべき。`ensureQueryData` でも同様。`queryFn: () => fetch()` ではなく `queryFn: ({ signal }) => fetch({ signal })` とする。
