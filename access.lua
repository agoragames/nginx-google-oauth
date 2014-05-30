ngx.log(ngx.ERR, "DEBUG URL "..ngx.var.uri)
 
-- import requirements
local cjson = require "cjson"

-- Ubuntu broke the install. Puts the source in /usr/share/lua/5.1/https.lua,
-- but since the source defines itself as the module "ssl.https", after we
-- load the source, we need to grab the actual thing. Building from source
-- wasn't practical.
-- TODO: make this more generic but still work with Ubuntu
require "https" -- 
local https = require "ssl.https" -- /usr/share/lua/5.1/https.lua
local ltn12  = require("ltn12")
 
-- setup some app-level vars
local app_id = ngx.var.ngo_app_id
local app_secret = ngx.var.ngo_app_secret
local code_callback = ngx.var.scheme.."://"..ngx.var.server_name.."/_code"
local args = ngx.req.get_uri_args()

 
local access_token = ngx.var.cookie_AccessToken
if access_token then
    ngx.header["Set-Cookie"] = "AccessToken="..access_token.."; path=/;Max-Age=3000"
end

if ngx.var.uri=='/_code' then
  -- If I get around to working luasec, this says how to pass a function which
  -- can generate a socket, needed for NBIO using nginx cosocket
  -- http://lua-users.org/lists/lua-l/2009-02/msg00251.html

  -- TODO handle when there's an "error" parameter and no code
  local code = args["code"]
  ngx.log(ngx.ERR, "DEBUG: CHECKING ACCESS CODE "..code..ngx.var.request_method)

  local res, code, headers, status = https.request(
    "https://accounts.google.com/o/oauth2/token",
    "code="..ngx.escape_uri(code).."&client_id="..app_id.."&client_secret="..app_secret.."&redirect_uri="..ngx.escape_uri(code_callback).."&grant_type=authorization_code"
  )

  ngx.log(ngx.ERR, "DEBUG: token response"..res..code..status..type(code))

  -- TODO handle non-200
  if code==200 then
    local json  = cjson.decode( res )
    local expires = json["expires_in"]
    ngx.header["Set-Cookie"] = "AccessToken="..json["access_token"].."; path=/;Max-Age="..json["expires_in"]
    local send_headers = {
      Authorization = "Bearer "..json["access_token"],
    }
 
    local result_table = {} 
    local res2, code2, headers2, status2 = https.request({
      url = "https://www.googleapis.com/oauth2/v2/userinfo",
      method = "GET",
      headers = send_headers,
      sink = ltn12.sink.table(result_table),
    })

    -- TODO handle non-200
    json = cjson.decode( table.concat(result_table) )
    if json["hd"]~="agoragames.com" then
      return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    ngx.log(ngx.ERR, "DEBUG: profile response"..res2..code2..status2..table.concat(result_table))
    -- TODO: preserve the max-age from above
    -- TODO: needs to be escaped I think, might be why they're not showing up or are overwriting access token cookie
    --ngx.header["Set-Cookie"] = "Name="..json["name"].."; path=/"
    --ngx.header["Set-Cookie"] = "Email="..json["email"].."; path=/"
    --ngx.header["Set-Cookie"] = "Picture="..json["picture"].."; path=/"
  end

  --return ngx.exit(ngx.HTTP_OK)
  -- TODO: only if we get a valid token!
  return ngx.redirect(args["state"]) 
end
 
-- first lets check for a code where we retrieve
if not access_token or args.code then
    -- Redirect to the /oauth endpoint, request access to ALL scopes
    return ngx.redirect("https://accounts.google.com/o/oauth2/auth?client_id="..app_id.."&scope=email&response_type=code&redirect_uri="..ngx.escape_uri(code_callback).."&state="..ngx.escape_uri(ngx.var.uri).."&login_hint="..ngx.escape_uri("agoragames.com"))
end
