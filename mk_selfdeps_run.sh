#!/bin/bash
#

SCRIPT=`realpath $0`
SCRIPTDIR=`dirname $SCRIPT`
CUR_DIR=`pwd`
elf_file=""
fake_root_dir="fake_root"
externlibs_list_path=""
script_base_name=`basename $0`
cur_script_base_name=$script_base_name

# map拼接函数
function join_map_keys {
  eval "declare -A map="${1#*=}
  local demli="$2"
  local keys_string=""  # 初始化字符串

  # 遍历关联数组的键
  for key in "${!map[@]}"
  do
    # 拼接键到字符串
    if [ -z "$keys_string" ]; then
      keys_string="$key"
    else
      keys_string="$keys_string:$key"
    fi
  done

  # 返回拼接后的字符串
  echo "$keys_string"
}


# 定义合并关联数组的函数
function merge_map() {
  eval "declare -A map1="${1#*=}
  eval "declare -A map2="${2#*=}

  for key in "${!map2[@]}"; do
        map1["$key"]="${map2[$key]}"
  done
  merged_str=$(declare -p map1)
  echo "$merged_str"
}


# 打印map
function print_map() {
  local promt="$2"
  local idx=0
  eval "declare -A map="${1#*=}
  for key in "${!map[@]}"; do
    ((idx++))
    echo "$promt[$idx] $key=${map[$key]}"
  done
}


# 拷贝文件(保持目录结构)
# $1 原始文件路径
# $2 拷贝的目标路径
#   如果src文件是符号连接，还需要拷贝原始文件
function copy_file {
  local src_file="$1"
  local root_dir="$2"
  local old_dir=$(dirname $src_file)  
  local dst_dir="$root_dir""$old_dir"
  dst_path="$root_dir""$src_file" 
  echo "    copy $src_file => $dst_dir"
  if [ -f "$src_file" ]; then
    # 创建目录
    mkdir -p $dst_dir
    # 拷贝文件(软连接和源文件)到fakeroot
    rm -rf $dst_path
    cp -a "$src_file" "$dst_dir"
    # 如果是符号文件，需要拷贝原始文件
    if [ -L "$src_file" ]; then
      sym_org_name=$(ls -l $src_file | awk '{print $11}')
      sym_org_path="$old_dir/$sym_org_name"
      dst_path="$root_dir""$sym_org_path"
      echo "    link file $sym_org_path => $dst_path"
      rm -rf $dst_path
      cp -a "$sym_org_path" "$dst_path"
    fi
  fi
}

function print_help {
  echo "Desc:"
  echo "  解除elf文件的依赖，变成可以独立运行的程序(依赖指定目录下的动态库)。"
  echo "  可用于将高版本系统中的可执行程序迁移到低版本的系统上运行。"
  echo Usage:
  echo "  $cur_script_base_name -f path/to/elf [-r path/to/fake/root] [-e path/to/extlibs/descfile]"
  echo "    extlibs formart(one line one lib path):"
  echo "      /lib64/libresolv.so.2"
  echo "      /lib64/libnsl.so.1"
  echo "      #/lib64/libc.so.6"  
}

if ! command -v patchelf &>/dev/null; then
    echo "patchelf could not be found，excute:"
    echo "  yum install patchelf"
    echo "  or"
    echo "  apt install patchelf"
    exit 1
fi

ext_args=""
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--file)
      elf_file="$2"
      shift # past argument
      shift # past value
      ;;
    -r|--rootdir)
      fake_root_dir="$2"
      shift # past argument
      shift # past value
      ;; 
    -e|--externlibs)
      externlibs_list_path="$2"
      shift # past argument
      shift # past value
      ;;        
    -h|--help)
      fake_root_dir="$2"
      shift # past argument
      print_help
      exit 0
      ;;         
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

# 检查参数
if [ ! -f "$elf_file" ]; then
  echo "[ERROR] elf file \"$elf_file\" is not exist"
  print_help
  exit 1
fi

echo "---- copy elf file ----"
elf_file_new="$CUR_DIR/"$(basename $elf_file)
echo "$elf_file => $elf_file_new"
cp -a -rf $elf_file $elf_file_new


# 定义map
declare -A elf_deps_map
declare -A ext_deps_map
declare -A deps_map
declare -A rpath_map

# 创建fake root目录
mkdir -p $fake_root_dir

echo "---- get elf file \"$elf_file_new\" deps ----"
# 从elf中获取依赖
elffile_deps=$(ldd $elf_file_new | grep -v '^$' | sort | uniq)
idx=0
while read -r dep; do
  # 忽略以"linux-vdso.so.1"开头的行
  if [[ $dep == *"linux-vdso"* ]]; then
    continue
  fi
  idx=$((idx+1))
  # 提取名字和路径
  name=$(echo "$dep" | awk '{print $1}')
  # 对于"/lib64/ld-linux-x86-64.so.2"，将其名字改为"ld-linux"
  if [[ "$name" == *"ld-linux"* ]]; then
    path="$name"
    name="ld-linux"
  else
    path=$(echo "$dep" | awk '{print $3}')
  fi

  elf_deps_map["$name"]="$path"
