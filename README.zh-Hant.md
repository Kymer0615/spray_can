<p align="center">
  <img src="docs/images/icon.png" width="112" alt="Spray Can App 圖像">
</p>

<h1 align="center">Spray Can</h1>

<p align="center">
  <strong>看得見「輔助使用」遺漏之處的鍵盤導覽工具。</strong><br>
  透過標籤、網格與私密的裝置端 OCR 操作你的 Mac。
</p>

<p align="center">
  macOS 14+ · Apple Silicon 與 Intel · Swift + AppKit · 100% 本機處理
</p>

<p align="center">
  🌐 <a href="README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <strong>繁體中文</strong> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a>
</p>

<p align="center"><em>本文件為翻譯版本；如與英文版 README 有出入，以英文版為準。</em></p>

<p align="center">
  <a href="https://buymeacoffee.com/ziyang">
    <img src="docs/images/buymeacoffee.png" width="36" alt="請我喝杯咖啡"><br>
    支持 Spray Can
  </a>
</p>

**依 [MIT License](LICENSE) 免費開放原始碼。**
沒有訂閱、付費方案、分析追蹤或雲端 OCR。

![元素導覽](docs/images/elements.png)

Spray Can 讓你**無須伸手拿滑鼠，就能點按、拖移、捲動與導覽**。

按下 **⇧⌘J**，輸入標籤，再按 **Return**。

有別於只依賴 macOS「輔助使用」的工具，Spray Can 還能**完全在裝置端使用 Apple Vision OCR**，為 App 未透過輔助使用樹狀結構提供的可見文字加上標籤。

截圖絕不會離開你的 Mac。

## 看得更多，觸及一切

Spray Can 結合三層定位方式：

- **輔助使用** — 精準定位控制項、按鈕、欄位、列、選單與系統介面。
- **裝置端 OCR** — 在「輔助使用」未提供文字時，辨識畫面上可見的文字。
- **網格** — 觸及其他所有位置，包括自訂畫布與沒有標籤的區域。

OCR 使用 **ScreenCaptureKit + Apple Vision**，並在本機執行。擷取的畫面只在記憶體中處理後即丟棄 — 沒有雲端推論、截圖紀錄或分析追蹤。

![元素操作流程](docs/images/element-demo.gif)

## 四種導覽方式

| 模式 | 快捷鍵 | 用途 |
| --- | --- | --- |
| **元素** | ⇧⌘J | 可存取的控制項 + OCR 文字 |
| **網格** | ⇧⌘K | 任一已連接顯示器上的任何位置 |
| **自由模式** | ⇧⌘L | 以鍵盤精準移動指標 |
| **捲動** | ⌃J | Vim 風格的 HJKL 捲動 |

全域快捷鍵皆可完全自訂。

## 設計上不打擾你

導覽時，Spray Can 會讓目標 App 保持在焦點上。

鍵盤輸入的擷取獨立於覆蓋層，因此在元素探索與 OCR 於背景繼續進行時，你就能立即開始輸入。開始輸入後，較晚完成的 OCR 結果不會再變更標籤。

點按之前，會重新驗證可存取的目標，以減少目標過期造成的錯誤。

標籤會跟隨你的焦點。當目標視窗改變時 — 切換分頁、開啟視窗、移動或調整視窗大小，或以 ⌘Tab 或點按切換到其他 App — Spray Can 會重新搜尋並顯示新的標籤。已輸入一半的標籤會被清除，進行中的拖移會被取消，而不會放到意料之外的位置。網格與自由模式涵蓋整個螢幕，因此不受影響。

## 標籤清晰，即使介面密集

標籤緊貼在元素**旁邊**——通常就在其文字之後——絕不會遮住你要點按的文字或圖像。每個項目只有一個標籤，只有在標籤無法貼近元素的少數情況下才會出現連接線。你可以在**外觀**中選擇元素的左側、右側、上方、下方或元素之上，並透過水平與垂直偏移微調位置。

