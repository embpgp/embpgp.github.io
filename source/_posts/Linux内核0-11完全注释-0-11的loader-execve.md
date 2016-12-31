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
根据Linux操作系统的设计原理,在Linux 0.11版本里面，进程0是手动创建的，进程1(init)是fork到进程0的，并且后续进程都是以1号进程为最顶层父进程。如果仅仅是fork只能实现所谓的多进程并发操作，而想要加载新的内容的话必须使用execve系统调用，将数据和代码从其他介质(比如硬盘)通过文件系统加载到内存，将原有进程代码和数据"冲刷掉"，现代Linux操作系统大体上也是这样的。

# do_execve()代码如下

- 根据Linux操作系统内核的编码习惯*do_*开头的一般为系统调用或者中断的下半部函数。在后续的Linux内核版本里面允许进程在内核态被抢占(几乎总是在中断里面)就主要是执行下半部的时候开放中断。个人认为所谓被抢占即不是自愿放弃CPU时间(即任务自身进程空间内主动直接或者间接调用schedule函数进行任务调度和切换),而主要是由于时钟中断(所谓操作系统的脉搏)而引发的周期性的任务调度。但是在0.11版本里面当发生时钟中断的时候会检查当前的cs是否为0x0f(0.11代码段选择子写死)，如果不是的话表明刚刚从另外一个任务的内核态切换过来的，控制流程立即返回，而不进行调度。

