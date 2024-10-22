#!/bin/bash

echo "*********************************************************************************************" >> /home/student/setup/reboot.log
echo "SYSTEM REBOOTED AT $(date)" >> /home/student/setup/reboot.log
echo "*********************************************************************************************" >> /home/student/setup/reboot.log

# Assigned IPs
IP1=128.8.238.105
IP2=128.8.238.178
IP3=128.8.238.80
IP4=128.8.238.29
IP5=128.8.238.47

# Read honeypot configurations from the file "honeypot_configs"
honeypot_configs=($(cat /home/student/setup/honeypot_configs))

sudo ip addr add 128.8.238.105/24 brd + dev eth3;
sudo ip addr add 128.8.238.178/24 brd + dev eth3;
sudo ip addr add 128.8.238.80/24 brd + dev eth3;
sudo ip addr add 128.8.238.29/24 brd + dev eth3;
sudo ip addr add 128.8.238.47/24 brd + dev eth3;

# Basic firewall rules as per instruction
sudo modprobe br_netfilter
sudo modprobe br_netfilter
sudo /home/student/firewall_rules

# Create 5 active LXC containers using the default LXC template (usually Ubuntu)
for i in {1..5}; do
    sudo lxc-create -n container$i -t download -- --dist ubuntu --release focal --arch amd64;
    sleep 5;
    sudo lxc-start -n container$i;
    sleep 5;
    sudo systemctl restart lxc-net; # DO WE NEED THIS
    sleep 5;
    sudo apt update -y && sudo apt upgrade -y;
    sleep 5;
    sudo lxc-attach -n container$i -- sudo apt install openssh-server -y;
    sleep 5;
    echo "Created container$i with Ubuntu" >> /home/student/setup/reboot.log
done

# Assign honeypot configurations to remaining containers (6-12) and name them according to the config
for i in {6..12}; do
    # Assign the next honeypot configuration from the list
    HP_CONFIG=${honeypot_configs[$((i-6))]}

    # Create the container with a name matching the honeypot config
    sudo lxc-create -n $HP_CONFIG -t download -- --dist ubuntu --release focal --arch amd64;
    sleep 5;
    sudo lxc-start -n $HP_CONFIG;
    sleep 5;
    sudo systemctl restart lxc-net; # DO WE NEED THIS
    sleep 5;
    sudo apt update -y && sudo apt upgrade -y;
    sleep 5;
    sudo lxc-attach -n $HP_CONFIG -- apt install openssh-server -y;
    sleep 5;
    /home/student/setup/setup_"$HP_CONFIG" $HP_CONFIG;
    sleep 5;
    sudo lxc-stop -n $HP_CONFIG;
    sleep 5;
    echo "Created container $HP_CONFIG with Ubuntu" >> /home/student/setup/reboot.log

    echo "Configured container "$HP_CONFIG"" >> /home/student/setup/reboot.log
done

# Grabbing container IPs for NAT table rules
CONTAINER1_IP=$(sudo lxc-info -n container1 -iH);
CONTAINER2_IP=$(sudo lxc-info -n container2 -iH);
CONTAINER3_IP=$(sudo lxc-info -n container3 -iH);
CONTAINER4_IP=$(sudo lxc-info -n container4 -iH);
CONTAINER5_IP=$(sudo lxc-info -n container5 -iH);

# Assign random honeypot configurations to first 5 honeypots
for i in {1..5}; do
    # Randomly select a honeypot configuration
    HP_CONFIG=$(shuf -n 1 /home/student/setup/honeypot_configs)
    echo "config:"$HP_CONFIG"" > /home/student/recycle_util_container$i
    echo "Selected honeypot config: $HP_CONFIG for container$i" >> /home/student/setup/reboot.log
    # Run the selected honeypot configuration script
    /home/student/setup/setup_"$HP_CONFIG" container$i;
    sleep 5;
    echo "Configured container$i with $HP_CONFIG" >> /home/student/setup/reboot.log
done

sudo sysctl -w net.ipv4.conf.all.route_localnet=1

sleep 10

# SETTING NAT RULES
HP_CONFIG=$(grep "config" /home/student/recycle_util_container1 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n container1 -i "$CONTAINER1_IP" -p 32887 --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 2 --debug;

sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP1" --jump DNAT --to-destination "$CONTAINER1_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER1_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP1"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP1" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1:32887 # is this right?
echo "NAT rules set for container1" >> /home/student/setup/reboot.log

sleep 10

HP_CONFIG=$(grep "config" /home/student/recycle_util_container2 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n container2 -i "$CONTAINER2_IP" -p 32888 --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 2 --debug
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP2" --jump DNAT --to-destination "$CONTAINER2_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER2_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP2"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP2" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1:32888 # is this right?
echo "NAT rules set for container2" >> /home/student/setup/reboot.log

sleep 10

HP_CONFIG=$(grep "config" /home/student/recycle_util_container3 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n container3 -i "$CONTAINER3_IP" -p 32889 --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 2 --debug
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP3" --jump DNAT --to-destination "$CONTAINER3_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER3_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP3"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP3" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1:32889 # is this right?
echo "NAT rules set for container3" >> /home/student/setup/reboot.log

sleep 10

HP_CONFIG=$(grep "config" /home/student/recycle_util_container4 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n container4 -i "$CONTAINER4_IP" -p 33424 --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 2 --debug
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP4" --jump DNAT --to-destination "$CONTAINER4_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER4_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP4"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP4" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1:33424 # is this right?
echo "NAT rules set for container4" >> /home/student/setup/reboot.log

sleep 10

HP_CONFIG=$(grep "config" /home/student/recycle_util_container5 | cut -d':' -f2)
sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/$(date -Iseconds) -a start /home/student/MITM/mitm.js -n container5 -i "$CONTAINER5_IP" -p 35234 --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 2 --debug
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP5" --jump DNAT --to-destination "$CONTAINER5_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER5_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$IP5"
# set-up NAT rules for MITM
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$IP5" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1:35234 # is this right?
echo "NAT rules set for container5" >> /home/student/setup/reboot.log

echo "Containers 1 to 5 started with random honeypot configurations and IP table rules." >> /home/student/setup/reboot.log
echo "Containers 6 to 12 are created and named after specific honeypot configurations but remain inactive." >> /home/student/setup/reboot.log
