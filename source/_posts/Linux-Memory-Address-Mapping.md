---
title: Linux_Memory_Address_Mapping
date: 2017-10-14 18:49:21
categories:
- study
tags:
- Linux kernel
- LDD
---

>  主要根据[www.ilinuxkernel.com](http://www.ilinuxkernel.com)站点上的同名pdf文档做实验分析

<!--more-->

-------------------------------------


参考:[https://jin-yang.github.io/post/kernel-memory-virtual-physical-map.html](https://jin-yang.github.io/post/kernel-memory-virtual-physical-map.html)
[https://stackoverflow.com/questions/8516021/proc-create-example-for-kernel-module](https://stackoverflow.com/questions/8516021/proc-create-example-for-kernel-module)
[http://www.voidcn.com/article/p-zqylmcig-ty.html](http://www.voidcn.com/article/p-zqylmcig-ty.html)
[http://www.cnblogs.com/hoys/archive/2011/04/10/2011261.html](http://www.cnblogs.com/hoys/archive/2011/04/10/2011261.html)

# 体系架构
首先要了解操作系统的内存管理机制,一般都是知道是段页式管理,但是各个处理器架构提供的机制有所不同,主要由处理器中mmu部件负责翻译,操作系统负责管理.特别在intel架构中,完全做到了段页式的实现.但是Linux内核在实现的时候是用技巧越过了段式的地址特性,即逻辑地址=线性地址,但是处理器对于地址转换的有效性的检查不会改变,只是说Linux内核实现比较巧妙.下面就开始实验.

# 环境
原文给我的实验代码是Linux 2.6内核的代码,我特意从网上下载了Centos6.9,之后`yum install kernel-devel.x86_64`安装发行版内核源代码,同时查看`build`目录是否正确链接到内核源码路径,可修改实验代码的Makefile文件的路径使其正确.当然,为了能够使得我PC的Linux 4.x内核也能够做这个实验,我对比了内核代码的改动部分,其中主要是`proc_create`接口变了,然后参考网上demo代码成功实现了迁移.可参考[这里](https://github.com/Iotlab-404/ilinuxkernel/tree/master/kernel/Memory_Address_Mapping).

# 实验
## mem_map
编译好内核模块后insmod两个ko文件,因为我的测试环境为64位,因此修改mem_map.c的部分代码,运行如下:
![ilk_mm_exam.png](/images/ilk_mm_exam.png)
## fileview
这个工具跟内核模块dram.ko挂钩,通过实现了lseek和read文件操作方法来对应用层开放查询进程物理地址信息.具体操作可见代码,其中主要可以按照显示方式为8421字节感觉很有用,若需要输入指定物理地址,按回车即可.
## 开始计算 
### 查看gdt中ds描述符
按照pdf教程,tmp所在段在ds数据段,查看后发现确实段基址为0.
 ![ilk_mm_gdtr.png](/images/ilk_mm_gdtr.png)
### 分解tmp地址为二进制
计算偏移的工具bc,我将其封装了一下,命名为calc.sh,代码在[这里](https://github.com/embpgp/PersonalToolKits/blob/master/shell/calc.sh).tmp地址分解如下:
```bash
root@Rutk1t0r:Memory_Address_Mapping# calc.sh -i 16 -o 2 7FFD0A1330C8
11111111111110100001010000100110011000011001000
root@Rutk1t0r:Memory_Address_Mapping# 
```
应该为分成9 9 9 9 12.
011111111 111110100 001010000 100110011 000011001000
### CR3->一级
```bash
root@Rutk1t0r:Memory_Address_Mapping# calc.sh -i 2 -o 16 8*11111111
7F8
root@Rutk1t0r:Memory_Address_Mapping# 
```
CR3=36082000,一级=36082000+8*011111111b=360827F8
![ilk_mm_cr3-one.png](/images/ilk_mm_cr3-one.png)
### 一级->二级
```bash
root@Rutk1t0r:Memory_Address_Mapping# calc.sh -i 2 -o 16 8*111110100
FA0
root@Rutk1t0r:Memory_Address_Mapping# 
````
一级=391B8000,二级=391B8000+8*111110100=391B8FA0
![ilk_mm_one-two.png](/images/ilk_mm_one-two.png)
### 二级->三级
二级=3D817000,三级=3D817000+8*001010000=3D817280
```bash
root@Rutk1t0r:rutk1t0r# calc.sh -i 2 -o 16 8*001010000
280
root@Rutk1t0r:rutk1t0r#
```
![ilk_mm_two-three.png](/images/ilk_mm_two-three.png)
### 三级->四级
```bash
root@Rutk1t0r:Memory_Address_Mapping# calc.sh -i 2 -o 16 8*100110011
998
root@Rutk1t0r:Memory_Address_Mapping#
```
三级=3B04B000,四级=3B04B000+8*100110011=3B04B998
![ilk_mm_three-four.png](/images/ilk_mm_three-four.png)
### 四级->真实物理地址(值)
四级=27D0F000,phy_addr=27D0F000+0c8=27D0F0C8.
![ilk_mm_four-phy.png](/images/ilk_mm_four-phy.png)
 而mem_map.c代码如下:
 ```C
 [root@localhost mm_addr]# cat mem_map.c 
 #include <stdio.h>
 #include <stdlib.h>
 #include <unistd.h>
 #include <fcntl.h>

 #define REGISTERINFO "/proc/sys_reg"
 #define BUFSIZE  4096

 static char buf[BUFSIZE];
 static unsigned long addr;

 #define FILE_TO_BUF(filename, fd) do{	\
	static int local_n;	\
	if (fd == - 1 && (fd = open(filename, O_RDONLY)) == - 1) {	\
	fprintf(stderr, "Open /proc/register file failed! \n");	\
	fflush(NULL);	\
	_exit(102);	\
	}	\
	lseek(fd, 0L, SEEK_SET);	\
	if ((local_n = read(fd, buf , sizeof buf -  1)) < 0) {	\
	perror(filename);	\
	fflush(NULL);	\
	_exit(103);	\
	}	\
	buf [local_n] = 0;	\
 }while(0)



 int main()
 {
	unsigned long tmp;
	tmp = 0x12345678deadbeef;
	static int cr_fd = - 1;

	asm("movq %rbp, %rbx\n movq %rbx, addr");

	printf("\n%%rbp:0x%08lX\n", addr);
	printf("tmp address:0x%08lX\n", &tmp);
	FILE_TO_BUF(REGISTERINFO, cr_fd);

	printf("%s", buf );

	while(1);

	return 0;
 }

[root@localhost mm_addr]# 

```
成功通过段页式翻译找到tmp对应的值为0x12345678deadbeef.

# 总结
通过实验加深理解,如有时间可再深入研究物理地址映射的实现.