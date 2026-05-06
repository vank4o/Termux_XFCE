# 설치 매트릭스 테스트 — 실행/유지 가이드

이 문서는 `install.sh`의 모든 CLI 옵션 조합을 검증하는 매트릭스 테스트와,
"설치 → 오류 → 수정 → push → 초기화 → 재설치" 자동화 루프를 다음 세션에서도
재현 가능하도록 정리한 기록이다.

---

## 1. 빠른 실행

```bash
cd ~/Termux_XFCE
git checkout dev && git pull

# 단위 + e2e 전체
bash tests/run_tests.sh

# 매트릭스만 (CLI 옵션 조합 dispatch 검증, mock 기반, 빠름)
bash tests/test_install_matrix.sh
```

매트릭스 테스트는 `_INSTALL_HOOK` 환경변수를 사용해 install.sh의 모든
`setup_*` 도메인 함수를 트레이스 스텁으로 교체한다. **실제 설치는 일어나지 않는다.**
훅 주입 지점: `install.sh` step 7 (도메인 로드 직후) 종료선.

---

## 2. 테스트 케이스 (17건)

| # | 카테고리 | CLI / 환경변수 | 검증 |
|---|----------|----------------|------|
| 1 | native | `--no-proot --no-gpu --no-korean` | gpu/korean/proot 호출 없음 |
| 2 | native | `--no-proot --gpu --no-korean` | gpu만, gpu_dev 없음 ⚠️ |
| 3 | native | `--no-proot --gpu --gpu-dev --no-korean` | gpu + gpu_dev 둘 다 |
| 4 | native | `--no-proot --no-gpu --korean` | setup_termux_korean 호출 |
| 5 | native | `--no-proot --no-gpu --no-korean --korean-locale` | setup_korean_locale_native 호출 |
| 6 | proot-only | `--proot-only --distro ubuntu --user testuser ...` | termux_base/x11_apk 생략 |
| 7 | proot-only | `--proot-only --distro archlinux --user testuser ...` | termux_base 생략 |
| 8 | full | `--distro ubuntu --user testuser --gpu --no-korean` | proot_korean 생략 ⚠️ |
| 9 | full | `--distro archlinux --user testuser --no-gpu --korean` | native+proot 양쪽 한글 |
| 10 | full | `--distro ubuntu --user testuser --gpu --gpu-dev --korean --korean-locale` | 모든 setup_* 호출 |
| 11 | env vars | `SKIP_PROOT=true SKIP_KOREAN=true INSTALL_GPU=false` | proot/gpu/korean 없음 |
| 12 | env vars | `DISTRO=ubuntu USERNAME=testuser INSTALL_GPU=true SKIP_KOREAN=true` | full 동등 ⚠️ |
| 13 | CLI 검증 | `--help` | exit 0 |
| 14 | CLI 검증 | `--not-a-real-flag` | non-zero exit ⚠️ |
| 15 | CLI 검증 | `--distro freebsd ...` | non-zero exit ⚠️ |
| 16 | config | `--distro ubuntu --user lideok --no-gpu --no-korean` | config 파일에 distro/user 기록 |
| 17 | config | `--no-proot --no-gpu --no-korean` | config의 PROOT_DISTRO="" |

⚠️ = 현재 실패 — 다음 세션에서 root cause 파악 후 수정 필요 (아래 §4).

---

## 3. 자동화 루프 워크플로우

사용자 요청: **모든 옵션 조합을 실제 설치 → 오류 시 수정 → dev push → 패키지만 제거 → 재설치 반복**

```
1. baseline:  bash tests/run_tests.sh
2. matrix:    bash tests/test_install_matrix.sh
3. for each combo in §2:
     a) bash install.sh <options>      # 실제 설치 시도
     b) 오류 발생 시:
        - 근본 원인 파악 (스택 추적, 로그)
        - domain/* 또는 adapter/* 수정
        - 회귀 테스트 추가 (tests/test_*.sh)
        - bash tests/run_tests.sh 통과 확인
        - git add -p && git commit && git push origin dev
     c) 패키지 제거(초기화):
        - Termux native: pkg uninstall <목록>
        - proot: bash tests/autopilot.sh 의 teardown_proot 패턴 참고
4. matrix 다시 실행 → 모든 조합 통과까지 반복
```

**주의**:
- "초기화"는 **설치 패키지만** 제거 (`pkg uninstall`) — Termux 환경 자체나 홈 디렉토리는 보존.
- proot 제거: `proot-distro remove <distro>` (autopilot.sh §단계4 참조).
- gh 인증은 이미 완료 (`gh auth status`로 확인). HTTPS 토큰 사용.

---

## 4. 다음 세션에서 처리할 실패 5건

매트릭스 테스트가 보고한 실패. 각 항목의 근본 원인은 **테스트 가정 vs install.sh 실제 동작** 사이의 갭으로 보임:

1. **#2 native + GPU**: `INSTALL_GPU_DEV` 미지정 시 `interactive.sh`가 `ui_confirm`으로 묻는다. 매트릭스 훅이 `ui_confirm`을 안 stub해서 `/dev/tty` 입력 대기 → `setup_termux_gpu_dev`가 호출됐을 수 있음.
   **수정 방향**: 훅에 `ui_confirm() { return 1; }` 추가하거나, 테스트가 `--gpu --no-gpu-dev` 명시 (단 현재 `--no-gpu-dev` 플래그 없음 — `cli.sh`에 추가 필요).

2. **#8 Ubuntu 풀 + GPU + no-korean**: 마찬가지로 `interactive.sh`의 한글/GPU 추가 질문이 stub 우회. `_assert_not_traced "setup_proot_korean"`이 실패한 건 `SKIP_KOREAN`이 명시 안 되어 interactive에서 yes로 갔을 가능성.
   **수정 방향**: 훅에서 ui_* 전체를 빠르게 no-op + 기본값 반환하도록 강화.

3. **#12 환경변수 full**: 동일 — `SKIP_KOREAN=true`만 있고 `INSTALL_GPU_DEV` 미지정.

4. **#14, #15 CLI 검증**: `--help` 후 exit 0은 OK. `--not-a-real-flag`는 stderr로 에러 + exit 1로 종료해야 하는데, 실제로 그렇게 동작하는 걸 확인했음 (`bash install.sh --not-a-real-flag` 종료코드 = 1). **테스트의 어딘가에서 종료코드가 0으로 보고됨** — pipefail/SIGPIPE 의심. 테스트 본문에서 `>/dev/null 2>&1` 리디렉션이 exit code 망가뜨릴 수 있음. 다음 세션에서 단계별로 디버그.

---

## 5. 새로 추가/수정한 파일 (커밋 대상)

```
tests/test_install_matrix.sh       (신규) — 17건 매트릭스 테스트
tests/INSTALL_MATRIX.md            (신규) — 이 문서
install.sh                         (수정) — _INSTALL_HOOK 훅 추가 (step 7 직후)
domain/proot_env.sh                (수정) — setup_proot_alias zsh 게이트 제거
                                              ('command -v zsh' → '[ -f .zshrc ]')
```

베이스라인 단위 테스트는 모두 통과 (273 → 274 passed).
