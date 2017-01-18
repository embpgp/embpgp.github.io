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

> 认真学习Minix文件系统!通过一个实例手动分析Minix。具体源码实现由于考虑其他情况将很复杂。

-------------------------

# mkfs a minix
如下图所示,先不考虑什么是i节点等等，我们只需要知道目前手动创建了一个文件系统，大小为360KB,并且拷贝了一个hello.c文件到其根目录下。
![Linux_0.11_Minix_mkfs_dev_fd1_360.png](/images/Linux_0.11_Minix_mkfs_dev_fd1_360.png)
![Linux_0.11_Minix_mkfs_dev_fd1_360_do.png](/images/Linux_0.11_Minix_mkfs_dev_fd1_360_do.png)

# 再来简介Minix文件系统格式  
## 引导块
根据Minix文件系统的设计，我们上面创建的360KB的软盘总共分为6个部分，图中的块是以1KB为单位的，这是设计需求，注意区别于硬盘中的扇区。其中约定第一个块为引导块，虽然引导区约定为512字节但是在这里最小单位为1K,浪费也就不在乎了。即使不引导也得有引导标志以符合标准。
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
- 0x0000 short 16位 在Minix 1.0中恒等于0，为后期改版做准备。
- 0x10081c00 long 32位 最大文件长度，书中注释到"显然有误",此字段应该是mkfs程序填充的，但是后面学习了i节点后进过计算个人认为没有那么"显然",mkfs程序仅仅是用双重间接块号来计算的，即512\*512\*1KB = 256MB=268966912=0x10081c00字节。但是实际情况是可以再存多一点的。加上前面的直接块号和一次间接块号。但是从内存字段的定义来看答案又不一样...(不触碰原则就没事儿,灵活点儿)
- 0x137f short 16位 Magic Number　约定值，类似于本版本文件系统的标志。
![Linux_0.11_Minix_360K_super_block_data.png](/images/Linux_0.11_Minix_360K_super_block_data.png)
- 关于内存中的字段含义参见原书或者Minix文件系统原理，对照着功能实现源码分析更好。
- 超级块在内核初始化的时候会被加载并分析，主要是为了加载根文件系统，或者mount其他文件系统和设备。

## i节点位图和逻辑块位图
图中偏移量0x800和0xc00分别表示，均为0x0007,表示有三个块被占用，当然约定第0比特不能用，直接被设置为1。所以文件系统中有两个块被使用。
## i节点
文件系统中最重要的数据结构!!!和超级块类似，磁盘中仅仅保存最精简的字段，内存中其他字段将经常被使用。
![Linux_0.11_Minix_1.0_inode_struct.png](/images/Linux_0.11_Minix_1.0_inode_struct.png)
看下图我们开始时候创建的360KB的软盘。
![Linux_0.11_Minix_1.0_inode_struct_do.png](/images/Linux_0.11_Minix_1.0_inode_struct_do.png)
继续照葫芦画瓢~由上述定义可以知道,inode在磁盘空间大小为32字节，所以一个块(1024字节)能够存1024/32=32个数据结构，因此4个块就刚好是128个i节点。其中的4是块4、5、6、7。块0引导,块1为super_block。块2、3分别是位图。块8就是真正的数据部分了。找到偏移为0x1000(第4块)。
- 0x41ed 表示目录文件权限为755。
- 0x0000 表示uid为0，即root用户
- 0x00000030 表示文件长度为0x30
- 0x585d223b 时间戳
- 0x00 gid为0,表示root用户组
- 0x02 链接数
- 0x08　数据区域的第一个块位置，后续均为0表示没有更多数据块了。 
![Linux_0.11_Minix_1.0_inode_struct_imode.png](/images/Linux_0.11_Minix_1.0_inode_struct_imode.png)
我们根据目录项的数据结构定义跳到第8块逻辑块继续追踪。即偏移量为0x2000处。
- 第一项
 - 0x0001 为i节点号(刚刚才跳过来的地方)
 - 0x2e 即为'.'，表示当前目录
- 第二项
 - 0x0001 为i节点号
 - 0x2e2e 即为".."，表示上层目录，因为这是根目录，因此".."="."
