---
name: xiaoyuzhou-podcast
description: Download Xiaoyuzhou FM podcasts with full transcripts via FunASR ASR. Use when user provides xiaoyuzhoufm.com links or requests podcast content analysis.
allowed-tools:
  - bash
  - read
  - glob
  - webfetch
---

# Xiaoyuzhou Podcast Skill

Download podcasts from xiaoyuzhoufm.com and generate full transcripts using FunASR Automatic Speech Recognition (ASR).

## Overview

This skill processes Xiaoyuzhou FM podcast links to:
1. Download audio files and show notes
2. Generate full transcripts via ASR (FunASR paraformer-zh)
3. Extract structured metadata
4. Provide comprehensive content for analysis

## When to Use

Activate this skill when:
- User provides a xiaoyuzhoufm.com episode link
- User asks to "download podcast" or "transcribe podcast"
- User needs full text content of a podcast for analysis
- User provides a 24-character hex episode ID

## Workflow

### Step 1: Install Dependencies

First-time setup:
```bash
~/.claude/skills/xiaoyuzhou-podcast/scripts/install.sh
```

This checks and installs:
- Python 3.8+
- PyTorch with Metal (MPS) acceleration
- FunASR and ModelScope
- xyz-dl downloader

### Step 2: Download Audio and Show Notes

```bash
~/.claude/skills/xiaoyuzhou-podcast/scripts/download.sh <URL or Episode ID>
```

Examples:
```bash
# Using full URL
scripts/download.sh https://www.xiaoyuzhoufm.com/episode/6942f3e852d4707aaa1feba3

# Using episode ID only
scripts/download.sh 6942f3e852d4707aaa1feba3

# Custom output directory
scripts/download.sh 6942f3e852d4707aaa1feba3 ~/MyPodcasts
```

Output structure:
```
~/Documents/Podcasts/
├── {id}_{host} - {title}/       # 播客目录
│   ├── README.md                # 最终合并文档（Show Notes + 转录）
│   └── .cache/                  # 临时缓存（处理后自动删除）
│       ├── *.md                 # Show Notes
│       └── *.m4a                # 音频文件
```

### Step 3: Generate Full Transcript

```bash
python3 ~/.claude/skills/xiaoyuzhou-podcast/scripts/transcribe.py --audio <audio_path>
```

Options:
- `--audio`: Path to audio file (required)
- `--output-dir`: Custom output directory
- `--hotword`: Space-separated keywords to improve accuracy
- `--batch-size`: Batch size in seconds (default: 300,适合 16GB 内存)

Example:
```bash
# Basic transcription
python3 scripts/transcribe.py --audio ~/Documents/Podcasts/6942f3e852d4707aaa1feba3/.cache/podcast.m4a

# With hotwords for better accuracy
python3 scripts/transcribe.py --audio podcast.m4a --hotword "投资 Fiserv 金融科技"

# Larger batch size for faster processing (requires more RAM)
python3 scripts/transcribe.py --audio podcast.m4a --batch-size 600
```

Output:
```
~/Documents/Podcasts/{id}_{host} - {title}/.cache/
├── {id}_{host} - {title}.txt            # Full transcript
└── {id}_{host} - {title}_timestamp.txt  # With timestamps
```

### Step 4: Extract Structured Information

```bash
~/.claude/skills/xiaoyuzhou-podcast/scripts/extract-info.sh <Episode ID or Show Notes path>
```

This outputs:
- Basic metadata (title, host, duration, date)
- Links (episode URL, audio URL)
- File locations
- Transcript statistics and preview

## Input Format

Accepts either:
- **Full URL**: `https://www.xiaoyuzhoufm.com/episode/{24-char-hex-id}`
- **Episode ID**: 24-character hexadecimal string (e.g., `6942f3e852d4707aaa1feba3`)

## Performance

**Expected performance on Mac M1/M2/M3:**
- Chinese ASR accuracy: > 90%
- Processing speed: 0.3-0.5x real-time (1 hour audio → 18-30 min transcription)
- Memory usage: ~1.5-2GB (model + audio)
- Metal (MPS) acceleration: 2-3x faster than CPU

## Technical Details

### ASR Engine

**FunASR paraformer-zh**:
- Model: 220M parameters, ~900MB
- Training data: 60,000 hours of Chinese Mandarin
- Native timestamp support (character-level)
- Automatic punctuation restoration
- Voice Activity Detection (VAD) for silence removal

