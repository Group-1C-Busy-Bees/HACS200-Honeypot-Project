#!/bin/bash 

# Catching incorrect params for recycle command
if [[ $# -ne 2 ]];
then
	echo "Usage: ./recycle <Current Container Name> <New Container Name>"
	exit 1
fi

# Assigning current container name to a variable
current_container=$1
# Assigning new container name to a variable
new_container=$2


# Assigning path of file containing a list of honeypot configs to a variable
honeypot_configs_file= # PATH TO HONEYPOT CONFIGS FILE
# Check to see if file is there
if [ ! -f "$honeypot_configs_file" ]
then
    echo "ERROR: File "$honeypot_configs_file" not found."
    exit 2
fi
# Store current honeypot’s default config to be used later
if [[ “$current_container”==“little_med” ]]
then 
    hp_config= “little_med”
elif [[ “$current_container”==“big_med” ]]
then
     hp_config= “big_med”
elif [[ “$current_container”==“little_fin” ]]
then 
    hp_config= “little_fin”
elif [[ “$current_container”==“big_fin” ]]
then 
    hp_config= “big_fin”
elif [[ “$current_container”==“little_tech” ]]
then 
    hp_config= “little_tech”
elif [[ “$current_container”==“big_tech” ]]
then 
    hp_config= “big_tech”
elif [[ “$current_container”==“control” ]]
then 
    hp_config= “control”
else
    echo “INVALID CONTAINER NAME”
    exit 3
fi

# Check if the current container exists 
if sudo lxc-ls -1 | grep -q "^${current_container}$"
then
    # Stop and destroy the container if it exists
    sudo lxc-stop -n "$current_container"
    sudo lxc-destroy -n "$current_container"
else
    # Create and start a new container if it doesn't exist
    sudo lxc-create -n "$new_container" -t download -- -d ubuntu -r focal -a amd64
    sudo lxc-start -n "$new_container"

    # Install snoopy logger
    sudo lxc-attach -n "$new_container" -- sudo apt-get install wget -y
    sudo lxc-attach -n "$new_container" -- wget -O install-snoopy.sh https://github.com/a2o/snoopy/raw/install/install/install-snoopy.sh
    sudo lxc-attach -n "$new_container" -- chmod 755 install-snoopy.sh
    sudo lxc-attach -n "$new_container" -- sudo ./install-snoopy.sh stable
    sudo lxc-attach -n "$new_container" -- sudo rm -rf ./install-snoopy.* snoopy-*

    # TODO: Install MITM
    sudo lxc-create -n mitm_container -t download -- -d ubuntu -r focal -a amd64
    sudo lxc-start -n mitm_container

    # TODO: networking rules
    random_ip=${ip_array[$((RANDOM % 4))]} #this is useless rn 
    container_ip=$(sudo lxc-info -n "$new_container" | grep "IP" | cut -d ' ' -f 14-)

    mitm_port=22
    mitm_ip= # REDACTED
    ip_of_honeypot= # REDACTED

    sudo forever -l /var/lib/lxc/"$new_container"/rootfs/var/log/auth.log -a start /home/student/MITM/mitm.js -n "$new_container" -i $container_ip -p $mitm_port --auto-access --auto-access-fixed 2 --debug
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 -- destination "$ip_of_honeypot" --jump DNAT --to-destination "$container_ip"
    sudo iptables --table nat --insert POSTROUTING --source "$container_ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$ip_of_honeypot"
    sudo ip addr add "$ip_of_honeypot"/16 brd + dev eth0
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination $ip_of_honeypot --protocol tcp --dport 22 --jump DNAT --to-destination "$mitm_ip":"$mitm_port"
   


    # Create directories and add honey
    sudo lxc-attach -n “$new_container” -- bash -c “echo ./setup_$hp_config “$new_container””
    
    exit 0
fi
