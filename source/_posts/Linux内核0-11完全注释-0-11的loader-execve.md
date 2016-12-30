---
title: Linux内核0.11完全注释 0.11的loader->execve
date: 2016-12-30 23:28:46
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---


> 着重分析操作系统的加载器是如何运行程序的。

------------------

# 从fork到execve

