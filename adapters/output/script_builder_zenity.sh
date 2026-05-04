#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: script_builder_zenity.sh
# -----------------------------------------------------------------------------
# Output Adapter — zenity 기반 런타임 스크립트 빌더
# script_builder.sh 포트의 zenity 구현체
# 생성되는 스크립트: startXFCE, kill_termux_x11, cp2menu
# =============================================================================

script_build_start_xfce() {
    local output="$1"

    cat > "$output" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# shortcut 실행 시 TMPDIR 미상속 방지
TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"

# XDG runtime dir (dbus 요구: mode 700 user-private) — shortcut은 rc를 source하지 않음
XDG_RUNTIME_DIR="${PREFIX:-/data/data/com.termux/files/usr}/var/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
export XDG_RUNTIME_DIR

# ─── X11 세션 중복 감지: X 소켓 또는 세션 프로세스가 남아 있으면 다이얼로그 ───
# 기존 dbus-daemon 카운트 방식은 세션 1개일 때 count=1이라 > 1 조건 미충족 → 감지 실패
# 더 직접적인 지표(X 소켓, xfce4-session, termux-x11)로 판별
_EXISTING_SOCK=$(ls "${TMPDIR}/.X11-unix/X"* 2>/dev/null | head -1)
_EXISTING_XFCE=$(pgrep -x xfce4-session 2>/dev/null | head -1 || echo "")
_EXISTING_TX11=$(pgrep -f "termux-x11 :" 2>/dev/null | head -1 || echo "")

if [ -n "$_EXISTING_SOCK" ] || [ -n "$_EXISTING_XFCE" ] || [ -n "$_EXISTING_TX11" ]; then
    # 기존 X 소켓으로 DISPLAY 설정 (zenity 표시용)
    if [ -n "$_EXISTING_SOCK" ]; then
        _NUM=$(basename "$_EXISTING_SOCK" | sed 's/^X//')
        export DISPLAY=":${_NUM}"
    fi

    XFCE_STATUS=$([ -n "$_EXISTING_XFCE" ] && echo "실행 중 (PID: ${_EXISTING_XFCE})" || echo "미실행")
    TX11_STATUS=$([ -n "$_EXISTING_TX11" ] && echo "실행 중 (PID: ${_EXISTING_TX11})" || echo "미실행")
    DBUS_COUNT=$(pgrep dbus-daemon 2>/dev/null | wc -l | tr -d ' ')

    choice=$(zenity --list \
        --title="XFCE 세션 중복 감지" \
        --text="⚠ X11 세션이 이미 실행 중입니다\n\n현황\n  • XFCE4 세션 : ${XFCE_STATUS}\n  • Termux:X11 : ${TX11_STATUS}\n  • dbus 수     : ${DBUS_COUNT:-0}개" \
        --column="동작" --height=320 \
        "기존 세션으로 이동" \
        "세션 종료 후 재시작" \
        "세션 전체 종료" \
        2>/dev/null || true)

    case "$choice" in
        "기존 세션으로 이동")
            am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
            exit 0
            ;;
        "세션 종료 후 재시작")
            # 정리 후 아래 신규 세션 시작 로직으로 fall-through
            killall -9 termux-x11 Xwayland xfce4-session pulseaudio dbus-daemon dbus-launch 2>/dev/null || true
            sleep 1
            rm -f "${TMPDIR}/.X11-unix/X"* "${TMPDIR}/.X"*"-lock" 2>/dev/null || true
            ;;
        "세션 전체 종료")
            killall -9 termux-x11 Xwayland xfce4-session pulseaudio dbus-daemon dbus-launch 2>/dev/null || true
            rm -f "${TMPDIR}/.X11-unix/X"* "${TMPDIR}/.X"*"-lock" 2>/dev/null || true
            termux-wake-unlock 2>/dev/null || true
            exit 0
            ;;
        *)
            # 취소(ESC/닫기) — 아무것도 안 함
            exit 0
            ;;
    esac
fi
# ───────────────���────────────────────────────────��───────────────

killall -9 termux-x11 Xwayland xfce4-session pulseaudio dbus-daemon dbus-launch 2>/dev/null || true
sleep 1

# 잔류 X 소켓/락 파일 전체 삭제
rm -f "${TMPDIR}/.X11-unix/X"* "${TMPDIR}/.X"*"-lock" 2>/dev/null || true

termux-wake-lock

# X 서버 실행 — 사용 가능한 디스플레이 번호 자동 탐색 (:0~:3)
# APK 버전에 따라 :0 또는 :1을 내부 점유하므로 첫 성공 번호를 사용
TX11_PID=""
for _DTRY in 0 1 2 3; do
    termux-x11 :${_DTRY} 2>/dev/null &
    TX11_PID=$!
    sleep 2
    if [ -e "${TMPDIR}/.X11-unix/X${_DTRY}" ]; then
        break
    fi
    kill $TX11_PID 2>/dev/null || true
    TX11_PID=""
done

# Termux:X11 APK 열기 — -S: 기존 APK를 force-stop 후 새로 시작하여 X 서버 재연결 보장
am start -S --user 0 -n com.termux.x11/com.termux.x11.MainActivity

