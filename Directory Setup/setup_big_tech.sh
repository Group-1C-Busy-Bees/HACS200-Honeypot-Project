#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
 	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITCAL ERROR: incorrect params in $(pwd)/setup_big_tech.sh (4)" >> scripts.log
	exit 4
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Hardware Website Customer_Services; cd Hardware; mkdir Home_Devices; cd ../Website; mkdir Resources; cd ../Customer_Services; mkdir Guides Assistance"

cp big_device_data.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home//Hardware/device_data.csv

cp big_userprefs.xls /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Website/Resources/userprefs.xls

cp big_login_customer.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Customer_Services/Assistance/login_customer.csv

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_big_tech.sh completed (0)" >> scripts.log
exit 0
