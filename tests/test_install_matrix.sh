#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: install.sh — CLI 옵션 조합 매트릭스 (dispatch 검증)
# -----------------------------------------------------------------------------
# install.sh를 모든 CLI 옵션 조합으로 호출하고, 각 조합에서 호출되어야 하는
# domain setup_* 함수의 호출 여부를 트레이스로 검증.
#
# - 실제 설치는 하지 않음 (모든 setup_* 함수는 _INSTALL_HOOK으로 스텁 교체)
# - distro × proot-only × no-proot × gpu × gpu-dev × korean × korean-locale
#   = 의미 있는 조합 14개 커버
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"

REPO_ROOT="${SCRIPT_DIR}/.."
TRACE_FILE="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/install_matrix_trace.$$"
HOOK_FILE="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/install_matrix_hook.$$"

# -----------------------------------------------------------------------------
# 훅 파일: install.sh가 source하는 스텁
#   - 모든 setup_* / proot 함수를 _record로 교체 (TRACE_FILE에 한 줄씩 추가)
#   - 외부 명령(termux-setup-storage 등)도 no-op으로 스텁
# -----------------------------------------------------------------------------
_write_hook_file() {
    cat > "$HOOK_FILE" << 'HOOK_EOF'
# 트레이스 기록 함수
_trace() { printf '%s\n' "$*" >> "${_TRACE_FILE}"; }

# Termux native setup
setup_termux_base()       { _trace "setup_termux_base"; }
setup_xfce_packages()     { _trace "setup_xfce_packages"; }
setup_xfce_theme()        { _trace "setup_xfce_theme"; }
setup_xfce_fonts()        { _trace "setup_xfce_fonts"; }
setup_xfce_wallpaper()    { _trace "setup_xfce_wallpaper"; }
setup_xfce_fancybash()    { _trace "setup_xfce_fancybash $*"; }
setup_xfce_autostart()    { _trace "setup_xfce_autostart"; }
setup_termux_korean()     { _trace "setup_termux_korean"; }
setup_termux_shortcuts()  { _trace "setup_termux_shortcuts"; }
setup_termux_gpu()        { _trace "setup_termux_gpu"; }
setup_termux_gpu_dev()    { _trace "setup_termux_gpu_dev"; }
setup_termux_x11_apk()    { _trace "setup_termux_x11_apk"; }
setup_korean_locale_native() { _trace "setup_korean_locale_native"; }

# proot setup
setup_proot_install()         { _trace "setup_proot_install"; }
setup_proot_update()          { _trace "setup_proot_update"; }
setup_proot_user()            { _trace "setup_proot_user"; }
setup_proot_base_packages()   { _trace "setup_proot_base_packages"; }
setup_proot_korean()          { _trace "setup_proot_korean"; }
setup_proot_env()             { _trace "setup_proot_env"; }
setup_proot_timezone()        { _trace "setup_proot_timezone"; }
setup_proot_fancybash()       { _trace "setup_proot_fancybash"; }
setup_proot_hardware_accel()  { _trace "setup_proot_hardware_accel"; }
setup_proot_cursor_theme()    { _trace "setup_proot_cursor_theme"; }
setup_proot_conky()           { _trace "setup_proot_conky"; }
setup_proot_alias()           { _trace "setup_proot_alias"; }

# 외부 명령 / pkg 어댑터 — install.sh가 호출할 수 있는 것들
termux-setup-storage()    { _trace "termux-setup-storage"; }
termux-reload-settings()  { _trace "termux-reload-settings"; return 0; }
sleep()                   { :; }   # 테스트 가속

# UI는 터미널 어댑터를 그대로 쓰되 ui_info만 조용히
ui_info()  { :; }
ui_warn()  { :; }
ui_error() { echo "ERROR: $*" >&2; }

# readlink (login shell 탐지)에 의해 setup_xfce_fancybash가 호출될지 결정.
# 테스트는 zsh가 login shell이 아닌 상태를 시뮬레이션 → fancybash 호출 발생 정상.
HOOK_EOF
}

# -----------------------------------------------------------------------------
# install.sh를 격리된 HOME/PREFIX에서 실행
# -----------------------------------------------------------------------------
_run_install() {
    local sandbox
    sandbox=$(mktemp -d "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/install_matrix_XXXXXX")
    > "$TRACE_FILE"

    # install.sh가 자체적으로 sandbox HOME에 .config 디렉토리 생성하므로 별도 셋업 불필요
    HOME="$sandbox/home" \
    PREFIX="$sandbox/usr" \
    _TRACE_FILE="$TRACE_FILE" \
    _INSTALL_HOOK="$HOOK_FILE" \
        bash "$REPO_ROOT/install.sh" "$@" >/dev/null 2>&1
    local rc=$?
    # sandbox는 트레이스만 남기면 되니 즉시 정리
    rm -rf "$sandbox"
    return $rc
}

