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
## move_to_user_mode()宏定义
- 这是一段嵌入汇编，gcc在预处理的时候就会完全替代掉。本质是模拟中断返回从内核态转到用户态，但是控制流还是下面那段。相当于虽然从内核态转到用户态但是由于选择子指向的是同一段物理内存空间，所以CPU执行流看起来还是没有什么变化。
- 根据压栈顺序可以知道用户态cs为0x0f，EIP为iret指令下面的标号1处，功能是仅仅将用户态的局部段选择子值送往各个数据段选择器。而后就会执行fork()函数。下面去看一下任务0的全部描述符表的项是如何加载进去的。
```C
#define move_to_user_mode() \
__asm__ ("movl %%esp,%%eax\n\t" \
	"pushl $0x17\n\t" \
	"pushl %%eax\n\t" \
	"pushfl\n\t" \
	"pushl $0x0f\n\t" \
	"pushl $1f\n\t" \
	"iret\n" \
	"1:\tmovl $0x17,%%eax\n\t" \
	"movw %%ax,%%ds\n\t" \
	"movw %%ax,%%es\n\t" \
	"movw %%ax,%%fs\n\t" \
	"movw %%ax,%%gs" \
	:::"ax")
```

## sched_init()
- 我们根据已有的注释可以大概知道这个函数的功能，主要进行了任务0的tss和ldt的加载到GDT中,以及把剩余任务的tss和ldt槽清0。
- 清除掉NT标志，因为并没有任务嵌套并且tss的back_link字段无效。
- 由于是第一次，因此必须手动加载tss到tr以及ldt到ldtr。
- 定时器功能选择，用于定时任务切换调度。
- 加载定时器中断门和系统调用门0x80到gdt。
```C

// 内核调度程序的初始化子程序
void sched_init(void)
{
	int i;
	struct desc_struct * p;                 // 描述符表结构指针

    // Linux系统开发之初，内核不成熟。内核代码会被经常修改。Linus怕自己无意中修改了
    // 这些关键性的数据结构，造成与POSIX标准的不兼容。这里加入下面这个判断语句并无
    // 必要，纯粹是为了提醒自己以及其他修改内核代码的人。
	if (sizeof(struct sigaction) != 16)         // sigaction 是存放有关信号状态的结构
		panic("Struct sigaction MUST be 16 bytes");
    // 在全局描述符表中设置初始任务(任务0)的任务状态段描述符和局部数据表描述符。
    // FIRST_TSS_ENTRY和FIRST_LDT_ENTRY的值分别是4和5，定义在include/linux/sched.h
    // 中；gdt是一个描述符表数组(include/linux/head.h)，实际上对应程序head.s中
    // 全局描述符表基址（_gdt）.因此gtd+FIRST_TSS_ENTRY即为gdt[FIRST_TSS_ENTRY](即为gdt[4]),
    // 也即gdt数组第4项的地址。
	set_tss_desc(gdt+FIRST_TSS_ENTRY,&(init_task.task.tss));
	set_ldt_desc(gdt+FIRST_LDT_ENTRY,&(init_task.task.ldt));
    // 清任务数组和描述符表项(注意 i=1 开始，所以初始任务的描述符还在)。描述符项结构
    // 定义在文件include/linux/head.h中。
	p = gdt+2+FIRST_TSS_ENTRY;
	for(i=1;i<NR_TASKS;i++) {
		task[i] = NULL;
		p->a=p->b=0;
		p++;
		p->a=p->b=0;
		p++;
	}
/* Clear NT, so that we won't have troubles with that later on */
    // NT标志用于控制程序的递归调用(Nested Task)。当NT置位时，那么当前中断任务执行
    // iret指令时就会引起任务切换。NT指出TSS中的back_link字段是否有效。
	__asm__("pushfl ; andl $0xffffbfff,(%esp) ; popfl");        // 复位NT标志
	ltr(0);
	lldt(0);
    // 下面代码用于初始化8253定时器。通道0，选择工作方式3，二进制计数方式。通道0的
    // 输出引脚接在中断控制主芯片的IRQ0上，它每10毫秒发出一个IRQ0请求。LATCH是初始
    // 定时计数值。
	outb_p(0x36,0x43);		/* binary, mode 3, LSB/MSB, ch 0 */
	outb_p(LATCH & 0xff , 0x40);	/* LSB */
	outb(LATCH >> 8 , 0x40);	/* MSB */
    // 设置时钟中断处理程序句柄(设置时钟中断门)。修改中断控制器屏蔽码，允许时钟中断。
    // 然后设置系统调用中断门。这两个设置中断描述符表IDT中描述符在宏定义在文件
    // include/asm/system.h中。
	set_intr_gate(0x20,&timer_interrupt);
	outb(inb_p(0x21)&~0x01,0x21);
	set_system_gate(0x80,&system_call);
}
```

