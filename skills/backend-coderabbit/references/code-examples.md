# Backend CodeRabbit - コード例示集

## Architecture Compliance

### DomainRepositoryがPresentation DTOに依存するのはNG

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

---

## Type Safety

### `_`でエラーを無視するのはNG

```python
# ❌ Bad: エラーを無視（認可チェックが消える）
assignment, _ = create_assignment(...)

# ✅ Good: エラーを受けてチェック
assignment, error = create_assignment(...)
if error:
    raise error
```

---

## Security & Authorization

### permission_classes の明示設定

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

---

## Error Messages & Constants

### エラーメッセージの定数化

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

---

## Database Performance

### SELECT * 禁止

```python
# ❌ Bad: 全カラム取得
user = User.objects.select_related('default_role_grant__role').get(pk=user_id)

# ✅ Good: 必要なカラムのみ
user = User.objects.select_related('default_role_grant__role').only(
    'id', 'email', 'default_role_grant__role__code'
).get(pk=user_id)
```

---

## Validation & Error Handling

### yearの範囲チェック

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

### frozen dataclassの__post_init__バリデーション

```python
# ❌ Bad: バリデーションなし
@dataclass(frozen=True)
class JournalItem:
    item_name: str
    year: int
    month: str

# ✅ Good: __post_init__で全ドメインルールを検証
@dataclass(frozen=True)
class JournalItem:
    item_name: str
    year: int
    month: str

    def __post_init__(self) -> None:
        if not self.item_name:
            raise ValidationError("item_name is required")
        if not (MIN_YEAR <= self.year <= MAX_YEAR):
            raise ValidationError("year out of range")
        if not re.match(r'^\d{4}-(0[1-9]|1[0-3])$', self.month):
            raise ValidationError("invalid month format")
```

### from_string/enum変換メソッドの入力型チェック

```python
# ❌ Bad: 型チェックなし（intやNoneでAttributeError）
@classmethod
def from_string(cls, value: str) -> "MyEnum":
    return cls(value.strip())

# ✅ Good: 型チェック後にstrip
@classmethod
def from_string(cls, value: str) -> "MyEnum":
    if not isinstance(value, str):
        raise ValueError(f"Expected str, got {type(value)}")
    return cls(value.strip())
```

---

## Test Quality

### テスト命名規約（動作_条件_期待結果）

```python
# ❌ Bad: 期待結果が読み取れない
def test_calculate_signed_amounts_debit_bs_debit_posting()

# ❌ Bad: 順序がガイドラインと逆
def test_save_assignment_execute_creates_default_format_for_yayoi()

# ✅ Good: 動作_条件_期待結果
def test_save_assignment_execute_for_yayoi_creates_default_format()
```

### CSRFテスト有効化

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
+     response = csrf_client.get(reverse('csrf'))
+     csrf_token = response.cookies['csrftoken'].value
+     csrf_client.credentials(HTTP_X_CSRFTOKEN=csrf_token)
```
</details>
```

### interaction検証 + 戻り値の確認

```python
# ❌ Bad: interactionのみ確認（戻り値未チェック）
mock_service.method.assert_called_once()

# ✅ Good: interactionと戻り値を両方確認
result, error = usecase.execute(journal_id)
assert error is None
assert result is not None
mock_service.method.assert_called_once()
```

---

## Code Organization & DRY

### dict comprehensionの重複キー上書きバグ

```python
# ❌ Bad: 同一キーが複数あると後の値で上書き
totals = {(e.year, e.month): e.figure for e in entries if ...}

# ✅ Good: 加算ループ
totals: dict[tuple[int, str], int] = {}
for e in entries:
    key = (e.year, e.month)
    totals[key] = totals.get(key, 0) + e.figure
```

### サイレントドロップより明示的エラー返却

```python
# ❌ Bad: データをサイレントにドロップ
items = [map[id] for id in ids if map.get(id) is not None]

# ✅ Good: 存在しない場合はエラーを返す
for id in ids:
    if (item := map.get(id)) is None:
        return failure(ValueError(f"item not found: {id}"))
    items.append(item)
```

---

## Migration & DB Schema

### update_or_create()はfull_clean()を呼ばない → CheckConstraint必須

```python
# ❌ Bad: アプリ層のバリデーションのみ
class MyModel(Model):
    month = CharField(validators=[RegexValidator(r'^(0[1-9]|1[0-3])$')])

# ✅ Good: DB側にもCheckConstraintで保証
class MyModel(Model):
    month = CharField()

    class Meta:
        constraints = [
            CheckConstraint(
                check=Q(month__regex=r'^(0[1-9]|1[0-3])$'),
                name='valid_month_format',
            )
        ]
```
