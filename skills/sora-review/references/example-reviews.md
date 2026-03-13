# Sora Review - Example Reviews

## Example Review (Japanese)

```markdown
## backend/app/application/services/account_title_service.py

引数多いのでオブジェクトにしたいです！

---

## backend/app/presentation/serializers/account_title_serializers.py

エラー文関連は定数にしたいかもです！
実際、「有効な会社IDが必要です。」が使用されている箇所は二つあります

---

## backend/app/infrastructure/repositories/account_title_repository_impl.py

【重要】
ここなんですが、クエリが２個走ってて、片方が成功して片方が失敗すると
不整合になってしまうのでトランザクションを貼りたいです
https://docs.djangoproject.com/en/5.2/topics/db/transactions/
https://qiita.com/Ryo-0131/items/56a0c357b7d7fa2ac699

---

これも上記に同様です！

---

エラーは返した方がいい気がします

---

select_for_updateも入れた方がいい気がします
https://qiita.com/sotaheavymetal21/items/fcba11952ac48505c44a

---

## backend/app/application/usecases/import_account_master_usecase.py

N+1問題が発生しているので激オモになる気がします
毎回毎回get_sub_category_by_nameを実行しちゃってるので

---

bulk_createってやつがあるので作成の際はそれ使った方がいいかもです
https://djangobrothers.com/blogs/django_bulk_create_update/

---

## backend/app/domain/repositories/account_title_repository.py

Anyは無しでお願いします！

---

nits
statusはenumから参照したいです🙇

---

## Summary

主に以下の点が気になりました：

1. **トランザクション:** 複数クエリで不整合が発生する可能性があります
2. **N+1問題:** 激オモになる可能性があるのでbulk操作を検討してください
3. **Any型:** できる限りやめたいです
4. **定数化:** エラーメッセージやステータスを定数にした方がいいかもです

トランザクションとN+1問題は優先的に対応いただけると！🙇
```

## Example Review (English)

```markdown
## backend/app/domain/repositories/account_title_repository.py

Can we avoid using Any type here? Would prefer Protocol or TypedDict!
No worries if it's not possible though!

---

## backend/app/infrastructure/repositories/account_title_repository_impl.py

[Important]
Two queries are running here, and if one succeeds and the other fails, we'll get data inconsistency.
Should we wrap this in a transaction?
https://docs.djangoproject.com/en/5.2/topics/db/transactions/

---

## backend/app/application/usecases/import_account_master_usecase.py

This looks like an N+1 problem - calling get_sub_category_by_name in a loop.
Could get really slow with lots of data.

---

Maybe use bulk_create for inserts?
https://docs.djangoproject.com/en/stable/ref/models/querysets/#bulk-create

---

## Summary

Main concerns:

1. **Transactions:** Potential data inconsistency from multiple queries
2. **N+1 queries:** Could cause major performance issues - consider bulk operations
3. **Any type:** Would prefer to avoid where possible
4. **Constants:** Some error messages should be constants

Transaction and N+1 issues are priority - please address these first!
```
