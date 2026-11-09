# Secure DevSecOps CI/CD Pipeline

**An End-to-End Secure Software Delivery Pipeline Using GitHub Actions, Terraform and AWS**

## 1. Project Overview

### 1.1 Background

Modern software delivery involves several stages, from writing application code to testing, building and publishing software.

Each stage introduces potential security risks. These include exposed credentials, vulnerable dependencies, insecure application code, misconfigured infrastructure and vulnerable container images.

When security is treated as a final check rather than part of the development process, these issues can remain undetected until much later.

This project addresses that challenge by integrating automated security checks into a CI/CD pipeline.

The solution combines GitHub Actions, Docker, Terraform and AWS to create a delivery process where application testing and security validation happen before container images are published.

### 1.2 Engineering Vision

The objective was to build a secure and automated software delivery pipeline that makes security part of the release process.

Rather than relying on manual checks, the pipeline uses automated security tools to examine different parts of the application and its infrastructure.

It also uses AWS OpenID Connect (OIDC) authentication to allow GitHub Actions to access AWS without storing permanent AWS access keys.

The result is a working pipeline that connects application testing, security validation, infrastructure provisioning and container image publishing.

### 1.3 Project Objectives

The project was designed to:

- Automate application testing.
- Detect exposed secrets and credentials.
- Perform static application security testing.
- Identify vulnerabilities in application dependencies.
- Scan Docker images for known vulnerabilities.
- Validate Terraform infrastructure against security best practices.
- Introduce security gates that control the publishing process.
- Establish secure GitHub Actions authentication to AWS using OIDC.
- Provision Amazon ECR and the required IAM resources using Terraform.
- Publish approved container images to Amazon ECR.

---

## 2. System Architecture and Design

### 2.1 Architecture Overview

The pipeline uses GitHub Actions as the central automation platform.

When code is pushed or a pull request is opened against the `main` branch, the workflow starts and executes the required application and security validation jobs.

The publishing stage depends on the successful completion of all six validation jobs.

After validation, GitHub Actions authenticates to AWS through OIDC, assumes the configured IAM role and publishes the Docker image to Amazon ECR.

### 2.2 Architecture Diagram

```text
                 DEVELOPER
                     |
                     |
              Git Push / PR
                     |
                     v
             GITHUB REPOSITORY
                     |
                     v
              GITHUB ACTIONS
                     |
          +----------+----------+
          |          |          |
          v          v          v
       PYTEST     GITLEAKS   SEMGREP
     App Tests    Secrets    SAST
          |          |          |
          +----------+----------+
                     |
          +----------+----------+
          |                     |
          v                     v
       TRIVY                 CHECKOV
   Dependencies          Terraform IaC
          |
          v
       TRIVY
   Container Image
          |
          +---------------------+
                     |
                     v
              SECURITY GATES
                     |
          Required jobs must pass
                     |
                     v
             GITHUB ACTIONS
                  OIDC
                     |
                     v
                 AWS IAM
                ROLE ASSUMPTION
                     |
                     v
              AMAZON ECR LOGIN
                     |
                     v
                DOCKER BUILD
                     |
                     v
                 DOCKER PUSH
                     |
                     v
              AMAZON ECR REPOSITORY
```

### 2.3 Workflow Execution

The main workflow is defined in:

`.github/workflows/secure-pipeline.yml`

It coordinates six reusable validation workflows:

| Workflow | Responsibility |
|---|---|
| `ci.yml` | Runs application tests. |
| `gitleaks.yml` | Detects exposed secrets. |
| `semgrep.yml` | Performs static application security testing. |
| `trivy.yml` | Scans application dependencies. |
| `trivy-image.yml` | Scans the Docker image. |
| `checkov.yml` | Checks Terraform infrastructure security. |

Each workflow has its own responsibility, keeping the pipeline organised and easier to maintain.

### 2.4 Publishing Conditions

The image publishing job is configured with dependencies on all six validation jobs.

