# Sora Review - コメントパターン集

## Pattern 1: Direct Request

```
定数にしたいです！
```

```
Anyはできる限りやめたいです！
```

```
引数が多いので型でまとめたいです！
```

## Pattern 2: Question Format

```
GETじゃなくてPOSTでしょうか？
```

```
型つけたほうがいいでしょうか？
```

```
ここってtry catchしなくて大丈夫でしょうか？
```

```
これって本当に最初の一個だけで大丈夫ですか？（ただの確認です！）
```

## Pattern 3: Concern Expression

```
これ内部のエラー筒抜けになってる気がしててセキュリティ上よくない気がします！🙇
```

```
N+1問題が発生しているので激オモになる気がします
毎回毎回get_sub_category_by_nameを実行しちゃってるので
```

```
クエリが２個走ってて、片方が成功して片方が失敗すると不整合になってしまうので
トランザクションを貼りたいです
```

## Pattern 4: Important Issues

```
【重要】
ここなんですが、クエリが２個走ってて、片方が成功して片方が失敗すると
不整合になってしまうのでトランザクションを貼りたいです
https://docs.djangoproject.com/en/5.2/topics/db/transactions/
https://qiita.com/Ryo-0131/items/56a0c357b7d7fa2ac699
```

## Pattern 5: Minor Issues (nits)

```
nits
statusはenumから参照したいです🙇
```

```
nits
SubCategoryNotFoundErrorとか作成してやった方がわかりやすいですかね？
```

## Pattern 6: Repeated Issues

```
これも定数にしたいです
```

```
これもお願いします！
```

```
他にもあるので修正お願いします
```

```
ditto
```

## Pattern 7: With Documentation References

```
null=Trueって必要でしょうか？
https://docs.djangoproject.com/en/5.1/ref/models/fields/?utm_source=chatgpt.com#null
```

```
select_for_updateも入れた方がいい気がします
https://qiita.com/sotaheavymetal21/items/fcba11952ac48505c44a
```

```
bulk_createってやつがあるので作成の際はそれ使った方がいいかもです
https://djangobrothers.com/blogs/django_bulk_create_update/
```

## Special Phrases

**For duplicate issues:**
```
これも
```
```
他にも同じようなところあるので確認いただけると！
```
```
ditto
```

**For optional improvements:**
```
無理だったら大丈夫です！
```

**For confirmations:**
```
ただの確認です！
```

**When unsure:**
```
〜な気がします
```
```
〜でしょうか？
```

## Emoji Usage

Use sparingly and naturally:
- 🙇 - When pointing out issues politely
- Use in casual contexts, not every comment

## Linking Resources

When suggesting improvements, link to:
- Django official docs
- Qiita articles (Japanese)
- Other practical references