_assert_traced() {
    local fn="$1"
    if ! grep -qx -- "$fn" "$TRACE_FILE" && ! grep -q "^${fn} " "$TRACE_FILE"; then
        echo "[ASSERT] expected call '$fn' not in trace" >&2
        echo "[ASSERT] trace was:" >&2
        sed 's/^/    /' "$TRACE_FILE" >&2
        return 1
    fi
}

_assert_not_traced() {
    local fn="$1"
    if grep -qx -- "$fn" "$TRACE_FILE" || grep -q "^${fn} " "$TRACE_FILE"; then
        echo "[ASSERT] unexpected call '$fn' in trace" >&2
        sed 's/^/    /' "$TRACE_FILE" >&2
        return 1
    fi
}

# 사전 준비
_write_hook_file

# =============================================================================
# 매트릭스 1: --no-proot (Termux native만)
# =============================================================================

describe "matrix — Termux native만 (--no-proot)"

_test_minimal_native() {
    _run_install --no-proot --no-gpu --no-korean
    _assert_traced "setup_termux_base"
    _assert_traced "setup_xfce_packages"
    _assert_traced "setup_xfce_autostart"
    _assert_traced "setup_termux_shortcuts"
    _assert_traced "setup_termux_x11_apk"
    _assert_not_traced "setup_termux_gpu"
    _assert_not_traced "setup_termux_korean"
    _assert_not_traced "setup_proot_install"
}
it "최소 native (no-gpu, no-korean) — proot/gpu/korean 호출 없음" _test_minimal_native

_test_native_with_gpu() {
    _run_install --no-proot --gpu --no-gpu-dev --no-korean
    _assert_traced "setup_termux_gpu"
    _assert_not_traced "setup_termux_gpu_dev"
    _assert_not_traced "setup_proot_install"
}
it "native + GPU — gpu만 호출, gpu_dev 없음" _test_native_with_gpu

_test_native_with_gpu_dev() {
    _run_install --no-proot --gpu --gpu-dev --no-korean
    _assert_traced "setup_termux_gpu"
    _assert_traced "setup_termux_gpu_dev"
}
it "native + GPU + gpu-dev — 둘 다 호출" _test_native_with_gpu_dev

_test_native_with_korean() {
    _run_install --no-proot --no-gpu --korean
    _assert_traced "setup_termux_korean"
}
it "native + 한글 입력기 — setup_termux_korean 호출" _test_native_with_korean

_test_native_with_korean_locale() {
    _run_install --no-proot --no-gpu --no-korean --korean-locale
    _assert_traced "setup_korean_locale_native"
}
it "native + --korean-locale — setup_korean_locale_native 호출" _test_native_with_korean_locale

# =============================================================================
# 매트릭스 2: --proot-only (proot만, native 생략)
# =============================================================================

describe "matrix — proot-only (--proot-only)"

_test_proot_only_ubuntu() {
    _run_install --proot-only --distro ubuntu --user testuser --no-gpu --no-korean
    _assert_not_traced "setup_termux_base"
    _assert_not_traced "setup_xfce_packages"
    _assert_not_traced "setup_termux_x11_apk"
    _assert_traced "setup_proot_install"
    _assert_traced "setup_proot_user"
    _assert_traced "setup_proot_alias"
}
it "Ubuntu proot-only — native 모두 생략, proot만 실행" _test_proot_only_ubuntu

_test_proot_only_archlinux() {
    _run_install --proot-only --distro archlinux --user testuser --no-gpu --no-korean
    _assert_not_traced "setup_termux_base"
    _assert_traced "setup_proot_install"
    _assert_traced "setup_proot_alias"
}
it "Arch proot-only — native 모두 생략, proot만 실행" _test_proot_only_archlinux

# =============================================================================
# 매트릭스 3: 풀 설치 (native + proot)
# =============================================================================

describe "matrix — 풀 설치 (native + proot)"

_test_full_ubuntu() {
    _run_install --distro ubuntu --user testuser --gpu --no-gpu-dev --no-korean
    _assert_traced "setup_termux_base"
    _assert_traced "setup_termux_gpu"
    _assert_traced "setup_proot_install"
    _assert_traced "setup_proot_base_packages"
    _assert_traced "setup_proot_alias"
    _assert_traced "setup_termux_x11_apk"
    _assert_not_traced "setup_proot_korean"
}
it "Ubuntu 풀 + GPU + no-korean — proot_korean 생략" _test_full_ubuntu

_test_full_arch_korean() {
    _run_install --distro archlinux --user testuser --no-gpu --korean
    _assert_traced "setup_termux_base"
    _assert_traced "setup_termux_korean"
    _assert_traced "setup_proot_install"
    _assert_traced "setup_proot_korean"
    _assert_traced "setup_proot_alias"
}
it "Arch 풀 + 한글 — native+proot 양쪽 한글 설정" _test_full_arch_korean

