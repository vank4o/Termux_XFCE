#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# PORT: script_builder.sh
# -----------------------------------------------------------------------------
# Output Port — 런타임 스크립트 생성 인터페이스 (계약 정의)
# 어댑터(adapters/output/script_builder_*.sh)가 이 함수들을 반드시 구현해야 함.
# 도메인은 스크립트 파일 위치/권한만 관리하고, 내용 생성은 이 포트를 통해 위임.
# =============================================================================

# script_build_start_xfce <output_path>
#   설명: startXFCE 런타임 스크립트 생성
#         X11 서버 시작, dbus 중복 감지, GPU 분기, pulseaudio 등 포함
#   인자: $1 = 스크립트 출력 경로
#   반환: 0=성공, 1=실패
# script_build_start_xfce() { ... }

# script_build_kill_x11 <output_path>
#   설명: kill_termux_x11 런타임 스크립트 생성
#         Termux-X11 및 XFCE 세션 종료
#   인자: $1 = 스크립트 출력 경로
#   반환: 0=성공, 1=실패
# script_build_kill_x11() { ... }

# script_build_cp2menu <output_path>
#   설명: cp2menu 런타임 스크립트 생성
#         proot .desktop 파일을 Termux 메뉴에 복사/제거
#   인자: $1 = 스크립트 출력 경로
#   반환: 0=성공, 1=실패
# script_build_cp2menu() { ... }
