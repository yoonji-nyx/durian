# GitHub Actions + Self-hosted Runner 초기 구축 가이드

이 폴더는 PC에서 먼저 구성해 두고, 한 번에 GitHub 저장소에 올리면 바로 동작하도록 만든 시작 템플릿입니다.

## 폴더 구성

```
gha-runner-starter/
├── .github/workflows/
│   ├── ci.yml          # PR 검사 (lint, test, 이미지 빌드 검증)
│   ├── release.yml     # main 머지 시 테스트 -> 이미지 빌드/GHCR push -> 배포(자리표시자) -> 알림
│   └── _notify.yml     # Discord 알림 (재사용 워크플로우)
├── app/                # 샘플 Node.js 앱 (교체해서 사용)
├── runner/
│   └── install-runner.sh   # self-hosted runner 설치 스크립트 (Ubuntu)
├── Dockerfile
├── .dockerignore
├── .gitignore
└── SETUP.md
```

## 전체 순서

| 단계 | 내용 |
|---|---|
| 1 | GitHub 저장소 생성 + 코드 push |
| 2 | 브랜치 보호 규칙 설정 |
| 3 | Environments, Secrets, Variables 설정 |
| 4 | Discord 웹훅 연결 |
| 5 | 호스티드 runner로 동작 확인 |
| 6 | (필요 시) EC2에 self-hosted runner 설치 후 전환 |

---

## 1. 저장소 생성 및 push (Git Bash)

GitHub에서 빈 저장소를 만든 뒤(README/.gitignore 추가 없이), 이 폴더에서 실행합니다.

```bash
cd ~/Documents/gha-runner-starter
git init -b main
git add .
git commit -m "chore: initial CI/CD scaffold"
git remote add origin https://github.com/<owner>/<repo>.git
git push -u origin main
```

main에 push하면 release 워크플로우가 바로 실행됩니다. 아직 설정 전이면 먼저 아래 2~4를 하고 push해도 됩니다. 그 경우 처음에는 `feature` 브랜치로 push해서 PR로 테스트하는 방식을 권장합니다.

```bash
git checkout -b feature/first-test
# 아무 파일 수정 후
git add . && git commit -m "test: first PR"
git push -u origin feature/first-test
# 출력되는 링크로 Pull Request 생성 -> ci.yml 실행 확인
```

## 2. 브랜치 보호 (Settings > Branches > Add rule, 대상 `main`)

- Require a pull request before merging (Approve 1명 이상)
- Require status checks to pass: `test`, `docker-verify` (워크플로우가 한 번 실행된 뒤에 목록에 나타남)
- Do not allow bypassing the above settings

## 3. Environments / Secrets / Variables

**Environments** (Settings > Environments)

| 이름 | 설정 |
|---|---|
| `staging` | 제한 없음 |
| `production` | Required reviewers 지정 (배포 전 승인) |

**Secrets** (Settings > Secrets and variables > Actions)

| 이름 | 용도 |
|---|---|
| `DISCORD_WEBHOOK_URL` | Discord 알림 (없으면 알림을 건너뜀) |

- 이미지 push는 기본 제공 `GITHUB_TOKEN`으로 GHCR에 올리므로 별도 키가 필요 없습니다.
- AWS 접근이 필요해지면 Access Key를 저장하지 말고 OIDC + IAM Role을 사용하세요 (앞서 안내한 방식).

**Variables** (같은 화면의 Variables 탭)

| 이름 | 값 | 설명 |
|---|---|---|
| `BUILD_RUNNER` | (비워둠) | 비어 있으면 GitHub-hosted(`ubuntu-latest`) 사용 |
| `BUILD_RUNNER` | `["self-hosted","linux","ec2"]` | self-hosted runner로 전환 (JSON 형식 그대로 입력) |

워크플로우를 수정하지 않고 변수 하나로 호스티드와 self-hosted를 오갈 수 있습니다.

## 4. Discord 웹훅

1. Discord 채널 설정 > 연동 > 웹후크 > 새 웹후크 > URL 복사
2. GitHub Secrets에 `DISCORD_WEBHOOK_URL`로 등록
3. URL은 비밀값이므로 코드/채팅/로그에 노출하지 마세요. 노출되면 웹훅을 삭제 후 재생성합니다.

## 5. 동작 확인 체크리스트

- [ ] PR 생성 시 `CI` 워크플로우가 실행되고 통과
- [ ] main 머지 후 `Release`의 build 단계에서 GHCR에 이미지 push (저장소 우측 Packages에서 확인)
- [ ] `deploy-prod`가 승인 대기 상태로 멈추고, 승인하면 진행
- [ ] Discord에 성공/실패 메시지 도착 (일부러 테스트를 실패시켜 실패 알림도 확인)
- [ ] Actions 탭의 사용 분량 확인 (Settings > Billing > Usage)

GHCR 패키지는 처음에 private으로 생성됩니다. 다른 곳(EKS 등)에서 pull하려면 인증(imagePullSecret)을 설정하거나 패키지 공개 범위를 조정하세요.

---

