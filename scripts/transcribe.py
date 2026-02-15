#!/usr/bin/env python3

"""
小宇宙播客 ASR 转录脚本
使用 FunASR paraformer-zh 进行语音识别
支持 Mac MPS (Metal) 加速
"""

import argparse
import os
import sys
from pathlib import Path
import time
import torch
from funasr import AutoModel

def check_device():
    """检测并返回最优设备"""
    if torch.backends.mps.is_available():
        print("[INFO] 检测到 MPS (Metal) 加速，使用 GPU")
        return "mps"
    elif torch.cuda.is_available():
        print("[INFO] 检测到 CUDA，使用 GPU")
        return "cuda"
    else:
        print("[INFO] 使用 CPU 模式")
        return "cpu"

def transcribe_audio(audio_path, output_dir=None, hotword="", batch_size_s=300):
    """
    转录音频文件

    Args:
        audio_path: 音频文件路径
        output_dir: 输出目录（默认为音频文件同级的 transcripts 目录）
        hotword: 热词，提升特定词汇识别准确度
        batch_size_s: 批处理长度（秒）
    """

    audio_path = Path(audio_path)
    if not audio_path.exists():
        print(f"[ERROR] 音频文件不存在: {audio_path}")
        sys.exit(1)

    print(f"[INFO] 音频文件: {audio_path}")

    # 确定输出目录（统一输出到 .cache 目录）
    if output_dir is None:
        # 如果音频在 .cache 目录，输出到同一目录
        if ".cache" in str(audio_path):
            output_dir = audio_path.parent
        else:
            # 兼容旧结构
            output_dir = audio_path.parent / "transcripts"

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[INFO] 输出目录: {output_dir}")

    # 检测设备
    device = check_device()

    print("[INFO] 正在加载 FunASR 模型...")
    print("[INFO] 首次运行会自动下载模型（约 2GB），请耐心等待...")

    # 检查磁盘空间
    output_dir_path = Path(output_dir)
    if not output_dir_path.exists():
        output_dir_path.mkdir(parents=True, exist_ok=True)

    # 初始化模型（带重试）
    max_retries = 3
    for attempt in range(max_retries):
        try:
            model = AutoModel(
                model="paraformer-zh",       # 中文非流式模型
                vad_model="fsmn-vad",        # 语音活动检测（去静音）
                punc_model="ct-punc",        # 标点恢复
                device=device,
            )
            break
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"[WARN] 模型加载失败 (尝试 {attempt + 1}/{max_retries}): {e}")
                time.sleep(2)
            else:
                print(f"[ERROR] 模型加载失败: {e}")
                print("[INFO] 请检查网络连接和磁盘空间")
                sys.exit(1)

    print("[INFO] 模型加载完成")
    print(f"[INFO] 开始转录...")
    print(f"[INFO] 批处理大小: {batch_size_s} 秒")

    if hotword:
        print(f"[INFO] 热词: {hotword}")

    # 进行转录（带重试）
    max_retries = 2
    for attempt in range(max_retries):
        try:
            result = model.generate(
                input=str(audio_path),
                batch_size_s=batch_size_s,
                hotword=hotword,
            )
            break
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"[WARN] 转录失败，正在重试 (尝试 {attempt + 1}/{max_retries}): {e}")
                time.sleep(3)
            else:
                print(f"[ERROR] 转录失败: {e}")
                print("[INFO] 请检查音频文件是否完整")
                sys.exit(1)

    if not result:
        print("[ERROR] 转录失败，未返回结果")
        sys.exit(1)

    # 提取文本
    text = result[0].get("text", "")
    timestamp = result[0].get("timestamp", [])

    if not text:
        print("[ERROR] 转录结果为空")
        sys.exit(1)

    # 生成输出文件名
    audio_name = audio_path.stem  # 去除扩展名
    output_file = output_dir / f"{audio_name}.txt"

    print(f"[INFO] 保存文字稿到: {output_file}")

    # 保存纯文本
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(text)

    # 如果有时间戳，保存带时间戳的版本
    if timestamp:
        timestamp_file = output_dir / f"{audio_name}_timestamp.txt"
        print(f"[INFO] 保存时间戳版本: {timestamp_file}")

        # 调试：打印 timestamp 的类型和前几个条目
        print(f"[DEBUG] Timestamp type: {type(timestamp)}")
        if len(timestamp) > 0:
            print(f"[DEBUG] First 3 timestamp entries: {timestamp[:3]}")

        with open(timestamp_file, "w", encoding="utf-8") as f:
            for i, entry in enumerate(timestamp):
                # FunASR timestamp 可能是 (start, end, word) 或 (start, end) 格式
                # 使用更健壮的解析方式
                try:
                    if isinstance(entry, (list, tuple)):
                        if len(entry) == 3:
                            start, end, word = entry
                        elif len(entry) == 2:
                            start, end = entry
                            word = ""  # 没有词信息
                        else:
                            print(f"[WARN] 跳过格式不正确的时间戳条目 {i}: {entry}")
                            continue
                    else:
                        print(f"[WARN] 跳过非列表类型的时间戳条目 {i}: {entry}")
                        continue

                    # 格式: [00:00:00.000 -> 00:00:01.000] 文字
                    start_time = format_timestamp(start)
                    end_time = format_timestamp(end)
                    if word:
                        f.write(f"[{start_time} -> {end_time}] {word}\n")
                    else:
                        f.write(f"[{start_time} -> {end_time}]\n")
                except Exception as e:
                    print(f"[WARN] 处理时间戳条目 {i} 时出错: {e}, entry={entry}")
                    continue

    # 输出统计信息
    word_count = len(text)
    duration_info = ""

    print("\n" + "="*50)
    print("[SUCCESS] 转录完成！")
    print("="*50)
    print(f"文字数量: {word_count}")
    print(f"输出文件: {output_file}")
    if timestamp:
        print(f"时间戳文件: {timestamp_file}")

    # 显示预览
    print("\n[文字稿预览] (前 500 字)")
    print("-" * 50)
    print(text[:500])
    if len(text) > 500:
        print("...")
    print("-" * 50)

def format_timestamp(ms):
    """将毫秒转换为 HH:MM:SS.mmm 格式"""
    hours = int(ms // 3600000)
    minutes = int((ms % 3600000) // 60000)
    seconds = int((ms % 60000) // 1000)
    milliseconds = int(ms % 1000)

    return f"{hours:02d}:{minutes:02d}:{seconds:02d}.{milliseconds:03d}"

def main():
    parser = argparse.ArgumentParser(
        description="小宇宙播客 ASR 转录工具（基于 FunASR paraformer-zh）"
    )

    parser.add_argument(
        "--audio",
        required=True,
        help="音频文件路径（支持 .m4a, .mp3, .wav 等格式）"
    )

    parser.add_argument(
        "--output-dir",
        help="输出目录（默认为音频同级 transcripts 目录）"
    )

    parser.add_argument(
        "--hotword",
        default="",
        help="热词，提升特定词汇识别准确度（用空格分隔）"
    )

    parser.add_argument(
        "--batch-size",
        type=int,
        default=300,
        help="批处理大小（秒），默认 300（适合 16GB 内存）"
    )

    args = parser.parse_args()

    print("="*50)
    print("小宇宙播客 ASR 转录工具")
    print("="*50)
    print()

    transcribe_audio(
        audio_path=args.audio,
        output_dir=args.output_dir,
        hotword=args.hotword,
        batch_size_s=args.batch_size
    )

if __name__ == "__main__":
    main()
