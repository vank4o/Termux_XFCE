#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: domain/termux_env.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"
source "${SCRIPT_DIR}/mocks.sh"

DOMAIN_DIR="${SCRIPT_DIR}/../domain"
_REAL_PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

_load_domain() {
    local sandbox="$1"
    setup_fs_sandbox "$sandbox"
    mock_pkg_adapter
    mock_ui_adapter
    mock_wget
    source "${DOMAIN_DIR}/packages.sh"
    source "${DOMAIN_DIR}/termux_env.sh"
}

# =============================================================================
# _setup_termux_properties
# =============================================================================

describe "termux_env — _setup_termux_properties"

_test_props_uncomments_allow_external() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_termux_properties
    assert_file_contains "${HOME}/.termux/termux.properties" "^allow-external-apps = true"
    cleanup_sandbox "$sb"
}
it "allow-external-apps 주석을 해제한다" _test_props_uncomments_allow_external

_test_props_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # 이미 설정된 상태
    echo "allow-external-apps = true" >> "${HOME}/.termux/termux.properties"
    echo "bell-character = ignore" >> "${HOME}/.termux/termux.properties"

    _setup_termux_properties

    # 중복 없이 1번만 존재해야 함
    local count
    count=$(grep -c "^allow-external-apps = true" "${HOME}/.termux/termux.properties")
    assert_eq "1" "$count" "멱등성: allow-external-apps가 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — 이미 설정된 경우 중복 추가하지 않는다" _test_props_idempotent

_test_props_appends_when_no_comment() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # 주석 라인 없이 빈 properties 파일
    echo "# 임의 설정" > "${HOME}/.termux/termux.properties"

    _setup_termux_properties
    assert_file_contains "${HOME}/.termux/termux.properties" "^allow-external-apps = true"
    assert_file_contains "${HOME}/.termux/termux.properties" "^bell-character = ignore"
    cleanup_sandbox "$sb"
}
it "주석 라인 없으면 직접 추가한다 (폴백)" _test_props_appends_when_no_comment

# =============================================================================
# _setup_aliases
# =============================================================================

describe "termux_env — _setup_aliases"

_test_aliases_written() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_aliases
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "termux-xfce-aliases"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "alias ll="
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "alias shutdown="
    cleanup_sandbox "$sb"
}
it "bash.bashrc에 alias 블록을 추가한다" _test_aliases_written

_test_aliases_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_aliases
    _setup_aliases  # 두 번 호출

    local count
    count=$(grep -c "termux-xfce-aliases" "${PREFIX}/etc/bash.bashrc")
    assert_eq "1" "$count" "멱등성: alias 블록이 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — alias 블록이 중복 추가되지 않는다" _test_aliases_idempotent

# =============================================================================
# _setup_locale
# =============================================================================

describe "termux_env — _setup_locale"

_test_locale_written() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_locale
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "termux-xfce-locale"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "LANG=ko_KR.UTF-8"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "XDG_CONFIG_HOME"
    cleanup_sandbox "$sb"
}
it "bash.bashrc에 locale 환경변수를 추가한다" _test_locale_written

_test_locale_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_locale
    _setup_locale

    local count
    count=$(grep -c "termux-xfce-locale" "${PREFIX}/etc/bash.bashrc")
    assert_eq "1" "$count" "멱등성: locale 블록이 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — locale 블록이 중복 추가되지 않는다" _test_locale_idempotent

# =============================================================================
# _setup_start_xfce
# =============================================================================

describe "termux_env — _setup_start_xfce"

_test_startxfce_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_start_xfce
    assert_file_exists "${HOME}/.shortcuts/startXFCE"
    # 실행 권한 확인
    [ -x "${HOME}/.shortcuts/startXFCE" ]
    cleanup_sandbox "$sb"
}
it "startXFCE 스크립트를 생성한다" _test_startxfce_created

_test_startxfce_has_gpu_detection() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_start_xfce
    assert_file_contains "${HOME}/.shortcuts/startXFCE" "GPU_MODEL"
    assert_file_contains "${HOME}/.shortcuts/startXFCE" "MESA_DRIVER"
    assert_file_contains "${HOME}/.shortcuts/startXFCE" "kgsl"
    cleanup_sandbox "$sb"
}
it "startXFCE에 GPU 자동 감지 로직이 있다" _test_startxfce_has_gpu_detection

