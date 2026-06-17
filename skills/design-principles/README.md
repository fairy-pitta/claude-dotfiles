# Design Principles Review Skill

言語非依存の設計品質（SOLID / デメテルの法則 / クリーンコード）に特化したコードレビュー用チェックリスト集。`backend/`（Python/DDD）・`frontend/`（TS/Vue）の両方に適用する横断観点。

スタック特化の `backend-coderabbit` / `frontend-coderabbit` がバグ・規約・性能を見るのに対し、こちらは **責務・依存・凝集/結合・複雑性** という「コードの綺麗さ」のレンズで全 diff を横断レビューする。

## 特徴

- **重要度指標:** 🔴 Critical / 🟠 Major / 🟡 Minor / 🔵 Trivial
- 言語非依存。Python/TypeScript 共通の設計原則のみを扱う
- バグ検出は行わず、設計品質に絞る（バグは各スタックのチェックリストへ）
- 既存チェックリストと重複する観点は二重指摘しない

## フォーカスエリア

1. **SOLID** - SRP / OCP / LSP / ISP / DIP
2. **Law of Demeter** - train-wreck 呼び出し, 内部構造の漏洩
3. **Coupling & Cohesion** - 低結合, 高凝集, feature envy
4. **Clean Code** - Tell Don't Ask, YAGNI, KISS, CQS, SLAP, 継承より合成
5. **Extended** - Rule of Three, 副作用の局所化, ブール引数, プリミティブ執着, 命名と責務の一致

## 使用方法

`self-review` の Design エージェントが `checklists/design-principles.md` を読んでレビューする。**スタック別**に起動し、`backend/` 変更で1つ・`frontend/` 変更で1つ、両方変更時は2つ立ち上がる（フロントとバックを別エージェントで見る）。`review-loop` 等の横断レビューにも組み込み可能。
