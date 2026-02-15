#!/bin/bash

# xiaoyuzhou-podcast skill 安装脚本
# 检查并安装所需依赖

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Python
check_python() {
    echo_info "检查 Python 环境..."

    if ! command -v python3 &> /dev/null; then
        echo_error "未找到 Python 3，请先安装 Python 3.8+"
        exit 1
    fi

    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    echo_info "Python 版本: $PYTHON_VERSION"

    # 检查版本是否 >= 3.8
    MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$MAJOR" -lt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 8 ]); then
        echo_error "Python 版本过低，需要 3.8 或更高版本"
        exit 1
    fi
}

# 检查 pip
check_pip() {
    echo_info "检查 pip..."

    if ! command -v pip3 &> /dev/null; then
        echo_error "未找到 pip3"
        exit 1
    fi

    PIP_VERSION=$(pip3 --version | awk '{print $2}')
    echo_info "pip 版本: $PIP_VERSION"
}

# 检查 PyTorch 和 MPS
check_pytorch() {
    echo_info "检查 PyTorch 和 MPS 支持..."

    if ! python3 -c "import torch" 2>/dev/null; then
        echo_warn "PyTorch 未安装"
        echo_info "正在安装 PyTorch（Metal 加速版）..."
        pip3 install torch torchvision torchaudio
    fi

    TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__)")
    MPS_AVAILABLE=$(python3 -c "import torch; print(torch.backends.mps.is_available())")

    echo_info "PyTorch 版本: $TORCH_VERSION"

    if [ "$MPS_AVAILABLE" = "True" ]; then
        echo_info "MPS (Metal) 加速: 可用 ✓"
    else
        echo_warn "MPS (Metal) 加速: 不可用"
        echo_warn "将使用 CPU 运行，速度较慢"
    fi
}

# 检查 FunASR
check_funasr() {
    echo_info "检查 FunASR..."

    if ! python3 -c "import funasr" 2>/dev/null; then
        echo_warn "FunASR 未安装"
        echo_info "正在安装 FunASR 和 ModelScope..."
        pip3 install funasr modelscope
    fi

    FUNASR_VERSION=$(python3 -c "import funasr; print(funasr.__version__)" 2>/dev/null || echo "未知")
    echo_info "FunASR 版本: $FUNASR_VERSION"
}

# 检查 xyz-dl
check_xyzdl() {
    echo_info "检查 xyz-dl..."

    XYZDL_PATH="$HOME/.claude/tools/xyz-dl"

    if [ ! -d "$XYZDL_PATH" ]; then
        echo_warn "xyz-dl 未安装到 $XYZDL_PATH"
        echo_info "正在克隆 xyz-dl..."
        mkdir -p "$HOME/.claude/tools"
        git clone https://github.com/slarkio/xyz-dl.git "$XYZDL_PATH"

        echo_info "正在安装 xyz-dl 依赖..."
        cd "$XYZDL_PATH"
        if command -v uv &> /dev/null; then
            uv sync
        else
            echo_warn "uv 未安装，尝试使用 pip..."
            pip3 install -e .
        fi
    else
        echo_info "xyz-dl 已安装在 $XYZDL_PATH"
    fi

    # 验证 xyz-dl 可执行
    if [ -d "$XYZDL_PATH/.venv" ]; then
        echo_info "xyz-dl 可用 ✓"
    else
        echo_warn "xyz-dl 虚拟环境不完整，正在重建..."
        cd "$XYZDL_PATH"
        uv sync 2>/dev/null || pip3 install -e .
    fi
}

# 检查模型（可选）
check_models() {
    echo_info "检查 FunASR 模型..."

    MODEL_CACHE="$HOME/.cache/modelscope/hub/iic"

    if [ -d "$MODEL_CACHE" ]; then
        echo_info "模型缓存目录存在"
        echo_info "首次运行转录时会自动下载所需模型（约 2GB）"
    else
        echo_info "模型尚未下载"
        echo_info "首次运行转录时会自动下载模型（约 2GB）"
    fi
}

# 主函数
main() {
    echo "================================"
    echo "小宇宙播客 Skill 安装检查"
    echo "================================"
    echo ""

    check_python
    check_pip
    check_pytorch
    check_funasr
    check_xyzdl
    check_models

    echo ""
    echo "================================"
    echo_info "所有依赖已就绪！"
    echo "================================"
    echo ""
    echo "接下来可以："
    echo "1. 运行下载脚本: scripts/download.sh"
    echo "2. 运行转录脚本: scripts/transcribe.py"
    echo ""
}

main "$@"
