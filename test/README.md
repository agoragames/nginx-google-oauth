# Ubuntu 12.04

Run `setup.sh` to install all apt requirements, download and build nginx with lua support. All prefixes will match this directory.

To run nginx, edit `oauth.conf` to use the correct domain and certificates, and then start the server with `sbin/nginx -c oauth.conf`. You should now be able to access the server 
