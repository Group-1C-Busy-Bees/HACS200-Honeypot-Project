#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_little_fin.sh (6)" >> scripts.log
	exit 6
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Customer_Service Services Activity | cd Customer_Service | mkdir Resources | cd ../Services | mkdir Credit_Card Retirement | cd ../Activity | mkdir Transfers"

sudo lxc file push little_bankacc_customer.csv "$container_name"/root/Customer_Service/bankacc_customer.csv

sudo lxc file push little_creditcard_info.csv "$container_name"/root/Services/Credit_Card/creditcard_info.csv 

sudo lxc file push little_moneytransfer_hist.xls "$container_name"/root/Activity/Transfers/moneytransfer_hist.xls

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_little_fin.sh completed (0)" >> scripts.log
exit 0
