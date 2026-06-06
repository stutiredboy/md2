<div align="center">
  <h1>Markdown2</h1>
  <p><strong>Markdown Editor Too</strong> — 轻量级 macOS 原生 Markdown 编辑器 & 阅读器</p>
  <p>[中文] <a href="README.md">[English]</a></p>

  <p>
    <a href="https://github.com/stutiredboy/md2/stargazers"><img src="https://img.shields.io/github/stars/stutiredboy/md2?style=social" alt="GitHub stars"></a>
    <a href="https://github.com/stutiredboy/md2/blob/main/LICENSE"><img src="https://img.shields.io/github/license/stutiredboy/md2" alt="License"></a>
    <a href="https://github.com/stutiredboy/md2/releases"><img src="https://img.shields.io/github/v/release/stutiredboy/md2" alt="Latest release"></a>
  </p>

  <p>受 Typora 极简写作体验启发，Markdown2 在一个紧凑的原生 macOS 应用中保留了无干扰的写作流程。使用 SwiftUI + AppKit 构建。</p>
</div>

## 功能

- **单窗口编辑** — 一个主界面提供「编写」和「阅读」两种模式，而非左右分栏预览。
- **原生 AppKit 文本编辑**，附带轻量 Markdown 样式。
- **实时渲染 HTML** 阅读模式。
- **大纲侧边栏**，由标题自动生成。
- **标准 macOS 打开/保存面板**，已保存文档支持防抖自动保存，关闭/退出时对未保存更改进行确认。
- **多窗口支持** — 每个文档在独立窗口中打开；从 Finder 或打开面板打开文件时，会复用尚未编辑的空白窗口。
- **字数、字符数、行数与阅读时间**状态栏。
- **丰富的 Markdown 渲染** — 标题、段落、强调、链接、图片、引用、分隔线、有序/无序/任务列表、表格、围栏代码（带语法高亮）、YAML front matter 及 `[TOC]`。
- **数学公式** — 行内 `$...$` 与独占一行的 `$$...$$` TeX 公式，使用内置 [KaTeX](https://katex.org/) 离线渲染（无需联网），并内置 mhchem 扩展以支持化学式（`\ce{...}`）。
- **图表** — `mermaid`、`flow`（[flowchart.js](https://flowchart.js.org/)）与 `sequence`（[js-sequence-diagrams](https://bramp.github.io/js-sequence-diagrams/)）代码块，使用内置引擎离线渲染（无需联网）。
- **快捷模式切换** — 编辑模式按 `Esc` 切换到预览，预览模式 `Cmd+双击` 切回编辑。
- **应用设置** 支持语言、默认打开模式与默认大纲可见性。
- 打包时为 `.md` 和 `.markdown` 文件声明 **Markdown 文件类型**。

完整的 Markdown/Typora 支持矩阵见 [Docs/MarkdownSupport.md](Docs/MarkdownSupport.md)。

## 安装

从 [Releases](https://github.com/stutiredboy/md2/releases) 下载最新的 `Markdown2.app`，拖入 `/Applications` 即可。

> [!NOTE]
> 从 GitHub Release 下载的 app 未经 Apple 签名和公证，macOS Gatekeeper 会阻止打开并提示"已损坏"。运行以下命令即可解除：
>
> ```sh
> xattr -cr /Applications/Markdown2.app
> ```
>
> 然后在 **系统设置 → 隐私与安全性** 中点击"仍要打开"，或直接双击打开即可。

## 从源码运行

```sh
swift run Markdown2
```

直接打开文件：

```sh
swift run Markdown2 path/to/file.md
```

构建本地 macOS app 包：

```sh
Scripts/package_app.sh
open dist/Markdown2.app
```

运行完整本地验证套件：

```sh
Scripts/functional_test.sh
```

## 测试

```sh
swift test
```

## 许可证

Markdown2 基于 [MIT License](LICENSE) 开源。
