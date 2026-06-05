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
- Debounced autosave for saved documents, plus close/quit confirmation for unsaved changes.
- Word, character, line, and reading-time status.
- Built-in rendering for headings, paragraphs, emphasis, links, images, blockquotes, horizontal rules, ordered/unordered/task lists, tables, fenced code with lightweight syntax highlighting, YAML front matter, and `[TOC]`.
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

## macOS "已损坏" 提示

从 GitHub Release 下载的 app 未经 Apple 签名和公证，macOS Gatekeeper 会阻止打开并提示"已损坏"。运行以下命令即可解除：

```sh
xattr -cr /Applications/Markdown2.app
```

然后在系统设置 → 隐私与安全性中点击"仍要打开"，或直接双击打开即可。

## Test

```sh
swift test
```