### Model Storage

Models are automatically downloaded to:
```
~/.cache/modelscope/hub/iic/
├── speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-pybuild/
├── speech_fsmn_vad_zh-cn-16k-common-pybuild/
└── punc_ct-transformer_cn-en-common-vocab471067-large/
```

Total disk usage: ~2GB (first-time download)

### Acceleration

- **Mac M1/M2/M3**: Metal Performance Shaders (MPS)
- **NVIDIA GPU**: CUDA support (optional)
- **CPU**: Fallback mode (slower)

## Success Response Format

```
[SUCCESS] Podcast processed successfully

**Metadata:**
- Title: {title}
- Host: {host}
- Duration: {duration}
- Published: {date}
- Episode ID: {id}

**Files:**
- Final Document: ~/Documents/Podcasts/{id}_{host} - {title}/README.md
- (Cache files deleted after processing)

**Transcript Statistics:**
- Word count: {count}
- Processing time: {time}

**Transcript Preview:**
{first 500 characters}...
```

## Error Handling

| Error Type | Message | Solution |
|------------|---------|----------|
| `invalid_url` | Invalid URL format | Use full URL or 24-char hex ID |
| `not_installed` | Dependencies missing | Run `install.sh` |
| `download_failed` | Audio download failed | Check network, verify URL |
| `transcribe_failed` | ASR transcription failed | Check audio file integrity |
| `not_found` | Episode not found | Verify URL is correct |
| `mps_unavailable` | Metal acceleration unavailable | Will use CPU fallback |

## Important Notes

### Usage Restrictions

- **Personal Use Only**: Downloaded content and transcripts are for personal use only
- **Support Creators**: Consider supporting podcast creators through official channels
- **Platform Terms**: Respect Xiaoyuzhou's terms of service
- **Rate Limiting**: Avoid frequent bulk downloads to prevent server overload

### Accuracy Considerations

- ASR accuracy is ~90%+, but may vary with:
  - Accents and dialects
  - Background music or noise
  - Multiple speakers (no speaker diarization)
  - Technical terminology

- **Hotwords**: Use `--hotword` parameter to improve specific term recognition
- **Review Recommended**: Proofread critical content manually

## Troubleshooting

### Common Issues

**1. MPS (Metal) not available**
- Ensure Mac M1/M2/M3 device
- Update macOS to latest version
- PyTorch 2.0+ required

**2. Model download fails**
- Check internet connection
- Verify sufficient disk space (~2GB)
- Use ModelScope mirror if in China

**3. Slow transcription**
- Check MPS is enabled: `python3 -c "import torch; print(torch.backends.mps.is_available())"`
- Increase batch size if RAM allows
- Close other resource-intensive applications

**4. Poor accuracy on specific terms**
- Add hotwords: `--hotword "term1 term2 term3"`
- Check audio quality

For detailed troubleshooting, see `references/troubleshooting.md`

## Example Usage

```
User: 帮我下载并转录这个播客 https://www.xiaoyuzhoufm.com/episode/6942f3e852d4707aaa1feba3

Assistant: I'll help you download and transcribe this podcast. Let me start by running the installation check, then download and transcribe it.

[Runs install.sh]
[Runs download.sh with URL]
[Runs transcribe.py with audio file]
[Runs extract-info.sh to show summary]

[SUCCESS] Podcast downloaded and transcribed!

**Metadata:**
- Title: EP9 深度专访MIT博士"黑色面包"-我为什么重仓Fiserv (FISV)
- Host: 鹅先知 投资、出海和长寿科技
- Duration: 196:20
- Published: 2025-01-15
- Episode ID: 6942f3e852d4707aaa1feba3

**Files:**
- Final Document: ~/Documents/Podcasts/6942f3e852d4707aaa1feba3_鹅先知.../README.md

**Transcript Preview:**
大家好，欢迎收听本期节目。今天我们邀请了MIT博士...

The transcript is ready for analysis. Would you like me to summarize key points or search for specific topics?
```

## References

- [FunASR Documentation](https://github.com/modelscope/FunASR)
- [xyz-dl Project](https://github.com/slarkio/xyz-dl)
- [Troubleshooting Guide](references/troubleshooting.md)
- [ASR Setup Details](references/asr-setup.md)
