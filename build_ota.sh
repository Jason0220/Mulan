#!/bin/bash

if (( $# < 4 )) ; then
	echo "params error"
	echo "Usage: $0 NXP_DIR BES_DIR NXP_VER BES_VER"
	echo "NXP_DIR: The parent dir of repository "Mulan-NXP595""
	
	echo "NXP_VER: The NXP595 firmware version to be included in the OTA package"
	
	logger "params error"
	logger "NXP_DIR: The parent dir of repository "Mulan-NXP595""
	logger "BES_DIR: The parent dir of repository "Mulan-BES2500L""
	logger "NXP_VER: The NXP595 firmware version to be included in the OTA package"
	logger "BES_VER: The BES2500 firmware version to be included in the OTA package"
	exit 1
fi

NXP_DIR=$1
if [ ! -d $NXP_DIR ];then
	echo "Directory $NXP_DIR does not exist"
	logger "Directory $NXP_DIR does not exist"
	exit 1
fi
BES_DIR=$2
if [ ! -d $BES_DIR ];then
	echo "Directory $BES_DIR does not exist"
	logger "Directory $BES_DIR does not exist"
	exit 1
fi
TIME_NOW=`date +%Y%m%d%H%M`
NXP_VER=$3
BES_VER=$4

cd $NXP_DIR
NXP_DIR=$(pwd)
LOG_FILE="$NXP_DIR/Mulan-OTA_$TIME_NOW.log"
echo "Mulan OTA generation (both NXP595FW & BES2500FW) start at $TIME_NOW" | tee $LOG_FILE
echo "NXP_DIR: $NXP_DIR" | tee -a $LOG_FILE
echo "BES_DIR: $BES_DIR" | tee -a $LOG_FILE
echo "NXP_VER: $NXP_VER" | tee -a $LOG_FILE
echo "BES_VER: $BES_VER" | tee -a $LOG_FILE

OTA_PATH="$NXP_DIR/Mulan-NXP595/framework/ota/tools"
echo "OTA_PATH: $OTA_PATH" | tee -a $LOG_FILE
OTA_FILE="$OTA_PATH/upgrade_firmwares.json"
echo "OTA_FILE: $OTA_PATH/upgrade_firmwares.json" | tee -a $LOG_FILE

function prepare_ota() {
	# copy the necessary ota files to OTA_PATH
	cd "$OTA_PATH"
	echo -e "\ncd $(pwd)" | tee -a $LOG_FILE
	cp $NXP_DIR/Mulan-NXP595/target/mulan/rtthread.bin . >> $LOG_FILE 2>&1
	echo "Copy NXP595 FW to $OTA_PATH result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	cp $BES_DIR/Mulan-BES2500L/out/best2500p_ibrt/best2500p_ibrt.bin.converted.bin ./bes.bin >> $LOG_FILE 2>&1
	echo "Copy BES2500 OTA file to $OTA_PATH and rename bes.bin result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	
	sed -i '36,55d' "$OTA_FILE" >> $LOG_FILE 2>&1
	echo "Remove the lines 36~55 from $OTA_FILE result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	sed -i '16,25d' "$OTA_FILE" >> $LOG_FILE 2>&1
	echo "Remove the lines 16~25 from $OTA_FILE result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	sed -i '12s/V4\.0/'"$NXP_VER"'/' "$OTA_FILE" >> $LOG_FILE 2>&1
	echo "Replace NXP new_firmware_version with $NXP_VER result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	sed -i '22s/V4\.0/'"$BES_VER"'/' "$OTA_FILE" >> $LOG_FILE 2>&1
	echo "Replace BES new_firmware_version with $BES_VER result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	
	return 0
}

function ota_generation() {
	cd $OTA_PATH
	echo -e "\ncd $(pwd)" | tee -a $LOG_FILE
	echo "Generating OTA upgrade file... result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	python ota_packager.py >> $LOG_FILE 2>&1
	
	# Find the last generated file starts with "upgrade" and get the file name
    file=$(ls -t upgrade* | head -n 1)

    # if the file exists, rename it as "upgrade.bin"
    if [ -n "$file" ]; then
        mv "$file" "upgrade.bin"
        echo "Renamed $file to "upgrade.bin" result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
    else
        echo "OTA generation failed! result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
    fi
	
	return 0
}

prepare_ota
ota_generation

echo -e "\nMulan OTA generation completed at `date +%Y%m%d%H%M`" | tee -a $LOG_FILE

exit 0
