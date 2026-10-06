<p align="center">
  <img src="docs/images/icon.png" width="112" alt="Spray Can 앱 아이콘">
</p>

<h1 align="center">Spray Can</h1>

<p align="center">
  <strong>손쉬운 사용이 놓치는 것까지 보는 키보드 탐색.</strong><br>
  레이블, 그리드, 기기 내 비공개 OCR로 Mac을 탐색하세요.
</p>

<p align="center">
  macOS 14+ · Apple Silicon 및 Intel · Swift + AppKit · 100% 로컬 처리
</p>

<p align="center">
  🌐 <a href="README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <strong>한국어</strong> · <a href="README.es.md">Español</a>
</p>

<p align="center"><em>이 문서는 번역본입니다. 내용이 다를 경우 영어 README가 우선합니다.</em></p>

<p align="center">
  <a href="https://buymeacoffee.com/ziyang">
    <img src="docs/images/buymeacoffee.png" width="36" alt="커피 한 잔 사 주기"><br>
    Spray Can 후원하기
  </a>
</p>

**[MIT License](LICENSE)에 따른 무료 오픈 소스입니다.**
구독, 유료 등급, 분석, 클라우드 OCR이 없습니다.

![요소 탐색](docs/images/elements.png)

Spray Can을 사용하면 **마우스에 손대지 않고 클릭, 드래그, 스크롤, 탐색**할 수 있습니다.

**⇧⌘J**를 누르고 레이블을 입력한 다음 **Return**을 누르세요.

macOS 손쉬운 사용에만 의존하는 도구와 달리, Spray Can은 **전적으로 기기 내에서 실행되는 Apple Vision OCR**을 사용해 앱이 손쉬운 사용 트리로 노출하지 않는 화면 속 텍스트에도 레이블을 붙일 수 있습니다.

스크린샷은 절대 Mac 밖으로 나가지 않습니다.

## 더 많이 보고, 어디든 닿기

Spray Can은 세 가지 타기팅 계층을 결합합니다.

- **손쉬운 사용** — 정밀한 컨트롤, 버튼, 필드, 행, 메뉴, 시스템 UI.
- **기기 내 OCR** — 손쉬운 사용으로 노출되지 않는 화면 속 텍스트를 인식합니다.
- **그리드** — 사용자 정의 캔버스나 레이블 없는 영역을 포함해 나머지 모든 곳에 닿습니다.

OCR은 **ScreenCaptureKit + Apple Vision**을 사용하며 로컬에서 실행됩니다. 캡처한 프레임은 메모리에서 처리된 후 폐기되며, 클라우드 추론, 스크린샷 기록, 분석이 없습니다.

![요소 탐색 흐름](docs/images/element-demo.gif)

## 네 가지 탐색 방식

| 모드 | 단축키 | 용도 |
| --- | --- | --- |
| **요소** | ⇧⌘J | 손쉬운 사용 컨트롤 + OCR 텍스트 |
| **그리드** | ⇧⌘K | 연결된 모든 디스플레이의 임의 위치 |
| **자유 이동** | ⇧⌘L | 키보드로 정밀한 포인터 이동 |
| **스크롤** | ⌃J | Vim 스타일 HJKL 스크롤 |

전역 단축키는 모두 변경할 수 있습니다.

## 방해하지 않도록 설계

Spray Can은 탐색하는 동안 대상 앱의 포커스를 유지합니다.

키보드 입력은 오버레이와 독립적으로 캡처되므로, 요소 탐색과 OCR이 백그라운드에서 계속되는 동안에도 바로 입력을 시작할 수 있습니다. 입력을 시작한 후에 도착한 OCR 결과는 레이블을 바꾸지 않습니다.

클릭하기 전에 손쉬운 사용 대상을 다시 확인하여 오래된 대상으로 인한 오류를 줄입니다.

레이블은 포커스를 따라갑니다. 대상 윈도우가 바뀌면 — 탭 전환, 윈도우 열기, 윈도우 이동 또는 크기 조절, ⌘Tab이나 클릭으로 다른 앱으로 이동 — Spray Can이 다시 검색하여 새 레이블을 표시합니다. 입력 중이던 레이블은 지워지고, 진행 중인 드래그는 예상치 못한 곳에 놓이는 대신 취소됩니다. 그리드 모드와 자유 이동 모드는 화면 전체를 대상으로 하므로 영향을 받지 않습니다.

## 복잡한 인터페이스에서도 명확한 레이블

