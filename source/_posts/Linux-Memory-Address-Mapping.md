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

-------------------------------------

# 体系架构
首先要了解操作系统的内存管理机制,一般都是知道是段页式管理,但是各个处理器架构提供的机制有所不同,主要由处理器中mmu部件负责翻译,操作系统负责管理.特别在intel架构中,完全做到了段页式的实现.但是Linux内核在实现的时候是用技巧越过了段式的地址特性,即逻辑地址=线性地址,但是处理器对于地址转换的有效性的检查不会改变,只是说Linux内核实现比较巧妙.