done <<< "$elffile_deps"
#declare -p elf_deps_map 
print_map "$(declare -p elf_deps_map)" "    "

echo "---- get extern libs list file \"$externlibs_list_path\" deps ----"
# 从外部列表中获取依赖
if [ -f "$externlibs_list_path" ]; then
  # 读取文件的每一行，并将其存储到数组中
  while IFS= read -r line; do
    # 忽略以"#"开头的行
    if [[ $line == \#* ]]; then
        continue
    fi
    name=$(basename "$line")
    ext_deps_map["$name"]="$line"
  done < "$externlibs_list_path"
fi
print_map "$(declare -p ext_deps_map)" "    "

echo "---- merge all deps ----"
# 合并map
merged_str=$(merge_map "$(declare -p elf_deps_map)" "$(declare -p ext_deps_map)")
#echo "merged_str: $merged_str"
eval "declare -A merged_deps_map="${merged_str#*=}
#declare -p merged_deps_map
print_map "$(declare -p merged_deps_map)" "    "

echo "---- copy all deps files ----"
# 读取依赖，并拷贝文件
idx=0
interpreter_path=""
interpreter_path_new=""
libc_path=""
libc_path_new=""
for key in "${!merged_deps_map[@]}"
do
  name="$key"
  path="${merged_deps_map[$key]}"
  # 忽略以"linux-vdso.so.1"开头的行
  if [[ $name == *"linux-vdso"* ]]; then
    continue
  fi
  idx=$((idx+1))
  new_path="$fake_root_dir""$path"
  # 对于"ld-linux"，需要特殊标记
  if [[ "$name" == *"ld-linux"* ]]; then
    interpreter_path="$path"
    interpreter_path_new="$new_path"
  elif [[ "$name" == *"libc.so"* ]]; then
    # 获取libc的信息
    libc_path="$path"
    libc_path_new="$new_path"      
  fi

  deps_map["$name"]="$new_path"
  echo "[$idx] $name : $path => $new_path"

  # 组装rpath
  rpath_dir=$(dirname $new_path)
  rpath_map["$rpath_dir"]="1"

  #拷贝文件
  copy_file "$path" "$fake_root_dir"
done


echo "---- check interpreter path ----"
if [ "$interpreter_path" == "" ]; then
  echo "[ERROR] no interpreter"
  exit 1
fi
echo "  get interpreter $interpreter_path => $interpreter_path_new"

# elf文件
echo "---- patch $elf_file_new interpreter ----"
echo "  change  $elf_file_new interpreter $interpreter_path => $interpreter_path_new"
patchelf --set-interpreter "$interpreter_path_new" "$elf_file_new"

# libc文件
echo "---- check libc path ----"
if [ -f "$libc_path_new" ]; then
  echo "  get libc $libc_path => $libc_path_new"
  echo "---- patch $libc_path_new interpreter ----"
  echo "  change  $libc_path_new interpreter $interpreter_path => $interpreter_path_new"
  patchelf --set-interpreter "$interpreter_path_new" "$libc_path_new"
else
  echo "[WARN] no libc"
fi

echo "---- check getted rpaths ----"
rpaths_str=$(join_map_keys "$(declare -p rpath_map)"  ":")
if [ "$rpaths_str" != "" ]; then
  echo "  get rpaths : $rpaths_str"
else
  echo "[WARN] no rpaths"
fi

# 修改elf文件，增加rpath
echo "---- add rpath to $elf_file_new ----"
echo "  current rpath:"
patchelf --print-rpath "$elf_file_new"
echo "  add rpath : $rpaths_str to $elf_file_new"
#patchelf --shrink-rpath --allowed-rpath-prefixes "$fake_root_dir" "$elf_file_new"
patchelf --set-rpath "$rpaths_str" "$elf_file_new"

# 遍历依赖列表，为每个动态库都增加rpath
echo "---- add rpath prefix to all deps files ----"
#declare -p deps_map
idx=0
for key in "${!deps_map[@]}"
do
  # 跳过libc和ld
  if [[ "$key" == *"libc.so"* ]]; then
    continue
  elif [[ "$key" == *"ld-linux"* ]]; then
    continue
  fi
  # 拼接键到字符串
  fpath="${deps_map[$key]}"
  if [ -f "$fpath" ]; then
    idx=$((idx+1))
    echo "  [$idx] add rpath : $rpaths_str to $fpath"
    patchelf --set-rpath "$rpaths_str" "$fpath"
  else
    echo "  [WARN] : $fpath is not exist"
  fi
done

echo "---- [done] ----"
echo "  new elf : $elf_file_new"
echo "  fake root : $fake_root_dir"
