#!/usr/bin/env python3

"""
小宇宙播客 ASR 转录脚本（增强版）
- 支持说话人分离（Speaker Diarization）
- 智能断句和分段
- 生成结构化对话格式
"""

import argparse
import os
import sys
import re
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

def smart_segment_text(text, min_paragraph_length=100, max_paragraph_length=500):
    """
    智能分段文本

    Args:
        text: 输入文本
        min_paragraph_length: 最小段落长度
        max_paragraph_length: 最大段落长度

    Returns:
        分段后的文本
    """
    # 首先按照句号、问号、感叹号分段
    sentences = re.split(r'([。！？])', text)
    sentences = [''.join(i) for i in zip(sentences[0::2], sentences[1::2] + [''])]

    paragraphs = []
    current_para = []
    current_length = 0

    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue

        sentence_len = len(sentence)

        # 如果当前段落为空，直接添加
        if not current_para:
            current_para.append(sentence)
            current_length = sentence_len
        # 如果添加这个句子不会超过最大长度，且当前长度小于最小长度
        elif current_length + sentence_len <= max_paragraph_length and current_length < min_paragraph_length:
            current_para.append(sentence)
            current_length += sentence_len
        # 如果当前长度已经达到最小长度，且这个句子比较长（可能是新话题）
        elif current_length >= min_paragraph_length and sentence_len > 20:
            paragraphs.append(''.join(current_para))
            current_para = [sentence]
            current_length = sentence_len
        # 否则继续添加
        else:
            current_para.append(sentence)
            current_length += sentence_len

        # 如果超过最大长度，强制分段
        if current_length >= max_paragraph_length:
            paragraphs.append(''.join(current_para))
            current_para = []
            current_length = 0

    # 添加最后一个段落
    if current_para:
        paragraphs.append(''.join(current_para))

    return '\n\n'.join(paragraphs)

def format_speaker_dialogue(speaker_segments):
    """
    格式化说话人对话

    Args:
        speaker_segments: 说话人片段列表

    Returns:
        格式化的对话文本
    """
    if not speaker_segments:
        return ""

    dialogue_lines = []
    current_speaker = None
    current_text = []

    for segment in speaker_segments:
        speaker = segment.get('speaker', '未知')
        text = segment.get('text', '').strip()

        if not text:
            continue

        # 如果说话人改变，保存之前的对话
        if speaker != current_speaker:
            if current_text:
                dialogue_lines.append(f"\n**{current_speaker}**：\n{''.join(current_text)}")
            current_speaker = speaker
            current_text = [text]
        else:
            current_text.append(text)

    # 添加最后一个说话人的对话
    if current_text:
        dialogue_lines.append(f"\n**{current_speaker}**：\n{''.join(current_text)}")

    return '\n'.join(dialogue_lines)

