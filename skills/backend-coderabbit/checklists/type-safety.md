# Backend Review: Type Safety + Validation & Error Handling

このチェックリストはサブエージェント用。`backend/` 配下の変更ファイルに対して適用する。

**コード例示:** `references/code-examples.md` を参照

---

## Core Checklist

### Type Safety

- [ ] **型ヒント必須・Any禁止** — すべての関数・メソッドに型ヒントを付与。`Any`型は禁止し`Protocol`/`TypedDict`/`Generic`で代替。`# type: ignore[return]`等での型チェック回避もNG。例: `QuerySet[Model]`の戻り値型を明示する
- [ ] **Result型タプルアンパック・エラー無視禁止** — `result, error = usecase.execute()`の形式が必須で`.error`属性アクセスは禁止。`value, _ = ...`でエラーを捨てると認可チェックが消えるため、必ずエラーを変数に受けてチェックする（→ `references/code-examples.md`）
- [ ] **Enum必須・基底型禁止** — ステータス値・カテゴリ値に文字列リテラルを使わず`TextChoices`/`IntegerChoices`を使用。Enum値を受け取る引数を基底型(str/int)でアノテーションしない。例: 任意値の通過を防ぐためEnum型でアノテーションする
- [ ] **エラー型は型・種別で判定** — Result型のエラーを文字列比較で分岐しない（メッセージ定数変更で分岐が壊れる）。UseCase層で例外を分類する場合はisinstanceで型判定し、メッセージやカスタム例外で具体的なエラー種別まで識別する。一律マッピングは原因隠蔽を招く
- [ ] **bool⊂int型チェック** — `isinstance(x, int)`によるバリデーションでboolが通過しないか確認。Pythonでは`isinstance(True, int)`がTrueを返すため、intチェックの前に`isinstance(x, bool)`で排除する
- [ ] **同一型の重複定義禁止** — 既存の型と同一構造なのに別名で再定義していないか確認。既存の型定義を検索し、同等の構造があれば再利用する
- [ ] **エッジケース・境界値の考慮** — ゼロ・空・None等のエッジケース、`<=` vs `<`の取り違え、off-by-oneエラーが考慮されているか
- [ ] **データアクセスの実行時正当性** — 属性・キー・IDへのアクセスが実行時に正当か確認。関連オブジェクト不在時のAttributeError/KeyError、外部キー参照先が削除されているケース等
- [ ] **バリデーション実行順序・ガード後の変換** — 削除・更新等の副作用やDB参照・重い処理の前にバリデーション（存在確認・権限確認・値域）を先行させる。`int()`等の型変換は妥当性検証(ガード節)の後に配置し、非数値文字列での`ValueError`を防ぐ。正規化・変換後は結果が有効か再検証する
- [ ] **コメント衛生** — コメントが実装と乖離していないか。docstringに記載した戻り値型が実装と一致しているか（特にResult型でエラーバリアントを追加した場合はdocstringも更新する）

---

## Extended Checklist

### Type Safety（詳細）

- **Enum型引数の実行時型検証** — `create()`等のファクトリで Enum 型パラメータを受け取る場合、`isinstance(x, SomeEnum)`の実行時チェックがあるか。型ヒントだけでは実行時に文字列が通り抜ける
- **SerializerとDomainモデルの整合・型精度** — APIレスポンスのフィールド名がDomainエンティティと整合しているか。`SerializerMethodField`の戻り値型が、渡すフィールドのOptional性に合わせて精度高く絞られているか（例: non-Optionalなら`str`に絞る）
- **DTO型・TypedDictの網羅性と分岐一致** — UseCaseで条件分岐する場合、DTO型がその分岐を反映しているか（Optionalで済ませずUnion型で意図を明示）。外部サービスのストリームイベント型（例: AWS Bedrock）が例外イベント型も含むか、`TypedDict`の`total=False`が適切か。`TypedDict`の各フィールドの全状態値（特にbool型のTrue/False両方）を生成するコードパスが存在するか
- **テストヘルパーの型ヒント精度** — テストヘルパー関数の引数型がドメインエンティティやリクエスト型の実フィールド型と一致しているか。`object`等の広すぎる型を避け、`UUID | None`等の具体型を使う
- **`*args`/`**kwargs`の型注釈** — `*args: T`は「各引数がT型」を意味する。`*args: tuple[...]`や`**kwargs: dict[...]`はコンテナ型を要素型に指定する誤り。正しくは`*args: object, **options: object`とし、個別値は`cast()`で絞り込む
- **Factory戻り値の型注釈** — `UserFactory()`の戻り値を`UserFactory`型で注釈しない。Factoryは生成物の型（`User`）を返す
- **Enum分岐の網羅性** — if/elif/elseでEnumを分岐する際、elseで「残り全て」を暗黙処理していないか。バリアント追加時に誤動作するため、明示的に全バリアントを分岐し未知値は例外にする

### Validation & Error Handling（詳細）

