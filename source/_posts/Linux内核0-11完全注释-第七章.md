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
- 注释里面也提到了，task_struct结构体和内核态堆栈都处于同一个页面，因此把两者放在一起构成一个共同体是很正确的用法。
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
