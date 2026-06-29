#!/usr/bin/env bash
#
# install.sh -- Hortus 가 관리하는 전역 설정 파일들을 ~/.claude 에 심링크로 건다.
#
# 새 장비에서: Hortus 를 클론한 뒤 이 스크립트를 한 번 실행하면 동일한 전역 설정이 구성된다.
#   $ git clone git@github.com:Olbbemi/Hortus.git
#   $ cd Hortus && ./install.sh
#
# - 경로를 하드코딩하지 않는다: 레포 루트는 실행 시점에 스크립트 위치로 알아내고,
#   링크 대상은 $HOME 기준이라 사용자명/클론 위치가 달라도 동작한다.
# - 멱등: 이미 올바른 링크면 건너뛴다.
# - 기존에 실제 파일/디렉토리가 있으면 백업 후 링크로 교체한다.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/hortus-install-$(date +%Y%m%d-%H%M%S)"

# "레포 내 상대경로 -> ~/.claude 내 대상 경로" 매핑
MAP=(
  "CLAUDE.md:::$CLAUDE_DIR/CLAUDE.md"
  "settings.json:::$CLAUDE_DIR/settings.json"
  "hooks/guard-global-config.sh:::$CLAUDE_DIR/hooks/guard-global-config.sh"
)

echo "Hortus install"
echo "  repo   : $REPO_DIR"
echo "  target : $CLAUDE_DIR"
echo

# 훅 스크립트는 실행 가능해야 한다
chmod +x "$REPO_DIR/hooks/guard-global-config.sh" 2>/dev/null || true

link_one() {
  local src="$1" dst="$2"

  if [ ! -e "$src" ]; then
    echo "  SKIP  $dst  (소스 없음: $src)"
    return
  fi

  mkdir -p "$(dirname -- "$dst")"

  # 이미 원하는 곳을 가리키는 심링크면 통과
  if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ]; then
    echo "  OK    $dst  ->  $src  (이미 링크됨)"
    return
  fi

  # 기존에 무언가 있으면 백업 (심링크/실파일/디렉토리 모두)
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    mv -- "$dst" "$BACKUP_DIR/$(basename -- "$dst")"
    echo "  BACKUP $dst  ->  $BACKUP_DIR/"
  fi

  ln -s -- "$src" "$dst"
  echo "  LINK  $dst  ->  $src"
}

for entry in "${MAP[@]}"; do
  rel="${entry%%:::*}"
  dst="${entry##*:::}"
  link_one "$REPO_DIR/$rel" "$dst"
done

echo
if [ -d "$BACKUP_DIR" ]; then
  echo "기존 파일은 다음에 백업됨: $BACKUP_DIR"
fi
echo "완료. 전역 설정이 Hortus 레포로 연결되었습니다."
