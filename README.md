# code-to-markdown

指定したディレクトリ内のソースファイルを単一のMarkdownドキュメントに変換するCLIツール。

## インストール

### ワンライナーインストール（推奨）

```bash
curl -fsSL https://raw.githubusercontent.com/togo5/code-to-markdown/main/install.sh | bash
```

バイナリは `~/.local/bin` にインストールされます。PATHが通っていない場合は、シェルの設定ファイルに以下を追加してください：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 使い方

```bash
# 基本的な使い方
code-to-markdown --dirs src --out output.md

# 複数ディレクトリと拡張子フィルタ
code-to-markdown --dirs src lib --exts .ts .tsx --out code.md --base .
```

### オプション

| オプション | 説明                                           |
| ---------- | ---------------------------------------------- |
| `--dirs`   | スキャンするディレクトリ（複数指定可）         |
| `--out`    | 出力ファイルパス                               |
| `--exts`   | 対象とするファイル拡張子（省略時は全ファイル） |
| `--base`   | 相対パスの基準ディレクトリ                     |

## 出力形式

- 冒頭にファイル一覧のコードブロック
- 各ファイルは相対パス見出し + 言語タグ付きコードブロック

## ライセンス

MIT
