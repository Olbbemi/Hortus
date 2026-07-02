#!/usr/bin/env bash
#
# statusline.sh -- Claude Code 상태줄
#
# 표시: 모델 | 디렉토리(git 브랜치) | 컨텍스트 사용량
# 컨텍스트 사용량은 임계값에 따라 색을 바꾼다 (50% 미만 초록 / 50~80% 노랑 / 80% 이상 빨강).
#
# stdin 으로 statusLine JSON 을 받는다. 컨텍스트 수치는 Claude Code 가 미리 계산해
# context_window.* 로 넣어주므로 transcript 파싱은 필요 없다.

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

model="$(printf '%s' "$input"  | jq -r '.model.display_name // .model.id // "?"')"
dir="$(printf '%s' "$input"    | jq -r '.workspace.current_dir // .cwd // empty')"
pct="$(printf '%s' "$input"    | jq -r '.context_window.used_percentage // empty')"
used="$(printf '%s' "$input"   | jq -r '.context_window.total_input_tokens // empty')"
max="$(printf '%s' "$input"    | jq -r '.context_window.context_window_size // empty')"

# 디렉토리 이름 + git 브랜치
loc=""
if [ -n "$dir" ]; then
  base="$(basename -- "$dir")"
  branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
  if [ -n "$branch" ]; then loc="$base ($branch)"; else loc="$base"; fi
fi

# 컨텍스트 사용량 + 색상 경고
ctx=""
if [ -n "$pct" ]; then
  pint="${pct%.*}"; [ -z "$pint" ] && pint=0
  case "$pint" in
    *[!0-9]*) pint=0 ;;
  esac
  if   [ "$pint" -ge 80 ]; then color='\033[31m'   # 빨강
  elif [ "$pint" -ge 50 ]; then color='\033[33m'   # 노랑
  else                          color='\033[32m'   # 초록
  fi
  reset='\033[0m'
  tok=""
  if [ -n "$used" ] && [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null; then
    tok=" $((used / 1000))k/$((max / 1000))k"
  fi
  ctx="${color}ctx ${pint}%${tok}${reset}"
fi

# 조립 ( 모델 | 위치 | 컨텍스트 )
sep=" | "
out="$model"
[ -n "$loc" ] && out="$out$sep$loc"
[ -n "$ctx" ] && out="$out$sep$ctx"
printf '%b' "$out"