def transcribe_audio_enhanced(audio_path, output_dir=None, hotword="", batch_size_s=300,
                               enable_diarization=True, enable_segmentation=True):
    """
    转录音频文件（增强版）

    Args:
        audio_path: 音频文件路径
        output_dir: 输出目录
        hotword: 热词
        batch_size_s: 批处理长度（秒）
        enable_diarization: 启用说话人分离
        enable_segmentation: 启用智能分段
    """

    audio_path = Path(audio_path)
    if not audio_path.exists():
        print(f"[ERROR] 音频文件不存在: {audio_path}")
        sys.exit(1)

    print(f"[INFO] 音频文件: {audio_path}")

    # 确定输出目录
    if output_dir is None:
        if ".cache" in str(audio_path):
            output_dir = audio_path.parent
        else:
            output_dir = audio_path.parent / "transcripts"

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[INFO] 输出目录: {output_dir}")

    # 检测设备
    device = check_device()

    print("[INFO] 正在加载 FunASR 模型...")
    print("[INFO] 首次运行会自动下载模型（约 2GB），请耐心等待...")

    # 初始化模型
    max_retries = 3
    for attempt in range(max_retries):
        try:
            # 基础 ASR 模型
            model = AutoModel(
                model="paraformer-zh",
                vad_model="fsmn-vad",
                punc_model="ct-punc",
                device=device,
            )

            # 说话人分离模型（可选）
            diarization_model = None
            if enable_diarization:
                print("[INFO] 加载说话人分离模型...")
                try:
                    diarization_model = AutoModel(
                        model="iic/speech_campplus_speaker_diarization_zh-cn",  # 说话人分离
                        device=device,
                    )
                except Exception as e:
                    print(f"[WARN] 说话人分离模型加载失败: {e}")
                    print("[INFO] 将跳过说话人分离，仅使用基础转录")
                    enable_diarization = False

            break
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"[WARN] 模型加载失败 (尝试 {attempt + 1}/{max_retries}): {e}")
                time.sleep(2)
            else:
                print(f"[ERROR] 模型加载失败: {e}")
                sys.exit(1)

    print("[INFO] 模型加载完成")
    print(f"[INFO] 开始转录...")
    print(f"[INFO] 批处理大小: {batch_size_s} 秒")
    print(f"[INFO] 说话人分离: {'启用' if enable_diarization else '禁用'}")
    print(f"[INFO] 智能分段: {'启用' if enable_segmentation else '禁用'}")

    if hotword:
        print(f"[INFO] 热词: {hotword}")

    # 进行转录
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
                print(f"[WARN] 转录失败，正在重试: {e}")
                time.sleep(3)
            else:
                print(f"[ERROR] 转录失败: {e}")
                sys.exit(1)

    if not result:
        print("[ERROR] 转录失败，未返回结果")
        sys.exit(1)

    # 提取文本和时间戳
    text = result[0].get("text", "")
    timestamp = result[0].get("timestamp", [])

    if not text:
        print("[ERROR] 转录结果为空")
        sys.exit(1)

    # 说话人分离（如果启用）
    speaker_segments = []
    if enable_diarization and diarization_model:
        print("[INFO] 正在进行说话人分离...")
        try:
            diarization_result = diarization_model.generate(
                input=str(audio_path),
            )

            if diarization_result and len(diarization_result) > 0:
                # 解析说话人分离结果
                # 注意：实际格式可能需要根据 FunASR 返回调整
                for seg in diarization_result[0].get('segments', []):
                    speaker_segments.append({
                        'speaker': seg.get('speaker', '说话人'),
                        'start': seg.get('start', 0),
                        'end': seg.get('end', 0),
                        'text': seg.get('text', '')
                    })
                print(f"[INFO] 识别到 {len(set(s['speaker'] for s in speaker_segments))} 位说话人")
        except Exception as e:
            print(f"[WARN] 说话人分离失败: {e}")
            print("[INFO] 将使用基础转录结果")

    # 生成输出文件名
    audio_name = audio_path.stem
    output_file = output_dir / f"{audio_name}.txt"
    output_file_formatted = output_dir / f"{audio_name}_formatted.md"

    # 保存纯文本
    print(f"[INFO] 保存原始文字稿到: {output_file}")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(text)

    # 保存格式化版本（智能分段 + 说话人对话）
    print(f"[INFO] 保存格式化版本到: {output_file_formatted}")
    with open(output_file_formatted, "w", encoding="utf-8") as f:
        f.write(f"# {audio_name} - 转录文本\n\n")
        f.write(f"<!-- 使用 FunASR paraformer-zh 自动生成 -->\n")
        f.write(f"<!-- 说话人分离: {'启用' if enable_diarization else '禁用'} -->\n")
        f.write(f"<!-- 智能分段: {'启用' if enable_segmentation else '禁用'} -->\n\n")

        # 如果有说话人分离结果，输出对话格式
        if speaker_segments:
            f.write("## 对话记录\n\n")
            dialogue_text = format_speaker_dialogue(speaker_segments)
            f.write(dialogue_text)
            f.write("\n\n---\n\n")

        # 输出分段文本
        if enable_segmentation:
            f.write("## 完整文本（智能分段）\n\n")
            segmented_text = smart_segment_text(text)
            f.write(segmented_text)
        else:
            f.write("## 完整文本\n\n")
            f.write(text)

    # 保存时间戳版本
    if timestamp:
        timestamp_file = output_dir / f"{audio_name}_timestamp.txt"
        print(f"[INFO] 保存时间戳版本: {timestamp_file}")

        with open(timestamp_file, "w", encoding="utf-8") as f:
            for i, entry in enumerate(timestamp):
                try:
                    if isinstance(entry, (list, tuple)):
                        if len(entry) == 3:
                            start, end, word = entry
                        elif len(entry) == 2:
                            start, end = entry
                            word = ""
                        else:
                            continue

                        start_time = format_timestamp(start)
                        end_time = format_timestamp(end)
                        if word:
                            f.write(f"[{start_time} -> {end_time}] {word}\n")
                        else:
                            f.write(f"[{start_time} -> {end_time}]\n")
                except Exception as e:
                    continue

    # 输出统计信息
    word_count = len(text)

    print("\n" + "="*50)
    print("[SUCCESS] 转录完成！")
    print("="*50)
    print(f"文字数量: {word_count}")
    print(f"原始文件: {output_file}")
    print(f"格式化文件: {output_file_formatted}")
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
        description="小宇宙播客 ASR 转录工具（增强版）"
    )

    parser.add_argument(
        "--audio",
        required=True,
        help="音频文件路径"
    )

    parser.add_argument(
        "--output-dir",
        help="输出目录"
    )

    parser.add_argument(
        "--hotword",
        default="",
        help="热词（用空格分隔）"
    )

    parser.add_argument(
        "--batch-size",
        type=int,
        default=300,
        help="批处理大小（秒）"
    )

    parser.add_argument(
        "--no-diarization",
        action="store_true",
        help="禁用说话人分离"
    )

    parser.add_argument(
        "--no-segmentation",
        action="store_true",
        help="禁用智能分段"
    )

    args = parser.parse_args()

    print("="*50)
    print("小宇宙播客 ASR 转录工具（增强版）")
    print("="*50)
    print()

    transcribe_audio_enhanced(
        audio_path=args.audio,
        output_dir=args.output_dir,
        hotword=args.hotword,
        batch_size_s=args.batch_size,
        enable_diarization=not args.no_diarization,
        enable_segmentation=not args.no_segmentation
    )

if __name__ == "__main__":
    main()
