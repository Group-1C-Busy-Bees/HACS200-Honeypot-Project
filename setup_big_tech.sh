#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
 	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITCAL ERROR: incorrect params in $(pwd)/setup_big_tech.sh (4)" >> scripts.log
	exit 4
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Hardware Website Customer_Services | cd Hardware | mkdir Home_Devices | cd ../Website | mkdir Resources | cd ../Customer_Services | mkdir Guides Assistance"

sudo lxc file push big_device_data.csv "$container_name"/root/Hardware/device_data.csv

sudo lxc file push big_userprefs.xls "$container_name"/root/Website/Resources/userprefs.xls
sudo lxc file push big_login_customer.csv "$container_name"/root/Customer_Services/Assistance/login_customer.csv

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_big_tech.sh completed (0)" >> scripts.log
exit 0
