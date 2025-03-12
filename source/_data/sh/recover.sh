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

: '
hexo v
INFO  Validating config
WARN  Deprecated config detected: "external_link" with a Boolean value is deprecated. See https://hexo.io/docs/configuration for more details.
hexo: 5.4.0
hexo-cli: 4.3.2
os: linux 6.8.0-51-generic Ubuntu 24.04.2 LTS 24.04.2 LTS (Noble Numbat)
node: 16.20.2
v8: 9.4.146.26-node.26
uv: 1.43.0
zlib: 1.2.11
brotli: 1.0.9
ares: 1.19.1
modules: 93
nghttp2: 1.47.0
napi: 8
llhttp: 6.0.11
openssl: 1.1.1v+quic
cldr: 41.0
icu: 71.1
tz: 2022f
unicode: 14.0
ngtcp2: 0.8.1
nghttp3: 0.7.0

'

#hexo clean && hexo g && hexo s
# 本地验证OK后，发布
#hexo d