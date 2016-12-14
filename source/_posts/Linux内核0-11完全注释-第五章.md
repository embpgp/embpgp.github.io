---
title: Linux内核0-11完全注释-第五章
date: 2016-12-14 17:14:41
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---


> 久违的章节,简介Linux内核体系结构

--------------

# OS组成部分
![Linux_0.11_chapter5_Linux_kernel_arch.png](/images/Linux_0.11_chapter5_Linux_kernel_arch.png)

> 所谓内核，主要是运行起来之后与计算机硬件交互，实现对硬件部件的编程控制和接口操作，调度对硬件资源的访问，并且为计算机的用户程序提供一个高级环境和对硬件的虚拟接口。个人认为纯粹地看就是一大堆的数据结构和策略算法以及驱动程序，当然为了能够发挥作用必须得提供接口给用户等等。

# 宏内核模型
![Linux_0.11_chapter5_Linux_kernel_single_model.png](/images/Linux_0.11_chapter5_Linux_kernel_single_model.png)
- 灵活运用计算机体系里最重要的"分层"思想，可以很好地解决大问题，此时可以揣摩计算机网络等等
- 服务提供者和调用者即“客户-服务”思想让人容易想到C++类等等机制

# Linux内核体系结构
## 主要模块
- 进程调度
- 内存管理
- 文件系统
- 进程间通信
- 网络接口
![Linux_0.11_chapter5_Linux_kernel_arch_picture.png](/images/Linux_0.11_chapter5_Linux_kernel_arch_picture.png)

## 内核对内存的管理和使用
### 内存分布视图
![Linux_0.11_chapter5_Linux_kernel_mm_function.png](/images/Linux_0.11_chapter5_Linux_kernel_mm_function.png)
- 其中显存和BIOS ROM部分是由于工程师在集成PC的时候把地址空间分给了它们。
- 分段机制在Intel处理器中必须开启，但是软件工程师可以采用"平坦模式"寻址使得没有分段
- 分页机制需要大量的"铺垫"才能启用，并且为mm子系统提供支持
### 内存地址空间概念
- 虚拟地址:由程序运行时候CPU内部的段选择子和段内偏移组成，因为没有直接用来访问物理内存(区别于8086时代)，因此成为虚拟地址。虚拟地址空间由GDT和LDT映射组成，理论上的空间总量(注意不要又扯到物理地址去了，不要管地址总线多少根)为2^13*4G=64T。逻辑地址即可理解为虚拟地址。
- 线性地址:虚拟地址和物理地址变换之间的中间层，是处理器可以寻址的内存空间。即相应的段基址加上偏移地址即可，相当于去描述符表中或者高速缓存中取了一次数据后合并后的地址。如果此时没有启用分页机制，则线性地址即为物理地址，CPU直接放在地址总线上去内存中存取数据。
- 物理地址:即CPU外部总线上的地址信号，如果开启分页机制，则线性地址必须经过CR3、页目录和页表等转换才能送到地址总线上。
- 虚拟存储:即OS使得CPU对所有内存的寻址加一个"hook",以满足最大化的需求。

![Linux_0.11_chapter5_Linux_kernel_vm_space.png](/images/Linux_0.11_chapter5_Linux_kernel_vm_space.png)

### Linux具体的内存分布
![Linux_0.11_chapter5_Linux_kernel_line_addr.png](/images/Linux_0.11_chapter5_Linux_kernel_line_addr.png)
- 虽然代码段和数据段共用一个内存空间，但是对于当时的版本来说安全性不是首要考虑的，因此一切以方便工程师编程为出发点。
- 各种人工的定义也是为了方便操作。
![Linux_0.11_chapter5_Linux_kernel_process_code_data_space.png](/images/Linux_0.11_chapter5_Linux_kernel_process_code_data_space.png)

### 内核代码段和数据段三种地址转换
![Linux_0.11_chapter5_Linux_kernel_code_data_on_3_addr_convert.png](/images/Linux_0.11_chapter5_Linux_kernel_code_data_on_3_addr_convert.png)
- 在head.s程序的初始化过程中把内核代码段和数据段都设置为16M的段，两个段重叠并且线性地址都为0开始到0xFFFFF。
- 在这16M的内核空间中包括所有的代码、内核段表、页目录表和内核的二级页表、内核局部数据以及内核临时堆栈(将被用作任务0的用户堆栈)。
- 16M的空间仅仅需要4个页表(16M/1024/4K=4)，一个页4*1024字节,一个页目录项包括1024个页表，一个页表含有1024个页，因此仅仅需要一个页目录表和4个页表即可。(默认情况Linux 0.11最多可以管理16MB的物理内存)
- 小于16M的物理内存也可以运行Linux 0.11,在init/main.c中也仅仅映射了0-16MB的内存范围，多了也用不到，除非自己修改内核代码，增加页表。

### 任务0
![Linux_0.11_chapter5_task0_space.png](/images/Linux_0.11_chapter5_task0_space.png)
