# Cloud-Native CI/CD Pipeline & Highly Available Architecture on AWS EKS

## 🚀 Project Overview
This project demonstrates a production-grade, highly available containerized web application deployed on **AWS Elastic Kubernetes Service (EKS)**. It features a fully automated **CI/CD pipeline** using **GitHub Actions**, implements dynamic scaling using **Kubernetes Horizontal Pod Autoscaler (HPA)**, and establishes full-stack observability with **Prometheus, Grafana, and Telegram alerting**. All underlying AWS infrastructure is strictly provisioned as code (IaC) using **AWS CloudFormation**.

## 🏗️ Architecture & Tech Stack
- **Cloud Provider:** Amazon Web Services (EKS, ECR, Elastic Load Balancing, VPC, IAM)
- **Infrastructure as Code (IaC):** AWS CloudFormation, Helm
- **Containerization:** Docker (Multi-stage builds, Alpine Linux)
- **Orchestration:** Kubernetes (Deployments, Services, HPA, Metrics Server)
- **Monitoring & Alerting:** Prometheus, Grafana, Alertmanager
- **CI/CD Automation:** GitHub Actions
- **Operations & Notifications:** aws cli, kubectl, Makefile, Telegram Bot API

## ✨ Core Features & Technical Highlights

### 1. Infrastructure as Code (IaC) via CloudFormation
Designed and deployed custom VPCs, subnets, security groups, and the EKS cluster purely through CloudFormation templates, completely eliminating manual AWS Console configuration.

### 2. Zero-Downtime Deployments (Rolling Updates)
Engineered a robust GitHub Actions workflow that automatically builds, tags, and pushes Docker images to Amazon ECR upon every main branch commit.

Utilized the unique Git Commit SHA (`github.sha`) as the immutable image tag, forcing Kubernetes to reliably trigger seamless Rolling Updates without service interruption.

Decoupled sensitive AWS Account IDs from Kubernetes manifests using dynamic image injection.

### 3. Auto-Scaling & Self-Healing (HPA)
Successfully deployed the Kubernetes Metrics Server, implementing a custom TLS bypass patch (`--kubelet-insecure-tls`) to resolve native AWS VPC CNI communication bottlenecks.

Configured HPA to monitor CPU utilization, automatically scaling Pod replicas up during traffic spikes (threshold > 50%) and scaling down during idle periods to minimize AWS EC2 costs.

### 4. Full-Stack Observability & Incident Response
Deployed the kube-prometheus-stack via Helm to monitor cluster health, node metrics, and application performance.

Troubleshooting Highlight: Resolved a critical configuration sync issue between Helm and Alertmanager by implementing a Direct Secret Injection strategy. By bypassing the Helm engine and injecting pure YAML directly into the Kubernetes Secret layer, I successfully routed critical alerts to a Telegram Bot with <10s latency.

### 5. DevSecOps & Security Hardening
Image Security: Integrated security patching directly into the Dockerfile layer, actively resolving high-severity vulnerabilities (e.g., CVE-2022-37434 zlib) identified by ECR vulnerability scanning via automated apk upgrade.

Credential Protection: Addressed Copilot Security Scan warnings by implementing an Environment Variable (.env) isolation model, preventing the hardcoding of sensitive Telegram API tokens in the codebase.

## 🛠️ Getting Started & Lifecycle Management

### Prerequisites
- AWS CLI configured with administrative access.
- kubectl, helm, and docker installed locally.
- .env file created in the root directory containing your TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.
- GitHub Repository Secrets configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION).

### 1. 🌟 One-Click Environment Bootstrapping
Provision the entire underlying infrastructure (VPC, EKS Cluster, ECR Repository, Metrics Server, and Prometheus Stack) in a strict dependency order:

```bash
make deploy-all
```

Note: CloudFormation and Helm orchestration typically take 20-25 minutes. Cloud automation is at work! ☕

### 2. 🚀 Trigger the CI/CD Pipeline (GitHub Actions)
Once the infrastructure and metrics are ready, push your code. GitHub Actions will automatically build the image, push it to ECR, and deploy it to EKS:

```bash
make git-push m="feat: initial application deployment via CI/CD"
```

(If you are reviving an existing repository, simply navigate to the GitHub Actions tab, select the latest workflow run, and click "Re-run all jobs" to deploy the application into the fresh cluster.)

### 3. 🌐 Access the Live Application & Dashboards
Retrieve the public-facing URL of your web application:

```bash
make get-url
```

Retrieve your Grafana admin credentials and the public dashboard URL to view real-time cluster metrics:

```bash
make get-grafana-password
make get-grafana-url
```

> Paste your Grafana URL into the browser and log in:
> - Username: `admin`
> - Password: run `make get-grafana-password` to fetch the current admin password.


### 4. 📈 📊 Monitoring Cluster Health via Grafana
Once logged into Grafana, navigate to these default dashboards to observe your cluster's behavior:

- Kubernetes / Compute Resources / Cluster: Monitor overall CPU and Memory utilization across your EC2 worker nodes.
- Kubernetes / Compute Resources / Namespace (Workloads): Track the real-time Pod count of your sl-cicd-app to verify HPA scaling.
- Alertmanager / Status: View firing alerts (e.g., HighPodCount) being routed to your Telegram bot.

### 5. ⚔️ Stress Testing & Alert Validation
To validate the auto-scaling architecture and the Telegram alerting pipeline, trigger a traffic load using two levels of intensity:

Level 1: Light Stress Test (Single Pod generator):

```bash
make stress-test
```

Level 2: Heavy "Load Army" Test (10-replica concurrent bombardment):

```bash
make start-load-army-test
```

Monitor the reaction:

- Run `make status` to see the HPA triggering Pod scale-ups as CPU load crosses the 50% threshold.
- Check your Telegram for "🚨 EKS Alert: HighPodCount" notifications.
- Stop the heavy test with `make stop-load-army-test`.

### 6. ☢️ Clean Up Resources (Nuclear Option)
To avoid incurring unnecessary AWS charges, tear down the entire application, monitoring stack, ECR, EKS cluster, and VPC networking:

```bash
make destroy-all
```

FinOps Feature: The script intelligently uninstalls Helm charts and releases all AWS LoadBalancers before cluster termination to prevent "orphaned" billing resources.

---

## ☕ Support My Work
If you found this project helpful and want to support my cloud engineering journey, feel free to buy me a coffee!

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-orange?style=for-the-badge&logo=buy-me-a-coffee)](https://www.buymeacoffee.com/shieliang22)

---