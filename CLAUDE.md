# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

code-to-markdownは、指定したディレクトリ内のソースファイルを単一のMarkdownドキュメントに変換するCLIツール。Bun ランタイムで動作するTypeScriptアプリケーション。

## Commands

```bash
# 依存関係のインストール
bun install

# CLIの直接実行
bun src/cli.ts --dirs <dir...> --out <file> [--exts <ext...>] [--base <dir>]

# フォーマット
bunx prettier --write .
```

## CLI Usage

```bash
# 基本的な使い方
bun src/cli.ts --dirs src --out output.md

# 複数ディレクトリと拡張子フィルタ
bun src/cli.ts --dirs src lib --exts .ts .tsx --out code.md --base .
```

## Architecture

単一ファイル構成（`src/cli.ts`）で、以下の処理フローを持つ：

1. **引数解析** (`parseArgs`) - `--dirs`, `--out`, `--exts`, `--base` オプションを処理
2. **ファイル探索** (`findFiles`, `walk`) - 指定ディレクトリを再帰的にスキャン
3. **バイナリ判定** (`isBinaryFile`) - NULバイト検出で判定
4. **Markdown生成** (`buildMarkdown`) - ファイルリスト + 各ファイルのコードブロック

出力形式：

- 冒頭にファイル一覧のコードブロック
- 各ファイルは相対パス見出し + 言語タグ付きコードブロック
- コンテンツ内に ``` がある場合は ```` でエスケープ
