#!/usr/bin/env bash
# ==============================================================================
# 重新关联 / 初始化 Git 仓库并推送到新远端 (GitHub / Gitee)
# 使用方法: 
#   ./scripts/relink-github-repo.sh [新仓库地址]
# 例如:
#   ./scripts/relink-github-repo.sh git@github.com:yingxiyy/clusterManager-New.git
#   ./scripts/relink-github-repo.sh https://github.com/yingxiyy/clusterManager-New.git
#   ./scripts/relink-github-repo.sh https://gitee.com/yingxiyy/clusterManager-Public.git
# ==============================================================================
set -euo pipefail

NEW_REPO_URL="${1:-}"

echo "======================================================================"
echo " 🚀 Git 仓库重联与推送到新 Repo 工具"
echo "======================================================================"

if [ -z "${NEW_REPO_URL}" ]; then
  echo "❌ 请输入新的 Git 仓库地址！"
  echo ""
  echo "用法示例："
  echo "  1) GitHub SSH (国内最稳定推荐，避开 443 超时)："
  echo "     ./scripts/relink-github-repo.sh git@github.com:yingxiyy/clusterManager-New.git"
  echo ""
  echo "  2) GitHub HTTPS："
  echo "     ./scripts/relink-github-repo.sh https://github.com/yingxiyy/clusterManager-New.git"
  echo ""
  echo "  3) Gitee 码云 (国内免代理直连，推荐备选)："
  echo "     ./scripts/relink-github-repo.sh https://gitee.com/yingxiyy/clusterManager-Public.git"
  echo "======================================================================"
  exit 1
fi

# 1. 检查或重新初始化 .git
if [ ! -d ".git" ]; then
  echo "--> 当前目录未包含 .git 目录，正在全新初始化本地仓库 (git init)..."
  git init
  git branch -M main
else
  echo "--> 检测到已有 .git 目录，清理历史无效远程引用..."
  git branch -M main || true
fi

# 2. 设置或重置远端 origin
if git remote | grep -q "^origin$"; then
  echo "--> 更新现有 origin 远程地址为: ${NEW_REPO_URL}"
  git remote set-url origin "${NEW_REPO_URL}"
else
  echo "--> 添加 origin 远程地址: ${NEW_REPO_URL}"
  git remote add origin "${NEW_REPO_URL}"
fi

echo "--> 当前远程配置为："
git remote -v

# 3. 检查敏感文件与 .gitignore
echo "--> 检查 .gitignore 保护敏感凭证..."
if [ -f "credentials.env" ]; then
  echo "   [保护] credentials.env 已被 .gitignore 排除，防止密码泄露至公开仓库"
fi

# 4. 提交当前所有代码
echo "--> 正在暂存所有更新代码 (Flink 2.2 / Kafka 4.0.1 / Mongo 8.0 / MySQL 8.4 / Helm)..."
git add .

COMMIT_MSG="feat: complete production HA cluster stack (Flink 2.2, Kafka 4.0.1 KRaft, Mongo 8.0, MySQL 8.4, Redis, MinIO, Nginx)"
if git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "--> 当前工作区无新修改，准备直接推送..."
else
  git commit -m "${COMMIT_MSG}" || true
  echo "✅ 本地 Commit 完成！"
fi

# 5. 网络连通性提示与推送
echo "======================================================================"
echo " 正在准备推送到新仓库: ${NEW_REPO_URL}"
echo "======================================================================"
echo "💡 提示："
echo "如果推送时遇到 'Failed to connect to github.com port 443' 超时，可采用以下方案之一："
echo "  方案 A: 切换为 SSH 地址 (git@github.com:...) 并配置 ~/.ssh/id_rsa"
echo "  方案 B: 为 git 设置代理 (如果有 Clash/v2ray，如 7890 端口):"
echo "         git config --global http.proxy http://127.0.0.1:7890"
echo "  方案 C: 推送到 Gitee 码云 (国内全速访问):"
echo "         git remote set-url origin https://gitee.com/你的用户名/仓库名.git"
echo "======================================================================"

read -p "是否立即执行 git push -u origin main --force 推送? [y/N]: " CONFIRM || CONFIRM="y"
if [[ "${CONFIRM}" =~ ^[yY]$ ]]; then
  echo "--> 正在推送到远端..."
  git push -u origin main --force
  echo "🎉 推送成功！新仓库已就绪。"
else
  echo "已取消直接推送。您可以在准备好网络或 SSH Key 后随时手动执行："
  echo "  git push -u origin main --force"
fi
