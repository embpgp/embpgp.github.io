---
title: chromium支持arm64架构验证
date: 2025-03-12 19:04:49
tags:
- Linux
categories: 
- study
---

> html2pdf ?

<!--more-->

参考资料：
[CentOS系统下内存页Page Size如何从64K切换到4K](https://www.hikunpeng.com/document/detail/zh/kunpengfaq/productfaq/osfaq/os_faq_0011.html)
[https://bbs.chinauos.com/zh/post/18054](https://bbs.chinauos.com/zh/post/18054)

# 背景
有一个case是需要在ARM64架构下支持html2pdf，以及crawler功能，其引用的库为puppeteer(或者python下叫pyppeteer),
通过检索后了解到[google官网](https://commondatastorage.googleapis.com/chromium-browser-snapshots/index.html)没有为ARM64架构支持发行版的二进制包，从别的地方搜索可知ubuntu 18.04默认的发型版带了，因此需要做迁移验证。

# 验证
用虚拟化工具安装官方镜像或者直接去云平台服务商购买虚拟机均可以，通过`apt`等工具装上后，如下：


```bash

root@VM-1-28-ubuntu:~# cat /etc/os-release 
NAME="Ubuntu"
VERSION="18.04.6 LTS (Bionic Beaver)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 18.04.6 LTS"
VERSION_ID="18.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
VERSION_CODENAME=bionic
UBUNTU_CODENAME=bionic
root@VM-1-28-ubuntu:~# uname -r
4.15.0-213-generic
root@VM-1-28-ubuntu:~# uname -a
Linux VM-1-28-ubuntu 4.15.0-213-generic #224-Ubuntu SMP Mon Jun 19 13:29:44 UTC 2023 aarch64 aarch64 aarch64 GNU/Linux
root@VM-1-28-ubuntu:~# apt install chromium-browser

root@VM-1-28-ubuntu:~# chromium-browser -v
[13070:13070:0312/192614.751212:ERROR:zygote_host_impl_linux.cc(100)] Running as root without --no-sandbox is not supported. See https://crbug.com/638180.
root@VM-1-28-ubuntu:~# chromium-browser --no-sandbox -v
[13159:13159:0312/192626.645634:ERROR:ozone_platform_x11.cc(239)] Missing X server or $DISPLAY
[13159:13159:0312/192626.645678:ERROR:env.cc(255)] The platform failed to initialize.  Exiting.
root@VM-1-28-ubuntu:~# 


```

安装相关库
```bash

root@VM-1-28-ubuntu:~#  apt install alsa-utils libatk1.0-0 libcups2 libgtk-3-0 fonts-ipafont-gothic libxcomposite1 libxcursor1 libxdamage1 libxext6 libxi6  libxrandr2 libxss1 libxtst6 libpango-1.0-0 xfonts-100dpi xfonts-75dpi xfonts-cyrillic  xfonts-base xfonts-scalable x11-utils libnss3 -y

```
生成pdf，可能会有如下的乱码，可以尝试导入字体库来解决。
![chrome_01.png](/images/chrome_01.png)

```bash
root@VM-1-28-ubuntu:~#  chromium-browser --headless --no-sandbox --disable-gpu --print-to-pdf=./2.pdf  https://www.baidu.com

```

# 支持容器场景部署
上述已经在虚拟机场景跑通了，但是一般业务部署在容器上下文，通过修改基础镜像并打包容器部署到k8s的时候，发现一模一样的镜像，在k8s运行出core，core的方式是收到trap信号被终止，堆栈信息不完整。因此怀疑是host机的问题，有可能是glibc版本不兼容，但是对比用虚拟机跑，glibc版本一致，后面重新做了一个ubuntu 16.04的容器镜像，运行在k8s上的时候，报错`FATAL:page_allocator_internals_posix.h(224)] Check failed: . : Invalid argument (22)`，因此怀疑是内存分页的问题，再次对比容器和虚拟机的分页大小，执行`getconf PAGE_SIZE`，发现k8s上的大小为64K，而正常虚拟机仍为4K，此时只能怀疑是chromium默认采用了4K大小的逻辑编译二进制。后续的兼容方案就是修改服务的部署，采用更换host机，若host机仍为64K的操作系统，则可以更新rpm等包，手动替换内核，host机上再运行k8s或者docker即可，至此问题解决。



