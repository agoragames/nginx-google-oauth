
-- Will filter the output and put in a header implying login
if ngx.var.cookie_AccessToken then
  local img = "<img src=\""..ngx.unescape_uri(ngx.var.cookie_Picture).."\" />"
  local user = "<span class=\"ngo_user\">"..ngx.unescape_uri(ngx.var.cookie_Name).."</span>"
  local email = "<span class=\"ngo_email\">"..ngx.unescape_uri(ngx.var.cookie_Email).."</span>"
  local div = "<div class=\"ngo_auth\">"..img..user..email.."</div>"

  if ngx.var.ngo_css then
    local css = [[
      <style>
        div.ngo_auth { width: 100%; background-color: #6199DF; color: white; padding: 0.5em 0em 0.5em 2em; vertical-align: middle; margin: 0; }
        div.ngo_auth > img { width: auto; height: 2em; margin: 0 1em 0 0; padding: 0; }
        div.ngo_auth > span.ngo_user { font-weight: bold; margin-right: 1em; }
      </style>
    ]]
    div = css..div
  end

  ngx.arg[1] = ngx.re.sub(ngx.arg[1], "<body>", "<body>"..div)
end
