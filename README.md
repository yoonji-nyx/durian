# ktcloud_durian

CI/CD 플랫폼 앱 저장소. GitHub Actions로 테스트/빌드하고, 배포는 gitops 저장소(`cicd-platform-gitops`)를 통해 ArgoCD가 반영합니다.

## 흐름

```
feature 브랜치 -> PR (CI: lint/test/docker 검증) -> main 병합
  -> Release: 이미지 빌드 -> ghcr.io push (태그 = 커밋 SHA 7자리)
  -> gitops 저장소 태그 갱신 -> ArgoCD가 staging 자동 반영 / prod 수동 Sync
```

## 작업 규칙

1. 최신 main에서 브랜치 생성: `git switch main && git pull && git switch -c feature/<이름>-<작업>`
2. 작은 단위로 commit, push
3. 작업 중에는 **Draft PR**로 올리면 CI가 돌지 않습니다 (Actions 분 절약). 리뷰 준비가 되면 Ready for review
4. main에 직접 push 금지. 항상 PR
5. 문서(`*.md`, `docs/`)만 바뀐 변경은 CI/Release가 실행되지 않습니다

커밋 메시지 예: `feat: ...`, `fix: ...`, `chore: ...`, `docs: ...`

## 폴더

| 경로 | 설명 |
|---|---|
| `app/` | 애플리케이션 (Node.js) |
| `Dockerfile` | 이미지 빌드 |
| `.github/workflows/` | `ci.yml`(PR), `release.yml`(main), `_notify.yml`(Discord 알림) |
| `runner/` | self-hosted runner 설치 스크립트 |

## 알림 (Discord)

commit / PR / issue / actions 채널로 구분되어 전송됩니다. 처음 설정은 `git-config` 채널의 안내를 따르세요.

## 보안

- 토큰, 키, 비밀번호를 코드/커밋/이슈/채팅에 올리지 마세요. 비밀값은 GitHub Secrets로만 관리합니다.
- 실수로 올렸다면 즉시 토큰을 폐기(재발급)하고 담당자에게 알리세요.

## 담당

CI/CD 메인 / 보조: (이름 기입)
