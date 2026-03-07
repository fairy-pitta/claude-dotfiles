---
name: backend-coderabbit
description: Backend専用 CodeRabbit-style code review - Django/DDD/Clean Architectureの観点で体系的・網羅的にレビュー。FSDフロントエンドは対象外。
---

# Backend CodeRabbit Review

Django + Clean Architecture/DDDのバックエンドコードをCodeRabbitスタイルで体系的にレビューする。

**Announce at start:** "I'm using the backend-coderabbit skill to perform a comprehensive backend code review."

**Data source:** 431 backend inline comments from 33 PRs (recent 40 PRs analyzed)

**コード例示:** `references/code-examples.md` を参照

## Language

**日本語で回答すること。**タイトルに【必須修正】【要改善】【任意】等のラベルを使用する。

## Review Personality

- Formal & systematic
- 重要度を必ず明記し、actionableな修正案（diffつき）を必ず提示
- ファイルパスと行番号を参照
- `<details>` collapsibleで修正案を展開

## Comment Structure

```
_<category>_ | _<severity>_

**<title>**

<explanation>

<details>
<summary>🔧 修正案</summary>

```diff
<before/after diff>
```
</details>
```

## Severity Indicators

- **🔴 Critical** - マージ前必須修正（セキュリティ、データ損失、クラッシュ）
- **🟠 Major** - 修正推奨（機能影響、アーキテクチャ違反、型安全性）
- **🟡 Minor** - 改善推奨（リファクタ、軽微な最適化）
- **🔵 Trivial** - コードスタイル（未使用import、フォーマット）

## Category Labels

- `_⚠️ Potential issue_` - バグ・ロジック問題
- `_🧹 Nitpick_` - コード品質・スタイル
- `_🛠️ Refactor suggestion_` - アーキテクチャ改善

---

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^backend/"
```

### 2. Core チェック（全PRで必ず実施）

変更ファイルを読んだ後、**Core Checklist** の全項目をチェックする。
見落としゼロを優先。ファイル数が多い場合でもCore観点は省略しない。

### 3. Extended チェック（変更内容に応じて実施）

変更内容がマイグレーション・テスト・バリデーション等に関係する場合、
**Extended Checklist** の対応セクションをチェックする。

### 4. Generate Summary

```markdown
## Review Summary

**Actionable comments posted: <N>**

### Severity Distribution
- 🔴 Critical: <N>
- 🟠 Major: <N>
- 🟡 Minor: <N>
- 🔵 Trivial: <N>

### Key Findings

**Architecture:** ...
**Type Safety:** ...
**Security:** ...
**Performance:** ...
**Test Quality:** ...

