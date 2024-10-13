#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_big_med.sh (3)" >> scripts.log
	exit 3
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Patients General Legal | cd Patients | mkdir Data | cd ../General | mkdir Historical | cd ../Public | mkdir Information Documents"

sudo lxc file push big_patient_files.csv "$container_name"/root/Patients/Data/patient_files.csv

sudo lxc file push big_hospital_hist.xls "$container_name"/root/General/Historical/hospital_hist.xls

sudo lxc file push big_insurance.csv "$container_name"/root/Legal/Information/insurance.csv

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_big_med.sh completed (0)" >> scripts.log
exit 0
