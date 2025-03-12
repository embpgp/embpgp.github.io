---
title: VPC网络打通研究
date: 2021-08-08 11:15:28
categories:
- study
tags:
- go
- 设计
- 网络
---

> 云内网络打通

<!--more-->
--- 
**参考资料**
- [gofrp](https://gofrp.org/docs/ "frp")
- [n2n](https://github.com/ntop/n2n "n2n")
- [nps](https://github.com/ehang-io/nps/blob/master/README_zh.md "nps")
---

# 背景

在云内多VPC场景下，需要实现多NFV极简+管控+运维+部署。传统的安全管理平台采用平台侧主动推送和纳管NFV组件， 但是在VPC场景下网络打通存在中间的访问控制策略隔离，以及私有网络的暴露面问题。

# 思路
- 正向打通：网络往往采用NAT技术或者代理服务器，将内网的服务暴露出来，但是这样的运维成本较大，且存在安全性问题。 采用VPN技术需要两端都外挂前置设备或者软件。
- 逆向打通：技术上采用将原本的服务端安装一个client_agent，通过反向的先让client_agent接入原本的客户端的server_proxy， 然后代理程序本身实现IP级别或者PORT级别的隧道数据转发，下面分析逆向打通的几个方案。


# 开源方案

| 技术方案 | 优点 | 缺点 |
| :-----:| :----: | :----: |
| N2N |功能丰富，满足需求，实现IP2IP级别访问  | 采用内核方案，稳定性差  |
| NPS | 功能丰富，控制面安全性较好 | GPL协议无法商用 |
| FRP | 功能较丰富，apache协议可以商用| 控制面安全性一般 | 

# FRP方案分析

为了满足商用需求，可以考虑采用FRP作为VPC网络打通数据面的方案，默认监听7000端口。
引入另外的独立的控制面来负责FRP的统一管理/升级维护/横向扩展/高可用等，以满足持续迭代的需求。

# 配置方法
参考[官网教程](https://gofrp.org/docs/examples/ssh/ "示例") 直接配置frpc.ini和frps.ini即可
> 因此在client上如何管理好frpc.ini是重点.

frps.ini
```ini
[common]
bind_port = 7000
```
- 可以选择默认启用tls_only选项以及token。
- 可以启用服务端插件功能获取frpc的接入上下文来实现访问控制。

frpc.ini 
```ini
[common]
server_addr = x.x.x.x
server_port = 7000

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 6000
```
绝大部分的业务都是tcp。这里可以通过设置local_ip为路由可达的服务器地址，而不仅仅局限于本地通信，因为经常作为hacker的横向扩展工具使用。 具体参考[配置文件](https://gofrp.org/docs/reference/ "配置")。

# 总结
- 多学习开源项目的设计思路
- 多看看开源代码的编码风格

