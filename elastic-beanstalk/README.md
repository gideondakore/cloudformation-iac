# Elastic Beanstalk Lab — Node.js CI/CD Deployment

Node.js web app deployed to AWS Elastic Beanstalk. Every push to `main` that
touches the app packages a source bundle, uploads it to S3, registers a new
Beanstalk application version, and deploys it — no manual steps.

## Layout

```
elastic-beanstalk/
├── app/                      # Node.js application (Express + DynamoDB)
│   ├── package.json
│   └── server.js
├── infrastructure/
│   └── eb_stack.yml          # CloudFormation: EB app/env, S3, DynamoDB, IAM/OIDC
├── param.yml                 # GitSync deployment file
└── README.md
.github/workflows/
└── deploy-elastic-beanstalk.yml   # CI/CD pipeline
```

## Application

Endpoints:

- `GET /` — deployment confirmation, app version, DynamoDB visit counter
  (**optional challenge**: external service via `TABLE_NAME` / `AWS_REGION`
  Beanstalk managed environment variables)
- `GET /health` — used by CI smoke test
- `GET /version` — app version + commit SHA

Bump `version` in `elastic-beanstalk/app/package.json` before a demo push so the change is
visible after redeployment.

## Setup (one time)

1. **Deploy infrastructure** via CloudFormation GitSync: point a sync
   configuration at `elastic-beanstalk/param.yml`. Creates:
   - S3 bucket `eb-lab-bundles-<account>-<region>` (versioned, encrypted, private)
   - DynamoDB table `eb-lab-visits`
   - Elastic Beanstalk application `eb-lab` + environment `eb-lab-env`
     (starts with the sample app until the first pipeline run)
   - GitHub OIDC provider + `eb-lab-github-deploy-role` (least-privilege)
   - If the account already has the GitHub OIDC provider, set
     `CreateGitHubOidcProvider: "false"` in `elastic-beanstalk/param.yml`.
2. **Configure GitHub**: add repository secret `AWS_DEPLOY_ROLE_ARN` =
   `GitHubDeployRoleArn` stack output. No long-lived AWS keys anywhere.
3. **First deployment**: push to `main` (or run the workflow manually via
   *Actions → Deploy to Elastic Beanstalk → Run workflow*). The pipeline
   uploads the bundle to S3 and deploys it through Elastic Beanstalk.

If the default solution stack has been retired, list current ones and update
the `SolutionStackName` parameter:

```bash
aws elasticbeanstalk list-available-solution-stacks \
  --query "SolutionStacks[?contains(@, 'Node.js')]"
```

## Pipeline (per push)

1. `npm install --omit=dev` — bundle includes production `node_modules`
2. Zip → `s3://eb-lab-bundles-.../<branch>-<sha>-<run>.zip`
3. `create-application-version` (versioned releases, labeled by commit)
4. `update-environment` → waits for completion → curls `/health`

Security best practices (extra credit): OIDC federation instead of stored
access keys, `permissions` limited to `id-token: write` + `contents: read`,
least-privilege deploy role scoped to the bundle bucket and this repo/branch,
concurrency group prevents overlapping deployments, post-deploy smoke test.

## Demo / Validation

1. Open `EnvironmentUrl` stack output — JSON response confirms deployment,
   shows version and incrementing `totalVisits` (DynamoDB connectivity).
2. Edit `elastic-beanstalk/app/server.js` message or bump `package.json` version, push to `main`.
3. Watch the Actions run, then refresh the URL — new version visible.
4. Beanstalk console → Application versions — full release history in S3.
