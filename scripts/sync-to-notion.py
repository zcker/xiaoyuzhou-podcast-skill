#!/usr/bin/env python3

"""
将播客文档同步到 Notion
支持将 Markdown 格式的播客文档上传到 Notion 数据库
"""

import argparse
import os
import sys
from pathlib import Path
from datetime import datetime

try:
    from notion_client import Client
except ImportError:
    print("[ERROR] notion-client 未安装")
    print("[INFO] 请运行: pip3 install notion-client")
    sys.exit(1)

def parse_front_matter(content):
    """解析 Markdown 文件的 YAML Front Matter"""
    metadata = {}

    lines = content.split('\n')
    in_front_matter = False

    for line in lines:
        if line.strip() == '---':
            if in_front_matter:
                break
            else:
                in_front_matter = True
                continue

        if in_front_matter and ':' in line:
            key, value = line.split(':', 1)
            metadata[key.strip()] = value.strip()

    return metadata

def markdown_to_notion_blocks(content):
    """将 Markdown 内容转换为 Notion block 格式"""
    blocks = []

    # 分割为段落
    paragraphs = content.split('\n\n')

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue

        # 跳过 Front Matter
        if para.startswith('---'):
            continue

        # 处理标题
        if para.startswith('# '):
            blocks.append({
                "object": "block",
                "type": "heading_1",
                "heading_1": {
                    "rich_text": [{"type": "text", "text": {"content": para[2:]}}]
                }
            })
        elif para.startswith('## '):
            blocks.append({
                "object": "block",
                "type": "heading_2",
                "heading_2": {
                    "rich_text": [{"type": "text", "text": {"content": para[3:]}}]
                }
            })
        elif para.startswith('### '):
            blocks.append({
                "object": "block",
                "type": "heading_3",
                "heading_3": {
                    "rich_text": [{"type": "text", "text": {"content": para[4:]}}]
                }
            })
        else:
            # 普通段落（Notion 单个 block 最多 2000 字符）
            if len(para) <= 2000:
                blocks.append({
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": {
                        "rich_text": [{"type": "text", "text": {"content": para}}]
                    }
                })
            else:
                # 分割长段落
                for i in range(0, len(para), 1900):
                    chunk = para[i:i+1900]
                    blocks.append({
                        "object": "block",
                        "type": "paragraph",
                        "paragraph": {
                            "rich_text": [{"type": "text", "text": {"content": chunk}}]
                        }
                    })

    return blocks

