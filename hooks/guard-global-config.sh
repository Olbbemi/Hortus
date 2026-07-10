#!/usr/bin/env bash
#
# guard-global-config.sh -- PreToolUse hook
#
# Hortus 가 관리하는 전역 설정 파일(전역 CLAUDE.md / settings.json / 이 훅 스크립트)을
# Hortus working tree 밖에서 Edit/Write/NotebookEdit 로 수정하려 하면 차단한다.
#
# 판정: 도구가 건드리는 파일의 realpath 가 관리 대상이면, 현재 세션 cwd 의 git remote 가
#       Olbbemi/Hortus 인지 본다. 아니면(다른 remote, 또는 git 레포 아님) 차단.
#
# stdin 으로 PreToolUse JSON 을 받는다: { tool_name, tool_input{ file_path }, cwd }.
# 차단은 exit code 2 + stderr (Claude 에게 사유 전달). 그 외엔 exit 0 (허용).
#
# 안전상 fail-open: 입력 파싱 실패 등 예외 상황에서는 허용한다(전체 편집이 막히는 사고 방지).
# 이 훅은 보안 경계가 아니라 "다른 세션의 무분별한 수정" 방지용 백스톱이다.

input="$(cat)"

# jq 가 없거나 입력이 비면 그냥 허용
command -v jq >/dev/null 2>&1 || exit 0
[ -n "$input" ] || exit 0

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"

# 건드리는 파일 경로가 없으면 가드 대상 아님
[ -n "$file_path" ] || exit 0

# 상대경로면 cwd 기준으로 절대화
case "$file_path" in
  /*) : ;;
  *)  [ -n "$cwd" ] && file_path="$cwd/$file_path" ;;
esac

# 대상 파일의 canonical 경로 (존재하지 않아도 -m 으로 정규화)
target="$(realpath -m -- "$file_path" 2>/dev/null)"
[ -n "$target" ] || exit 0

# 관리 대상의 canonical 경로 집합 (~/.claude 심링크 -> Hortus 실파일로 해소됨)
managed_links="
$HOME/.claude/CLAUDE.md
$HOME/.claude/settings.json
$HOME/.claude/hooks/guard-global-config.sh
$HOME/.claude/hooks/guard-bash.sh
$HOME/.claude/statusline.sh
"

is_managed=0
while IFS= read -r link; do
  [ -n "$link" ] || continue
  canon="$(realpath -m -- "$link" 2>/dev/null)"
  if [ -n "$canon" ] && [ "$canon" = "$target" ]; then
    is_managed=1
    break
  fi
done <<EOF
$managed_links
EOF

# 관리 대상이 아니면 통과
[ "$is_managed" = "1" ] || exit 0

# 관리 대상이다 -> cwd 가 Hortus working tree 인지 remote 로 판정
remote_url=""
if [ -n "$cwd" ]; then
  remote_url="$(git -C "$cwd" config --get remote.origin.url 2>/dev/null)"
fi

case "$remote_url" in
  *[:/]Olbbemi/Hortus|*[:/]Olbbemi/Hortus.git)
    exit 0  # Hortus 내부 -> 허용
    ;;
esac

# 여기까지 왔으면 Hortus 밖에서의 관리 대상 수정 -> 차단
cat >&2 <<EOF
[guard-global-config] 차단됨: 전역 설정 파일은 Hortus working tree 안에서만 수정할 수 있습니다.

  대상 파일 : $target
  현재 cwd  : ${cwd:-(없음)}
  remote    : ${remote_url:-(git 레포 아님 / remote 없음)}

Hortus 가 관리하는 전역 설정 파일(CLAUDE.md / settings.json / 가드 훅 / statusline 등)은
remote 가 Olbbemi/Hortus 인 위치에서만 고칩니다.
Hortus 레포로 이동해 수정한 뒤 사용하세요. (수정 내용을 메모리에 적어두는 것을 권장)
EOF
exit 2
