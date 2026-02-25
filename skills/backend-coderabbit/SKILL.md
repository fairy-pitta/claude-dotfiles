---
name: backend-coderabbit
description: Backend専用 CodeRabbit-style code review - Django/DDD/Clean Architectureの観点で体系的・網羅的にレビュー。FSDフロントエンドは対象外。
---

# Backend CodeRabbit Review

Django + Clean Architecture/DDDのバックエンドコードをCodeRabbitスタイルで体系的にレビューする。

**Announce at start:** "I'm using the backend-coderabbit skill to perform a comprehensive backend code review."

**Data source:** 431 backend inline comments from 33 PRs (recent 40 PRs analyzed)

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

## Review Focus Areas

### 1. Architecture Compliance（アーキテクチャ準拠）`[最多頻出]`

依存方向: `Presentation → Application → Domain ← Infrastructure`

- **Feature間直接依存** - 通常Feature間の直接import（例: journal→accounting）が存在しないか。`shared/types/`経由が必要。許可: 全Feature→shared/, 全Feature→user/organization（基盤Feature）
- **Domain層の純粋性** - Domain層（entities, repositories, enums）がDjango/DRFに依存していないか。`QuerySet`・`Model`・ページングのデフォルト値などインフラ概念がDomainに混入していないか
- **DomainRepositoryがDTOに依存するのはNG** `[新観点]` - `AuthUserPayload`等のPresentation/Application DTOをDomain層のRepositoryが返してはいけない。ドメインモデル/VOを返し、UseCase側でDTOへ変換すること
- **Presentation→Infrastructure直接依存** - ViewやSerializerがRepositoryImplやAPI関数を直接参照していないか。UseCase経由のアクセスになっているか
- **Transaction管理の配置** - `transaction.atomic()`がUseCase層でのみ管理されているか。Repository層でのトランザクション禁止
- **1 class = 1 file** - 各クラスが独自のファイルに配置されているか

```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】DomainのRepositoryがPresentation DTO（AuthUserPayload）に依存しています**

`AuthUserPayload`はLogin/WhoAmIのレスポンス形でPresentation/Applicationの関心事です。
Domain層のRepositoryがDTOを返すと依存方向が逆転し、API変更がDomainに波及します。
ドメインモデル/VOを返し、UseCase側でDTOへ変換してください。

<details>
<summary>🔧 修正案</summary>

```diff
- from app.features.user.types import AuthUserPayload
  class UserRepository(Protocol):
-     def find_by_id(self, user_id: int) -> AuthUserPayload | None: ...
+     def find_by_id(self, user_id: int) -> User | None: ...
```
</details>
```

### 2. Type Safety（型安全性）`[高頻度]`

- **型ヒント必須** `[10回/261タイトル]` - すべての関数・メソッドに型ヒントを付与。`Any`型は禁止 → `Protocol`/`TypedDict`/`Generic`で代替
- **Result型タプルアンパック** `[6回]` - `result, error = usecase.execute()`の形式が必須。`.error`属性アクセス禁止
- **`_`でエラー無視はNG** `[新観点]` - `value, _ = usecase.execute()`でエラーを捨てると認可チェックが消えてバグの原因になる。必ずエラーを変数に受けてチェックすること
  ```python
  # ❌ Bad: エラーを無視
  assignment, _ = create_assignment(...)

  # ✅ Good: エラーを受けてチェック
  assignment, error = create_assignment(...)
  if error:
      raise error
  ```
- **Enum必須** `[6回]` - ステータス値・カテゴリ値に文字列リテラル禁止。`TextChoices`/`IntegerChoices`を使用
- **ドメインエンティティのEnum型引数の実行時型検証** `[新観点 from PR#465]` - `create()` 等のファクトリメソッドでEnum型パラメータを受け取る場合、`isinstance(x, SomeEnum)` の実行時チェックがあるか確認。型ヒントだけでは実行時に文字列等が通り抜けてバリデーションをすり抜ける。
- **Serializer/Domainモデルフィールド不一致** - APIレスポンスのフィールド名がDomainエンティティと整合しているか。存在しないフィールドがSerializerに定義されていないか

### 3. Security & Authorization（セキュリティ・認可）

