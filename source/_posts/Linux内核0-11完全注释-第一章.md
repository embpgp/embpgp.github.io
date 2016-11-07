---
title: Linux内核0.11完全注释 第一章
date: 2016-11-07 13:38:41
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> 一直学习Linux内核源码,现在有些时间了,便开始找本书籍开始.从最初的成形版本可以学到当时Linux内核开发者的思考方式,便于理解后期Linux的改进路线.

----------------


# Linux诞生和发展
Linux操作系统的诞生,发展和成长过程依赖于以下五个重要支柱:
UNIX操作系统:鼻祖
MINIX操作系统:DEMO版本供学习
GNU计划:GNU's not Unix,含编辑工具,shell程序,gcc系列编译程序,gdb调试程序等
POSIX标准:Linux的未来
Internet网络:传播的媒介

# 主要版本号
![kernel_release_1](/images/kernel_release_1.png)
![kernel_release_2](/images/kernel_release_2.png)

# 内核目录树
![Linux_kernel_0.11](/images/Linux_kernel_0.11.png)

# 书籍章节划分
书籍分为了5个部分,第1章至第4章是基础部分.操作系统与所运行的硬件环境密切相关(Intel的80X86保护模式下的编程原理,到目前位置Linus本人仍然认为X86系列的处理器比较适合Linux);  
第二部分包括第5至第7章,描述内核引导启动和32位运行方式的准备阶段,作为学习内核的初学者应该全部进行阅读;  
第三部分是从第8章到第13章是内核代码的主要部分;  
第四部分是从14章到16章,作为第三部分的参考部分;  
第五部分介绍如何使用PC模拟软件系统Bochs针对Linux 0.11内核进行各种实验活动.  

