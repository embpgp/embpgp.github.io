---
title: ln -sf target link_name
date: 2017-12-24 22:02:13
categories:
- study
tags:
- coreutils
---

> 进程起不来?

-------------------------
# 事因
Linux下经常会创建软链接来指向真正的路径,特别是Web服务器的配置文件路径.事因是由于在bash脚本中用`ln -sf  target_conf_dir new_dir`,现象是首次执行的时候会正常创建`new_dir`,而当`new_dir`存在的时候,再次执行上述命令现象为在`new_dir`下新建了一个软链接,名字为`target_conf_dir`的base_dir,此时若`new_dir`未指向正确的链接且又用到`new_dir`的时候,错误就发生了,极有可能导致进程运行失败.

# 实验
## down源码
ln是GNU自带的工具链,因此直接去[http://ftp.gnu.org/gnu/coreutils/](http://ftp.gnu.org/gnu/coreutils/),可下载最新版的`coreutils-8.28.tar.xz`,解压后进入目录后经典的GNU三段式源码安装程序,即`configure->make->make install`,单独验证程序逻辑仅仅需要前面两步即可.

## 大致分析ln实现
进入src/ln.c,找到main函数,可以看`usage`函数,其实就是`ln --help`的输出.由于重点关注`-sf`参数,因此找到静态变量中对这两个参数相关的`remove_existing_files,interactive,symbolic_link`,即当`-sf`加上的时候,三个变量分别是`true,false,true`