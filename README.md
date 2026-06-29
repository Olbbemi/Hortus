# Hortus

Claude Code 의 전역 설정을 한 레포에서 버전 관리하고, 여러 장비에서 동일하게 사용하기 위한 저장소.

## 목적

전역 설정 파일(전역 `CLAUDE.md`, `settings.json`)은 원래 `~/.claude` 아래에 흩어져 있어
장비마다 따로 관리해야 한다. Hortus 는 그 실체를 이 레포 한 곳에 모아 두고, `~/.claude`
쪽에는 심볼릭 링크만 거는 방식으로 다음을 달성한다.

- 전역 설정을 git 으로 버전 관리한다.
- 새 장비에서도 "클론 + 스크립트 한 번"으로 동일한 전역 설정을 구성한다.
- 다른 프로젝트 세션에서 전역 설정이 무분별하게 수정되는 것을 막는다.

## 관리 대상

| 레포 파일 | 링크되는 위치 |
| --- | --- |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `settings.json` | `~/.claude/settings.json` |
| `hooks/guard-global-config.sh` | `~/.claude/hooks/guard-global-config.sh` |

스킬, 플러그인, `settings.local.json`(머신 로컬 permissions), 그리고 `~/.claude` 의 런타임
상태(`history.jsonl`, `sessions/`, `projects/`, `cache/`, `.credentials.json` 등)는 관리
대상이 아니다.

## 구조

```
Hortus/
  CLAUDE.md                    # 전역 CLAUDE.md 본체
  settings.json                # 전역 settings.json 본체 (가드 훅 등록 포함)
  hooks/
    guard-global-config.sh     # 전역 설정 수정 가드 (PreToolUse 훅)
  install.sh                   # ~/.claude 에 심링크를 생성하는 설치 스크립트
  README.md
```

## 동작 원리

1. 설정의 실체는 이 레포에 두고, `install.sh` 가 `~/.claude` 의 해당 경로를 레포 파일로
   향하는 심볼릭 링크로 만든다. 이후 레포 파일을 고치면 즉시 전역에 반영된다.
2. `settings.json` 에 등록된 PreToolUse 가드 훅이, Claude Code 의 `Edit`/`Write`/
   `NotebookEdit` 가 건드리는 경로를 `realpath` 로 정규화해 관리 대상이면 가로챈다.
   현재 세션의 cwd git remote 가 `Olbbemi/Hortus` 가 아니면(다른 remote, 또는 git 레포가
   아니라 조회 실패) 수정을 차단한다.

즉 **"전역 설정 수정은 Hortus working tree 안에서만"** 이라는 규칙을, 훅이 기계적으로
강제하고 전역 `CLAUDE.md` 의 규칙 문구가 (훅이 못 잡는 `Bash` 경로까지) 백스톱한다.

가드의 한계: Claude Code 의 도구 호출만 가로채므로, 사용자가 에디터로 직접 여는 수동 편집은
막지 못한다. 이 장치의 목적은 다른 세션에서의 무분별한 자동 수정 방지다.

## 사용법

### 설치 (현재 장비 / 새 장비 공통)

```sh
git clone git@github.com:Olbbemi/Hortus.git
cd Hortus
./install.sh
```

`install.sh` 는 몇 번을 실행해도 결과가 같다 -- 이미 올바른 링크가 걸려 있으면 건너뛰고,
대상 자리에 기존 실파일이 있으면 `~/.claude/backups/hortus-install-<타임스탬프>/` 로 백업한
뒤 링크로 교체한다.
백업은 "실파일 -> 심링크"로 교체되는 최초 1회에만 생성되며, 이후 실행이나 평소 편집에서는
쌓이지 않는다.

### 전역 설정 수정

반드시 Hortus 레포 안(remote 가 `Olbbemi/Hortus` 인 working tree)에서 `CLAUDE.md` 나
`settings.json` 을 고친다. 심링크 덕분에 레포 파일만 고치면 전역에 바로 반영된다.

다른 프로젝트에서 작업 중 전역 설정을 고쳐야 하면, 그 자리에서 고치지 말고(가드가 막는다)
Hortus 로 와서 수정한다.

### 제거 / 복원

심링크를 지우고 백업본을 되돌리면 된다.

```sh
rm ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/hooks/guard-global-config.sh
# 필요하면 ~/.claude/backups/hortus-install-<타임스탬프>/ 의 원본을 복사해 되돌린다
```
