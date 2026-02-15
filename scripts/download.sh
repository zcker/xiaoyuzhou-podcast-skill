#!/bin/bash

# 小宇宙播客下载脚本
# 下载音频和 Show Notes 到临时缓存目录

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_usage() {
    echo "用法: $0 <URL 或 Episode ID> [输出根目录]"
    echo ""
    echo "示例:"
    echo "  $0 https://www.xiaoyuzhoufm.com/episode/6942f3e852d4707aaa1feba3"
    echo "  $0 6942f3e852d4707aaa1feba3"
    echo "  $0 6942f3e852d4707aaa1feba3 ~/MyPodcasts"
    echo ""
    exit 1
}

# 解析URL或ID
parse_input() {
    local input="$1"

    # 如果是完整 URL
    if [[ "$input" =~ ^https?:// ]]; then
        # 提取 episode ID
        EPISODE_ID=$(echo "$input" | grep -oE '[0-9a-f]{24}' | head -1)
        URL="$input"
    else
        # 假设是 episode ID
        if [[ ! "$input" =~ ^[0-9a-f]{24}$ ]]; then
            echo_error "无效的 Episode ID，需要 24 位十六进制字符"
            echo_usage
        fi
        EPISODE_ID="$input"
        URL="https://www.xiaoyuzhoufm.com/episode/$EPISODE_ID"
    fi
}

# 检查 xyz-dl
check_xyzdl() {
    XYZDL_PATH="$HOME/.claude/tools/xyz-dl"

    if [ ! -d "$XYZDL_PATH" ]; then
        echo_error "xyz-dl 未安装"
        echo_info "请先运行: scripts/install.sh"
        exit 1
    fi

    if [ ! -d "$XYZDL_PATH/.venv" ]; then
        echo_error "xyz-dl 虚拟环境不完整"
        echo_info "请先运行: scripts/install.sh"
        exit 1
    fi
}

# 下载播客
download_podcast() {
    local url="$1"
    local cache_dir="$2"

    echo_info "正在下载播客..."
    echo_info "URL: $url"
    echo_info "临时缓存: $cache_dir"
    echo ""

    # 调用 xyz-dl，下载到缓存目录
    cd "$XYZDL_PATH"
    uv run xyz-dl --mode both --dir "$cache_dir" "$url"

    # 检查下载结果
    echo ""
    echo_info "下载完成！"

    # 查找下载的文件
    echo_info "文件列表:"
    ls -lh "$cache_dir"/ | grep -E '\.(md|m4a|mp3)$' || true
}

# 主函数
main() {
    if [ $# -lt 1 ]; then
        echo_usage
    fi

    INPUT="$1"
    OUTPUT_ROOT="${2:-$HOME/Podcasts/xiaoyuzhou}"

    parse_input "$INPUT"

    # 新的目录结构：每个 episode 一个文件夹
    EPISODE_DIR="$OUTPUT_ROOT/$EPISODE_ID"
    CACHE_DIR="$EPISODE_DIR/.cache"

    echo "================================"
    echo "小宇宙播客下载器"
    echo "================================"
    echo ""
    echo "Episode ID: $EPISODE_ID"
    echo "URL: $URL"
    echo "播客目录: $EPISODE_DIR"
    echo "缓存目录: $CACHE_DIR"
    echo ""

    check_xyzdl

    # 创建目录结构
    mkdir -p "$CACHE_DIR"

    download_podcast "$URL" "$CACHE_DIR"

    # 查找下载的音频文件
    AUDIO_FILE=$(find "$CACHE_DIR" -name "*.m4a" -o -name "*.mp3" | head -1)

    echo ""
    echo_info "下载完成！"
    echo_info "音频文件: $AUDIO_FILE"
    echo ""
    echo_info "下一步: 运行转录脚本"
    echo "  python3 ~/.claude/skills/xiaoyuzhou-podcast/scripts/transcribe.py --audio \"$AUDIO_FILE\""
    echo ""
    echo_info "或者运行完整流程脚本（转录 + 合并 + 清理）："
    echo "  ~/.claude/skills/xiaoyuzhou-podcast/scripts/process-podcast.sh $EPISODE_ID"
}

main "$@"
