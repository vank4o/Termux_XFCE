#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER (공통): pkg_common_termux.sh
# -----------------------------------------------------------------------------
# Termux native 패키지 관리 — 모든 pkg_*.sh 어댑터가 source하는 공통 구현체
# pkg_manager.sh 포트의 Termux native 계약 구현
# =============================================================================

pkg_update() {
    pkg update -y -o Dpkg::Options::="--force-confold"
}

pkg_upgrade() {
    pkg upgrade -y -o Dpkg::Options::="--force-confold"
}

pkg_install() {
    pkg install -y -o Dpkg::Options::="--force-confold" "$@"
}

pkg_remove() {
    pkg uninstall -y "$@"
}

pkg_is_installed() {
    dpkg -s "$1" 2>/dev/null | grep -q "^Status: install ok installed"
}

pkg_autoremove() {
    apt autoremove -y
    apt autoclean -y
}
