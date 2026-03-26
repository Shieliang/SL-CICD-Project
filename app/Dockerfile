# 1. 使用轻量级的 Nginx 官方镜像作为基础环境 (alpine 版本体积超小)
FROM nginx:alpine

# 🛡️ 安全补丁：修复 AWS Inspector 扫描出的 zlib 高危漏洞
RUN apk update && apk upgrade --no-cache zlib && rm -rf /var/cache/apk/*

# 2. 把我们刚才写的网页，复制到 Nginx 默认存放网页的目录里
COPY index.html /usr/share/nginx/html/

# 3. 声明这个容器在运行时将使用 80 端口 (标准的 HTTP 网页端口)
EXPOSE 80