---
title: Hello world
date: 2016-08-16 15:10:22
categories:
- study
tags:
- Configure
---

Hexo and NexT on Github 建博客折腾...
==============

---
**参考资料**  
1. [Hexo.io原装教程:https://hexo.io/zh-cn/docs/](https://hexo.io/zh-cn/docs/ "Hexo官网")  
2. [Next主题配置:http://theme-next.iissnan.com/theme-settings.html](http://theme-next.iissnan.com/theme-settings.html "Next主题")  
3. [不如的教程，很是详细:http://ibruce.info/2013/11/22/hexo-your-blog/](http://ibruce.info/2013/11/22/hexo-your-blog/ "不如的博客")  
4. [bubukoo:http://bubkoo.com/2013/12/16/hexo-issure/](http://bubkoo.com/2013/12/16/hexo-issure/ "tags..")  
5. [新增tags等:http://www.cnblogs.com/debugzer0/articles/5461804.html](http://www.cnblogs.com/debugzer0/articles/5461804.html)  

---

#### 1. 装环境(详情参考官网教程,此处简述，至少github环境安装从略~_~Windows的有点坑)  


**安装Node.js**  
	Wget:  
	`$ wget -qO- https://raw.github.com/creationix/nvm/master/install.sh | sh`  
	安装完成后，重启终端并执行一下命令：  
	`$ nvm install stable`  
**安装Hexo**  
	`$ npm install hexo-cli -g　　#装hexo`   
**初始化项目并开启服务**(在github上建立一个名为username.github.io(或者com)项目，并在本地仓库进行绑定)
```  
	$ hexo init username.github.com　#此处应保证项目(username替换成你的名字)目录已被git remote add等操作过即已经绑定github项目,如果不绑定也能用即可忽略  
	$ cd username.github.com　　　　　　#切换到工作目录   
	$ npm install　　　　#npm加载,从远程端加载默认配置文件到本地  
	$ hexo g　　　#生成相应的文件和文档,每次更改之后都要键入这行命令，或者直接键入hexo g -d就可生成并上传  
	$ hexo s 　　　#开启服务监听，即在本地可以访问，默认是http://localhost:4000,每次可以先在本地浏览无误后上传至github  
	$ hexo d　　　#上传至github,可以在浏览器键入username.github.io二级域名进行访问，在此之前需要配置好_config.yml文件  
```  
#### 2. 配置  
`按照教程更改相应参数即可，若上述命令中遇到有错误，可直接google或者按照错误打印出来的网址进行访问即可得到解决方案,下图是我的github配置,某些情况下可能需要改成使用https,但是仍然可以不必每次都输入账户名和密码`   
![github配置](/images/git.png)
#### 3. 选择主题  
`我觉得加载一个好的主题对一个博客还是很重要的，所以我找了很久，官方放出来的链接在这里`[https://hexo.io/themes/index.html](https://hexo.io/themes/index.html "theme"),`慢慢寻找吧，几乎都是开源可用的，有一些需要一些前端方面的知识．建议选择Next．pacman等经典的主题，即简单又美观.  `  
#### 4. 编辑和发布  
`参考前文教程装好所有的插件(评论系统，统计，打赏系统等)之后就可以自己写文章发布了，在这里注意完成菜单下的各个类别的目录的创建．比如`**hexo new page "tags"**`等，否则会导致访问失败．参考快速写文章的命令以及生成和发布命令可以使得写作是一种享受哦．一起来用MarkDown写博客吧.`  
