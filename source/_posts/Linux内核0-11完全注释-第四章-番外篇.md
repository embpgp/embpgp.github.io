---
title: Linux内核0.11完全注释 第四章-番外篇
date: 2016-11-22 20:19:15
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> 本篇将根据实战经验来构建这个简单的多任务内核的运行

--------------------------


# Bochs安装和配置
- 通过Debian或者RHEL的包管理器直接安装或者源码安装都可以，网上多建议源码安装，说可以开启调试和反汇编功能，我发现都差不多，至于Win平台的直接点击点击即可。
- 按照网上的一些教程将拷贝一份配置文件或者直接文本新建一个，将**romimage**和**vgaromimage**的路径配置好，我的配置如下，删除了很多没啥用的。看启动文件可知道仅仅需要一个设备即可完成。**Image**是后面编译链接后用dd命令写入的文件。
```bash
romimage: file=$BXSHARE/BIOS-bochs-latest
megs: 16
vgaromimage: file=/usr/local/share/bochs/VGABIOS-lgpl-latest
floppya: 1_44=Image, status=inserted
boot: a
log: bochsout.txt
```


# 生成启动文件
- 首先由于我没有Get到原网站的资料，只好硬着头皮根据书本的后面章节来推敲了。
　![Linux_0.11_chapter4_make_by_heself.png](/images/Linux_0.11_chapter4_make_by_heself.png)
- 我根据上图自己"凑合着"编写Makefile文件。
 ```bash
rutk1t0r@Rutk1t0r:example_for_multi_tasks$ cat Makefile 


Image: boot system
	dd bs=32 if=boot of=Image skip=1
	dd bs=1 if=system of=Image skip=4096 seek=512   #必须指出这里的错误，skip偏移量是0x1000，不是1024

boot: boot.o
	ld86 -0 -s -o $@ $<
boot.o: boot.s
	as86 -0 -a -o $@ $<

system: head.o
	ld -m elf_i386 -Ttext 0 -e startup_32 -s -x -M $< -o $@ > System.map
head.o: head.s
	as -32 -o $@ $<

disk:
	dd bs=8192 if=Image of=/dev/fd0
	sync;sync;sync

clean:
	-rm -rf *.o boot system System.map Image
rutk1t0r@Rutk1t0r:example_for_multi_tasks$
rutk1t0r@Rutk1t0r:example_for_multi_tasks$ make clean
rm -rf *.o boot system System.map Image
rutk1t0r@Rutk1t0r:example_for_multi_tasks$ make
as86 -0 -a -o boot.o boot.s
ld86 -0 -s -o boot boot.o
as -32 -o head.o head.s
ld -m elf_i386 -Ttext 0 -e startup_32 -s -x -M head.o -o system > System.map
dd bs=32 if=boot of=Image skip=1
记录了16+0 的读入
记录了16+0 的写出
512 bytes copied, 0.00025786 s, 2.0 MB/s
dd bs=1 if=system of=Image skip=4096 seek=512   #必须指出这里的错误，skip偏移量是0x1000，不是1024
记录了4996+0 的读入
记录了4996+0 的写出
4996 bytes (5.0 kB, 4.9 KiB) copied, 0.0211415 s, 236 kB/s
rutk1t0r@Rutk1t0r:example_for_multi_tasks$
 ```
- 由于我们这个**多任务内核例子**并不需要文件系统，仅仅只是模拟一下保护模式下的各种机制，因此bochs的配置文件可以直接设置为软盘启动并直接配置**Image**为启动文件。这里需要说明的是如果直接照着Makefile文件的来dd，参数skip是有问题的，我当时为了编译能够通过从网上找了很多参数，可能原文编译的情况不同吧。由于elf文件格式的缘故必须去掉它的头部,用工具查看得知代码段偏移量在0x1000，所以我为了简单好看就每次单字节的写入了4096次。不想自个儿敲以及稍微详细点的注释请参考[这里](https://github.com/embpgp/Linux_kernel_0.11_examples/tree/master/chapter4/example_for_multi_tasks)


# 奔跑吧，小内核~~~
- 
