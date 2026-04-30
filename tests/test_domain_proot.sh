#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: domain/proot_env.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"
source "${SCRIPT_DIR}/mocks.sh"

DOMAIN_DIR="${SCRIPT_DIR}/../domain"

_load_domain() {
    local sandbox="$1"
    local distro="${2:-ubuntu}"
    local user="${3:-testuser}"

    setup_fs_sandbox "$sandbox"
    export PROOT_DISTRO="$distro"
    export PROOT_USER="$user"

    mock_pkg_adapter
    mock_ui_adapter
    mock_wget

    # proot-distro 명령 mock
    proot-distro() { _record_call "proot-distro $*"; }

    source "${DOMAIN_DIR}/packages.sh"
    # PROOT_ROOTFS readonly 재선언 방지
    source "${DOMAIN_DIR}/proot_env.sh" 2>/dev/null || true
}

_make_proot_rootfs() {
    local sandbox="$1" distro="${2:-ubuntu}" user="${3:-testuser}"
    local rootfs="${sandbox}/usr/var/lib/proot-distro/installed-rootfs/${distro}"
    mkdir -p \
        "${rootfs}/home/${user}" \
        "${rootfs}/etc" \
        "${rootfs}/usr/share/icons"
    # sudoers stub
    touch "${rootfs}/etc/sudoers"
    # .bashrc stub
    touch "${rootfs}/home/${user}/.bashrc"
}

# =============================================================================
# setup_proot_install — 멱등성
# =============================================================================

describe "proot_env — setup_proot_install"

_test_proot_install_runs_if_missing() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu"
    reset_mock_calls

    # rootfs 없음
    setup_proot_install 2>/dev/null || true
    assert_was_called "proot-distro install"
    cleanup_sandbox "$sb"
}
it "rootfs가 없으면 proot-distro install을 호출한다" _test_proot_install_runs_if_missing

_test_proot_install_skips_if_exists() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu"
    # rootfs 미리 생성
    mkdir -p "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu"
    reset_mock_calls

    setup_proot_install 2>/dev/null || true
    assert_not_called "proot-distro install"
    cleanup_sandbox "$sb"
}
it "멱등성 — rootfs가 이미 있으면 install을 건너뛴다" _test_proot_install_skips_if_exists

# =============================================================================
# setup_proot_user — 멱등성
# =============================================================================

describe "proot_env — setup_proot_user"

_test_proot_user_created() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_mock_calls

    setup_proot_user 2>/dev/null || true
    assert_was_called "proot_exec"
    cleanup_sandbox "$sb"
}
it "사용자 홈 없을 시 useradd를 실행한다" _test_proot_user_created

_test_proot_user_skips_if_exists() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"
    reset_mock_calls

    setup_proot_user 2>/dev/null || true
    assert_not_called "proot_exec"
    cleanup_sandbox "$sb"
}
it "멱등성 — 사용자가 이미 있으면 건너뛴다" _test_proot_user_skips_if_exists

# =============================================================================
# _setup_proot_sudoers
# =============================================================================

describe "proot_env — _setup_proot_sudoers"

_test_sudoers_entry_added() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    _setup_proot_sudoers "testuser"

    assert_file_contains \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/etc/sudoers" \
        "testuser ALL=(ALL) NOPASSWD:ALL"
    cleanup_sandbox "$sb"
}
it "sudoers에 NOPASSWD 항목을 추가한다" _test_sudoers_entry_added

_test_sudoers_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    _setup_proot_sudoers "testuser"
    _setup_proot_sudoers "testuser"  # 두 번

    local count
    count=$(grep -c "testuser ALL=(ALL)" \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/etc/sudoers")
    assert_eq "1" "$count" "멱등성: sudoers 항목이 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — sudoers 항목이 중복 추가되지 않는다" _test_sudoers_idempotent

# =============================================================================
# setup_proot_env — 환경변수
# =============================================================================

describe "proot_env — setup_proot_env"

_test_proot_env_written() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    setup_proot_env 2>/dev/null || true

    local bashrc="${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.bashrc"
    assert_file_contains "$bashrc" "termux-xfce-proot-env"
    assert_file_contains "$bashrc" "DISPLAY=:0.0"
    assert_file_contains "$bashrc" "MESA_LOADER_DRIVER_OVERRIDE=zink"
    cleanup_sandbox "$sb"
}
it ".bashrc에 DISPLAY, MESA 등 환경변수를 추가한다" _test_proot_env_written

