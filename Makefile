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
# 利用 aws sts 命令动态获取当前环境的 12 位账号 ID，避免硬编码泄露隐私
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME)
IMAGE_TAG ?= v3
-include .env
export

.PHONY: deploy-network destroy-network deploy-cluster destroy-cluster deploy-ecr destroy-ecr build-image push-image deploy-app destroy-app deploy-metrics stress-test status git-push get-url deploy-all destroy-all
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
	@echo "🔗 正在更新本地 kubectl 配置，连接到新生集群..."
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(STACK_NAME_CLUSTER)
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
	@echo "🔄 2/2 正在动态注入你的专属 ECR 镜像地址..."
	kubectl set image deployment/sl-cicd-app web=$(ECR_URI):$(IMAGE_TAG)
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
	kubectl get hpa -w
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

# ======== 第7层：监控体系与告警机器人（Prometheus, Grafana & Telegram） ========

install-helm:
	@echo "📥 正在安装 Helm 包管理器..."
	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	@echo "✅ Helm 安装完成！"

# 添加 Helm 仓库
prep-monitoring:
	@echo "🔄 正在更新 Prometheus Helm 仓库..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

# 一键安装监控全家桶
deploy-monitoring: prep-monitoring
	@echo "📡 正在生成自定义配置文件..."
	@printf "grafana:\n  service:\n    type: LoadBalancer\nadditionalPrometheusRulesMap:\n  custom-rules:\n    groups:\n      - name: PodScalingAlerts\n        rules:\n          - alert: HighPodCount\n            expr: count(kube_pod_info{namespace=\"default\", pod=~\"sl-cicd-app.*\"}) > 3\n            for: 1m\n            labels:\n              severity: warning\n            annotations:\n              summary: \"🚨 EKS Alert\"\n              description: \"High traffic detected!\"\n" > alert-values.yaml
	@echo "📦 正在部署 Prometheus & Grafana..."
	helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace -f alert-values.yaml
	@echo "🛠️ 正在注入 Telegram Secret..."
	@# 检查变量是否存在，如果不存在则报错并停止
	@if [ -z "$(TELEGRAM_BOT_TOKEN)" ] || [ -z "$(TELEGRAM_CHAT_ID)" ]; then \
		echo "❌ 错误: TELEGRAM_BOT_TOKEN 或 TELEGRAM_CHAT_ID 未在 .env 或环境变量中定义！"; \
		exit 1; \
	fi
	@printf "global:\n  resolve_timeout: 5m\nroute:\n  group_by: ['alertname']\n  group_wait: 5s\n  group_interval: 1m\n  repeat_interval: 1h\n  receiver: 'telegram-bot'\nreceivers:\n  - name: 'telegram-bot'\n    telegram_configs:\n      - bot_token: '$(TELEGRAM_BOT_TOKEN)'\n        chat_id: $(TELEGRAM_CHAT_ID)\n        message: \"🚨 警告：AWS EKS 集群高并发，Pod 已扩容！\"\n" > alertmanager.yaml
	kubectl create secret generic alertmanager-prometheus-stack-kube-prom-alertmanager --from-file=alertmanager.yaml -n monitoring --dry-run=client -o yaml | kubectl apply -f -
	@echo "♻️ 重启 Alertmanager..."
	kubectl delete pod -l app.kubernetes.io/name=alertmanager -n monitoring --ignore-not-found=true
	@rm -f alert-values.yaml alertmanager.yaml
	@echo "✅ 部署完毕！"

# 获取 Grafana 登录密码 (默认账号是 admin)
get-grafana-password:
	@echo "🔐 Grafana 默认账号: admin"
	@echo "🔑 初始密码如下:"
	kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# 获取 Grafana 访问链接
get-grafana-url:
	@echo "🖼️ 正在获取 Grafana 仪表盘链接..."
	@URL=$$(kubectl get svc --namespace monitoring prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); \
	echo "👉 http://$$URL"


# ======== 第8层：混沌压测与生命周期管理 (Chaos & Lifecycle) ========

