<p align="center">
  <img src="docs/images/icon.png" width="112" alt="Spray Can 应用图标">
</p>

<h1 align="center">Spray Can</h1>

<p align="center">
  <strong>能看见辅助功能遗漏之处的键盘导航。</strong><br>
  借助标签、网格和私密的设备端 OCR 操控你的 Mac。
</p>

<p align="center">
  macOS 14+ · Apple 芯片与 Intel · Swift + AppKit · 100% 本地处理
</p>

<p align="center">
  🌐 <a href="README.md">English</a> · <strong>简体中文</strong> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a>
</p>

*本文为译文；如与英文版 README 有出入，以英文版为准。*

<p align="center">
  <a href="https://buymeacoffee.com/ziyang">
    <img src="docs/images/buymeacoffee.png" width="36" alt="请我喝杯咖啡"><br>
    支持 Spray Can
  </a>
</p>

**基于 [MIT License](LICENSE) 免费开源。**
无订阅、无付费版本、无数据分析，也无云端 OCR。

![元素导航](docs/images/elements.png)

Spray Can 让你**无需伸手拿鼠标，即可点按、拖移、滚动和导航**。

按下 **⇧⌘J**，输入标签，然后按 **Return**。

与只依赖 macOS 辅助功能的工具不同，Spray Can 还能**完全在设备端使用 Apple Vision OCR**，为应用未通过辅助功能树公开的可见文本添加标签。

截屏绝不会离开你的 Mac。

## 看得更多，触手可及

Spray Can 结合了三层定位方式：

- **辅助功能** — 精确定位控件、按钮、输入框、列表行、菜单和系统界面。
- **设备端 OCR** — 在辅助功能未公开时识别可见文本。
- **网格** — 覆盖其余一切，包括自定义画布和无标签区域。

OCR 使用 **ScreenCaptureKit + Apple Vision**，完全在本地运行。捕获的画面在内存中处理后即被丢弃 — 无云端推理、无截屏日志、无数据分析。

![元素导航流程](docs/images/element-demo.gif)

## 四种导航方式

| 模式 | 快捷键 | 用途 |
| --- | --- | --- |
| **元素** | ⇧⌘J | 可访问的控件 + OCR 文本 |
| **网格** | ⇧⌘K | 任意已连接显示器上的任意位置 |
| **自由移动** | ⇧⌘L | 用键盘精确移动指针 |
| **滚动** | ⌃J | Vim 风格的 HJKL 滚动 |

全局快捷键可完全自定义。

## 专注于你的工作

导航时，Spray Can 会让目标应用保持焦点。

键盘输入的捕获独立于叠加层，因此你可以立即开始输入，同时元素查找和 OCR 在后台继续进行。开始输入后，迟到的 OCR 结果不会再改变标签。

点按之前，Spray Can 会重新验证可访问目标，以减少因目标过时导致的错误。

标签会跟随你的焦点。当目标窗口发生变化时 — 切换标签页、打开窗口、移动窗口或调整其大小，或者通过 ⌘Tab 或点按切换到其他应用 — Spray Can 会重新查找并显示新的标签。已输入一半的标签会被清除，进行中的拖移会被取消，而不会在意外的位置放下。网格和自由移动模式覆盖整个屏幕，因此不受影响。

## 界面再密集，标签也清晰

标签默认位于元素**旁边**，因此绝不会遮挡你将要点按的内容。你可以在**外观**中选择元素的左侧、右侧、上方、下方或元素之上，并通过水平和垂直偏移微调位置。

拥挤的标签会自动绕开附近的控件，而不是简单地叠在一起。连接线清楚地标明每个移位标签对应的目标。

![针对垂直和水平密集区域的自适应布局](docs/images/clustered-labels.png)

## 拖移、点按、滚动

Spray Can 支持：

- 左键、中键、右键点按和连按两次
- 按住修饰键点按
- 拖放
- 精细移动和整格移动指针
- 跳转到屏幕边缘
- Vim 风格滚动
- 多显示器

拖移示例：

`⇧⌘K` → 输入起点标签 → `=` → 输入终点标签 → `Return`

![网格拖移流程](docs/images/drag-demo.gif)

## 原生 macOS 体验

![设置](docs/images/settings.png)

Spray Can 使用 Swift 和 AppKit 构建。

它在 **macOS 26+ 上使用 Liquid Glass**，在 macOS 14–15 上使用原生材质，并遵循“降低透明度”设置。在“外观”中关闭**使用 Liquid Glass**，即可让标签和状态面板使用纯色背景。关闭玻璃效果后，可以调整标签背景的不透明度，而文字不会变淡。启用玻璃效果或“降低透明度”时，该滑块不可用。

你可以自定义：

- 导航快捷键
- 目标范围
- OCR 及其识别语言
- vi 按键绑定
- 标签位置和偏移
- 标签大小
- 网格间距
- 背景不透明度
- 标签、OCR、网格、文字和选中颜色
- 界面语言

Spray Can 的界面提供 English、简体中文、繁體中文、日本語、한국어 和 Español 版本。默认跟随 Mac 的语言；也可以在**通用 → 语言**中选择其他语言，并在提示时重新启动 Spray Can。

