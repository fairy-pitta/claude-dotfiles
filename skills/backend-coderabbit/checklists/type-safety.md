# Backend Review: Type Safety + Validation & Error Handling

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Type Safety

- [ ] **型ヒント必須・Any禁止** — すべての関数・メソッドに型ヒントを付与。`Any`型は禁止 → `Protocol`/`TypedDict`/`Generic`で代替
- [ ] **Result型タプルアンパック** — `result, error = usecase.execute()`の形式が必須。`.error`属性アクセス禁止
- [ ] **`_`でエラー無視はNG** — `value, _ = usecase.execute()`でエラーを捨てると認可チェックが消える。必ずエラーを変数に受けてチェック（→ `references/code-examples.md`）
- [ ] **Enum必須** — ステータス値・カテゴリ値に文字列リテラル禁止。`TextChoices`/`IntegerChoices`を使用
- [ ] **エラー型判定** — Result型のエラーを文字列比較で分岐していないか確認する。UseCase層で例外型を分類している場合はisinstanceで型判定すべき。文字列比較はメッセージ定数の変更で分岐が壊れるリスクがある
- [ ] **bool⊂int型チェック** — isinstance(x, int)によるバリデーション箇所でboolが通過しないか確認する。Pythonではboolはintのサブクラスのため、isinstance(True, int)がTrueを返す。intチェックの前にisinstance(x, bool)で排除する
- [ ] **同一型の重複定義禁止** — 型の中身が既存の型と同一なのに別名で新たに定義していないか確認する。既存の型定義を検索し、同等の構造がすでにあれば再利用すること
- [ ] **エッジケースの考慮** — 境界値・ゼロ・空・None等のエッジケースが考慮されているか。`<=` vs `<`の取り違え、off-by-oneエラー等に注意
- [ ] **データアクセスの正当性** — 属性・キー・IDへのアクセスが実行時に正当か確認する。関連オブジェクトが存在しない場合のAttributeError/KeyError、外部キーの参照先が削除されているケース等

---

## Extended Checklist

### Type Safety（詳細）

- **ドメインエンティティのEnum型引数の実行時型検証** — `create()`等のファクトリメソッドでEnum型パラメータを受け取る場合、`isinstance(x, SomeEnum)` の実行時チェックがあるか。型ヒントだけでは実行時に文字列が通り抜ける
- **Serializer/Domainモデルフィールド不一致** — APIレスポンスのフィールド名がDomainエンティティと整合しているか
- **QuerySet 戻り値型の明示** - `# type: ignore[return]` で型チェックを回避していないか確認。CLAUDE.md「型ヒント必須」に従い `QuerySet[Model]` の戻り値型を明示すること。
- **Serializer SerializerMethodField の戻り値型精度** - `SerializerMethodField` のメソッドで `Optional[str]` を返しているが、渡すフィールドが non-Optional な場合は `str` に絞れる。エンティティのフィールド定義と照合して型精度を上げること。
- **EventStream型定義の網羅性** — AWS Bedrock等の外部サービスのストリームイベント型が、チャンクだけでなく例外イベント型も含んでいるかチェック。TypeDictのtotal=Falseの適切な使用。
- **DTO型とUseCase分岐の一致性** — UseCaseで条件分岐する場合、DTOの型がその分岐を反映しているかチェック。Optionalで済ませずUnion型で意図を明示する
- **テストヘルパーの型ヒント精度** — テストヘルパー関数の引数型がドメインエンティティやリクエスト型の実際のフィールド型と一致しているか確認する。`object`のような広すぎる型はテストの型安全性を損なう。ドメイン型に合わせて`UUID | None`等の具体型を使う

### Validation & Error Handling（詳細）

