# Windows에서 NoMachine으로 한영 전환하기

이 포크의 **일반 → 원격 입력 설정**은 물리 HID 키보드 없이 전달되는 키 이벤트를 처리합니다. 기본값은 꺼짐입니다. Windows에서 한영키를 오른쪽 Alt로 보내고, Mac에서 **우측 Option ⌥ (Alt)**을 선택하면 됩니다.

## Mac 설정

1. 이 포크를 소스에서 빌드한 gksdud를 실행합니다. 원본 앱과 동시에 실행하지 마세요.
2. 일반 설정에서 **활성화**를 켜고 **접근성 권한 허용**을 진행합니다. 키 이벤트를 바꾸는 기능이므로 입력 모니터링 권한만으로는 충분하지 않습니다.
3. **원격 입력 설정 → 이벤트 기반 전환 사용**을 켭니다.
4. **전달받을 키 → 우측 Option ⌥ (Alt)**을 선택합니다. 일반 설정의 **내부 전환 키**는 F19로 두어도 됩니다. 전달받을 키와 내부 전환 키는 서로 다른 단계입니다.
5. **키 수신 확인 (15초)**을 누르고 Windows의 한영키를 누릅니다. 오른쪽 Option의 macOS 키 코드는 61입니다. 수신 횟수가 늘고 Mac 메뉴바의 입력 언어가 바뀌는지 확인합니다.

이 옵션은 원격 접속을 자동 식별하지 않습니다. 선택한 키는 Mac의 로컬 키보드에서도 전환 전용으로 동작합니다. Command/Control/Shift 등 다른 보조키를 함께 누른 단축키는 보존합니다. 원격용 키는 단독으로 누르세요. 오른쪽 Alt의 다른 기능이 필요하면 F18 같은 전용 키를 전송하는 방법을 사용하세요.

## Windows 설정: AutoHotkey v2

AutoHotkey는 별도로 설치하는 Windows 앱입니다. [공식 사이트](https://www.autohotkey.com/)에서 **v2**를 설치합니다. 아래 스크립트는 레지스트리의 Scancode Map이나 Windows 전역 키 매핑을 변경하지 않습니다. **NoMachine 창이 활성화된 동안만** 한영키를 변환하며, 다른 앱에서는 한영키의 기존 동작을 유지합니다.

아래 내용을 `nomachine-hangul.ahk`로 저장해 실행하세요.

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
SetKeyDelay(10, 10)

#HotIf WinActive("ahk_exe nxplayer.bin") || WinActive("ahk_exe nxplayer.exe")
$vk15:: {
    SendEvent("{RAlt down}{RAlt up}")
    KeyWait("vk15")
}
#HotIf
```

이 예시는 한 번 누르면 한 번 전환하고, 누르고 있는 동안 반복 전환을 막습니다. Windows에서 눌림을 즉시 한 쌍으로 보내므로 gksdud의 ‘길게 눌러 대소문자 전환’은 이 스크립트로 사용할 수 없습니다.

`vk15`는 Windows의 `VK_HANGUL`입니다. 키보드 종류와 Windows 입력 언어에 따라 다른 코드가 들어올 수 있으므로 동작하지 않으면 AutoHotkey의 **Key history**로 실제 VK/스캔 코드를 확인하세요. 무조건 오른쪽 Alt나 특정 스캔 코드라고 가정하지 마세요. NoMachine 창의 실제 프로세스 이름도 Window Spy로 확인하고 필요한 경우 `#HotIf` 조건을 수정하세요.

**대안: F18 전송**

오른쪽 Alt가 클라이언트에서 다른 기능으로 처리되면 `SendEvent("{RAlt down}{RAlt up}")`를 `SendEvent("{F18}")`로 바꾸고, Mac 원격 입력 설정의 전달받을 키도 **F18**로 선택합니다. 내부 전환 키는 **F19**로 유지할 수 있습니다. F19가 이미 Mac까지 정상 전달된다면 기존 시스템 단축키 경로로도 전환될 수 있습니다.

‘우측 Command’를 시험하려고 Windows 키를 보냈을 때 **Windows 시작 메뉴가 열린 것은 Mac에 전달됐다는 증거가 아닙니다.** 반드시 Mac 쪽 수신 상태와 입력 언어 변화를 확인하세요. NoMachine의 Ctrl/Command 교환 옵션도 수신 키에 영향을 줄 수 있습니다.

## 안 될 때 확인할 순서

| 관측 | 다음 확인 |
| --- | --- |
| Mac에 A/B는 들어오지만 한영키 이벤트는 없음 | Windows의 한영키 감지, AHK 실행, 실제 NoMachine 프로세스, 클라이언트 입력 언어와 키 캡처 설정 |
| Mac에 코드 61이 들어오지만 횟수는 늘지 않음 | 원격 모드·앱 활성화·우측 Option 선택·접근성 권한, 다른 보조키가 눌려 있는지 |
| 횟수는 늘지만 입력 언어가 그대로임 | macOS 한국어/영어 입력 소스, 내부 F키 단축키 충돌, 다른 키보드 유틸 |
| HID 키보드가 없다고 표시됨 | 물리 키보드 매핑 대상이 없다는 뜻. 이벤트 기반 전환 상태와 별도로 확인 |
| 빌드 교체 뒤 권한이 켜져 있는데 수신/변환이 안 됨 | 앱 종료 후 접근성 항목에서 기존 앱을 제거하고 현재 `/Applications/gksdud.app`을 다시 추가. ad-hoc 서명 변경으로 기존 승인이 맞지 않을 수 있음 |

NoMachine의 **Ctrl+Alt+0 → Input → Grab the keyboard input**도 확인하세요. 이 옵션만으로 모든 언어 키가 전달되는 것은 아닙니다. 수신되지 않은 이벤트를 Mac 앱에서 복원할 수는 없습니다.

진단 버튼은 설정 창이 열려 있는 15초 동안 코드·이벤트 종류·flags만 화면에 표시합니다. 입력 문자열이나 키 이벤트를 파일로 저장하지 않습니다. 진단 자체가 한영 전환을 끄지는 않습니다.

## 중지와 원복

- Windows: 알림 영역의 AutoHotkey 아이콘에서 **Exit**로 스크립트를 종료하면 변환이 멈춥니다. 다른 앱의 한영키 설정은 바뀌지 않습니다.
- Mac: **이벤트 기반 전환 사용**을 끕니다. 전체 gksdud를 정상 종료하면 앱이 관리하던 HID 매핑과 시스템 단축키도 기존 값으로 복원합니다.
- Windows 자동 시작은 양쪽에서 실제 동작을 확인한 뒤 원하는 경우에만 등록하세요.

## 검증 범위

자동 테스트는 보조키/F키 판정, 반복 억제, 누름·뗌 관리, 다른 보조키 조합 보존, 설정 복원, HID 장치 없는 환경을 검사합니다. Windows의 AHK 실행과 실제 NoMachine 전달은 별도 사용자 입력으로 확인해야 합니다. 화면 렌더 테스트나 Mac에서 합성한 입력만으로 Windows E2E 성공을 주장하지 않습니다.

## 참고

- [NoMachine: 서버 측 키 매핑을 거치지 않는 보조키 입력](https://forum.nomachine.com/archive/topic/remap-option-and-command-keys)
- [NoMachine: Ctrl/Command 교환 옵션](https://kb.nomachine.com/AR10W01331)
- [AutoHotkey v2: 창별 조건부 단축키](https://www.autohotkey.com/docs/v2/lib/_HotIf.htm)
- [Microsoft: VK_HANGUL 0x15](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)
