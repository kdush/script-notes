#!/bin/bash

# 配置参数
RPC_AUTH="name:password"
BASE_DIR="/downloads/incomplete/"

# 安全连接测试
echo "正在测试 Transmission 连接..."
test_output=$(transmission-remote -n "$RPC_AUTH" -l)
if [ $? -ne 0 ] || ! echo "$test_output" | grep -q "Sum:"; then
    echo "错误：无法连接到 Transmission"
    echo "错误信息: $test_output"
    exit 1
fi

echo "开始处理下载任务路径..."

# 初始化计数器
total_tasks=0
fixed_count=0

# 获取所有任务列表（只保留Stopped状态的任务）
echo "正在获取停止状态的任务列表..."
IFS=$'\n'
tasks=$(echo "$test_output" | grep "Stopped" | grep -vE '^[[:space:]]*ID|^Sum:')

# 检查任务列表是否为空
if [ -z "$tasks" ]; then
    echo "没有找到任何停止状态的任务"
    exit 0
fi

# 预先获取所有任务的详细信息
echo "正在获取所有任务的详细信息..."
declare -A task_info_map
declare -A task_location_map
declare -A task_name_map

while IFS= read -r task_line; do
    if [ -z "$task_line" ]; then
        continue
    fi
    
    # 从任务行获取ID和名称
    task_id=$(echo "$task_line" | awk '{print $1}' | tr -d '*')
    
    # 检查任务ID是否有效
    if ! [[ "$task_id" =~ ^[0-9]+$ ]]; then
        echo "警告：无效的任务ID: $task_id，跳过"
        continue
    fi
    
    # 获取任务详细信息
    task_info=$(transmission-remote -n "$RPC_AUTH" -t "$task_id" -i)
    if [ -z "$task_info" ]; then
        echo "警告：无法获取任务 $task_id 的信息，跳过"
        continue
    fi
    
    # 存储任务信息
    task_info_map[$task_id]="$task_info"
    task_location_map[$task_id]=$(echo "$task_info" | grep "^  Location:" | sed 's/^  Location: //')
    task_name_map[$task_id]=$(echo "$task_line" | awk -F'Idle|Stopped' '{print $NF}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    echo "已获取任务 $task_id 的信息"
done <<< "$tasks"

# 调试输出
echo "正在遍历目录: $BASE_DIR"
echo "----------------------------"

# 检查基础目录是否存在
if [ ! -d "$BASE_DIR" ]; then
    echo "错误：基础目录 $BASE_DIR 不存在"
    exit 1
fi

# 设置最大处理文件数量，避免无限循环
max_files=10000
file_count=0

# 遍历实际文件系统
while IFS= read -r file_path; do
    # 检查文件计数
    ((file_count++))
    if [ "$file_count" -gt "$max_files" ]; then
        echo "警告：已达到最大文件处理数量 ($max_files)，停止处理"
        break
    fi

    # 获取文件名或目录名
    file_name=$(basename "$file_path")
    
    # 如果是文件或目录，则处理
    if [ -f "$file_path" ] || [ -d "$file_path" ]; then
        # 遍历所有transmission任务
        for task_id in "${!task_name_map[@]}"; do
            # 获取预存的任务信息
            task_name="${task_name_map[$task_id]}"
            current_location="${task_location_map[$task_id]}"
            
            # 调试输出
            echo "----------------------------"
            echo "检查路径: $file_path"
            echo "比较文件:"
            echo "  本地文件: '$file_name'"
            echo "  任务文件: '$task_name'"
            echo "  当前位置: '$current_location'"
            
            # 如果文件名与任务名匹配
            if [ "$file_name" = "$task_name" ]; then
                echo "找到匹配！"
                echo "任务ID: $task_id"
                echo "当前位置: $current_location"
                echo "文件位置: $(dirname "$file_path")"
                
                # 如果当前位置与实际位置不同
                if [ "$current_location" != "$(dirname "$file_path")" ]; then
                    echo "开始修正任务 $task_id:"
                    echo "  文件: $file_path"
                    echo "  当前位置: $current_location"
                    echo "  目标位置: $(dirname "$file_path")"
                    
                    # 移动任务到正确位置
                    if transmission-remote -n "$RPC_AUTH" -t "$task_id" --move "$(dirname "$file_path")"; then
                        ((fixed_count++))
                        echo "  ✓ 路径修正成功"
                    else
                        echo "  × 路径修正失败"
                    fi
                fi
            fi
            ((total_tasks++))
        done
    fi
done < <(find "$BASE_DIR" -mindepth 1)

echo "----------------------------"
echo "处理完成："
echo "总任务数: $total_tasks"
echo "已修正数: $fixed_count"
echo "处理的文件数: $file_count"