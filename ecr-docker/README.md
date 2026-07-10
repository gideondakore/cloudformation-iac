# Push Docker Image to ECR — Lab

Node.js app containerized and pushed to a private Amazon ECR repository by
GitHub Actions on every push, authenticated with GitHub OIDC (no AWS keys in
GitHub secrets).

## Layout

```
ecr-docker/
├── app/
│   ├── server.js             # Minimal Node.js HTTP app (no dependencies)
│   ├── package.json
│   ├── Dockerfile            # Multi-stage, alpine, non-root, HEALTHCHECK
│   └── .dockerignore
├── infrastructure/
│   └── ecr_stack.yml         # CloudFormation: ECR repo + OIDC push role
├── param.yml                 # GitSync deployment file (bonus: IaC + GitSync)
└── README.md
```

## Architecture

```
push to main ──▶ GitHub Actions
                   │ 1. OIDC token ──▶ AWS STS ──▶ assume ecr-lab-github-push-role
                   │ 2. docker build (multi-stage, node:22-alpine, USER node)
                   │ 3. smoke test container (/health)
                   │ 4. docker push ──▶ private ECR: ecr-lab-app
                   │        tags: gideondakore_ecr-lab-app  (required format)
                   │              gideondakore_ecr-lab-app-<sha>  (traceable)
                   └─ any step fails ──▶ pipeline stops, nothing pushed
ECR: scan-on-push enabled, AES256 encryption, lifecycle policy
```

## Security practices

- **Dockerfile**: minimal `node:22-alpine` base, multi-stage build, runs as
  the unprivileged `node` user, `--ignore-scripts` on install, `HEALTHCHECK`,
  only runtime files copied (`.dockerignore` excludes git/IDE/env files).
- **Auth**: GitHub OIDC federation — zero long-lived AWS credentials. The
  only GitHub secret is the role ARN (an identifier, not a credential).
- **IAM**: role trusts only `repo:gideondakore/cloudformation-iac` on `main`;
  push permissions scoped to the single `ecr-lab-app` repository
  (`ecr:GetAuthorizationToken` is account-scoped by AWS design).
- **ECR**: scan-on-push, encryption at rest, lifecycle policy (drop untagged
  after 7 days, keep last 20), repo policy limiting pulls to the account.
- **Pipeline fails securely**: `set -euo pipefail`, smoke test gates the
  push, official `aws-actions/*` actions, `permissions` limited to
  `id-token: write` + `contents: read`, concurrency guard.

## Setup

1. Deploy `ecr-docker/param.yml` via CloudFormation GitSync (bonus
   requirement). If the account does **not** already have the GitHub OIDC
   provider (the eb-lab stack creates one), set
   `CreateGitHubOidcProvider: "true"`.
2. Add GitHub repository secret `AWS_ECR_PUSH_ROLE_ARN` =
   `GitHubEcrPushRoleArn` stack output.
3. Push a change under `ecr-docker/app/` — pipeline builds, tests, pushes.

## Validation

- Actions tab: green run on push.
- ECR console (`RepositoryConsoleUrl` stack output): image with tag
  `gideondakore_ecr-lab-app` + SHA-suffixed tag, scan results attached.
- Local test:
  ```bash
  aws ecr get-login-password --region eu-west-1 | \
    docker login --username AWS --password-stdin <account>.dkr.ecr.eu-west-1.amazonaws.com
  docker run -p 8080:8080 <account>.dkr.ecr.eu-west-1.amazonaws.com/ecr-lab-app:gideondakore_ecr-lab-app
  curl localhost:8080
  ```
