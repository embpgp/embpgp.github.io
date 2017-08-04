---
title: gentoo_install
date: 2017-08-04 19:09:31
categories:
- study
tags:
- GNU/Linux
- gentoo
---

参考资料:
[https://wiki.gentoo.org/wiki/Handbook:AMD64/zh-cn](https://wiki.gentoo.org/wiki/Handbook:AMD64/zh-cn)等等搜索引擎能够解决的问题链接

> 今年三月份的时候就着手准备，无奈时间一直不连续，到近期下决心装好桌面版本，遂今日成．

---------------------------

# gentoo是啥？
  跟Arch差不多的可供闲着的人折腾的定制化版的GNU/Linux．滚动更新和源码安装等是其和其他普遍的发行版最大的区别．成功安装gentoo，最起码使得初学者对GNU/Linux操作系统的大题构成有一定了解．

# 安装环境
  我个人的情况是已经安装了个GNU/Linux了且boot选项移交给了其gurb管理器，同时我是安装在物理机上的，因此后续的安装bootloader部分我就可以跳过了．简单点说就是在rootfs没有问题的情况下只要把内核源码编译出来的镜像放在指定位置同时新增前者的grub内容选项即可．我为rootfs分配了大概35G的磁盘空间，为boot分配了100M,而swap可以借用前者的，由于没有为/usr和/home分区因此其内容均挂载在rootfs下，其影响就是容灾性降低了．具体分区可用fdisk等分区工具．
    
    
# 下载镜像
  网络上建议下载minimal版本的，其跟live主要区别就是全部都是黑框框．而后下载stage3和portage.可以在[这里](http://mirrors.163.com/gentoo/releases/)下载.portage得下载最新版的，便于后期处理．而后可以用dd或者其他烧录工具将iso镜像烧录到u盘中，将其他两个文件包直接放在rootfs里面即可．
  
# 配置gentoo
 
 