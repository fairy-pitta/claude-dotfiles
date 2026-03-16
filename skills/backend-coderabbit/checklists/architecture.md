# Backend Review: Architecture + Code Organization + Syntax

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Architecture

- [ ] **Feature間直接依存** — 通常Feature間の直接import（例: journal→accounting）がないか。`shared/types/`経由が必要。全Feature→shared/・user/・organization/ は許可
- [ ] **Domain層の純粋性** — Domain層（entities, repositories, enums）がDjango/DRFに依存していないか（`QuerySet`・`Model`・インフラ概念の混入禁止）
- [ ] **Application層のORM非依存** — Application層のサービス・ユースケースがORM Model（`from app.models import ...`）を直接importしていないか確認する。依存方向「Application → Domain ← Infrastructure」に従い、ORM操作はInfrastructure層のRepository実装に配置し、Application層はDomainインターフェースのみに依存させる
- [ ] **DomainRepositoryがDTOに依存するのはNG** — `AuthUserPayload`等のPresentation/Application DTOをDomain層のRepositoryが返していないか。ドメインモデル/VOを返しUseCase側でDTO変換すること（→ `references/code-examples.md`）
- [ ] **Transaction管理の配置** — `transaction.atomic()`がUseCase層でのみ管理されているか。Repository層でのトランザクション禁止
- [ ] **Result型とtransaction.atomicの組み合わせ** — Result型パターンでtransaction.atomic()を使う場合、エラーチェックがatomicブロック内にあるか確認する。Result型は例外を投げないため、atomicブロック外でのエラーチェックではロールバックされない。エラー時はRuntimeErrorをraiseしてatomicにrollbackさせる
- [ ] **transaction.atomic内のset_rollback漏れ** — `transaction.atomic()` 内で複数の書き込み操作がある場合、最初の書き込み成功後に後続が失敗するケースで `set_rollback(True)` が漏れていないか確認する。漏れるとトークン無効化だけコミットされる等の部分コミットバグが発生する。全 `return failure()` 前に `set_rollback(True)` を追加する
- [ ] **1 class = 1 file** — 各クラスが独自のファイルに配置されているか
- [ ] **トランザクション外副作用の並行リスク** — トランザクション外でメール送信等の副作用を実行する場合、その間に他リクエストが状態を変更し、送信内容が無効になる競合がないか検証する。特にcooldown=0等の設定で競合窓が広がるケースに注意
- [ ] **Domain層docstringの実装詳細漏洩** — Domain層の抽象メソッドdocstringに「UPDATE ... WHERE」等のSQL/ORM実装詳細が含まれていないか確認する。振る舞いはドメイン用語で記述し、実装方法はInfra層に委ねる
- [ ] **Viewでバリデーション直書き禁止** — View層でバリデーションロジックを直接実装していないか。バリデーションはSerializer/UseCase層に配置すること。View層は入力の受け取りとレスポンス変換のみ
- [ ] **既存エラーパターンの無視** — 既存のエラーハンドリングパターン（共通のエラーハンドラ・例外変換等）を無視して独自実装を作っていないか。プロジェクトの既存パターンに従うこと
- [ ] **既存パターンと重複する新ファイル** — 既存のコードと同等のパターンを持つ新ファイルを不必要に作成していないか。既存のパターンに沿い、不要なファイル増殖を防ぐ
- [ ] **バックエンド/フロントエンド間のスキーマ不一致** — APIレスポンスのフィールド名・型・構造がフロントエンドの期待するスキーマと一致しているか確認する。スキーマ不一致はサイレントなバグの原因になる
- [ ] **既存の定数・型を使わず独自定義** — プロジェクトに既存の定数・型定義・Enumがあるのに、同等の値を独自に再定義していないか。既存定義を検索して再利用すること
- [ ] **不要な条件分岐（フレームワーク自動処理）** — フレームワーク（Django/DRF）が自動的に処理する部分に不要な条件分岐を追加していないか。例: DRFが自動的にNone/空文字を処理するフィールドへの手動チェック
- [ ] **コードの意図明確性** — 暗黙的な振る舞いに依存せず、意図が明確に読み取れるコードになっているか。Optionalにして明示的にチェックする、命名で意図を伝える等

### Syntax & Basic Quality

- [ ] **構文エラー** — importの括弧閉じ忘れ、未解決のマージコンフリクトマーカー（`<<<<<<<`）
- [ ] **命名規約** — CLAUDE.md準拠（`{action}_{entity}_usecase.py`, `{Entity}RepositoryImpl`等）
- [ ] **未使用コード** — 未使用の関数・import・型定義・定数がないか
- [ ] **ドキュメント内ファイルパス参照の正確性** — リファレンスドキュメント内のファイルパスが実際のファイル名と一致しているか確認する。特にファイル名の単数/複数形の不一致に注意

