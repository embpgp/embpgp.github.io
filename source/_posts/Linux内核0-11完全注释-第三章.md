---
title: Linux内核0.11完全注释 第三章
date: 2016-11-15 16:46:00
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> 介绍Linux内核0.11版本的编程语言和环境以及目标文件格式等  

<!--more-->

------------


# as86 和 ld86 
- as86 在开发Linux内核时仅用来创建16位的启动引导扇区程序boot/boosect.s和实模式下的初始设置程序boot/setup.s的二进制执行代码.采用Intel格式的汇编指令格式.
 - 汇编的命令行基本格式:`as [选项] -o objfile srcfile`.
 - `=`或`EQU`符号等价于C语言的宏
 - `.`编译过程中的位置计数器,等价于`$`
 - `:`符号,本质为汇编地址
 - 目标文件objfile起码包含三个section,**.text**,**.data**,**.bss**

- as86汇编语言程序例程:
```asm
!
!Filename:boot.s
!
!Description: boot section codes on Intel CPU
!
!Author:rutk1t0r
!
!Data:2016.11.8
!
!GPL
!
!method:
![/root]# as86 -0 -a -o boot.o boot.s    #编译
![/root]# ld86 -0 -s -o boot boot.o      #链接
![/root]# dd bs=32 if=boot of=/dev/fd0 skip=1   #写入软盘或者image文件,跳过文件头
!==================================================================
!
!
! boot.s -- bootsect.s 的框架程序.用代码0x07替换字符串msg1中一个字符,然后在屏幕上1行显示
!
.globl begtext, begdata, begbss, endtext, enddata, endbss !全局标识符,供ld86链接使用
.text  !代码段
begtext:
.data
begdata:
.bss
begbss:
.text
BOOTSEG = 0x07c0   !类似于C语言宏定义,EQU,Intel内存代码执行首地址
entry start        !告知链接程序,程序从start标号开始执行
start:
jmpi	go, BOOTSEG !段间跳转,两个地址,低地址16位送IP寄存器,高地址16位送cs段寄存器
go:
		mov	ax, cs  !将cs段寄存器值同步至ds,es,此代码未用到ss
		mov es, ax
		mov ds, ax
		mov [msg1+17], ah   !示例修改串,然后会调用BIOS中断,参考链接https://zh.wikipedia.org/wiki/INT_10
		mov	cx, #20  		!立即数需要前缀#,根据BIOS提供的接口约定,cx为字符总个数
		mov	dx, #0x1004  	!约定,位置,此时为17行5列
		mov bx, #0x000c    	!约定,字符属性(红色)
		mov bp, #msg1		!约定,字符缓冲区首地址
		mov ax, #0x1301		!ah=0x13表示写字符串功能号
		int 0x10			!调用BIOS中断
loop1:  jmp 	loop1  		!死循环待机
msg1:	.ascii	"Loading system..." !字符20个,包括回车换行
		.byte 	13,10
.org	510					!表示以后的语句从偏移地址510开始放
		.word 	0xAA50		!有效引导扇区标志,约定
.text
endtext:
.data
enddata:
.bss
endbss:

```
 - 可参照如下命令进行编译链接等
 ![Linux_0.11_chapter3_as86_compile.png](/images/Linux_0.11_chapter3_as86_compile.png)
 - 本应该512字节的boot程序(MBR)多出32字节为MINIX可执行文件头结构,需剔除掉(dd命令等).而后可用Bochs等模拟器观察现象,正常如下:
 ![Linux_0.11_chapter3_as86_boot.png.png](/images/Linux_0.11_chapter3_as86_boot.png.png)
- **as86具体使用方法:**
![Linux_0.11_chapter3_as86.png](/images/Linux_0.11_chapter3_as86.png)
- **ld86具体使用方法:**
![Linux_0.11_chapter3_ld86.png](/images/Linux_0.11_chapter3_ld86.png)

# GNU as汇编
- 内核中其余所有汇编语言程序(包括C语言产生的汇编程序)均由gas来编译,并与C语言程序编译产生的模块进行链接. 
- **Intel格式的汇编与AT&T格式的汇编区别:**
![Linux_0.11_chapter3_Intel_AT&T_diff.png](/images/Linux_0.11_chapter3_Intel_AT&T_diff.png)
- as汇编器对汇编语言程序只进行简单地预处理,比如调整并删除多余空格和制表符,删除注释等;如需要进行宏替换则可以让汇编语言程序使用大写后缀'.S'来让as使用gcc的CPP预处理功能.
- 具体关于汇编指令部分可以参考Intel开发者手册
## 区和重定位
 - 区:有时候也成为段,节或部分,英文为section,用来表示一个地址范围,操作系统将会以相同的方式对待和处理改地址范围的数据信息.
 - 重定位:当汇编过后的数据中出现重定位节时候,由链接器负责修正重定位的数据部分(至于为什么会需要重定位这与很多机制有关系了,必须虚拟内存等).
## 链接器涉及的区:
 ![Linux_0.11_chapter3_linker_section.png](/images/Linux_0.11_chapter3_linker_section.png)
