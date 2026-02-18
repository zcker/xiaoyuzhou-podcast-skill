#!/bin/bash

# 合并 Show Notes 和转录文本，并清理临时文件

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 合并文档
merge_documents() {
    local episode_dir="$1"
    local cache_dir="$episode_dir/.cache"
    local output_file="$episode_dir/README.md"

    # 查找 Show Notes 文件
    local show_notes=$(find "$cache_dir" -name "*.md" | head -1)

    if [ -z "$show_notes" ]; then
        echo_error "未找到 Show Notes 文件"
        exit 1
    fi

    # 查找转录文本文件
    local transcript=$(find "$cache_dir" -name "*.txt" ! -name "*_timestamp.txt" | head -1)

    if [ -z "$transcript" ]; then
        echo_warn "未找到转录文本，仅复制 Show Notes"
        cp "$show_notes" "$output_file"
        return
    fi

    echo_info "正在合并文档..."
    echo_info "Show Notes: $show_notes"
    echo_info "转录文本: $transcript"
    echo_info "输出文件: $output_file"

    # 创建合并后的文档
    {
        # 复制 Show Notes（包含元数据）
        cat "$show_notes"

        # 添加分隔符和转录文本
        echo ""
        echo "---"
        echo ""
        echo "# 完整转录文本"
        echo ""
        echo "<!-- 使用 FunASR paraformer-zh 自动生成 -->"
        echo ""
        cat "$transcript"
    } > "$output_file"

    echo_info "文档合并完成！"

    # 显示统计信息
    local word_count=$(wc -m < "$transcript" | xargs)
    echo_info "转录文本字数: $word_count"
}

# 清理临时文件
cleanup_cache() {
    local cache_dir="$1"

    echo_info "正在清理临时文件..."

    # 删除整个 .cache 目录
    if [ -d "$cache_dir" ]; then
        rm -rf "$cache_dir"
        echo_info "缓存目录已完全删除: $cache_dir"
        echo_info "已节省音频和临时文件占用空间"
    else
        echo_info "缓存目录不存在，无需清理"
    fi
}

# 主函数
main() {
    if [ $# -lt 1 ]; then
        echo "用法: $0 <Episode ID 或 目录路径>"
        echo ""
        echo "示例:"
        echo "  $0 6942f3e852d4707aaa1feba3"
        echo "  $0 ~/Podcasts/xiaoyuzhou/E080-稳定币与RWA-虚实之间True Imagination-20250716"
        exit 1
    fi

    INPUT="$1"

    # 判断输入是目录路径还是 Episode ID
    if [ -d "$INPUT" ]; then
        EPISODE_DIR="$INPUT"
    else
        EPISODE_ID="$INPUT"
        # 尝试用 ID 查找目录（可能是新命名格式）
        EPISODE_DIR=$(find "$HOME/Documents/Podcasts" -maxdepth 1 -type d -name "*$EPISODE_ID*" 2>/dev/null | head -1)

        if [ -z "$EPISODE_DIR" ]; then
            # 回退到旧格式（兼容）
            EPISODE_DIR="$HOME/Documents/Podcasts/$EPISODE_ID"
        fi
    fi

    CACHE_DIR="$EPISODE_DIR/.cache"

    if [ ! -d "$EPISODE_DIR" ]; then
        echo_error "播客目录不存在: $EPISODE_DIR"
        exit 1
    fi

    if [ ! -d "$CACHE_DIR" ]; then
        echo_error "缓存目录不存在: $CACHE_DIR"
        exit 1
    fi

    echo "================================"
    echo "文档合并与清理"
    echo "================================"
    echo ""
    echo "播客目录: $EPISODE_DIR"
    echo ""

    # 合并文档
    merge_documents "$EPISODE_DIR"

    # 清理临时文件
    cleanup_cache "$CACHE_DIR"

    echo ""
    echo "================================"
    echo_info "处理完成！"
    echo "================================"
    echo ""
    echo_info "最终文档: $EPISODE_DIR/README.md"
    echo ""

    # 显示文件大小
    ls -lh "$EPISODE_DIR/README.md"
}

main "$@"
