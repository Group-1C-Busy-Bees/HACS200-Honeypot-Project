#!/bin/bash
# Catching incorrect params for recycle command
if [[ $# -ne 2 ]];
then
	echo "Usage: ./recycle <Recycled_IP_Address>"
	exit 1
fi
# Storing ip address of container that we are recycling
old_ip=$1
# Grab the name of the target container
container_ip=$(sudo iptables -t nat -vL | grep 10.0.3.0/24 | cut -d'.' -f4- | cut -d' ' -f2- | sed 's/^ *//')
current_container=$(sudo lxc-ls --fancy | grep $container_ip | cut -d' ' -f1)
if [ ! -f "$honeypot_configs_file" ]
then
    echo "ERROR: File "$honeypot_configs_file" not found."
    exit 2
fi
# Check if honeypot exists
if sudo lxc-ls -1 | grep -q "^${current_container}$"
then
    # container ip variable
    CONTAINER_IP=$(sudo lxc-info -n $CONTAINER_NAME | grep "IP" | cut -d ' ' -f 14-)
    # delete NAT table rules from container
    sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination REDACTED --jump DNAT --to-destination $CONTAINER_IP
    sudo iptables --table nat --delete POSTROUTING --source $CONTAINER_IP --destination 0.0.0.0/0 --jump SNAT --to-source REDACTED
    sudo ip addr delete REDACTED brd + dev eth0
    # Stop and destroy the container if it exists
    sudo lxc-stop -n "$current_container"
    sudo lxc-destroy -n "$current_container"
fi 
# Select new container to be deployed (NOT THE SAME AS NEW CONTAINER BEING CREATED)
# randomly choose a container from a pool of idling containers
# Idling containers are stored in a file called ./honeypot_configs
# Container names (also listed at the bottom of the document) are:
# "little_med", "big_med", "little_fin", "big_fin", “little_tech”, “big_tech”, and “control”
new_container=${shuf -n 1 ./honeypot_configs}
# delete randomly selected container
sed -i '/$new_container/d' ./honeypot_configs
# add recently deleted container to the list
echo $current_container >> ./honeypot_configs
ip_of_honeypot=$1
# Set up NAT rules for to-be deployed container
# attacker -> $old_ip -> container's ip
sudo lxc-start -n $new_container
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 -- destination "$ip_of_honeypot" --jump DNAT --to-destination "$new_container"
sudo iptables --table nat --insert POSTROUTING --source "$new_container" --destination 0.0.0.0/0 --jump SNAT --to-source "$ip_of_honeypot"
sudo ip addr add "$ip_of_honeypot"/16 brd + dev eth0
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination $ip_of_honeypot --protocol tcp --dport 22 --jump DNAT --to-destination "$mitm_ip":"$mitm_port"
# Recreate container that we just deleted
sudo lxc-create -n "$current_container" -t download -- -d ubuntu -r focal -a amd64
sudo lxc-start -n "$current_container"
# Install Snoopy Logger
sudo lxc-attach -n "$current_container" -- sudo apt-get install wget -y
sudo lxc-attach -n "$current_container" -- wget -O install-snoopy.sh https://github.com/a2o/snoopy/raw/install/install/install-snoopy.sh
sudo lxc-attach -n "$current_container" -- chmod 755 install-snoopy.sh
sudo lxc-attach -n "$current_container" -- sudo ./install-snoopy.sh stable
sudo lxc-attach -n "$current_container" -- sudo rm -rf ./install-snoopy.* snoopy-*
# Install MITM
mitm_port=22
mitm_ip= # REDACTED
ip_of_honeypot=$1
sudo lxc-create -n mitm_container -t download -- -d ubuntu -r focal -a amd64
sudo lxc-start -n mitm_container
sudo forever -l /var/lib/lxc/"$current_container"/rootfs/var/log/auth.log -a start /home/student/MITM/mitm.js -n "$current_container" -i $container_ip -p $mitm_port --auto-access --auto-access-fixed 2 --debug
# Set up container with its honeypot configuration
sudo lxc-attach -n "$current_container" -- bash -c "echo ./setup_$hp_config "$current_container""
exit 0