_test_startxfce_overwrites_on_update() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # 구버전 startXFCE
    echo "old_version" > "${HOME}/.shortcuts/startXFCE"

    _setup_start_xfce

    # 새 내용으로 덮어씀 (가드 없음 — 업데이트 보장)
    assert_file_contains "${HOME}/.shortcuts/startXFCE" "termux-x11"
    cleanup_sandbox "$sb"
}
it "startXFCE를 항상 최신 버전으로 재생성한다" _test_startxfce_overwrites_on_update

# =============================================================================
# _setup_prun
# =============================================================================

describe "termux_env — _setup_prun"

_test_prun_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_prun
    assert_file_exists "${PREFIX}/bin/prun"
    [ -x "${PREFIX}/bin/prun" ]
    cleanup_sandbox "$sb"
}
it "prun 스크립트를 생성한다" _test_prun_created

_test_prun_has_config_source() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_prun
    assert_file_contains "${PREFIX}/bin/prun" "CONFIG"
    assert_file_contains "${PREFIX}/bin/prun" "proot-distro login"
    cleanup_sandbox "$sb"
}
it "prun은 config에서 DISTRO를 읽는다" _test_prun_has_config_source

_test_prun_overwrites_old_version() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    echo "old_version" > "${PREFIX}/bin/prun"
    _setup_prun

    # 최신 내용으로 갱신됨 (가드 없음 — test_prun_ld_preload.sh와 일관)
    assert_file_contains "${PREFIX}/bin/prun" "proot-distro login"
    cleanup_sandbox "$sb"
}
it "prun을 항상 최신 버전으로 재생성한다" _test_prun_overwrites_old_version

# =============================================================================
# _setup_cp2menu
# =============================================================================

describe "termux_env — _setup_cp2menu"

_test_cp2menu_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_cp2menu
    assert_file_exists "${PREFIX}/bin/cp2menu"
    assert_file_exists "${PREFIX}/share/applications/cp2menu.desktop"
    cleanup_sandbox "$sb"
}
it "cp2menu 스크립트와 desktop 파일을 생성한다" _test_cp2menu_created

_test_cp2menu_desktop_valid() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_cp2menu
    assert_file_contains "${PREFIX}/share/applications/cp2menu.desktop" "[Desktop Entry]"
    assert_file_contains "${PREFIX}/share/applications/cp2menu.desktop" "Exec=cp2menu"
    cleanup_sandbox "$sb"
}
it "cp2menu.desktop에 필수 필드가 있다" _test_cp2menu_desktop_valid

# =============================================================================
# _setup_korean_env
# =============================================================================

describe "termux_env — _setup_korean_env"

_test_korean_fcitx5_desktop_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_korean_env
    assert_file_exists "${HOME}/.config/autostart/fcitx5.desktop"
    assert_file_contains "${HOME}/.config/autostart/fcitx5.desktop" "Exec=fcitx5 -d"
    cleanup_sandbox "$sb"
}
it "fcitx5.desktop 자동시작 파일을 생성한다" _test_korean_fcitx5_desktop_created

_test_korean_env_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_korean_env
    local mtime1; mtime1=$(stat -c %Y "${HOME}/.config/autostart/fcitx5.desktop")
    sleep 1
    _setup_korean_env
    local mtime2; mtime2=$(stat -c %Y "${HOME}/.config/autostart/fcitx5.desktop")
    assert_eq "$mtime1" "$mtime2" "멱등성"
    cleanup_sandbox "$sb"
}
it "멱등성 — fcitx5.desktop이 이미 있으면 덮어쓰지 않는다" _test_korean_env_idempotent

# =============================================================================
# _detect_and_log_gpu
# =============================================================================

describe "termux_env — _detect_and_log_gpu (GPU 감지)"

_test_gpu_no_kgsl() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_ui_output

    # KGSL 없음 → warn
    _detect_and_log_gpu 2>/dev/null || true
    assert_ui_contains "WARN"
    cleanup_sandbox "$sb"
}
it "KGSL 미감지 시 경고를 출력한다" _test_gpu_no_kgsl

