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

<!--more-->
---------------------------

# gentoo是啥？
  跟Arch差不多的可供闲着的人折腾的定制化版的GNU/Linux．滚动更新和源码安装等是其和其他普遍的发行版最大的区别．成功安装gentoo，最起码使得初学者对GNU/Linux操作系统的大体构成有一定了解．

# 安装环境
  我个人的情况是已经安装了个GNU/Linux了且boot选项移交给了其gurb管理器，同时我是安装在物理机上的，因此后续的安装bootloader部分我就可以跳过了．简单点说就是在rootfs没有问题的情况下只要把内核源码编译出来的镜像放在指定位置同时新增前者的grub内容选项即可．我为rootfs分配了大概35G的磁盘空间，为boot分配了100M,而swap可以借用前者的，由于没有为/usr和/home分区因此其内容均挂载在rootfs下，其影响就是容灾性降低了．具体分区可用fdisk等分区工具．
    
    
# 下载镜像
  网络上建议下载minimal版本的，其跟live主要区别就是全部都是黑框框．而后下载stage3和portage.可以在[这里](http://mirrors.163.com/gentoo/releases/)下载.portage得下载最新版的，便于后期处理．而后可以用dd或者其他烧录工具将iso镜像烧录到u盘中，将其他两个文件包直接放在rootfs里面即可(portage包是在stage3解压之后再解压到/usr目录)．
  
# 配置gentoo
根据wiki里面的handbook先配置好大部分，其中需要主要的是网卡驱动部分．现在shell里面键入`lspci -k`即可，如下所示:


```bash
01:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8101/2/6E PCI Express Fast/Gigabit Ethernet controller (rev 05)
	Subsystem: Dell RTL8101/2/6E PCI Express Fast/Gigabit Ethernet controller
	Kernel driver in use: r8169
	Kernel modules: r8169
02:00.0 Network controller: Broadcom Corporation BCM43142 802.11b/g/n (rev 01)
	Subsystem: Dell Wireless 1704 802.11n + BT 4.0
	Kernel driver in use: wl
	Kernel modules: bcma, wl
	
```

根据下面的提示可以找到相应的网卡驱动，在`make menuconfig`之后直接键入`/`进行模块的搜索，例如`r8169`而后选中后即可将内核模块编译进来，同时需要注意网卡命名是否类似于`eth0`，如果不是则需要在网络配置的时候更改，例如`enp1s0`建立软链接，这样网络才能起来．其他部分也可以先让系统起来之后再去重新编译内核再加．如果没有挂载boot分区则需要手动将压缩后的内核镜像和符号表等复制到boot分区．我的grub.cfg新增的内容如下:


```bash
menuentry 'Gentoo/Linux 4.9.34'{
	insmod ext2
	set root='hd0,msdos10'
	linux /vmlinuz-4.9.34-gentoo root=/dev/sda16
}

```


其中`set root=`部分是boot所在的分区，我这里是sda10.`linux ...`里面的vmlinuz-4.9.34-gentoo是内核镜像名称，其文件就在sda10分区．而root=后面的内容则是rootfs所在分区．而后exit处chroot环境，reboot准备进入物理环境了．

# 装桌面
先不着急在eselect里面选择，首先利用网络先`emerge --sync`同步portage树，而后可以选择安装一些需要的软件例如vim等．之前一直卡在这里，解决不了依赖性问题，首先搜索到了xorg的安装方式，参考[这里](https://wiki.gentoo.org/wiki/Xorg/Guide/zh-cn)将显卡的驱动安装好，之后便可操作eselect选项，可先做轻便的desktop的选项，而后搜索到xfce4的安装方法，照葫芦画瓢的我便从昨天装到今天中午终于完工了．之后的APP的安装应该都不是什么大问题，装上chrome几乎能够解决很多需求问题．
![gentoo_desktop.png](/images/gentoo_desktop.png)


# 总结
换个酷炫点的桌面还是继续折腾BLFS...

## issue
* 提示`The emerge option --autounmask-write writes autounmask features into the corresponding config files.`，重复上次的命令加上参数，然后使用自带的`dispatch-conf`命令自动写入配置，而后再执行最开始的命令即可解决软件安装版本以及依赖性问题．
