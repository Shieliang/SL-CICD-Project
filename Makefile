# SL-CI/CD-Project 自动化控制台

# 默认使用新加坡区域 (距离近，延迟低)
AWS_REGION ?= us-east-1
# 给我们的网络基础设施起个名字
STACK_NAME_NETWORK ?= sl-cicd-network
# 给我们的 Kubernetes 集群起个名字
STACK_NAME_CLUSTER ?= sl-cicd-cluster
# 给我们的 ECR 镜像仓库起个名字
ECR_REPO_NAME ?= sl-cicd-repo

# 你的 AWS 账号 ID 和完整 ECR 地
AWS_ACCOUNT_ID ?= 987762561422
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME)
IMAGE_TAG ?= v3

.PHONY: deploy-network destroy-network deploy-cluster destroy-cluster deploy-ecr destroy-ecr build-image push-image deploy-app destroy-app deploy-metrics stress-test status git-push

# 一键拉起网络基础设施
deploy-network:
	@echo "🚀 正在 AWS 创建底层网络 (VPC, Subnets)..."
	aws cloudformation deploy \
		--template-file cloudformation/network.yaml \
		--stack-name $(STACK_NAME_NETWORK) \
		--region $(AWS_REGION) \
		--capabilities CAPABILITY_NAMED_IAM
	@echo "✅ 网络基础设施部署完成！"

# 一键销毁网络，杜绝账单刺客
destroy-network:
	@echo "🧹 正在销毁底层网络..."
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME_NETWORK) \
		--region $(AWS_REGION)
	@echo "✅ 网络已彻底销毁！"

# ======== 第二层：Kubernetes 集群 ========
deploy-cluster:
	@echo "🧠 正在 AWS 创建 EKS 集群与 EC2 节点 (约需 15-20 分钟，去喝杯咖啡吧)..."
	aws cloudformation deploy \
		--template-file cloudformation/eks-cluster.yaml \
		--stack-name $(STACK_NAME_CLUSTER) \
		--region $(AWS_REGION) \
		--capabilities CAPABILITY_NAMED_IAM
	@echo "✅ EKS 集群部署完成！"

destroy-cluster:
	@echo "🔥 正在销毁 EKS 集群与 EC2 节点 (防账单刺客第一步)..."
	aws cloudformation delete-stack --stack-name $(STACK_NAME_CLUSTER) --region $(AWS_REGION)
	@echo "✅ EKS 集群已安全销毁！"

# ======== 第三层：镜像仓库 (ECR) ========
deploy-ecr:
	@echo "📦 正在 AWS 创建 ECR 镜像仓库..."
	aws ecr create-repository \
		--repository-name $(ECR_REPO_NAME) \
		--region $(AWS_REGION)
	@echo "✅ ECR 仓库创建完成！"

destroy-ecr:
	@echo "💥 正在销毁 ECR 镜像仓库 (包含内部所有镜像)..."
	aws ecr delete-repository \
		--repository-name $(ECR_REPO_NAME) \
		--region $(AWS_REGION) \
		--force
	@echo "✅ ECR 仓库已彻底销毁！"

# ======== 第四层：构建与推送镜像到 ECR ========
build-image:
	@echo "🔨 正在根据 Dockerfile 构建本地镜像..."
	docker build --no-cache -t sl-cicd-app:$(IMAGE_TAG) app/

push-image: build-image
	@echo "🔐 正在获取 AWS 临时令牌并登录 Docker..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	@echo "🏷️ 正在给本地镜像打上云端专属标签..."
	docker tag sl-cicd-app:$(IMAGE_TAG) $(ECR_URI):$(IMAGE_TAG)
	@echo "🚀 正在发射！推送镜像到 AWS ECR..."
	docker push $(ECR_URI):$(IMAGE_TAG)
	@echo "✅ 镜像推送完成！你的应用已经安全存放在 AWS 云端！"

# ======== 第五层：Kubernetes 应用部署 ========
deploy-app:
	@echo "🚀 正在向 EKS 集群部署应用 (Deployment & Service)..."
	kubectl apply -f k8s/
	@echo "⏳ 正在等待 AWS 分配 LoadBalancer 公网地址 (通常需要 2-3 分钟)..."
	@echo "👉 请运行 'kubectl get svc sl-cicd-service' 来查看你的网站链接 (EXTERNAL-IP)！"

destroy-app:
	@echo "🗑️ 正在从集群中删除应用，并释放 AWS LoadBalancer..."
	kubectl delete -f k8s/
	@echo "✅ 应用已下线，LoadBalancer 正在销毁！"

# ======== 第五层：高阶 K8s 魔法 (HPA 与 监控) ========
deploy-metrics:
	@echo "📡 1/3 正在向集群安装官方 Metrics Server 雷达..."
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	@echo "⏳ 2/3 等待 15 秒让组件初始化..."
	sleep 15
	@echo "💉 3/3 正在注入 '--kubelet-insecure-tls' 证书绕过补丁..."
	kubectl patch deployment metrics-server -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"]}]}}}}'
	@echo "✅ 雷达安装并破解成功！请等待 1 分钟后运行 'make status' 查看 CPU 数据。"

stress-test:
	@echo "⚔️ 警告：正在发动海量流量死循环攻击！"
	@echo "🛑 想要停止攻击，请随时按下键盘的 [Ctrl + C]。"
	kubectl run -i --tty load-generator-heavy --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://sl-cicd-service; done"

status:
	@echo "📊 ====== 当前集群健康大盘 ======"
	@echo "1. 容器状态 (Pods):"
	kubectl get pods
	@echo "\n2. 资源消耗 (Top):"
	kubectl top pods || echo "雷达正在启动中，请稍后再试..."
	@echo "\n3. 自动扩容状态 (HPA):"
	kubectl get hpa
	@echo "================================="

# ======== 第六层：一键代码提交与触发 CI/CD ========
git-push:
	@echo "📦 1/3 正在将所有更改添加到 Git 暂存区..."
	git add .
	@echo "📝 2/3 正在提交代码..."
	@# 这里的逻辑是：如果你传入了 m="xxx"，就用你的，否则用默认的 "Auto commit: trigger CI/CD"
	git commit -m "$(if $(m),$(m),Auto commit: trigger CI/CD pipeline)"
	@echo "🚀 3/3 正在推送到 GitHub，准备触发自动化流水线..."
	git push
	@echo "✅ 推送成功！现在请切到浏览器，去 GitHub Actions 页面看机器人干活吧！"