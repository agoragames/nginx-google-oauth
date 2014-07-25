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

  set $ngo_client_id 'abc-def.apps.googleusercontent.com';
  set $ngo_client_secret 'abcdefg-123-xyz';
  access_by_lua_file "/etc/nginx/nginx-google-oauth/access.lua";
}

```

The access controls can be configured using nginx variables. The supported
variables are:

- **$ngo_client_id** This is the client id key (see below)
- **$ngo_client_secret** This is the client secret (see below)
- **$ngo_domain** The domain to use for validating users
- **$ngo_callback_scheme** The scheme for the callback URL, defaults to that of the request (e.g. ``https``)
- **$ngo_callback_host** The host for the callback, defaults to first entry in the ``server_name`` list (e.g ``supersecret.net``)
- **$ngo_callback_uri** The URI for the callback, defaults to "/_oauth"
- **$ngo_debug** If defined, will enable debug logging through nginx error logger

## Configuring OAuth Access

Visit https://console.developers.google.com. If you're signed in to multiple
Google accounts, be sure to switch to the one which you want to host the OAuth
credentials (usually your company's Apps domain). This should match
``$ngo_domain`` (e.g. "yourcompany.com").

From the dashboard, create a new project. After selecting that project, you
should see an "APIs & Auth" section in the left-hand navigation. Within that
section, select "Credentials". This will present a page in which you can
generate a Client ID and configure access. Choose "Web application" for the
application type, and enter all origins and redirect URIs you plan to use.

In the "Authorized Javascript Origins" field, enter all the protocols and
domains from which you plan to perform authorization 
(e.g. ``https://supersecret.net``), separated by a newline.

In the "Authorized Redirect URI", enter all of the URLs which the Lua module
will send to Google to redirect after the OAuth workflow has been completed.
By default, this will be the protocol, server_name and ``/_oauth`` (e.g.
``https://supersecret.net/_oauth``. You can override these defaults using the
``$ngo_callback_*`` settings.

After completing the form you will be presented with the Client ID and 
Client Secret which you can use to configure ``$ngo_client_id`` and 
``$ngo_client_secret`` respectively.


## Development

Bug reports and pull requests are [welcome](https://github.com/agoragames/nginx-google-oauth).

It can be useful to turn off [lua_code_cache](http://wiki.nginx.org/HttpLuaModule#lua_code_cache)
while you're iterating.

## Roadmap

- Add support for non-blocking sockets in obtaining an auth token
- Support auth token refresh and timeouts
- Add whitelisting and blacklisting of users 
- Continue support for Ubuntu but make imports work on other platforms as well
