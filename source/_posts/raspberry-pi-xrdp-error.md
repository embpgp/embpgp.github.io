---
title: raspberry pi xrdp error
date: 2016-11-07 10:35:42
categories:
- study
tags:
- Configure
- Linux
---

参考资料:
[http://askubuntu.com/questions/648819/couldnt-start-xtightvnc-trying-default-font-path-vncserver](http://askubuntu.com/questions/648819/couldnt-start-xtightvnc-trying-default-font-path-vncserver)

> 关于树莓派的介绍以及使用可参考官方网站  


# 单板Linux
随着嵌入式Linux越来越流行,目前很多厂商都在致力于做单板主机,因此市面上也有很多产品可供选择.其中最具有活力的便是树莓派了,连在**Mr Robot**一剧中都被主人公拿来"打广告".其他诸如香蕉派,香橙派,菠萝派等等pi都有开发团队在开发和维护,有兴趣的可以逐个折腾或者吊的自己绘制PCB制作.

# 访问方式
毫无疑问Web是目前最流行的可视化途径,但是在Linux中最最适合的还是属于console.一般默认在刷入固件之后会默认开启sshd服务,此时便可以通过网络接口ssh连接工具访问树莓派.当然,如果没有开启或者没有通过扫描等方式获取到树莓派的IP地址,则可以借助显示设备或者默认的串口来查看信息,可供选择的是显示接口为HDMI和专用显示接口,一般我们会用HDMI转VGA转接口来接显示屏,此后配置好后便可以当小型服务器用了.

# 配置远程桌面
有些时候console解决不了的时候就必须启用rdp了.Linux中可供选择的桌面系统还是很多的,其中xfce作为流行的轻量级的桌面系统深受好评.一般我们仅仅需要开启xrdp服务即可采用微软的**mstsc**工具来连接Linux主机,但xrdp貌似也是在本地封装vnc服务,因此当vnc服务出现问题的时候即便3389端口处于监听状态也是没辙.无奈只好谷歌.报错信息如下:
```bash
osmc@osmc:~$ vncserver 
Couldn't start Xtightvnc; trying default font path.
Please set correct fontPath in the vncserver script.
Couldn't start Xtightvnc process.

07/11/16 01:04:29 Xvnc version TightVNC-1.3.9
07/11/16 01:04:29 Copyright (C) 2000-2007 TightVNC Group
07/11/16 01:04:29 Copyright (C) 1999 AT&T Laboratories Cambridge
07/11/16 01:04:29 All Rights Reserved.
07/11/16 01:04:29 See http://www.tightvnc.com/ for information on TightVNC
07/11/16 01:04:29 Desktop name 'X' (osmc:1)
07/11/16 01:04:29 Protocol versions supported: 3.3, 3.7, 3.8, 3.7t, 3.8t
07/11/16 01:04:29 Listening for VNC connections on TCP port 5901
Font directory '/usr/share/fonts/X11/misc/' not found - ignoring
Font directory '/usr/share/fonts/X11/Type1/' not found - ignoring
Font directory '/usr/share/fonts/X11/75dpi/' not found - ignoring
Font directory '/usr/share/fonts/X11/100dpi/' not found - ignoring

Fatal server error:
could not open default font 'fixed'
07/11/16 01:04:30 Xvnc version TightVNC-1.3.9
07/11/16 01:04:30 Copyright (C) 2000-2007 TightVNC Group
07/11/16 01:04:30 Copyright (C) 1999 AT&T Laboratories Cambridge
07/11/16 01:04:30 All Rights Reserved.
07/11/16 01:04:30 See http://www.tightvnc.com/ for information on TightVNC
07/11/16 01:04:30 Desktop name 'X' (osmc:1)
07/11/16 01:04:30 Protocol versions supported: 3.3, 3.7, 3.8, 3.7t, 3.8t
07/11/16 01:04:30 Listening for VNC connections on TCP port 5901
Font directory '/usr/share/fonts/X11/misc/' not found - ignoring
Font directory '/usr/share/fonts/X11/Speedo/' not found - ignoring
Font directory '/usr/share/fonts/X11/Type1/' not found - ignoring
Font directory '/usr/share/fonts/X11/75dpi/' not found - ignoring
Font directory '/usr/share/fonts/X11/100dpi/' not found - ignoring

Fatal server error:
could not open default font 'fixed'
```
找了好几个论坛之后又装了好多貌似多余的东西,最后发现仅仅需在[这里](http://askubuntu.com/questions/648819/couldnt-start-xtightvnc-trying-default-font-path-vncserver)键入`sudo apt-get install  xfonts-base`即可解决字体问题了.   


```bash
osmc@osmc:~$ sudo vncserver 

New 'X' desktop is osmc:1

Creating default startup script /root/.vnc/xstartup
Starting applications specified in /root/.vnc/xstartup
Log file is /root/.vnc/osmc:1.log

osmc@osmc:~$ netstat -anot
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       Timer
tcp        0      0 0.0.0.0:5901            0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 0.0.0.0:111             0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 0.0.0.0:6001            0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 127.0.0.1:3350          0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 0.0.0.0:1177            0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 0.0.0.0:36666           0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0      0 0.0.0.0:3389            0.0.0.0:*               LISTEN      off (0.00/0/0)
tcp        0    180 192.168.31.132:22       10.129.95.50:33532      ESTABLISHED on (0.21/0/0)
tcp6       0      0 :::111                  :::*                    LISTEN      off (0.00/0/0)
tcp6       0      0 :::8080                 :::*                    LISTEN      off (0.00/0/0)
tcp6       0      0 :::22                   :::*                    LISTEN      off (0.00/0/0)
tcp6       0      0 :::36666                :::*                    LISTEN      off (0.00/0/0)
tcp6       0      0 :::36667                :::*                    LISTEN      off (0.00/0/0)
tcp6       0      0 ::1:9090                :::*                    LISTEN      off (0.00/0/0)

```
可以看到服务已经开启了,5901端口处于监听状态.再次`mstsc`之后发现error没了,问题解决.
# 总结
遇到问题还是要有折腾的情怀,虽然还不知所以然,但是能够解决这个问题也不辜负**搬砖**的身份...为了不犯第二次错误,便记录下了本文.
