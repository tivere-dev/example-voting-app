# Capstone 1: Ship It (Voting App)

DevOps capstone project by **Tivere Madagwa**, built on a fork of
[dockersamples/example-voting-app](https://github.com/dockersamples/example-voting-app).

The goal of the capstone is to take the Voting App from local development
through hardened containers, infrastructure as code, CI/CD and a Helm
deployment with rollback.

> **Zero-cost scope.** This project is being completed with a budget of
> **$0**. No cloud account is used and no cloud resources are created. The
> cloud requirements of the brief are covered by reviewable code and clearly
> labelled local substitutes. See
> [Cloud requirement and limitation](#cloud-requirement-and-limitation).

## Status

Last updated: 21 October 2026. Only results that were actually run are marked
as verified.

| Stage | What it covers | Status |
|---|---|---|
| 1. Run locally | Docker Compose, cast a vote, see it counted | Verified on macOS 13 (Intel), Docker Desktop 28.5 |
| 2. Containerize safely | Pinned base images, non-root users, `.dockerignore`, health checks | Verified locally |
| 3. Terraform | EKS cluster in the default VPC | Code written ([terraform/](terraform/)). `terraform fmt` passed. `validate` pending (planned for CI). **Never applied: no cluster exists.** |
| 4. GitHub Actions | Tests, Trivy scan, build, push tagged with the commit SHA | Not started |
| 5. Helm | One chart, one values file, bad release, `helm rollback` | Not started (target: local Minikube) |

## Architecture

```mermaid
flowchart LR
    user([Browser])
    subgraph front-tier
        vote["vote<br/>Python / Flask<br/>:8080"]
        result["result<br/>Node.js<br/>:8080"]
    end
    subgraph back-tier
        redis[("Redis<br/>queue")]
        worker["worker<br/>.NET 10"]
        db[("PostgreSQL 15<br/>db-data volume")]
    end
    user -- "localhost:8082" --> vote
    user -- "localhost:8081" --> result
    vote -- "RPUSH votes" --> redis
    worker -- "LPOP votes" --> redis
    worker -- "INSERT / UPDATE" --> db
    result -- "SELECT every 1 s" --> db
```

1. `vote` accepts a vote and pushes it onto the Redis list `votes`.
2. `worker` pops votes from Redis and writes them to PostgreSQL. Each browser
   (identified by a `voter_id` cookie) has one vote that it can change.
3. `result` reads the totals from PostgreSQL every second and pushes them to
   the browser over Socket.IO.

If the worker stops, votes wait in Redis and are processed when it returns.
This was tested: 3 votes queued while the worker was stopped were all saved
after it restarted.

## Running locally

Prerequisites: Docker Desktop (or another Docker Engine with Compose v2).

```bash
docker compose up -d --build --wait
```

| Page | URL |
|---|---|
| Vote | http://localhost:8082 |
| Result | http://localhost:8081 |

The host ports can be changed without editing the Compose file, for example
`VOTE_PORT=9000 RESULT_PORT=9001 docker compose up -d`. Inside the containers
both web apps listen on port 8080.

Optional load: `docker compose --profile seed run --rm seed` sends 3,000 votes.
The worker processes roughly 10 votes per second, so the results page catches
up over about five minutes.

Stop the app and keep the votes:

```bash
docker compose down
```

Stop the app and delete the votes:

```bash
docker compose down -v
```

## Container hardening (Stage 2)

| Image | Base (pinned by tag and digest) | Runs as |
|---|---|---|
| vote | `python:3.13.16-slim-trixie` | UID 10001 |
| result | `node:24.22.0-trixie-slim` | UID 1000 (`node`) |
| worker | `mcr.microsoft.com/dotnet/runtime:10.0.13-noble-chiseled` | UID 1654 (`app`) |
| seed | `python:3.13.16-slim-trixie` | UID 65534 |
| redis | `redis:8.10.2-alpine` | `redis` (entrypoint drops root) |
| db | `postgres:15.19-alpine` | UID 70 (`postgres`) |

- Python dependencies are pinned to exact versions, and npm installs from
  `package-lock.json` with `npm ci`.
- Application code is owned by root and is read-only for the app user.
- The vote and result health checks use Python and Node directly, so `curl`
  is not installed in the images.
- The worker image has no shell or package manager. Its connection string
  disables Npgsql's GSS (Kerberos) encryption attempt, which needs a library
  the chiseled image does not include.

## Cloud requirement and limitation

The brief asks for Terraform to create a Kubernetes cluster **in the default
VPC**, then destroy it and recreate it from code. Capstone 2 then runs on
that cluster. A default VPC is an AWS concept, and a managed AWS cluster
(EKS) costs money: about $0.10 per hour for the control plane alone (AWS
price list, September 2026). Even the AWS Free plan needs a payment card at
sign-up.

Because the budget is $0, the plan is:

- **No AWS account, no cloud resources, no `terraform apply`.**
- Terraform code for an EKS cluster in the default VPC is written for review
  and checked with `terraform fmt -check` and `terraform validate`. Neither
  command needs credentials or creates anything. `terraform plan` cannot run
  without an AWS account, so no plan output is claimed.
- Kubernetes work runs on **Minikube on this laptop**. Minikube is a
  single-node practice cluster. **It is not an EKS cluster and does not meet
  the "default VPC" requirement.**
- CI/CD uses GitHub Actions and the GitHub Container Registry. Both are free
  for public repositories on standard GitHub-hosted runners.

### What can be shown locally, and what needs a real cloud cluster

| Requirement (from the brief) | Shown at $0? | How |
|---|---|---|
| Fork the repo, run with Docker Compose, vote is counted | Yes | Docker Compose (verified) |
| Pinned images, non-root, `.dockerignore`, every image builds and starts | Yes | Docker (verified) |
| Terraform code for a Kubernetes cluster | Yes, as code | [terraform/](terraform/): `fmt` passed; `validate` to run in CI |
| Cluster created **in the default VPC**, destroyed and recreated | **No** | Needs an AWS account. Not performed. |
| "The environment rebuilds from code" | Partly | Minikube can be deleted and rebuilt from scripts, but this is a local substitute, not the AWS cluster |
| Each push runs tests, a Trivy scan, a build and a push tagged with the commit SHA | Yes | GitHub Actions and GHCR (free for public repos) |
| "One push builds, scans and **deploys**" | Partly | The pipeline can deploy the Helm chart to a temporary cluster created inside the CI runner and test it. That cluster is deleted when the job ends. There is no persistent cloud deployment. |
| One Helm chart, one values file | Yes | Helm |
| Bad release on purpose, then `helm rollback`, shown live | Yes | On Minikube |
| No secrets in Git | Yes | Checked before every commit |
| Capstone 2 on "your Capstone 1 cluster" | **No** (substitute) | Runs on Minikube instead, limited by laptop memory and disk |

### Could an instructor-provided environment meet the cloud requirement?

Possibly, if it involves no personal payment. Options to ask the instructor
about:

1. **An instructor- or school-provided AWS sandbox.** For example, an account
   or role in the instructor's AWS organisation, or AWS Academy Learner Lab if
   the school is a member. Learner Lab accounts need no personal card, but
   they restrict IAM (students generally cannot create IAM roles and must use
   a provided role), limit regions, and may not allow EKS. The Terraform code
   would need to use the provided role. **Not confirmed. This needs the
   instructor's answer.**
2. **A shared cluster run by the instructor.** A kubeconfig for a namespace
   would cover the Helm and Capstone 2 work, but not the "Terraform creates
   the cluster" step.
3. **Azure for Students** offers $100 of credit with no credit card for
   eligible full-time students. Azure uses virtual networks (VNets) rather
   than a default VPC, so this would be a deviation from the brief and
   needs the instructor's approval.
4. **Accept the documented local substitute** described above.

Until one of these is confirmed, every cloud step in this repository is
marked as not performed.

## Repository layout

| Path | Purpose |
|---|---|
| `vote/`, `result/`, `worker/` | Application services and their Dockerfiles |
| `seed-data/` | Optional load generator (Apache Bench) |
| `healthchecks/` | Health check scripts for Redis and PostgreSQL |
| `docker-compose.yml` | Local stack (production images) |
| `terraform/` | EKS cluster in the default VPC, for review only (see its [README](terraform/README.md)) |
| `k8s-specifications/`, `docker-stack.yml`, `docker-compose.images.yml` | Upstream examples. They use upstream images on port 80 and are not part of this capstone. The Helm chart (Stage 5) will replace them. |

## Security notes

- No secrets, credentials, tokens or Terraform state are committed.
- The PostgreSQL username and password (`postgres`/`postgres`) are the
  upstream demo values and are only used on the local Docker network. They
  will move to a Kubernetes Secret in the Helm stage.

## Attribution

Capstone work by Tivere Madagwa. The application code comes from
[dockersamples/example-voting-app](https://github.com/dockersamples/example-voting-app)
(Apache License 2.0, see [LICENSE](LICENSE)). Upstream's notes: the app accepts
one vote per browser, and it is a teaching example rather than a
production-ready design.
