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

### 1. Provision the Infrastructure (Initial Setup)
Create the EKS cluster and VPC networking from scratch using CloudFormation via the Makefile:
```bash
make deploy-cluster
```
> Note: CloudFormation stack provisioning typically takes 15-20 minutes.

### 2. Trigger the CI/CD Pipeline
Once the cluster is ready, push your code to trigger GitHub Actions to build and deploy your app:
```bash
make git-push m="feat: initial application deployment"
```

### 3. Monitor Cluster Health
Check the status of Pods, Services, and HPA real-time metrics:
```bash
make status
```

### 4. Clean Up Resources (Cost Optimization)
To avoid incurring unnecessary AWS charges, tear down the entire EKS cluster, LoadBalancers, and underlying CloudFormation stacks:
```bash
make destroy-cluster
```

### 5. 🔄 Redeploying After Destruction
Because the infrastructure is entirely defined as code, reviving the project is effortless. To rebuild the exact same environment after a teardown:

Run `make deploy-cluster` to provision the AWS infrastructure again.

Go to the GitHub repository, navigate to Actions, select the latest workflow run, and click "Re-run all jobs" to deploy the application into the fresh cluster.