It runs only when:

- The workflow is triggered by a push to `main`.
- All required validation jobs complete successfully.

Pull requests run the validation stages but do not publish images.

This separates code validation from image publishing and prevents the publishing job from running independently of the required security checks.

---

## 3. Technology Stack

| Component | Technology | Purpose |
|---|---|---|
| Application | Python and Flask | Provides the API used by the pipeline. |
| Application server | Gunicorn | Runs the Flask application. |
| Testing | Pytest | Validates application behaviour. |
| Containerization | Docker | Packages the application. |
| CI/CD | GitHub Actions | Automates testing, scanning and publishing. |
| Secret scanning | Gitleaks | Detects exposed credentials and secrets. |
| SAST | Semgrep | Analyses application code for security issues. |
| Dependency scanning | Trivy | Identifies vulnerable dependencies. |
| Container scanning | Trivy | Checks Docker images for vulnerabilities. |
| Infrastructure as Code | Terraform | Provisions AWS resources. |
| IaC security | Checkov | Validates Terraform security configurations. |
| Cloud platform | AWS | Provides the infrastructure and container registry. |
| Authentication | GitHub Actions OIDC | Establishes temporary AWS authentication. |
| Container registry | Amazon ECR | Stores published Docker images. |

---

## 4. Application Implementation

### 4.1 Application Design

A lightweight Flask API was developed to provide an application workload for the pipeline.

It exposes two endpoints:

| Endpoint | Function |
|---|---|
| `/` | Returns application information and running status. |
| `/health` | Returns the application's health status. |

The application is intentionally small. The main engineering focus is the secure delivery process rather than application feature development.

### 4.2 Automated Testing

Pytest was used to validate both application endpoints.

The tests verify:

- Successful HTTP responses.
- Expected JSON response values.
- Correct application status information.

The CI workflow installs the development dependencies and executes the test suite.

A failed application test prevents the pipeline from progressing through its required publishing dependencies.

---

## 5. Security Engineering Implementation

Security controls were integrated across the application, dependencies, container image and infrastructure configuration.

### 5.1 Secret Detection — Gitleaks

Gitleaks was integrated to detect exposed credentials and secrets in the repository.

The workflow checks repository history using a full Git checkout.

This helps identify accidentally committed secrets rather than checking only the latest working tree.

The scan is configured to fail when secrets are detected.

### 5.2 Static Application Security Testing — Semgrep

Semgrep performs static analysis on the application code.

It checks the source code for potential security issues without requiring the application to be running.

The workflow uses Semgrep's automatic configuration and the `--error` option to make detected findings fail the security check.

### 5.3 Dependency Vulnerability Scanning — Trivy

Trivy scans the application's filesystem and dependency files for known vulnerabilities.

The scan is configured to:

- Examine application dependencies.
- Focus on library vulnerabilities.
- Report HIGH and CRITICAL severity findings.
- Ignore vulnerabilities without available fixes.
- Return a non-zero exit code when the configured blocking conditions are met.

This makes dependency security part of the pipeline's required validation process.

### 5.4 Container Image Scanning — Trivy

Trivy also scans the Docker image created during the pipeline.

This provides visibility into vulnerabilities introduced through the container image and its installed packages.

The container scan currently operates in report-only mode.

It uses an exit code of `0`, meaning reported findings do not automatically block image publishing.

This is an intentional distinction between dependency enforcement and container image reporting.

### 5.5 Infrastructure Security — Checkov

Checkov was integrated to examine the Terraform configuration before infrastructure deployment.

It checks the infrastructure definitions against security policies and best practices.

The workflow runs Checkov against the Terraform directory:

```bash
checkov -d terraform --framework terraform
```

The security gate uses Checkov's default failure behaviour, meaning failed checks cause the workflow to fail.

The final validation recorded:

- 18 passed checks.
- 0 failed checks.
- 0 skipped checks.

---

## 6. Container Security Engineering

### 6.1 Docker Image Design

