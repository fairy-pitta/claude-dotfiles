# Frontend Review: Test Quality

このチェックリストはサブエージェント用。`frontend/` 配下の変更ファイル（特にテストファイル）に対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Extended Checklist

### Test Quality（テストファイルが変更されている場合）

- **MSW使用** — APIモックはMSWを使用しているか。`vi.fn()`の直接モック乱用は避ける
- **テスト期待値の文字列リテラル禁止** — `rejects.toThrow('エラーメッセージ')` 等の期待値に文字列リテラルを直書きしていないか。定数（`MESSAGES.VALIDATION.X`等）を参照する。定数側の変更に追従できず、テストの意図も不明確になる
- **FormDataを使うmutationテスト** — `FormData`を使うMutationのテストでAxiosアダプターをNode.js httpに設定しているか（`axios.defaults.adapter = 'http'`）（→ `references/code-examples.md`）
- **型安全なモック** — モック関数に適切な型が付いているか
- **テストケースの網羅性** — ローディング・エラー・成功状態のそれぞれをカバーしているか
- **テストデータの独立性** — テスト間で共有される可変なオブジェクトがないか
- **モックハンドラのAPIバリデーション再現** — MSWモックハンドラがAPIの必須パラメータ組み合わせバリデーションを正しく再現しているか確認する。片方のみ指定時のエラーレスポンス等
- **Playwright ルートのクエリパラメータ対応** — APIリクエストにクエリパラメータが付く場合（例: `?page=1&page_size=50`）、glob パターン `'**/api/endpoint/'` はマッチしない。`page.route()` のパターンは正規表現 `/\/api\/endpoint\//` を使うこと。ページネーションパラメータ追加後は既存テストの route パターンを見直す
- **E2E/VRTテストのセレクタ安定性とモックレスポンス整合性** — CSS クラスセレクタはスタイル変更で壊れやすい。コンポーネントに `data-testid` を追加し `page.getByTestId()` を使うこと。また MSW/Playwright モックのレスポンス形式はAPIの実際のレスポンス形式（ページネーションフィールド `count`/`page`/`page_size` 等）と一致させること
- **ソートテストの non-null assertion** - ループ範囲が保証されているソート検証テストで `data?.[i+1].createdAt.getTime() ?? 0` のパターンは false positive のリスク。`expect(data!.length).toBeGreaterThanOrEqual(2)` を追加し `data![i]`/`data![i+1]` の non-null assertion を使う。
- **テストモック正規表現の厳密化** — Playwrightの `page.route()` やMSWの正規表現パターンに `$` アンカーを付けているか確認。広すぎるパターンは将来エンドポイント追加時に衝突する
- **実装追加時のテストケース同期** — 既存の判定関数やユーティリティに新しいケース（例: concatColumns）を追加した場合、対応するテストファイルにもケースが追加されているか確認する。実装とテストの不一致は見落としやすい。
- **テストファイルのFSDインポートルール** — テストファイルでも内部パス直接importではなくバレルエクスポート経由でimportしているかチェック。FSDの「内部直接import禁止」ルールはテストにも適用される。
- **timeout スコープの最小化** — `describe` 全体に `{ timeout: N }` を設定していないか確認。遅いテストケースが1つだけなら、そのテストの `it` ブロックにのみ `{ timeout: N }` を設定する。describe全体への設定は他のテストの潜在的なタイムアウト問題を隠蔽する。
