#!/bin/bash

# Check if 4 IP addresses are provided as arguments
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <IP1> <IP2> <IP3> <IP4>"
    exit 1
fi

# Get IP addresses from arguments
IP1=$1
IP2=$2
IP3=$3
IP4=$4

# Create 8 LXC containers using the default LXC template (usually Ubuntu)
for i in {1..8}; do
    lxc-create -n container$i -t download -- --dist ubuntu --release focal --arch amd64
    echo "Created container$i with Ubuntu"
done

# Start the first 4 containers and assign random honeypot configurations with IPs
for i in {1..4}; do
    # Randomly select a honeypot configuration
    HP_CONFIG=$(shuf -n 1 ./honeypot_configs)
    echo "Selected honeypot config: $HP_CONFIG for container$i"

    # Start the container
    lxc-start -n container$i
    echo "Started container$i"

    # Wait for the container to obtain an IP address
    sleep 3  # Add a delay to give the container time to initialize networking

    # Get the container's internal IP
    CONTAINER_IP=$(lxc-info -n container$i -iH)

    # Add iptables rule to map external IPs to container IPs
    EXTERNAL_IP_VAR="IP$i"
    EXTERNAL_IP="${!EXTERNAL_IP_VAR}"
    
    iptables -t nat -A PREROUTING -d $EXTERNAL_IP -j DNAT --to-destination $CONTAINER_IP
    iptables -t nat -A POSTROUTING -s $CONTAINER_IP -j SNAT --to-source $EXTERNAL_IP

    echo "Assigned external IP $EXTERNAL_IP to container$i ($CONTAINER_IP)"

    # Run the selected honeypot configuration script
    ./setup_"$HP_CONFIG"
    echo "Configured container$i with $HP_CONFIG"
done

echo "Containers 1 to 4 started with random honeypot configurations and IP table rules. Containers 5 to 8 are created and waiting to be deployed."