- 第三项
 - 0x0002 为i节点号(待会儿分析）
 - 一波ascii码，表示"hello.c"


关于如何根据文件名称定位一个具体文件算法可以参见源码，原理参见书。
![Linux_0.11_Minix_1.0_dir_entry_struct.png](/images/Linux_0.11_Minix_1.0_dir_entry_struct.png)

然后接着上面把hello.c文件也分析一下,如果已经定位了到刚刚的第三项，根据inode为2定位到其inode数据结构。
- 0x8180 表示普通文件权限为600,注意文件类型定义为8进制数
- 0x0000 root
- 0x0000004a 表示文件大小为74字节
- 0x585d223b 时间戳
- 0x01 链接数
- 0x00 root
- 0x09 数据部分第一个块区，内容不多因此一个块足够。


定位到偏移量为0x2400处，将这一大串ascii码翻译过来就是hello.c文件的具体内容。

# 定位文件基本原理
![Linux_0.11_Minix_1.0_find_file_by_name.png](/images/Linux_0.11_Minix_1.0_find_file_by_name.png)
![Linux_0.11_Minix_1.0_find_file_by_name_words.png](/images/Linux_0.11_Minix_1.0_find_file_by_name_words.png)


> 现在来分析为什么说硬链接不能是目录以及不能跨文件系统而软链接就可以呢...


# sys_link系统调用

```C
//// 为文件建立一个文件名目录项
// 为一个已存在的文件创建一个新链接(也称为硬链接 - hard link)
// 参数：oldname - 原路径名；newname - 新的路径名
// 返回：若成功则返回0，否则返回出错号。
int sys_link(const char * oldname, const char * newname)
{
	struct dir_entry * de;
	struct m_inode * oldinode, * dir;
	struct buffer_head * bh;
	const char * basename;
	int namelen;

    // 首先对原文件名进行有效性验证，它应该存在并且不是一个目录名。所以我们先取得原文件
    // 路径名对应的i节点oldnode.若果为0，则表示出错，返回出错号。若果原路径名对应的是
    // 一个目录名，则放回该i节点，也返回出错号。
	oldinode=namei(oldname);
	if (!oldinode)
		return -ENOENT;
	if (S_ISDIR(oldinode->i_mode)) {
		iput(oldinode);
		return -EPERM;
	}
    // 然后查找新路径名的最顶层目录的i节点dir，并返回最后的文件名及其长度。如果目录的
    // i节点没有找到，则放回原路径名的i节点，返回出错号。如果新路径名中不包括文件名，
    // 则放回原路径名i节点和新路径名目录的i节点，返回出错号。
	dir = dir_namei(newname,&namelen,&basename);
	if (!dir) {
		iput(oldinode);
		return -EACCES;
	}
	if (!namelen) {
		iput(oldinode);
		iput(dir);
		return -EPERM;
	}
    // 我们不能跨设备建立硬链接。因此如果新路径名顶层目录的设备号与原路径名的设备号不
    // 一样，则放回新路径名目录的i节点和原路径名的i节点，返回出错号。另外，如果用户没
    // 有在新目录中写的权限，则也不能建立连接，于是放回新路径名目录的i节点和原路径名
    // 的i节点，返回出错号。
	if (dir->i_dev != oldinode->i_dev) {
		iput(dir);
		iput(oldinode);
		return -EXDEV;
	}
	if (!permission(dir,MAY_WRITE)) {
		iput(dir);
		iput(oldinode);
		return -EACCES;
	}
    // 现在查询该新路径名是否已经存在，如果存在则也不能建立链接。于是释放包含该已存在
    // 目录项的高速缓冲块，放回新路径名目录的i节点和原路径名的i节点，返回出错号。
	bh = find_entry(&dir,basename,namelen,&de);
	if (bh) {
		brelse(bh);
		iput(dir);
		iput(oldinode);
		return -EEXIST;
	}
    // 现在所有条件都满足了，于是我们在新目录中添加一个目录项。若失败则放回该目录的
    // i节点和原路径名的i节点，返回出错号。否则初始设置该目录项的i节点号等于原路径名的
    // i节点号，并置包含该新添加目录项的缓冲块已修改标志，释放该缓冲块，放回目录的i节点。
	bh = add_entry(dir,basename,namelen,&de);
	if (!bh) {
		iput(dir);
		iput(oldinode);
		return -ENOSPC;
	}
	de->inode = oldinode->i_num;
	bh->b_dirt = 1;
	brelse(bh);
	iput(dir);
    // 再将原节点的链接计数加1，修改其改变时间为当前时间，并设置i节点已修改标志。最后
    // 放回原路径名的i节点，并返回0（成功）。
	oldinode->i_nlinks++;
	oldinode->i_ctime = CURRENT_TIME;
	oldinode->i_dirt = 1;
	iput(oldinode);
	return 0;
}



```

- 根据源代码分析程序首先获取源(old)文件inode，如果不存在就直接返回了，如果存在则继续判断是否为目录，如果是则放回inode并返回。那么到这里几乎就可以回答为什么不能为目录了(因为源码实现不允许呀),但是仍然要刨根问底，假定有"开发者"绕过了这么策略操作系统将如何处理呢?先继续看。
- 之后就是检查目的(new)文件的顶层目录权限了，如果没问题将继续往下走
- 再后就是说的不能进行跨文件系统的硬链接...
- 如果没问题的话就在目的文件的目录下建立一个链接文件-->本质上仅仅在其目录下新增了一个dir\_entry结构体并使得其inode字段指向源文件m_inode的i\_num字段,将inode的i\_nlinkds字段++。
- 现在我们假设某"开发者"先绕过这个检查策略(自己修改这段源码然后创建目录硬链接或者二进制大牛自己手动输入都可)，看程序会发生什么...


- 可以看到至少shell是不允许我们创建的
![Linux_0.11_fs_hard_links_not_allow.png](/images/Linux_0.11_fs_hard_links_not_allow.png)
- 开始建立一些测试文件,由于忘了linux 0.11版本仅仅允许最多14个字符的文件名字，导致有些名字不全。删除也出类似前面的问题，说不是owner。在写下这段文字之前我做的测试成功了但我自己建立的是根目录的硬链接，导致切换新的内核rm的时候把根文件系统删掉了。。。又重新复制了一个hdc文件过来。
图中的`dir_for_hard_l`(其实是dir\_for\_hard_link)是我们想要链接的目录(为了保险起见了，怕忘了又把根目录删了...)。`hard_link_not_`是C语言源程序，但是gcc编译的时候报错，因此我重定向了一个短的.c文件。
![linux_0.11_fs_usr_root_dir.png](/images/linux_0.11_fs_usr_root_dir.png)
- 用来测试没有修改内核代码的时候能否创建目录硬链接。为了简单我也没有检测main函数的具体参数合法性了。看结果没有创建成功，而返回值-1恰恰是宏定义ENOENT的负数，说明内核检测到了目录问题。
![linux_0.11_fs_hard_link_not_allow.png](/images/linux_0.11_fs_hard_link_not_allow.png)

- 我修改了这段代码，然后重新编译内核代码看看吧。
![linux_0.11_fs_hard_link_allow_codes.png](/images/linux_0.11_fs_hard_link_allow_codes.png)

- 用bash修改失败了，猜测在bash的实现中提前加入了检测，我们用C语言来就成功了。可以看到确实可以创建硬链接的，在这种情况下也没有出问题。
![linux_0.11_fs_hard_link_allow_test.png](/images/linux_0.11_fs_hard_link_allow_test.png)
![linux_0.11_fs_hard_link_allow_new_file.png](/images/linux_0.11_fs_hard_link_allow_new_file.png)



- 为了建立"有向循环图"测试之后删除的时候又把文件系统给删了...

- 以下为bash自带bc计算器快速进制转换命令，可以结合hexdump用于自己计算inode偏移自己解析数据结构啥的
```bash
$ echo "obase=10;ibase=16;50BA" | bc -l
20666

```

- 下面为硬链接为目录出现的问题，我建立了一个指向自己父目录的目录,仅仅cd命令就"吃不消"了，若其他遍历目录树的工具的算法逃不出这个坑的话就死机了估计。因此文件系统的设计要求不能建立目录的硬链接，否则**有可能**导致循环图。
![Linux_0.11_fs_hard_link_error.png](/images/Linux_0.11_fs_hard_link_error.png)


- 至于为什么不能跨文件系统，由于link的本质是在建立一个inode指针计数增加的目录项，而inode是各个文件系统分布不一致的，因此不能进行跨文件系统寻址，超级块都不一定一致。
- 而软链接在本版本的内核貌似没有实现，其具体实现是在软链接文件的数据块放置真正链接文件的路径字符串，因此系统拿到一个软链接的时候再用文件内容的路径去寻址，因此可以跨文件系统以及目录。
![Linux_0.11_fs_no_symbolic_link.png](/images/Linux_0.11_fs_no_symbolic_link.png)

# 总结
当然不可能每次都需要人来手动计算，计算机内部实现了更多算法来存取数据，大概的基本原理就这些，当然内存里面关于缓存和文件表等后期会稍微提一下。刨根问底还是很重要的。