The application is packaged using Docker with a slim Python 3.12 base image.

The Dockerfile includes operating system package updates and installs the application dependencies.

Additional configuration includes:

- Python environment settings to reduce unnecessary bytecode files and buffering.
- A dedicated non-root application user.
- Restricted application file ownership.
- A health check against the `/health` endpoint.
- Gunicorn configured with two workers.

### 6.2 Non-Root Execution

The container does not run the application as the root user.

A dedicated `appuser` account is created during the image build, and the application runs under that account.

This reduces the privileges available to the application process inside the container.

### 6.3 Container Health Check

Docker is configured to check the application's health every 30 seconds.

The health check sends a request to:

`http://127.0.0.1:5000/health`

It uses a five-second timeout, a ten-second startup period and three retries.

This provides a basic mechanism for identifying when the application stops responding.

---

## 7. AWS Infrastructure Implementation

### 7.1 Infrastructure Provisioning with Terraform

Terraform manages the AWS resources required for secure image publishing.

The infrastructure configuration provisions:

- GitHub Actions OIDC identity provider.
- Dedicated IAM publishing role.
- IAM trust policy.
- IAM permissions policy.
- Amazon ECR repository.

The AWS provider is configured through Terraform variables, with `us-east-1` as the default region.

### 7.2 GitHub Actions OIDC Integration

One of the main security decisions in this project was to avoid storing permanent AWS access keys in GitHub.

Instead, GitHub Actions uses OIDC to establish a trusted relationship with AWS.

The authentication flow works as follows:

1. GitHub Actions requests an OIDC identity token.
2. AWS validates the token against its configured identity provider.
3. IAM checks the token's audience and repository/branch identity against the trust policy.
4. GitHub Actions assumes the dedicated IAM role when the conditions are satisfied.
5. AWS provides temporary credentials.
6. The workflow uses those credentials to authenticate to Amazon ECR.

The trust policy restricts role assumption to the designated repository and `main` branch.

This reduces the risk associated with long-lived credentials and limits which GitHub workflow identity can access the publishing role.

### 7.3 IAM Permissions

The publishing role has the permissions required for ECR authentication and image publishing.

The policy includes:

- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:BatchGetImage`
- `ecr:CompleteLayerUpload`
- `ecr:InitiateLayerUpload`
- `ecr:PutImage`
- `ecr:UploadLayerPart`

The image publishing permissions are scoped to the designated ECR repository.

The ECR authorization token action uses the required wildcard resource scope.

### 7.4 Amazon ECR Configuration

The ECR repository is configured with several security and storage controls.

| Configuration | Implementation |
|---|---|
| Image tag mutability | Immutable |
| Image scanning | Enabled on push |
| Encryption | AWS KMS |
| Lifecycle management | Untagged images expire after seven days |

Immutable tags help protect published image references from being overwritten.

Image scanning on push provides an additional opportunity to identify vulnerabilities in uploaded images.

The lifecycle policy also helps prevent untagged images from accumulating indefinitely.

---

## 8. CI/CD Pipeline Validation

Validation was performed at different stages to confirm that the application, security controls, infrastructure and publishing process worked as expected.

### 8.1 Application and Container Validation

The application was tested using Pytest.

The Docker image was built and the container was started successfully.

Additional validation confirmed:

- The application endpoints returned the expected responses.
- The container ran using a non-root user.
- The Docker health check targeted the correct endpoint.

### 8.2 Security Validation

The following security workflows were successfully executed:

| Validation | Result |
|---|---|
| Pytest | Passed |
| Gitleaks | Passed |
| Semgrep | Passed |
| Trivy dependency security gate | Passed |
| Trivy container image scan | Executed successfully; report-only |
| Checkov | 18 passed, 0 failed, 0 skipped |

The container image scan is reported separately because its findings do not currently block publishing.

### 8.3 AWS Authentication Validation

The publishing workflow successfully authenticated to AWS using GitHub Actions OIDC.

The workflow verified the AWS identity before continuing with ECR authentication.

This confirmed that the configured identity provider, trust policy and IAM role worked together as intended.

### 8.4 ECR Publishing Validation

After all required validation jobs succeeded, GitHub Actions built and pushed the Docker image to Amazon ECR.

The published image was verified in the ECR repository.

Images use the Git commit SHA as their tag, making it possible to trace a published image back to its source revision.

**Final result: The complete pipeline executed successfully, and the application image was published to Amazon ECR.**

---

## 9. Repository Structure

```text
Secure-DevSecOps-CI-CD/
│
├── .github/
│   └── workflows/
│       ├── secure-pipeline.yml
│       ├── ci.yml
│       ├── gitleaks.yml
│       ├── semgrep.yml
│       ├── trivy.yml
│       ├── trivy-image.yml
│       └── checkov.yml
│
├── app/
│   └── app.py
│
├── screenshots/
│
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
│
├── tests/
│   └── test_app.py
│
├── Dockerfile
├── .dockerignore
├── .gitignore
├── requirements.txt
├── requirements-dev.txt
├── requirements-lock.txt
├── requirements-dev-lock.txt
└── trivy.yaml
```

### Important Repository Security Configuration

The `.gitignore` file excludes local development files and sensitive Terraform artifacts, including:

- Terraform state files.
- Terraform backup state files.
- Terraform provider directories.
- Variable files.
- Local virtual environments.
- Python cache files.
- Local environment files.

Terraform state files are kept out of version control.

---

## 10. Running the Project Locally

### 10.1 Clone the Repository

```bash
git clone https://github.com/Achapatience123/Secure-DevSecOps-CI-CD.git

