<p align="center">
  <img src="docs/images/icon.png" width="112" alt="Spray Can 앱 아이콘">
</p>

<h1 align="center">Spray Can</h1>

<p align="center">
  <strong>마우스에 손대지 않고 Mac의 무엇이든 클릭하세요.</strong><br>
  컨트롤마다 레이블을, 나머지 모든 곳에는 그리드를, 그 사이의 텍스트에는 기기 내 비공개 OCR을.
</p>

<p align="center">
  macOS 14+ · Apple Silicon 및 Intel · 무료 오픈 소스(MIT) · 100% 기기 내 처리
</p>

<p align="center">
  🌐 <a href="README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <strong>한국어</strong> · <a href="README.es.md">Español</a>
</p>

```sh
brew install --cask kymer0615/tap/spray-can
```

![Spray Can이 윈도우에 레이블을 붙이고 파일을 클릭하는 모습](docs/images/element-demo.gif)

## 작동 방식

1. **⇧⌘J**를 누릅니다. 모든 버튼, 링크, 행, 필드의 텍스트 바로 옆에 짧은 레이블이 붙습니다.
2. 레이블을 입력합니다. 포인터가 그곳으로 이동합니다.
3. **Return**을 눌러 클릭합니다. **두 번** 누르면 이중 클릭합니다.

마우스도, 트랙패드도, 커서를 찾아 헤맬 필요도 없습니다.

## 주요 기능

<table>
<tr>
<td width="50%" valign="top">

### 방해하지 않는 레이블
각 레이블은 요소의 텍스트 옆에 놓이며, 클릭하려는 텍스트나 아이콘을 가리지 않습니다. 빽빽한 목록과 도구 막대에서도 항목마다 레이블은 하나뿐입니다.

<img src="docs/images/elements.png" alt="파일 윈도우의 각 항목 옆에 놓인 레이블">

</td>
<td width="50%" valign="top">

### 색상 구분
주변 레이블은 확연히 다른 색을 쓰고 각 요소도 같은 색으로 옅게 칠해지므로, 레이블과 요소를 한눈에 연결할 수 있습니다. 글자를 하나 입력하면 일치하는 요소만 남습니다. 색각 이상 친화 구성을 포함해 다섯 가지 색 구성을 제공합니다.

<img src="docs/images/color-coding.png" alt="글자 입력 전후의 색상 구분 레이블">

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 나머지 모든 곳에는 그리드
캔버스, 게임, 원격 데스크탑, 레이블 없는 아이콘도 **⇧⌘K**를 누르면 어느 디스플레이의 어느 지점이든 닿을 수 있습니다.

<img src="docs/images/grid.png" alt="화면을 덮은 그리드 레이블">

</td>
<td width="50%" valign="top">

### 드래그와 스크린샷
**Space**를 눌러 버튼을 누른 채로 두고, 두 번째 레이블을 입력해 그곳까지 드래그한 다음, **Space**를 다시 눌러 놓습니다. macOS 스크린샷 도구(⇧⌘4)도 조작할 수 있습니다.

<img src="docs/images/screenshot-demo.gif" alt="그리드 레이블과 Space로 스크린샷 찍기">

</td>
</tr>
</table>

그 밖에도:

- **손쉬운 사용이 놓치는 것까지.** 선택 사항인 Apple Vision OCR이 컨트롤을 노출하지 않는 앱에서도 화면 속 텍스트에 레이블을 붙이며, 여러 언어를 동시에 인식합니다.
- **부드러운 스크롤 모드.** **⌃J**를 누른 다음 **HJKL**로 스크롤하며, 부드러움을 조절할 수 있습니다. VS Code 및 기타 Electron 앱에서도 작동합니다.
- **단축키는 그대로.** 레이블이 표시된 동안에도 ⌘C, ⌘V, ⌘W, Spotlight 등 Spray Can이 쓰지 않는 단축키는 계속 작동합니다.
- **사용자를 따라갑니다.** 탭, 윈도우, 앱을 전환하면(⌘Tab 포함) 새 레이블이 나타납니다.
- **네이티브.** Swift와 AppKit으로 만들었고, macOS 26에서는 Liquid Glass를 사용하며, 인터페이스는 6개 언어로 제공됩니다.

## 네 가지 모드

| 모드 | 단축키 | 용도 |
| --- | --- | --- |
| **요소** | ⇧⌘J | 버튼, 링크, 행, 필드, OCR 텍스트 |
| **그리드** | ⇧⌘K | 모든 디스플레이의 임의 위치 |
| **자유 이동** | ⇧⌘L | 포인터를 조금씩 또는 셀 단위로 이동 |
| **스크롤** | ⌃J | HJKL 스크롤, 반 페이지, 맨 위와 맨 아래 |

전역 단축키는 모두 설정에서 변경할 수 있습니다.

## 단축키 요약

