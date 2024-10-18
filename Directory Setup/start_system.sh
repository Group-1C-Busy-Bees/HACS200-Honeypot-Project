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

# Read honeypot configurations from the file "honeypot_configs"
honeypot_configs=($(cat /home/student/test/honeypot_configs))

# Create 4 active LXC containers using the default LXC template (usually Ubuntu)
for i in {1..4}; do
    lxc-create -n container$i -t download -- --dist ubuntu --release focal --arch amd64
    echo "Created container$i with Ubuntu"
done

# Assign honeypot configurations to remaining containers (5-11) and name them according to the config
for i in {5..11}; do
    # Assign the next honeypot configuration from the list
    HP_CONFIG=${honeypot_configs[$((i-5))]}
    
    # Create the container with a name matching the honeypot config
    lxc-create -n $HP_CONFIG -t download -- --dist ubuntu --release focal --arch amd64
    echo "Created container $HP_CONFIG with Ubuntu"

    # (Optional) You could add pre-configuration steps here if needed, but containers remain inactive
done

#!/bin/bash

# Check if 4 IP addresses are provided as arguments
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <IP1> <IP2> <IP3> <IP4>"
    exit 1
fi

# Start the first 4 containers and assign random honeypot configurations with IPs
for i in {1..4}; do
    # Randomly select a honeypot configuration
    HP_CONFIG=$(shuf -n 1 /home/student/test/honeypot_configs)
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
    /home/student/test/setup_"$HP_CONFIG" container$i
    echo "Configured container$i with $HP_CONFIG"
done

echo "Containers 1 to 4 started with random honeypot configurations and IP table rules."
echo "Containers 5 to 11 are created and named after specific honeypot configurations but remain inactive."