- 在反汇编的时候会经常发现C库的crt过程先push三个参数，然后call main,最后再返回。
![Linux_0.11_fs_exec_new_stack.png](/images/Linux_0.11_fs_exec_new_stack.png)
- 用户层执行exec类lib函数库簇或者直接通过系统调用嵌入汇编等方式触发系统调用,因此至少传递filename、argv、envp等参数，貌似envp经常由编译链接过程自动填充。
- 函数首先检查是否为用户层通过系统调用过来的，如果不是则panic。
- linus认为128K的空间足够来存储环境变量和参数,因此立即先将这段空间初始化为0
- 可执行文件必须为普通文件
- 根据文件的set标志位等检查进程是否有权限执行该文件
- 先处理是否为脚本类可执行文件，因此直接读出文件的第一块内容，看第一行是否为`#!`,该约定在内核里面写死，因此如果不是则不能执行脚本。
- 如果是脚本的话将改造参数顺序，如原来为`./example.sh -arg1 -arg2`变为`interp -iarg1 -iarg2 example.sh -arg1 -arg2`，即把可执行文件送往解释脚本里面去(注意没有约定说一定要为#!/bin/sh,例如#!/bin/cat等自己可以试试)，而解释脚本(如bash)本身为elf格式的二进制可执行文件，可被直接加载到内存交由CPU执行，有种"偷天换日"的感觉，但事实就是这样，而解释脚本(一般为bash)进一步怎么处理那是它的事情，可参考GNU的各种/bin/目录下文件的实现(例如GNU bash)。
- 之后便将参数一一填充至顶端,并取得解释程序i节点继续goto处理，第二次的处理将在这个if语句`if ((bh->b_data[0] == '#') && (bh->b_data[1] == '!') && (!sh_bang)) {`跳出到brelse(bh)。
- 然后便直接开始二进制程序的识别了,0.11版本的仅仅支持ZMAGIC格式的可执行映像。下图为0.11系统中hello程序的磁盘映像布局。(精通处理器指令集的大牛可以尝试不需要编译器链接器手动创建一个程序...)
![Linux_0.11_fs_exec_ZMAGIC_header.png](/images/Linux_0.11_fs_exec_ZMAGIC_header.png)

- 处理掉原来进程的一些"后事"之后便修改task_struct结构的某些字段，置返回地址为新程序的入口，栈指针为环境块、参数块p,如果调度程序待会儿调度到本进程运行，则立即触发no\_page异常，页面处理程序将磁盘上的代码和数据载入相应线性地址映射的物理地址处即可按需加载执行。
```C

/*
 * 'do_execve()' executes a new program.
 */
//// execve()系统中断调用函数。加载并执行子进程
// 该函数是系统中断调用（int 0x80）功能号__NR_execve调用的函数。函数的参数是进
// 入系统调用处理过程后直接到调用本系统调用处理过程和调用本函数之前逐步压入栈中
// 的值。
// eip - 调用系统中断的程序代码指针。
// tmp - 系统中断中在调用_sys_execve时的返回地址，无用；
// filename - 被执行程序文件名指针；
// argv - 命令行参数指针数组的指针；
// envp - 环境变量指针数组的指针。
// 返回：如果调用成功，则不返回；否则设置出错号，并返回-1.
int do_execve(unsigned long * eip,long tmp,char * filename,
	char ** argv, char ** envp)
{
	struct m_inode * inode;
	struct buffer_head * bh;
	struct exec ex;
	unsigned long page[MAX_ARG_PAGES];
	int i,argc,envc;
	int e_uid, e_gid;
	int retval;
	int sh_bang = 0;                            // 控制是否需要执行的脚本程序
	unsigned long p=PAGE_SIZE*MAX_ARG_PAGES-4;  // p指向参数和环境空间的最后部

    // 在正式设置执行文件的运行环境之前，让我们先干这些杂事。内核准备了128kb(32
    // 个页面)空间来存放化执行文件的命令行参数和环境字符串。上杭把p初始设置成位
    // 于128KB空间中的当前位置。
    // 另外，参数eip[1]是调用本次系统调用的原用户程序代码段寄存器CS值，其中的段
    // 选择符当然必须是当前任务的代码段选择符0x000f.若不是该值，那么CS只能会是
    // 内核代码段的选择符0x0008.但这是绝对不允许的，因为内核代码是常驻内存而不
    // 能被替换掉的。因此下面根据eip[1]的值确认是否符合正常情况。然后再初始化
    // 128KB的参数和环境串空间，把所有字节清零，并取出执行文件的i节点。再根据函
    // 数参数分别计算出命令行参数和环境字符串的个数argc和envc。另外，执行文件必
    // 须是常规文件。
	if ((0xffff & eip[1]) != 0x000f)
		panic("execve called from supervisor mode");
	for (i=0 ; i<MAX_ARG_PAGES ; i++)	/* clear page-table */
		page[i]=0;
	if (!(inode=namei(filename)))		/* get executables inode */
		return -ENOENT;
	argc = count(argv);
	envc = count(envp);
	
restart_interp:
	if (!S_ISREG(inode->i_mode)) {	/* must be regular file */
		retval = -EACCES;
		goto exec_error2;
	}
    // 下面检查当前进程是否有权运行指定的执行文件。即根据执行文件i节点中的属性，
    // 看看本进程是否有权执行它。在把执行文件i节点的属性字段值取到i中后，我们首
    // 先查看属性中是否设置了"设置-用户-ID"(set-user_id)标志和“设置-组-ID”(set_group-id)
    // 标志。这两个标志主要是让一般用户能够执行特权用户(如超级用户root)的程序，
    // 例如改变密码的程序passwd等。如果set-user-id标志置位，则后面执行进程的有
    // 效用户ID(euid)就设置成执行文件的用户ID，否则设置成当前进程的euid。如果执
    // 行文件set-group-id被置位的话，则执行进程的有效组ID（egid）就被设置为执行
    // 文件的组ID。否则设置成当前进程的egid。这里暂时把这两个判断出来的值保存在
    // 变量e_uid和e_gid中。
	i = inode->i_mode;                      // 取文件属性字段
	e_uid = (i & S_ISUID) ? inode->i_uid : current->euid;
	e_gid = (i & S_ISGID) ? inode->i_gid : current->egid;
    // 现在根据进程的euid和egid和执行文件的访问属性进行比较。如果执行文件属于运
    // 行进程的用户，则把文件属性值i右移6位，此时最低3位是文件宿主的访问权限标
    // 志。否则的话如果执行文件与当前进程的用户属性同租，则使属性值最低3位是执
    // 行文件组用户的访问权限标志。否则此时属性值最低3位就是其他用户访问该执行
    // 文件的权限。
    // 然后我们根据属性字i的最低3bit值来判断当前进程是否有权限运行这个执行文件。
    // 如果选出的相应用户没有运行该文件的权利(位0是执行权限)，并且其他用户也没
    // 有任何权限或者当前进程用户不是超级用户，则表明当前进程没有权利运行这个执
    // 行文件。于是置不可执行出错码，并跳转到exec_error2处去做退出处理。
	if (current->euid == inode->i_uid)
		i >>= 6;
	else if (current->egid == inode->i_gid)
		i >>= 3;
	if (!(i & 1) &&
	    !((inode->i_mode & 0111) && suser())) {
		retval = -ENOEXEC;
		goto exec_error2;
	}
    // 程序执行到这里，说明当前进程有运行指定执行文件的权限。因此从这里开始我们
    // 需要取出执行文件头部数据并根据其中的信息来分析设置运行环境，或者运行另一
    // 个shell程序来执行脚本程序。首先读取执行文件第1块数据到高速缓冲块中。并复
    // 制缓冲块数据到ex中。如果执行文件开始的两个字节是字符'#!'，则说明执行文件
    // 是一个脚本文件。如果想运行脚本文件，我们就需要执行脚本文件的解释程序(例
    // 如shell程序)。通常脚本文件的第一行文本为'#!/bin/bash'。他指明了运行脚本
    // 文件需要的解释程序。运行方法从脚本文件第一行中取出其中的解释程序名及后面
    // 的参数(若有的话)，然后将这些参数和脚本文件名放进执行文件（此时是解释程序）
    // 的命令行参数空间中。在这之前我们当然需要先把函数指定的原有命令行参数和环
    // 境字符串放到128KB空间中，而这里建立起来的命令行参数则放到它们前面位置处(
    // 因为是逆向放置)。最后让内核执行脚本文件的解释程序。下面就是在设置好解释
    // 程序的脚本文件名等参数后，取出解释程序的i节点并跳转去执行解释程序。由于
    // 我们需要跳转去执行，因此在下面确认处并处理了脚本文件之后需要设置一个禁止
    // 再次执行下面的脚本处理代码标志sh_bang。在后面的代码中该标志也用来表示我
    // 们已经设置好执行的命令行参数，不用重复设置。
	if (!(bh = bread(inode->i_dev,inode->i_zone[0]))) {
		retval = -EACCES;
		goto exec_error2;
	}
	ex = *((struct exec *) bh->b_data);	/* read exec-header */
	if ((bh->b_data[0] == '#') && (bh->b_data[1] == '!') && (!sh_bang)) {
		/*
		 * This section does the #! interpretation.
		 * Sorta complicated, but hopefully it will work.  -TYT
		 */

		char buf[1023], *cp, *interp, *i_name, *i_arg;
		unsigned long old_fs;

        // 从这里开始，我们从脚本文件中提取解释程序名以及其参数，并把解释程序名、
        // 解释程序的参数和脚本文件名组合放入环境参数块中。首先复制脚本文件头1
        // 行字符'#!'后面的字符串到buf中，其中含有脚本解释程序名，也可能包含解
        // 释程序的几个参数。然后对buf中的内容进行处理。删除开始空格、制表符。
		strncpy(buf, bh->b_data+2, 1022);
		brelse(bh);
		iput(inode);
		buf[1022] = '\0';
		if ((cp = strchr(buf, '\n'))) {
			*cp = '\0';
			for (cp = buf; (*cp == ' ') || (*cp == '\t'); cp++);
		}
		if (!cp || *cp == '\0') {
			retval = -ENOEXEC; /* No interpreter name found */
			goto exec_error1;
		}
        // 此时我们得到了开头是脚本解释程序名的一行内容(字符串)。下面分析改行。
        // 首先取第一个字符串，它应该是解释程序名，此时i_name指向该名称。若解释
        // 程序名后还有字符，则它们应该是解释程序的参数串，于是令i_arg指向该串。
		interp = i_name = cp;
		i_arg = 0;
		for ( ; *cp && (*cp != ' ') && (*cp != '\t'); cp++) {
 			if (*cp == '/')
				i_name = cp+1;
		}
		if (*cp) {
			*cp++ = '\0';
			i_arg = cp;
		}
		/*
		 * OK, we've parsed out the interpreter name and
		 * (optional) argument.
		 */
        // 现在我们要把上面解析出来的解释程序名i_name及其参数i_arg和脚本文件名作
        // 即使程序的参数放进环境和参数块中。不过首先我们需要把函数提供的原来一
        // 些参数和环境字符串先放进去，然后再放这里解析出来的。例如对于命令行参
        // 数来说，如果原来的参数是"-arg1-arg2"、解释程序名是bash、其参数是"-iarg1
        //  -iarg2"、脚本文件名(即原来的执行文件名)是"example.sh"，那么放入这里
        //  的参数之后，新的命令行类似于这样：
        //  "bash -iarg1 -iarg2 example.sh -arg1 -arg2"
        //  这里我们把sh_bang标志置上，然后把函数参数提供的原有参数和环境字符串
        //  放入到空间中。环境字符串和参数个数分别是envc和argc-1个。少复制的一
        //  个原有参数是原来的执行文件名，即这里的脚本文件名。[[??? 这里可以看
        //  出，实际上我们需要去另行处理脚本文件名，即这里完全可以复制argc个参
        //  数，包括原来执行文件名(即现在的脚本文件名)。因为它位于同一个位置上]]
        //  注意！这里指针p随着复制信息增加而逐渐向小地址方向移动，因此这两个复
        //  制串函数执行完后，环境参数串信息块位于程序命令行参数串信息块的上方，
        //  并且p指向程序的第一个参数串。copy_strings()最后一个参数(0)指明参数
        //  字符串在用户空间。
		if (sh_bang++ == 0) {
			p = copy_strings(envc, envp, page, p, 0);
			p = copy_strings(--argc, argv+1, page, p, 0);
		}
		/*
		 * Splice in (1) the interpreter's name for argv[0]
		 *           (2) (optional) argument to interpreter
		 *           (3) filename of shell script
		 *
		 * This is done in reverse order, because of how the
		 * user environment and arguments are stored.
		 */
        // 接着我们逆向复制脚本文件名、解释程序的参数和解释程序文件名到参数和环
        // 境空间中。若出错，则置出错码，跳转到exec_error1。另外，由于本函数参
        // 数提供的脚本文件名filename在用户空间，而这里赋予copy_string()的脚本
        // 文件名指针在内核空间，因此这个复制字符串函数的最后一个参数(字符串来
        // 源标志)需要被设置成1.若字符串在内核空间，则copy_strings()的最后一个
        // 参数要设置成2。
		p = copy_strings(1, &filename, page, p, 1);
		argc++;
		if (i_arg) {
			p = copy_strings(1, &i_arg, page, p, 2);
			argc++;
		}
		p = copy_strings(1, &i_name, page, p, 2);
		argc++;
		if (!p) {
			retval = -ENOMEM;
			goto exec_error1;
		}
		/*
		 * OK, now restart the process with the interpreter's inode.
		 */
        // 最后我们取得解释程序的i节点指针，然后跳转到上面去执行解释程序。为了
        // 获得解释程序的i节点，我们需要使用namei()函数，但是该函数所使用的参数
        // (文件名)是从用户数据空间得到的，即从段寄存器fs指向空间中取得。因此调
        // 用namei()函数之前我们需要先临时让fs指向内核数据空间，以让函数能从内
        // 核空间得到解释程序名，并在namei()返回后恢复fs的默认设置。因此这里我
        // 们先临时保存原fs段寄存器（原指向用户数据段）的值，将其设置成指向内核
        // 数据段，然后取解释程序的i节点。之后再恢复fs的原值。并跳转到restart_interp
        // 出重新处理新的执行文件——脚本文件解释程序。
		old_fs = get_fs();
		set_fs(get_ds());
		if (!(inode=namei(interp))) { /* get executables inode */
			set_fs(old_fs);
			retval = -ENOENT;
			goto exec_error1;
		}
		set_fs(old_fs);
		goto restart_interp;
	}
    // 此时缓冲块中的执行文件头结构数据已经复制到了ex中。于是先释放该缓冲块，并
    // 开始对ex中的执行头信息进行判断处理。对于Linux0.11内核来说，它仅支持ZMAGIC
    // 执行文件格式，并且执行文件代码都从逻辑地址0开始执行，因此不支持含有代码
    // 或数据重定位信息的执行文件。当然，如果执行文件实在太大或者执行文件残缺不
    // 全，那么我们也不能运行它。因此对于下列情况将不执行程序：如果执行文件不是
    // 需求页可执行文件（ZMAGIC）、或者代码和数据重定位部分不等于0，或者（代码段
    // + 数据段+堆）长度超过50MB、或者执行文件长度小于（代码段+数据段+符号表长度
    // +执行头部分）长度的总和。
	brelse(bh);
	if (N_MAGIC(ex) != ZMAGIC || ex.a_trsize || ex.a_drsize ||
		ex.a_text+ex.a_data+ex.a_bss>0x3000000 ||
		inode->i_size < ex.a_text+ex.a_data+ex.a_syms+N_TXTOFF(ex)) {
		retval = -ENOEXEC;
		goto exec_error2;
	}
    // 另外，如果执行文件中代码开始处没有位于1个页面(1024字节)边界处，则也不能
    // 执行。因为需求页(Demand paging)技术要求加载执行文件内容时以页面为单位，
    // 因此要求执行文件映象中代码和数据都从页面边界处开始。
	if (N_TXTOFF(ex) != BLOCK_SIZE) {
		printk("%s: N_TXTOFF != BLOCK_SIZE. See a.out.h.", filename);
		retval = -ENOEXEC;
		goto exec_error2;
	}
    // 如果sh_bang标志没有设置，则复制指定个数的命令行参数和环境字符串到参数和
    // 环境空间中。若sh_bang标志已经设置，则表明是将运行脚本解释程序，此时环境
    // 变量页面已经复制，无须再复制。同样，若sh_bang没有置位而需要复制的话，那
    // 么此时指针p随着复制信息增加而逐渐向小地址方向移动，因此这两个复制串函数
    // 执行完后，环境参数串信息块位于程序参数串信息块上方，并且p指向程序的第1个
    // 参数串。事实上，p是128KB参数和环境空间中的偏移值。因此如果p=0，则表示环
    // 境变量与参数空间页面已经被占满，容纳不下了。
	if (!sh_bang) {
		p = copy_strings(envc,envp,page,p,0);
		p = copy_strings(argc,argv,page,p,0);
		if (!p) {
			retval = -ENOMEM;
			goto exec_error2;
		}
	}
/* OK, This is the point of no return */
    // 前面我们针对函数参数提供的信息对需要运行执行文件的命令行参数和环境空间进
    // 行了设置，但还没有为执行文件做过什么实质性的工作，即还没有做过为执行文件
    // 初始化进程任务结构信息、建立页表等工作。现在我们就来做这些工作。由于执行
    // 文件直接使用当前进程的“躯壳”，即当钱进程将被改造成执行文件的进程，因此我
    // 们需要首先释放当前进程占用的某些系统资源，包括关闭指定的已打开文件、占用
    // 的页表和内存页面等。然后根据执行文件头结构信息修改当前进程使用的局部描述
    // 符表LDT中描述符的内容，重新设置代码段和数据段描述符的限长，再利用前面处
    // 理得到的e_uid和e_gid等信息来设置进程任务结构中相关的字段。最后把执行本次
    // 系统调用程序的返回地址eip[]指向执行文件中代码的其实位置处。这样当本系统
    // 调用退出返回后就会去运行新执行文件的代码了。注意，虽然此时新执行文件代码
    // 和数据还没有从文件中加载到内存中，但其参数和环境块已经在copy_strings()中
    // 使用get_free_page()分配了物理内存页来保存数据，并在change_ldt()函数中使
    // 用put_page()放到了进程逻辑空间的末端处。另外，在create_tables()中也会由
    // 于在用户栈上存放参数和环境指针表而引起缺页异常，从而内存管理程序也会就此
    // 为用户栈空间映射物理内存页。
    //
    // 这里我们首先放回进程原执行程序的i节点，并且让进程executable字段指向新执行
    // 文件的i节点。然后复位原进程的所有信号处理句柄。再根据设定的执行时关闭文件
    // 句柄（close_on_exec）位图标志，关闭指定的打开文件，并复位该标志。
	if (current->executable)
		iput(current->executable);
	current->executable = inode;
	for (i=0 ; i<32 ; i++)
		current->sigaction[i].sa_handler = NULL;
	for (i=0 ; i<NR_OPEN ; i++)
		if ((current->close_on_exec>>i)&1)
			sys_close(i);
	current->close_on_exec = 0;
    // 然后根据当前进程指定的基地址和限长，释放原来程序的代码段和数据段所对应的
    // 内存页表指定的物理内存页面及页表本身。此时新执行文件并没有占用主内存区任
    // 何页面，因此在处理器真正运行新执行文件代码时就会引起缺页异常中断，此时内
    // 存管理程序执行缺页处理而为新执行文件申请内存页面和设置相关表项，并且把相
    // 关执行文件页面读入内存中。如果“上次任务使用了协处理器”指向的是当前进程，
    // 则将其置空，并复位使用了协处理器的标志。
	free_page_tables(get_base(current->ldt[1]),get_limit(0x0f));
	free_page_tables(get_base(current->ldt[2]),get_limit(0x17));
	if (last_task_used_math == current)
		last_task_used_math = NULL;
	current->used_math = 0;
    // 然后我们根据新执行文件头结构中的代码长度字段a_text的值修改局部表中描述符
    // 基地址和段限长，并将128KB的参数和环境空间页面放置在数据段末端。执行下面
    // 语句之后，p此时更改成以数据段起始处为原点的偏移值，但仍指向参数和环境空
    // 间数据开始处，即已转换成为栈指针值。然后调用内部函数create_tables()在栈中
    // 穿件环境和参数变量指针表，供程序的main()作为参数使用，并返回该栈指针。
	p += change_ldt(ex.a_text,page)-MAX_ARG_PAGES*PAGE_SIZE;
	p = (unsigned long) create_tables((char *)p,argc,envc);
    // 接着再修改各字段值为新执行文件的信息。即令进程任务结构代码尾字段end_code
    // 等于执行文件的代码长度a_text；数据尾字段end_data等于执行文件的代码段长度
    // 加数据段长度(a_data+a_text)；并令进程堆结尾字段brk=a_text+a_data+a_bss.
    // brk用于指明进程当前数据段（包括未初始化数据部分）末端位置。然后设置进程
    // 栈开始字段为栈指针所在页面，并重新设置进程的有效用户id和有效组id。
	current->brk = ex.a_bss +
		(current->end_data = ex.a_data +
		(current->end_code = ex.a_text));
	current->start_stack = p & 0xfffff000;
	current->euid = e_uid;
	current->egid = e_gid;
    // 如果执行文件代码加数据长度的末端不再页面边界上，则把最后不到1页长度的内
    // 存过空间初始化为零。
	i = ex.a_text+ex.a_data;
	while (i&0xfff)
		put_fs_byte(0,(char *) (i++));
    // 最后将原调用系统中断的程序在堆栈上的代码指针替换为指向新执行程序的入口点，
    // 并将栈指针替换为执行文件的栈指针。此后返回指令将这些栈数据并使得CPU去执
    // 行新执行文件，因此不会返回到原调用系统中断的程序中去了。
	eip[0] = ex.a_entry;		/* eip, magic happens :-) */
	eip[3] = p;			/* stack pointer */
	return 0;
exec_error2:
	iput(inode);
exec_error1:
	for (i=0 ; i<MAX_ARG_PAGES ; i++)
		free_page(page[i]);
	return(retval);
}

```

# 总结
相对于Windows的PE格式来说该版本的可执行文件格式(a.out)还是简单许多，所以需要配套的编译链接工具提供支持，有时间可以继续分析ELF。

