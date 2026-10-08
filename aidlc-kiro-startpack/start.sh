#!/usr/bin/env bash
# AIDLC 시작 도우미 (macOS / Linux)
# Python/Node가 없어도 더블클릭(또는 실행) 한 번으로 개발 준비를 끝냅니다.
set -u

# 스크립트가 있는 폴더로 이동 (더블클릭 시 홈에서 실행되는 것 방지)
cd "$(dirname "$0")" 2>/dev/null || true

say() { printf "\033[1;36m%s\033[0m\n" "$1"; }
ok()  { printf "\033[1;32m✔ %s\033[0m\n" "$1"; }
warn(){ printf "\033[1;33m! %s\033[0m\n" "$1"; }

say "AIDLC 시작 도우미를 실행합니다."
say "(이 창은 설치가 끝나면 닫아도 됩니다.)"
echo

# ── 0) 다운로드 도구 (curl 우선, 없으면 wget) ──────────────────
dl() { # URL 을 표준출력으로 내려받음
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1";
  elif command -v wget >/dev/null 2>&1; then wget -qO- "$1";
  else return 127; fi
}
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  warn "curl 도 wget 도 없어 자동 설치를 진행할 수 없습니다."
  warn "  · macOS: curl 은 기본 내장이라 보통 이 메시지는 안 뜹니다."
  warn "  · Linux: 'sudo apt-get install -y curl' (또는 wget) 후 다시 실행하세요."
fi

# ── 1) uv (파이썬 관리자) 확인/설치 ─────────────────────────────
ensure_path() { export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"; }
ensure_path
if command -v uv >/dev/null 2>&1; then
  ok "uv 가 이미 설치되어 있습니다 ($(uv --version 2>/dev/null))."
else
  say "uv(파이썬을 자동 관리하는 초경량 도구)를 설치합니다..."
  uv_installer="$(dl https://astral.sh/uv/install.sh 2>/dev/null)"
  if [ -n "$uv_installer" ] && printf '%s' "$uv_installer" | sh; then
    ensure_path
    ok "uv 설치 완료."
  else
    warn "uv 자동 설치에 실패했습니다. 인터넷/프록시 연결을 확인하거나 https://astral.sh/uv 를 참고하세요."
  fi
fi

# ── 2) 파이썬 확보 (uv가 알아서 받아옴) ─────────────────────────
if command -v uv >/dev/null 2>&1; then
  say "파이썬 3.12 를 준비합니다(이미 있으면 건너뜁니다)..."
  if uv python install 3.12; then ok "파이썬 준비 완료."; else warn "파이썬 준비 중 문제가 있었지만 계속 진행합니다."; fi
fi

# ── 3) Node.js 확인/설치 (uv처럼 공식 LTS 빌드를 자동 다운로드) ────
NODE_LTS="v22.14.0"
NODE_DIR="$HOME/.aidlc/node"
if command -v node >/dev/null 2>&1; then
  ok "Node.js 가 이미 설치되어 있습니다 ($(node --version 2>/dev/null))."
elif [ -x "$NODE_DIR/bin/node" ]; then
  export PATH="$NODE_DIR/bin:$PATH"
  ok "Node.js 준비됨 ($(node --version 2>/dev/null))."
else
  say "Node.js(공식 LTS 빌드)를 설치합니다..."
  nos=""; narch=""
  case "$(uname -s)" in Darwin) nos=darwin;; Linux) nos=linux;; esac
  case "$(uname -m)" in arm64|aarch64) narch=arm64;; x86_64|amd64) narch=x64;; esac
  if [ -n "$nos" ] && [ -n "$narch" ]; then
    mkdir -p "$NODE_DIR"
    nurl="https://nodejs.org/dist/$NODE_LTS/node-$NODE_LTS-$nos-$narch.tar.gz"
    dl "$nurl" 2>/dev/null | tar -xz -C "$NODE_DIR" --strip-components=1 2>/dev/null
    if [ -x "$NODE_DIR/bin/node" ]; then
      export PATH="$NODE_DIR/bin:$PATH"
      ok "Node.js 설치 완료 ($(node --version 2>/dev/null))."
    else
      warn "Node.js 자동 설치 실패(네트워크/curl 없음?). https://nodejs.org 에서 LTS 를 받아주세요."
    fi
  else
    warn "이 OS/CPU는 Node 자동 설치 미지원. https://nodejs.org 에서 설치해주세요."
  fi
fi

# 다음에 여는 터미널·AI 툴에서도 uv·node 를 찾도록 PATH 를 셸 설정에 등록한다.
# (새 컴퓨터라 설정 파일이 하나도 없을 수 있으므로 없으면 만든다.)
persist_line='export PATH="$HOME/.local/bin:$HOME/.aidlc/node/bin:$PATH"'
persist_marker='# AIDLC PATH (auto-added)'
case "$(uname -s)" in
  Darwin) rc_files="$HOME/.zshenv $HOME/.zprofile $HOME/.profile" ;;  # macOS 기본 셸 zsh
  *)      rc_files="$HOME/.bashrc $HOME/.profile" ;;
esac
for rc in $rc_files; do
  touch "$rc" 2>/dev/null || continue
  grep -qF "$persist_marker" "$rc" 2>/dev/null || printf '\n%s\n%s\n' "$persist_marker" "$persist_line" >> "$rc"
done
# 이 스크립트를 부모 셸에서 `source` 한 경우 즉시 반영되도록 현재 세션에도 export
export PATH="$HOME/.local/bin:$HOME/.aidlc/node/bin:$PATH"

echo
ok "준비가 끝났습니다!"
say "다음 단계: 이 폴더를 사용하는 AI 코딩 툴(예: Claude Code, Kiro, Codex)에서 열고,"
say "          'requirements 폴더의 문서를 보고 AIDLC 워크플로우를 시작해줘' 라고 요청하세요."
echo
printf "엔터 키를 누르면 창을 닫습니다... "
read -r _ 2>/dev/null || true
