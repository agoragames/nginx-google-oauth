 
-- import requirements

-- allow either ccjsonjson, or th-LuaJSON
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
 
-- setup some app-level vars
local client_id = ngx.var.ngo_client_id
local client_secret = ngx.var.ngo_client_secret
local domain = ngx.var.ngo_domain
local cb_scheme = ngx.var.ngo_callback_scheme or ngx.var.scheme
local cb_server_name = ngx.var.ngo_callback_host or ngx.var.server_name
local cb_uri = ngx.var.ngo_callback_uri or "/_oauth"
local cb_url = cb_scheme.."://"..cb_server_name..cb_uri
local signout_uri = ngx.var.ngo_signout_uri or "/_signout"
local debug = ngx.var.ngo_debug
local whitelist = ngx.var.ngo_whitelist
local blacklist = ngx.var.ngo_blacklist
local secure_cookies = ngx.var.ngo_secure_cookies

local uri_args = ngx.req.get_uri_args()

-- See https://developers.google.com/accounts/docs/OAuth2WebServer 
if ngx.var.uri == signout_uri then
  ngx.header["Set-Cookie"] = "AccessToken=deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT"
  return ngx.redirect(ngx.var.scheme.."://"..ngx.var.server_name)
end

if not ngx.var.cookie_AccessToken then
  -- If no access token and this isn't the callback URI, redirect to oauth
  if ngx.var.uri ~= cb_uri then
    -- Redirect to the /oauth endpoint, request access to ALL scopes
    return ngx.redirect("https://accounts.google.com/o/oauth2/auth?client_id="..client_id.."&scope=email&response_type=code&redirect_uri="..ngx.escape_uri(cb_url).."&state="..ngx.escape_uri(ngx.var.uri).."&login_hint="..ngx.escape_uri(domain))
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

  -- If no whitelist or blacklist, match on domain
  if not whitelist and not blacklist and domain then
    if not string.find(email, "@"..domain) then
      if debug then
        ngx.log(ngx.ERR, "DEBUG: "..email.." not in "..domain)
      end
      return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
  end

  if whitelist then
    if not string.find(whitelist, email) then
      if debug then
        ngx.log(ngx.ERR, "DEBUG: "..email.." not in whitelist")
      end
      return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
  end

  if blacklist then
    if string.find(blacklist, email) then
      if debug then
        ngx.log(ngx.ERR, "DEBUG: "..email.." in blacklist")
      end
      return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
  end

  ngx.header["Set-Cookie"] = {
    "AccessToken="..access_token..cookie_tail,
    "Name="..ngx.escape_uri(name)..cookie_tail,
    "Email="..ngx.escape_uri(email)..cookie_tail,
    "Picture="..ngx.escape_uri(picture)..cookie_tail
  }

  -- Redirect
  if debug then
    ngx.log(ngx.ERR, "DEBUG: authorized "..json["email"]..", redirecting to "..uri_args["state"])
  end
  return ngx.redirect(uri_args["state"]) 
end
