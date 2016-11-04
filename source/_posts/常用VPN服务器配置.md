---
title: 常用VPN服务器配置
date: 2016-10-27 23:29:29
categories:
- study
tags:
- Configure
- network security
---


参考资料:  
[https://www.nigesb.com/setup-your-own-vpn-with-pptp.html](https://www.nigesb.com/setup-your-own-vpn-with-pptp.html)
`sudo apt-get install pptpd`  
编辑/etc/pptpd.conf    
`localip 10.0.0.1`
`remoteip 10.0.0.100-200`


修改/etc/ppp/pptpd-options.pptpd

`ms-dns 202.96.128.86`
`ms-dns 202.96.128.166`

/etc/ppp/chap-secrets
次为：账号，协议，密码，ip地址。


编辑系统配置文件/etc/sysctl.conf

`net.ipv4.ip_forward = 1`


`sysctl -p`




`iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE`
`iptables -A FORWARD -p tcp --syn -s 10.0.0.0/24 -j TCPMSS --set-mss 1356`
`iptables-save`




系统环境：Debian-6 32-bit

iptables是即时生效的，所以无需重启，如果要停止iptables，请使用iptables -F命令，如果要iptables配置重启后仍然有效，请按如下操作步骤

1.创建/etc/iptables文件(文件名可以随意取)

2.创建/etc/network/if-pre-up.d/iptables文件，并给予其执行权限
`root@hostname:~# touch /etc/network/if-pre-up.d/iptables`
`root@hostname:~# chmod +x /etc/network/if-pre-up.d/iptables`

3.编辑/etc/network/if-pre-up.d/iptables文件，使其内容如下：
```bash
#!/bin/sh
 /sbin/iptables-restore < /etc/iptables
 ```
 4.配置iptables，过程略，配置好iptables后，将配置保存到/etc/iptables文件中即可
 root@hostname:~# iptables-save > /etc/iptables

 //配置openvpn
 http://www.zhengyali.com/?p=52
 http://www.zhengyali.com/?p=66
 http://blog.csdn.net/brad_chen/article/details/49633491
 http://openvpn.ustc.edu.cn/




 openvpn之树莓派问题



 `sudo apt-get purge openvpn liblzo2-2`
 `sudo apt-get install openvpn`
