#!/usr/bin/python3

import sys
import re

# 定义提交信息的各个部分的合法范围
valid_question_nums = range(1, 4)  # 1 到 3 的整数
valid_algo_prefix = 'algo'  # algo 前缀
min_algo_num = 1  # algo_num 的最小值
max_algo_num = 110  # algo_num 的最大值

# 获取提交信息头部
def get_commit_msg(msg):
    res = re.search("\n", msg)
    if res is None:
        return msg
    else:
        return msg[:res.span()[0]]

# 验证提交信息格式
def valid_commit_msg(commit_msg):
    # 正则表达式匹配提交信息的格式
    pattern = r'\[(?P<question_num>\d+)\]\((?P<algo_num>algo\d+)\): (?P<subject>.+)'
    res = re.match(pattern, commit_msg)
    if res is None:
        print("\033[0;35m-- please input standard format for commit: [<question_num>](<algo_num>): <subject>\033[0m")
        print("\033[0;35m-- question_num should be 1 or 2 or 3\033[0m")
        print("\033[0;35m-- algo_num should be in the format of algo<num> and between algo1 to algo110\033[0m")
        return False
    else:
        question_num = int(res.group('question_num'))
        algo_num = res.group('algo_num')
        subject = res.group('subject').strip()

        if question_num not in valid_question_nums:
            print("\033[0;35m-- question_num not valid, should be 1 or 2 or 3\033[0m")
            return False
        if not algo_num.startswith(valid_algo_prefix) or not algo_num[len(valid_algo_prefix):].isdigit():
            print("\033[0;35m-- algo_num not valid, should be in the format of algo<num>\033[0m")
            return False
        algo_num_value = int(algo_num[len(valid_algo_prefix):])
        if algo_num_value < min_algo_num or algo_num_value > max_algo_num:
            print(f"\033[0;35m-- algo_num should be between algo{min_algo_num} to algo{max_algo_num}\033[0m")
            return False
    return True

def main():
    print('-- [commit-msg] Checking git-commit-format')
    if len(sys.argv) < 2:
        print("\033[0;35m-- commit message file not provided\033[0m")
        sys.exit(1)
        
    message_file = sys.argv[1]
    try:
        with open(message_file, 'r') as txt_file:
            msg = txt_file.read()
            commit_msg = get_commit_msg(msg)
            if valid_commit_msg(commit_msg):
                print('-- commit format is correct')
                sys.exit(0)
    except FileNotFoundError:
        print(f"\033[0;35m-- commit message file {message_file} not found\033[0m")
        sys.exit(1)

    sys.exit(1)

if __name__ == "__main__":
    main()
