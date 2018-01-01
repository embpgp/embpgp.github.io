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
进入src/ln.c,找到main函数,可以看`usage`函数,其实就是`ln --help`的输出.由于重点关注`-sf`参数,因此找到静态变量中对这两个参数相关的`remove_existing_files,interactive,symbolic_link`,即当`-sf`加上的时候,三个变量分别是`true,false,true`.查看代码找到关键几处,一时`no_target_directory`是否为NULL,暂时不考虑-T和-t参数,因此逻辑走到`!target_directory`的else if处,在这里将判断目标链接文件是否为目录的问题,如果命令执行的时候不加,则认为是当前目录.下创建,而>2直接认为非法出`die`了,因此只能等于2,同时短路if语句去执行`target_directory_operand`函数,这个函数将直接根据是否有属于-n参数很大一部分程度来决定目标`target_directory`是否为NULL,如果有-n参数,lstat函数将取到链接文件本身,因此每次这个函数返回false,直接导致`target_directory`指针为NULL,后面将直接执行else语句`ok = do_link (file[0], file[1]);`去了.如果-n没有置位,则根据stat函数取得链接文件指向的文件看是否为目录.`bool is_a_dir = !err && S_ISDIR (st.st_mode);`如果不为目录则也返回false也进入调用者的else逻辑.这些都不会导致'事故'的产生,最常见的是没加-n参数同时链接指向的是一个目录,这个时候就进入if逻辑.由于创建的是软链接,直接定位for循环,个人认为for循环是没必要的,n_files肯定为1,肯定只能执行一次.关键分析`file_name_concat`函数.

## file_name_concat
首先调用者传递的参数中第一个是链接文件路径,第二个是取了`last_component`源文件路径的末尾,即不包括/之前的部分,同时第三个参数暂时没什么用.分析函数逻辑,这个函数主要是拼接路径,通过`DBG`宏定义打印,此函数将直接返回在链接目录下再生成一个链接文件指向源文件,此时很可能就违背了命令执行者的本意了.如下:
```bash
root@Rutk1t0r:coreutils-8.28# src/ln -sf /home/rutk1t0r/ /tmp//test/eee
[src/ln.c][533 main]n_files:2
[src/ln.c][559 main]file[n_files -1] = file[1] = /tmp//test/eee
[src/ln.c][132 target_directory_operand]err:0
[src/ln.c][134 target_directory_operand]is_a_dir:true
[src/ln.c][579 main]target_dir:/tmp//test/eee
[lib/filenamecat-lgpl.c][73 mfile_name_concat][param] dir:/tmp//test/eee, abase:rutk1t0r/
[lib/filenamecat-lgpl.c][77 mfile_name_concat]dirbase:eee, dirbaselen:3, dirlen:14, needs_separator:1, base:rutk1t0r/, baselen:9
[lib/filenamecat-lgpl.c][87 mfile_name_concat]ret value:/tmp//test/eee/rutk1t0r/ ,base_in_result:rutk1t0r/
[src/ln.c][612 main]file:/home/rutk1t0r/, dest:/tmp//test/eee/rutk1t0r
root@Rutk1t0r:coreutils-8.28#

```
若加上-n参数,则执行如下:
```bash
root@Rutk1t0r:coreutils-8.28# src/ln -sfn /home/rutk1t0r/ /tmp//test/eee
[src/ln.c][533 main]n_files:2
[src/ln.c][559 main]file[n_files -1] = file[1] = /tmp//test/eee
[src/ln.c][132 target_directory_operand]err:0
[src/ln.c][134 target_directory_operand]is_a_dir:false
[src/ln.c][579 main]target_dir:(null)
[src/ln.c][619 main]file[0]:/home/rutk1t0r/, file[1]:/tmp//test/eee
root@Rutk1t0r:coreutils-8.28# 
```
具体更改的代码见[Github:https://github.com/embpgp/gnu_coreutils-8.28](https://github.com/embpgp/gnu_coreutils-8.28)
# 总结
个人觉得这段代码写得并不怎么样...