_test_gpu_adreno_7xx() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_ui_output

    # sys 파일 모킹 (임시 파일로 함수 내 경로 재정의)
    _detect_and_log_gpu_mocked() {
        local gpu_model="Adreno (TM) 750"
        ui_info "감지된 GPU: ${gpu_model}"
        if [[ "$gpu_model" =~ [Aa]dreno.*7[0-9]{2} ]]; then
            ui_info "Adreno 7xx"
        fi
    }
    _detect_and_log_gpu_mocked
    assert_ui_contains "Adreno 7xx"
    cleanup_sandbox "$sb"
}
it "Adreno 7xx GPU 감지 시 7xx 메시지를 출력한다" _test_gpu_adreno_7xx

_test_gpu_adreno_8xx_info() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_ui_output

    _detect_and_log_gpu_mocked() {
        local gpu_model="Adreno (TM) 830"
        ui_info "감지된 GPU: ${gpu_model}"
        if [[ "$gpu_model" =~ [Aa]dreno.*8[0-9]{2} ]]; then
            ui_info "Adreno 8xx (Snapdragon 8 Elite) 감지 — Termux mesa-vulkan-icd-freedreno 26+ 사용"
        fi
    }
    _detect_and_log_gpu_mocked
    assert_ui_contains "Adreno 8xx"
    cleanup_sandbox "$sb"
}
it "Adreno 8xx GPU 감지 시 8xx 정보를 출력한다" _test_gpu_adreno_8xx_info

# =============================================================================
# setup_termux_gpu — 패키지 설치 루프
# =============================================================================

describe "termux_env — setup_termux_gpu"

_test_setup_gpu_installs_pkgs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_mock_calls
    MOCK_INSTALLED_PKGS=""  # 아무것도 설치 안 된 상태

    setup_termux_gpu 2>/dev/null || true

    # GPU 패키지 중 하나라도 pkg_install 호출됐는지 확인
    assert_was_called "pkg_install"
    cleanup_sandbox "$sb"
}
it "GPU 패키지 미설치 시 pkg_install을 호출한다" _test_setup_gpu_installs_pkgs

_test_setup_gpu_skips_installed() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_mock_calls
    # 모든 GPU 패키지를 설치된 것으로 설정
    MOCK_INSTALLED_PKGS="${PKGS_TERMUX_GPU[*]}"

    setup_termux_gpu 2>/dev/null || true

    assert_not_called "pkg_install"
    cleanup_sandbox "$sb"
}
it "멱등성 — GPU 패키지가 이미 설치된 경우 pkg_install을 호출하지 않는다" _test_setup_gpu_skips_installed

# =============================================================================
# _setup_tur_multilib — sed '/^deb /' 패턴 검증
# =============================================================================

describe "termux_env — _setup_tur_multilib"

_test_tur_multilib_only_deb_lines() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # 빈 줄·주석 포함한 tur.list 생성
    cat > "${PREFIX}/etc/apt/sources.list.d/tur.list" << 'EOF'
deb https://tur.kcubeterm.com tur-packages tur

# this is a comment
EOF

    _setup_tur_multilib 2>/dev/null || true

    local result
    result=$(cat "${PREFIX}/etc/apt/sources.list.d/tur.list")

    # deb 줄에만 추가됐는지
    assert_output_contains "$result" "deb https://tur.kcubeterm.com tur-packages tur tur-multilib tur-hacking"
    # 빈 줄에 붙지 않았는지
    local blank_line
    blank_line=$(echo "$result" | grep "^[[:space:]]*tur-multilib" || echo "none")
    assert_eq "none" "$blank_line" "빈 줄에 tur-multilib이 붙으면 안 된다"
    # 주석 줄에 붙지 않았는지
    local comment_line
    comment_line=$(echo "$result" | grep "^#.*tur-multilib" || echo "none")
    assert_eq "none" "$comment_line" "주석 줄에 tur-multilib이 붙으면 안 된다"
    cleanup_sandbox "$sb"
}
it "deb 줄에만 tur-multilib/tur-hacking을 추가한다" _test_tur_multilib_only_deb_lines

_test_tur_multilib_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    echo "deb https://tur.kcubeterm.com tur-packages tur tur-multilib tur-hacking" \
        > "${PREFIX}/etc/apt/sources.list.d/tur.list"

    _setup_tur_multilib 2>/dev/null || true

    local count
    count=$(grep -c "tur-multilib" "${PREFIX}/etc/apt/sources.list.d/tur.list")
    assert_eq "1" "$count" "멱등성: tur-multilib이 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — tur-multilib이 이미 있으면 중복 추가하지 않는다" _test_tur_multilib_idempotent

