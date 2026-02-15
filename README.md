# Xiaoyuzhou Podcast Skill

自动下载小宇宙播客音频并生成完整转录文本的 Claude Code Skill。

## 功能特性

- 自动下载小宇宙播客音频和节目信息
- 使用 FunASR paraformer-zh 进行高质量中文语音识别
- Mac MPS (Metal) 加速，转录速度快 2-3 倍
- 自动合并 Show Notes 和完整转录文本
- 智能清理临时文件，节省存储空间
- 支持热词优化特定术语识别

## 安装

### 前置要求

- macOS (推荐 M1/M2/M3 芯片)
- Python 3.8+
- 约需 2GB 磁盘空间（用于 ASR 模型）

### 安装步骤

运行安装脚本检查并安装所有依赖：

```bash
~/.claude/skills/xiaoyuzhou-podcast/scripts/install.sh
```

安装脚本会自动：
1. 检测 Python 环境
2. 安装 PyTorch (Metal 加速版)
3. 安装 FunASR 和 ModelScope
4. 安装 xyz-dl 下载工具

## 快速开始

### 一键处理（推荐）

```bash
~/.claude/skills/xiaoyuzhou-podcast/scripts/process-podcast.sh <播客链接或ID>
```

示例：
```bash
# 使用完整 URL
~/.claude/skills/xiaoyuzhou-podcast/scripts/process-podcast.sh \
  https://www.xiaoyuzhoufm.com/episode/6942f3e852d4707aaa1feba3

# 使用 Episode ID
~/.claude/skills/xiaoyuzhou-podcast/scripts/process-podcast.sh 6942f3e852d4707aaa1feba3
```

完整流程会：
1. 下载音频和 Show Notes
2. ASR 转录音频
3. 合并文本到 README.md
4. 自动清理临时文件

### 分步操作

如果需要更细粒度的控制：

```bash
# 步骤 1: 下载
~/.claude/skills/xiaoyuzhou-podcast/scripts/download.sh <URL或ID>

# 步骤 2: 转录
python3 ~/.claude/skills/xiaoyuzhou-podcast/scripts/transcribe.py \
  --audio ~/Podcasts/xiaoyuzhou/<ID>/.cache/audio.m4a

# 步骤 3: 合并和清理
~/.claude/skills/xiaoyuzhou-podcast/scripts/merge-and-clean.sh <ID>
```

## 输出结构

### 文件组织

```
~/Podcasts/xiaoyuzhou/
└── {episode_id}/
    └── README.md          # 最终合并文档
```

### 文档内容

每个 `README.md` 包含：

1. **元数据** (YAML Front Matter)
   - 标题、主播、时长
   - 发布日期、音频链接
   - Episode ID

2. **Show Notes**
   - 节目简介
   - 时间戳大纲

3. **完整转录文本**
   - ASR 自动生成
   - 中文准确度 > 90%

## 性能参数

### 处理速度

| 设备 | 1小时音频转录时间 | 加速比 |
|------|------------------|--------|
| Mac M1/M2/M3 (MPS) | 18-30 分钟 | 2-3x |
| CPU | 45-60 分钟 | 1x |

### 模型信息

- **模型**: FunASR paraformer-zh
- **参数量**: 220M
- **训练数据**: 60,000 小时中文语音
- **模型大小**: ~900MB (总计约 2GB，包含 VAD 和标点模型)

## 高级用法

### Notion 同步

支持将转录文档同步到 Notion 数据库：

```bash
# 安装依赖
pip3 install notion-client

# 设置环境变量（推荐）
export NOTION_TOKEN="your-integration-token"
export NOTION_DATABASE_ID="your-database-id"

# 使用 Notion 同步
~/.claude/skills/xiaoyuzhou-podcast/scripts/process-podcast.sh <URL> --notion
```

**获取 Notion Token 和 Database ID：**

1. **Integration Token**
   - 访问 https://www.notion.so/my-integrations
   - 创建新 Integration
   - 复制 "Internal Integration Token"

2. **Database ID**
   - 在 Notion 中打开目标数据库
   - 点击右上角 "..." → "Copy link"
   - URL 格式: `https://www.notion.so/{workspace}?v={view_id}&p={DATABASE_ID}`
   - 复制 DATABASE_ID 部分（32位字符）

3. **授权数据库**
   - 在 Notion 数据库页面点击 "..." → "Add connections"
   - 选择你创建的 Integration

**Notion 数据库建议字段：**
- 标题
- 主播
- 发布日期
- 时长
- Episode URL (url)

### 热词优化

提升特定术语识别准确度：

```bash
python3 scripts/transcribe.py \
  --audio audio.m4a \
  --hotword "投资 Fiserv 金融科技"
```

### 批处理大小调整

根据内存调整批处理大小：

```bash
# 16GB 内存（默认）
--batch-size 300

# 32GB+ 内存（更快）
--batch-size 600
```

## 常见问题

### 1. MPS 不可用

检查 MPS 支持：
```bash
python3 -c "import torch; print(torch.backends.mps.is_available())"
```

确保：
- Mac M1/M2/M3 设备
- macOS 最新版本
- PyTorch 2.0+

### 2. 模型下载失败

- 检查网络连接
- 确认可用磁盘空间 > 2GB
- 国内用户可能需要配置 ModelScope 镜像

### 3. 转录速度慢

优化建议：
- 确认启用了 MPS 加速
- 关闭其他资源密集应用
- 增加批处理大小（如果内存充足）

## 技术架构

### 依赖项

- **xyz-dl**: 小宇宙播客下载工具
- **FunASR**: 阿里达摩院语音识别框架
- **PyTorch**: 深度学习框架（Metal 加速）
- **ModelScope**: 模型管理和下载

### 工作流程

```
播客 URL/ID
    ↓
xyz-dl 下载
    ↓
音频 + Show Notes (.cache/)
    ↓
FunASR 转录 (MPS 加速)
    ↓
合并到 README.md
    ↓
清理临时文件
    ↓
最终文档
```

## 使用限制

### 重要说明

- **仅供个人使用**: 下载的内容和转录文本仅供个人学习
- **尊重版权**: 支持创作者，通过官方渠道收听
- **平台条款**: 遵守小宇宙平台的用户协议
- **合理使用**: 避免频繁批量下载

### 准确度说明

- 中文 ASR 准确度约 90%+
- 可能受以下因素影响：
  - 口音和方言
  - 背景音乐或噪音
  - 多人对话（无说话人分离）
  - 专业术语

- 建议对关键内容人工校对

## 故障排查

详细故障排查指南请参考：`references/troubleshooting.md`

## 更新日志

### v1.0.0 (2026-02-15)

- 初始版本发布
- 支持一键下载、转录、合并
- Mac MPS 加速支持
- 自动清理临时文件

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 致谢

- [xyz-dl](https://github.com/slarkio/xyz-dl) - 小宇宙播客下载工具
- [FunASR](https://github.com/modelscope/FunASR) - 语音识别框架
- [ModelScope](https://modelscope.cn/) - 模型平台
