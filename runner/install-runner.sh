#!/usr/bin/env bash
# GitHub Actions self-hosted runner 설치 스크립트 (Ubuntu 22.04/24.04, EC2 또는 VM)
#
# 사용법 (서버에서 root/sudo로 실행):
#   sudo REPO_URL="https://github.com/<owner>/<repo>" RUNNER_TOKEN="<등록 토큰>" \
#        RUNNER_LABELS="ec2,linux" bash install-runner.sh
#
# 등록 토큰: 저장소 Settings > Actions > Runners > New self-hosted runner 화면에 표시 (약 1시간 유효)
# 토큰은 비밀값이므로 셸 히스토리/로그에 남기지 않도록 주의하세요.
set -euo pipefail

: "${REPO_URL:?REPO_URL 필요 (예: https://github.com/owner/repo)}"
: "${RUNNER_TOKEN:?RUNNER_TOKEN 필요}"
RUNNER_LABELS="${RUNNER_LABELS:-ec2,linux}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)-runner}"
RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_DIR="/opt/actions-runner"

if [ "$(id -u)" -ne 0 ]; then
  echo "root 권한으로 실행하세요 (sudo)."; exit 1
fi

echo "[1/6] 기본 패키지 설치"
apt-get update -y
apt-get install -y curl jq tar ca-certificates git

echo "[2/6] Docker 설치"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

echo "[3/6] runner 사용자 생성"
id "$RUNNER_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$RUNNER_USER"
usermod -aG docker "$RUNNER_USER"

echo "[4/6] runner 최신 버전 다운로드"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) RARCH="x64" ;;
  aarch64) RARCH="arm64" ;;
  *) echo "지원하지 않는 아키텍처: $ARCH"; exit 1 ;;
esac
VERSION="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
curl -fsSL -o runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-${RARCH}-${VERSION}.tar.gz"
tar xzf runner.tar.gz && rm runner.tar.gz
chown -R "$RUNNER_USER":"$RUNNER_USER" "$RUNNER_DIR"

echo "[5/6] runner 등록"
sudo -u "$RUNNER_USER" ./config.sh \
  --unattended \
  --url "$REPO_URL" \
  --token "$RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --replace

echo "[6/6] 서비스 등록 및 시작 (재부팅 후 자동 시작)"
./svc.sh install "$RUNNER_USER"
./svc.sh start
./svc.sh status || true

unset RUNNER_TOKEN
echo "완료. GitHub > Settings > Actions > Runners 에서 Idle 상태를 확인하세요."
