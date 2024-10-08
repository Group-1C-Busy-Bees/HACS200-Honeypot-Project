#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
	echo "Usage: ./setup_little_tech <Container Name>"
	echo "ERROR: incorrect params in $(pwd)/setup_little_tech.sh (9)" >> scripts.log
	exit 9
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Hardware Website Customer_Services | cd Hardware | mkdir Home_Devices | cd ../Website | mkdir Resources | cd ../Customer_Services | mkdir Guides Assistance"

sudo lxc file push little_device_data.csv "$container_name"/root/Hardware/device_data.csv

sudo lxc file push little_userprefs.xls "$container_name"/root/Website/Resources/userprefs.xls
sudo lxc file push little_login_customer.csv "$container_name"/root/Customer_Services/Assistance/login_customer.csv
echo "SUCCESS: $(pwd)/setup_little_tech.sh (0)" >> scripts.log
exit 0