- **permission_classes明示設定** - DRF Viewに`permission_classes`が必ず明示されているか。デフォルト依存によるセキュリティホール防止
- **認可バイパス経路** - Result型の誤用やエラーハンドリング不備により認可チェックがスキップされる経路がないか
- **write_only on sensitive fields** - パスワード等の機密フィールドに`write_only=True`が設定されているか
- **トークン無効化** - パスワード変更・ログアウト時にトークンが適切に無効化されているか

```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】`permission_classes` を明示的に設定してください**

DRFのデフォルト設定に依存すると、設定変更時に意図しないアクセス許可が発生します。

<details>
<summary>🔧 修正案</summary>

```diff
  class EmailVerificationView(APIView):
+     permission_classes = [AllowAny]
```
</details>
```

### 4. Error Messages & Constants（エラーメッセージ・定数）`[最多頻出: 定数21回/エラーメッセージ17回]`

- **エラーメッセージ定数化** - 文字列リテラルでエラーメッセージを直接記述していないか。`app/shared/constants/`等の定数ファイルで管理
- **`logger`/`print`禁止** - `logger`や`print`（マイグレーションbackward含む）の使用禁止。例外伝播またはResult型で処理
- **マジックナンバー・マジック文字列** - 直書きの数値・文字列リテラルを定数化

```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】エラーメッセージを定数化してください**

`"有効な会社IDが必要です。"`が2箇所で文字列リテラルとして使用されています。

<details>
<summary>🔧 修正案</summary>

```diff
+ # app/shared/constants/error_messages.py
+ COMPANY_ID_REQUIRED = "有効な会社IDが必要です。"

- raise ValueError("有効な会社IDが必要です。")
+ raise ValueError(ErrorMessages.COMPANY_ID_REQUIRED)
```
</details>
```

### 5. Database Performance（DB性能）`[N+1: 7回]`

- **N+1クエリ** - ループ内でDBクエリを実行していないか。`select_related()`/`prefetch_related()`の適用漏れ
- **`SELECT *`禁止** `[新観点]` - `select_related(...).get()`は全カラム取得になり、ガイドラインの「SELECT * 禁止」に抵触。Serializerで使う項目に`.only()`/`.values()`で絞り込む
  ```python
  # ❌ Bad
  user = User.objects.select_related('default_role_grant__role').get(pk=user_id)

  # ✅ Good
  user = User.objects.select_related('default_role_grant__role').only(
      'id', 'email', 'default_role_grant__role__code'
  ).get(pk=user_id)
  ```
- **Bulk操作** - 複数レコードの作成・更新時に`bulk_create()`/`bulk_update()`を使用しているか
- **Admin list_displayでのN+1クエリ** `[新観点 from PR#465]` - `list_display` にカウントや集計を表示するメソッドがある場合、`get_queryset()` で `annotate(Count(...))` しているか確認。ループ内での `.count()` / `.all()` 呼び出しはN+1の原因になる。

### 6. Validation & Error Handling（バリデーション・エラーハンドリング）

- **バリデーション網羅性** - 重複チェック・既使用チェック・必須項目チェック等の漏れ
- **エッジケース考慮** - 同時リクエスト・タイミング問題・境界値（`<=` vs `<`）
- **バリデーション実行順序** - 削除・更新処理の前にバリデーションが実行されているか。副作用の後にチェックをしていないか
- **正規化後の再バリデーション** - 入力値を正規化・変換した後に結果が有効か再検証しているか。例: `normalize_month_params()`後に空配列になるケースをエラーとして弾く
- **年の範囲チェック** - `year <= 0`のみで1900-9999の範囲チェックが漏れていないか
- **frozen dataclassの__post_init__バリデーション不足** `[新観点 from PR#465]` - `@dataclass(frozen=True)` のエンティティで `__post_init__` が定義されていない場合、不正な値でインスタンスが作られる可能性がある。`item_name`の非空・`year`の範囲・`month`/`relative_month`の正規表現など、ドメインルールをすべて `__post_init__` 内で `ValidationError` を使って検証すること。
- **from_string/enum変換メソッドの入力型チェック不足** `[新観点 from PR#465]` - `from_string(value)` で `isinstance(value, str)` チェックを行わないと、`int`や`None`が渡された場合に `AttributeError` になる。`strip()` の呼び出し前に必ず型チェックを行い、非文字列なら `ValueError` を上げること。

