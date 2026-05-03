#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_ubuntu.sh
# -----------------------------------------------------------------------------
# Output Adapter — Ubuntu proot-distro 패키지 매니저 (apt)
# pkg_manager.sh 포트의 Ubuntu 구현체
# 환경변수: PROOT_DISTRO=ubuntu, PROOT_USER=<username> 필요
# =============================================================================

# Termux native 패키지 관리 (공통)
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ADAPTER_DIR/pkg_common_termux.sh"

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
# proot (Ubuntu 내부) 패키지 관리
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

proot_pkg_install() {
    proot_exec sudo apt install -y -o Dpkg::Options::="--force-confold" "$@"
}

proot_pkg_install_root() {
    proot_exec_root apt install -y -o Dpkg::Options::="--force-confold" "$@"
}

proot_pkg_update() {
    proot_exec sudo apt update
    proot_exec sudo apt upgrade -y -o Dpkg::Options::="--force-confold"
}

proot_pkg_update_root() {
    proot_exec_root apt update
    proot_exec_root apt upgrade -y -o Dpkg::Options::="--force-confold"
}

proot_pkg_remove() {
    proot_exec sudo apt remove -y "$@"
    proot_exec sudo apt autoremove -y
}

proot_pkg_is_installed() {
    proot_exec dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "^install ok installed"
}

proot_pkg_autoremove() {
    proot_exec sudo apt autoremove -y
    proot_exec sudo apt autoclean -y
}
