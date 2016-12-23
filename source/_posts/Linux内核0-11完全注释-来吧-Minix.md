---
title: Linux内核0.11完全注释 来吧,Minix!
date: 2016-12-22 22:44:04
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> 认真学习Minix文件系统!通过一个实例手动分析Minux。具体源码实现由于考虑其他情况将很复杂。

-------------------------

# mkfs a minix
如下图所示,先不考虑什么是i节点等等，我们只需要知道目前手动创建了一个文件系统，大小为360KB,并且拷贝了一个hello.c文件到其根目录下。
![Linux_0.11_Minix_mkfs_dev_fd1_360.png](/images/Linux_0.11_Minix_mkfs_dev_fd1_360.png)
![Linux_0.11_Minix_mkfs_dev_fd1_360_do.png](/images/Linux_0.11_Minix_mkfs_dev_fd1_360_do.png)

# 再来简介Minux文件系统格式  
## 引导块
根据Minux文件系统的设计，我们上面创建的360KB的软盘总共分为6个部分，图中的块是以1KB为单位的，这是设计需求，注意区别于硬盘中的扇区。其中约定第一个块为引导块，虽然引导区约定为512字节但是在这里最小单位为1K,浪费也就不在乎了。即使不引导也得有引导标志以符合标准。
![Linux_0.11_Minix_360K_fd_layout.png](/images/Linux_0.11_Minix_360K_fd_layout.png)
- 注意0x200偏移前面的0xaa55。
![Linux_0.11_Minix_360K_Boot.png](/images/Linux_0.11_Minix_360K_Boot.png)
## 超级块
仅仅知道这是一块可用的软盘还是不够的，必须还得知道到底我们需要的数据存在什么地方。因此Minix文件系统在设计的时候用一个数据结构来描述整个可用设备的具体情况。
![Linux_0.11_Minix_360K_super_block.png](/images/Linux_0.11_Minix_360K_super_block.png)
为什么要分内存中字段和磁盘中字段呢?本应该磁盘中存储这些数据结构是够了，但是操作系统为了更快更好地管理文件系统便用"以空间来换时间"的思想来操作数据。下面继续分析我们自己创建的360KB的软盘。在bochs终端键入`hexdump /dev/fd1 | more`。加more是由于终端不支持拉屏只能一帧帧看了。我们按空格键快速定位到偏移0x400。刚好是1KB后的块，即第1个块(引导区约定为0块)。对照着上面的数据结构照葫芦画瓢来解析各个字段(注意intel小端格式的显示)。
- 0x0078 short 16位 对应文件系统中i节点总数目 十进制为120 刚好对应创建文件系统的时候显示的结果。
- 0x0168 short 16位 逻辑块的数目　十进制为360 实质上在Minix 1.0设计的时候逻辑块大小等于磁盘块大小
- 0x0001 short 16位 i节点位图占块数目　1表示仅仅用一个块就可以描述所有i就节点映射情况
- 0x0001 short 16位 逻辑块位图占块数目 同上
- 0x0008　short 16位 表示数据区第一个块号 真正保存文件内容的块区
- 0x0000 short 16位 在Minux 1.0中恒等于0，为后期改版做准备。
- 0x10081c00 long 32位 最大文件长度，书中注释到"显然有误",此字段应该是mkfs程序填充的，但是后面学习了i节点后进过计算个人认为没有那么"显然",mkfs程序仅仅是用双重间接块号来计算的，即512\*512\*1KB = 256MB=268966912=0x10081c00字节。但是实际情况是可以再存多一点的。加上前面的直接块号和一次间接块号。
- 0x137f short 16位 Magic Number　约定值，类似于本版本文件系统的标志。
![Linux_0.11_Minix_360K_super_block_data.png](/images/Linux_0.11_Minix_360K_super_block_data.png)