```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】yearの範囲(1900〜9999)の検証が不足しています**

`year <= 0`のみチェックされ、1899や10000が通過します。

<details>
<summary>🔧 修正案</summary>

```diff
+ MIN_YEAR = 1900
+ MAX_YEAR = 9999
+
  if year <= 0:
      return failure(ValueError(ValidationErrors.YEAR_FORMAT_INVALID))
+ if year < MIN_YEAR or year > MAX_YEAR:
+     return failure(ValueError(ValidationErrors.YEAR_OUT_OF_RANGE))
```
</details>
```

### 7. Test Quality（テスト品質）`[テスト: 42回 - 最多頻出]`

- **pytestスタイル** `[4 PR]` - `class TestXxx`ではなく`def test_xxx()`の関数ベース。`Mock(spec=...)`で型安全なモック
- **テスト名命名規約・順序** `[新観点: 複数PR]` - `test_<動作>_<条件>_<期待結果>`の順序が必須。`_for_<条件>`の後置形式はNG
  ```python
  # ❌ Bad: 期待結果が読み取れない
  def test_calculate_signed_amounts_debit_bs_debit_posting()

  # ❌ Bad: 順序がガイドラインと逆
  def test_save_assignment_execute_creates_default_format_for_yayoi()

  # ✅ Good: 動作_条件_期待結果
  def test_save_assignment_execute_for_yayoi_creates_default_format()
  ```
- **`@pytest.fixture`の活用** `[新観点]` - `setup_method`ではなく`@pytest.fixture`を使って共通フィクスチャを切り出す。4箇所以上で同じsetupコードが重複しているならDRY違反
- **CSRFテスト有効化** `[新観点]` - `csrf_protect`を使うViewのテストは`APIClient(enforce_csrf_checks=True)`で実運用と同条件にすること。CSRFを無効にするとテストが偽陽性になる
- **正常系カバレッジ** - 異常系テストのみで正常系が抜けていないか
- **テストデータの独立性** - テスト間で共有される可変なdict・listがないか。テスト汚染を防ぐ
- **テストはクラスベース禁止・関数ベース必須** `[新観点 from PR#465]` - 新規テストファイルでクラスを使っていないか確認。`class TestXxx:` の形式は禁止。すべて `def test_xxx():` のモジュールレベル関数で記述すること。
- **テスト名は英語必須** `[新観点 from PR#465]` - テスト関数名に日本語を使っていないか確認。`test_<subject>__<condition>__<expected>` 形式の英語名を使うこと。

```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】ログイン系テストでCSRFを有効化しないと実運用と乖離します**

`LoginView`は`csrf_protect`なので、CSRF無効の`APIClient`だと成功してしまいテストが偽陽性になります。

<details>
<summary>🔧 修正案</summary>

```diff
- def test_login_returns_default_role_code(self, api_client: APIClient):
+ def test_login_returns_default_role_code():
+     csrf_client = APIClient(enforce_csrf_checks=True)
+     # CSRFトークン取得
+     response = csrf_client.get(reverse('csrf'))
+     csrf_token = response.cookies['csrftoken'].value
+     csrf_client.credentials(HTTP_X_CSRFTOKEN=csrf_token)
```
</details>
```

### 8. Unused Code Detection（未使用コード）

- 呼び出されていない関数・メソッド
- 未使用のinterface・型定義・定数
- 未使用import
- 削除されたコードと連鎖して孤立した定義

### 9. Code Organization & DRY

