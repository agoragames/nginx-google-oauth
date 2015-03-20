 
-- import requirements

-- allow either cjson, or th-LuaJSON
local has_cjson, jsonmod = pcall(require, "cjson")
if not has_cjson then
  jsonmod = require "json"
end

-- Ubuntu broke the install. Puts the source in /usr/share/lua/5.1/https.lua,
-- but since the source defines itself as the module "ssl.https", after we
-- load the source, we need to grab the actual thing.
pcall(require,"https")
local https = require "ssl.https" -- /usr/share/lua/5.1/https.lua
local ltn12  = require("ltn12")
 
local uri = ngx.var.uri
local uri_args = ngx.req.get_uri_args()
local scheme = ngx.var.scheme
local server_name = ngx.var.server_name

-- setup some app-level vars
local client_id = ngx.var.ngo_client_id
local client_secret = ngx.var.ngo_client_secret
local domain = ngx.var.ngo_domain
local cb_scheme = ngx.var.ngo_callback_scheme or scheme
local cb_server_name = ngx.var.ngo_callback_host or server_name
local cb_uri = ngx.var.ngo_callback_uri or "/_oauth"
local cb_url = cb_scheme.."://"..cb_server_name..cb_uri
local redir_url = cb_scheme.."://"..cb_server_name..uri
local signout_uri = ngx.var.ngo_signout_uri or "/_signout"
local debug = ngx.var.ngo_debug
local whitelist = ngx.var.ngo_whitelist
local blacklist = ngx.var.ngo_blacklist
local secure_cookies = ngx.var.ngo_secure_cookies
local token_secret = ngx.var.ngo_token_secret or "UNSET"
local set_user = ngx.var.ngo_user
local email_as_user = ngx.var.ngo_email_as_user

-- Force the user to set a token secret
if token_secret == "UNSET" then
  ngx.log(ngx.ERR, "$ngo_token_secret must be set in Nginx config!")
  return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- See https://developers.google.com/accounts/docs/OAuth2WebServer 
if uri == signout_uri then
  ngx.header["Set-Cookie"] = "AccessToken=deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT"
  return ngx.redirect(cb_scheme.."://"..server_name)
end

-- Enforce token security and expiration
local oauth_expires = tonumber(ngx.var.cookie_OauthExpires) or 0
local oauth_email = ngx.unescape_uri(ngx.var.cookie_OauthEmail or "")
local oauth_access_token = ngx.unescape_uri(ngx.var.cookie_OauthAccessToken or "")
local expected_token = ngx.encode_base64(ngx.hmac_sha1(token_secret, cb_server_name .. oauth_email .. oauth_expires))

if oauth_access_token == expected_token and oauth_expires and oauth_expires > ngx.time() then
  -- Populate the nginx 'ngo_user' variable with our Oauth username, if requested
  if set_user then
    local oauth_user, oauth_domain = oauth_email:match("([^@]+)@(.+)")
    if email_as_user then
      ngx.var.ngo_user = email
    else
      ngx.var.ngo_user = oauth_user
    end
  end
  return
else
  -- If no access token and this isn't the callback URI, redirect to oauth
  if uri ~= cb_uri then
    -- Redirect to the /oauth endpoint, request access to ALL scopes
    return ngx.redirect("https://accounts.google.com/o/oauth2/auth?client_id="..client_id.."&scope=email&response_type=code&redirect_uri="..ngx.escape_uri(cb_url).."&state="..ngx.escape_uri(redir_url).."&login_hint="..ngx.escape_uri(domain))
  end

  -- Fetch teh authorization code from the parameters
  local auth_code = uri_args["code"]
  local auth_error = uri_args["error"]

  if auth_error then
    ngx.log(ngx.ERR, "received "..auth_error.." from https://accounts.google.com/o/oauth2/auth")
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
    
  if debug then
    ngx.log(ngx.ERR, "DEBUG: fetching token for auth code "..auth_code)
  end

  -- TODO: Switch to NBIO sockets
  -- If I get around to working luasec, this says how to pass a function which
  -- can generate a socket, needed for NBIO using nginx cosocket
  -- http://lua-users.org/lists/lua-l/2009-02/msg00251.html
  local res, code, headers, status = https.request(
    "https://accounts.google.com/o/oauth2/token",
    "code="..ngx.escape_uri(auth_code).."&client_id="..client_id.."&client_secret="..client_secret.."&redirect_uri="..ngx.escape_uri(cb_url).."&grant_type=authorization_code"
  )

  if debug then
    ngx.log(ngx.ERR, "DEBUG: token response "..res..code..status)
  end

  if code~=200 then
    ngx.log(ngx.ERR, "received "..code.." from https://accounts.google.com/o/oauth2/token")
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end

  -- use version 1 cookies so we don't have to encode. MSIE-old beware
  local json  = jsonmod.decode( res )
  local access_token = json["access_token"]
  local expires = ngx.time() + json["expires_in"]
  local cookie_tail = ";version=1;path=/;Max-Age="..json["expires_in"]
  if secure_cookies then
    cookie_tail = cookie_tail..";secure"
  end

  local send_headers = {
    Authorization = "Bearer "..access_token,
  }

  local result_table = {} 
  local res2, code2, headers2, status2 = https.request({
    url = "https://www.googleapis.com/oauth2/v2/userinfo",
    method = "GET",
    headers = send_headers,
    sink = ltn12.sink.table(result_table),
  })

  if code2~=200 then
    ngx.log(ngx.ERR, "received "..code2.." from https://www.googleapis.com/oauth2/v2/userinfo")
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end

  if debug then
    ngx.log(ngx.ERR, "DEBUG: userinfo response "..res2..code2..status2..table.concat(result_table))
  end

  json = jsonmod.decode( table.concat(result_table) )

  local name = json["name"]
  local email = json["email"]
  local picture = json["picture"]
  local token = ngx.encode_base64(ngx.hmac_sha1(token_secret, cb_server_name .. email .. expires))

  local oauth_user, oauth_domain = email:match("([^@]+)@(.+)")

  -- If no whitelist or blacklist, match on domain
  if not whitelist and not blacklist and domain then
    if oauth_domain ~= domain then
      if debug then
        ngx.log(ngx.ERR, "DEBUG: "..email.." not in "..domain)
      end
      return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
  end

  if whitelist then
    if not string.find(" " .. whitelist .. " ", " " .. email .. " ") then
      if debug then
        ngx.log(ngx.ERR, "DEBUG: "..email.." not in whitelist")
      end
      return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
  end

  if blacklist then
    if string.find(" " .. blacklist .. " ", " " .. email .. " ") then
      if debug then
        ngx.log(ngx.ERR, "DEBUG: "..email.." in blacklist")
      end
      return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
  end

  ngx.header["Set-Cookie"] = {
    "OauthAccessToken="..ngx.escape_uri(token)..cookie_tail,
    "OauthExpires="..expires..cookie_tail,
    "OauthName="..ngx.escape_uri(name)..cookie_tail,
    "OauthEmail="..ngx.escape_uri(email)..cookie_tail,
    "OauthPicture="..ngx.escape_uri(picture)..cookie_tail
  }

  -- Poplate our ngo_user variable
  if set_user then
    if email_as_user then
      ngx.var.ngo_user = email
    else
      ngx.var.ngo_user = oauth_user
    end
  end

  -- Redirect
  if debug then
    ngx.log(ngx.ERR, "DEBUG: authorized "..json["email"]..", redirecting to "..uri_args["state"])
  end
  return ngx.redirect(uri_args["state"]) 
end
