local m, s

m = Map("custom_ssh_tunnel", "Custom SSH Tunnel Configuration", "Modify SSH Tunnel settings.")

-- Define servers
local servers = {"server_1", "server_2", "server_3", "server_4", "server_5"}

for i, server in ipairs(servers) do
    s = m:section(NamedSection, server, "server", "Server " .. i .. " Configuration")
    
    -- Removed the current_server option
    
    local sni = s:option(Value, "sni", "SNI (Server Name)")
    sni.default = "cdn.snapchat.com"
    
    local local_port = s:option(Value, "local_port", "Local Proxy Port")
    local_port.default = tostring(1010 + (i * 1010))
    
    local servers_list = s:option(DynamicList, "servers", "Available Servers", "List of available SSH servers")
    servers_list.default = {
        "139.59.235.231:443@racevpn.com-alyan36:H5512552:24-02-2025",
        "sg4.tun1.pro:443@sshstores-shayan34:H5512552:26-02-2025"
    }
end

-- SSH Tunnel Status
status = m:section(NamedSection, "settings", "tunnel", "Tunnel Status")
status_display = status:option(DummyValue, "_status", "SSH Tunnel Status")
status_display.rawhtml = true

function status_display.cfgvalue(self, section)
    local cursor = luci.model.uci.cursor()
    local port = cursor:get("custom_ssh_tunnel", "server_1", "local_port") or "2020"
    local check = io.popen("netstat -tulnp | grep ':" .. port .. "'")
    local result = check:read("*all")
    check:close()
    
    if result and result ~= "" then
        return "<b><span style='color: green;'>Running</span></b>"
    else
        return "<b><span style='color: red;'>Stopped</span></b>"
    end
end

-- Start SSH Tunnel Service Button
start_btn = status:option(Button, "_start", "Start SSH Tunnel")
start_btn.inputtitle = "Start"
start_btn.inputstyle = "apply"
function start_btn.write(self, section)
    os.execute("service zzz start &")
end

-- Stop SSH Tunnel Service Button
stop_btn = status:option(Button, "_stop", "Stop SSH Tunnel")
stop_btn.inputtitle = "Stop"
stop_btn.inputstyle = "reset"
function stop_btn.write(self, section)
    os.execute("service zzz stop &")
end

return m