- **DRY原則違反** - 同一・類似のヘルパーメソッドやバリデーションロジックが複数箇所に存在
- **コード意図の明確さ** - 変数名・メソッド名・コメントから意図が読み取れるか
- **Deprecated API使用** - 非推奨のDjango API（例: `CheckConstraint`のclass引数）を使用していないか
- **コメント正確性** - コメントが実際のコードの挙動と一致しているか
- **型アノテーションスタイルの一貫性** - `Union[A, B]`と`A | B`が混在していないか。PEP 604対応済みプロジェクトでは`|`構文に統一
- **同一Repository呼び出しのprivateメソッド抽出** `[新観点 from PR#465]` - `save()`と`find_*()`で同じ `Entity.reconstruct(...)` の呼び出しが重複している場合、`_to_entity(obj)` のようなprivate staticメソッドに抽出してDRYを達成する。Infrastructure層のRepositoryImplで特に頻出するパターン。
- **dict comprehensionの重複キー上書きバグ** `[新観点 from PR#465]` - `{(e.year, e.month): e.figure for e in entries if ...}` のようなdict comprehensionは同一キーが複数存在すると後の値で上書きされてデータが消える。集計が必要な場合は加算ループ `result[key] = result.get(key, 0) + e.figure` に変更すること。
- **サイレントドロップより明示的エラー返却** `[新観点 from PR#465]` - `if name := map.get(id) is not None` のようなlist comprehension内のNoneフィルタでデータをサイレントにドロップするのは危険。存在すべきデータが欠損している場合はエラーを返すべき。特にマスターデータとの突合処理ではドロップではなく`failure(ValueError(...))`を返すこと。
- **Moduleレベルシングルトンとインスタンス変数の重複** `[新観点 from PR#465]` - ステートレスなCalculatorやServiceが一部はモジュールレベルシングルトン（`_calc = Calculator()`）、一部は`__init__`でインスタンス変数として初期化されている場合は統一する。モジュールレベルシングルトンに統一してメモリ節約と一貫性を確保すること。
- **テストヘルパーのconftest.py共通化** `[新観点 from PR#465]` - 複数のテストファイルで同一の`_make_entry`/`_make_fixture`ヘルパーが定義されている場合、同ディレクトリの`conftest.py`に共通化してimportで使い回す。3箇所以上での重複は必ず指摘すること。

### 10. Migration & DB Schema（マイグレーション）

- **リバースマイグレーション実装** - `reverse_code`がnoopではなく、ロールバック可能な実装か
- **ロールバックリスク評価** - データ破壊的なマイグレーション（カラム削除、型変更等）にデータ保全策があるか
- **マイグレーション内のBulk操作** - 大量データ更新時に`bulk_update()`やiteratorの`chunk_size`指定を使用しているか
- **`logger`/`print`をマイグレーションのbackwardに使わない** - マイグレーションのbackward関数内でloggerやprintを使わない
- **複合インデックスで代替可能な単一db_index** `[新観点 from PR#465]` - `['company', 'year', 'month']` のような複合インデックスが存在する場合、`year`や`month`フィールドへの個別`db_index=True`は冗長。複合インデックスの左端に含まれないカラムに単独インデックスがある場合は指摘し削除を推奨する。

### 11. Syntax & Basic Quality（構文・基本品質）

- **構文エラー** - importの括弧閉じ忘れ、重複パラメータ定義、未解決のマージコンフリクトマーカー（`<<<<<<<`）
- **命名規約** - CLAUDE.mdの命名規約準拠（`{action}_{entity}_usecase.py`, `{Entity}RepositoryImpl`等）
- **型アノテーション一貫性** - 同一ファイル内でスタイルが混在しないか

---

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^backend/"
```

### 2. Analyze Each File

各backendファイルに対して以下を確認:
1. Architecture Compliance（Feature依存, Domain純粋性, DTO依存方向）
2. Type Safety（Any型, Result型アンパック, `_`無視, Enum）
3. Security（permission_classes, write_only, 認可バイパス）
4. Error Messages & Constants（文字列リテラル, logger禁止）
5. Database Performance（N+1, SELECT*, bulk操作）
6. Validation & Error Handling（網羅性, エッジケース, 正規化後チェック）
7. Test Quality（pytest命名・順序, fixture, CSRF, 正常系）
8. Unused Code Detection
9. Code Organization & DRY
10. Migration & DB Schema
11. Syntax & Basic Quality

### 3. Generate Summary

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

## Red Flags - Never Do This

- 重要度インジケーターを省略
- actionableな修正案なしにフィードバック
- アーキテクチャ違反をスルー
- `Any`型の使用を見逃す
- N+1クエリ問題を見逃す
- `SELECT *`問題を見逃す
- Result型の`_`でのエラー無視を見逃す
- テスト命名規約の順序違反を見逃す
- コードdiffなしに修正案を提示
