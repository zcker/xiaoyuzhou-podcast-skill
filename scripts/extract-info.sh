#!/bin/bash

# 整合 Show Notes 元数据和转录文字稿
# 输出结构化信息

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 解析 Show Notes 的 YAML Front Matter
parse_show_notes() {
    local md_file="$1"

    if [ ! -f "$md_file" ]; then
        echo_error "Show Notes 文件不存在: $md_file"
        exit 1
    fi

    # 提取 YAML Front Matter
    local in_front_matter=0
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if [ $in_front_matter -eq 0 ]; then
                in_front_matter=1
                continue
            else
                break
            fi
        fi

        if [ $in_front_matter -eq 1 ]; then
            # 解析键值对
            key=$(echo "$line" | cut -d: -f1 | xargs)
            value=$(echo "$line" | cut -d: -f2- | xargs)

            case "$key" in
                title) TITLE="$value" ;;
                podcast_name) PODCAST_NAME="$value" ;;
                duration_text) DURATION="$value" ;;
                audio_url) AUDIO_URL="$value" ;;
                url) EPISODE_URL="$value" ;;
                published_date) PUBLISHED_DATE="$value" ;;
                episode_id) EPISODE_ID="$value" ;;
            esac
        fi
    done < "$md_file"
}

# 输出结构化信息
output_info() {
    local transcript_file="$1"

    echo "================================"
    echo "播客信息汇总"
    echo "================================"
    echo ""

    echo "【基础信息】"
    echo "标题: $TITLE"
    echo "主播: $PODCAST_NAME"
    echo "时长: $DURATION"
    echo "发布日期: $PUBLISHED_DATE"
    echo ""

    echo "【链接信息】"
    echo "节目链接: $EPISODE_URL"
    echo "音频链接: $AUDIO_URL"
    echo ""

    echo "【文件信息】"
    echo "Episode ID: $EPISODE_ID"
    echo "Show Notes: $SHOW_NOTES_PATH"
    echo "音频文件: $AUDIO_PATH"
    echo "文字稿: $transcript_file"
    echo ""

    # 如果转录文件存在，显示统计
    if [ -f "$transcript_file" ]; then
        local word_count=$(wc -m < "$transcript_file" | xargs)
        echo "【转录统计】"
        echo "文字数量: $word_count"
        echo ""

        # 显示预览
        echo "【文字稿预览】(前 200 字)"
        echo "----------------------------------------"
        head -c 200 "$transcript_file"
        echo "..."
        echo "----------------------------------------"
        echo ""
    fi
}

# 主函数
main() {
    if [ $# -lt 1 ]; then
        echo "用法: $0 <Episode ID 或 Show Notes 文件路径>"
        echo ""
        echo "示例:"
        echo "  $0 6942f3e852d4707aaa1feba3"
        echo "  $0 ~/Podcasts/xiaoyuzhou/6942f3e852d4707aaa1feba3_播客名.md"
        exit 1
    fi

    INPUT="$1"

    # 判断输入类型
    if [[ "$INPUT" =~ ^[0-9a-f]{24}$ ]]; then
        # Episode ID
        EPISODE_ID="$INPUT"
        # 查找文件
        SHOW_NOTES_PATH=$(find ~/Podcasts/xiaoyuzhou -name "${EPISODE_ID}_*.md" | head -1)
        if [ -z "$SHOW_NOTES_PATH" ]; then
            echo_error "未找到 Episode ID 为 $EPISODE_ID 的 Show Notes 文件"
            exit 1
        fi
    else
        # 文件路径
        SHOW_NOTES_PATH="$INPUT"
    fi

    # 解析 Show Notes
    parse_show_notes "$SHOW_NOTES_PATH"

    # 推断相关文件路径
    BASE_DIR=$(dirname "$SHOW_NOTES_PATH")
    BASENAME=$(basename "$SHOW_NOTES_PATH" .md)

    AUDIO_PATH="$BASE_DIR/audio/${BASENAME}.m4a"
    TRANSCRIPT_PATH="$BASE_DIR/transcripts/${BASENAME}.txt"

    # 输出信息
    output_info "$TRANSCRIPT_PATH"
}

main "$@"
