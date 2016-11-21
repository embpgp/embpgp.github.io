---
title: Linux内核0-11完全注释 第四章
date: 2016-11-19 21:36:22
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> 介绍Intel 80X86保护模式及其编程

-----------


# 80X86基础知识
## eflags标志寄存器
- 几个系统标志的作用，其中需要说明的IF标志位也是可以控制的，通过汇编指令`sti`和`cli`。需要特权才能执行，否则产生异常。Intel芯片的设计者增加这几个标志位的目的是为了配合操作系统更好地管理系统资源以及安全性的提升，诚然操作系统设计者可以不用理会部分标志，但是有这些硬件机制使得程序流程执行起来更加快速。
![Linux_0.11_chapter4_eflag_sys.png](/images/Linux_0.11_chapter4_eflag_sys.png)  

## 内存管理寄存器
> 由于80386及以后的CPU的主要工作状态均采用保护模式(相对于8086时代的实模式)，其实所谓的保护最主要的还是保护内存，DOS时代的病毒太过于泛滥的主要原因之一是当时8086的内存保护几乎为0。因此真正懂得程序布局和设计的早期hacker可以随意"摆弄"计算机。而保护模式便要大大提高门槛了，把恶意指令限制在CPU内部解决而不直接通过系统总线送往内存控制器。  


### GDTR
- 全局描述符表寄存器，CPU内部，48位，保存GDT的32位线性基地址和16位表长度(字节)
- 使用汇编指令LGDT和SGDT来加载和保存GDTR的内容
- 刚刚上电初始化base为0,len为0xFFFF
- boot阶段进入保护模式过程中必须被赋值,因为一旦进入保护模式便要一直用它

### IDTR
- 中断描述符寄存器,CPU内部，48位，保存IDT的32位线性地址和16位表长度(字节为单位)
- LIDT和SIDT
- 上电同上
- 也是必须被设置，但是初始化过程中可以关闭中断使得如同空设。而后必须填充好。

### LDTR
- 不仅包含和GDTR的48位,还有段属性以及选择子
- 可用于任务切换的局部空间寻址

### TR
- 同上，但描述符部分属性和内容更多

## 控制寄存器
### CRO
- 主要含有控制处理器模式和状态的系统控指标志
- 协处理器的相关控制(浮点计算)
- 保护模式开启和关闭以及分页模式的启毕 

 
### CR1 Intel保留  
  

### CR2 
- 异常的线性地址保存CR2，便于实现虚拟内存


### CR3
- PDBR，高20位为页目录基地址，低12位暂时保留。
- 任务切换时被更新，分页机制的第一基点



# 保护模式内存管理
## 地址变换
![Linux_0.11_chapter4_address_convert.png](/images/Linux_0.11_chapter4_address_convert.png)

## 段的定义
> Intel芯片中的分段机制必须开启，但是软件开发人员可以采用平坦模式，即配置分段机制的各个选择子描述符基址为0，长度为4G，好处是便于后期编程。

### 段描述符
- GDT 
 - 8字节,含段基址，段限长及段属性，可表示(类似继承)成各种段，包括代码段，数据段，tss段等等
 - 由GDTR指向，一般确定后不会更改地址，可以增加项目
　- 第一项约定必须为空
- LDT
 - 属性差不多同上，但只能包含成任务的代码段和数据段等，不包含特殊系统段。
 - 第一项可以用

### 段选择符
![Linux_0.11_chapter4_sector.png](/images/Linux_0.11_chapter4_sector.png)
- 以前的段寄存器并不直接用于寻址，而是提供index，并隐含不可直接操作的Cache部分，只有在切换的时候才更新，加快处理速度。
![Linux_0.11_chapter4_sector_CDEFGS.png](/images/Linux_0.11_chapter4_sector_CDEFGS.png)
- 各个8字节的描述符概括图，主要三个字段的段基址、段限长和段属性一般由编译器、链接器、加载器和操作系统来创建。详细定义参考Intel开发者手册等。开发者需要理解芯片设计者的本意而后根据自己的实际情况来创建。
![Linux_0.11_chapter4_SD_common.png](/images/Linux_0.11_chapter4_SD_common.png)

- 除了代码段、数据段和堆栈段等一般的段还有系统描述符类型，包括LDT、TSS、调用门、中断门、陷阱门和任务门。


### 分页机制
- 作为分段机制的补充和"串联选择",如果不开启则分段过程后地址将直接放在系统总线上。
- 提供OS高级功能虚拟内存的硬件平台。
- 提供加强的内存属性保护
![Linux_0.11_chapter4_address_to_real_address.png](/images/Linux_0.11_chapter4_address_to_real_address.png)
# 各种保护措施
![Linux_0.11_chapter4_protect_for_segment_and_page.png](/images/Linux_0.11_chapter4_protect_for_segment_and_page.png)
## 段级保护
> 所有违反保护的操作都将导致产生一个异常，要么进行异常过程处理，要么down掉Reset。


### 段界限检查
- 主要是GDT、LDT、IDT长度限制和常规描述符的段限长控制
### 段类型检查
> 谈谈绕过方法的个人猜想，当不讨论分页机制时候或者说没有开启分页的时候，分段机制作为最核心的内存保护而存在于CPU内部。诸如下面的保护都是在CPU内部完成的，当我们想要修改内存中数据怎么办呢？首先需要取得所有权限，即0特权级，而后建立新的描述符指向我们想要修改的内存区域(例如某某进程的密码等等),而后即可绕过"他人的防守"径直地向系统总线上发控制信号来读写内存数据。而当其他进程再去操作的时候拿到的东西已经被"掉过包"了。这也是为什么内存攻防中能够提权的漏洞越来越得到重视的原因之一，由于shellcode等已经被"共享"得差不多了，也大同小异。为了获取系统权限，必须不断Fuzzing冲击内存，突破程序逻辑....



