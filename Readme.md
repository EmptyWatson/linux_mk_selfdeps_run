
## 功能说明
Building elf programs that depend on themselves. Given an ELF file, copy all its dependent files to a specified directory and modify the information of all its dependent dynamic libraries to the specified directory, especially modifying the dependencies of libc and the ld loader.

构建自依赖elf程序。给定一个elf文件，将其依赖的文件都拷贝到指定目录，并且修改其所有依赖的动态库的信息到指定目录，特别是修改libc和ld装载器的依赖。

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

生成后的文件结构
```bash
[root@localhost linux_mk_selfdeps_run]# tree /home/test_root/
/home/test_root/
└── lib64
    ├── ld-2.17.so
    ├── ld-linux-x86-64.so.2 -> ld-2.17.so
    ├── libc-2.17.so
    ├── libc.so.6 -> libc-2.17.so
    ├── libdl-2.17.so
    ├── libdl.so.2 -> libdl-2.17.so
    ├── libgcc_s-4.8.5-20150702.so.1
    ├── libgcc_s.so.1 -> libgcc_s-4.8.5-20150702.so.1
    ├── libm-2.17.so
    ├── libm.so.6 -> libm-2.17.so
    ├── libncursesw.so.5 -> libncursesw.so.5.9
    ├── libncursesw.so.5.9
    ├── libtinfo.so.5 -> libtinfo.so.5.9
    └── libtinfo.so.5.9

1 directory, 14 files

[root@localhost linux_mk_selfdeps_run]# ldd ./htop 
	linux-vdso.so.1 =>  (0x00007ffce4101000)
	libncursesw.so.5 => /home/test_root/lib64/libncursesw.so.5 (0x00007fc2046f5000)
	libtinfo.so.5 => /home/test_root/lib64/libtinfo.so.5 (0x00007fc2044c9000)
	libm.so.6 => /home/test_root/lib64/libm.so.6 (0x00007fc2041c4000)
	libgcc_s.so.1 => /home/test_root/lib64/libgcc_s.so.1 (0x00007fc203fad000)
	libc.so.6 => /home/test_root/lib64/libc.so.6 (0x00007fc203bdb000)
	libdl.so.2 => /home/test_root/lib64/libdl.so.2 (0x00007fc2039d6000)
	/home/test_root/lib64/ld-linux-x86-64.so.2 => /lib64/ld-linux-x86-64.so.2 (0x00007fc204930000
```