- **frozen dataclass / エンティティ不変条件の網羅** — `__post_init__`で全フィールドの不変条件を検証しているか。プリミティブ型(int, str)も型ヒントだけでは不十分。非空チェックは`not self.field`ではなく`not self.field.strip()`で空白のみ入力を弾く。エラーメッセージが定数化されているかも確認（例: `item_name`非空・`year`範囲）（→ `references/code-examples.md`）
- **`reconstruct()`/変換系の入力型・例外保護** — `from_string()`やenum変換で`isinstance(value, str)`チェックがないと`int`/`None`で`AttributeError`になる。`reconstruct()`では`isinstance(field, UUID)`等の型不変条件を検証しDB破損データの混入を防ぐ。`SomeEnum(value)`は不正値で`ValueError`を送出するため`try/except ValueError`で保護し明示的に再送出する（→ `references/code-examples.md`）
- **Repositoryのexcept節でのmapper例外捕捉** — `except DatabaseError as exc: return failure(exc)`はmapper（`model_to_entity`等）由来の`ValueError`を捕捉しない。`except (DatabaseError, ValueError) as exc:`にしてResult契約を保つ
- **例外チェーンの`from exc`** — `except ... as exc: raise ... from exc`を使用しているか。`from exc`がないとトレースバック情報が失われデバッグ困難になる
- **例外変換時のメッセージ保持** — 例外変換時に元のエラーメッセージを破棄していないか。原因特定のため元例外メッセージはできる限り保持する
- **エラーメッセージと検証パターンの整合** — エラーメッセージに記載した許容値範囲が実際の`RegexValidator`パターンや年の範囲チェック（例: `year <= 0`のみで1900-9999が漏れていないか）と一致しているか（→ `references/code-examples.md`）
- **validate_<field>サニタイズ後の空文字チェック** — `validate_<field>`で制御文字除去・trim等のサニタイズを行う場合、サニタイズ後の空文字を考慮しているか。DRFの`allow_blank`/`required`チェックは`validate_<field>`より先に実行されるため、明示的な空文字チェックと`ValidationError`発生が必要
- **月文字列のint変換による形式ロス** — MM形式の月文字列を`int()`変換して再ゼロパディングするパターン（「1」→1→「01」）は入力バリデーションを無効化する。月操作はstr→str変換で行う
- **UseCase層の自己完結した検証** — UseCaseは独立したインターフェースとして自己完結すべき。Presentation/View層で検証済みでも、引数間の依存関係（例: category_typeとsub_category_id）の整合性ガードと値域検証（`<= 0`等）をUseCase.execute()冒頭で行う
- **Presentation層のエラーメッセージ定数化・変換** — ヘルパー関数内のインライン`raise ValueError(f"...")`を定数クラス（例: `SummaryErrors`）経由にする。Presentationヘルパーで発生する例外はView層でキャッチし`ApiResponse.error`に変換する
- **エラー型とHTTPステータスのマッピング統一** — `ApiResponse.error()`のマッピングに存在しないエラー型（例: `ValueError`）を使っていないか（`ValidationError`→400、`PermissionDeniedError`→403等）。同じエラーコード（例: `NOT_APPLICANT`）を複数usecaseで返す場合は例外型まで統一し、HTTPステータスの差異を防ぐ
- **assert文の本番使用禁止** — `python -O`で無効化されるassertをバリデーションに使わない。明示的なif文+エラーレスポンスに置き換える
- **Result型とraise混在の禁止** — Result型を返す関数内で例外をraiseしていないか。タプルアンパック前提の呼び出し側で捕捉できず500になる。同一usecase内の複数分岐で同じドメインメソッドを呼ぶ場合、全分岐でエラーハンドリングを統一しResult契約を保つ
- **except Exception でエラーを潰さない** — Result型を返すusecaseのcatch allはSentry検知を妨げる。`ValidationError`等の特定例外のみcatchし、`DatabaseError`等はバブルアップさせる。実際にraiseされない例外型をcatchしていないか（`fail_with_rollback`でResult化される例外はexcept不要）も確認し、catchは必要最小限にする
- **SSEジェネレータの例外捕捉範囲** — ストリーミングのジェネレータで特定例外のみ捕捉すると他例外でストリームが無言で途切れる。`GeneratorExit`以外を包括的に捕捉し、クライアントにエラーイベントを送信する
- **キャッシュロック解放漏れ** — ロック取得後〜ストリーム開始前の同期コードで例外発生時のロック解放を確認。try/exceptで保護しないとTTL期限までリクエストがブロックされる
- **リトライ間隔パラメータの最小値バリデーション** — 0を許可すると即時リトライによる無限ループやリソース飢餓が発生しうる。リトライ系パラメータは最低1秒以上を強制する
- **条件付き必須フィールドの検出** — あるフィールドの値で他フィールドの必須/不要が変わるケースで常時requiredにしていないか。`validate()`メソッドで条件分岐する
- **DRFの内部APIアクセス検出** — `_declared_fields`や`_meta`等のアンダースコア接頭辞属性を直接操作していないか。バージョンアップで互換性が壊れるため、継承+`get_fields()`オーバーライドで代替する
- **未検証の外部入力(request.data)の型保証は「境界」で行う** — `request.data.get()`由来の値はJSON上 非str(int/bool/list/dict)になり得る。これに`len()`/`.isascii()`/`.strip()`等の文字列操作を行う検証コードは`TypeError`→500を招く。型保証(`isinstance`/型強制)はプレゼン境界のパースヘルパ(`parse_optional_int`/`parse_optional_str`等)に置き、ドメインエンティティには自衛的`isinstance`を持ち込まない（エンティティは自身の型契約`Optional[str]`を信頼すべき）。境界で弾けばクリーンな400になる
