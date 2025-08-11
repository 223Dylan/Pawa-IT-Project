## Insight-Agent on Google Cloud (Serverless, IaC, CI/CD)

This repository contains a minimal production-ready setup to deploy a Python FastAPI service (Insight-Agent) to Google Cloud Run using Terraform and GitHub Actions.

### Architecture Overview

- **App**: Python FastAPI exposing `POST /analyze` to perform basic text analysis (word and character counts).
- **Container**: Built from a lightweight Python base image with a non-root user.
- **Registry**: Google Artifact Registry hosts container images.
- **Runtime**: Google Cloud Run service runs the container with a dedicated least-privilege service account.
- **Security**: The service is private (no public access). Only explicitly authorized principals can invoke it.
- **Automation**: GitHub Actions builds, pushes the image, and deploys Terraform to update Cloud Run.

Text-based diagram:

```
Developer Push -> GitHub Actions -> (OIDC Auth) -> GCP
   |                                   |
   |                                   +--> Cloud Build (optional via gcloud) builds & pushes image to
   |                                        Artifact Registry: <location>-docker.pkg.dev/<project>/<repo>/insight-agent:<sha>
   |
   +--> Terraform Apply --------------> Provisions/updates:
                                          - APIs, Artifact Registry
                                          - Cloud Run service (private)
                                          - Service Accounts & IAM (least-privilege)

Client (with IAM permission) --ID token--> Cloud Run (Private) --returns--> Analysis JSON
```

### Design Decisions

- **Cloud Run**: Serverless, scales to zero, secure by default, simple deployment and rollbacks.
- **Private Access**: The service is not publicly accessible. We do not grant `allUsers` the `run.invoker` role. Only identities you specify can invoke the service. This satisfies the “not publicly accessible” requirement while keeping the setup simple for an MVP. You may later place an Internal HTTP(S) Load Balancer in front if you need strict VPC-only access.
- **Terraform**: All infrastructure is defined as code. Project ID, region, repository names, and invoker principals are parameterized.
- **GitHub Actions + OIDC**: Uses Workload Identity Federation to avoid storing long-lived keys. The pipeline performs: lint/test → build → push → deploy.
- **Two-phase deploy in CI**: Terraform first ensures APIs and Artifact Registry exist; then the image is built and pushed; finally Terraform updates Cloud Run with the new image.

### Repository Structure

```
.
├─ app/
│  ├─ main.py
│  └─ requirements.txt
├─ tests/
│  └─ test_app.py
├─ terraform/
│  ├─ main.tf
│  ├─ variables.tf
│  ├─ outputs.tf
│  └─ versions.tf
├─ .github/
│  └─ workflows/
│     └─ deploy.yaml
├─ Dockerfile
├─ .dockerignore
├─ .gitignore
└─ README.md
```

### Prerequisites

- A Google Cloud project (or create a new one). Note the `project_id`.
- Permissions to enable APIs and create resources: typically `Owner` for the initial bootstrap or a set of equivalent roles including `Artifact Registry Admin`, `Cloud Run Admin`, `Service Account Admin`, `Service Usage Admin`, `Cloud Build Editor`.
- A GitHub repository to host this code.

### One-time GCP Setup

1) Enable Workload Identity Federation for GitHub Actions (recommended):

- Create a Workload Identity Pool and Provider that trusts your GitHub repo.
- Create a deployer Service Account (e.g., `sa-deployer@<project_id>.iam.gserviceaccount.com`).
- Grant the deployer SA these roles at project level (minimally):
  - `roles/run.admin`
  - `roles/iam.serviceAccountUser`
  - `roles/artifactregistry.admin` (or repo-scoped equivalent)
  - `roles/cloudbuild.builds.editor`
  - `roles/serviceusage.serviceUsageAdmin`

Map the GitHub OIDC to impersonate the deployer SA. Follow Google’s guide: `https://github.com/google-github-actions/auth#setting-up-workload-identity-federation`

