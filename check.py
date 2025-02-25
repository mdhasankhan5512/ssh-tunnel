import os
import re
import time
import subprocess
from datetime import datetime

CONFIG_FILE = "/etc/config/custom_ssh_tunnel"
LOG_FILE = "/root/tunnel.log"

def log_message(message):
    """Logs messages to a file, recreating the log file every day."""
    today_str = datetime.now().strftime("%Y-%m-%d")
    if not os.path.exists(LOG_FILE) or time.localtime(os.stat(LOG_FILE).st_mtime).tm_mday != time.localtime().tm_mday:
        open(LOG_FILE, "w").close()  # Clear log file daily

    with open(LOG_FILE, "a") as log:
        log.write(f"{datetime.now()} - {message}\n")


def read_config():
    """Reads the configuration file and extracts relevant settings."""
    config = {"servers": [], "tunnel": {}}

    with open(CONFIG_FILE, "r") as file:
        lines = file.readlines()

    server_data = {}
    for line in lines:
        line = line.strip()
        if line.startswith("config server"):
            if server_data:
                config["servers"].append(server_data)
            server_name = line.split("'")[1]  # Extract server name (e.g., 'server_1')
            server_data = {"name": server_name, "servers": []}
        elif line.startswith("config tunnel"):
            # Handle the tunnel section
            tunnel_name = line.split("'")[1]
            config["tunnel"]["name"] = tunnel_name
        elif line.startswith("option sni"):
            server_data["sni"] = line.split("'")[1]
        elif line.startswith("option local_port"):
            server_data["local_port"] = line.split("'")[1]
        elif line.startswith("list servers"):
            server_data["servers"].append(line.split("'")[1])
        elif line.startswith("option _status"):
            config["tunnel"]["_status"] = line.split("'")[1]

    if server_data:  # Append the last server configuration
        config["servers"].append(server_data)

    return config


def parse_server(server):
    """Parses a server entry and returns its details."""
    match = re.match(r"(.+?):(.+?)@(.+?):(.+?):(\d{2}-\d{2}-\d{4})", server)
    if match:
        return {
            "host": match.group(1),
            "port": match.group(2),
            "username": match.group(3),
            "password": match.group(4),
            "expiry": datetime.strptime(match.group(5), "%d-%m-%Y")
        }
    return None


def remove_expired_servers(config):
    """Removes expired servers from the configuration."""
    today = datetime.today()
    for server_data in config["servers"]:
        new_servers = []
        for server in server_data["servers"]:
            parsed = parse_server(server)
            if parsed and parsed["expiry"] >= today:
                new_servers.append(server)
            else:
                log_message(f"Removing expired server: {server}")
        server_data["servers"] = new_servers

    write_config(config)


def write_config(config):
    """Writes the updated configuration back to the file."""
    with open(CONFIG_FILE, "w") as file:
        # Write server sections
        for server_data in config["servers"]:
            file.write(f"config server '{server_data['name']}'\n")
            file.write(f"    option sni '{server_data['sni']}'\n")
            file.write(f"    option local_port '{server_data['local_port']}'\n")
            for server in server_data["servers"]:
                file.write(f"    list servers '{server}'\n")

        # Write tunnel section
        if "tunnel" in config and "name" in config["tunnel"]:
            file.write(f"config tunnel '{config['tunnel']['name']}'\n")
            if "_status" in config["tunnel"]:
                file.write(f"    option _status '{config['tunnel']['_status']}'\n")


def check_server_port(port):
    """Check if a given port is listening."""
    result = subprocess.run(
        ["netstat", "-tulnp"], capture_output=True, text=True
    )
    return f":{port} " in result.stdout


def send_tmux_command(server_index):
    """Sends tmux command to start the server script."""
    tmux_command = f"/tmp/ssh_tunnel_server_{server_index}.sh"
    log_message(f"Starting server script: {tmux_command}")
    os.system(f"tmux send-keys -t 'server_{server_index}' '{tmux_command}' C-m")


def switch_server(config):
    """Switches to the next available server or loops back to the first server if none work."""
    if config["servers"]:
        for i, server_data in enumerate(config["servers"]):
            port = int(server_data["local_port"])
            if not check_server_port(port):
                log_message(f"Server on port {port} is not running. Restarting...")
                send_tmux_command(i + 1)  # i + 1 because server names are 1-based
    else:
        log_message("No available servers.")


def main():
    while True:
        config = read_config()
        remove_expired_servers(config)
        switch_server(config)
        time.sleep(300)  # Ensures the check is done every 30 seconds


if __name__ == "__main__":
    main()
