---
title: Linux内核0.11完全注释 第七章
date: 2016-12-15 13:36:08
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> init进程来了

-----------

# 内核初始化流程
![Linux_0.11_chapter7_main_init.png](/images/Linux_0.11_chapter7_main_init.png)

# 着重分析"move_to_user_mode()"函数的前前后后

