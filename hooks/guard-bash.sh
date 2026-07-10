#!/usr/bin/env bash
#
# guard-bash.sh -- PreToolUse Bash hook
#
# Hortus 전역 권한 설정은 allow:["Bash"] 로 대부분의 Bash 를 자동 허용하되,
# "자동 실행되면 큰일 나는" 명령만 정지시킨다. permissions.ask 목록은 접두어
# (subcommand prefix)로 잡히는 위험만 담당하고, 접두어로 못 잡는 잔여 -- 복합/
# 파이프 원격실행/옵션순서 뒤바뀜/리다이렉트/시크릿 파일/env 덤프/전역설정 편집 --
# 을 이 훅이 명령 문자열 통째로 파싱해 걷어낸다.
#
# 정지는 hard block(deny)이 아니라 ask 다: permissionDecision:"ask" 를 내보내
# 사용자에게 확인 프롬프트를 강제한다(대답 전 실행이 멈춘다). 설계 철학상 deny 는 안 쓴다.
#
# stdin 으로 PreToolUse JSON 을 받는다: { tool_name, tool_input{ command }, cwd }.
# 매칭되면 ask JSON 을 stdout 으로 내고 exit 0. 아니면 아무것도 안 내고 exit 0
# (결정 없음 -> 권한 규칙 evaluation 으로 폴백 -> allow:["Bash"] 로 통과).
#
# fail-open: jq 없음/입력 파싱 실패 등 예외에선 통과(전체 Bash 가 막히는 사고 방지).
# 이 훅은 보안 경계가 아니라 자율 실행 중 사고 방지용 백스톱이다.

input="$(cat)"

# jq 가 없거나 입력이 비면 그냥 통과
command -v jq >/dev/null 2>&1 || exit 0
[ -n "$input" ] || exit 0

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
[ "$tool" = "Bash" ] || exit 0

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] || exit 0

# ask <사유>: 확인 프롬프트를 강제하고 종료
ask() {
  jq -cn --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

# 1) 원격 스크립트를 받아 셸/인터프리터로 바로 실행: curl/wget/fetch | sh|bash|python|perl|ruby|node
if printf '%s' "$cmd" | grep -Eq '\b(curl|wget|fetch)\b' \
  && printf '%s' "$cmd" | grep -Eq '\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh|dash|python[0-9.]*|perl|ruby|node)\b'; then
  ask "원격에서 받은 스크립트를 셸로 바로 실행합니다(curl/wget | sh). 자동 실행을 정지하고 확인을 받습니다."
fi

# 2) 시크릿/자격증명 파일을 읽거나 밖으로 빼내는 명령
if printf '%s' "$cmd" | grep -Eq '\b(cat|less|more|head|tail|xxd|od|strings|base64|nc|ncat|socat)\b' \
  && printf '%s' "$cmd" | grep -Eq '(\.ssh/|/\.ssh\b|id_rsa|id_ed25519|id_ecdsa|\.aws/credentials|\.netrc|\.pgpass|\.env\b|secring|private[_-]?key)'; then
  ask "SSH 키/자격증명/.env 등 시크릿 파일을 읽거나 외부로 보낼 수 있습니다. 자동 실행을 정지하고 확인을 받습니다."
fi

# 3) 전체 환경변수 덤프(bare env / printenv) -- 시크릿 노출 위험
if printf '%s' "$cmd" | grep -Eq '(^|[;&|][[:space:]]*)(env|printenv)[[:space:]]*($|[|>;&])'; then
  ask "환경변수를 통째로 출력합니다(env/printenv). 시크릿 노출 위험이 있어 확인을 받습니다."
fi

# 4) Bash 로 전역 설정 파일(~/.claude 관리 대상) 편집 -- guard-global-config(Edit/Write)가 못 잡는 경로
if printf '%s' "$cmd" | grep -Eq '\.claude/(settings\.json|CLAUDE\.md|statusline\.sh|hooks/(guard-global-config|guard-bash)\.sh)' \
  && printf '%s' "$cmd" | grep -Eq '(>>?|[[:space:]]tee\b|sed[[:space:]]+-i|[[:space:]](cp|mv|ln|install|truncate|dd)\b|chmod|chown)'; then
  ask "Bash 로 전역 설정 파일(~/.claude)을 수정하려 합니다. Hortus working tree 에서 실체 파일을 고쳐야 하므로 확인을 받습니다."
fi

# 5) 블록 디바이스(디스크)로의 직접 기록 -- 파괴적
if printf '%s' "$cmd" | grep -Eq '(>[[:space:]]*/dev/(sd|nvme|disk|hd|vd)|of=[[:space:]]*/dev/(sd|nvme|disk|hd|vd))'; then
  ask "블록 디바이스(디스크)에 직접 기록합니다. 파괴적이라 확인을 받습니다."
fi

# 6) 옵션 순서가 뒤바뀐 force push (접두어 Bash(git push --force:*) 가 못 잡는 경우)
if printf '%s' "$cmd" | grep -Eq '\bgit[[:space:]]+push\b' \
  && printf '%s' "$cmd" | grep -Eq '(--force([-a-z]*)?\b|[[:space:]]-f([[:space:]]|$))'; then
  ask "git push 를 강제(force)로 실행합니다. 원격 히스토리 덮어쓰기 위험이 있어 확인을 받습니다."
fi

exit 0
