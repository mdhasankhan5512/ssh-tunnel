module("luci.controller.custom_ssh_tunnel", package.seeall)

function index()
    entry({"admin", "services", "custom_ssh_tunnel"}, cbi("custom_ssh_tunnel"), _("Custom SSH Tunnel"), 80).dependent = true
end
