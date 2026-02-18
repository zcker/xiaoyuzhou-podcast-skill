#!/bin/bash

# 迁移脚本：从 ~/Podcasts/xiaoyuzhou 迁移到 ~/Documents/Podcasts

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_step() {
    echo -e "${BLUE}==>${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

OLD_DIR="$HOME/Podcasts/xiaoyuzhou"
NEW_DIR="$HOME/Documents/Podcasts"

# 检查旧目录是否存在
if [ ! -d "$OLD_DIR" ]; then
    echo "旧目录不存在，无需迁移: $OLD_DIR"
    exit 0
fi

# 创建新目录
mkdir -p "$NEW_DIR"

echo "================================"
echo "播客目录迁移"
echo "================================"
echo ""
echo "从: $OLD_DIR"
echo "到: $NEW_DIR"
echo ""

# 统计文件数量
podcast_count=$(find "$OLD_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | xargs)
echo_step "找到 $podcast_count 个播客目录"
echo ""

# 询问用户确认
read -p "是否继续迁移？(y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消迁移"
    exit 0
fi

# 迁移每个播客目录
for podcast_dir in "$OLD_DIR"/*/; do
    if [ -d "$podcast_dir" ]; then
        podcast_name=$(basename "$podcast_dir")
        echo_step "正在迁移: $podcast_name"

        # 移动目录
        mv "$podcast_dir" "$NEW_DIR/$podcast_name"
    fi
done

echo ""
echo_success "迁移完成！"
echo ""

# 询问是否删除旧目录
read -p "是否删除旧目录？(y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$OLD_DIR"
    echo_success "旧目录已删除: $OLD_DIR"
else
    echo_warn "旧目录保留: $OLD_DIR"
fi

echo ""
echo "新目录位置: $NEW_DIR"
ls -la "$NEW_DIR" | head -10