| 키 | 동작 |
| --- | --- |
| 레이블 입력 | 포인터를 해당 위치로 이동 |
| **Return** | 클릭(빠르게 두 번: 이중 클릭) |
| `]` / `[` / `\` | 오른쪽 클릭 / 가운데 클릭 / 이중 클릭 |
| **Space** 또는 `=` | 버튼을 누른 채로 드래그, 다시 누르면 놓기 |
| 화살표 · ⌥ 화살표 | 포인터를 조금 · 한 셀만큼 이동 |
| ⇧ 화살표 | 스크롤 |
| **Esc** | 입력한 글자를 지우고, 다시 누르면 종료 |

Emacs 및 vi 키 설정을 포함한 전체 목록은 [SHORTCUTS.md](docs/SHORTCUTS.md)를 참고하세요.

## 나에게 맞게 설정

![모양 설정](docs/images/appearance.png)

- 레이블 위치, 크기, 오프셋, Liquid Glass 또는 일반 배경
- 다섯 가지 색 구성의 색상 구분, 요소 음영, 음영 불투명도
- 스크롤 부드러움, 스크롤 모드의 포인터 위치
- 레이블 입력이 끝나면 바로 클릭, Return을 두 번 눌러 이중 클릭
- OCR 켜기/끄기 및 텍스트 인식 언어
- 모든 전역 단축키와 선택 사항인 vi 커서 키

## 설치

```sh
brew install --cask kymer0615/tap/spray-can
open "/Applications/Spray Can.app"
```

업데이트는 `brew update && brew upgrade --cask kymer0615/tap/spray-can`, 제거는 `brew uninstall --cask spray-can`으로 합니다(환경설정은 유지됩니다). [Releases](https://github.com/Kymer0615/spray_can/releases)에서 유니버설 ZIP을 다운로드하여 **Spray Can.app**을 응용 프로그램 폴더로 옮겨도 됩니다.

Spray Can이 요청하는 권한:

1. **손쉬운 사용**: 컨트롤을 찾고, 탐색 키를 캡처하고, 포인터 이동, 클릭, 드래그, 스크롤을 수행합니다.
2. **화면 기록**(선택 사항): 기기 내 OCR과 레이블 옆 텍스트 찾기에만 사용됩니다.

릴리스는 **프로젝트 자체 인증서로 서명되었으며 공증되지 않았습니다**. 모든 릴리스를 같은 인증서로 서명하므로 업데이트해도 macOS가 Spray Can의 권한을 유지합니다(0.1.7부터). macOS가 처음 실행을 차단하면 **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**를 사용하세요. 릴리스 아카이브와 SHA-256 체크섬은 버전별로 관리됩니다. [릴리스 안내](docs/RELEASING.md)를 참고하세요.

## 개인정보 보호

모든 처리는 Mac 안에서 이루어집니다. OCR은 기기 내 Apple Vision을 사용하며, 스크린샷은 메모리에서 처리된 후 폐기됩니다. 스크린샷 기록, 분석, 클라우드 추론, 계정이 모두 없습니다.

## OCR

OCR은 **여러 언어를 동시에** 읽습니다. **일반 → 텍스트 인식 언어**에서 언어를 선택하고 순서를 정하세요. 영어, 프랑스어, 스페인어처럼 같은 문자 체계를 쓰는 언어는 함께 인식됩니다. 중국어, 일본어, 한국어처럼 문자 체계가 하나 추가될 때마다 같은 스크린샷에 인식 과정이 한 번 더 실행되므로 스캔이 조금 더 오래 걸립니다. 기본적으로 Spray Can은 Mac의 선호 언어와 영어를 선택합니다.

OCR은 텍스트의 위치를 찾을 뿐, 클릭 가능한지는 알 수 없으므로 텍스트 레이블이 제목을 가리킬 수도 있습니다. 레이블 없는 아이콘이나 사용자 정의 캔버스에는 그리드를 사용하세요. 호환성 및 테스트 현황은 [VALIDATION.md](docs/VALIDATION.md)를 참고하세요.

## 소스에서 빌드

**Xcode 26 이상**이 필요합니다.

```sh
scripts/test.sh            # core tests + localization check
scripts/build.sh           # universal Release build
scripts/install-local.sh
```

기타 도구: `scripts/render-docs.sh`(README 이미지), `scripts/snapshot-labels.sh`(실제 윈도우 위의 레이블), `scripts/integration-test.sh`, `swift scripts/ocr-smoke.swift`, `python3 scripts/check-localizations.py`. `SprayCanCore`에는 세션 상태 머신, 레이블 배치 및 기타 순수 로직이 들어 있고, `Sources/SprayCanApp`에는 앱, 이벤트 캡처, 탐색, 오버레이가 들어 있습니다. [AGENTS.md](AGENTS.md)와 [아키텍처 노트](docs/ARCHITECTURE.md)를 참고하세요.

## 현황

Spray Can 0.1.13은 macOS 14 이상에서 실행됩니다. 탐색 코어는 1,000회의 빠른 활성화 사이클로 스트레스 테스트를 거쳤으며, 네이티브 테스트 픽스처에서 60회의 요소/그리드 클릭 사이클을 클릭 누락이나 입력 유출 없이 완료했습니다. 타사 앱, 다중 디스플레이, 전체 화면, 이전 macOS 버전은 아직 검증 중입니다. [VALIDATION.md](docs/VALIDATION.md)를 참고하세요.

## 커뮤니티

[이슈 및 기능 아이디어](https://github.com/Kymer0615/spray_can/issues), 테스트, [기여](https://github.com/Kymer0615/spray_can/pulls)를 환영합니다. 특히 손쉬운 사용 지원 범위, OCR 검증, 상호작용 디자인, 문서, 여러 앱에서의 테스트에 도움을 주시면 좋겠습니다.

<p>
  <a href="https://buymeacoffee.com/ziyang"><img src="docs/images/buymeacoffee.png" width="28" alt="커피 한 잔 사 주기"></a>
  Spray Can이 도움이 되었다면 <a href="https://buymeacoffee.com/ziyang">커피 한 잔 사 주세요</a>. 후원은 선택 사항이며, 후원으로 기능이 잠금 해제되지는 않습니다.
</p>

## 크레딧

원본 구현과 아트워크는 [MIT License](LICENSE)로 배포됩니다. 워크플로 영감: [Scoot](https://github.com/mjrusso/scoot) · [Vimac](https://github.com/nchudleigh/vimac). 두 프로젝트의 소스 코드나 시각 자산은 포함되어 있지 않습니다.