### Recommendations
1. **マージ前必須修正:** [Critical/Major]
2. **修正推奨:** [Minor]
3. **任意改善:** [Trivial]
```

---

## Core Checklist（全PRで必ずチェック）`[最頻出・最重要]`

### Architecture

- [ ] **Feature間直接依存** — 通常Feature間の直接import（例: journal→accounting）がないか。`shared/types/`経由が必要。全Feature→shared/・user/・organization/ は許可
- [ ] **Domain層の純粋性** — Domain層（entities, repositories, enums）がDjango/DRFに依存していないか（`QuerySet`・`Model`・インフラ概念の混入禁止）
- [ ] **DomainRepositoryがDTOに依存するのはNG** — `AuthUserPayload`等のPresentation/Application DTOをDomain層のRepositoryが返していないか。ドメインモデル/VOを返しUseCase側でDTO変換すること（→ `references/code-examples.md`）
- [ ] **Transaction管理の配置** — `transaction.atomic()`がUseCase層でのみ管理されているか。Repository層でのトランザクション禁止
- [ ] **Result型とtransaction.atomicの組み合わせ** `[新観点 from PR#510]` — Result型パターンでtransaction.atomic()を使う場合、エラーチェックがatomicブロック内にあるか確認する。Result型は例外を投げないため、atomicブロック外でのエラーチェックではロールバックされない。エラー時はRuntimeErrorをraiseしてatomicにrollbackさせる
- [ ] **1 class = 1 file** — 各クラスが独自のファイルに配置されているか

### Type Safety

- [ ] **型ヒント必須・Any禁止** — すべての関数・メソッドに型ヒントを付与。`Any`型は禁止 → `Protocol`/`TypedDict`/`Generic`で代替
- [ ] **Result型タプルアンパック** — `result, error = usecase.execute()`の形式が必須。`.error`属性アクセス禁止
- [ ] **`_`でエラー無視はNG** — `value, _ = usecase.execute()`でエラーを捨てると認可チェックが消える。必ずエラーを変数に受けてチェック（→ `references/code-examples.md`）
- [ ] **Enum必須** — ステータス値・カテゴリ値に文字列リテラル禁止。`TextChoices`/`IntegerChoices`を使用
- [ ] **エラー型判定** `[新観点 from PR#522]` — Result型のエラーを文字列比較で分岐していないか確認する。UseCase層で例外型を分類している場合はisinstanceで型判定すべき。文字列比較はメッセージ定数の変更で分岐が壊れるリスクがある
- [ ] **bool⊂int型チェック** `[新観点 from PR#469]` — isinstance(x, int)によるバリデーション箇所でboolが通過しないか確認する。Pythonではboolはintのサブクラスのため、isinstance(True, int)がTrueを返す。intチェックの前にisinstance(x, bool)で排除する

### Security & Authorization

- [ ] **permission_classes明示設定** — DRF ViewにPermissionが必ず明示されているか。デフォルト依存禁止（→ `references/code-examples.md`）
- [ ] **認可バイパス経路** — Result型の誤用やエラーハンドリング不備により認可チェックがスキップされる経路がないか
- [ ] **write_only on sensitive fields** — パスワード等の機密フィールドに`write_only=True`が設定されているか
- [ ] **冪等キー実装のTOCTOUチェック** `[新観点 from PR#486]` — cache.get/setの分離パターンは並行リクエストで競合する。冪等制御にはcache.add()等の原子的操作を使い、エラーパスでのロック解放漏れがないか確認
- [ ] **冪等キーのスコープ** `[新観点 from PR#486]` — 認証必須APIのcache keyにユーザーIDが含まれているか確認する。ユーザーIDなしだと異なるユーザー間で冪等キーが衝突し、正当なリクエストが拒否される

### Error Messages & Constants

- [ ] **エラーメッセージ定数化** — 文字列リテラルでエラーメッセージを直接記述していないか。`app/shared/constants/`で管理（→ `references/code-examples.md`）
- [ ] **`logger`/`print`禁止** — `logger`・`print`（マイグレーションbackward含む）の使用禁止
- [ ] **ユーザー向け/内部向けメッセージの混在チェック** `[新観点 from PR#486]` — Msg/InternalMsgの分離が不十分だとAPIレスポンスに内部メッセージが露出するリスクがある。メッセージ定数を追加する際、用途（ユーザー向け/内部向け）を確認して適切なクラスに配置すること
- [ ] **定数ファイルの責務分離** `[新観点 from PR#486]` — メッセージ定数ファイルに設定値（TTL, 閾値等）を混在させていないか確認する。文言定数と運用設定値は別ファイルに分離すること。混在すると責務が曖昧になり保守性が低下する
- [ ] **DRFフィールド制約のエラーメッセージ定数化** `[新観点 from PR#520]` — DRFフィールドにmax_length/min_length/min_value/max_value等の制約を追加する際、error_messagesもセットでMsg定数化されているか確認する。DRFビルトインメッセージはプロジェクトの「エラーメッセージ定数化」ルールの対象外と見落としやすい。error_messagesパラメータで明示的に定数を指定すること

### Database Performance

- [ ] **N+1クエリ** — ループ内でDBクエリを実行していないか。`select_related()`/`prefetch_related()`の適用漏れ
- [ ] **`SELECT *`禁止** — `select_related(...).get()`は全カラム取得になる。`.only()`/`.values()`で絞り込む（→ `references/code-examples.md`）
- [ ] **select_related使用時の.only()適用** `[新観点 from PR#472]` — select_relatedやprefetch_relatedで関連テーブルをJOINしている箇所で.only()/.defer()によるカラム制限が付いているかチェックする。SELECT *禁止ルールはJOIN先テーブルにも適用される。必要フィールドのみ明示的に列挙する
- [ ] **QuerySetのorder_by明示** `[新観点 from PR#472]` — Django の QuerySet で `.all()` を使用する際、`order_by` を指定しないとDB依存で順序が揺れる。APIレスポンスの安定性・テスト再現性のため、`order_by` は常に明示すべき

### Test Quality（テストファイルが変更されている場合）

- [ ] **関数ベーステスト必須** — `class TestXxx:`禁止。すべて`def test_xxx():`のモジュールレベル関数
- [ ] **テスト名は英語・命名順序** — `test_<動作>_<条件>_<期待結果>`の順序が必須。日本語禁止（→ `references/code-examples.md`）
- [ ] **正常系カバレッジ** — 異常系テストのみで正常系が抜けていないか

### Syntax & Basic Quality

- [ ] **構文エラー** — importの括弧閉じ忘れ、未解決のマージコンフリクトマーカー（`<<<<<<<`）
- [ ] **命名規約** — CLAUDE.md準拠（`{action}_{entity}_usecase.py`, `{Entity}RepositoryImpl`等）
- [ ] **未使用コード** — 未使用の関数・import・型定義・定数がないか
- [ ] **ドキュメント内ファイルパス参照の正確性** `[新観点 from PR#469]` — リファレンスドキュメント内のファイルパスが実際のファイル名と一致しているか確認する。特にファイル名の単数/複数形の不一致に注意

---

## Extended Checklist（変更内容に応じてチェック）

### Architecture（詳細）

- **Presentation→Infrastructure直接依存** — ViewやSerializerがRepositoryImplを直接参照していないか。UseCase経由が必要

### Type Safety（詳細）

- **ドメインエンティティのEnum型引数の実行時型検証** — `create()`等のファクトリメソッドでEnum型パラメータを受け取る場合、`isinstance(x, SomeEnum)` の実行時チェックがあるか。型ヒントだけでは実行時に文字列が通り抜ける
- **Serializer/Domainモデルフィールド不一致** — APIレスポンスのフィールド名がDomainエンティティと整合しているか
- **QuerySet 戻り値型の明示** `[新観点 from PR#480]` - `# type: ignore[return]` で型チェックを回避していないか確認。CLAUDE.md「型ヒント必須」に従い `QuerySet[Model]` の戻り値型を明示すること。
- **Serializer SerializerMethodField の戻り値型精度** `[新観点 from PR#480]` - `SerializerMethodField` のメソッドで `Optional[str]` を返しているが、渡すフィールドが non-Optional な場合は `str` に絞れる。エンティティのフィールド定義と照合して型精度を上げること。
- **EventStream型定義の網羅性** `[新観点 from PR#486]` — AWS Bedrock等の外部サービスのストリームイベント型が、チャンクだけでなく例外イベント型も含んでいるかチェック。TypeDictのtotal=Falseの適切な使用。

### Security（詳細）

- **トークン無効化** — パスワード変更・ログアウト時にトークンが適切に無効化されているか

### Validation & Error Handling（詳細）

- **バリデーション実行順序** — 削除・更新処理の前にバリデーションが実行されているか。副作用の後にチェックをしていないか
- **正規化後の再バリデーション** — 入力値を正規化・変換した後に結果が有効か再検証しているか
- **validate_\<field\>サニタイズ後の空文字チェック** `[新観点 from PR#520]` — validate_\<field\>メソッドで制御文字除去・trim等のサニタイズを行う場合、サニタイズ後の値が空文字になるケースを考慮しているか確認する。DRFのallow_blank/requiredチェックはvalidate_\<field\>より先に実行されるため、サニタイズ後の空文字はDRFでは検出できない。明示的な空文字チェックとValidationErrorの発生が必要
- **年の範囲チェック** — `year <= 0`のみで1900-9999の範囲チェックが漏れていないか（→ `references/code-examples.md`）
- **frozen dataclassの`__post_init__`バリデーション** — 不正な値でインスタンスが作られないよう、`item_name`の非空・`year`の範囲等を`__post_init__`内で`ValidationError`を使って検証（→ `references/code-examples.md`）
- **frozen dataclass不変条件の網羅性** `[新観点 from PR#469]` — __post_init__で全フィールドがバリデーションされているか確認する。特にプリミティブ型(int, str)は型ヒントがあるだけでは不十分。エンティティの全属性に対して不変条件検証が必要
- **エンティティ不変条件の空白チェック** `[新観点 from PR#480]` — ドメインエンティティの `__post_init__` で `not self.field` ではなく `not self.field.strip()` を使っているか確認。空白のみ入力を通過させるバグを防ぐ。エラーメッセージが定数化されているかも併せて確認
- **`from_string()`/enum変換の入力型チェック** — `isinstance(value, str)` チェックがないと`int`や`None`で`AttributeError`になる（→ `references/code-examples.md`）
- **`reconstruct()`でのUUID型不変条件の未検証** — `isinstance(field, UUID)` チェックがないとDB破損データがDomainに混入する
- **`reconstruct()` 内 Enum 変換の例外保護** `[新観点 from PR#480]` — `SomeEnum(value)` 形式の Enum 変換は不正な値で `ValueError` を送出する。`reconstruct()` 内で変換する場合は `try/except ValueError` で保護し、エラーを明示的に再送出すること。Repository の `except DatabaseError` では `ValueError` は捕捉されないため Result 契約が崩れる
- **Repository の except 節での ValueError 捕捉** `[新観点 from PR#480]` — `except DatabaseError as exc: return failure(exc)` は mapper 由来の `ValueError` を捕捉しない。mapper（`model_to_entity` 等）が送出する例外も Result に包むため `except (DatabaseError, ValueError) as exc:` にすること
- **例外チェーンの `from exc`** `[新観点 from PR#480]` — `except ValueError as exc: raise ... from exc` パターンを使用しているか確認。`from exc` がないとトレースバック情報が失われデバッグ困難になる
- **エラーメッセージと正規表現の整合性** — エラーメッセージに記載した許容値範囲が実際の`RegexValidator`パターンと一致しているか
- **月文字列のint変換による形式ロス** `[新観点 from PR#469]` — MM形式の月文字列をint()変換して再ゼロパディングするパターンを検出する。「1」→1→「01」の暗黙正規化で入力バリデーションが無効化される。月操作はstr→str変換で行うべき
- **UseCase層の引数整合性ガード** `[新観点 from PR#472]` — 引数間の依存関係がある場合（例: category_typeとsub_category_id/large_item_id）、UseCase層でも防御的に検証しているかチェックする。Presentation層でバリデーションしていてもUseCase層は独立したインターフェースとして整合性を保証すべき。引数の組み合わせ制約はUseCase.execute()の冒頭でガードする
- **UseCaseの値域検証** `[新観点 from PR#476]` - UseCaseでIDパラメータの`None`チェックに加えて値域（`<= 0`など）の検証も行っているか。View層で検証されていてもUseCaseは独立したビジネスロジック単位として自己完結すべきなため、直接呼び出し経路でも不正入力を拒否できるよう値域検証を追加すること。
- **Presentation層のエラーメッセージ定数化** `[新観点 from PR#476]` - ヘルパー関数内の`raise ValueError(f"...")`等のインラインエラーメッセージが定数化されているか。CLAUDE.mdルール「エラーメッセージ定数化」に従い、`SummaryErrors`等の定数クラス経由にすること。またPresentationヘルパーで発生する例外はView層でキャッチして`ApiResponse.error`に変換すること。
- **assert文の本番使用禁止** `[新観点 from PR#486]` — python -Oで無効化されるassertをバリデーションに使っていないかチェック。明示的なif文+エラーレスポンスに置き換える。
- **SSEジェネレータの例外捕捉範囲チェック** `[新観点 from PR#486]` — ストリーミングレスポンスのジェネレータでは、特定例外のみ捕捉すると他の例外でストリームが無言で途切れる。GeneratorExit以外を包括的に捕捉し、クライアントにエラーイベントを送信すること
- **エラー種別の識別精度** `[新観点 from PR#486]` — isinstanceだけでなく、エラーメッセージやカスタム例外で具体的なエラー種別を判別しているか確認する。一律マッピングは原因隠蔽を招き、ユーザーに不適切なエラーメッセージが返される
- **キャッシュロック解放漏れ** `[新観点 from PR#486]` — キャッシュロック取得後〜ストリーム開始前の同期コードで例外が発生した場合のロック解放を確認する。try/exceptで保護しないとロックが残存し、TTL期限までリクエストがブロックされる
- **入力IDの早期バリデーション** `[新観点 from PR#522]` — View で外部入力（session_id 等のID参照）を受け取る場合、DB参照・ペイロード構築等の重い処理の前に軽量なバリデーション（存在確認・権限確認）を先行させているかをチェックする。無効な入力で重い処理が走るとリソースの無駄になる

### Database Performance（詳細）

- **Bulk操作** — 複数レコードの作成・更新時に`bulk_create()`/`bulk_update()`を使用しているか
- **Admin list_displayでのN+1** — `list_display`に集計表示がある場合、`get_queryset()`で`annotate(Count(...))`しているか
- **ページネーションの副キー** `[新観点 from PR#480]` — `order_by` が単一カラムの場合、同値タイブレーカー不在で重複・取りこぼしが起きる。PKを副キーに追加して安定ソートにする
- **management commandでのDB側フィルタリング** `[新観点 from PR#510]` — management commandでも大量データの可能性を考慮し、DB側フィルタリング（Exists subquery等）を優先する。Python側でset差分を取る前に、SQLレベルで絞り込めないか検討する。iterator(chunk_size)で逐次取得してメモリ圧迫を回避する

### Test Quality（詳細）

- **`@pytest.fixture`の活用** — `setup_method`ではなく`@pytest.fixture`を使って共通フィクスチャを切り出す。4箇所以上の重複はDRY違反
- **CSRFテスト有効化** — `csrf_protect`を使うViewのテストは`APIClient(enforce_csrf_checks=True)`で実運用と同条件に（→ `references/code-examples.md`）
- **テストデータの独立性** — テスト間で共有される可変なdict・listがないか
- **`interaction`検証テストで`execute()`の戻り値も確認** — `mock.assert_called_once()` だけでなく `result, error = usecase.execute()` でアンパックして `assert error is None` まで検証（→ `references/code-examples.md`）
- **`count()`のみのアサーションは不十分** — `assert Model.objects.count() == 1` だけでなく、特定行の存在も確認
- **異常系テストでDB不変性を検証** — 例外発生テストで `assert Model.objects.count() == 0` のようにDB不変性まで検証
- **テストヘルパーの`conftest.py`共通化** — 3箇所以上で同一ヘルパーが重複しているなら`conftest.py`に共通化
- **リポジトリテストのクエリ数検証一貫性** `[新観点 from PR#469]` — DBアクセスを伴うリポジトリテストでdjango_assert_num_queriesが統一的に使用されているか確認する。空結果テストでも省略しない
- **ファクトリのデフォルト値とモデル制約の整合性** `[新観点 from PR#472]` — テストファクトリのデフォルト値がモデルの`CheckConstraint`に違反していないか確認する。特にpolymorphic FKパターン（category_type + FK）では、デフォルトの組み合わせが制約条件を満たすこと
- **バリデーション追加時の失敗系テスト** `[新観点 from PR#472]` — UseCase/Repository層にバリデーションを追加した際、失敗パスのテストも同時に追加しているかチェックする。正常系テストだけではバリデーションの実効性が保証されない。各ガード条件に対応する回帰テストを作成する
- **Factory traitの活用** `[新観点 from PR#472]` — テストでFactoryのフィールドを直接指定している場合、既存traitで同等の設定ができないかチェックする。trait（例: for_large_item=True）を使うことでFactory定義の変更に自動追従でき、テストの保守性が向上する
- **テストフィクスチャのCSRF設定** `[新観点 from PR#472]` — 新規テストファイルでAPIClientフィクスチャを独自定義する際、conftest.pyの規約（enforce_csrf_checks=True + CSRFトークン設定）を踏襲しているかチェックする。GETのみのテストでも規約統一のためCSRFを有効化する
- **DIテスト配線検証** `[新観点 from PR#472]` — DIテストでは型チェック（isinstance）だけでなく依存配線の検証まで含めるべき。同ファイル内の既存DIテストパターンとの一貫性をチェックし、resolve後のインスタンスが正しい依存を持つことまで確認する
- **APIコントラクトテスト網羅性** `[新観点 from PR#472]` — APIコントラクトテストではレスポンスシリアライザの全フィールドをカバーすべき。新フィールド追加時に既存テストの更新漏れを検出するため、レスポンスbodyのキー一覧とシリアライザのfields定義を突合する
- **テストヘルパーMUSTルール準拠** `[新観点 from PR#472]` — 新規テスト作成時にCODING_STANDARDS.md 9.3のテストヘルパー利用MUSTルールに準拠しているか確認する。既存のconftest.pyヘルパーやFactoryを使わず独自にセットアップしている箇所を検出する
- **テストモックの `create_autospec`** `[新観点 from PR#480]` — ABCやProtocolが定義されたリポジトリを `Mock()` でモックしている場合、`create_autospec(Repository, instance=True)` に置換すべき。シグネチャ検証でリファクタ退行を検知
- **バリデーションテストのエラー値検証** `[新観点 from PR#480]` — `assert error is not None` だけでなく `str(error) == ErrorConstants.XXX` で具体的な値を検証。別エラーへの退行を検知する
- **統合テストのクエリバジェット統一** `[新観点 from PR#480]` — 一覧エンドポイントにクエリ上限があるなら詳細エンドポイントにも `django_assert_max_num_queries` を設定。N+1退行を検知するため全エンドポイントに統一して適用する
- **mock の autospec 設定** `[新観点 from PR#496]` - テストで外部ライブラリ（boto3等）をmockする際に `autospec=True` が設定されているかチェックする。autospecにより実際のインターフェースと一致しない呼び出しを早期検出できる。

### Code Organization & DRY（詳細）

- **DRY原則違反** — 同一・類似のヘルパーメソッドやバリデーションロジックが複数箇所に存在
- **入力型だけ異なる同一アルゴリズムの重複** `[新観点 from PR#469]` — 入力型が異なるだけでロジックが同一の関数ペアがないか確認する。型変換部分を分離して共通化すべき。2箇所でもメンテリスクがある
- **メソッド間の同一集計再計算** `[新観点 from PR#469]` — メインメソッドで作成した集計結果(dict等)をサブメソッドに渡さず再計算していないか確認する。O(n)走査の不要な繰り返しを防ぐ
- **同一Repository呼び出しのprivate メソッド抽出** — `save()`と`find_*()`で同じ`Entity.reconstruct(...)`が重複している場合、`_to_entity(obj)`に抽出
- **dict comprehensionの重複キー上書きバグ** — `{key: value for ...}`は同一キーで後の値が上書きされる。集計が必要な場合は加算ループに変更（→ `references/code-examples.md`）
- **サイレントドロップより明示的エラー返却** — list comprehension内のNoneフィルタでデータを捨てるのは危険。存在すべきデータが欠損している場合は`failure(ValueError(...))`を返す（→ `references/code-examples.md`）
- **Moduleレベルシングルトンとインスタンス変数の重複** — ステートレスなCalculator/Serviceの初期化方法を統一する
- **Deprecated API使用** — 非推奨のDjango API（例: `CheckConstraint`のclass引数）を使用していないか
- **コメント正確性** — コメントが実際のコードの挙動と一致しているか
- **型アノテーションスタイルの一貫性** — `Union[A, B]`と`A | B`が混在していないか
- **到達不能コードの検出** `[新観点 from PR#486]` — 防御ガード（`if not x: return`）が上流のバリデーションで到達不能になっていないかチェック。冗長な防御コードはテストカバレッジを下げ保守コストを増やす。
- **設定値マジックナンバーの定数化** `[新観点 from PR#486]` — TTL・タイムアウト等のビジネス設定値がローカル変数にハードコードされていないかチェック。constants/に定義して一元管理する。
- **設定変数の上書き検出** `[新観点 from PR#495]` — settings.pyで条件分岐により変数をインポートした後、同じ変数を無条件に再定義していないかチェック。Pythonでは後続の代入が前の代入を上書きするため、条件付きインポート＋無条件ハードコード定義の組み合わせは常にバグとなる。条件付きインポートが存在する場合、後続の定義も対応するelse/notガードで囲むこと。
- **事前構築データの一貫使用** `[新観点 from PR#522]` — `prepare()` 等で構築したデータを後続処理に渡さず、元の入力を再利用していないかをチェックする。保存用データとストリーム用データの出所が同一であることを確認する。「事前構築 → 使用」の流れで構築結果が一貫して使われていなければ、二重化バグや不整合の原因になる。

### Migration & DB Schema（マイグレーションファイルが変更されている場合）

- **リバースマイグレーション実装** — `reverse_code`がnoopではなく、ロールバック可能な実装か
- **`RunSQL.noop` reverse後に制約消失** `[新観点 from PR#469]` - `RunSQL`でConstraintをDROPする場合、`reverse_sql=RunSQL.noop`だと、ロールバック時に元の制約が復元されない。`reverse_sql`に元の制約を再作成するSQLを明示すること。
- **ロールバックリスク評価** — データ破壊的なマイグレーション（カラム削除、型変更等）にデータ保全策があるか
- **マイグレーション内のBulk操作** — 大量データ更新時に`bulk_update()`やiteratorの`chunk_size`指定を使用しているか
- **複合インデックスで代替可能な単一`db_index`** — `['company', 'year', 'month']`のような複合インデックスが存在する場合、`year`・`month`への個別`db_index=True`は冗長
- **一意制約追加前の重複データ検証** `[新観点 from PR#480]` — `unique=True` を追加する migration で、既存の重複データを事前チェックする `RunPython` がないと本番適用時に `IntegrityError` が発生する。`RunPython` で重複を検出して `RuntimeError` で停止するか、重複解消ロジックを含めること
- **`update_or_create()`はfull_clean()を呼ばない** → `Meta.constraints`に`CheckConstraint`を追加してDB側でも制約すること。特に`CharField`の正規表現バリデーションや`IntegerField`の範囲バリデーションが対象（→ `references/code-examples.md`）
- **Migration インポート位置** `[新観点 from PR#480]` - `django.db.models` の汎用クラス（Count など）は関数内ではなくモジュールトップでインポートする。モデル取得（`apps.get_model()`）は関数内が必須だが、汎用クラスはトップレベルで OK。

---

## Red Flags - Never Do This

- 重要度インジケーターを省略
- actionableな修正案なしにフィードバック
- Core Checklistの項目をスキップ
- `Any`型の使用を見逃す
- N+1クエリ問題・`SELECT *`問題を見逃す
- Result型の`_`でのエラー無視を見逃す
- テスト命名規約の順序違反・クラスベーステストを見逃す
- コードdiffなしに修正案を提示
