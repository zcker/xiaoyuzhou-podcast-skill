#!/bin/bash

# 完整播客处理流程：下载 → 转录 → 合并 → 清理

set -e

SCRIPTS_DIR="$HOME/.claude/skills/xiaoyuzhou-podcast/scripts"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_step() {
    echo -e "${BLUE}==>${NC} $1"
}

# 主函数
main() {
    if [ $# -lt 1 ]; then
        echo "用法: $0 <URL 或 Episode ID>"
        echo ""
        echo "示例:"
        echo "  $0 https://www.xiaoyuzhoufm.com/episode/6942f3e852d4707aaa1feba3"
        echo "  $0 6942f3e852d4707aaa1feba3"
        exit 1
    fi

    INPUT="$1"

    echo "========================================"
    echo "小宇宙播客完整处理流程"
    echo "========================================"
    echo ""

    # 步骤 1: 下载
    echo_step "步骤 1/4: 下载音频和 Show Notes"
    "$SCRIPTS_DIR/download.sh" "$INPUT"

    # 提取 Episode ID
    if [[ "$INPUT" =~ ^https?:// ]]; then
        EPISODE_ID=$(echo "$INPUT" | grep -oE '[0-9a-f]{24}' | head -1)
    else
        EPISODE_ID="$INPUT"
    fi

    CACHE_DIR="$HOME/Podcasts/xiaoyuzhou/$EPISODE_ID/.cache"

    # 查找音频文件
    AUDIO_FILE=$(find "$CACHE_DIR" -name "*.m4a" -o -name "*.mp3" | head -1)

    if [ -z "$AUDIO_FILE" ]; then
        echo "[ERROR] 未找到音频文件"
        exit 1
    fi

    echo ""

    # 步骤 2: 转录
    echo_step "步骤 2/4: ASR 转录音频"
    python3 "$SCRIPTS_DIR/transcribe.py" --audio "$AUDIO_FILE"

    echo ""

    # 步骤 3: 合并
    echo_step "步骤 3/4: 合并 Show Notes 和转录文本"
    "$SCRIPTS_DIR/merge-and-clean.sh" "$EPISODE_ID"

    echo ""

    # 步骤 4: 完成
    echo_step "步骤 4/4: 处理完成"
    FINAL_FILE="$HOME/Podcasts/xiaoyuzhou/$EPISODE_ID/README.md"

    echo ""
    echo "========================================"
    echo -e "${GREEN}[SUCCESS] 播客处理完成！${NC}"
    echo "========================================"
    echo ""
    echo "最终文档: $FINAL_FILE"
    echo ""
    echo "文档内容预览："
    head -30 "$FINAL_FILE"
    echo "..."
}

main "$@"
