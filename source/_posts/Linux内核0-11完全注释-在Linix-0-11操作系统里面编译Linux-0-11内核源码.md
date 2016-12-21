---
title: Linux内核0-11完全注释 在Linix 0.11操作系统里面编译Linux 0.11内核源码
date: 2016-12-21 12:46:31
categories:
- study
tags:
- C/C++
- Linux kernel
- Asm
- LDD
---

> 来回折腾，终得其法

------------------------------
# Get开发版本
参照书籍第836页17.8的教程，可以wget[此处](http://www.oldlinux.org/Linux.old/bochs/linux-0.11-devel-040923.zip)的压缩包到本地，解压之后修改掉相应的配置文件即可启动。

# 修改源代码增加系统调用
我在tinylab上按照书上的教程增加了`sethostname`系统调用的相关代码和配置。发现用汇编直接编写或者嵌入汇编都是可以达到目的的，但是用C库调用硬是出问题，而后去gcc1.4版本的库文件查看发现并没有相关的信息，但是居然能够编译通过仅仅是执行出问题，相必是内核库文件里面有，但是gcc没有把代码实现链接过来，便想着手动强制gcc链接lib.a，但是报错，应该版本不一样导致的，因为编译Linux 0.11内核源码gcc版本是高版本的。又想着能否自己手动制作一个库文件到gcc1.4里面去呢?结果肯定是太麻烦了，从网上随意搜搜便发现[别人家的操作系统课程才是真正的操作系统](http://deathking.github.io/hit-oslab/chap1.html)。然后才意识到Linux 0.11里面有前辈已经做好了自身源代码编译的条件，便尝试编译。然后又爆出`Not Owner`错误，[此处有讨论](https://cms.hit.edu.cn/mod/forum/discuss.php?d=5781)。个人认为还是hdc-0.11.img文件的制作者可能出了点小差错,文件系统命令没有正确调用系统调用。因此暂时放弃tinylab的测试，转到前者去。

# 0.11干上0.11
启动赵博士的硬盘dev版本内核后直接进入到/usr/src/linux目录后,ls -la发现有uid问题.但是不碍事，直接make clean;make后开始编译了。而我在tinylab的源码里面编译出现问题，后面尝试修复。编译完毕之后按照教程先备份原来的引导内核，然后重新启动后在/usr/src/linux目录下键入`dd bs=8192 if=Image of=/dev/fd0`。为了看到新的内核引导我特意在main函数里面加入了一行代码，打印`New kernel Starting`。
- UID乱数字
 ![Linux_0.11_compile_0.11_uid.png](/images/Linux_0.11_compile_0.11_uid.png)
- make clean
 ![Linux_0.11_compile_0.11_make_clean.png](/images/Linux_0.11_compile_0.11_make_clean.png)
- make
 ![Linux_0.11_compile_0.11_make.png](/images/Linux_0.11_compile_0.11_make.png)
- restart
 ![Linux_0.11_compile_0.11_new_kernel_start.png](/images/Linux_0.11_compile_0.11_new_kernel_start.png)

# 继续尝试调用sethostname
为了保险期间我先用嵌入汇编来写(系统调用号也被改到74去了)，但是居然给我报出了-38的错误号(我用printf看的)，果然查看内核错误号发现居然没有实现的意思，看源码发现真的是没有实现...dev版本的sys_sethostname系统调用直接`return -ENOSYS;`然后果断照着教程修改源码实现一遍，写出如下C函数，发现终于可以用了。
- ![Linux_0.11_compile_0.11_sethostname_syscall_num.png](/images/Linux_0.11_compile_0.11_sethostname_syscall_num.png)
- ![Linux_0.11_compile_0.11_sethostname_call_C.png](/images/Linux_0.11_compile_0.11_sethostname_call_C.png)
- ![Linux_0.11_compile_0.11_sethostname_test.png](/images/Linux_0.11_compile_0.11_sethostname_test.png)

# 转到tinylab工程上去
本以为是tinylab的Linux 0.11操作系统里面的Linux 0.11内核源代码出了问题，后来还是认为是hdc-0.11.img的缘故。果断修改tools下的bochs的硬盘配置文化，将ata0改为`ata0-master: type=disk, path="rootfs/hdc-0.11-new.img", mode=flat, cylinders=410, heads=16, spt=38`，其中的hdc-0.11-new.img文件从赵博士的dev版本拷贝过来的，而后make start-hd后继续make clean发现仍然出现`Not Owner`问题，直接一波刚`chown -R root.root ./*`。之后就OK了。顺利编译链接写入引导重启没问题。
- ![Linux_0.11_compile_0.11_chown.png](/images/Linux_0.11_compile_0.11_chown.png)

# 总结
虽然用C语言搭载成功嵌入hdc-0.11.img的gcc1.4能够继续开发Linux 0.11内核功能，但是能否学习bash来更好地契合Linux呢?我想我应该首先学一遍文件系统相关理论知识自己能够鼓捣hdc文件吧。发现hexdump居然可以用了~~~
![Linux_0.11_compile_0.11_hexdump_root.png](/images/Linux_0.11_compile_0.11_hexdump_root.png)
