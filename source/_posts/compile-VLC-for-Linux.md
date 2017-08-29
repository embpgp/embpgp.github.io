---
title: compile VLC for Linux
date: 2017-08-25 21:26:42
tags:
- Linux
categories: 
- study
---

参考资料：
依赖项：[http://www.cnblogs.com/oloroso/p/4595136.html](http://www.cnblogs.com/oloroso/p/4595136.html)
Aclocal版本重新校正：[https://github.com/threatstack/libmagic/issues/3](https://github.com/threatstack/libmagic/issues/3)
临时卸载QT5：[https://forum.videolan.org/viewtopic.php?t=124188&start=20](https://forum.videolan.org/viewtopic.php?t=124188&start=20)

--------------------------
# 源码下载
* 在[官网](https://www.videolan.org/vlc/download-sources.html)或者[Github仓库](https://github.com/videolan/vlc)将源码下载到本地。
```bash
pgp@r00t:~/github/vlc-2.2.6$ ls 
ABOUT-NLS   autotools  ChangeLog    configure     COPYING      extras   lib         Makefile.am  NEWS    share  THANKS
aclocal.m4  bin        compat       configure.ac  COPYING.LIB  include  m4          Makefile.in  po      src
AUTHORS     bootstrap  config.h.in  contrib       doc          INSTALL  make-alias  modules      README  test
pgp@r00t:~/github/vlc-2.2.6$
```

* 首先查看源码的INSTALL文件了解如何编译源码，如果没有configure文件则需要先运行bootstrap脚本来生成它。

# 编译源码
* 之后运行`./configure`即可配置，此过程可能会遇到很多检查不通过，而且会不断地运行该命令来检查是否配置正确。因此先参考[链接](http://www.cnblogs.com/oloroso/p/4595136.html)来解决一些依赖性问题。对于ubuntu可在终端直接键入`sudo apt-get build-dep vlc`。

* 对于问题“configure: error: "You cannot build VLC with Qt-5.5.0. You need to backport I78ef29975181ee22429c9bd4b11d96d9e68b7a9c"”[网络上](https://forum.videolan.org/viewtopic.php?t=124188&start=20)给出的解决方案是暂时移除Qt5相关库，在编译通过后以后若需要则再安装回来即可。键入`sudo apt remove qt5-default qt5-qmake qtbase5-dev qtbase5-dev-tools libqt5opengl5-dev libqt5x11extras5-dev `,之后继续`./configure`。当遇到如下提示则表明可进行编译了。

```bash
libvlc configuration
--------------------
version               : 2.2.6
system                : linux
architecture          : x86_64 mmx sse sse2
optimizations         : yes
vlc aliases           : cvlc rvlc nvlc

To build vlc and its plugins, type `make', or `./compile' if you like nice colors.
```

* 编译完成


```bash
pgp@r00t:~/github/vlc-2.2.6$ ls 
ABOUT-NLS   bin        compile      config.status  COPYING      doltcompile  INSTALL  make-alias   modules  README  stamp-h1
aclocal.m4  bootstrap  config.h     configure      COPYING.LIB  doltlibtool  lib      Makefile     NEWS     rvlc    test
AUTHORS     ChangeLog  config.h.in  configure.ac   cvlc         extras       libtool  Makefile.am  nvlc     share   THANKS
autotools   compat     config.log   contrib        doc          include      m4       Makefile.in  po       src     vlc
pgp@r00t:~/github/vlc-2.2.6$ ./vlc --version
VLC media player 2.2.6 Umbrella (revision 2.2.6-0-g1aae78981c)
VLC version 2.2.6 Umbrella (2.2.6-0-g1aae78981c)
Compiled by pgp on r00t (Aug 28 2017 10:47:37)
Compiler: gcc version 5.4.0 20160609 (Ubuntu 5.4.0-6ubuntu1~16.04.4)
This program comes with NO WARRANTY, to the extent permitted by law.
You may redistribute it under the terms of the GNU General Public License;
see the file named COPYING for details.
Written by the VideoLAN team; see the AUTHORS file.
pgp@r00t:~/github/vlc-2.2.6$

```

# 总结
搭建VLC编译环境的主要目的还是为了学习一下其内部某些库对于音视频流标准的解析和构建算法。



