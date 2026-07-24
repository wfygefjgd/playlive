#!/bin/bash
# 一键发布脚本 - 在 TVPlayer-iOS 目录下运行
# 用法: ./release.sh v1.4.6

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "用法: ./release.sh v1.4.6"
    exit 1
fi

echo "=== 发布 TVPlayer iOS $VERSION ==="

# 确保在 git 仓库中
if [ ! -d .git ]; then
    echo "错误: 当前目录不是 git 仓库"
    exit 1
fi

# 检查是否有未提交的变更
if ! git diff-index --quiet HEAD --; then
    echo "提交本地变更..."
    git add .
    git commit -m "release: $VERSION"
fi

# 推送代码
echo "推送代码..."
git push origin main

# 创建并推送 tag
echo "创建 tag: $VERSION"
git tag -f "$VERSION"
git push origin "$VERSION" --force

echo ""
echo "=== Tag 已推送，等待 GitHub Actions 构建完成 ==="
echo ""
echo "接下来请手动操作:"
echo "1. 打开 GitHub 仓库 Releases 页面"
echo "2. 找到 '$VERSION' tag 对应的 Release（Actions 构建完成后自动生成）"
echo "3. 编辑 Release 内容，粘贴发布说明"
echo "4. 上传 TVPlayer.ipa 文件"
echo "5. 发布"
echo ""
echo "或者使用 GitHub CLI (gh) 自动创建 Release:"
echo "gh release create $VERSION --title \"TVPlayer iOS $VERSION\" --notes-file RELEASE_NOTES.md"
