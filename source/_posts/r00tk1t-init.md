---
title: r00tk1t init
date: 2017-01-12 21:33:55
categories:
- study
- misc
tags:
- exploit
- C/C++
- r00tk1t
---

参考:
[谷大神:http://www.freebuf.com/articles/system/54263.html](http://www.freebuf.com/articles/system/54263.html)
[https://chirath02.wordpress.com/tag/asmlinkage/](https://chirath02.wordpress.com/tag/asmlinkage/)
[r00tk1t基础实验](http://mp.weixin.qq.com/s?__biz=MjM5OTk4MDE2MA==&mid=2655113676&idx=3&sn=07e450fb7553f87fa3c9fa5fd186c5b0&chksm=bc864c238bf1c5350ddc594555f4412faa42df025d49e2364884b851d7ea9a1e2d1cfda697d4#rd)
[https://memset.wordpress.com/2010/12/28/syscall-hijacking-simple-rootkit-kernel-2-6-x/](https://memset.wordpress.com/2010/12/28/syscall-hijacking-simple-rootkit-kernel-2-6-x/)
[https://memset.wordpress.com/2011/01/20/syscall-hijacking-dynamically-obtain-syscall-table-address-kernel-2-6-x/](https://memset.wordpress.com/2011/01/20/syscall-hijacking-dynamically-obtain-syscall-table-address-kernel-2-6-x/)
[http://www.mallocfree.com/data/compile-linux-kernel-mallocfree.com.pdf](http://www.mallocfree.com/data/compile-linux-kernel-mallocfree.com.pdf)


# What's this?
关于其概念可以参考[维基百科](https://en.wikipedia.org/wiki/Rootkit)。

# 实验环境
建议不要在物理机下实验~因此我根据[这里](https://chirath02.wordpress.com/tag/asmlinkage/)介绍的情况便去ubuntu的官方网站下载了ubuntu 15.10的i386镜像。然后用VMWare安装ISO，便开始按照里面的指令进行修改和编译。其中增加的系统调用是根据上述的[r00tk1t](http://mp.weixin.qq.com/s?__biz=MjM5OTk4MDE2MA==&mid=2655113676&idx=3&sn=07e450fb7553f87fa3c9fa5fd186c5b0&chksm=bc864c238bf1c5350ddc594555f4412faa42df025d49e2364884b851d7ea9a1e2d1cfda697d4#rd)增加的。修改系统调用是主要的方式之一，因此可以借鉴。

# 编译部分
为了方便可以直接在虚拟机里面切换到root用户，然后键入`# apt-get source linux-image-$(uname -r)`即可下载虚拟机本内核源代码。然后cp到/usr/src目录，再解压出来。然后安装编译所需要的一些依赖工具。
```bash
$ sudo apt-get update
$ sudo apt-get build-dep linux-image-$(uname -r)
$ sudo apt-get install kernel-package  # for make-kpkg clean
$ sudo apt-get install libncurses-dev  # for make menuconfig
```
再之后按照教程部分增加系统调用，照葫芦画瓢。然后就`make menuconfig`配置内核编译选项，教程给的是默认(不知道修改是否编译快一些)。而后便可以开始漫长的编译过程了。
```bash
sudo make
sudo make modules_install˖
sudo make install
sudo mkinitramfs -o /boot/initrd.img-2.6.32.65
sudo update-initramfs -c -k 2.6.32.65
sudo update-grub2 

sudo vim /etc/default/grub     //注释掉下面的部分
#GRUB_HIDDEN_TIMEOUT=0
sudo update-grub2 
```
上述参考mallocfree的教程。可以使得不用完全覆盖掉原有内核选项而使得grub增加新的选项来供用户选择。
按照教程第一部分部分结果如下:至少我们工程的从内核任务链表中实现了相应的功能。
```bash
root@r00t:~# uname -r
4.2.2
root@r00t:~# ps aux | grep sshd
root       655  0.0  0.5  10432  5320 ?        Ss   20:13   0:00 /usr/sbin/sshd -D
root      1144  0.0  0.6  13652  6268 ?        Ss   20:13   0:00 sshd: r00t [priv]   
r00t      1209  0.1  0.2  13652  2948 ?        S    20:13   0:00 sshd: r00t@pts/8    
root      1248  0.0  0.6  13652  6196 ?        Ss   20:14   0:00 sshd: r00t [priv]   
r00t      1285  0.0  0.2  13652  2960 ?        S    20:14   0:00 sshd: r00t@pts/9    
root      1330  0.0  0.2   5972  2308 pts/8    S+   20:19   0:00 grep --color=auto sshd
root@r00t:~# ./testPname 
Enter process to find
sshd
PID = 655
         PID = 1144
                   PID = 1209
                             PID = 1248
                                       PID = 1285
                                                 System call returned 0
root@r00t:~# 


```
# LKM
按照谷大神的教程第一个LKM程序编译如下:
```bash
root@r00t:~/LKM# make
make -C /lib/modules/4.2.2/build SUBDIRS=/root/LKM modules
make[1]: Entering directory '/usr/src/linux-4.2.2'
  CC [M]  /root/LKM/lkm.o
  Building modules, stage 2.
  MODPOST 1 modules
  CC      /root/LKM/lkm.mod.o
  LD [M]  /root/LKM/lkm.ko
make[1]: Leaving directory '/usr/src/linux-4.2.2'
root@r00t:~/LKM# insmod lkm.ko 
root@r00t:~/LKM# dmesg | tail -n 1
[ 4019.602327] Arciryas:module loaded
root@r00t:~/LKM# lsmod | grep lkm
lkm                    16384  0
root@r00t:~/LKM# rmmod lkm.ko
root@r00t:~/LKM# dmesg | tail -n 2
[ 4019.602327] Arciryas:module loaded
[ 4117.988381] Arciryas:module removed
root@r00t:~/LKM# 
```

# Kernel Hook
- 静态的方式获得syscall表的地址
```bash
root@r00t:~# !cat
cat /boot/System.map-4.2.2 | grep sys_call_table
c1755140 R sys_call_table
root@r00t:~# 

```
- hook代码如下,稍微大概解释以下，内核模块在初始化的时候会检查sys\_call\_table的内存地址是否可写，一般情况下肯定是不能写的，上面的System.map文件中也看到的，因此程序会检查并通过改写其对应的内存页读写属性来强行修改表借此来hook。在模块卸载的时候又将原来的地址修改回来。
```bash

root@r00t:~/LKM/pname# cat captainhook.c
#include <asm/unistd.h>
#include <asm/cacheflush.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/syscalls.h>
#include <asm/pgtable_types.h>
#include <linux/highmem.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/moduleparam.h>
#include <linux/unistd.h>
#include <asm/cacheflush.h>
MODULE_LICENSE("GPL");
MODULE_AUTHOR("rutk1t0r");
/*MY sys_call_table address*/
//c1755140
void **system_call_table_addr;
/*my custom syscall that takes process name*/
asmlinkage int (*custom_syscall) (char* name);
/*hook*/
asmlinkage int captain_hook(char* play_here) {
    /*do whatever here (print "HAHAHA", reverse their string, etc)
        But for now we will just print to the dmesg log*/
    printk(KERN_INFO "Pname Syscall:HOOK! HOOK! HOOK! HOOK!...ROOOFFIIOO!");
    return custom_syscall(play_here);
}
/*Make page writeable*/
int make_rw(unsigned long address){
    unsigned int level;
    pte_t *pte = lookup_address(address, &level);
    if(pte->pte &~_PAGE_RW){
        pte->pte |=_PAGE_RW;
    }
    return 0;
}
/* Make the page write protected */
int make_ro(unsigned long address){
    unsigned int level;
    pte_t *pte = lookup_address(address, &level);
    pte->pte = pte->pte &~_PAGE_RW;
    return 0;
}
static int __init entry_point(void){
    printk(KERN_INFO "Captain Hook loaded successfully..\n");
    /*MY sys_call_table address*/
    system_call_table_addr = (void*)0xc1755140;
    /* Replace custom syscall with the correct system call name (write,open,etc) to hook*/
    custom_syscall = system_call_table_addr[__NR_pname];
    /*Disable page protection*/
    make_rw((unsigned long)system_call_table_addr);
    /*Change syscall to our syscall function*/
    system_call_table_addr[__NR_pname] = captain_hook;
    return 0;
}
static int __exit exit_point(void){
        printk(KERN_INFO "Unloaded Captain Hook successfully\n");
    /*Restore original system call */
    system_call_table_addr[__NR_pname] = custom_syscall;
    /*Renable page protection*/
    make_ro((unsigned long)system_call_table_addr);
    return 0;
}
module_init(entry_point);
module_exit(exit_point);
```
- 结果如下:
```bash
root@r00t:~/LKM/pname# insmod captainhook.ko
root@r00t:~/LKM/pname# cd
root@r00t:~# ./testPname 
Enter process to find
sshd
PID = 655
         PID = 1144
                   PID = 1209
                             PID = 1248
                                       PID = 1285
                                                 System call returned 0
root@r00t:~# rmmod captainhook
root@r00t:~# 

## dmesg中输出如下:
[ 1月13 21:49] Captain Hook loaded successfully..
[ 1月13 21:50] Pname Syscall:HOOK! HOOK! HOOK! HOOK!...ROOOFFIIOO!
[ +11.875845] Unloaded Captain Hook successfully

```

# 总结
后续实验应该会参照谷大神的[教程](https://github.com/NoviceLive/research-rootkit)继续学习，关于其防范策略目前还没有什么非常好用的方法，只能靠管理员多注意了。在后渗透测试阶段此隐蔽性非常强，特别是内核级的相对于应用级的更加难以发现，其中有一个应用级的用bash实现的可以[参考学习](https://github.com/cloudsec/brootkit)。