레이블은 요소 **바로 옆**——대개 텍스트 바로 뒤——에 놓이며, 클릭하려는 텍스트나 아이콘을 가리지 않습니다. 항목마다 레이블은 하나이고, 레이블을 요소에 붙일 수 없는 드문 경우에만 연결선이 표시됩니다. **모양**에서 요소의 왼쪽, 오른쪽, 위, 아래 또는 요소 위를 선택하고 가로·세로 오프셋으로 위치를 미세 조정할 수 있습니다.

**색상 구분**은 주변 레이블에 확연히 다른 색을 쓰고 각 요소를 레이블 색으로 옅게 칠해, 레이블과 요소를 한눈에 연결할 수 있게 합니다. 음영은 항상, 입력 중에만 표시하거나 끌 수 있으며 불투명도도 조절할 수 있습니다. 글자를 하나 입력하면 일치하는 요소만 남고 각자의 색으로 테두리가 표시됩니다.

![글자 입력 전후의 색상 구분](docs/images/color-coding.png)

![목록과 도구 막대에서 텍스트 옆에 놓인 레이블](docs/images/clustered-labels.png)

## 드래그, 클릭, 스크롤

Spray Can이 지원하는 기능:

- 왼쪽, 가운데, 오른쪽 클릭 및 이중 클릭
- 보조 키 클릭
- 드래그 앤 드롭
- 미세 이동 및 셀 단위 포인터 이동
- 화면 가장자리로 이동
- Vim 스타일 스크롤
- 다중 디스플레이

드래그 예시:

`⇧⌘K` → 출발 레이블 입력 → `Space` → 도착 레이블 입력 → `Space`

누른 버튼이 각 목적지까지 부드럽게 이동하므로, 포인터를 추적하는 앱(macOS 스크린샷 도구 ⇧⌘4 포함)도 드래그를 따라갑니다.

![그리드 드래그 흐름](docs/images/drag-demo.gif)

## macOS 네이티브 경험

![설정](docs/images/settings.png)

Spray Can은 Swift와 AppKit으로 만들어졌습니다.

**macOS 26 이상에서는 Liquid Glass**를, macOS 14–15에서는 네이티브 재질을 사용하며 투명도 줄이기 설정을 따릅니다. 모양에서 **Liquid Glass 사용**을 끄면 레이블과 상태 패널에 단색 배경을 사용합니다. 글래스를 끄면 텍스트를 흐리게 하지 않고 레이블 배경 불투명도를 조절할 수 있습니다. 글래스나 투명도 줄이기가 켜져 있는 동안에는 슬라이더가 비활성화됩니다.

사용자화할 수 있는 항목:

- 탐색 단축키
- 대상 범위
- OCR 및 인식 언어
- vi 키 설정
- 레이블 위치 및 오프셋
- 색상 구분, 요소 음영, 음영 불투명도
- 레이블 크기
- 그리드 간격
- 배경 불투명도
- 레이블, OCR, 그리드, 텍스트, 선택 색상
- 인터페이스 언어

Spray Can의 인터페이스는 English, 简体中文, 繁體中文, 日本語, 한국어, Español로 제공됩니다. 기본적으로 Mac의 언어를 따르며, **일반 → 언어**에서 다른 언어를 선택한 후 안내에 따라 Spray Can을 재시작하면 됩니다.

![모양 사용자화](docs/images/appearance.png)

## 설치

