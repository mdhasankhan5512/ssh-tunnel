#!/bin/bash

CONFIG_FILE="/etc/config/custom_ssh_tunnel"

# Loop through all server_* sections
for section in $(uci show custom_ssh_tunnel | grep "=server" | cut -d'.' -f2 | cut -d'=' -f1); do
    # Get the first server from the list
    FIRST_SERVER=$(uci get custom_ssh_tunnel.$section.servers 2>/dev/null | head -n1)

    if [ -z "$FIRST_SERVER" ]; then
        echo "Skipping $section, no servers defined."
        continue
    fi

    # Extract host, port, username, and password
    HOST=$(echo "$FIRST_SERVER" | awk -F'[:@]' '{print $1}')
    PORT=$(echo "$FIRST_SERVER" | awk -F'[:@]' '{print $2}')
    USERNAME=$(echo "$FIRST_SERVER" | awk -F'[:@]' '{print $3}')
    PASSWORD=$(echo "$FIRST_SERVER" | awk -F'[:@]' '{print $4}')
    SNI=$(uci get custom_ssh_tunnel.$section.sni 2>/dev/null)
    LOCAL_PORT=$(uci get custom_ssh_tunnel.$section.local_port 2>/dev/null)

    # Debugging output
    echo "Configuring $section..."
    echo "  Host: $HOST"
    echo "  Port: $PORT"
    echo "  Username: $USERNAME"
    echo "  Password: ********"
    echo "  SNI: $SNI"
    echo "  Local Port: $LOCAL_PORT"

    # Create temporary script
    TEMP_SCRIPT="/tmp/ssh_tunnel_${section}.sh"
    cat <<EOF > $TEMP_SCRIPT
#!/bin/bash
sshpass -p '${PASSWORD}' ssh -o 'ProxyCommand=openssl s_client -connect ${HOST}:${PORT} -servername ${SNI} -quiet' -o ServerAliveInterval=30 -o StrictHostKeyChecking=no -N -D ${LOCAL_PORT} ${USERNAME}@${HOST}
EOF

    # Make script executable
    chmod +x $TEMP_SCRIPT

    # Start tmux session for this server
    tmux new-session -d -s "$section"
    sleep 2
    tmux send-keys -t "$section" "$TEMP_SCRIPT" C-m

    echo "Started SSH tunnel in tmux session: $section"
done

