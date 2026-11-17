# 검증 결과 (Study Blocks 1.1)

2026-11-17, macOS 26.6.2 / Apple Silicon / Xcode 27.2.

## 1. 자동 검증 (Unit Tests & Persistence Probe)

`./Tools/test.sh`: **XCTest 17개, 실패 0개**. SwiftData 실제 모델과 저장 컨텍스트(인메모리 및 디스크 저장소)를 사용합니다.

| 검증 항목 | 결과 |
| --- | --- |
| 강의 완료 → 다음 강의 자동 계산, 마지막 강의 완료 → 완강 처리 | 통과 |
| 중복 완료 방지, 다른 화면에서 완료한 블록과 강좌 진도의 상태 일치 | 통과 |
| 완료 취소 → 강좌 진도 및 다음 강의 재계산 | 통과 |
| 건너뛴 강의 처리, 여러 강의 연속 계획, 동일 강의 중복 계획 방지 | 통과 |
| 일반 학습 블록 생성·완료, 강의 시청과 문제 풀이의 독립 상태 유지 | 통과 |
| 미완료 학습 이월 시 블록 ID 유지, 자동 이월 최대 12개 제한 | 통과 |
| 주간 실제 달성 분량 계산(초기 진도 제외), 초과 달성 표시, 완료 취소 반영 | 통과 |
| 저장 실패 주입 시 `ModelContext.rollback()`을 통한 진도·블록·이벤트 전체 롤백 | 통과 |
| 총강의 수 축소 시 확인 요구, 범위 밖 수강 이력 보존 및 재확장 시 복원 | 통과 |
| 반복 복습 생성 중복 방지, 날짜 이동·보관 뒤 중복 생성 방지, 반복 중단 | 통과 |
| 계획 제안 중복 적용 방지, 기존 수동 계획 보존, 목표 변경 반영 | 통과 |
| JSON 백업 왕복·동일 ID 복원, 잘못된 버전·중복 데이터 거부, 실패 시 롤백 | 통과 |
| 한국 표준시(`Asia/Seoul`) 자정 경계, 월요일 주간 경계, 잘못된 날짜 검증 | 통과 |
| 블록 드래그 재정렬, 날짜 이동 시 원본·복사본 중복 방지 | 통과 |
| 강좌 이름·과목 변경 시 연결 블록 자동 갱신 및 사용자 지정 제목 보존 | 통과 |
| 축소된 범위 밖 수강 이력 JSON 왕복 및 완료 취소 | 통과 |
| 새 `ModelContainer`에서 디스크 저장소(`Study.store`) 재오픈 검증 | 통과 |
| 강좌 URL 검증(`validURL`), 인강 블록 외부 링크 연결, 강의별 계획 여부 및 주간 계획 분량 계산 (`1.1`) | 통과 |

별도 프로세스 간 영구 저장 검증(`PersistenceProbe`)도 통과했습니다. 작성 프로세스가 종료된 뒤 읽기 프로세스가 동일한 `Study.store` 파일을 열어 모든 상태를 검증했습니다.

```text
WRITE_OK courses=1 completed=2 next=3
READ_OK courses=1 completed=2 next=3 blocks=2 weekly=10/20
```

---

## 2. 1.0.0 → 1.1 데이터 호환성 검증

1.0.0 버전에서 생성된 실제 SwiftData 저장소(`build/UICheck/Study.store` 및 기본 사용자 저장소)와 JSON 백업(`build/UICheck/backup-ui.json`, `formatVersion = 1`)을 1.1 Release 앱(`build/StudyBlocks.app`)에서 그대로 열어 검증했습니다.

