import argparse
import os
import glob
import shutil
import re
import sys

parser = argparse.ArgumentParser(description='Script configuration')
parser.add_argument('--profraw_dir', type=str, default='.', help='Directory containing profraw files')
parser.add_argument('--obj_dir', type=str, default='../../../../build/lib/', help='Directory containing object files')
parser.add_argument('--output_dir', type=str, default='./output', help='Output directory for coverage results')
parser.add_argument('--ignore_filename', nargs='+', default=None, help='File names to be ignored, enclosed in double quotes and separated by spaces')
parser.add_argument('--branch_coverage', action='store_true', help='Whether to display branch coverage')
parser.add_argument('--name', type=str, default=None, help='File names that show code coverage')

args = parser.parse_args()
profraw_dir = args.profraw_dir
obj_dir = args.obj_dir
output_dir = os.path.abspath(args.output_dir)
ignore_filename = args.ignore_filename
branch_coverage = args.branch_coverage
name = args.name

print("profraw_dir:", profraw_dir)
print("obj_dir:", obj_dir)
print("output_dir:", output_dir)
print("ignore_filename:", ignore_filename)
print("branch_coverage:", branch_coverage)
print("name:", name)

def check_dir():
    if not os.path.exists(profraw_dir):
        raise Exception("profraw_dir does not exit")
    if not os.path.exists(obj_dir):
        raise Exception("obj_dir does not exit")

    profraw_files = glob.glob(f"{profraw_dir}/*.profraw")
    group_profraw_files = glob.glob(f"{profraw_dir}/group_*/*.profraw")
    profraw_files = profraw_files + group_profraw_files
    if not profraw_files:
        raise Exception("profraw not found")
    obj_files = glob.glob(f"{obj_dir}/*.o")
    if not obj_files:
        raise Exception("obj not found")

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    if not os.path.exists(f"{output_dir}/html"):
        os.makedirs(f"{output_dir}/html")

def merge_profdata():
    profraw_files = glob.glob(f"{profraw_dir}/*.profraw")
    group_profraw_files = glob.glob(f"{profraw_dir}/group_*/*.profraw")
    profraw_files = profraw_files + group_profraw_files
    num_profraw_files = 0
    for file in profraw_files:
        if file.count('.profraw') > 1:
            os.remove(file)
            print(f"delete: {file}")
        else:
            num_profraw_files += 1
    print("num_profraw_files:", num_profraw_files)
    if num_profraw_files < 1:
        print("raw profile not found")
        raise Exception("raw profile not found")
    elif num_profraw_files < 2000:
        command = f"tecoprofdata merge {profraw_dir}/*.profraw -o {output_dir}/merged.profdata --sdaa-device-only --failure-mode=all"
        ret_code = os.system(command)
        if ret_code != 0:
            raise Exception(command, "failed")
        profraw_files_1 = glob.glob(f"{profraw_dir}/*.profraw")
        for file in profraw_files_1:
            if file.count('.profraw') > 1:
                os.remove(file)
    else:
        if num_profraw_files < 20000:
            range_limit = 10
        else:
            range_limit = 100
        for group_index in range(range_limit):
            folder_path = f"{profraw_dir}/group_{group_index}"
            os.makedirs(folder_path, exist_ok=True)
        files = os.listdir(profraw_dir)
        for file in files:
            if file.endswith(".profraw"):
                if num_profraw_files < 20000:
                    group_index = int(file.split('-')[2][-1])
                else:
                    group_index = int(file.split('-')[2][-2:])
                src_path = os.path.join(profraw_dir, file)
                dest_path = f"{profraw_dir}/group_{group_index}/{file}"
                shutil.move(src_path, dest_path)

        for group_index in range(range_limit):
            print("processing the", group_index, "th profraw dir")
            command = f"tecoprofdata merge {profraw_dir}/group_{group_index}/*.profraw -o {output_dir}/merged_{group_index}.profdata --sdaa-device-only --failure-mode=all"
            ret_code = os.system(command)
            if ret_code != 0:
                raise Exception(command ,"failed")
            profraw_files_1 = glob.glob(f"{profraw_dir}/group_{group_index}/*.profraw")
            for file in profraw_files_1:
                if file.count('.profraw') > 1:
                    os.remove(file)
        command = f"tecoprofdata merge {output_dir}/merged_*.profdata -o {output_dir}/merged.profdata --failure-mode=all"
        ret_code = os.system(command)
        if ret_code != 0:
            raise Exception(command, "failed")
    print("Merge profdata Success!")

def generate_single_info():
    for root, dirs, files in os.walk(obj_dir):
        for file in files:
            if file.endswith(".o"):
                file_path = os.path.join(root, file)
                file_name = os.path.splitext(os.path.basename(file_path))[0]
                command = f"tecocov export {file_path} --instr-profile={output_dir}/merged.profdata --sdaa-device-only --input-profdata -format=lcov > {output_dir}/coverage_{file_name}.info"
                ret_code = os.system(command)
                #if ret_code != 0:
                    #raise Exception(command, "failed")
    print("Generate single info Success!")

def merge_info():
    functions_in_all_files = set()
    content_all=""
    for filename in os.listdir(output_dir):
        print(filename)
        if filename.startswith("coverage_") and filename.endswith(".info"):
            filepath = os.path.join(output_dir, filename)
            with open(filepath, "r") as file:
                content = file.read()
                lines = content.split('\n')
                pattern=[]
                for line in lines:
                    if line.startswith('SF'):
                        function_name = line[3:]
                        if ignore_filename:
                            for ignore_file in ignore_filename:
                                if ignore_file in function_name:
                                    pattern = re.escape(line) + r"(?:[\s\S]*?)end_of_record\n"
                                    content = re.sub(pattern, "", content)
                        if name:
                            if name not in function_name:
                                pattern = re.escape(line) + r"(?:[\s\S]*?)end_of_record\n"
                                content = re.sub(pattern, "", content)
                        if function_name in functions_in_all_files:
                            pattern = re.escape(line) + r"(?:[\s\S]*?)end_of_record\n"
                            content = re.sub(pattern, "", content)
                        elif ".h" not in function_name:
                            functions_in_all_files.add(function_name)
                content_all += content
    merged_info_file_path = os.path.join(output_dir, "merged.info")
    with open(merged_info_file_path, "w") as file:
        file.write(content_all)

    print("Merge info Success!")

def generate_html():
    if branch_coverage:
        command = f"genhtml {output_dir}/merged.info --branch-coverage -o {output_dir}/html"
    else:
        command = f"genhtml {output_dir}/merged.info -o {output_dir}/html"
    ret_code = os.system(command)
    if ret_code != 0:
        raise Exception(command, "failed")
    print("Genhtml Success!")


try:
    check_dir()
    merge_profdata()
    generate_single_info()
    merge_info()
    generate_html()
except Exception as e:
    print("An error occurred:", str(e))
    sys.exit(1)
