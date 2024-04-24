## 功能说明
    Given an ELF file, copy all its dependent files to a specified directory and modify the information of all its dependent dynamic libraries to the specified directory, especially modifying the dependencies of libc and the loader.
    
    给定一个elf文件，将其依赖的文件都拷贝到指定目录，并且修改其所有依赖的动态库的信息到指定目录，特别是修改libc和装载器的依赖。
    
    可用于将高版本系统中的可执行程序迁移到低版本的系统上运行。例如将centos 7上的部分程序迁移到centos 6上。

## 启发
  https://superuser.com/questions/1144758/overwrite-default-lib64-ld-linux-x86-64-so-2-to-call-executables
  
  overwrite default /lib64/ld-linux-x86-64.so.2 to call executables。

  patchelf工具提供了对elf文件的各种修改能力。

## 使用方法
### 帮助
```bash
[root@localhost linux_mk_selfdeps_run]# ./mk_selfdeps_run.sh -h
Desc:
  解除elf文件的依赖，变成可以独立运行的程序(依赖指定目录下的动态库)。
  可用于将高版本系统中的可执行程序迁移到低版本的系统上运行。
Usage:
  mk_selfdeps_run.sh -f path/to/elf [-r path/to/fake/root] [-e path/to/extlibs/descfile]
    extlibs formart(one line one lib path):
      /lib64/libresolv.so.2
      /lib64/libnsl.so.1
      #/lib64/libc.so.6
```

### 生成
```bash
# 转移依赖
# fake root默认放置在运行目录下：fake_root
./rm_ext_deps.sh -f /usr/bin/htop
# 将fake root设置为/home/test_root
./mk_selfdeps_run.sh -f /usr/bin/htop -r /home/test_root
# 指定外部库（例如指定运行时加载动态库的程序）
./mk_selfdeps_run.sh -f /usr/bin/htop -e externlibs_example.txt
#运行程序
./htop
```