#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
 	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_big_fin.sh (2)" >> scripts.log
	exit 2
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Customer_Service Services Activity | cd Customer_Service | mkdir Resources | cd ../Services | mkdir Credit_Card Retirement | cd ../Activity | mkdir Transfers"

sudo lxc file push big_bankacc_customer.csv "$container_name"/root/Customer_Service/bankacc_customer.csv

sudo lxc file push big_creditcard_info.csv "$container_name"/root/Services/Credit_Card/creditcard_info.csv 

sudo lxc file push big_moneytransfer_hist.xls "$container_name"/root/Activity/Transfers/moneytransfer_hist.xls

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_big_fin.sh (0) complete" >> scripts.log
exit 0
