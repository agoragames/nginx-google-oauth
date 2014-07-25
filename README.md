nginx-google-oauth
==================

Lua module to add Google OAuth to nginx.

## Installation

You can copy `access.lua` to your nginx configurations, or clone the
repository. Your installation of nginx must already be built with Lua
support, and you will need the ``cjson`` and ``luasec`` modules as well.

### Ubuntu

You will need to install the following packages.

```
lua5.1
liblua5.1-0
liblua5.1-0-dev
liblua5.1-sec-dev
```

You will also need to download and build the following and link them
with nginx

```
ngx_devel_kit
lua-nginx-module
lua-cjson-2.1.0
```

See ``/chef/source-lua.rb`` for a Chef recipe to install nginx and Lua
with all of the requirements.


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

  set $ngo_client_id "abc-def.apps.googleusercontent.com";
  set $ngo_client_secret "abcdefg-123-xyz";
  set $ngo_secure_cookies "true";
  access_by_lua_file "/etc/nginx/nginx-google-oauth/access.lua";
}

```

The access controls can be configured using nginx variables. The supported
variables are:

- **$ngo_client_id** This is the client id key
- **$ngo_client_secret** This is the client secret
- **$ngo_domain** The domain to use for validating users when not using white- or blacklists
- **$ngo_whitelist** Optional list of authorized email addresses
- **$ngo_blacklist** Optional list of unauthorized email addresses
- **$ngo_callback_scheme** The scheme for the callback URL, defaults to that of the request (e.g. ``https``)
- **$ngo_callback_host** The host for the callback, defaults to first entry in the ``server_name`` list (e.g ``supersecret.net``)
- **$ngo_callback_uri** The URI for the callback, defaults to "/_oauth"
- **$ngo_debug** If defined, will enable debug logging through nginx error logger
- **$ngo_secure_cookies** If defined, will ensure that cookies can only be transfered over a secure connection
- **$ngo_css** An optional stylesheet to replace the default stylesheet when using the body_filter

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

If you need to further limit access within your organization, you can use
``$ngo_whitelist`` and/or ``$ngo_blacklist``. Both should be formatted as
a space-separated list of allowed (whitelist) or rejected (blacklist) email
addresses. If either of these values are defined, the ``$ngo_domain`` will
not be used for validating that the user is authorized to access the protected
resource.

## Body filter

If you want visual confirmation of successful authentication, you can use the
``body_filter.lua`` script to inject a header into your web application. Your
nginx configuration should look something like this:

```
server {
  server_name supersecret.net;
  listen 443;

  set $ngo_client_id 'abc-def.apps.googleusercontent.com';
  set $ngo_client_secret 'abcdefg-123-xyz';
  access_by_lua_file "/etc/nginx/nginx-google-oauth/access.lua";

  location / {
    header_filter_by_lua "ngx.header.content_length = nil";
    body_filter_by_lua_file "/etc/nginx/nginx-google-oauth/body_filter.lua";

    proxy_set_header Accept-Encoding "";
    proxy_pass http://supersecret-backend;
  }
}

```

The ``header_filter_by_lua`` directive is required so that the 
``content_length`` header returned by the backend is stripped and re-calculated
after the body filter has been applied.

The ``Accept-Encoding`` directive is recommended in cases where the backend
may be returning a gzipped document, in which case nginx will not decompress
the document before sending it to the body filter.

The ``body_filter_by_lua_file`` directive causes all responses from the backend
to be routed through a lua script that will inject a div just after the opening
``<body>`` element. The div will take the form of:

```html
<div class="ngo_auth">
  <img src="google-oauth-profile-pic" />
  <span class="ngo_user">google-oauth-user-name</span>
  <span class="ngo_email">google-oauth-email</span>
</div>
```

If ``$ngo_css`` is defined, the default stylesheet will be overridden,
otherwise the stylesheet will be:

```css
<style>
  div.ngo_auth { width: 100%; background-color: #6199DF; color: white; padding: 0.5em 0em 0. 5em 2em; vertical-align: middle; margin: 0; }
  div.ngo_auth > img { width: auto; height: 2em; margin: 0 1em 0 0; padding: 0; }
  div.ngo_auth > span.ngo_user { font-weight: bold; margin-right: 1em; }
</style>

```

The filter operates by performing a regular expression match on ``<body>``,
and so should act as a no-op for non-HTML content types. It may be necessary
to use the body filter only on a subset of routes depending on your application.

## Development

Bug reports and pull requests are [welcome](https://github.com/agoragames/nginx-google-oauth).

It can be useful to turn off [lua_code_cache](http://wiki.nginx.org/HttpLuaModule#lua_code_cache)
while you're iterating.

## Roadmap

- Add support for non-blocking sockets in obtaining an auth token
- Support auth token refresh and timeouts
- Continue support for Ubuntu but make imports work on other platforms as well
- Replace cjson requirement with "standard" Lua json

## Copyright

Copyright 2014 Aaron Westendorf

## License

MIT

## Thanks

This project wouldn't have gone beyond the idea stage without the excellent
example provided by [SeatGeek](http://chairnerd.seatgeek.com/oauth-support-for-nginx-with-lua/).
