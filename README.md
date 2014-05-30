nginx-google-oauth
==================

Lua module to add Google OAuth to nginx

## Installation

You can copy `access.lua` to your nginx configurations, or clone the
repository.

## Configuration

Add the access controls in your configuration. Because oauth tickets will be
included in cookies (and you are presumably protecting something very 
important), it is strongly recommended that you use SSL.

```
server {
  server_name supersecret.net;
  listen 443;

  ssl on;
  ssl_certificate /etc/nginx/certs/supersecret.net.pem;
  ssl_certificate_key /etc/nginx/certs/supersecret.net.key;

  set $ngo_app_id 'abc-def.apps.googleusercontent.com';
  set $ngo_app_secret 'abcdefg-123-xyz';
  access_by_lua_file "/etc/nginx/nginx-google-oauth/access.lua";
}

```

The access controls can be configured using nginx variables. The supported
variables are:

- **$ngo_app_id** This is the app id key (see below)
- **$ngo_app_secret** This is the app secret (see below)

## Obtaining OAuth Access

TODO: How get the necessary credentials from Google to use OAuth

## Roadmap

- Make the fixed `/_code` callback URL configurable, or otherwise less generic
- Add support for non-blocking sockets in obtaining an auth token
- Support auth token refresh and timeouts
- Add whitelisting and blacklisting of users 