![外观自定义](docs/images/appearance.png)

## 安装

从[我的 Homebrew tap](https://github.com/Kymer0615/homebrew-tap) 安装：

```sh
brew install --cask kymer0615/tap/spray-can
open "/Applications/Spray Can.app"
```

更新或卸载：

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
brew uninstall --cask spray-can
```

普通卸载会保留偏好设置。如果你之前是手动安装的，请在改用 Homebrew 之前退出 Spray Can，并将该副本移出“应用程序”文件夹，以免同时运行两个副本。

你也可以从 [Releases](https://github.com/Kymer0615/spray_can/releases) 下载通用 ZIP 包，解压后将 **Spray Can.app** 移到“应用程序”文件夹。

0.1.2 版本采用 **ad-hoc 签名，未经公证**。如果 macOS 阻止了你信任的版本：

**系统设置 → 隐私与安全性 → 仍要打开**

Spray Can 可能会请求：

1. **辅助功能** — 查找控件、捕获导航按键并执行指针操作。
2. **屏幕录制** — 可选，仅用于设备端 OCR。

键盘捕获使用辅助功能权限，无需另外设置输入监控。“权限”页面会显示捕获是否真正在运行。

发布的压缩包及其 SHA-256 校验和均带有版本号。请参阅[发布说明](docs/RELEASING.md)。

## 隐私

Spray Can 设计为在本地运行。

- OCR 通过**设备端 Apple Vision** 运行
- 截屏在内存中处理后即被丢弃
- 无截屏日志
- 无数据分析
- 无云端推理
- 无需帐户或订阅

## OCR 语言

OCR 可以**同时识别多种语言**。在**通用 → 文本识别语言**中，选择 Apple Vision 在你的 Mac 上支持的任意语言并排好顺序。所有选中语言的文本会在同一次扫描中添加标签，因此英文工具栏、中文文档和日文菜单都能一并触达。

使用相同书写系统的语言（例如英语、法语和西班牙语）会一起识别。每增加一种书写系统（例如中文、日文或韩文），就会在同一张截屏上多进行一轮识别，因此扫描耗时会稍长一些。默认情况下，Spray Can 会选择 Mac 的偏好语言以及英语。

## OCR 的局限

OCR 识别的是**文本位置**，而不是该文本是否可点按。

因此，识别出的标签可能指向标题或其他不可交互的文本。它也无法检测所有无标签的图标或任意视觉控件。

对于这些情况，请使用**网格模式**。

有关当前兼容性和测试状态，请参阅 [VALIDATION.md](docs/VALIDATION.md)。

## 构建

需要 **Xcode 26+**。

```sh
scripts/test.sh
scripts/build.sh
scripts/install-local.sh
```

开发时：

```sh
swift scripts/generate-artwork.swift
python3 scripts/generate-project.py
scripts/render-docs.sh
scripts/integration-test.sh
swift scripts/ocr-smoke.swift
swift scripts/ocr-smoke.swift image.png --languages en-US,zh-Hans,ja-JP --expect "Open,打开,開く"
python3 scripts/check-localizations.py
scripts/release.sh 0.1.2 adhoc
```

在 Xcode 中打开 `SprayCan.xcodeproj`。

界面翻译位于 `Resources/<language>.lproj/Localizable.strings`，英文键即为源文本。`scripts/check-localizations.py` 会检查每种语言是否包含所有键以及占位符是否一致。

`SprayCanCore` 包含会话状态机、标签生成与布局、OCR 语言分组、刷新规则、几何计算和快捷键映射。`Sources/SprayCanApp` 包含应用界面、事件捕获、元素查找提供者、鼠标驱动和叠加层。

## 状态

Spray Can 0.1.2 适用于 macOS 14 及更高版本。

导航核心已通过 **1,000 次快速激活循环**的压力测试，原生测试夹具完成了 **60 次元素/网格点按循环**，没有漏点，也没有输入泄漏。

第三方应用、多显示器、全屏以及跨版本的兼容性仍在验证中。

请参阅 [VALIDATION.md](docs/VALIDATION.md)。

## 社区

欢迎提交[问题和功能建议](https://github.com/Kymer0615/spray_can/issues)、参与测试和[贡献代码](https://github.com/Kymer0615/spray_can/pulls)。

特别欢迎以下方面的帮助：

* 辅助功能覆盖范围
* OCR 验证
* 界面与交互设计
* 文档
* 跨应用测试

如果 Spray Can 对你有帮助，欢迎[请我喝杯咖啡](https://buymeacoffee.com/ziyang)。支持完全自愿，也不会解锁任何功能。

## 致谢

原创实现和美术资源均以 [MIT License](LICENSE) 发布。

工作流程灵感来源：
[Scoot](https://github.com/mjrusso/scoot) ·
[Vimac](https://github.com/nchudleigh/vimac)

本项目未包含上述任一项目的源代码或视觉素材。

请参阅[架构与研究笔记](docs/ARCHITECTURE.md)。
