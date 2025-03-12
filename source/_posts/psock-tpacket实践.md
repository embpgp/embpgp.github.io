---
title: psock_tpacket实践
date: 2025-03-11 22:41:54
categories:
- study
- misc
tags:
- C/C++
---

> 抓包原理初识

<!--more-->

参考资料:
[https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.10.1.tar.gz](https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.10.1.tar.gz)
[https://docs.kernel.org/networking/packet_mmap.html](https://docs.kernel.org/networking/packet_mmap.html)
[https://www.zhihu.com/question/486178226/answer/2587632732](https://www.zhihu.com/question/486178226/answer/2587632732)
[https://jgsun.github.io/2019/01/21/linux-tcpdump/](https://jgsun.github.io/2019/01/21/linux-tcpdump/)

--- 

> 分析 tools/testing/selftests/net/psock_tpacket.c

# 下载内核源码并编译测试程序
`cd linux-3.10.1/tools/testing/selftests/net && make` 
![tpacket_compile](/images/tpacket_01.png)


# 分析初始化
首先定位到pfsocket函数，其中需要初始化一个domain为PF_PACKET，type为SOCK_RAW的套接字，通过分析PF_PACKET是宏定义AF_PACKET一样的值，
而在Linux内核的介绍当中AF_PACKET专门用来嗅探流量用的，类似wireshark和tcpdump;当调用到setsockopt的时候，内核对应packet_setsockopt函数，

```C 
static int pfsocket(int ver)
{
	int ret, sock = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
	if (sock == -1) {
		perror("socket");
		exit(1);
	}

	ret = setsockopt(sock, SOL_PACKET, PACKET_VERSION, &ver, sizeof(ver));
	if (ret == -1) {
		perror("setsockopt");
		exit(1);
	}

	return sock;
}

```


直接看V3版本（当然最正确的方式是根据当前内核支持的版本自动选择v1/v2/v3）,设置版本的时候只是简单给po->tp_version赋值。
当再次调用设置PACKET_RX_RING或者PACKET_TX_RING的时候，会进入到packet_set_ring，这里会根据应用层的配置（例如使用mmap方案）来决定使用
哪个收包函数，在有环形缓冲区的方案情况下，会调用`pg_vec = alloc_pg_vec(req, order);` 申请内存页面，并指向当前的sock的，等待后续应用层调用
mmap的时候，通过给应用程序插入vma并指向同样的内存区域，
                    
```C
...


	case PACKET_RX_RING:
	case PACKET_TX_RING:
	{
		union tpacket_req_u req_u;
		int len;

		switch (po->tp_version) {
		case TPACKET_V1:
		case TPACKET_V2:
			len = sizeof(req_u.req);
			break;
		case TPACKET_V3:
		default:
			len = sizeof(req_u.req3);
			break;
		}
		if (optlen < len)
			return -EINVAL;
		if (pkt_sk(sk)->has_vnet_hdr)
			return -EINVAL;
		if (copy_from_user(&req_u.req, optval, len))
			return -EFAULT;
		return packet_set_ring(sk, &req_u, 0,
			optname == PACKET_TX_RING);
	}

...
	case PACKET_VERSION:
	{
		int val;

		if (optlen != sizeof(val))
			return -EINVAL;
		if (po->rx_ring.pg_vec || po->tx_ring.pg_vec)
			return -EBUSY;
		if (copy_from_user(&val, optval, sizeof(val)))
			return -EFAULT;
		switch (val) {
		case TPACKET_V1:
		case TPACKET_V2:
		case TPACKET_V3:
			po->tp_version = val;
			return 0;
		default:
			return -EINVAL;
		}
	}
...
```

在这里会判断是否有环形缓冲区来决定采用哪个收包函数
`po->prot_hook.func = (po->rx_ring.pg_vec) ?
						tpacket_rcv : packet_rcv;`

两者的差异可以参考上述 [https://jgsun.github.io/2019/01/21/linux-tcpdump/](https://jgsun.github.io/2019/01/21/linux-tcpdump/)



```C
...
    if (closing || atomic_read(&po->mapped) == 0) {
		err = 0;
		spin_lock_bh(&rb_queue->lock);
		swap(rb->pg_vec, pg_vec);
		rb->frame_max = (req->tp_frame_nr - 1);
		rb->head = 0;
		rb->frame_size = req->tp_frame_size;
		spin_unlock_bh(&rb_queue->lock);

		swap(rb->pg_vec_order, order);
		swap(rb->pg_vec_len, req->tp_block_nr);

		rb->pg_vec_pages = req->tp_block_size/PAGE_SIZE;
		po->prot_hook.func = (po->rx_ring.pg_vec) ?
						tpacket_rcv : packet_rcv;
		skb_queue_purge(rb_queue);
		if (atomic_read(&po->mapped))
			pr_err("packet_mmap: vma is busy: %d\n",
			       atomic_read(&po->mapped));
	}
...
```

也可以简单查看下面的视图。

```
+---------------------+
|  Network Interface  |
+----------+----------+
           |
           v
+----------+----------+
|   Protocol Hook     |
|   (prot_hook.func)  +---> [ tpacket_rcv ] 带环形缓冲区
|                     |       |
+----------+----------+       | 直接写入共享内存
           |                  |
           |                  v
           |        +---------+---------+
           |        |  Ring Buffer      |
           |        | (pg_vec)          |
           |        +-------------------+
           |
           v
+----------+----------+
|   packet_rcv        +---> 传统接收路径
|                     |      (sk_receive_queue)
+---------------------+


```

当应用程序调用mmap的时候，其中第一个参数fd是PF_PACKET类型的，最终会调用到内核的packet_mmap函数，通过调用`vm_insert_page`
将环形缓冲区的地址插入到进程的vma里面，应用程序可以正常访问。

```C
...

	start = vma->vm_start;
	for (rb = &po->rx_ring; rb <= &po->tx_ring; rb++) {
		if (rb->pg_vec == NULL)
			continue;

		for (i = 0; i < rb->pg_vec_len; i++) {
			struct page *page;
			void *kaddr = rb->pg_vec[i].buffer;
			int pg_num;

			for (pg_num = 0; pg_num < rb->pg_vec_pages; pg_num++) {
				page = pgv_to_page(kaddr);
				err = vm_insert_page(vma, start, page);
				if (unlikely(err))
					goto out;
				start += PAGE_SIZE;
				kaddr += PAGE_SIZE;
			}
		}
	}
...

```

而后就是bind具体的网卡，可以选择any，这里可以通过SOL_SOCKET层配合SO_ATTACH_FILTER，注入类似于tcpdump的过滤语法规则，而后数据流就开始了。


# AF_PACKET收包流程
当应用层通过poll或者其他的轮询方式发现rx_ring有可读的数据的时候，就可以将数据包做进一步处理了。正常网卡先通过软中断经过gro等操作后，在进入协议栈之前
会在`__netif_receive_skb_core`函数寻找注册的ptype_all找到回调函数，在这里
AF_PACKET的就是tpacket_rcv。

```C
...
	list_for_each_entry_rcu(ptype, &ptype_all, list) {
		if (!ptype->dev || ptype->dev == skb->dev) {
			if (pt_prev)
				ret = deliver_skb(skb, pt_prev, orig_dev);
			pt_prev = ptype;
		}
	}

...

```


跑`run_filter`是否匹配目标数据包，若不命中就直接跳过，否则通过
`h.raw = packet_current_rx_frame(po, skb,
					TP_STATUS_KERNEL, (macoff+snaplen));`寻找一个
空闲frame，调用`skb_copy_bits(skb, 0, h.raw + macoff, snaplen);`将skb的线性区和分片区（若有，存储在skb_shinfo指向的多个页面以及关联的SKB分片链表一次性拷贝到`h.raw + macoff`,而后更新status，并通过`sk->sk_data_ready(sk, 0);`唤醒应用进程，此时应用层拿到的frame就是现成的数据包了。

```C
...

	snaplen = skb->len;

	res = run_filter(skb, sk, snaplen);
	if (!res)
		goto drop_n_restore;
	if (snaplen > res)
		snaplen = res;

...


```

# 应用层处理
V3版本直接调用walk_v3_rx处理，通过`__v3_walk_block`将数据包摘下来（比如在拷贝到预申请的应用层缓冲区，然后调用`__v3_flush_block`刷新块状态，内核便可以继续读写该块。

> 这里可以简单再用一个udp套接字，将拿到的数据包，再通过`sendto`转发出去（流量采集），以实现类似网络流量分析的功能。考虑到CPU开销问题，有一些优化思路：
1、可以先用sendmmsg批量发送（内核最大1024），即应用层每缓存1024的数据包发起一次系统调用，将数据批量拷贝到内核发送，以降低系统调用次数；2、通过AF_PACKET的发送缓冲区mmap，直接从rx_ring摘下来后，稍微"加工"一下写入另一个AF_PACKET发送出去，这就需要自己构造L2-L4等，进一步降低拷贝带来的CPU开销。3、通过将GRO的思想移植到应用层，进一步降低发送端PPS，这样的话就需要应用层缓存抓取的流量，需要实际的测试数据对比第2点。
```C
static void walk_v3(int sock, struct ring *ring)
{
	if (ring->type == PACKET_RX_RING)
		walk_v3_rx(sock, ring);
	else
		bug_on(1);
}


static void walk_v3_rx(int sock, struct ring *ring)
{
        unsigned int block_num = 0;
        struct pollfd pfd;
        struct block_desc *pbd;
        int udp_sock[2];

        bug_on(ring->type != PACKET_RX_RING);

        pair_udp_open(udp_sock, PORT_BASE);
        pair_udp_setfilter(sock);

        memset(&pfd, 0, sizeof(pfd));
        pfd.fd = sock;
        pfd.events = POLLIN | POLLERR;
        pfd.revents = 0;

        pair_udp_send(udp_sock, NUM_PACKETS);

        while (total_packets < NUM_PACKETS * 2) {
                pbd = (struct block_desc *) ring->rd[block_num].iov_base;

                while ((BLOCK_STATUS(pbd) & TP_STATUS_USER) == 0)
                        poll(&pfd, 1, 1);

                __v3_walk_block(pbd, block_num);
                __v3_flush_block(pbd);

                block_num = (block_num + 1) % ring->rd_num;
        }

        pair_udp_close(udp_sock);

        if (total_packets != 2 * NUM_PACKETS) {
                fprintf(stderr, "walk_v3_rx: received %u out of %u pkts\n",
                        total_packets, NUM_PACKETS);
                exit(1);
        }

        fprintf(stderr, " %u pkts (%u bytes)", NUM_PACKETS, total_bytes >> 1);
}



```

# 展望
结合ebpf技术，轻量级agent支持旁路https解密，分析主动外联场景。 参考[https://github.com/gojue/ecapture](https://github.com/gojue/ecapture)