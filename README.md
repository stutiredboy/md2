<div align="center">
  <h1>Markdown2</h1>
  <p><strong>Markdown Editor Too</strong> — a lightweight native macOS Markdown editor & reader</p>
  <p><a href="README.zh-CN.md">[中文]</a> [English]</p>

  <p>
    <a href="https://github.com/stutiredboy/md2/stargazers"><img src="https://img.shields.io/github/stars/stutiredboy/md2?style=social" alt="GitHub stars"></a>
    <a href="https://github.com/stutiredboy/md2/blob/main/LICENSE"><img src="https://img.shields.io/github/license/stutiredboy/md2" alt="License"></a>
    <a href="https://github.com/stutiredboy/md2/releases"><img src="https://img.shields.io/github/v/release/stutiredboy/md2" alt="Latest release"></a>
  </p>

  <p>Inspired by Typora's minimal writing flow, Markdown2 keeps the distraction-free experience in a compact, native macOS app built with SwiftUI + AppKit.</p>
</div>

## Features

- **Single-window editing** — one main surface with `Write` and `Read` modes instead of a side-by-side preview.
- **Native AppKit text editing** with lightweight Markdown styling.
- **Live-rendered HTML** reading mode.
- **Outline sidebar** generated from headings.
- **Standard macOS open/save panels** with debounced autosave for saved documents, plus close/quit confirmation for unsaved changes.
- **Multi-window support** — each document opens in its own window; untouched starter windows are reused when opening files from Finder or the open panel.
- **Word, character, line, and reading-time** status bar.
- **Rich Markdown rendering** — headings, paragraphs, emphasis, links, images, blockquotes, horizontal rules, ordered/unordered/task lists, tables, fenced code with syntax highlighting, YAML front matter, and `[TOC]`.
- **Math typesetting** — inline `$...$` and display `$$...$$` TeX rendered offline with bundled [KaTeX](https://katex.org/) (no network required), including the mhchem extension for chemistry (`\ce{...}`).
- **Quick mode switching** — press `Esc` in the editor to switch to preview; `Cmd+double-click` in preview to jump back to edit.
- **App settings** for language, default open mode, and default outline visibility.
- **Markdown file type declaration** for `.md` and `.markdown` files when packaged.

See [Docs/MarkdownSupport.md](Docs/MarkdownSupport.md) for the tested Markdown/Typora support matrix.

## Install

Download the latest `Markdown2.app` from [Releases](https://github.com/stutiredboy/md2/releases), then drag it to `/Applications`.

> [!NOTE]
> Apps downloaded from GitHub Releases are not signed or notarized by Apple. macOS Gatekeeper will block them with a "damaged" warning. Run the following command to remove the quarantine attribute:
>
> ```sh
> xattr -cr /Applications/Markdown2.app
> ```
>
> Then open **System Settings → Privacy & Security** and click **Open Anyway**, or simply double-click the app.

## Run from Source

```sh
swift run Markdown2
```

Open a file directly:

```sh
swift run Markdown2 path/to/file.md
```

Build a local macOS app bundle:

```sh
Scripts/package_app.sh
open dist/Markdown2.app
```

Run the full local verification suite:

```sh
Scripts/functional_test.sh
```

## Test

```sh
swift test
```

## License

Markdown2 is open source under the [MIT License](LICENSE).
