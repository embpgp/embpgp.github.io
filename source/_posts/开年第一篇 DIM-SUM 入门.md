---
title: DIM-SUM学习
date: 2022-01-16 19:35:40
categories:
- study
tags:
- DIM-SUM
- OS内核
---

> DIM-SUM内核学习,先跑起来吧。

<!--more-->
--- 
**参考资料**
- [DIM-SUM仓库](https://gitee.com/xiebaoyou/dim-sum)
---

# 缘由
之前很早有关注过作者，后面逐渐听说有设计操作系统内核的计划，今年偶然听说出了一本新书，就买来学习了。

# 跑起来
拿到书籍后里面有读者服务的二维码，所以就从那里面先拿到了源码包以及《答案.docx》。后续可以直接参考gitee上的教程跑。
## 编译
> 编译少库的问题自行搜索解决即可，我的系统是ubuntu 20.04
```bash
rutk1t0r@ubuntu:~/dev/dim-sum/dim-sum/src$ ./build.sh 
  CHK     include/linux/version.h
  CHK     include/generated/utsrelease.h
  CALL    scripts/checksyscalls.sh
grep: scripts/../arch/x86/syscalls/syscall_32.tbl: No such file or directory
  CHK     include/generated/compile.h
  CC      kernel/sched/core.o
  LD      kernel/sched/built-in.o
  LD      kernel/built-in.o
  LD      vmlinux.o
  MODPOST vmlinux.o
WARNING: modpost: Found 20 section mismatch(es).
To see full details build your kernel with:
'make CONFIG_DEBUG_SECTION_MISMATCH=y'
  GEN     .version
  CHK     include/generated/compile.h
  UPD     include/generated/compile.h
  CC      init/version.o
  LD      init/built-in.o
  LD      .tmp_vmlinux1
  KSYM    .tmp_kallsyms1.S
  AS      .tmp_kallsyms1.o
  LD      .tmp_vmlinux2
  KSYM    .tmp_kallsyms2.S
  AS      .tmp_kallsyms2.o
  LD      vmlinux
  SYSMAP  System.map
  SYSMAP  .tmp_System.map
  OBJCOPY arch/arm64/boot/Image
  Kernel: arch/arm64/boot/Image is ready
rutk1t0r@ubuntu:~/dev/dim-sum/dim-sum/src$ 
```
## 运行
```bash
rutk1t0r@ubuntu:~/dev/dim-sum/dim-sum/src$ ./run.sh 
WARNING: Image format was not specified for './dim-sum.img' and probing guessed raw.
         Automatically detecting the format is dangerous for raw images, write operations on block 0 will be restricted.
         Specify the 'raw' format explicitly to remove the restrictions.
W: /etc/qemu-ifup: no bridge for guest interface found
simple console is ready.
timer_rate is 62500000.
io scheduler noop registered(default)
xby_debug in virtio_mmio_setup, 1, 554d4551.
xby_debug in virtio_mmio_setup, 2, 554d4551.
xby_debug in virtio_dev_match, id->vendor:-1, id->device:2.
xby_debug in virtio_dev_match, dev->vendor:1431127377, dev->device:2.
xby_debug in virtblk_probe, vda
......
LWIP-1.4.1 TCP/IP initialized.
xby_debug in __cpu_launch, 1.
xby_debug in psci_launch_cpu, pa is 0000000040158020.
xby_debug in __cpu_launch, 2.
xby_debug in psci_launch_cpu, pa is 0000000040158020.
xby_debug in __cpu_launch, 3.
xby_debug in psci_launch_cpu, pa is 0000000040158020.
	                                                    
	##############################################
	#                                            #
	#  *   *   ***   *****  ****    ***   *****  #
	#  *   *  *   *    *    *   *  *   *    *    #
	#  *   *  *   *    *    *   *  *   *    *    #
	#  *****  *   *    *    ****   *   *    *    #
	#  *   *  *   *    *    *      *   *    *    #
	#  *   *  *   *    *    *      *   *    *    #
	#  *   *   ***     *    *       ***     *    #
	#                                            #
	##############################################
	                                              
[dim-sum@hot pot]# xby_debug in task2, enter
xby_debug in task1, enter

```
![DIM-SUM_shell_ps.png](/images/DIM-SUM_shell_ps.png)

> 这里是修改过后的代码，将通过creat_process实现执行子命令

# 展望

* 实现sys_wait4回收task_struct等更丰富的接口实现
* 支持x86等更丰富的arch
* 用户态程序
* 理解作者的问题和《答案.docx》
* ...