---

## Extended Checklist

### Architecture（詳細）

- **Presentation→Infrastructure直接依存** — ViewやSerializerがRepositoryImplを直接参照していないか。UseCase経由が必要
- **フィルタ除外と永続化の不一致** — 「フィルタ除外」と「状態遷移の永続化」が一致しているか。exclude_expired_pendingのようなフィルタは表示上の除外であり、データの整合性を保証しない。一覧系APIで期限切れを永続化する設計判断が必要
- **終端状態の関連エンティティ削除後の一覧取得耐性** — 終端状態（APPROVED等）の申請が参照する関連エンティティ（会社・ユーザー）が削除される可能性を考慮しているか。特に削除ジョブが存在するフローでは、一覧取得時に欠損を許容する設計が必要。

### Code Organization & DRY（詳細）

- **DRY原則違反** — 同一・類似のヘルパーメソッドやバリデーションロジックが複数箇所に存在。複数UseCaseに同じロジックが重複している場合は共通化して切り出す
- **不要な中間ファイル・ラッパー** — 薄いラッパーやパススルーだけの中間ファイルが作られていないか。直接呼び出しで十分な場合は中間層を省く
- **QuerySetフィルタ重複の共通化** — `exclude_expired_pending` のような同一 QuerySet フィルタが `search` / `count` / `search_approvable_requests` に重複していないか確認する。3箇所以上の完全重複は helper 化して条件のズレを防ぐ。
- **入力型だけ異なる同一アルゴリズムの重複** — 入力型が異なるだけでロジックが同一の関数ペアがないか確認する。型変換部分を分離して共通化すべき。2箇所でもメンテリスクがある
- **メソッド間の同一集計再計算** — メインメソッドで作成した集計結果(dict等)をサブメソッドに渡さず再計算していないか確認する。O(n)走査の不要な繰り返しを防ぐ
- **同一Repository呼び出しのprivate メソッド抽出** — `save()`と`find_*()`で同じ`Entity.reconstruct(...)`が重複している場合、`_to_entity(obj)`に抽出
- **dict comprehensionの重複キー上書きバグ** — `{key: value for ...}`は同一キーで後の値が上書きされる。集計が必要な場合は加算ループに変更（→ `references/code-examples.md`）
- **サイレントドロップより明示的エラー返却** — list comprehension内のNoneフィルタでデータを捨てるのは危険。存在すべきデータが欠損している場合は`failure(ValueError(...))`を返す（→ `references/code-examples.md`）
- **Moduleレベルシングルトンとインスタンス変数の重複** — ステートレスなCalculator/Serviceの初期化方法を統一する
- **Deprecated API使用** — 非推奨のDjango API（例: `CheckConstraint`のclass引数）を使用していないか
- **コメント正確性** — コメントが実際のコードの挙動と一致しているか
- **for_updateメソッドのdocstring** — `select_for_update()` を使用するリポジトリメソッドの docstring にトランザクション内で呼び出す必要がある旨を明記しているか確認する。欠落すると呼び出し側がトランザクション外で使用するリスクがある
- **カーソルページネーションのソート契約明記** — cursor を受け付ける repository interface に、結果がどの順序（`-requested_at, -id` 等）で返るかが docstring で明記されているか確認する。実装だけに order_by があっても、Protocol 契約が曖昧だと差し替え時に崩れる。
- **型アノテーションスタイルの一貫性** — `Union[A, B]`と`A | B`が混在していないか
- **到達不能コードの検出** — 防御ガード（`if not x: return`）が上流のバリデーションで到達不能になっていないかチェック。冗長な防御コードはテストカバレッジを下げ保守コストを増やす。
- **設定値マジックナンバーの定数化** — TTL・タイムアウト等のビジネス設定値がローカル変数にハードコードされていないかチェック。constants/に定義して一元管理する。
- **設定変数の上書き検出** — settings.pyで条件分岐により変数をインポートした後、同じ変数を無条件に再定義していないかチェック。Pythonでは後続の代入が前の代入を上書きするため、条件付きインポート＋無条件ハードコード定義の組み合わせは常にバグとなる。条件付きインポートが存在する場合、後続の定義も対応するelse/notガードで囲むこと。
- **事前構築データの一貫使用** — `prepare()` 等で構築したデータを後続処理に渡さず、元の入力を再利用していないかをチェックする。保存用データとストリーム用データの出所が同一であることを確認する。「事前構築 → 使用」の流れで構築結果が一貫して使われていなければ、二重化バグや不整合の原因になる。
- **ロールスコープ階層の冗長grant防止** — ロールのスコープ階層（GLOBAL > REGION > COMPANY）を意識し、上位スコープのロール保持時に下位スコープのgrant作成が不要かを確認する。複数ロール併有ケースでは上位スコープが下位を包含するため、冗長なgrantは作成しない。