- **Bundle Identifier 보존**: `com.pastelj.studyblocks`
- **스키마 호환성**: `StudySchemaV1` (`1.0.0`) 유지 — 마이그레이션 손실 없이 기존 강좌, 수강 이력(`LessonCompletion`), 학습 블록, 주간 목표, 반복 규칙, 이벤트가 그대로 로드됨을 확인했습니다.
- `build/UICheck/release-1.1-launch.json` 확인 결과:
  - `version = 1.1.0` (`displayVersion = 1.1`)
  - `rendered = true`, `startupError = ""`
  - 1.0 저장소의 강좌(`세젤쉬 확률과 통계` 13/14강, 다음 14강), 블록 3개(완료 2개), 주간 목표(`1/4`)가 손실 없이 그대로 열림을 확인했습니다.

---

## 3. UI 렌더링 및 화면 캡처 검증 (Index & Graphite)

1.1 Release 앱을 실행하여 라이트 모드(Paper), 다크 모드(Graphite), 기본 창(`1180×800`) 및 작은 창(`840×600`)에서 실제 SwiftUI 화면을 렌더링하고 캡처하여 시각적 위계와 가독성을 검수했습니다.

캡처된 검증 이미지(`Docs/Screenshots/`):

- `Docs/Screenshots/today-light.png`: 오늘 화면 (라이트 모드) — 상단 압축 진행 요약 바, 인라인 빠른 추가 바, 핵심/추가 구분, 인강 블록의 `강좌 열기 ↗` 버튼, 완료한 학습 접기 영역 확인
- `Docs/Screenshots/courses-light.png`: 강좌 화면 (라이트 모드) — 수강 중인 강좌와 완강한 강좌 분리, 진도 바 및 남은 강의 수, `다음(N강) 오늘에 추가` 및 `강좌 열기 ↗` 동작 확인
- `Docs/Screenshots/plan-light.png`: 계획 화면 (라이트 모드) — 월~일 7일 인덱스 탭, 주간 학습량 목표(`완료` · `계획됨` · `남은 분량` 비교), 선택 날짜 학습 배치 및 반복 복습 규칙 확인
- `Docs/Screenshots/history-light.png`: 기록 화면 (라이트 모드) — 일일 완료 요약(수강 강의·풀이 문항·복습), 완료한 학습 기록과 접힌 상태의 변경/이월 내역 분리 확인
- `Docs/Screenshots/today-dark.png`, `Docs/Screenshots/courses-dark.png`: 다크 모드 (Graphite) — 어두운 흑연 배경과 카드 표면, 세이지 그린 강조색, 저채도 과목 태그의 명도 대비 확인
- `Docs/Screenshots/today-compact.png`: 작은 창(`840×600`)에서의 레이아웃 안정성 및 줄바꿈 확인

---

## 4. 최종 Release 빌드 및 패키징

`./Tools/build.sh`: **BUILD SUCCEEDED**.

- **유니버설 바이너리 검증**: `lipo -archs build/StudyBlocks.app/Contents/MacOS/StudyBlocks` → `x86_64 arm64`
- **서명 검증**: `codesign --verify --deep --strict build/StudyBlocks.app` 통과 (ad hoc 서명)
- **산출물**:
  - `build/StudyBlocks.app`
  - `build/StudyBlocks-macOS.zip`
  - `Downloads/StudyBlocks-macOS.zip`
  - `.github/workflows/release.yml` (GitHub Actions 자동 테스트·빌드·릴리스 워크플로)
  - `RELEASE_NOTES_1.1.md` (1.1 릴리스 노트)
  - `LICENSE` (MIT License)

---

## 5. 환경적 한계 및 참고 사항

- **서명 및 공증**: 유료 Apple Developer Program 인증서를 사용하지 않으므로 Developer ID 서명 및 Apple 공증(Notarization)은 포함되어 있지 않습니다. 외부 Mac에서 다운로드 후 최초 실행 시 Gatekeeper 우회 절차(`우클릭 → 열기` 또는 `개인정보 보호 및 보안 → 없이 열기`)를 `README.md`와 릴리스 노트에 안내했습니다.
- **물리 장비 범위**: Apple Silicon 환경에서 빌드·실행·검증했으며, Intel Mac 지원은 Universal 바이너리(`x86_64 arm64`) 빌드 및 정적 링크 검증으로 확인했습니다.