_test_proot_env_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    setup_proot_env 2>/dev/null || true
    setup_proot_env 2>/dev/null || true

    local bashrc="${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.bashrc"
    local count
    count=$(grep -c "termux-xfce-proot-env" "$bashrc")
    assert_eq "1" "$count" "멱등성: env 블록이 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — proot env 블록이 중복 추가되지 않는다" _test_proot_env_idempotent

# =============================================================================
# setup_proot_base_packages — distro 분기
# =============================================================================

describe "proot_env — setup_proot_base_packages"

_test_ubuntu_base_uses_ubuntu_pkgs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu"
    reset_mock_calls
    MOCK_INSTALLED_PKGS=""

    setup_proot_base_packages 2>/dev/null || true
    assert_was_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "Ubuntu: proot 패키지 설치를 호출한다" _test_ubuntu_base_uses_ubuntu_pkgs

_test_arch_base_uses_arch_pkgs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux"
    reset_mock_calls
    MOCK_INSTALLED_PKGS=""

    setup_proot_base_packages 2>/dev/null || true
    assert_was_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "Arch: proot 패키지 설치를 호출한다" _test_arch_base_uses_arch_pkgs

# =============================================================================
# setup_proot_cursor_theme
# =============================================================================

describe "proot_env — setup_proot_cursor_theme"

_test_cursor_skips_if_dst_exists() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_mock_calls

    # 목적지 이미 존재
    mkdir -p "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/usr/share/icons/dist-dark"

    setup_proot_cursor_theme 2>/dev/null || true
    assert_not_called "cp"
    cleanup_sandbox "$sb"
}
it "멱등성 — dist-dark가 이미 있으면 복사하지 않는다" _test_cursor_skips_if_dst_exists

_test_cursor_warns_if_src_missing() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_ui_output

    # src 없음 (${PREFIX}/share/icons/dist-dark 없음)
    setup_proot_cursor_theme 2>/dev/null || true
    assert_ui_contains "WARN"
    cleanup_sandbox "$sb"
}
it "dist-dark 소스가 없으면 경고를 출력한다" _test_cursor_warns_if_src_missing

_test_cursor_theme_copied() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    # src 생성
    mkdir -p "${PREFIX}/share/icons/dist-dark"
    touch "${PREFIX}/share/icons/dist-dark/cursor.theme"

    setup_proot_cursor_theme 2>/dev/null || true

    assert_dir_exists "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/usr/share/icons/dist-dark"
    cleanup_sandbox "$sb"
}
it "dist-dark 커서 테마를 proot로 복사한다" _test_cursor_theme_copied

# =============================================================================
# setup_proot_fancybash
# =============================================================================

describe "proot_env — setup_proot_fancybash"

_test_fancybash_warns_if_src_missing() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_ui_output

    # Termux .fancybash.sh 없음
    setup_proot_fancybash 2>/dev/null || true
    assert_ui_contains "WARN"
    cleanup_sandbox "$sb"
}
it "Termux의 .fancybash.sh가 없으면 경고를 출력한다" _test_fancybash_warns_if_src_missing

_test_fancybash_copied_to_proot() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    echo 'PS1="testuser@termux"' > "${HOME}/.fancybash.sh"

    setup_proot_fancybash 2>/dev/null || true

    assert_file_exists \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.fancybash.sh"
    cleanup_sandbox "$sb"
}
it ".fancybash.sh를 proot 홈으로 복사한다" _test_fancybash_copied_to_proot

_test_fancybash_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    echo 'PS1="testuser@termux"' > "${HOME}/.fancybash.sh"

    setup_proot_fancybash 2>/dev/null || true
    local dst="${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.fancybash.sh"
    local mtime1; mtime1=$(stat -c %Y "$dst")

    sleep 1
    setup_proot_fancybash 2>/dev/null || true
    local mtime2; mtime2=$(stat -c %Y "$dst")

    assert_eq "$mtime1" "$mtime2" "멱등성"
    cleanup_sandbox "$sb"
}
it "멱등성 — proot .fancybash.sh가 이미 있으면 덮어쓰지 않는다" _test_fancybash_idempotent

# =============================================================================
# setup_proot_update — proot_pkg_update 호출 확인
# =============================================================================

describe "proot_env — setup_proot_update"