**顏色區分**會為相鄰的標籤使用明顯不同的顏色，並以標籤的顏色為元素著色，讓每個標籤與其元素一眼就能對應。著色可以永遠顯示、只在輸入時顯示或關閉，不透明度也可以調整。輸入一個字母後，只會保留符合的元素，並以各自的顏色加上外框。

![輸入字母前後的顏色區分](docs/images/color-coding.png)

![列表與工具列中位於文字旁的標籤](docs/images/clustered-labels.png)

## 拖移、點按、捲動

Spray Can 支援：

- 左鍵、中鍵、右鍵點按與按兩下
- 搭配修飾鍵點按
- 拖放
- 精細移動與整格移動指標
- 跳到螢幕邊緣
- Vim 風格捲動
- 多台顯示器

拖移範例：

`⇧⌘K` → 輸入來源標籤 → `空白鍵` → 輸入目的地標籤 → `空白鍵`

按住的按鈕會平順移動到每個目的地，因此追蹤指標的 App——包括 macOS 截圖工具（⇧⌘4）——都能跟著拖移。

![網格拖移操作流程](docs/images/drag-demo.gif)

## 原生 macOS 體驗

![設定](docs/images/settings.png)

Spray Can 以 Swift 與 AppKit 打造。

它在 **macOS 26+ 使用 Liquid Glass**，在 macOS 14–15 使用原生材質，並遵循「減少透明度」設定。在「外觀」中關閉**使用 Liquid Glass**，即可讓標籤與狀態面板改用純色背景。關閉玻璃效果後，可以調整標籤背景的不透明度，而文字不會跟著變淡。啟用玻璃效果或「減少透明度」時，此滑桿會停用。

你可以自訂：

- 導覽快捷鍵
- 目標範圍
- OCR 及其辨識語言
- vi 按鍵設定
- 標籤位置與偏移
- 顏色區分、元素著色與著色不透明度
- 標籤大小
- 網格間距
- 背景不透明度
- 標籤、OCR、網格、文字與選取的顏色
- 介面語言

Spray Can 的介面提供 English、简体中文、繁體中文、日本語、한국어 與 Español。預設會跟隨你 Mac 的語言；你也可以在**一般 → 語言**中選擇其他語言，並在出現提示時重新啟動 Spray Can。

![外觀自訂](docs/images/appearance.png)

## 安裝

