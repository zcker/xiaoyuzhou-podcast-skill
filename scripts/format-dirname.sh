#!/bin/bash

# 格式化播客目录名：序号-主题-节目名-日期

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 从 Markdown 文件的 YAML front matter 中提取元数据
extract_metadata() {
    local md_file="$1"

    if [ ! -f "$md_file" ]; then
        echo_error "文件不存在: $md_file"
        exit 1
    fi

    # 提取各个字段
    TITLE=$(grep '^title:' "$md_file" | sed 's/title: *//' | sed 's/^"//;s/"$//')
    PODCAST_NAME=$(grep '^podcast_name:' "$md_file" | sed 's/podcast_name: *//' | sed 's/^"//;s/"$//')
    PUBLISHED_DATE=$(grep '^published_date:' "$md_file" | sed 's/published_date: *//')

    # 解析标题提取序号和主题
    # 例如: "E080 稳定币与RWA：里世界向你敞开的一角"
    # 序号: E080
    # 主题: 稳定币与RWA

    EPISODE_NUMBER=$(echo "$TITLE" | grep -oE '^[A-Z]?[0-9]+' | head -1)

    # 提取主题（序号后的第一个冒号或空格前的内容）
    TOPIC=$(echo "$TITLE" | sed "s/^${EPISODE_NUMBER} //" | sed 's/：.*//' | sed 's/:.*//' | sed 's/ /-/g')

    # 格式化日期（从 "2025年07月16日" 到 "20250716"）
    FORMATTED_DATE=$(echo "$PUBLISHED_DATE" | grep -oE '[0-9]{4}年[0-9]{2}月[0-9]{2}日' | sed 's/年//;s/月//;s/日//')

    # 清理节目名中的特殊字符
    CLEAN_PODCAST_NAME=$(echo "$PODCAST_NAME" | sed 's/ /-/g' | sed 's/[():]//g')

    # 生成目录名
    if [ -n "$EPISODE_NUMBER" ] && [ -n "$TOPIC" ]; then
        NEW_DIR_NAME="${EPISODE_NUMBER}-${TOPIC}-${CLEAN_PODCAST_NAME}-${FORMATTED_DATE}"
    else
        # 如果无法提取序号和主题，使用原标题
        CLEAN_TITLE=$(echo "$TITLE" | sed 's/ /-/g' | sed 's/[():]//g')
        NEW_DIR_NAME="${CLEAN_TITLE}-${FORMATTED_DATE}"
    fi

    echo "$NEW_DIR_NAME"
}

# 主函数
main() {
    if [ $# -lt 2 ]; then
        echo "用法: $0 <episode_id> <show_notes.md>"
        echo ""
        echo "示例:"
        echo "  $0 6875107a93fd2d72b828e3e1 ~/Podcasts/xiaoyuzhou/6875107a93fd2d72b828e3e1/.cache/show_notes.md"
        exit 1
    fi

    local episode_id="$1"
    local show_notes="$2"

    echo_info "正在解析元数据..." >&2
    NEW_DIR_NAME=$(extract_metadata "$show_notes")

    echo_info "新目录名: $NEW_DIR_NAME" >&2

    # 只输出目录名（供其他脚本使用）
    echo "$NEW_DIR_NAME"
}

# 如果直接调用此脚本，执行main函数
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