[Homebrew tap](https://github.com/Kymer0615/homebrew-tap)에서 설치합니다.

```sh
brew install --cask kymer0615/tap/spray-can
open "/Applications/Spray Can.app"
```

업데이트 또는 제거:

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
brew uninstall --cask spray-can
```

일반 제거 시 환경설정은 유지됩니다. 수동으로 설치한 경우, 두 개의 복사본이 실행되지 않도록 Homebrew로 전환하기 전에 Spray Can을 종료하고 해당 복사본을 응용 프로그램 폴더 밖으로 옮기세요.

또는 [Releases](https://github.com/Kymer0615/spray_can/releases)에서 유니버설 ZIP을 다운로드하여 압축을 풀고 **Spray Can.app**을 응용 프로그램 폴더로 옮기세요.

릴리스는 **프로젝트 자체 인증서로 서명되었으며 공증되지 않았습니다**. 모든 릴리스를 같은 인증서로 서명하므로 업데이트해도 macOS가 Spray Can의 권한을 유지합니다(0.1.7부터. 이전 버전에서 업데이트한 경우 한 번만 다시 허용하세요). 신뢰하는 빌드를 macOS가 차단하는 경우:

**시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**

Spray Can이 요청할 수 있는 권한:

1. **손쉬운 사용** — 컨트롤 탐색, 탐색 키 캡처, 포인터 동작 수행.
2. **화면 기록** — 선택 사항이며 기기 내 OCR에만 사용됩니다.

키보드 캡처는 손쉬운 사용 권한을 사용하며, 별도의 입력 모니터링 설정이 필요하지 않습니다. 권한 페이지에서 캡처가 실제로 실행 중인지 확인할 수 있습니다.

릴리스 아카이브와 SHA-256 체크섬은 버전별로 관리됩니다. [릴리스 안내](docs/RELEASING.md)를 참고하세요.

## 개인정보 보호

Spray Can은 로컬에서 작동하도록 설계되었습니다.

- OCR은 **기기 내 Apple Vision**으로 실행됩니다
- 스크린샷은 메모리에서 처리된 후 폐기됩니다
- 스크린샷 기록 없음
- 분석 없음
- 클라우드 추론 없음
- 계정이나 구독 불필요

## OCR 언어

OCR은 **여러 언어를 동시에** 읽을 수 있습니다. **일반 → 텍스트 인식 언어**에서 Mac의 Apple Vision이 지원하는 언어를 선택하고 순서를 정하세요. 선택한 모든 언어의 텍스트에 한 번의 스캔으로 레이블이 붙으므로, 영어 도구 막대, 중국어 문서, 일본어 메뉴에 모두 함께 접근할 수 있습니다.

영어, 프랑스어, 스페인어처럼 같은 문자 체계를 쓰는 언어는 함께 인식됩니다. 중국어, 일본어, 한국어처럼 문자 체계가 하나 추가될 때마다 같은 스크린샷에 인식 과정이 한 번 더 실행되므로 스캔이 조금 더 오래 걸립니다. 기본적으로 Spray Can은 Mac의 선호 언어와 영어를 선택합니다.

## OCR의 한계

OCR은 **텍스트의 위치**를 인식할 뿐, 그 텍스트가 클릭 가능한지는 알 수 없습니다.

따라서 인식된 레이블이 제목이나 기타 상호작용할 수 없는 텍스트를 가리킬 수 있습니다. 또한 레이블 없는 모든 아이콘이나 임의의 시각적 컨트롤을 감지하지는 못합니다.

이런 경우에는 **그리드 모드**를 사용하세요.

현재 호환성 및 테스트 현황은 [VALIDATION.md](docs/VALIDATION.md)를 참고하세요.

## 빌드

**Xcode 26 이상**이 필요합니다.

```sh
scripts/test.sh
scripts/build.sh
scripts/install-local.sh
```

개발용:

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

Xcode에서 `SprayCan.xcodeproj`를 여세요.

인터페이스 번역은 `Resources/<language>.lproj/Localizable.strings`에 있으며, 영어 키가 원문입니다. `scripts/check-localizations.py`는 모든 언어에 모든 키와 일치하는 플레이스홀더가 있는지 확인합니다.

`SprayCanCore`에는 세션 상태 머신, 레이블 생성 및 배치, OCR 언어 그룹화, 새로 고침 규칙, 기하 계산, 단축키 매핑이 들어 있습니다. `Sources/SprayCanApp`에는 앱 UI, 이벤트 캡처, 탐색 제공자, 마우스 드라이버, 오버레이가 들어 있습니다.

## 현황

Spray Can 0.1.7는 macOS 14 이상에서 사용할 수 있습니다.

탐색 코어는 **1,000회의 빠른 활성화 사이클**로 스트레스 테스트를 거쳤으며, 네이티브 테스트 픽스처에서 **60회의 요소/그리드 클릭 사이클**을 클릭 누락이나 입력 유출 없이 완료했습니다.

타사 앱, 다중 디스플레이, 전체 화면, 버전 간 호환성은 아직 검증 중입니다.

[VALIDATION.md](docs/VALIDATION.md)를 참고하세요.

## 커뮤니티

[이슈 및 기능 아이디어](https://github.com/Kymer0615/spray_can/issues), 테스트, [기여](https://github.com/Kymer0615/spray_can/pulls)를 환영합니다.

특히 도움이 되는 분야:

* 손쉬운 사용 지원 범위
* OCR 검증
* UI 및 상호작용 디자인
* 문서
* 여러 앱에서의 테스트

Spray Can이 도움이 되었다면 [커피 한 잔 사 주세요](https://buymeacoffee.com/ziyang). 후원은 선택 사항이며, 후원으로 기능이 잠금 해제되지는 않습니다.

## 크레딧

원본 구현과 아트워크는 [MIT License](LICENSE)로 배포됩니다.

워크플로 영감:
[Scoot](https://github.com/mjrusso/scoot) ·
[Vimac](https://github.com/nchudleigh/vimac)

두 프로젝트의 소스 코드나 시각 자산은 포함되어 있지 않습니다.

[아키텍처 및 연구 노트](docs/ARCHITECTURE.md)를 참고하세요.
