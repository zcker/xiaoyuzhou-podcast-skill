#!/bin/bash

# 完整播客处理流程：下载 → 转录 → 合并 → 清理 → (可选) 同步到 Notion

set -e

SCRIPTS_DIR="$HOME/.claude/skills/xiaoyuzhou-podcast/scripts"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_step() {
    echo -e "${BLUE}==>${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 错误处理
error_handler() {
    echo ""
    echo "[ERROR] 处理过程中出现错误"
    echo "[INFO] 请检查上面的错误信息"
    exit 1
}

trap error_handler ERR

# 主函数
main() {
    local sync_to_notion=false
    local notion_token=""
    local database_id=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --notion)
                sync_to_notion=true
                shift
                ;;
            --token)
                notion_token="$2"
                shift 2
                ;;
            --database-id)
                database_id="$2"
                shift 2
                ;;
            -*)
                echo "未知选项: $1"
                exit 1
                ;;
            *)
                INPUT="$1"
                shift
                ;;
        esac
    done

    if [ -z "$INPUT" ]; then
        echo "用法: $0 <URL 或 Episode ID> [--notion] [--token NOTION_TOKEN] [--database-id DATABASE_ID]"
        echo ""
        echo "选项:"
        echo "  --notion          同步到 Notion（需要 --token 和 --database-id）"
        echo "  --token           Notion Integration Token"
        echo "  --database-id     Notion Database ID"
        echo ""
        echo "示例:"
        echo "  # 基本用法"
        echo "  $0 https://www.xiaoyuzhoufm.com/episode/6942f3e852d4707aaa1feba3"
        echo ""
        echo "  # 同步到 Notion"
        echo "  $0 6942f3e852d4707aaa1feba3 --notion --token \$NOTION_TOKEN --database-id \$NOTION_DATABASE_ID"
        exit 1
    fi

    local total_steps=4
    if [ "$sync_to_notion" = true ]; then
        total_steps=5
    fi

    echo "========================================"
    echo "小宇宙播客完整处理流程"
    echo "========================================"
    echo ""

    # 解析输入：可以是目录路径、URL 或 Episode ID
    if [ -d "$INPUT" ]; then
        # 输入是目录路径
        EPISODE_DIR="$INPUT"
        CACHE_DIR="$EPISODE_DIR/.cache"
    else
        # 输入是 URL 或 Episode ID，需要先下载
        echo_step "步骤 1/$total_steps: 下载音频和 Show Notes"

        # 调用 download.sh
        DOWNLOAD_OUTPUT=$("$SCRIPTS_DIR/download.sh" "$INPUT" 2>&1)
        DOWNLOAD_EXIT_CODE=$?

        if [ $DOWNLOAD_EXIT_CODE -ne 0 ]; then
            echo_warn "下载步骤出现问题，但继续执行..."
        fi

        # 从输出中提取目录路径（格式：===EPISODE_DIR:/path/to/dir===）
        EPISODE_DIR=$(echo "$DOWNLOAD_OUTPUT" | grep "===EPISODE_DIR:" | sed 's/===EPISODE_DIR:\(.*\)===/\1/')

        if [ -z "$EPISODE_DIR" ] || [ ! -d "$EPISODE_DIR" ]; then
            echo "[ERROR] 未找到播客目录"
            echo "[DEBUG] Download output: $DOWNLOAD_OUTPUT"
            exit 1
        fi

        CACHE_DIR="$EPISODE_DIR/.cache"

        echo ""
        echo "下载完成，目录: $EPISODE_DIR"
    fi

    # 查找音频文件
    AUDIO_FILE=$(find "$CACHE_DIR" -name "*.m4a" -o -name "*.mp3" 2>/dev/null | head -1)

    if [ -z "$AUDIO_FILE" ]; then
        echo "[ERROR] 未找到音频文件"
        echo "[INFO] 检查缓存目录: $CACHE_DIR"
        ls -la "$CACHE_DIR" 2>/dev/null || echo "[INFO] 缓存目录不存在"
        exit 1
    fi

    echo ""

    # 步骤 2: 转录
    echo_step "步骤 2/$total_steps: ASR 转录音频（增强版：说话人识别 + 智能分段）"
    if ! python3 "$SCRIPTS_DIR/transcribe_enhanced.py" --audio "$AUDIO_FILE"; then
        echo "[ERROR] 转录失败"
        exit 1
    fi

    echo ""

    # 步骤 3: 合并
    echo_step "步骤 3/$total_steps: 合并 Show Notes 和转录文本"
    if ! "$SCRIPTS_DIR/merge-and-clean.sh" "$EPISODE_DIR"; then
        echo_warn "合并步骤出现问题..."
    fi

    echo ""

    FINAL_FILE="$EPISODE_DIR/README.md"

    # 步骤 4: Notion 同步（可选）
    if [ "$sync_to_notion" = true ]; then
        echo_step "步骤 4/$total_steps: 同步到 Notion"

        # 检查 notion-client 是否安装
        if ! python3 -c "import notion_client" 2>/dev/null; then
            echo_warn "notion-client 未安装，正在安装..."
            pip3 install notion-client
        fi

        # 检查参数
        if [ -z "$notion_token" ]; then
            notion_token="${NOTION_TOKEN:-}"
        fi
        if [ -z "$database_id" ]; then
            database_id="${NOTION_DATABASE_ID:-}"
        fi

        if [ -z "$notion_token" ] || [ -z "$database_id" ]; then
            echo_warn "缺少 Notion 配置，跳过同步"
            echo "[INFO] 请设置 --token 和 --database-id 参数"
            echo "[INFO] 或设置环境变量 NOTION_TOKEN 和 NOTION_DATABASE_ID"
        else
            if ! python3 "$SCRIPTS_DIR/sync-to-notion.py" \
                --file "$FINAL_FILE" \
                --token "$notion_token" \
                --database-id "$database_id"; then
                echo_warn "Notion 同步失败，但本地文件已保存"
            fi
        fi

        echo ""
    fi

    # 步骤 5/4: 完成
    echo_step "步骤 $total_steps/$total_steps: 处理完成"

    echo ""
    echo "========================================"
    echo -e "${GREEN}[SUCCESS] 播客处理完成！${NC}"
    echo "========================================"
    echo ""
    echo "最终文档: $FINAL_FILE"

    # 显示文件大小
    if [ -f "$FINAL_FILE" ]; then
        local file_size=$(du -h "$FINAL_FILE" | cut -f1)
        echo "文件大小: $file_size"
    fi

    echo ""
    echo "文档内容预览："
    echo "----------------------------------------"
    head -30 "$FINAL_FILE"
    echo "..."
    echo "----------------------------------------"
    echo ""
    echo "查看完整文档:"
    echo "  cat \"$FINAL_FILE\""
    echo ""
    echo "在编辑器中打开:"
    echo "  open -a \"Visual Studio Code\" \"$FINAL_FILE\""
}

main "$@"
