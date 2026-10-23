#!/usr/bin/python3

import sys
import re

types = ('[feat]', '[fix]', '[perf]', '[refactor]', '[ci]', '[tool]', '[docs]', '[test]')

#get header
def get_commit_msg(msg):
    res = re.search("\n", msg)
    if(res == None):
        return msg
    else:
        return msg[0:res.span()[0]]

def valid_commit_msg(commit_msg, msg):
    res = re.match(r'(?P<type>\[\w+\])(?P<colon>:)(?P<subject> *\w+)', commit_msg)
    if res == None:
        print("\033[0;35m-- please input standard format for commit: {[type]: <subject> }\033[0m")
        print("\033[0;35m-- the type should be one of: 'feat', 'fix', 'perf', 'refactor', 'ci', 'tool', 'docs', 'test' \033[0m")
        return False
    else:
        msg_type = res.groupdict()['type'].lstrip().rstrip()
        if msg_type not in types:
            print("\033[0;35m-- type not match, the type should be one of: 'feat', 'fix', 'refactor', 'ci', 'tool', 'doc', 'test' \033[0m")
            print("\033[0;35m-- please input standard format for commit: {[type]: <subject> }\033[0m")
            return False
    return True

def main():
    print('-- [commit-msg] Checking git-commit-format')
    message_file = sys.argv[1]
    txt_file = open(message_file, 'r')
    msg = txt_file.read()
    commit_msg = get_commit_msg(msg)
    if(valid_commit_msg(commit_msg, msg)):
        print('-- commit format is correct')
        sys.exit(0)
    sys.exit(1)

if __name__ == "__main__":
    main()