# X 소켓이 생길 때까지 최대 10초 추가 대기 (위 루프에서 이미 감지된 경우 즉시 통과)
DISPLAY_NUM=""
for i in $(seq 1 10); do
    SOCK=$(ls "${TMPDIR}/.X11-unix/X"* 2>/dev/null | head -1)
    if [ -n "$SOCK" ]; then
        DISPLAY_NUM=$(basename "$SOCK" | sed 's/^X//')
        break
    fi
    sleep 1
done

if [ -z "$DISPLAY_NUM" ]; then
    echo "ERROR: Termux:X11 X 소켓을 찾을 수 없습니다. Termux:X11 앱을 먼저 열어주세요." >&2
    exit 1
fi

XDISPLAY=":${DISPLAY_NUM}"
echo "Detected DISPLAY=${XDISPLAY}"

LD_PRELOAD=/system/lib64/libskcodec.so pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1

LD_PRELOAD=/system/lib64/libskcodec.so pacmd load-module \
    module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true

GPU_MODEL=$(cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null || echo "")

if [ -n "$GPU_MODEL" ]; then
    # Adreno GPU 감지 → Zink(OpenGL→Vulkan) + Turnip
    # 주의: XFCE4 컴포지터(xfwm4)가 검은 화면을 유발할 경우
    #       설정 → 창관리자(작업) → 컴포지터 → '화면 컴포지팅 활성화' 해제
    env DISPLAY="$XDISPLAY" \
        PULSE_SERVER=tcp:127.0.0.1:4713 \
        MESA_LOADER_DRIVER_OVERRIDE=zink \
        TU_DEBUG=noconform \
        ZINK_DESCRIPTORS=lazy \
        MESA_NO_ERROR=1 \
        MESA_GL_VERSION_OVERRIDE=4.6COMPAT \
        MESA_GLES_VERSION_OVERRIDE=3.2 \
        MESA_VK_WSI_PRESENT_MODE=fifo \
        GSK_RENDERER=cairo \
        dbus-launch --exit-with-session xfce4-session &
else
    # llvmpipe 소프트웨어 폴백 (KGSL 미감지)
    env DISPLAY="$XDISPLAY" \
        PULSE_SERVER=tcp:127.0.0.1:4713 \
        MESA_NO_ERROR=1 \
        MESA_GL_VERSION_OVERRIDE=4.6COMPAT \
        MESA_GLES_VERSION_OVERRIDE=3.2 \
        LIBGL_ALWAYS_SOFTWARE=1 \
        GSK_RENDERER=cairo \
        dbus-launch --exit-with-session xfce4-session &
fi
EOF
}

script_build_kill_x11() {
    local output="$1"

    cat > "$output" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
if pgrep -f 'apt|apt-get|dpkg|nala' > /dev/null; then
    zenity --info --text="패키지 설치 중입니다. 완료 후 시도하세요."
    exit 1
fi

# X 서버 종료 전에 세션 존재 여부 확인
XFCE_PID=$(pgrep -x xfce4-session 2>/dev/null | head -1)
TX11_PID=$(pgrep -f termux-x11 2>/dev/null | head -1)

if [ -z "$XFCE_PID" ] && [ -z "$TX11_PID" ]; then
    zenity --info --text="실행 중인 세션을 찾을 수 없습니다."
    exit 0
fi

# 모든 관련 프로세스 종료 (startXFCE 정리 로직과 동일)
killall -9 termux-x11 Xwayland xfce4-session pulseaudio dbus-daemon dbus-launch 2>/dev/null || true
termux-wake-unlock 2>/dev/null || true
EOF
}

script_build_cp2menu() {
    local output="$1"

    cat > "$output" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"

DISTRO="${PROOT_DISTRO:-ubuntu}"
ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO"
USERNAME=$(basename "$ROOTFS/home/"* 2>/dev/null || echo "user")

action=$(zenity --list --title="cp2menu" --text="작업 선택:" \
    --radiolist --column="" --column="Action" \
    TRUE "Copy .desktop file" FALSE "Remove .desktop file")

[ -z "$action" ] && exit 0

if [[ "$action" == "Copy .desktop file" ]]; then
    selected=$(zenity --file-selection --title=".desktop 파일 선택" \
        --file-filter="*.desktop" \
        --filename="$ROOTFS/usr/share/applications")
    [ -z "$selected" ] && exit 0

    filename=$(basename "$selected")
    cp "$selected" "$PREFIX/share/applications/"
    app_name=$(grep -m1 '^Name=' "$PREFIX/share/applications/$filename" | cut -d= -f2-)
    app_name="${app_name:-App}"
    # sed 구분자(|)와 작은따옴표 충돌 방지
    app_name="${app_name//\'/\'\\\'\'}"
    app_name="${app_name//|/\\|}"
    sed -i "s|^Exec=\(.*\)$|Exec=bash -c \"prun-gui '${app_name}' -- \1 </dev/null >/dev/null 2>\&1 \&\"|" \
        "$PREFIX/share/applications/$filename"
    zenity --info --text="복사 완료: $filename"

elif [[ "$action" == "Remove .desktop file" ]]; then
    selected=$(zenity --file-selection --title="제거할 .desktop 선택" \
        --file-filter="*.desktop" \
        --filename="$PREFIX/share/applications")
    [ -z "$selected" ] && exit 0

    rm "$selected"
    zenity --info --text="제거 완료: $(basename "$selected")"
fi
EOF
}
