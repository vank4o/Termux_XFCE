#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: adapters/input/interactive.sh
# -----------------------------------------------------------------------------
# Input Adapter — 대화형 입력 (터미널 select)
# PROOT_DISTRO, PROOT_USER 등이 비어있을 때 사용자에게 물어봄
# =============================================================================

resolve_interactive_inputs() {
    # 사용자 이름
    if [ -z "${PROOT_USER:-}" ]; then
        PROOT_USER=$(ui_input "사용자 이름(id)을 입력하세요" "user")
        export PROOT_USER
    fi

    # proot 설치 여부
    if [ "${SKIP_PROOT:-false}" = "false" ] && [ -z "${PROOT_DISTRO:-}" ]; then
        local distro_choice
        distro_choice=$(ui_select \
            "proot-distro 선택" \
            "설치할 Linux 환경을 선택하세요 (Termux native XFCE는 항상 설치됩니다):" \
            "ubuntu" \
            "archlinux" \
            "없음 (Termux native만)")

        case "$distro_choice" in
            "없음 (Termux native만)")
                SKIP_PROOT=true
                PROOT_DISTRO=""
                ;;
            *)
                PROOT_DISTRO="$distro_choice"
                ;;
        esac
        export PROOT_DISTRO SKIP_PROOT
    fi

}