- 关于gcc对于C程序的编译和链接过程可参考[前文](http://www.rutk1t0r.org/2016/09/06/C%E8%AF%AD%E8%A8%80%E5%AE%8F%E5%AE%9A%E4%B9%89%E5%B0%8F%E8%AF%95/)
## 嵌入汇编
 - 格式：
	```asm
	asm("汇编语句"
		:输出寄存器
		:输入寄存器
		:会被修改的寄存器);
	```
 - 嵌入汇编的好处就是利用gcc的灵活性在C语言里面精练地实现某些特定功能
 - Linux内核源码中仍然在使用圆括号的组合语句，一般用在宏定义。
 - strcpy的嵌入汇编实现如下，因为首先要进行预处理，所以增加换行便于浏览。
	```C
	//将字符串(src)拷贝到另一字符串(dest)，直到遇到NULL字符后终止
	//参数:dest - 目的字符串指针, src - 源字符串指针, %0 - esi(src), %1 - edi(dest)。
	extern inline char *strcpy(char *dest, const char *src)
	{
	__asm__("cld\n"			//清空方向标志，往上为默认增长
			"1:\tlodsb\n\t" //加载DS:[esi]处1字节->al,esi++
			"stosb\n\t"		//存储al->ES:[edi],edi++
			"testb %%al, %%al\n\t"	//测试刚刚存储是否为NULL字符
			"jne 1b"		//不是则继续跳到标号1处，否则就结束
			::"S"(src), "D"(dest)":"si","di","ax");
	return dest;			//返回目的字符串首地址，实现链式
	}
	```
 - 嵌入汇编加载代码
 ![Linux_0.11_chapter3_emb_asm_load_code1.png](/images/Linux_0.11_chapter3_emb_asm_load_code1.png)
 ![Linux_0.11_chapter3_emb_asm_load_code2.png](/images/Linux_0.11_chapter3_emb_asm_load_code2.png)
## C与汇编的相互调用
- 调用约定(主要根据参数顺序、传参方式以及平衡堆栈者等来区分,当然其他体系结构也有其他实现,这里主要是IA-32体系,Intel 64调用约定已经开始大幅度使用寄存器传参)
  - fastcall:Linux系统调用比较常用，直接利用寄存器传参，子程序(被调用者)清除栈帧
  - __cdecl:参数从右至左压栈，由调用者负责清除栈空间，可变参数
  - stdcall:Windows的Win32 API常用，与__cdecl区别是被调用者一般用类似`ret n`指令来清除栈空间(清除栈空间主要是恢复被保存的寄存器值以及栈指针回归)
  - PASCAL:从左到右压栈，被调用者清栈
  - this:C++标准的Microsoft实现利用ecx传递对象首地址
- 在软件工程师的角度,以汇编语言作为"车轮子"和"底线"完全可以应付了绝大多数的问题了，因此只要源代码汇编过后保持一致性，各种语言之间的相互调用都是可以的。


# Linux 0.11目标文件格式


> 有关目标文件和链接程序的基本工作原理可参见John R.Levine著的《Linkers & Loaders》(有中文译版）一书。

## a.out映像
- 在Linux 0.11系统中，GNU gcc或者gas编译输出的目标模块文件和链接程序所生成的可执行文件都使用了UNIX传统的a.out格式。对于具有内存分页机制的系统(可由硬件芯片给予软件以支持）来说，这是一种简单有效的目标文件格式。
![Linux_0.11_chapter3_a.out_map.png](/images/Linux_0.11_chapter3_a.out_map.png)
![Linux_0.11_chapter3_a.out_map_header1.png](/images/Linux_0.11_chapter3_a.out_map_header1.png)
![Linux_0.11_chapter3_a.out_map_header2.png](/images/Linux_0.11_chapter3_a.out_map_header2.png)
- Linux内核可执行文件加载器将可执行文件从磁盘加载到内存中的映像
![Linux_0.11_chapter3_a.out_map_to_memory.png](/images/Linux_0.11_chapter3_a.out_map_to_memory.png)
- 链接程序的操作
![Linux_0.11_chapter3_a.out_linkers.png](/images/Linux_0.11_chapter3_a.out_linkers.png)

## 链接程序预定义变量
- 在链接过程中，链接器ld和ld86会使用自身的变量记录下执行程序中每个段的逻辑地址。因此可以在程序用通过几个外部变量来获取程序中段的位置。
 - _etext(etext):它的地址是.text段结束后的第一个地址;
 - _edata(edata):它的地址是.data初始化数据区后的第一个地址;
 - _end(end):它的地址是未初始化数据区.bss后的第一个地址位置。
 - 带下划线前缀和不带是等价的，唯一的区别在ANSI、POSIX等标准中没有定义符号etext、edata和end。
 - Linux 0.1x 内核在初始化块设备高速缓存区时(fs/buffer.c)， 就使用了变量_end来获取内核映像文件Image在内存中的末端后的位置，并从这个位置起开始设置高速缓冲区。

- 利用System.map文件可以找寻到**目标文件及符号信息映射到内存的位置**、**公共符号设置**、**链接中包含的所有文件成员以及其引用的符号**和**内核运行错误信息及调试**。
 - 目标文件符号列表文件中的符号类型
 ![Linux_0.11_chapter3_a.out_symbol1.png](/images/Linux_0.11_chapter3_a.out_symbol1.png)
 ![Linux_0.11_chapter3_a.out_symbol2.png](/images/Linux_0.11_chapter3_a.out_symbol2.png)

# Make 和 Makefile
- make程序通过Makefile文件知道如何编译和链接程序
- make的执行过程为两个阶段。
 - 读取**所有的**Makefile文件以及包含的Makefile文件等，记录所有的变量及值、隐式的或显式的规则，并构造出所有目标对象及其先决条件的一幅全景图;
 - make就使用这些内部结构来确定哪个目标对象需要被重建，并且根据相应的规则来操作。
- 当make重新编译程序的时，每个修改过的C代码文件(根据文件时间戳)必须被重新编译。如果头文件被修改过了，那么为了保证正确，make也会重新编译每个包含此头文件的C代码文件。

# 总结
- 基本的开发环境需要搭建和理解
- 汇编语言在Linux内核中的重要性
- 目标文件格式基本格式需理解(PE更复杂)
- 链接器的高级特效需理解
- Makefile高级用法需要会用