## init_task共同体
- 关于内核态的堆栈"只读"理解见[这里](https://github.com/embpgp/Linux_kernel_0.11_examples/blob/master/chapter4/example_for_multi_tasks/head.s#L180)
- 注释里面也提到了，task_struct结构体和内核态堆栈都处于同一个页面，因此把两者放在一起构成一个共同体是很正确的用法。但得保证task结构体必须放在4K对齐边界，否则在初始化的时候加了个PAGE_SIZE esp0就指到了另外一个内存页了。
```C
// 每个任务(进程)在内核态运行时都有自己的内核态堆栈。这里定义了任务的内核态堆栈结构。
// 定义任务联合(任务结构成员和stack字符数组成员)。因为一个任务的数据结构与其内核态堆栈
// 在同一内存页中，所以从堆栈段寄存器ss可以获得其数据端选择符。
union task_union {
	struct task_struct task;
	char stack[PAGE_SIZE];
};

static union task_union init_task = {INIT_TASK,};   // 定义初始任务的数据
```

## INIT_TASK宏
- 越过前面的任务字段看后面的tss字段可以看到ss0为0x10,esp0为PAGE_SIZE+init_task。
- CR3字段为[pg_dir](https://github.com/embpgp/linux-0.11-lab/blob/master/boot/head.s#L16),其实就是物理地址为0x00000000处，代码运行到[0x5000](https://github.com/embpgp/linux-0.11-lab/blob/master/boot/head.s#L128)之后就开始"粉碎"物理地址0x0000处的代码和数据了。重新建立新的"秩序",一个页目录和4个页表。参见[after_page_tables](https://github.com/embpgp/linux-0.11-lab/blob/master/boot/head.s#L137)和[setup_paging](https://github.com/embpgp/linux-0.11-lab/blob/master/boot/head.s#L200)这两个汇编过程源码。
- 其余字段几乎初始化为默认值(0)。而esp3是由move_to_user_mode()宏来加载的。
- 局部段的代码段和数据段的物理地址还是对应内核一致。
```C

/*
 *  INIT_TASK is used to set up the first task table, touch at
 * your own risk!. Base=0, limit=0x9ffff (=640kB)
 */
#define INIT_TASK \
/* state etc */	{ 0,15,15, \
/* signals */	0,{{},},0, \
/* ec,brk... */	0,0,0,0,0,0, \
/* pid etc.. */	0,-1,0,0,0, \
/* uid etc */	0,0,0,0,0,0, \
/* alarm */	0,0,0,0,0,0, \
/* math */	0, \
/* fs info */	-1,0022,NULL,NULL,NULL,0, \
/* filp */	{NULL,}, \
	{ \
		{0,0}, \
/* ldt */	{0x9f,0xc0fa00}, \
		{0x9f,0xc0f200}, \
	}, \
/*tss*/	{0,PAGE_SIZE+(long)&init_task,0x10,0,0,0,0,(long)&pg_dir,\
	 0,0,0,0,0,0,0,0, \
	 0,0,0x17,0x17,0x17,0x17,0x17,0x17, \
	 _LDT(0),0x80000000, \
		{} \
	}, \
}

```

> 此时已经从内核态返回到了任务0的用户态了，但是控制流已经执行到了fork()函数了，Linux 0.11由一个宏定义来引用，下面继续分析

## fork
- 为了不"污染"任务1的用户栈因此选择使用宏定义来进行fork系统调用。
```C
// Linux在内核空间创建进程时不使用写时复制技术(Copy on write).main()在移动到用户
// 模式（到任务0）后执行内嵌方式的fork()和pause(),因此可保证不适用任务0的用户栈。
// 在执行moveto_user_mode()之后，本程序main()就以任务0的身份在运行了。而任务0是
// 所有将将创建子进程的父进程。当它创建一个子进程时(init进程)，由于任务1代码属于
// 内核空间，因此没有使用写时复制功能。此时任务0的用户栈就是任务1的用户栈，即它们
// 共同使用一个栈空间。因此希望在main.c运行在任务0的环境下不要有对堆栈的任何操作，
// 以免弄乱堆栈。而在再次执行fork()并执行过execve()函数后，被加载程序已不属于内核空间
// 因此可以使用写时复制技术了。
//
// 下面_syscall0()是unistd.h中的内嵌宏代码。以嵌入汇编的形式调用Linux的系统调用中断
// 0x80.该中断是所有系统调用的入口。该条语句实际上是int fork()创建进程系统调用。可展
// 开看之就会立刻明白。syscall0名称中最后的0表示无参数，1表示1个参数。
static inline _syscall0(int,fork)
// int pause() 系统调用，暂停进程的执行，直到收到一个信号
static inline _syscall0(int,pause)
// int setup(void * BIOS)系统调用，仅用于linux初始化(仅在这个程序中被调用)
static inline _syscall1(int,setup,void *,BIOS)
// int sync()系统调用：更新文件系统。
static inline _syscall0(int,sync)
```
- 可以直接跳到kernel/system_call.s的[sys_fork](https://github.com/embpgp/linux-0.11-lab/blob/master/kernel/system_call.s#L208)系统调用源码处查看。
- 可以知道主要进行了两个步骤。
 - find_empty_process:寻找空闲进程号码(个人觉得代码有点"累赘")
 - copy_process:复制进程PCB,并修改某些字段以符合逻辑。关于其具体实现等到mm模块的时候再具体分析。最后在父进程中返回last_pid。

```C
### sys_fork()调用，用于创建子进程，是system_call功能2.
# 首先调用C函数find_empty_process()，取得一个进程号PID。若返回负数则说明目前任务数组
# 已满。然后调用copy_process()复制进程。
.align 2
sys_fork:
	call find_empty_process
	testl %eax,%eax             # 在eax中返回进程号pid。若返回负数则退出。
	js 1f
	push %gs
	pushl %esi
	pushl %edi
	pushl %ebp
	pushl %eax
	call copy_process
	addl $20,%esp               # 丢弃这里所有压栈内容。
1:	ret

```
- 之后main函数(即任务0)就一直死循环执行pause()系统调用。
- 而fork得到的子进程会调用init()函数并继续执行后期初始化。再之后的fork以及execve才调用shell。
- 并且再之后的while(1)循环会一直执行fork & execve。这也是为什么在shell终端键入exit或者退出命令后显示一个进程号并仍然存在shell的原因。
```C
// 在main()中已经进行了系统初始化，包括内存管理、各种硬件设备和驱动程序。init()函数
// 运行在任务0第1次创建的子进程(任务1)中。它首先对第一个将要执行的程序(shell)的环境
// 进行初始化，然后以登录shell方式加载该程序并执行。
void init(void)
{
	int pid,i;

    // setup()是一个系统调用。用于读取硬盘参数包括分区表信息并加载虚拟盘(若存在的话)
    // 和安装根文件系统设备。该函数用25行上的宏定义，对应函数是sys_setup()，在块设备
    // 子目录kernel/blk_drv/hd.c中。
	setup((void *) &drive_info);        // drive_info结构是2个硬盘参数表
    // 下面以读写访问方式打开设备"/dev/tty0",它对应终端控制台。由于这是第一次打开文件
    // 操作，因此产生的文件句柄号(文件描述符)肯定是0。该句柄是UNIX类操作系统默认的
    // 控制台标准输入句柄stdin。这里再把它以读和写的方式别人打开是为了复制产生标准输出(写)
    // 句柄stdout和标准出错输出句柄stderr。函数前面的"(void)"前缀用于表示强制函数无需返回值。
	(void) open("/dev/tty0",O_RDWR,0);
	(void) dup(0);                      // 复制句柄，产生句柄1号——stdout标准输出设备
	(void) dup(0);                      // 复制句柄，产生句柄2号——stderr标准出错输出设备
    // 打印缓冲区块数和总字节数，每块1024字节，以及主内存区空闲内存字节数
	printf("%d buffers = %d bytes buffer space\n\r",NR_BUFFERS,
		NR_BUFFERS*BLOCK_SIZE);
	printf("Free mem: %d bytes\n\r",memory_end-main_memory_start);
    // 下面fork()用于创建一个子进程(任务2)。对于被创建的子进程，fork()将返回0值，对于
    // 原进程(父进程)则返回子进程的进程号pid。该子进程关闭了句柄0(stdin)、以只读方式打开
    // /etc/rc文件，并使用execve()函数将进程自身替换成/bin/sh程序(即shell程序)，然后
    // 执行/bin/sh程序。然后执行/bin/sh程序。所携带的参数和环境变量分别由argv_rc和envp_rc
    // 数组给出。关闭句柄0并立即打开/etc/rc文件的作用是把标准输入stdin重定向到/etc/rc文件。
    // 这样shell程序/bin/sh就可以运行rc文件中的命令。由于这里的sh的运行方式是非交互的，
    // 因此在执行完rc命令后就会立刻退出，进程2也随之结束。
    // _exit()退出时出错码1 - 操作未许可；2 - 文件或目录不存在。
	if (!(pid=fork())) {
		close(0);
		if (open("/etc/rc",O_RDONLY,0))
			_exit(1);                       // 如果打开文件失败，则退出(lib/_exit.c)
		execve("/bin/sh",argv_rc,envp_rc);  // 替换成/bin/sh程序并执行
		_exit(2);                           // 若execve()执行失败则退出。
	}
    // 下面还是父进程(1)执行语句。wait()等待子进程停止或终止，返回值应是子进程的进程号(pid).
    // 这三句的作用是父进程等待子进程的结束。&i是存放返回状态信息的位置。如果wait()返回值
    // 不等于子进程号，则继续等待。
	if (pid>0)
		while (pid != wait(&i))
			/* nothing */;
    // 如果执行到这里，说明刚创建的子进程的执行已停止或终止了。下面循环中首先再创建
    // 一个子进程，如果出错，则显示“初始化程序创建子进程失败”信息并继续执行。对于所
    // 创建的子进程将关闭所有以前还遗留的句柄(stdin, stdout, stderr),新创建一个会话
    // 并设置进程组号，然后重新打开/dev/tty0作为stdin,并复制成stdout和sdterr.再次
    // 执行系统解释程序/bin/sh。但这次执行所选用的参数和环境数组另选了一套。然后父
    // 进程再次运行wait()等待。如果子进程又停止了执行，则在标准输出上显示出错信息
    // “子进程pid挺直了运行，返回码是i”,然后继续重试下去....，形成一个“大”循环。
    // 此外，wait()的另外一个功能是处理孤儿进程。如果一个进程的父进程先终止了，那么
    // 这个进程的父进程就会被设置为这里的init进程(进程1)，并由init进程负责释放一个
    // 已终止进程的任务数据结构等资源。
	while (1) {
		if ((pid=fork())<0) {
			printf("Fork failed in init\r\n");
			continue;
		}
		if (!pid) {                                 // 新的子进程
			close(0);close(1);close(2);
			setsid();                               // 创建一新的会话期
			(void) open("/dev/tty0",O_RDWR,0);
			(void) dup(0);
			(void) dup(0);
			_exit(execve("/bin/sh",argv,envp));
		}
		while (1)
			if (pid == wait(&i))
				break;
		printf("\n\rchild %d died with code %04x\n\r",pid,i);
		sync();                                     // 同步操作，刷新缓冲区。
	}
    // _exit()和exit()都用于正常终止一个函数。但_exit()直接是一个sys_exit系统调用，
    // 而exit()则通常是普通函数库中的一个函数。它会先执行一些清除操作，例如调用
    // 执行各终止处理程序、关闭所有标准IO等，然后调用sys_exit。
	_exit(0);	/* NOTE! _exit, not exit() */
}


```


# 小结
此时Linux 0.11内核已经起来了，当然还有一大波驱动代码和系统调用、库函数、文件系统(重点)和调度策略等等等没有分析，后面将挑出个人认为重点的部分记录。
