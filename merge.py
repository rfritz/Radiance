import os
import shutil
import sys


def mergefolders(root_src_dir, root_dst_dir):
    for src_dir, dirs, files in os.walk(root_src_dir):
        dst_dir = src_dir.replace(root_src_dir, root_dst_dir, 1)
        if not os.path.exists(dst_dir):
            os.makedirs(dst_dir)
        for file_ in files:
            src_file = os.path.join(src_dir, file_)
            dst_file = os.path.join(dst_dir, file_)
            if os.path.exists(dst_file):
                os.remove(dst_file)
            shutil.copy(src_file, dst_dir)


working_dir = os.getcwd()

ARGS = sys.argv[1:]
# 'C:\\hostedtoolcache\\windows\\perl\\5.30.2\\x64'
PATH = ARGS[0]
print(PATH)


mergefolders(f'{working_dir}\\PAR', PATH)

