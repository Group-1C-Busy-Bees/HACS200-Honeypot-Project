#!/bin/bash

echo "*********************************************************************************************" > /home/student/setup/reboot.log
echo "SYSTEM REBOOTED AT $(date)" >> /home/student/setup/reboot.log
echo "*********************************************************************************************" >> /home/student/setup/reboot.log


# STOP ALL FOREVER PROCESSES
sudo forever stopall;
echo "[$(date +'%Y-%m-%d %H:%M:%S')] all forever processes stopped" >> /home/student/setup/reboot.log

# DELETE ALL CONTAINERS
sudo /home/student/setup/destroy_containers;
echo "[$(date +'%Y-%m-%d %H:%M:%S')] destroyed all containers" >> /home/student/setup/reboot.log

# Assigned IPs
IP1= # REDACTED
IP2= # REDACTED
IP3= # REDACTED
IP4= # REDACTED
IP5= # REDACTED

# Read honeypot configurations from the file "honeypot_configs"
honeypot_configs=($(cat /home/student/setup/honeypot_configs))

sudo ip addr add $IP1/24 brd + dev eth3;
sudo ip addr add $IP2/24 brd + dev eth3;
sudo ip addr add $IP3/24 brd + dev eth3;
sudo ip addr add $IP4/24 brd + dev eth3;
sudo ip addr add $IP5/24 brd + dev eth3;

# Basic firewall rules as per instruction
sudo modprobe br_netfilter
sudo modprobe br_netfilter
sudo bash /home/student/firewall_rules

# Create 5 active LXC containers using the default LXC template (usually Ubuntu)
for i in {1..5}; do
    sudo lxc-create -n system$i -t download -- --dist ubuntu --release focal --arch amd64;
    sleep 15;
    sudo lxc-start -n system$i;
    sleep 5;
    sudo systemctl restart lxc-net; # DO WE NEED THIS
    sleep 5;
    sudo lxc-attach -n system$i -- sudo apt update -y;
    sudo lxc-attach -n system$i -- sudo apt-get install ssh -y;
    sleep 15;
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Created system$i with Ubuntu" >> /home/student/setup/reboot.log
done

# Assign honeypot configurations to remaining containers (6-12) and name them according to the config
for i in {6..12}; do
    # Assign the next honeypot configuration from the list
    HP_CONFIG=${honeypot_configs[$((i-6))]}

    # Create the container with a name matching the honeypot config
    sudo lxc-create -n $HP_CONFIG -t download -- --dist ubuntu --release focal --arch amd64;
    sleep 15;
    sudo lxc-start -n $HP_CONFIG;
    sleep 5;
    sudo systemctl restart lxc-net; # DO WE NEED THIS
    sleep 5;
    sudo lxc-attach -n $HP_CONFIG -- sudo apt update -y;
    sudo lxc-attach -n $HP_CONFIG -- sudo apt-get install ssh -y;
    sleep 15;
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Created container $HP_CONFIG with Ubuntu" >> /home/student/setup/reboot.log
    /home/student/setup/setup_"$HP_CONFIG" $HP_CONFIG;
    sleep 5;
    sudo lxc-stop -n $HP_CONFIG;
    sleep 5;

    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Configured container "$HP_CONFIG"" >> /home/student/setup/reboot.log
done

# Grabbing container IPs for NAT table rules
CONTAINER1_IP=$(sudo lxc-info -n system1 -iH);
CONTAINER2_IP=$(sudo lxc-info -n system2 -iH);
CONTAINER3_IP=$(sudo lxc-info -n system3 -iH);
CONTAINER4_IP=$(sudo lxc-info -n system4 -iH);
CONTAINER5_IP=$(sudo lxc-info -n system5 -iH);

# Assign random honeypot configurations to first 5 honeypots
for i in {1..5}; do
    # Randomly select a honeypot configuration
    HP_CONFIG=$(shuf -n 1 /home/student/setup/honeypot_configs)
    echo "config:"$HP_CONFIG"" > /home/student/recycle_util_system$i
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Selected honeypot config: $HP_CONFIG for system$i" >> /home/student/setup/reboot.log
    # Run the selected honeypot configuration script
    /home/student/setup/setup_"$HP_CONFIG" system$i;
    sleep 5;
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Configured system$i with $HP_CONFIG" >> /home/student/setup/reboot.log
done

sudo sysctl -w net.ipv4.conf.all.route_localnet=1

sleep 5;

# CONTAINER 1 SET UP
HP_CONFIG=$(grep "config" /home/student/recycle_util_system1 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n system1 -i "$CONTAINER1_IP" -p REDACTED --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 1 --debug;
# nat rules for container
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP1" --jump DNAT --to-destination "$CONTAINER1_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER1_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP1"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP1" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1: # REDACTED
echo "[$(date +'%Y-%m-%d %H:%M:%S')] NAT rules set for system1" >> /home/student/setup/reboot.log


# CONTAINER 2 SET UP
HP_CONFIG=$(grep "config" /home/student/recycle_util_system2 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n system2 -i "$CONTAINER2_IP" -p REDACTED --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 1 --debug
# nat rules for container
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP2" --jump DNAT --to-destination "$CONTAINER2_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER2_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP2"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP2" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1: # REDACTED
echo "[$(date +'%Y-%m-%d %H:%M:%S')] NAT rules set for system2" >> /home/student/setup/reboot.log


# CONTAINER 3 SET UP
HP_CONFIG=$(grep "config" /home/student/recycle_util_system3 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n system3 -i "$CONTAINER3_IP" -p REDACTED --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 1 --debug
# nat rules for container
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP3" --jump DNAT --to-destination "$CONTAINER3_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER3_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP3"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP3" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1: # REDACTED
echo "[$(date +'%Y-%m-%d %H:%M:%S')] NAT rules set for system3" >> /home/student/setup/reboot.log


# CONTAINER 4 SET UP
HP_CONFIG=$(grep "config" /home/student/recycle_util_system4 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n system4 -i "$CONTAINER4_IP" -p REDACTED --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 1 --debug
# nat rules for container
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP4" --jump DNAT --to-destination "$CONTAINER4_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER4_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP4"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP4" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1: # REDACTED
echo "[$(date +'%Y-%m-%d %H:%M:%S')] NAT rules set for system4" >> /home/student/setup/reboot.log


#CONTAINER 5 SET UP
HP_CONFIG=$(grep "config" /home/student/recycle_util_system5 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n system5 -i "$CONTAINER5_IP" -p REDACTED --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 1 --debug
# nat rules for container
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP5" --jump DNAT --to-destination "$CONTAINER5_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER5_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP5"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP5" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1: # REDACTED
echo "[$(date +'%Y-%m-%d %H:%M:%S')] NAT rules set for system5" >> /home/student/setup/reboot.log



echo "[$(date +'%Y-%m-%d %H:%M:%S')] Containers 1 to 5 started with random honeypot configurations and IP table rules." >> /home/student/setup/reboot.log
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Containers 6 to 12 are created and named after specific honeypot configurations but remain inactive." >> /home/student/setup/reboot.log
