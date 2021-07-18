---
title: Linux内核0.11完全注释 第六章
date: 2016-12-14 20:59:20
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> 迷你bootloader部分

<!--more-->


----------

# 从ROM BIOS处接手过来
![Linux_0.11_chapter6_bootloader_seq.png](/images/Linux_0.11_chapter6_bootloader_seq.png)
![Linux_0.11_chapter6_bootloader_graph.png](/images/Linux_0.11_chapter6_bootloader_graph.png)

# 加载内核代码
- 需要参考ROM BIOS的中断使用手册，从硬盘加载数据以及控制显示设备等
- MBR的508、509偏移字节处保存根设备号
- 参考书籍作者的[资料](http://www.oldlinux.org/Linux.old/docs/)中《Linux内核源代码漫游》  


# 硬盘设备号
![Linux_0.11_chapter6_disk_device_number.png](/images/Linux_0.11_chapter6_disk_device_number.png)

# 全局参数
![Linux_0.11_chapter6_setup_global_params.png](/images/Linux_0.11_chapter6_setup_global_params.png)

# PIC 8295A中断芯片
- 配置相当复杂，建议直接用现成的吧。

# system模块映像
![Linux_0.11_chapter6_system_map.png](/images/Linux_0.11_chapter6_system_map.png)

# 小结
本章跟以前分析的小程序大同小异，只不过开启了分页机制，但是也是很简单的换算。