## 6. Self-hosted runner (EC2) 설치

호스티드 분량이 부족해지거나 사내망/AWS 내부 접근이 필요할 때 추가합니다.

### 6-1. EC2 준비

| 항목 | 권장 |
|---|---|
| 인스턴스 | t3.medium (2 vCPU / 4GiB)로 시작, 부족하면 t3.large |
| OS | Ubuntu 22.04 또는 24.04 |
| 디스크 | gp3 30~50GB |
| 보안 그룹 | 인바운드 전부 차단 (runner는 아웃바운드 HTTPS만 필요) |
| 접속 | SSM Session Manager 권장 (SSH 포트 개방 불필요) |
| IAM | 인스턴스 프로파일에 필요한 최소 권한만 (장기 Access Key 저장 금지) |

### 6-2. 설치

1. 저장소 Settings > Actions > Runners > **New self-hosted runner** 에서 등록 토큰 확인 (약 1시간 유효)
2. `runner/install-runner.sh`를 EC2로 복사한 뒤 실행

```bash
sudo REPO_URL="https://github.com/<owner>/<repo>" \
     RUNNER_TOKEN="<토큰>" \
     RUNNER_LABELS="ec2,linux" \
     bash install-runner.sh
```

3. Runners 목록에서 **Idle**(초록)인지 확인
4. Variables에 `BUILD_RUNNER` = `["self-hosted","linux","ec2"]` 입력
5. PR 또는 push로 실행하여 해당 runner에서 job이 도는지 확인

### 6-3. 운영 점검

| 항목 | 방법 |
|---|---|
| 서비스 상태 | `cd /opt/actions-runner && sudo ./svc.sh status` |
| 로그 | `journalctl -u 'actions.runner.*' -f` |
| 디스크 정리 | 주 1회 `docker system prune -af --filter "until=168h"` (cron 등록 권장) |
| 업데이트 | runner는 보통 자동 업데이트됨. 장기간 꺼져 있으면 재등록이 필요할 수 있음 |
| 비용 절감 | 안 쓰는 시간에는 인스턴스 중지 (stop). 중지 중에는 job이 대기(queued)됨 |
| 제거 | `sudo ./svc.sh stop && sudo ./svc.sh uninstall`, `./config.sh remove --token <제거 토큰>` |

### 6-4. 보안 필수 사항

- **Public 저장소에는 self-hosted runner를 연결하지 마세요.** 외부인의 PR 코드가 내 서버에서 실행될 수 있습니다.
- Private 저장소에서도 외부 협업자의 포크 PR은 승인 후 실행되도록 설정합니다 (Settings > Actions > General > Fork pull request workflows).
- runner 사용자는 일반 사용자로 두고(docker 그룹 포함 시 사실상 높은 권한이므로 전용 VM 권장), 같은 서버에 중요한 데이터를 두지 않습니다.
- 운영 배포용 runner는 별도 라벨(예: `prod`)로 분리하고 `production` Environment 승인과 함께 사용합니다.

---

## 7. 배포 단계 연결 (다음 작업)

`release.yml`의 `deploy-staging`, `deploy-prod`는 현재 자리표시자(`echo`)입니다. ArgoCD 구조로 갈 때는 아래로 교체합니다.

1. gitops 저장소를 별도로 만들고 Kustomize/Helm 매니페스트를 둠
2. deploy 단계에서 gitops 저장소를 checkout -> 이미지 태그 변경 -> commit/push (전용 토큰은 Environment secret으로 관리)
3. ArgoCD가 gitops 저장소를 감시하다 클러스터에 반영
4. 배포 완료 알림은 ArgoCD Notifications로 보내는 것이 정확함 (CI는 커밋까지만 확인 가능)

## 8. 자주 발생하는 문제

| 증상 | 원인/해결 |
|---|---|
| job이 `Queued`에서 안 움직임 | `BUILD_RUNNER` 라벨과 runner 라벨 불일치, 또는 runner 오프라인 |
| `docker: permission denied` | runner 사용자가 docker 그룹에 없음. 추가 후 서비스 재시작 |
| `no space left on device` | 디스크 부족. `docker system prune`, EBS 확장 |
| GHCR push 403 | 워크플로우 `permissions: packages: write` 확인, 기존 패키지가 다른 저장소에 연결돼 있는지 확인 |
| `fromJSON` 오류 | `BUILD_RUNNER` 값이 올바른 JSON인지 확인 (`["self-hosted","linux","ec2"]`) |
| status check 이름이 목록에 안 보임 | 워크플로우가 최소 한 번 실행되어야 선택 가능 |

## 9. 사용 전 확인 사항

- 워크플로우에 쓰인 Action 버전(`checkout@v4`, `setup-node@v4`, `docker/*@v3·v6`)은 시간이 지나면 최신 메이저가 올라갑니다. 적용 전에 각 Action 저장소에서 확인하세요.
- 요금과 무료 분량(Private 저장소 월 2,000분 등)은 정책이 바뀔 수 있으므로 GitHub 공식 요금 문서를 확인하세요.
