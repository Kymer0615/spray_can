<p align="center">
  <img src="docs/images/icon.png" width="112" alt="Spray Can App 圖像">
</p>

<h1 align="center">Spray Can</h1>

<p align="center">
  <strong>不碰滑鼠，就能點按 Mac 上的任何東西。</strong><br>
  每個控制項都有標籤，其他地方交給網格，兩者之間的文字則由私密的裝置端 OCR 處理。
</p>

<p align="center">
  macOS 14+ · Apple Silicon 與 Intel · 免費開放原始碼（MIT）· 100% 裝置端處理
</p>

<p align="center">
  🌐 <a href="README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <strong>繁體中文</strong> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a>
</p>

```sh
brew install --cask kymer0615/tap/spray-can
```

![Spray Can 為視窗加上標籤並點按檔案](docs/images/element-demo.gif)

## 運作方式

1. 按下 **⇧⌘J**。每個按鈕、連結、列與欄位的文字旁邊都會出現一個簡短的標籤。
2. 輸入標籤，指標就會跳到該處。
3. 按 **Return** 點按——按**兩次**即可連按，**按住**則進行右鍵點按。

不用滑鼠、不用觸控式軌跡板，也不必再到處找游標。

## 特色

<table>
<tr>
<td width="50%" valign="top">

### 標籤不擋路
每個標籤都放在元素文字的旁邊，絕不會蓋住你要點按的文字或圖像。即使在密集的列表與工具列中，每個項目也只有一個標籤。

<img src="docs/images/elements.png" alt="檔案視窗中位於每個項目旁的標籤">

</td>
<td width="50%" valign="top">

### 顏色區分
相鄰的標籤使用明顯不同的顏色，元素也會以相同顏色著色，讓每個標籤與其元素一眼就能對應。輸入一個字母後，只會留下符合的項目。共有五種配色方案，包括一種色盲友善的配色。

<img src="docs/images/color-coding.png" alt="輸入字母前後的顏色區分標籤">

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 其他地方交給網格
畫布、遊戲、遠端桌面、沒有標籤的圖像：按下 **⇧⌘K**，就能觸及任何顯示器上的任何位置。

<img src="docs/images/grid.png" alt="覆蓋整個螢幕的網格標籤">

</td>
<td width="50%" valign="top">

### 拖移與截圖
按**空白鍵**按住按鈕，輸入第二個標籤拖移到該處，再按一次**空白鍵**放下。連 macOS 截圖工具（⇧⌘4）都能操作。

<img src="docs/images/screenshot-demo.gif" alt="用網格標籤和空白鍵截圖">

</td>
</tr>
</table>

還有更多：

- **看得見「輔助使用」遺漏之處。** 可選用 Apple Vision OCR，為未提供控制項資訊的 App 中的可見文字加上標籤，並可同時辨識多種語言。
- **平滑捲動模式。** 按 **⌃J**，再用 **HJKL** 或方向鍵捲動，平滑度可調整；按其他鍵即結束，該鍵照常傳給 App。在 VS Code 與其他 Electron App 中也能使用。
- **保留你的快捷鍵。** 標籤顯示時，⌘C、⌘V、⌘W、Spotlight 以及其他 Spray Can 沒有用到的快捷鍵都照常運作。
- **跟著你走。** 切換分頁、視窗或 App（即使用 ⌘Tab）時，新的標籤就會出現。
- **原生打造。** 以 Swift 與 AppKit 開發，在 macOS 26 使用 Liquid Glass，介面提供六種語言。

## 四種模式

| 模式 | 快捷鍵 | 用途 |
| --- | --- | --- |
| **元素** | ⇧⌘J | 按鈕、連結、列、欄位與 OCR 文字 |
| **網格** | ⇧⌘K | 任何顯示器上的任何位置 |
| **自由模式** | ⇧⌘L | 以小幅或整格的步距移動指標 |
| **捲動** | ⌃J | HJKL 捲動、半頁捲動、跳到頂端與底部 |

所有全域快捷鍵都可以在「設定」中更改。

## 速查表