_test_proot_update_calls_pkg_update() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu"
    reset_mock_calls

    setup_proot_update 2>/dev/null || true
    assert_was_called "proot_pkg_update"
    cleanup_sandbox "$sb"
}
it "setup_proot_update는 proot_pkg_update를 호출한다" _test_proot_update_calls_pkg_update

# =============================================================================
# setup_proot_korean — distro 분기 확인
# =============================================================================

describe "proot_env — setup_proot_korean"

_test_korean_ubuntu_installs_pkgs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"
    reset_mock_calls
    MOCK_INSTALLED_PKGS=""

    setup_proot_korean 2>/dev/null || true
    assert_was_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "Ubuntu: proot 한글 패키지 설치를 호출한다" _test_korean_ubuntu_installs_pkgs

_test_korean_arch_installs_pkgs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux"
    _make_proot_rootfs "$sb" "archlinux" "testuser"
    reset_mock_calls
    MOCK_INSTALLED_PKGS=""

    setup_proot_korean 2>/dev/null || true
    assert_was_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "Arch: proot 한글 패키지 설치를 호출한다" _test_korean_arch_installs_pkgs

# =============================================================================
# _setup_ubuntu_korean_locale — PROOT_DISTRO 변수 사용 (하드코딩 수정 검증)
# =============================================================================

describe "proot_env — _setup_ubuntu_korean_locale 경로 검증"

_test_ubuntu_korean_locale_uses_distro_var() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    _setup_ubuntu_korean_locale 2>/dev/null || true

    local profile="${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.profile"
    local locale_file="${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/etc/default/locale"
    assert_file_exists "$profile"
    assert_file_contains "$profile" "termux-xfce-korean"
    assert_file_exists "$locale_file"
    assert_file_contains "$locale_file" "ko_KR.UTF-8"
    cleanup_sandbox "$sb"
}
it "ubuntu: .profile과 /etc/default/locale을 올바른 경로에 작성한다" _test_ubuntu_korean_locale_uses_distro_var

_test_ubuntu_korean_locale_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    _setup_ubuntu_korean_locale 2>/dev/null || true
    _setup_ubuntu_korean_locale 2>/dev/null || true

    local count
    count=$(grep -c "termux-xfce-korean" \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.profile")
    assert_eq "1" "$count" "멱등성: korean 블록이 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — korean locale 블록이 중복 추가되지 않는다" _test_ubuntu_korean_locale_idempotent

# =============================================================================
# _setup_arch_korean_locale — PROOT_DISTRO 변수 사용 (하드코딩 수정 검증)
# =============================================================================

describe "proot_env — _setup_arch_korean_locale 경로 검증"

_test_arch_korean_locale_uses_distro_var() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux" "testuser"
    _make_proot_rootfs "$sb" "archlinux" "testuser"

    local locale_gen="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux/etc/locale.gen"
    touch "$locale_gen"

    _setup_arch_korean_locale 2>/dev/null || true

    assert_file_contains "$locale_gen" "ko_KR.UTF-8"
    cleanup_sandbox "$sb"
}
it "archlinux: locale.gen을 올바른 경로에 작성한다" _test_arch_korean_locale_uses_distro_var

# =============================================================================
# _setup_arch_nimf_or_fcitx5 — nimf 성공/실패 분기
# =============================================================================

describe "proot_env — _setup_arch_nimf_or_fcitx5"

_test_arch_nimf_success_writes_nimf_env() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux" "testuser"
    _make_proot_rootfs "$sb" "archlinux" "testuser"

    # paru + nimf 설치 성공 mock
    _install_yay()  { return 0; }
    proot_exec() {
        # yay -S nimf → 성공
        _record_call "proot_exec $*"
        return 0
    }

    _setup_arch_nimf_or_fcitx5 2>/dev/null || true

    local profile="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux/home/testuser/.profile"
    assert_file_exists "$profile"
    assert_file_contains "$profile" "GTK_IM_MODULE=nimf"
    cleanup_sandbox "$sb"
}
it "nimf AUR 빌드 성공 시 nimf 환경변수를 .profile에 쓴다" _test_arch_nimf_success_writes_nimf_env

