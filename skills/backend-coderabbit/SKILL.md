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
- [ ] **1 class = 1 file** — 各クラスが独自のファイルに配置されているか

### Type Safety

- [ ] **型ヒント必須・Any禁止** — すべての関数・メソッドに型ヒントを付与。`Any`型は禁止 → `Protocol`/`TypedDict`/`Generic`で代替
- [ ] **Result型タプルアンパック** — `result, error = usecase.execute()`の形式が必須。`.error`属性アクセス禁止
- [ ] **`_`でエラー無視はNG** — `value, _ = usecase.execute()`でエラーを捨てると認可チェックが消える。必ずエラーを変数に受けてチェック（→ `references/code-examples.md`）
- [ ] **Enum必須** — ステータス値・カテゴリ値に文字列リテラル禁止。`TextChoices`/`IntegerChoices`を使用

### Security & Authorization

- [ ] **permission_classes明示設定** — DRF ViewにPermissionが必ず明示されているか。デフォルト依存禁止（→ `references/code-examples.md`）
- [ ] **認可バイパス経路** — Result型の誤用やエラーハンドリング不備により認可チェックがスキップされる経路がないか
- [ ] **write_only on sensitive fields** — パスワード等の機密フィールドに`write_only=True`が設定されているか

### Error Messages & Constants

- [ ] **エラーメッセージ定数化** — 文字列リテラルでエラーメッセージを直接記述していないか。`app/shared/constants/`で管理（→ `references/code-examples.md`）
- [ ] **`logger`/`print`禁止** — `logger`・`print`（マイグレーションbackward含む）の使用禁止

### Database Performance

- [ ] **N+1クエリ** — ループ内でDBクエリを実行していないか。`select_related()`/`prefetch_related()`の適用漏れ
- [ ] **`SELECT *`禁止** — `select_related(...).get()`は全カラム取得になる。`.only()`/`.values()`で絞り込む（→ `references/code-examples.md`）

### Test Quality（テストファイルが変更されている場合）

- [ ] **関数ベーステスト必須** — `class TestXxx:`禁止。すべて`def test_xxx():`のモジュールレベル関数
- [ ] **テスト名は英語・命名順序** — `test_<動作>_<条件>_<期待結果>`の順序が必須。日本語禁止（→ `references/code-examples.md`）
- [ ] **正常系カバレッジ** — 異常系テストのみで正常系が抜けていないか

### Syntax & Basic Quality

- [ ] **構文エラー** — importの括弧閉じ忘れ、未解決のマージコンフリクトマーカー（`<<<<<<<`）
- [ ] **命名規約** — CLAUDE.md準拠（`{action}_{entity}_usecase.py`, `{Entity}RepositoryImpl`等）
- [ ] **未使用コード** — 未使用の関数・import・型定義・定数がないか

---

## Extended Checklist（変更内容に応じてチェック）

### Architecture（詳細）

- **Presentation→Infrastructure直接依存** — ViewやSerializerがRepositoryImplを直接参照していないか。UseCase経由が必要

### Type Safety（詳細）

- **ドメインエンティティのEnum型引数の実行時型検証** — `create()`等のファクトリメソッドでEnum型パラメータを受け取る場合、`isinstance(x, SomeEnum)` の実行時チェックがあるか。型ヒントだけでは実行時に文字列が通り抜ける
- **Serializer/Domainモデルフィールド不一致** — APIレスポンスのフィールド名がDomainエンティティと整合しているか

### Security（詳細）

- **トークン無効化** — パスワード変更・ログアウト時にトークンが適切に無効化されているか

### Validation & Error Handling（詳細）

- **バリデーション実行順序** — 削除・更新処理の前にバリデーションが実行されているか。副作用の後にチェックをしていないか
- **正規化後の再バリデーション** — 入力値を正規化・変換した後に結果が有効か再検証しているか
- **年の範囲チェック** — `year <= 0`のみで1900-9999の範囲チェックが漏れていないか（→ `references/code-examples.md`）
- **frozen dataclassの`__post_init__`バリデーション** — 不正な値でインスタンスが作られないよう、`item_name`の非空・`year`の範囲等を`__post_init__`内で`ValidationError`を使って検証（→ `references/code-examples.md`）
- **`from_string()`/enum変換の入力型チェック** — `isinstance(value, str)` チェックがないと`int`や`None`で`AttributeError`になる（→ `references/code-examples.md`）
- **`reconstruct()`でのUUID型不変条件の未検証** — `isinstance(field, UUID)` チェックがないとDB破損データがDomainに混入する
- **エラーメッセージと正規表現の整合性** — エラーメッセージに記載した許容値範囲が実際の`RegexValidator`パターンと一致しているか