| 按鍵 | 動作 |
| --- | --- |
| 輸入標籤 | 將指標移到該處 |
| **Return** | 點按 · 快速按兩次：連按 · 按住：右鍵點按 |
| `]` / `[` / `\` | 右鍵點按／中鍵點按／連按 |
| **空白鍵**或 `=` | 按住按鈕以拖移；再按一次放下 |
| 方向鍵 · ⌥ 方向鍵 | 將指標移動一點點 · 一整格 |
| ⇧ 方向鍵 | 捲動 |
| **Esc** | 清除已輸入的字母，再按一次即結束 |

完整列表（包括 Emacs 與 vi 按鍵）請參閱 [SHORTCUTS.md](docs/SHORTCUTS.md)。

## 依你的喜好調整

![外觀設定](docs/images/appearance.png)

- 標籤位置、大小、偏移，以及 Liquid Glass 或純色背景
- 顏色區分（五種配色方案）、元素著色與著色不透明度
- 捲動平滑度，以及捲動模式下的指標位置
- 標籤輸入完成時立即點按，以及按兩次 Return 進行連按
- 開啟或關閉 OCR，以及其辨識語言
- 所有全域快捷鍵，以及選用的 vi 按鍵

## 安裝

```sh
brew install --cask kymer0615/tap/spray-can
open "/Applications/Spray Can.app"
```

使用 `brew update && brew upgrade --cask kymer0615/tap/spray-can` 更新；使用 `brew uninstall --cask spray-can` 移除（偏好設定會保留）。你也可以從 [Releases](https://github.com/Kymer0615/spray_can/releases) 下載通用 ZIP 檔，再將 **Spray Can.app** 移到「應用程式」資料夾。

Spray Can 會要求：

1. **輔助使用**：用來尋找控制項、擷取導覽按鍵，以及移動、點按、拖移與捲動。
2. **螢幕錄製**（選用）：僅用於裝置端 OCR，以及尋找標籤旁的文字。

各版本皆**使用專案自有憑證簽署，未經公證**。所有版本都使用同一張憑證簽署，因此更新後 macOS 會保留 Spray Can 的權限（自 0.1.7 起）。如果 macOS 阻擋了首次開啟，請使用**系統設定 → 隱私權與安全性 → 強制打開**。發行封存檔及其 SHA-256 檢查碼都有版本編號；請參閱[發行說明](docs/RELEASING.md)。

## 隱私權

一切都在你的 Mac 上執行。OCR 使用裝置端的 Apple Vision；截圖只在記憶體中處理後即丟棄。沒有截圖紀錄、沒有分析追蹤、沒有雲端推論，也不需要帳號。

## OCR

OCR 可以**同時讀取多種語言**。在**一般 → 文字辨識語言**中選擇語言並排列順序。使用相同書寫系統的語言（英文、法文、西班牙文……）會一起辨識；每多一種書寫系統（中文、日文、韓文……），就會在同一張截圖上多一輪辨識，因此掃描會稍微久一些。預設情況下，Spray Can 會選取你 Mac 的偏好語言再加上英文。

OCR 辨識的是文字所在位置，而非該文字能否點按，因此文字標籤可能會指向標題。遇到沒有標籤的圖像與自訂畫布時，請使用網格。相容性與測試狀態請參閱 [VALIDATION.md](docs/VALIDATION.md)。

## 從原始碼建置

需要 **Xcode 26+**。

```sh
scripts/test.sh            # core tests + localization check
scripts/build.sh           # universal Release build
scripts/install-local.sh
```

更多工具：`scripts/render-docs.sh`（README 圖片）、`scripts/snapshot-labels.sh`（在真實視窗上顯示標籤）、`scripts/integration-test.sh`、`swift scripts/ocr-smoke.swift`、`python3 scripts/check-localizations.py`。`SprayCanCore` 包含工作階段狀態機、標籤放置與其他純邏輯；`Sources/SprayCanApp` 包含 App 本身、事件擷取、元素探索與覆蓋層。請參閱 [AGENTS.md](AGENTS.md) 與[架構筆記](docs/ARCHITECTURE.md)。

## 狀態

Spray Can 0.1.15 適用於 macOS 14 及更新版本。導覽核心已通過 1,000 次快速啟動循環的壓力測試，且一個原生測試環境完成了 60 次元素／網格點按循環，沒有遺漏點按或輸入外洩。第三方 App、多台顯示器、全螢幕與較舊的 macOS 版本仍在驗證中；請參閱 [VALIDATION.md](docs/VALIDATION.md)。

## 社群

歡迎提出[問題與功能構想](https://github.com/Kymer0615/spray_can/issues)、協助測試，以及[貢獻程式碼](https://github.com/Kymer0615/spray_can/pulls)，特別是輔助使用的涵蓋範圍、OCR 驗證、互動設計、文件與跨 App 測試。

<p>
  <a href="https://buymeacoffee.com/ziyang"><img src="docs/images/buymeacoffee.png" width="28" alt="請我喝杯咖啡"></a>
  如果 Spray Can 對你有幫助，歡迎<a href="https://buymeacoffee.com/ziyang">請我喝杯咖啡</a>。支持完全自由，也絕不會解鎖任何功能。
</p>

## 致謝

原創實作與美術素材皆依 [MIT License](LICENSE) 釋出。操作流程靈感來源：[Scoot](https://github.com/mjrusso/scoot) · [Vimac](https://github.com/nchudleigh/vimac)。未包含上述任一專案的原始碼或視覺素材。
