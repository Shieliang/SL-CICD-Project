# Cloud-Native CI/CD Pipeline & Highly Available Architecture on AWS EKS

## 🚀 Project Overview
This project demonstrates a production-grade, highly available containerized web application deployed on **AWS Elastic Kubernetes Service (EKS)**. It features a fully automated **CI/CD pipeline** using **GitHub Actions** and implements dynamic scaling using **Kubernetes Horizontal Pod Autoscaler (HPA)**. All underlying AWS infrastructure is strictly provisioned as code (IaC) using **AWS CloudFormation**.

## 🏗️ Architecture & Tech Stack
- **Cloud Provider:** Amazon Web Services (EKS, ECR, Elastic Load Balancing, VPC, IAM)
- **Infrastructure as Code (IaC):** AWS CloudFormation
- **Containerization:** Docker (Multi-stage builds, Alpine Linux)
- **Orchestration:** Kubernetes (Deployments, Services, HPA, Metrics Server)
- **CI/CD Automation:** GitHub Actions
- **Operations:** `aws cli`, `kubectl`, `Makefile`

## ✨ Core Features & Technical Highlights

### 1. Infrastructure as Code (IaC) via CloudFormation
- Designed and deployed custom VPCs, subnets, security groups, and the EKS cluster purely through **AWS CloudFormation** templates, completely eliminating manual AWS Console configuration.

### 2. Zero-Downtime Deployments (Rolling Updates)
- Engineered a robust GitHub Actions workflow that automatically builds, tags, and pushes Docker images to Amazon ECR upon every `main` branch commit.
- Utilized the unique **Git Commit SHA** (`github.sha`) as the immutable image tag, forcing Kubernetes to reliably trigger seamless **Rolling Updates** without service interruption.
- Decoupled sensitive AWS Account IDs from Kubernetes manifests using dynamic image injection.

### 3. Auto-Scaling & Self-Healing (HPA)
- Successfully deployed the Kubernetes **Metrics Server**, implementing a custom TLS bypass patch (`--kubelet-insecure-tls`) to resolve native AWS VPC CNI communication bottlenecks.
- Configured **HPA** to monitor CPU utilization, automatically scaling Pod replicas up during traffic spikes (threshold > 50%) and scaling down during idle periods to minimize AWS EC2 costs.

### 4. DevSecOps & Image Security
- Integrated security patching directly into the Dockerfile layer.
- Actively resolved high-severity vulnerabilities (e.g., CVE-2022-37434 `zlib`) identified by ECR vulnerability scanning via automated `apk upgrade` implementations.

## 🛠️ Getting Started & Lifecycle Management

### Prerequisites
- AWS CLI configured with administrative access.
- `kubectl` and `docker` installed locally.
- GitHub Repository Secrets configured (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`).

### 1. 🌟 One-Click Environment Bootstrapping
Provision the entire underlying infrastructure (VPC, EKS Cluster, ECR Repository) and initialize monitoring components in a strict dependency order:
```bash
make deploy-all
```
> Note: CloudFormation stack provisioning typically takes 15-20 minutes. Grab a coffee! ☕

### 2. Trigger the CI/CD Pipeline
Once the infrastructure and metrics are ready, push your code. GitHub Actions will automatically build the image, push it to ECR, and deploy it to EKS:
```bash
make git-push m="feat: initial application deployment via CI/CD"
```

### 3. ⚔️ Stress Testing & HPA Monitoring
To validate the auto-scaling architecture, trigger a massive traffic load:
```bash
make stress-test
```
While the stress test is running, open a new terminal tab and monitor the real-time cluster health, Pod scaling, and CPU utilization:
```bash
make status
```
You will observe the HPA triggering Pod scale-ups as the CPU load crosses the 50% threshold.

> Note: If you want to quit the stress test, press "Ctrl + C" in the terminal.

### 4. ☢️ Clean Up Resources (Nuclear Option)
To avoid incurring unnecessary AWS charges, tear down the entire application, ECR, EKS cluster, and VPC networking:
```bash
make destroy-all
```

### 5. 🔄 Redeploying After Destruction
Because the infrastructure is entirely defined as code, reviving the project is effortless. To rebuild the exact same environment:

Run the following Makefile command to provision the infrastructure and monitoring radar:
```bash
make deploy-all
```
Go to your GitHub repository, navigate to Actions, select the latest workflow run, and click "Re-run all jobs" to deploy the application into the fresh cluster.