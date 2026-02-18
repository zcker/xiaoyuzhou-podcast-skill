# 小宇宙播客下载插件 - 更新日志

## 版本 2.0 (2026-02-18)

### 重大更新

#### 📁 目录结构变更

**旧路径**: `~/Podcasts/xiaoyuzhou/`
**新路径**: `~/Documents/Podcasts/`

#### 🗂️ 新的文件组织结构

```
~/Documents/Podcasts/
├── {id}_{host} - {title}/       # 播客目录
│   ├── README.md                # 最终合并文档（Show Notes + 转录）
│   └── .cache/                  # 临时缓存（处理后自动删除）
│       ├── *.md                 # Show Notes（原始）
│       ├── *.m4a                # 音频文件
│       └── *.txt                # 转录文本（临时）
```

#### 🧹 自动清理中间产物

处理完成后自动删除 `.cache` 目录，只保留最终的 `README.md` 文档，节省磁盘空间。

**之前**（保留所有中间文件）:
- 音频文件（~50-200MB）
- 转录文本（~1-2MB）
- Show Notes 原始文件

**之后**（只保留最终文档）:
- README.md（包含 Show Notes + 完整转录文本）

### 升级指南

#### 从旧版本迁移

如果您有旧的播客数据在 `~/Podcasts/xiaoyuzhou/`，运行迁移脚本：

```bash
~/.claude/skills/xiaoyuzhou-podcast/scripts/migrate-to-documents.sh
```

脚本会：
1. 列出所有旧播客目录
2. 询问是否继续迁移
3. 移动到新位置 `~/Documents/Podcasts/`
4. 询问是否删除旧目录

#### 全新安装

无需任何操作，直接使用：

```bash
# 完整流程
~/.claude/skills/xiaoyuzhou-podcast/scripts/process-podcast.sh "https://www.xiaoyuzhoufm.com/episode/xxx"

# 或分步操作
~/.claude/skills/xiaoyuzhou-podcast/scripts/download.sh "episode_id"
python3 ~/.claude/skills/xiaoyuzhou-podcast/scripts/transcribe.py --audio "audio.m4a"
~/.claude/skills/xiaoyuzhou-podcast/scripts/merge-and-clean.sh "episode_id"
```

### 其他改进

- ✅ 修改默认输出目录为 `~/Documents/Podcasts`
- ✅ 自动清理 `.cache` 目录及其所有内容
- ✅ 更新所有脚本中的路径引用
- ✅ 更新 SKILL.md 文档

### 兼容性

- ✅ 旧路径脚本仍然可用（会自动兼容）
- ✅ 提供迁移脚本无缝升级
- ✅ extract-info.sh 同时支持新旧路径

---

**更新日期**: 2026-02-18
**维护者**: Boss Kai
