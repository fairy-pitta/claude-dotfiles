# CodeRabbit コメント分析 - Backend vs Frontend 分類データ

## 概要

**収集日:** 2026-02-24
**リポジトリ:** WAOTech-Team/forval-crossgear
**対象PR:** 最近40件（PR#420〜#466）

## 統計

| カテゴリ | 件数 |
|---------|------|
| Backend インライン指摘 | 431 |
| Frontend インライン指摘 | 394 |
| Meta/設定ファイル等 | 360 |
| **合計** | **1,185** |
| コメントのあったPR数 | 33 |

## ファイル構成

### `summary.md`
全体サマリー。Backend/Frontend別の重要度統計、対象PR一覧。

### `backend.md` (478KB)
Backendファイル（`backend/`以下）へのCodeRabbitインラインコメント全件。
- 重要度別・PR別に整理
- よく指摘されたモジュールのTop15付き

### `frontend.md` (433KB)
Frontendファイル（`frontend/`以下）へのCodeRabbitインラインコメント全件。
- 重要度別・PR別に整理
- よく指摘されたモジュールのTop15付き

### `raw_data.json` (3.0MB)
加工前の生データ（JSON形式）。
- `backend`: PR別のbackendコメント一覧
- `frontend`: PR別のfrontendコメント一覧
- `meta`: サマリーレビュー・設定ファイルへのコメント
- `pr_titles`: PR番号→タイトルマッピング
- `stats`: 集計統計

## 重要度分類ロジック

CodeRabbitのコメント本文に含まれるアイコンで分類:
- 🔴 Critical (`Critical`)
- 🟠 Major (`Major`)
- 🟡 Minor (`Minor`)
- 🔵 Nitpick/Trivial (`Nitpick`, `Trivial`)
- ℹ️ Info (上記以外)

## Backend/Frontend分類ロジック

コメントが付いたファイルパスで分類:
- `backend/` で始まる → Backend
- `frontend/` で始まる → Frontend
- それ以外（`.github/`, `.coderabbit.yml`, `CLAUDE.md` 等）→ Meta

## 収集方法

```bash
# インラインコメント
gh api repos/WAOTech-Team/forval-crossgear/pulls/{PR}/comments \
  --jq '.[] | select(.user.login == "coderabbitai[bot]")'

# レビューサマリー
gh api repos/WAOTech-Team/forval-crossgear/pulls/{PR}/reviews \
  --jq '.[] | select(.user.login == "coderabbitai[bot]")'
```

## 利用目的

- コーディング規約の強化・更新の参考に
- よく繰り返される指摘パターンの把握
- Backend/Frontend各チームへのフィードバック資料として
