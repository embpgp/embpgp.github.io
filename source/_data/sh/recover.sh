#!/bin/bash

#拉代码,目前是hexo_dev分支开发
git clone git@github.com:embpgp/embpgp.github.io.git
git checkout hexo_dev

# install nvm

wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# 指定node版本
nvm install 16.20.2
nvm use 16.20.2
node -v

# 下载主题 复用相关配置
rm -rf themes/next
git clone https://github.com/next-theme/hexo-theme-next themes/next
cp source/_data/20210718_next_config.yml ./themes/next/_config.yml


# 指定hexo版本，并尝试修复一些问题

rm node_modules -rf
npm install hexo@4.2.1
npm install hexo@5.4.0 -f
npm install -f

#hexo clean && hexo g && hexo s
# 本地验证OK后，发布
#hexo d