def sync_to_notion(notion_token, database_id, markdown_file, metadata=None):
    """同步文档到 Notion 数据库"""

    # 初始化客户端
    notion = Client(auth=notion_token)

    # 读取 Markdown 文件
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 解析元数据
    if metadata is None:
        metadata = parse_front_matter(content)

    # 创建页面属性
    properties = {
        "标题": {
            "title": [{"text": {"content": metadata.get('title', 'Untitled')}}]
        }
    }

    # 添加其他属性（如果数据库有这些字段）
    if 'podcast_name' in metadata:
        properties["主播"] = {
            "rich_text": [{"text": {"content": metadata['podcast_name']}}]
        }

    if 'published_date' in metadata:
        # 转换日期格式为 ISO 8601
        date_str = metadata['published_date']
        # 如果是中文格式 "2025年07月16日"，转换为 "2025-07-16"
        if '年' in date_str:
            import re
            match = re.search(r'(\d{4})年(\d{2})月(\d{2})日', date_str)
            if match:
                date_str = f"{match.group(1)}-{match.group(2)}-{match.group(3)}"
        # 如果有 published_at，使用它（已经是 ISO 格式）
        elif 'published_at' in metadata:
            date_str = metadata['published_at'].replace('.000Z', '').replace('"', '')

        # 清理任何多余的引号和转义字符
        date_str = date_str.strip('"').strip("'")

        properties["发布日期"] = {
            "date": {"start": date_str}
        }

    if 'duration_text' in metadata:
        properties["时长"] = {
            "rich_text": [{"text": {"content": metadata['duration_text']}}]
        }

    if 'url' in metadata:
        properties["Episode URL"] = {
            "url": metadata['url']
        }

    # 转换内容为 Notion blocks
    print("[INFO] 正在转换 Markdown 为 Notion 格式...")
    blocks = markdown_to_notion_blocks(content)

    # Notion API 限制每次最多 100 个 blocks
    print(f"[INFO] 共 {len(blocks)} 个 blocks")

    # 创建页面
    print("[INFO] 正在创建 Notion 页面...")
    try:
        # 创建页面和前 100 个 blocks
        first_batch = blocks[:100]
        page = notion.pages.create(
            parent={"database_id": database_id},
            properties=properties,
            children=first_batch
        )

        page_id = page['id']
        print(f"[INFO] 页面已创建: {page_id}")

        # 添加剩余的 blocks
        remaining_blocks = blocks[100:]
        if remaining_blocks:
            print(f"[INFO] 正在添加剩余的 {len(remaining_blocks)} 个 blocks...")
            for i in range(0, len(remaining_blocks), 100):
                batch = remaining_blocks[i:i+100]
                notion.blocks.children.append(
                    block_id=page_id,
                    children=batch
                )
                print(f"[INFO] 已添加 {min(i+100, len(remaining_blocks))}/{len(remaining_blocks)} 个 blocks")

        return page['url']

    except Exception as e:
        print(f"[ERROR] 创建页面失败: {e}")
        raise

def main():
    parser = argparse.ArgumentParser(
        description="同步播客文档到 Notion"
    )

    parser.add_argument(
        "--file",
        required=True,
        help="Markdown 文件路径"
    )

    parser.add_argument(
        "--token",
        help="Notion Integration Token (或通过环境变量 NOTION_TOKEN 设置)"
    )

    parser.add_argument(
        "--database-id",
        help="Notion Database ID (或通过环境变量 NOTION_DATABASE_ID 设置)"
    )

    args = parser.parse_args()

    # 获取 Token
    notion_token = args.token or os.getenv('NOTION_TOKEN')
    if not notion_token:
        print("[ERROR] 需要提供 Notion Integration Token")
        print("[INFO] 请设置环境变量 NOTION_TOKEN 或使用 --token 参数")
        print("\n如何获取 Notion Integration Token:")
        print("1. 访问 https://www.notion.so/my-integrations")
        print("2. 点击 '+ New integration'")
        print("3. 填写名称后创建")
        print("4. 复制 'Internal Integration Token'")
        sys.exit(1)

    # 获取 Database ID
    database_id = args.database_id or os.getenv('NOTION_DATABASE_ID')
    if not database_id:
        print("[ERROR] 需要提供 Notion Database ID")
        print("[INFO] 请设置环境变量 NOTION_DATABASE_ID 或使用 --database-id 参数")
        print("\n如何获取 Database ID:")
        print("1. 在 Notion 中打开目标数据库")
        print("2. 点击右上角 '...' -> 'Copy link'")
        print("3. URL 格式: https://www.notion.so/{workspace}?v={view_id}&p={DATABASE_ID}")
        print("4. 复制 DATABASE_ID 部分（32位字符）")
        sys.exit(1)

    # 检查文件
    markdown_file = Path(args.file)
    if not markdown_file.exists():
        print(f"[ERROR] 文件不存在: {markdown_file}")
        sys.exit(1)

    print("="*50)
    print("Notion 同步工具")
    print("="*50)
    print(f"\n文件: {markdown_file}")
    print(f"Database ID: {database_id[:8]}...")
    print()

    # 同步
    try:
        page_url = sync_to_notion(notion_token, database_id, markdown_file)

        print("\n" + "="*50)
        print("[SUCCESS] 同步完成！")
        print("="*50)
        print(f"\nNotion 页面: {page_url}")

    except Exception as e:
        print(f"\n[ERROR] 同步失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