_test_arch_nimf_failure_falls_back_to_fcitx5() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux" "testuser"
    _make_proot_rootfs "$sb" "archlinux" "testuser"

    # paru 설치 실패 mock → fcitx5 폴백 경로
    _install_yay() { return 1; }

    _setup_arch_nimf_or_fcitx5 2>/dev/null || true

    local profile="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux/home/testuser/.profile"
    assert_file_exists "$profile"
    assert_file_contains "$profile" "GTK_IM_MODULE=fcitx5"
    cleanup_sandbox "$sb"
}
it "nimf AUR 빌드 실패 시 fcitx5로 폴백하고 .profile에 fcitx5 환경변수를 쓴다" _test_arch_nimf_failure_falls_back_to_fcitx5

_test_arch_nimf_fcitx5_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux" "testuser"
    _make_proot_rootfs "$sb" "archlinux" "testuser"

    _install_yay() { return 1; }

    _setup_arch_nimf_or_fcitx5 2>/dev/null || true
    _setup_arch_nimf_or_fcitx5 2>/dev/null || true

    local count
    count=$(grep -c "termux-xfce-korean" \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux/home/testuser/.profile")
    assert_eq "1" "$count" "멱등성: korean 블록이 1번만 있어야 한다"
    cleanup_sandbox "$sb"
}
it "멱등성 — _setup_arch_nimf_or_fcitx5가 중복 호출돼도 .profile 블록은 1개" _test_arch_nimf_fcitx5_idempotent

_test_arch_nimf_fallback_installs_fcitx5_pkgs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux" "testuser"
    _make_proot_rootfs "$sb" "archlinux" "testuser"
    reset_mock_calls

    _install_yay() { return 1; }

    _setup_arch_nimf_or_fcitx5 2>/dev/null || true
    assert_was_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "nimf 폴백 시 fcitx5 패키지 설치를 호출한다" _test_arch_nimf_fallback_installs_fcitx5_pkgs

# =============================================================================
# setup_proot_conky — SCRIPT_DIR cp / 멱등성 / emoji 폰트 복사
# =============================================================================

describe "proot_env — setup_proot_conky"

_REAL_PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

_test_conky_copies_from_repo() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"
    export SCRIPT_DIR="${_REAL_PROJECT_DIR}"

    setup_proot_conky 2>/dev/null || true

    assert_dir_exists \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.config/conky"
    cleanup_sandbox "$sb"
}
it "SCRIPT_DIR 있으면 tar/conky에서 직접 복사한다" _test_conky_copies_from_repo

_test_conky_idempotent() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"
    export SCRIPT_DIR="${_REAL_PROJECT_DIR}"

    setup_proot_conky 2>/dev/null || true
    local conky_dir="${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.config/conky"
    local mtime1; mtime1=$(stat -c %Y "$conky_dir")
    sleep 1
    setup_proot_conky 2>/dev/null || true
    local mtime2; mtime2=$(stat -c %Y "$conky_dir")

    assert_eq "$mtime1" "$mtime2" "멱등성: conky 디렉토리가 재복사되면 안 된다"
    cleanup_sandbox "$sb"
}
it "멱등성 — conky가 이미 있으면 재복사하지 않는다" _test_conky_idempotent

_test_conky_copies_emoji_font() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"
    export SCRIPT_DIR="${_REAL_PROJECT_DIR}"

    # NotoColorEmoji 준비
    mkdir -p "${HOME}/.fonts"
    touch "${HOME}/.fonts/NotoColorEmoji-Regular.ttf"

    setup_proot_conky 2>/dev/null || true

    assert_file_exists \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.fonts/NotoColorEmoji-Regular.ttf"
    cleanup_sandbox "$sb"
}
it "NotoColorEmoji를 proot 홈 .fonts에 복사한다" _test_conky_copies_emoji_font

# =============================================================================
# _install_ubuntu_nimf_deb — deb 다운로드/설치, 멱등성
# =============================================================================

describe "proot_env — _install_ubuntu_nimf_deb"

_test_nimf_deb_skips_when_installed() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_mock_calls

    # nimf 이미 설치됨 mock
    proot_exec() {
        _record_call "proot_exec $*"
        if [[ "$*" == *"command -v nimf"* ]]; then return 0; fi
        return 0
    }

    _install_ubuntu_nimf_deb 2>/dev/null || true
    # nimf 존재 확인 후 return → wget 호출 없어야 함
    assert_not_called "wget"
    cleanup_sandbox "$sb"
}
it "nimf 이미 설치 시 건너뛴다" _test_nimf_deb_skips_when_installed

