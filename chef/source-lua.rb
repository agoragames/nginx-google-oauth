#
# Cookbook Name:: nginx
# Recipe:: source-lua
#
# Example recipe, may not be complete. Intended for Ubuntu.
#

include_recipe "build-essential"

# TODO: docs recommend LuaJIT if possible
# http://wiki.nginx.org/HttpLuaModule#Installation_on_Ubuntu_11.10
# TODO: try using "lua-json" instead of lua-cjson
# https://launchpad.net/ubuntu/+source/lua-json
%w{libpcre3 libpcre3-dev libssl-dev liblwp-useragent-determined-perl libpam0g-dev lua5.1 liblua5.1-0 liblua5.1-0-dev cmake liblua5.1-sec-dev liblua5.1-json}.each do |devpkg|
  package devpkg
end

nginx_version = node[:nginx][:version]
configure_flags = node[:nginx][:configure_flags].join(" ")

# download sources
# ----------------

remote_file "/tmp/nginx-#{nginx_version}.tar.gz" do
  source "http://nginx.org/download/nginx-#{nginx_version}.tar.gz"
  action :create_if_missing
end

remote_file "/tmp/ngx_devel_kit-0.2.19.tar.gz" do
  source "https://github.com/simpl/ngx_devel_kit/archive/v0.2.19.tar.gz"
  action :create_if_missing
end

remote_file "/tmp/nginx-lua-0.9.6.tar.gz" do
  source "https://github.com/chaoslawful/lua-nginx-module/archive/v0.9.6.tar.gz"
  action :create_if_missing
end

# compile nginx
# -------------

bash "compile_nginx_source" do
  cwd "/tmp"
  code <<-END
    # extract
    tar zxf nginx-#{nginx_version}.tar.gz
    tar zxf ngx_devel_kit-0.2.19.tar.gz
    tar zxf nginx-lua-0.9.6.tar.gz

    # Lua paths. Requires hack to get linking right.
    ln -s `find /usr/lib -iname liblua5.1.so` /usr/lib/liblua.so
    export LUA_LIB=/usr/lib/
    export LUA_INC=/usr/include/lua5.1

    # compileize
    cd nginx-#{nginx_version}
    ./configure #{configure_flags} \
      --add-module=/tmp/ngx_devel_kit-0.2.19 \
      --add-module=/tmp/lua-nginx-module-0.9.6
    make
    make install
  END
  creates node[:nginx][:src_binary]
end