cd Secure-DevSecOps-CI-CD
```

### 10.2 Create a Virtual Environment

```bash
python -m venv .venv

source .venv/Scripts/activate
```

### 10.3 Install Development Dependencies

```bash
pip install -r requirements-dev.txt
```

### 10.4 Run Application Tests

```bash
python -m pytest -v
```

### 10.5 Build the Docker Image

```bash
docker build -t secure-devsecops-api .
```

### 10.6 Run the Container

```bash
docker run -d \
  --name secure-devsecops-api \
  -p 5000:5000 \
  secure-devsecops-api
```

### 10.7 Validate the Application

```bash
curl http://localhost:5000/

curl http://localhost:5000/health
```

Both endpoints should return successful responses when the application is running correctly.

---

## 11. Terraform Deployment

The AWS infrastructure is managed through the Terraform configuration in the `terraform/` directory.

From that directory, run:

```bash
terraform init

terraform validate

terraform plan

terraform apply
```

Review the Terraform execution plan before applying changes.

The infrastructure uses the configured AWS region and repository variables.

Terraform state files and other sensitive local configuration must remain outside version control.

---

## 12. Evidence and Screenshots

Implementation and validation evidence is maintained in the `screenshots/` directory.

The screenshots document the major project milestones.

| Evidence | What It Demonstrates |
|---|---|
| Docker image build | Successful container image creation. |
| Docker API validation | Application endpoints responding correctly. |
| Non-root verification | Application running without root privileges. |
| GitHub Actions CI | Successful automated test execution. |
| Gitleaks | Successful secret scanning. |
| Semgrep | Successful static analysis. |
| Trivy dependency scan | Dependency vulnerability validation. |
| Trivy container scan | Container image vulnerability reporting. |
| Checkov initial scan | Initial infrastructure security assessment. |
| Checkov passing scan | Successful Terraform security validation. |
| Checkov security gate | Validation of the infrastructure security gate. |
| Terraform deployment | Successful AWS infrastructure provisioning. |
| ECR publishing | Successful image publishing. |
| ECR repository verification | Published image visible in the repository. |

---

## 13. Key Engineering Decisions

Several decisions shaped the implementation of this project.

### 13.1 Reusable GitHub Actions Workflows

Security checks were separated into reusable workflows rather than placing every step inside one large workflow file.

This makes the pipeline easier to maintain and allows each security control to have its own configuration and execution responsibility.

### 13.2 Security Gates Based on Risk

Not every scan was configured to block publishing.

Dependency scanning enforces the selected HIGH and CRITICAL vulnerability policy, while container image scanning remains report-only.

This makes the enforcement behaviour explicit rather than treating every scanner finding as an automatic release blocker.

### 13.3 OIDC Instead of Permanent AWS Credentials

GitHub Actions uses OIDC to obtain temporary AWS credentials.

This avoids maintaining permanent AWS access keys in GitHub and allows IAM to control access through a repository-specific trust policy.

### 13.4 Least-Privilege IAM Permissions

The publishing role receives the ECR permissions required for its task rather than broad administrative access.

The repository-specific permissions also reduce the scope of the publishing role.

### 13.5 Immutable ECR Image Tags

Image tags are immutable, and the Git commit SHA is used as the image tag.

This improves traceability and prevents an existing tag from being silently replaced.

### 13.6 Terraform for Infrastructure Management

Terraform provides a repeatable way to provision and manage the AWS resources used by the pipeline.

It also allows infrastructure security checks to run before deployment.

---

## 14. Lessons and Engineering Outcomes

This implementation demonstrates several important software delivery and cloud security practices:

- Security checks can be integrated directly into CI/CD workflows.
- Reusable workflows help organise complex automation.
- Security gates provide control over whether a publishing stage can proceed.
- OIDC provides a way to authenticate GitHub Actions to AWS without permanent access keys.
- IAM trust policies and permissions determine which workflows can access cloud resources.
- Terraform makes cloud infrastructure easier to manage consistently.
- Container security requires attention to both the image and the privileges used to run the application.
- Successful pipeline execution and zero vulnerability findings are not the same thing.

The project also demonstrates the importance of validating each component independently before relying on the complete pipeline.

---

## 15. Cleanup and Resource Management

AWS resources created for this project should be removed when they are no longer required.

Before destroying the infrastructure:

1. Confirm that all required screenshots and documentation have been saved.
2. Review the Terraform resources currently managed by the project.
3. Remove the ECR images so that the repository can be deleted.
4. Review the Terraform destroy plan.
5. Destroy the provisioned infrastructure.

Useful Terraform commands:

```bash
terraform state list