2) Decide who can invoke the service:

- Collect the list of IAM members (e.g., `serviceAccount:sa-caller@<project>.iam.gserviceaccount.com`, or `user:you@example.com`) and put them in Terraform variable `allowed_invokers`.

### Local Development (optional)

Run the app locally:

```
python -m venv .venv
. .venv/bin/activate  # Windows: .\.venv\Scripts\activate
pip install -r app/requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

Test locally:

```
pytest -q
```

Sample request:

```
curl -s -X POST localhost:8080/analyze \
  -H 'Content-Type: application/json' \
  -d '{"text": "I love cloud engineering!"}' | jq
```

### Build and Run Container Locally

```
docker build -t insight-agent:local .
docker run -p 8080:8080 insight-agent:local
```

### Terraform Configuration

Key variables (see `terraform/variables.tf`):

- `project_id` (string): Your GCP project ID.
- `region` (string): Deployment region (e.g., `us-central1`).
- `repo_id` (string): Artifact Registry repo name (default `insight-agent`).
- `service_name` (string): Cloud Run service name (default `insight-agent`).
- `container_image` (string): Full image URI used by Cloud Run (set by CI).
- `allowed_invokers` (list(string)): Principals allowed to invoke the service.

Initialize and apply (manually):

```
cd terraform
terraform init
terraform apply -var "project_id=<your-project-id>" -var "region=us-central1" \
                -var "allowed_invokers=[\"user:you@example.com\"]"
```

Outputs include the Cloud Run service URL. Since the service is private, invoke it using an identity with `run.invoker` permission, for example:

```
gcloud auth application-default login
gcloud auth print-identity-token
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello GCP"}' \
  https://<cloud-run-url>/analyze
```

### CI/CD with GitHub Actions

The workflow (`.github/workflows/deploy.yaml`) runs on pushes to `main` and performs:

1) Lint and tests for Python and Terraform (basic).
2) Bootstrap infra parts (APIs + Artifact Registry) via Terraform `-target`.
3) Build & push image to Artifact Registry.
4) Full Terraform apply with the new image URI.

Required GitHub Actions secrets/vars:

- `GCP_PROJECT_ID` (Actions Variable)
- `GCP_REGION` (Actions Variable, e.g., `us-central1`)
- `WORKLOAD_IDENTITY_PROVIDER` (Actions Secret/Variable): Resource name of the WIF provider, e.g., `projects/123456789/locations/global/workloadIdentityPools/github/providers/my-provider`
- `GCP_SERVICE_ACCOUNT` (Actions Secret/Variable): Deployer SA email, e.g., `sa-deployer@<project_id>.iam.gserviceaccount.com`

### Security Notes

- No public access is granted. Only specified `allowed_invokers` may call the service.
- The Cloud Run runtime uses a dedicated service account with least-privilege roles required for logging and image pulls.
- No secrets are committed to the repo. Authentication uses GitHub OIDC.

### Future Enhancements

- Add an Internal HTTP(S) Load Balancer with a Serverless NEG for strict VPC-only access.
- Store Terraform state in a GCS bucket with state locking.
- Add more comprehensive tests and observability (tracing/metrics).


### Pre-commit hooks (linting and tests)

Set up git hooks to auto-lint and run tests on push:

1) Install dev tools (Windows PowerShell shown):

```
python -m venv .venv
. .\.venv\Scripts\Activate.ps1
python -m pip install -r app/requirements.txt -r requirements-dev.txt
```

2) Install hooks:

```
pre-commit install              # installs pre-commit
pre-commit install --hook-type pre-push  # runs pytest before push
```

3) Run on all files once (optional):

```
pre-commit run -a
```

Notes:
- Commit-time hooks run fast auto-fixes (trailing whitespace, ruff lint/format).
- Push-time hook runs `pytest -q`. To bypass in emergencies, use `--no-verify` (not recommended).