- 根据描述符属性字段中的tpye进行匹配
- 当一个描述符的选择符被加进段寄存器时
 - CS寄存器只能被加载进一个可执行段的选择符;
 - 不可读可执行的选择符不能加进数据段选择子;
 - 只有可写数据段才能被加进SS寄存器  
- 当指令访问段时
 - 任何指令不能写一个可执行段
 - 任何指令不能写一个可写位没有置位的数据段
 - 任何指令不能读一个可执行段，除非可执行段设置了可读标志


### 特权级检查
- CPL的值即为CS和SS寄存器的低2位(保护模式中要求任何时候代码段和堆栈段的CPL一致) 
- 关于更详细和细致地代码段特权级检查可参考[代码一致性和非一致性](http://blog.csdn.net/trochiluses/article/details/8968386)
- 数据段中主要是CPL、RPL和DPL的逻辑比较
- 属性字段的匹配


### 指令集限制
- 主要是非特权程序不能执行特权指令


## 页级保护
![Linux_0.11_chapter4_page_check.png](/images/Linux_0.11_chapter4_page_check.png)
# 中断和异常处理
> 硬件机制和软件处理两者完美结合才能完成一个良好的系统的设计

![Linux_0.11_chapter4_interrupt_vector.png](/images/Linux_0.11_chapter4_interrupt_vector.png)
- 把中断看作是另一个控制流程即可,从逻辑上符合人类思考。
- 需要提前填充处理过程的地址，处理器自动加载并跳转执行。
- 中断源来自硬件(INTR和NMI引脚)和软件(指令各种内部错误和主动发起的int n软中断)
- 中断优先级规定
 ![Linux_0.11_chapter4_interrupt_priority.png](/images/Linux_0.11_chapter4_interrupt_priority.png) 
- IDT可以存放三种门描述符
> 这些描述符相当于也只是指针，真正的过程实现不能直接找到,需要继续定位


 - 中断门:含有长指针，即段选择子和偏移，显式调用中断门时候的长指针偏移被忽略，因为此处才是真正的入口地址
 - 陷阱门:同上，但进入后eflags状态寄存器IF标志位不置位
 - 任务门:用于任务切换，作用于tss
- 异常和中断处理过程与以前的差不多，只是会增加更多检查以及切换的时候多压栈更多数据结构和追踪量，并还可以进行任务切换，相当于常规调度了。


# 任务管理
- 任务有多种叫法，也可叫进程，是相对于程序而言的。针对磁盘上(或更泛统称非易失性存储器)和内存中(CPU可直接寻址并进行取指译码执行过程的存储单元)目标文件的布局等等特性概念来划分。
- 在OS概念中PCB+程序=进程
- Intel芯片提供硬件级别的任务切换(处理器自动保存和加载tss)
- 任务状态包括但不限于:
 - 所有通用寄存器和段寄存器信息
 - EFLAGS、EIP、CR3、TR和LDTR
 - 段寄存器指定的任务当前执行空间
 - I/0映射位图基地址和I/O位图信息(TSS)
 - 特权级0、1和2的堆栈指针(TSS)
 - 链接至前一个任务的链指针(TSS，主要用于嵌套中断)
- 详细可继续参考Intel手册...


# 保护模式编程的初始化
> 进入保护模式之前必须搭建起环境


- IDT
- GDT
- TSS
- LDT
- 若开启分页，则最少一个页目录和一个页表可用
- 处理器切换到保护模式运行的代码段
- 含有中断和异常处理的代码模块
- 初始化GDTR、IDTR、CR3等
- 而后置位CR0的PE位并jmp清空流水线即可运行在保护模式下
# 一个简单的多任务内核例子

> 先安装个环境跑一下....   


- 由于这两天赵博士维护的开源网站[www.oldlinux.org](http://www.oldlinux.org)貌似突然down掉了，真是资料到用的时候方恨没下载。不过幸好我早期下载了一份**Linux-0.11-040305**。按照网上的教程手动编译源码后进入这个文件夹，翻到书最后一章，仿照并依据自身实际情况修改，如下图所示，终于跑上了系统。
![Linux_0.11_chapter4_run_linux_0.11_hd.png](/images/Linux_0.11_chapter4_run_linux_0.11_hd.png)
 - 我的配置
 ```bash
	rutk1t0r@Rutk1t0r:linux-0.11-040305$ cat bochsrc-hd-new.bxrc 
	romimage: file=$BXSHARE/BIOS-bochs-latest
	megs: 16
	vgaromimage: file=/usr/local/share/bochs/VGABIOS-lgpl-latest
	floppya: 1_44=bootimage-0.11-hd.new, status=inserted
	ata0-master: type=disk, path="hdc-0.11.img", mode=flat, cylinders=121, heads=16, spt=63
	boot: a
	rutk1t0r@Rutk1t0r:linux-0.11-040305$ bochs -f ./bochsrc-hd-new.bxrc
 ```
 ![Linux_0.11_chapter4_run_linux_0.11_bochs_self.png](/images/Linux_0.11_chapter4_run_linux_0.11_bochs_self.png)

- 接下来应该编译这个小程序并融合进去，看是否有错误...



# 总结
- Intel的保护模式确实很复杂，如果想要完全深入理解必须要动手鼓捣鼓捣
- [泰晓科技](http://www.tinylab.org/linux-0.11-lab/)有大牛已经搭建好了平台，只需简单make即可，并且linux 0.11系统也具有gcc。