terraform plan -destroy
```

After reviewing the destroy plan, the infrastructure can be removed with:

```bash
terraform destroy
```

Run these commands from the Terraform directory using the correct AWS credentials and region.

**Important:** ECR repositories containing images may need their images deleted before Terraform can remove the repository. Confirm the repository is empty before completing cleanup.

---

## 16. Future Improvements

The current implementation focuses on securing the application testing and container publishing stages.

Future improvements could extend the pipeline with:

- Automated deployment to Amazon ECS or EKS.
- Deployment approval controls.
- A stricter container image vulnerability enforcement policy.
- Expanded application security testing.
- Runtime monitoring and alerting.
- Multi-cloud infrastructure and security integration across AWS, Microsoft Azure and Google Cloud Platform.

These improvements would extend the existing pipeline rather than replace its current architecture.

---

## 17. Final Project Status

**Implementation: Completed**

The Secure DevSecOps CI/CD Pipeline was successfully implemented and validated.

The completed workflow:

- Runs automated application tests.
- Performs secret detection and static code analysis.
- Scans application dependencies and container images.
- Validates Terraform infrastructure configurations.
- Enforces the configured security gates.
- Authenticates GitHub Actions to AWS using OIDC.
- Builds and publishes the application image to Amazon ECR.
- Verifies the published image in the ECR repository.

The final implementation demonstrates an automated approach to secure software delivery, combining application security, infrastructure validation, cloud identity management and container publishing in one CI/CD pipeline.

**The objective was not simply to automate a build. It was to establish a delivery process in which security validation is part of how software moves from source code to a published container image.**