- **バリデーション実行順序** — 削除・更新処理の前にバリデーションが実行されているか。副作用の後にチェックをしていないか
- **正規化後の再バリデーション** — 入力値を正規化・変換した後に結果が有効か再検証しているか
- **validate\_\<field\>サニタイズ後の空文字チェック** — validate*\<field\>メソッドで制御文字除去・trim等のサニタイズを行う場合、サニタイズ後の値が空文字になるケースを考慮しているか確認する。DRFのallow_blank/requiredチェックはvalidate*\<field\>より先に実行されるため、サニタイズ後の空文字はDRFでは検出できない。明示的な空文字チェックとValidationErrorの発生が必要
- **年の範囲チェック** — `year <= 0`のみで1900-9999の範囲チェックが漏れていないか（→ `references/code-examples.md`）
- **frozen dataclassの`__post_init__`バリデーション** — 不正な値でインスタンスが作られないよう、`item_name`の非空・`year`の範囲等を`__post_init__`内で`ValidationError`を使って検証（→ `references/code-examples.md`）
- **frozen dataclass不変条件の網羅性** — **post_init**で全フィールドがバリデーションされているか確認する。特にプリミティブ型(int, str)は型ヒントがあるだけでは不十分。エンティティの全属性に対して不変条件検証が必要
- **エンティティ不変条件の空白チェック** — ドメインエンティティの `__post_init__` で `not self.field` ではなく `not self.field.strip()` を使っているか確認。空白のみ入力を通過させるバグを防ぐ。エラーメッセージが定数化されているかも併せて確認
- **`from_string()`/enum変換の入力型チェック** — `isinstance(value, str)` チェックがないと`int`や`None`で`AttributeError`になる（→ `references/code-examples.md`）
- **`reconstruct()`でのUUID型不変条件の未検証** — `isinstance(field, UUID)` チェックがないとDB破損データがDomainに混入する
- **`reconstruct()` 内 Enum 変換の例外保護** — `SomeEnum(value)` 形式の Enum 変換は不正な値で `ValueError` を送出する。`reconstruct()` 内で変換する場合は `try/except ValueError` で保護し、エラーを明示的に再送出すること。Repository の `except DatabaseError` では `ValueError` は捕捉されないため Result 契約が崩れる
- **Repository の except 節での ValueError 捕捉** — `except DatabaseError as exc: return failure(exc)` は mapper 由来の `ValueError` を捕捉しない。mapper（`model_to_entity` 等）が送出する例外も Result に包むため `except (DatabaseError, ValueError) as exc:` にすること
- **例外チェーンの `from exc`** — `except ValueError as exc: raise ... from exc` パターンを使用しているか確認。`from exc` がないとトレースバック情報が失われデバッグ困難になる
- **エラーメッセージと正規表現の整合性** — エラーメッセージに記載した許容値範囲が実際の`RegexValidator`パターンと一致しているか
- **月文字列のint変換による形式ロス** — MM形式の月文字列をint()変換して再ゼロパディングするパターンを検出する。「1」→1→「01」の暗黙正規化で入力バリデーションが無効化される。月操作はstr→str変換で行うべき
- **UseCase層の引数整合性ガード** — 引数間の依存関係がある場合（例: category_typeとsub_category_id/large_item_id）、UseCase層でも防御的に検証しているかチェックする。Presentation層でバリデーションしていてもUseCase層は独立したインターフェースとして整合性を保証すべき。引数の組み合わせ制約はUseCase.execute()の冒頭でガードする
- **UseCaseの値域検証** - UseCaseでIDパラメータの`None`チェックに加えて値域（`<= 0`など）の検証も行っているか。View層で検証されていてもUseCaseは独立したビジネスロジック単位として自己完結すべきなため、直接呼び出し経路でも不正入力を拒否できるよう値域検証を追加すること。
- **Presentation層のエラーメッセージ定数化** - ヘルパー関数内の`raise ValueError(f"...")`等のインラインエラーメッセージが定数化されているか。CLAUDE.mdルール「エラーメッセージ定数化」に従い、`SummaryErrors`等の定数クラス経由にすること。またPresentationヘルパーで発生する例外はView層でキャッチして`ApiResponse.error`に変換すること。
- **assert文の本番使用禁止** — python -Oで無効化されるassertをバリデーションに使っていないかチェック。明示的なif文+エラーレスポンスに置き換える。
- **SSEジェネレータの例外捕捉範囲チェック** — ストリーミングレスポンスのジェネレータでは、特定例外のみ捕捉すると他の例外でストリームが無言で途切れる。GeneratorExit以外を包括的に捕捉し、クライアントにエラーイベントを送信すること
- **エラー種別の識別精度** — isinstanceだけでなく、エラーメッセージやカスタム例外で具体的なエラー種別を判別しているか確認する。一律マッピングは原因隠蔽を招き、ユーザーに不適切なエラーメッセージが返される
- **キャッシュロック解放漏れ** — キャッシュロック取得後〜ストリーム開始前の同期コードで例外が発生した場合のロック解放を確認する。try/exceptで保護しないとロックが残存し、TTL期限までリクエストがブロックされる
- **入力IDの早期バリデーション** — View で外部入力（session_id 等のID参照）を受け取る場合、DB参照・ペイロード構築等の重い処理の前に軽量なバリデーション（存在確認・権限確認）を先行させているかをチェックする。無効な入力で重い処理が走るとリソースの無駄になる
- **不要な例外catchの検出** — try-except句で実際にraiseされない例外型をcatchしていないか。fail_with_rollbackでResult型として返される例外はexcept句に不要。catchする例外は実際の発生源と照合して必要最小限に
- **例外変換時のメッセージ保持** — 例外変換時に元のエラーメッセージを破棄していないか。デバッグ時の原因特定のため、元例外のメッセージはできる限り保持する
- **リトライ間隔パラメータの最小値バリデーション** — リトライ間隔パラメータの最小値バリデーション。0を許可すると即時リトライによる無限ループやリソース飢餓が発生する可能性がある。リトライ系パラメータは最低1秒以上を強制。
- **同一usecase内の複数分岐のエラーハンドリング統一** — 同一usecase内の複数分岐で同じドメインメソッドを呼ぶ場合、全分岐でエラーハンドリングが統一されているかチェック。一方の分岐だけtry-exceptがない場合、Result契約を破る。
- **同一エラーコードの例外型統一** — 同じエラーコード（例: `NOT_APPLICANT`）を複数usecaseで返す場合、例外型まで統一されているか確認する。`ValidationError` と `PermissionDeniedError` の混在は API の HTTP ステータス差異を生み、呼び出し側を不安定にする。
- **DRFの内部APIアクセス検出** — DRFの `_declared_fields` や `_meta` 等のアンダースコア接頭辞属性を直接操作していないかチェック。バージョンアップで互換性が壊れるリスクがある。継承 + `get_fields()` オーバーライドで代替する
- **条件付き必須フィールドの検出** — あるフィールドの値によって他フィールドの必須/不要が変わるケースで、常時requiredにしていないかチェック。`validate()` メソッドで条件分岐する
- **入力変換はガード後に配置** `[新観点 from PR#614]` — `int()` や型変換は、対象値の妥当性検証（ガード節）の後に配置する。ガード前に変換すると非数値文字列で `ValueError` が発生する。入力バリデーション関数が上流で検証済みでも、変換の位置はガード節の後に統一する。