_test_full_ubuntu_all_options() {
    _run_install --distro ubuntu --user testuser --gpu --gpu-dev --korean --korean-locale
    _assert_traced "setup_termux_base"
    _assert_traced "setup_termux_gpu"
    _assert_traced "setup_termux_gpu_dev"
    _assert_traced "setup_termux_korean"
    _assert_traced "setup_korean_locale_native"
    _assert_traced "setup_proot_install"
    _assert_traced "setup_proot_korean"
}
it "Ubuntu 풀 + 모든 옵션 — 모든 setup_* 호출" _test_full_ubuntu_all_options

# =============================================================================
# 매트릭스 4: 환경변수 기반 (CLI 인자 대신)
# =============================================================================

describe "matrix — 환경변수 기반 호출"

_test_env_vars_no_proot() {
    SKIP_PROOT=true SKIP_KOREAN=true INSTALL_GPU=false _run_install
    _assert_traced "setup_termux_base"
    _assert_not_traced "setup_proot_install"
    _assert_not_traced "setup_termux_korean"
    _assert_not_traced "setup_termux_gpu"
}
it "SKIP_PROOT=true SKIP_KOREAN=true INSTALL_GPU=false" _test_env_vars_no_proot

_test_env_vars_full() {
    DISTRO=ubuntu USERNAME=testuser INSTALL_GPU=true INSTALL_GPU_DEV=false \
        SKIP_KOREAN=true _run_install
    _assert_traced "setup_termux_base"
    _assert_traced "setup_termux_gpu"
    _assert_traced "setup_proot_install"
}
it "DISTRO=ubuntu USERNAME=testuser INSTALL_GPU=true" _test_env_vars_full

# =============================================================================
# 매트릭스 5: --help / 잘못된 인자
# =============================================================================

describe "matrix — CLI 인자 검증"

_test_help_exits_zero() {
    local rc=0
    HOME="$(mktemp -d)" PREFIX="$(mktemp -d)" \
        bash "$REPO_ROOT/install.sh" --help >/dev/null 2>&1 || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "[ASSERT] --help should exit 0, got $rc" >&2
        return 1
    fi
}
it "--help는 exit 0으로 종료" _test_help_exits_zero

_test_unknown_arg_exits_nonzero() {
    # set -e 트립 방지: 비정상 종료를 기대하므로 || rc=$? 로 캡처
    local rc=0
    HOME="$(mktemp -d)" PREFIX="$(mktemp -d)" \
        bash "$REPO_ROOT/install.sh" --not-a-real-flag >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "[ASSERT] unknown flag should exit non-zero, got 0" >&2
        return 1
    fi
}
it "알 수 없는 인자는 non-zero exit" _test_unknown_arg_exits_nonzero

_test_invalid_distro_exits_nonzero() {
    local rc=0
    _INSTALL_HOOK="$HOOK_FILE" _TRACE_FILE="$TRACE_FILE" \
    HOME="$(mktemp -d)" PREFIX="$(mktemp -d)" \
        bash "$REPO_ROOT/install.sh" --distro freebsd --user testuser --no-gpu --no-gpu-dev --no-korean \
        >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "[ASSERT] invalid distro should exit non-zero, got 0" >&2
        return 1
    fi
}
it "지원하지 않는 distro는 non-zero exit" _test_invalid_distro_exits_nonzero

# =============================================================================
# 매트릭스 6: config 파일 생성 검증
# =============================================================================

describe "matrix — config 파일 생성"

_test_config_file_records_distro() {
    local sandbox; sandbox=$(mktemp -d)
    HOME="$sandbox/home" PREFIX="$sandbox/usr" \
    _TRACE_FILE="$TRACE_FILE" _INSTALL_HOOK="$HOOK_FILE" \
        bash "$REPO_ROOT/install.sh" --distro ubuntu --user lideok --no-gpu --no-korean \
        >/dev/null 2>&1

    local cfg="$sandbox/home/.config/termux-xfce/config"
    assert_file_exists "$cfg"
    assert_file_contains "$cfg" 'PROOT_DISTRO="ubuntu"'
    assert_file_contains "$cfg" 'PROOT_USER="lideok"'
    rm -rf "$sandbox"
}
it "config 파일에 distro/user가 기록됨" _test_config_file_records_distro

_test_config_file_no_distro_when_no_proot() {
    local sandbox; sandbox=$(mktemp -d)
    HOME="$sandbox/home" PREFIX="$sandbox/usr" \
    _TRACE_FILE="$TRACE_FILE" _INSTALL_HOOK="$HOOK_FILE" \
        bash "$REPO_ROOT/install.sh" --no-proot --no-gpu --no-korean \
        >/dev/null 2>&1

    local cfg="$sandbox/home/.config/termux-xfce/config"
    assert_file_exists "$cfg"
    assert_file_contains "$cfg" 'PROOT_DISTRO=""'
    rm -rf "$sandbox"
}
it "no-proot일 때 config의 PROOT_DISTRO는 빈 문자열" _test_config_file_no_distro_when_no_proot

# =============================================================================
# 정리
# =============================================================================
rm -f "$HOOK_FILE" "$TRACE_FILE"

print_results