從[我的 Homebrew tap](https://github.com/Kymer0615/homebrew-tap) 安裝：

```sh
brew install --cask kymer0615/tap/spray-can
open "/Applications/Spray Can.app"
```

更新或移除：

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
brew uninstall --cask spray-can
```

一般解除安裝會保留偏好設定。如果你曾手動安裝，請先結束 Spray Can，並將該副本移出「應用程式」資料夾後再改用 Homebrew，以免同時執行兩個副本。

你也可以從 [Releases](https://github.com/Kymer0615/spray_can/releases) 下載通用 ZIP 檔，解壓縮後將 **Spray Can.app** 移到「應用程式」資料夾。

各版本皆**使用專案自有憑證簽署，未經公證**。所有版本都使用同一憑證簽署，因此更新後 macOS 會保留 Spray Can 的權限（自 0.1.7 起；從較早版本更新時需再授予一次）。如果 macOS 阻擋了你信任的版本：

**系統設定 → 隱私權與安全性 → 強制打開**

Spray Can 可能會要求：

1. **輔助使用** — 探索控制項、擷取導覽按鍵，並執行指標操作。
2. **螢幕錄製** — 選用，僅用於裝置端 OCR。

鍵盤擷取使用「輔助使用」權限，不需要另外設定「輸入監控」。「權限」頁面會顯示擷取是否實際在執行中。

發行封存檔及其 SHA-256 檢查碼都有版本編號。請參閱[發行說明](docs/RELEASING.md)。

## 隱私權

Spray Can 的設計以本機運作為原則。

- OCR 透過**裝置端的 Apple Vision** 執行
- 截圖只在記憶體中處理後即丟棄
- 沒有截圖紀錄
- 沒有分析追蹤
- 沒有雲端推論
- 不需要帳號或訂閱

## OCR 語言

OCR 可以**同時讀取多種語言**。在**一般 → 文字辨識語言**中，選擇 Apple Vision 在你的 Mac 上支援的任何語言並排列順序。所有選取語言的文字都會在同一次掃描中加上標籤，因此英文工具列、中文文件和日文選單都能一起觸及。

使用相同書寫系統的語言（例如英文、法文和西班牙文）會一起辨識。每多一種書寫系統（例如中文、日文或韓文），就會在同一張截圖上多一輪辨識，因此掃描會稍微久一些。預設情況下，Spray Can 會選取你 Mac 的偏好語言再加上英文。

## OCR 的限制

OCR 辨識的是**文字位置**，而非該文字是否可以點按。

因此，辨識出的標籤可能指向標題或其他無法互動的文字。它也無法偵測所有沒有標籤的圖像或任意的視覺控制項。

遇到這些情況時，請使用**網格模式**。

目前的相容性與測試狀態請參閱 [VALIDATION.md](docs/VALIDATION.md)。

## 建置

需要 **Xcode 26+**。

```sh
scripts/test.sh
scripts/build.sh
scripts/install-local.sh
```

開發用：

```sh
swift scripts/generate-artwork.swift
python3 scripts/generate-project.py
scripts/render-docs.sh
scripts/integration-test.sh
swift scripts/ocr-smoke.swift
swift scripts/ocr-smoke.swift image.png --languages en-US,zh-Hans,ja-JP --expect "Open,打开,開く"
python3 scripts/check-localizations.py
scripts/release.sh 0.1.7 adhoc
```

在 Xcode 中開啟 `SprayCan.xcodeproj`。

介面翻譯位於 `Resources/<language>.lproj/Localizable.strings`；英文鍵值即為原文。`scripts/check-localizations.py` 會檢查每種語言是否具備所有鍵值，且佔位符號一致。

`SprayCanCore` 包含工作階段狀態機、標籤產生與放置、OCR 語言分組、重新整理規則、幾何運算與快捷鍵對應。`Sources/SprayCanApp` 包含 App 介面、事件擷取、探索提供者、滑鼠驅動程式與覆蓋層。

## 狀態

Spray Can 0.1.7 適用於 macOS 14 及更新版本。

導覽核心已通過 **1,000 次快速啟動循環**的壓力測試，且一個原生測試環境完成了 **60 次元素／網格點按循環**，沒有遺漏點按或輸入外洩。

第三方 App、多台顯示器、全螢幕與跨版本的相容性仍在驗證中。

請參閱 [VALIDATION.md](docs/VALIDATION.md)。

## 社群

歡迎提出[問題與功能構想](https://github.com/Kymer0615/spray_can/issues)、協助測試，以及[貢獻程式碼](https://github.com/Kymer0615/spray_can/pulls)。

特別需要協助的領域包括：

* 輔助使用的涵蓋範圍
* OCR 驗證
* 介面與互動設計
* 文件
* 跨 App 測試

如果 Spray Can 對你有幫助，歡迎[請我喝杯咖啡](https://buymeacoffee.com/ziyang)。支持完全自由，也絕不會解鎖任何功能。

## 致謝

原創實作與美術素材皆依 [MIT License](LICENSE) 釋出。

操作流程靈感來源：
[Scoot](https://github.com/mjrusso/scoot) ·
[Vimac](https://github.com/nchudleigh/vimac)

未包含上述任一專案的原始碼或視覺素材。

請參閱[架構與研究筆記](docs/ARCHITECTURE.md)。