_test_nimf_deb_downloads_all_debs() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_mock_calls

    # nimf 미설치 mock
    proot_exec() {
        _record_call "proot_exec $*"
        if [[ "$*" == *"command -v nimf"* ]]; then return 1; fi
        return 0
    }

    _install_ubuntu_nimf_deb 2>/dev/null || true
    assert_was_called "nimf_1.4.17_arm64-ubuntu.2404.arm64.deb"
    assert_was_called "nimf-i18n_1.4.17_arm64-ubuntu.2404.arm64.deb"
    cleanup_sandbox "$sb"
}
it "nimf 미설치 시 모든 .deb를 다운로드한다" _test_nimf_deb_downloads_all_debs

_test_nimf_deb_calls_apt_fix() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_mock_calls

    proot_exec() {
        _record_call "proot_exec $*"
        if [[ "$*" == *"command -v nimf"* ]]; then return 1; fi
        return 0
    }

    _install_ubuntu_nimf_deb 2>/dev/null || true
    assert_was_called "apt-get install -f -y"
    cleanup_sandbox "$sb"
}
it "deb 설치 후 apt-get install -f로 의존성을 해결한다" _test_nimf_deb_calls_apt_fix

_test_nimf_deb_uses_sudo_for_dpkg() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_mock_calls

    proot_exec() {
        _record_call "proot_exec $*"
        if [[ "$*" == *"command -v nimf"* ]]; then return 1; fi
        return 0
    }

    _install_ubuntu_nimf_deb 2>/dev/null || true
    assert_was_called "sudo dpkg -i"
    cleanup_sandbox "$sb"
}
it "dpkg -i를 sudo로 실행한다" _test_nimf_deb_uses_sudo_for_dpkg

_test_nimf_deb_uses_sudo_for_apt() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    reset_mock_calls

    proot_exec() {
        _record_call "proot_exec $*"
        if [[ "$*" == *"command -v nimf"* ]]; then return 1; fi
        return 0
    }

    _install_ubuntu_nimf_deb 2>/dev/null || true
    assert_was_called "sudo apt-get install -y"
    assert_was_called "sudo apt-get install -f -y"
    cleanup_sandbox "$sb"
}
it "apt-get을 sudo로 실행한다" _test_nimf_deb_uses_sudo_for_apt

# =============================================================================
# _setup_ubuntu_korean_locale — nimf & 가드
# =============================================================================

describe "proot_env — _setup_ubuntu_korean_locale nimf 가드"

_test_ubuntu_profile_guards_nimf_exec() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "ubuntu" "testuser"
    _make_proot_rootfs "$sb" "ubuntu" "testuser"

    _setup_ubuntu_korean_locale 2>/dev/null || true

    local profile="${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home/testuser/.profile"
    # "nimf &" 가 단독으로 있으면 안 됨 — command -v 가드 필요
    local bare_nimf
    bare_nimf=$(grep -c '^nimf &$' "$profile" 2>/dev/null || echo 0)
    assert_eq "0" "$bare_nimf" ".profile에 가드 없는 'nimf &'가 없어야 한다"
    assert_file_contains "$profile" "command -v nimf"
    cleanup_sandbox "$sb"
}
it ".profile에서 nimf 실행을 command -v로 가드한다" _test_ubuntu_profile_guards_nimf_exec

_test_arch_nimf_profile_guards_nimf_exec() {
    local sb; sb=$(make_sandbox)
    _load_domain "$sb" "archlinux" "testuser"
    _make_proot_rootfs "$sb" "archlinux" "testuser"

    _install_yay() { return 0; }
    proot_exec() {
        _record_call "proot_exec $*"
        return 0
    }

    _setup_arch_nimf_or_fcitx5 2>/dev/null || true

    local profile="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux/home/testuser/.profile"
    local bare_nimf
    bare_nimf=$(grep -c '^nimf &$' "$profile" 2>/dev/null || echo 0)
    assert_eq "0" "$bare_nimf" ".profile에 가드 없는 'nimf &'가 없어야 한다"
    assert_file_contains "$profile" "command -v nimf"
    cleanup_sandbox "$sb"
}
it "Arch nimf 성공 시에도 .profile nimf 실행을 가드한다" _test_arch_nimf_profile_guards_nimf_exec

print_results
