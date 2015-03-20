#!/bin/sh

# This has been tested to work on Ubuntu 12.04. YMMV
PACKAGES="libpcre3 libpcre3-dev libssl-dev liblwp-useragent-determined-perl libpam0g-dev lua5.1 liblua5.1-0 liblua5.1-0-dev cmake liblua5.1-sec-dev liblua5.1-json"
echo "Installing lua and supporting packages"
sudo apt-get install $PACKAGES

mkdir src
cd src

VERSION="1.6.2"
echo "Downloading nginx $VERSION"
wget "http://nginx.org/download/nginx-$VERSION.tar.gz"

echo "Downloading ngx_devel_kit"
wget "https://github.com/simpl/ngx_devel_kit/archive/v0.2.19.tar.gz"
mv v0.2.19.tar.gz ngx_devel_kit-0.2.19.tar.gz

echo "Downloading nginx-lua"
wget "https://github.com/chaoslawful/lua-nginx-module/archive/v0.9.6.tar.gz"
mv v0.9.6.tar.gz nginx-lua-0.9.6.tar.gz

echo "Untarring"
tar zxf nginx-$VERSION.tar.gz
tar zxf ngx_devel_kit-0.2.19.tar.gz
tar zxf nginx-lua-0.9.6.tar.gz

echo "Linking libua to /usr/lib/liblua.so"
sudo ln -s `find /usr/lib -iname liblua5.1.so` /usr/lib/liblua.so

echo "Building nginx"
cd nginx-$VERSION
./configure --add-module=../ngx_devel_kit-0.2.19 --add-module=../lua-nginx-module-0.9.6 --prefix=`readlink -f ../..` --with-http_ssl_module
make install
cd ..
