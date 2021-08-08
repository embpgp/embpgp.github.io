---
title: golang init
date: 2021-07-20 23:10:04
categories:
- study
tags:
- go
---

> 拥抱追求高效率生产的云原生时代


<!--more-->
---
**参考资料** 
- [go在线教程](https://github.com/unknwon/the-way-to-go_ZH_CN/blob/master/eBook/directory.md "go在线教程")  
- [leetcode区间合并](https://leetcode-cn.com/problems/merge-intervals/solution/go-er-wei-slicepai-xu-by-todayweather/ "leetcode")
---

# 安装 
此处可以直接搜索网上的教程，建议用goland+插件，可以极大地提高生产效率，试用补丁方案在[这里](https://zhile.io/2020/11/18/jetbrains-eval-reset-da33a93d.html "补丁")参考。

# 小试牛刀

> 采用leetcode刷题学习，题目是要求合并若干区间数组

以数组 intervals 表示若干个区间的集合，其中单个区间为 intervals[i] = [starti, endi] 。请你合并所有重叠的区间，并返回一个不重叠的区间数组，该数组需恰好覆盖输入中的所有区间。

这道题在现实情况的工程问题可能对应着需要找出用户配置的IP端，可以合并下发到数据面。

# 算法思路
> 所以解算法题最先要想到如果达到了目标状态，那些数据应该是什么样的

我们用数组 merged 存储最终的答案。
首先，我们将列表中的区间按照左端点升序排序。然后我们将第一个区间加入 merged 数组中，并按顺序依次考虑之后的每个区间：
如果当前区间的左端点在数组 merged 中最后一个区间的右端点之后，那么它们不会重合，我们可以直接将这个区间加入数组 merged 的末尾；
否则，它们重合，我们需要用当前区间的右端点更新数组 merged 中最后一个区间的右端点，将其置为二者的较大值。
左端点不需要设置，因为已经排序好了。

# 代码 

```go
package main

import (
	"fmt"
	"sort"
)

func min(a, b int) int {
	if a < b {
		return a
	}
	return b

}

func max(a, b int) int {
	if a < b {
		return b
	}
	return a

}

type Element [][]int

func (p Element) Swap(i, j int) { p[i], p[j] = p[j], p[i] }
func (p Element) Len() int      { return len(p) }

//判断i位置的元素是否比j位置的元素小，如果为真，sort方法会调用swap函数交换
//但是sort函数本身实现是根据从后往前判断的，因此还是默认为升序
//参考sort.sort函数实现的源码
//https://golang.org/src/sort/sort.go
func (p Element) Less(i, j int) bool {
	return p[i][0] < p[j][0]
}

/*
leetcode来源：
思路
按照最终的排序状态，肯定是连续的集合
*/
func merge(intervals [][]int) [][]int {

	ret := make([][]int, 0)
	sort.Sort(Element(intervals))
	retIndex := 0
	ret = append(ret, intervals[0])
	for i := 1; i < len(intervals); i++ {
		if ret[retIndex][1] < intervals[i][0] { // 当前扫描区间和前一区间不重合，则直接添加到结果中
			ret = append(ret, intervals[i])
			retIndex++
		} else { // 相邻两个区间重合，则合并成一个区间
			//ret[retIndex][0] = min(ret[retIndex][0], intervals[i][0]) //左值已经排序好了
			ret[retIndex][1] = max(ret[retIndex][1], intervals[i][1])
		}
	}

	return ret
}

func main() {
	array := [][]int{{1, 3}, {2, 6}, {8, 10}, {15, 18}}
	out := merge(array)
	fmt.Println((out))
}

```


# 总结
轮子好啊