# 🚀 发起高并发压测 (触发 HPA 和 Telegram 告警)
start-load-army-test:
	@echo "⚔️ 正在组建压测大军 (10个并发 Pod 疯狂发包)..."
	kubectl create deployment load-army --image=busybox -- /bin/sh -c "while true; do wget -q -O- http://sl-cicd-service; done" || true
	kubectl scale deployment load-army --replicas=10
	@echo "🔥 火力全开！去盯着你的 Telegram，准备接收警报！"

# 🛑 停止压测
stop-load-army-test:
	@echo "🛡️ 撤退！正在销毁压测大军..."
	kubectl delete deployment load-army --ignore-not-found=true
	@echo "🕊️ 压测已停止，等待 HPA 自动缩容。"

# ======== 获取网站专属链接 ========
get-url:
	@echo "🔍 正在向 AWS 索取你的公网链接..."
	@URL=$$(kubectl get svc sl-cicd-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	if [ -z "$$URL" ]; then \
		echo "⏳ AWS 还在努力分配中 (<pending>)，通常需要 2 分钟，请稍后再试..."; \
	else \
		echo "✅ 网站已上线！直接点击访问 👉 http://$$URL"; \
	fi

# ======== 🌟 终极创世按钮：一键拉起所有底层基础设施 ========
deploy-all:
	@echo "🌟 开始执行创世程序：一键拉起完整生产环境！"
	@echo "⏳ 预计耗时 20-25 分钟，请耐心等待..."
	$(MAKE) deploy-network
	$(MAKE) deploy-cluster
	$(MAKE) deploy-ecr
	$(MAKE) deploy-metrics
	$(MAKE) deploy-monitoring
	@echo "🎉 创世成功！网络、集群、ECR 车库和监控雷达已全部就绪！"
	@echo "👉 下一步：修改你的代码，然后运行 'make git-push' 交给机器人部署应用吧！"

# ======== ☢️ 终极核弹按钮：一键彻底销毁所有资源 ========
destroy-all:
	@echo "🚨 警告：正在执行核弹级销毁程序！所有资源将灰飞烟灭！"
	
	@echo "🛑 0/5 正在撤退压测大军 (清理残余负载)..."
	-$(MAKE) stop-load-army-test || true

	@echo "🗑️ 1/5 正在卸载监控大盘 (释放 Grafana 占用的 LoadBalancer)..."
	-helm uninstall prometheus-stack -n monitoring || true
	-kubectl delete svc -l release=prometheus-stack -n monitoring --ignore-not-found=true
	-kubectl delete namespace monitoring --ignore-not-found=true

	@echo "🗑️ 2/5 正在下线 Kubernetes 业务应用并清理 LB..."
	-kubectl delete -f k8s/ --ignore-not-found=true || true
	# 强行清理所有遗留的 LoadBalancer Service，这是省钱的关键
	-kubectl delete svc --all --all-namespaces --field-selector type=LoadBalancer || true

	@echo "💥 3/5 正在销毁 ECR 镜像仓库 (静默模式)..."
	-aws ecr delete-repository --repository-name $(ECR_REPO_NAME) --region $(AWS_REGION) --force > /dev/null 2>&1 || true
	@echo "✅ ECR 仓库已标记删除。"

	@echo "🔥 4/5 正在触发 EKS 集群销毁 (耗时 15-20 分钟)..."
	-aws cloudformation delete-stack --stack-name $(STACK_NAME_CLUSTER) --region $(AWS_REGION)
	@echo "⏳ 正在监控集群销毁状态，请勿中断终端..."
	-aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME_CLUSTER) --region $(AWS_REGION)

	@echo "🌪️ 5/5 集群已阵亡，正在销毁底层网络 (VPC, Subnets)..."
	-aws cloudformation delete-stack --stack-name $(STACK_NAME_NETWORK) --region $(AWS_REGION)
	@echo "⏳ 正在监控网络销毁状态..."
	-aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME_NETWORK) --region $(AWS_REGION)

	@echo "✅ 核弹打击完毕！所有云端资源已彻底清空，你的钱包现在 100% 安全！💸"