### Database Performance（詳細）

- **Bulk操作** — 複数レコードの作成・更新時に`bulk_create()`/`bulk_update()`を使用しているか
- **Admin list_displayでのN+1** — `list_display`に集計表示がある場合、`get_queryset()`で`annotate(Count(...))`しているか

### Test Quality（詳細）

- **`@pytest.fixture`の活用** — `setup_method`ではなく`@pytest.fixture`を使って共通フィクスチャを切り出す。4箇所以上の重複はDRY違反
- **CSRFテスト有効化** — `csrf_protect`を使うViewのテストは`APIClient(enforce_csrf_checks=True)`で実運用と同条件に（→ `references/code-examples.md`）
- **テストデータの独立性** — テスト間で共有される可変なdict・listがないか
- **`interaction`検証テストで`execute()`の戻り値も確認** — `mock.assert_called_once()` だけでなく `result, error = usecase.execute()` でアンパックして `assert error is None` まで検証（→ `references/code-examples.md`）
- **`count()`のみのアサーションは不十分** — `assert Model.objects.count() == 1` だけでなく、特定行の存在も確認
- **異常系テストでDB不変性を検証** — 例外発生テストで `assert Model.objects.count() == 0` のようにDB不変性まで検証
- **テストヘルパーの`conftest.py`共通化** — 3箇所以上で同一ヘルパーが重複しているなら`conftest.py`に共通化

### Code Organization & DRY（詳細）

- **DRY原則違反** — 同一・類似のヘルパーメソッドやバリデーションロジックが複数箇所に存在
- **同一Repository呼び出しのprivate メソッド抽出** — `save()`と`find_*()`で同じ`Entity.reconstruct(...)`が重複している場合、`_to_entity(obj)`に抽出
- **dict comprehensionの重複キー上書きバグ** — `{key: value for ...}`は同一キーで後の値が上書きされる。集計が必要な場合は加算ループに変更（→ `references/code-examples.md`）
- **サイレントドロップより明示的エラー返却** — list comprehension内のNoneフィルタでデータを捨てるのは危険。存在すべきデータが欠損している場合は`failure(ValueError(...))`を返す（→ `references/code-examples.md`）
- **Moduleレベルシングルトンとインスタンス変数の重複** — ステートレスなCalculator/Serviceの初期化方法を統一する
- **Deprecated API使用** — 非推奨のDjango API（例: `CheckConstraint`のclass引数）を使用していないか
- **コメント正確性** — コメントが実際のコードの挙動と一致しているか
- **型アノテーションスタイルの一貫性** — `Union[A, B]`と`A | B`が混在していないか

### Migration & DB Schema（マイグレーションファイルが変更されている場合）

- **リバースマイグレーション実装** — `reverse_code`がnoopではなく、ロールバック可能な実装か
- **`RunSQL.noop` reverse後に制約消失** `[新観点 from PR#469]` - `RunSQL`でConstraintをDROPする場合、`reverse_sql=RunSQL.noop`だと、ロールバック時に元の制約が復元されない。`reverse_sql`に元の制約を再作成するSQLを明示すること。
- **ロールバックリスク評価** — データ破壊的なマイグレーション（カラム削除、型変更等）にデータ保全策があるか
- **マイグレーション内のBulk操作** — 大量データ更新時に`bulk_update()`やiteratorの`chunk_size`指定を使用しているか
- **複合インデックスで代替可能な単一`db_index`** — `['company', 'year', 'month']`のような複合インデックスが存在する場合、`year`・`month`への個別`db_index=True`は冗長
- **`update_or_create()`はfull_clean()を呼ばない** → `Meta.constraints`に`CheckConstraint`を追加してDB側でも制約すること。特に`CharField`の正規表現バリデーションや`IntegerField`の範囲バリデーションが対象（→ `references/code-examples.md`）

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
