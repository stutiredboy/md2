# MD2

MD2 is a small native macOS Markdown editor and reader inspired by Typora's minimal writing flow.

MD2 是一个简洁的 macOS 原生 Markdown 编辑/阅读工具，目标是保留 Typora 式写作体验里最核心的部分。

## Typora-inspired scope

Typora emphasizes a distraction-free Markdown experience with no separate preview window, live preview, common block support, outline navigation, file organization, import/export, word count, focus tools, and custom themes.

MD2 keeps the first version intentionally compact:

- Single-window SwiftUI macOS app.
- One main surface with `Write` and `Read` modes instead of a side-by-side preview.
- Native AppKit text editing with lightweight Markdown styling.
- Live-rendered HTML reading mode.
- Outline sidebar generated from headings.
- Standard macOS open/save panels.
- Word, character, line, and reading-time status.
- Built-in rendering for headings, paragraphs, emphasis, links, images, blockquotes, horizontal rules, ordered/unordered/task lists, tables, fenced code, YAML front matter, and `[TOC]`.
- App settings for language, default open mode, and default outline visibility.
- Markdown file type declaration for `.md` and `.markdown` files when packaged.

See [Docs/MarkdownSupport.md](Docs/MarkdownSupport.md) for the tested Markdown/Typora support matrix.

## Run

```sh
swift run MD2
```

Open a file directly:

```sh
swift run MD2 path/to/file.md
```

Build a local macOS app bundle:

```sh
Scripts/package_app.sh
open dist/MD2.app
```

Run the full local verification suite:

```sh
Scripts/functional_test.sh
```

## Test

```sh
swift test
```