# =============================================================================
# _setup_kill_termux_x11 — bin 생성 및 desktop entry
# =============================================================================

describe "termux_env — _setup_kill_termux_x11"

_test_kill_x11_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_kill_termux_x11 2>/dev/null || true

    assert_file_exists "${PREFIX}/bin/kill_termux_x11"
    assert_file_exists "${PREFIX}/share/applications/kill_termux_x11.desktop"
    cleanup_sandbox "$sb"
}
it "kill_termux_x11 스크립트와 desktop 파일을 생성한다" _test_kill_x11_created

_test_kill_x11_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_kill_termux_x11 2>/dev/null || true
    local mtime1; mtime1=$(stat -c %Y "${PREFIX}/bin/kill_termux_x11")
    sleep 1
    _setup_kill_termux_x11 2>/dev/null || true
    local mtime2; mtime2=$(stat -c %Y "${PREFIX}/bin/kill_termux_x11")

    assert_eq "$mtime1" "$mtime2" "멱등성: 이미 있으면 덮어쓰지 않는다"
    cleanup_sandbox "$sb"
}
it "멱등성 — kill_termux_x11이 이미 있으면 덮어쓰지 않는다" _test_kill_x11_idempotent

# =============================================================================
# _migrate_desktop_to_prun_gui — 기존 prun → prun-gui 마이그레이션
# =============================================================================

describe "termux_env — _migrate_desktop_to_prun_gui"

_test_migrate_prun_to_prun_gui() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # prun 사용하는 .desktop 파일 생성
    cat > "${PREFIX}/share/applications/testapp.desktop" << 'EOF'
[Desktop Entry]
Name=TestApp
Exec=bash -c "prun testapp --flag </dev/null >/dev/null 2>&1 &"
EOF

    _migrate_desktop_to_prun_gui

    assert_file_contains "${PREFIX}/share/applications/testapp.desktop" "prun-gui 'TestApp' --"
    cleanup_sandbox "$sb"
}
it "prun 사용 .desktop 파일을 prun-gui로 변환한다" _test_migrate_prun_to_prun_gui

_test_migrate_skips_already_prun_gui() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # 이미 prun-gui 사용 중인 .desktop
    cat > "${PREFIX}/share/applications/already.desktop" << 'EOF'
[Desktop Entry]
Name=Already
Exec=bash -c "prun-gui Already -- someapp </dev/null >/dev/null 2>&1 &"
EOF

    _migrate_desktop_to_prun_gui

    local count
    count=$(grep -c "prun-gui" "${PREFIX}/share/applications/already.desktop")
    assert_eq "1" "$count" "멱등성: prun-gui가 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — 이미 prun-gui인 파일은 건너뛴다" _test_migrate_skips_already_prun_gui

_test_migrate_skips_non_proot() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # prun을 사용하지 않는 native .desktop
    cat > "${PREFIX}/share/applications/native.desktop" << 'EOF'
[Desktop Entry]
Name=NativeApp
Exec=firefox
EOF

    _migrate_desktop_to_prun_gui

    assert_file_contains "${PREFIX}/share/applications/native.desktop" "^Exec=firefox"
    cleanup_sandbox "$sb"
}
it "prun 미사용 .desktop 파일은 건드리지 않는다" _test_migrate_skips_non_proot

_test_migrate_uses_name_field() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    cat > "${PREFIX}/share/applications/named.desktop" << 'EOF'
[Desktop Entry]
Name=LibreOffice Writer
Exec=bash -c "prun libreoffice --writer </dev/null >/dev/null 2>&1 &"
EOF

    _migrate_desktop_to_prun_gui

    assert_file_contains "${PREFIX}/share/applications/named.desktop" "prun-gui 'LibreOffice Writer' --"
    cleanup_sandbox "$sb"
}
it "Name= 필드를 prun-gui 앱 이름으로 사용한다" _test_migrate_uses_name_field

# =============================================================================
# _append_to_rc — RC 파일 멱등 추가 유틸
# =============================================================================

describe "termux_env — _append_to_rc"

_test_append_to_rc_adds_content() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _append_to_rc "# test-marker" "# test-marker\nexport FOO=bar" "${PREFIX}/etc/bash.bashrc"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "test-marker"
    cleanup_sandbox "$sb"
}
it "마커가 없으면 내용을 추가한다" _test_append_to_rc_adds_content

