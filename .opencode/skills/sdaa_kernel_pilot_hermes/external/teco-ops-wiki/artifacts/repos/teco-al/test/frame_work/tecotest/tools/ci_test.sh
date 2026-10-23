#!/bin/bash

# 获取最新Commit的消息
latest_commit_message=$(git log -1 --pretty=format:'%s')
email_dress=$(git log -1  --pretty=format:'%ae')
# 将消息保存到文件
echo "$latest_commit_message"
cmd=$(python ../tools/gen_oa_cmd.py --commit_message="$latest_commit_message" --pr_url="$1" --commit_email="$email_dress")
$cmd

