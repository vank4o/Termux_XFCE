#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_arch.sh
# -----------------------------------------------------------------------------
# Output Adapter — Arch Linux proot-distro 패키지 매니저 (pacman)
# pkg_manager.sh 포트의 Arch Linux 구현체
# 환경변수: PROOT_DISTRO=archlinux, PROOT_USER=<username> 필요
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
# proot (Arch Linux 내부) 패키지 관리
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
    proot_exec sudo pacman -S --noconfirm --needed "$@"
}

proot_pkg_install_root() {
    proot_exec_root pacman -S --noconfirm --needed "$@"
}

proot_pkg_update() {
    proot_exec sudo pacman -Syu --noconfirm
}

proot_pkg_update_root() {
    proot_exec_root pacman -Syu --noconfirm
}

proot_pkg_remove() {
    proot_exec sudo pacman -Rs --noconfirm "$@"
}

proot_pkg_is_installed() {
    proot_exec pacman -Q "$1" > /dev/null 2>&1
}

proot_pkg_autoremove() {
    # Arch: 고아 패키지 제거
    proot_exec bash -c 'pacman -Qtdq | pacman -Rns --noconfirm - 2>/dev/null || true'
    # 캐시 정리
    proot_exec sudo pacman -Sc --noconfirm
}