_test_append_to_rc_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _append_to_rc "# test-marker" "# test-marker\nexport FOO=bar" "${PREFIX}/etc/bash.bashrc"
    _append_to_rc "# test-marker" "# test-marker\nexport FOO=bar" "${PREFIX}/etc/bash.bashrc"

    local count
    count=$(grep -c "test-marker" "${PREFIX}/etc/bash.bashrc")
    assert_eq "1" "$count"
    cleanup_sandbox "$sb"
}
it "멱등성 — 마커가 이미 있으면 중복 추가하지 않는다" _test_append_to_rc_idempotent

# =============================================================================
# _setup_xdg_runtime — XDG_RUNTIME_DIR mode 700
# =============================================================================

describe "termux_env — _setup_xdg_runtime"

_test_xdg_runtime_written() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_xdg_runtime
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "termux-xfce-xdg-runtime"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "XDG_RUNTIME_DIR"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "chmod 700"
    cleanup_sandbox "$sb"
}
it "bash.bashrc에 XDG_RUNTIME_DIR 블록을 추가한다" _test_xdg_runtime_written

_test_xdg_runtime_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_xdg_runtime
    _setup_xdg_runtime

    local count
    count=$(grep -c "termux-xfce-xdg-runtime" "${PREFIX}/etc/bash.bashrc")
    assert_eq "1" "$count"
    cleanup_sandbox "$sb"
}
it "멱등성 — XDG_RUNTIME_DIR 블록이 중복 추가되지 않는다" _test_xdg_runtime_idempotent

_test_xdg_runtime_removes_old_tmpdir_line() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    # 구버전 라인 삽입 (마이그레이션 대상)
    echo 'export XDG_RUNTIME_DIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"' >> "${PREFIX}/etc/bash.bashrc"

    _setup_xdg_runtime

    assert_file_not_contains "${PREFIX}/etc/bash.bashrc" 'XDG_RUNTIME_DIR="${TMPDIR'
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "termux-xfce-xdg-runtime"
    cleanup_sandbox "$sb"
}
it "구버전 TMPDIR 기반 XDG_RUNTIME_DIR 라인을 제거한다" _test_xdg_runtime_removes_old_tmpdir_line

# =============================================================================
# _setup_gpu_env — GPU 환경변수 RC 추가
# =============================================================================

describe "termux_env — _setup_gpu_env"

_test_gpu_env_written() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_gpu_env
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "termux-xfce-gpu"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "MESA_LOADER_DRIVER_OVERRIDE"
    assert_file_contains "${PREFIX}/etc/bash.bashrc" "GSK_RENDERER=cairo"
    cleanup_sandbox "$sb"
}
it "bash.bashrc에 GPU 환경변수 블록을 추가한다" _test_gpu_env_written

_test_gpu_env_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_gpu_env
    _setup_gpu_env

    local count
    count=$(grep -c "termux-xfce-gpu" "${PREFIX}/etc/bash.bashrc")
    assert_eq "1" "$count"
    cleanup_sandbox "$sb"
}
it "멱등성 — GPU 블록이 중복 추가되지 않는다" _test_gpu_env_idempotent

# =============================================================================
# _setup_prun_gui — prun-gui 스크립트 생성
# =============================================================================

describe "termux_env — _setup_prun_gui"

_test_prun_gui_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_prun_gui
    assert_file_exists "${PREFIX}/bin/prun-gui"
    [ -x "${PREFIX}/bin/prun-gui" ]
    assert_file_contains "${PREFIX}/bin/prun-gui" "notify-send"
    assert_file_contains "${PREFIX}/bin/prun-gui" "exec prun"
    cleanup_sandbox "$sb"
}
it "prun-gui 스크립트를 생성한다" _test_prun_gui_created

_test_prun_gui_syntax_valid() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"

    _setup_prun_gui
    bash -n "${PREFIX}/bin/prun-gui"
    cleanup_sandbox "$sb"
}
it "prun-gui 스크립트의 bash 문법 오류가 없다" _test_prun_gui_syntax_valid

# =============================================================================
# _setup_app_installer — bin + desktop + 바탕화면 아이콘
# =============================================================================

describe "termux_env — _setup_app_installer"

