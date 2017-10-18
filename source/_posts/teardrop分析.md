---
title: teardrop分析
date: 2017-10-18 15:13:09
categories:
- study
tags:
- Linux kernel
- network security
---

> 按照要求要丢弃掉这种数据包...

-------------------------
参考资料:
[http://blog.csdn.net/opens_tym/article/details/17737419](http://blog.csdn.net/opens_tym/article/details/17737419)
[https://segmentfault.com/a/1190000008836467](https://segmentfault.com/a/1190000008836467)
[http://zgykill.lofter.com/tag/Linux](http://zgykill.lofter.com/tag/Linux)
[https://www.juniper.net/documentation/en_US/junos/topics/concept/denial-of-service-os-teardrop-attack-understanding.html](https://www.juniper.net/documentation/en_US/junos/topics/concept/denial-of-service-os-teardrop-attack-understanding.html)
[http://www.nsfocus.net/index.php?act=magazine&do=view&mid=584](http://www.nsfocus.net/index.php?act=magazine&do=view&mid=584)
[https://www.samsclass.info/123/proj10/teardrop.htm](https://www.samsclass.info/123/proj10/teardrop.htm)

# 原理
teardrop主要是利用操作系统协议栈处理IP分片的时候,对于畸形数据包重叠其余分片来使得重组算法发生错误,轻则发生内存泄露重则造成宕机或者拒绝服务.可以参考绿盟分析Linux 2.0内核时期的漏洞原理.而从2.4开始内核就修复了这个漏洞,并尝试如果可能就尽量修复重叠的数据包.具体参见以下代码:
```C
	/* We found where to put this one.  Check for overlap with
	 * preceding fragment, and, if needed, align things so that
	 * any overlaps are eliminated.
	 */
	if (prev) {
		int i = (FRAG_CB(prev)->offset + prev->len) - offset;

		if (i > 0) {
			offset += i;
			err = -EINVAL;
			if (end <= offset)
				goto err;
			err = -ENOMEM;
			if (!pskb_pull(skb, i))
				goto err;
			if (skb->ip_summed != CHECKSUM_UNNECESSARY)
				skb->ip_summed = CHECKSUM_NONE;
		}
	}

	err = -ENOMEM;

	while (next && FRAG_CB(next)->offset < end) {
		int i = end - FRAG_CB(next)->offset; /* overlap is 'i' bytes */

		if (i < next->len) {
			/* Eat head of the next overlapped fragment
			 * and leave the loop. The next ones cannot overlap.
			 */
			if (!pskb_pull(next, i))
				goto err;
			FRAG_CB(next)->offset += i;
			qp->q.meat -= i;
			if (next->ip_summed != CHECKSUM_UNNECESSARY)
				next->ip_summed = CHECKSUM_NONE;
			break;
		} else {
			struct sk_buff *free_it = next;

			/* Old fragment is completely overridden with
			 * new one drop it.
			 */
			next = next->next;

			if (prev)
				prev->next = next;
			else
				qp->q.fragments = next;

			qp->q.meat -= free_it->len;
			frag_kfree_skb(qp->q.net, free_it, NULL);
		}
	}

```
