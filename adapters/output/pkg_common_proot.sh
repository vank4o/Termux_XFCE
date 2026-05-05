#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER (공통): pkg_common_proot.sh
# -----------------------------------------------------------------------------
# proot-distro 공통 구현 — pkg_ubuntu.sh, pkg_arch.sh가 source하는 공통 코드
# Termux native 패키지 관리 + proot 라이프사이클/실행 함수 제공
# =============================================================================

# Termux native 패키지 관리 (공통)
_PROOT_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PROOT_COMMON_DIR/pkg_common_termux.sh"

# -----------------------------------------------------------------------------
# proot-distro 라이프사이클
# -----------------------------------------------------------------------------

proot_install() {
    proot-distro install "$1"
}

proot_remove() {
    proot-distro remove "$1" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# proot 실행
# -----------------------------------------------------------------------------

proot_exec() {
    : "${PROOT_DISTRO:?PROOT_DISTRO 환경변수가 설정되지 않았습니다}"
    : "${PROOT_USER:?PROOT_USER 환경변수가 설정되지 않았습니다}"
    proot-distro login "$PROOT_DISTRO" \
        --user "$PROOT_USER" \
        --shared-tmp \
        -- env DISPLAY="${DISPLAY:-:0.0}" "$@"
}

# root 권한 실행 — 사용자 생성 전/패키지 업데이트 등 root 필요 작업용
proot_exec_root() {
    : "${PROOT_DISTRO:?PROOT_DISTRO 환경변수가 설정되지 않았습니다}"
    proot-distro login "$PROOT_DISTRO" \
        --shared-tmp \
        -- env DISPLAY="${DISPLAY:-:0.0}" "$@"
}