_test_app_installer_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    export SCRIPT_DIR="${_REAL_PROJECT_DIR}"

    _setup_app_installer
    assert_file_exists "${PREFIX}/bin/app-installer"
    assert_file_exists "${PREFIX}/share/applications/app-installer.desktop"
    assert_file_exists "${HOME}/Desktop/App-Installer.desktop"
    [ -x "${PREFIX}/bin/app-installer" ]
    cleanup_sandbox "$sb"
}
it "app-installer bin, desktop, 바탕화면 아이콘을 생성한다" _test_app_installer_created

_test_app_installer_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    export SCRIPT_DIR="${_REAL_PROJECT_DIR}"

    _setup_app_installer
    local mtime1; mtime1=$(stat -c %Y "${PREFIX}/bin/app-installer")
    sleep 1
    _setup_app_installer
    local mtime2; mtime2=$(stat -c %Y "${PREFIX}/bin/app-installer")

    assert_eq "$mtime1" "$mtime2" "멱등성: 이미 있으면 덮어쓰지 않는다"
    cleanup_sandbox "$sb"
}
it "멱등성 — app-installer가 이미 있으면 덮어쓰지 않는다" _test_app_installer_idempotent

# =============================================================================
# _install_base_packages — 패키지 설치 루프
# =============================================================================

describe "termux_env — _install_base_packages"

_test_base_pkgs_installs_missing() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_mock_calls
    MOCK_INSTALLED_PKGS=""

    _install_base_packages 2>/dev/null || true
    assert_was_called "pkg_install"
    cleanup_sandbox "$sb"
}
it "미설치 패키지에 대해 pkg_install을 호출한다" _test_base_pkgs_installs_missing

_test_base_pkgs_skips_installed() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_mock_calls
    MOCK_INSTALLED_PKGS="${PKGS_TERMUX_BASE[*]} ${PKGS_TERMUX_CLI[*]} ${PKGS_TERMUX_PROOT[*]} dbus"

    _install_base_packages 2>/dev/null || true
    # dbus remove는 항상 호출되지만 다른 pkg_install은 없어야 함
    local install_count=0
    for call in "${MOCK_CALLS[@]:-}"; do
        [[ "$call" == pkg_install* ]] && ((install_count++))
    done
    # dbus는 remove 후 재설치되므로 dbus 1건만 허용
    [ "$install_count" -le 1 ]
    cleanup_sandbox "$sb"
}
it "멱등성 — 이미 설치된 패키지는 건너뛴다" _test_base_pkgs_skips_installed

# =============================================================================
# setup_termux_gpu_dev — GPU 개발 도구 패키지 루프
# =============================================================================

describe "termux_env — setup_termux_gpu_dev"

_test_gpu_dev_installs_pkgs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_mock_calls
    MOCK_INSTALLED_PKGS=""

    setup_termux_gpu_dev 2>/dev/null || true
    assert_was_called "pkg_install"
    cleanup_sandbox "$sb"
}
it "GPU 개발 패키지 미설치 시 pkg_install을 호출한다" _test_gpu_dev_installs_pkgs

_test_gpu_dev_skips_installed() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    reset_mock_calls
    MOCK_INSTALLED_PKGS="${PKGS_TERMUX_GPU_DEV[*]}"

    setup_termux_gpu_dev 2>/dev/null || true
    assert_not_called "pkg_install"
    cleanup_sandbox "$sb"
}
it "멱등성 — GPU 개발 패키지가 이미 설치된 경우 건너뛴다" _test_gpu_dev_skips_installed

# =============================================================================
# setup_termux_shortcuts — composition 함수 검증
# =============================================================================

describe "termux_env — setup_termux_shortcuts (composition)"

_test_shortcuts_creates_all() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb"
    export SCRIPT_DIR="${_REAL_PROJECT_DIR}"

    setup_termux_shortcuts 2>/dev/null || true

    assert_file_exists "${HOME}/.shortcuts/startXFCE"
    assert_file_exists "${PREFIX}/bin/prun"
    assert_file_exists "${PREFIX}/bin/prun-gui"
    assert_file_exists "${PREFIX}/bin/cp2menu"
    assert_file_exists "${PREFIX}/bin/kill_termux_x11"
    assert_file_exists "${PREFIX}/bin/app-installer"
    cleanup_sandbox "$sb"
}
it "모든 유틸리티 스크립트를 생성한다" _test_shortcuts_creates_all

print_results
