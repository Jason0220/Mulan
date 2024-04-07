#!/bin/bash

if (( $# < 5 )) ; then
	echo "params error"
	echo "Usage: $0 BRANCH CODE_DIR NEW_VERSION LAST_VERSION GCC_ARM"
	echo "BRANCH: The branch of repository "Mulan-BES2500" you would like to build"
	echo "CODE_DIR: The parent dir of repository "Mulan-BES2500", which must be existing"
	echo "NEW_VERSION: The expected version number"
	echo "LAST_VERSION: To remove any redundant patches, the LAST_VERSION must be real"
	echo "GCC_ARM: The path of gcc arm tool in your local environment"
	logger "params error"
	logger "Usage: $0 CODE_DIR NEW_VERSION LAST_VERSION"
	logger "BRANCH: The branch of repository "Mulan-BES2500" you would like to build"
	logger "CODE_DIR: The parent dir of repository "Mulan-BES2500", which must be existing"
	logger "NEW_VERSION: The expected version number"
	logger "LAST_VERSION: To remove any redundant patches, the LAST_VERSION must be real"
	logger "GCC_ARM: The path of gcc arm tool in your local environment"
	exit 1
fi

BRANCH=$1
CODE_DIR=$2
if [ ! -d $CODE_DIR ];then
	echo "Directory $CODE_DIR does not exist"
	logger "Directory $CODE_DIR does not exist"
	exit 1
fi
TIME_NOW=`date +%Y%m%d%H%M`
NEW_VERSION=$3
LAST_VERSION=$4
GCC_ARM=$5

cd $CODE_DIR
CODE_DIR=$(pwd)
LOG_FILE="$CODE_DIR/Mulan-BES2500L_build_$TIME_NOW.log"
echo "Mulan-BES2500 build start at $TIME_NOW" | tee $LOG_FILE
echo "CODE_DIR: $CODE_DIR" | tee -a $LOG_FILE
echo "NEW_VERSION: $NEW_VERSION" | tee -a $LOG_FILE
echo "LAST_VERSION: $LAST_VERSION" | tee -a $LOG_FILE
echo "LOG_FILE: $LOG_FILE" | tee -a $LOG_FILE

OUT_PATH="$CODE_DIR/Mulan-BES2500L/out"
TOOLS_PATH="$CODE_DIR/Mulan-BES2500L/tools"
echo "OUT_PATH: $OUT_PATH" | tee -a $LOG_FILE
echo "TOOLS_PATH: $TOOLS_PATH" | tee -a $LOG_FILE

USER_NAME=$(git config --get user.name)
USER_EMAIL=$(git config --get user.email)
echo "USER_NAME: $USER_NAME" | tee -a $LOG_FILE
echo "USER_EMAIL: $USER_EMAIL" | tee -a $LOG_FILE

function download_bes_code() {
	# git pull or git clone the latest bes2500 code
	mkdir "$CODE_DIR" 2> /dev/null
	cd "$CODE_DIR"
	echo -e "\ncd $(pwd)" | tee -a $LOG_FILE

	if [ ! -d "Mulan-BES2500L" ];then
		for((i=1;i<=50;i++));
		do
			echo -e "\ngit clone Mulan-BES2500L start: $i" | tee -a $LOG_FILE
			echo "git clone -b $BRANCH ssh://$USER_NAME@10.10.192.13:29418/Mulan-BES2500L" | tee -a $LOG_FILE
			git clone -b $BRANCH ssh://$USER_NAME@10.10.192.13:29418/Mulan-BES2500L 2>&1 | tee -a $LOG_FILE
			result=${PIPESTATUS[0]}

			echo "git clone Mulan-BES2500L finish: $result" | tee -a $LOG_FILE
			if [ $result -eq 0 ]; then
				break
			fi
			if [ $i -eq 50 ]; then
				echo "git clone failed when download Mulan-BES2500L!" | tee -a $LOG_FILE
				exit 1
			fi
		done
	else
		cd Mulan-BES2500L
		echo "cd $(pwd)" | tee -a $LOG_FILE
		git checkout $BRANCH 2>&1 | tee -a $LOG_FILE
		echo "git checkout $BRANCH" | tee -a $LOG_FILE
		git reset --hard $LAST_VERSION 2>&1 | tee -a $LOG_FILE    # git reset to LAST_VERSION & git clean;
	        echo "git reset --hard $LAST_VERSION" | tee -a $LOG_FILE
	        git clean -fxd 2>&1 | tee -a $LOG_FILE
	        echo "git clean -fxd" | tee -a $LOG_FILE
		for((i=1;i<=50;i++));
		do
			echo -e "\ngit pull start: $i" | tee -a $LOG_FILE
			git pull 2>&1 | tee -a $LOG_FILE
			result=${PIPESTATUS[0]}

			echo "git pull finish: $result" | tee -a $LOG_FILE
			if [ $result -eq 0 ]; then
				break
			fi
			if [ $i -eq 50 ]; then
				echo "git pull failed!" | tee -a $LOG_FILE
				exit 1
			fi
		done
	fi

	return 0
}

function build_bes2500() {
	cd $CODE_DIR/Mulan-BES2500L
	echo -e "\ncd $(pwd)" | tee -a $LOG_FILE
	sed -i "s@arm-none-eabi-@$GCC_ARM/arm-none-eabi-@" Makefile 2>&1 | tee -a $LOG_FILE
	echo "Modified CONFIG_CROSS_COMPILE to $GCC_ARM/arm-none-eabi- in Makefile result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	sed -i "s/\\\$key\\\$/\\\$key/" tools/fill_sec_base.pl
	echo "Modified $key$ to $key in tools/fill_sec_base.pl result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	export PATH=$GCC_ARM:$PATH 2>&1 | tee -a $LOG_FILE
	echo "Export $GCC_ARM as environmental variable result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	
	echo -e "\nmake T=best2500p_ibrt SOFTWARE_VERSION=$NEW_VERSION -j FORCE_TO_USE_LIB=1" | tee -a $LOG_FILE
	make T=best2500p_ibrt SOFTWARE_VERSION=$NEW_VERSION -j FORCE_TO_USE_LIB=1 2>&1 | tee -a $LOG_FILE
	result=${PIPESTATUS[0]}
	if [ $result -ne 0 ]; then
		echo "make failed: "$result | tee -a $LOG_FILE
		exit 1
	fi
	
	echo -e "\nmake T=prod_test/ota_copy -j CHIP=best1501" | tee -a $LOG_FILE
	make T=prod_test/ota_copy -j CHIP=best1501 2>&1 | tee -a $LOG_FILE
	result=${PIPESTATUS[0]}
	if [ $result -ne 0 ]; then
		echo "make failed: "$result | tee -a $LOG_FILE
		exit 1
	fi
	
	return 0
}

function converted_bin_generation() {
	cd $TOOLS_PATH
	echo -e "\ncd $(pwd)" | tee -a $LOG_FILE
	echo -e "\npython2 generate_crc32_of_image.py $OUT_PATH/best2500p_ibrt/best2500p_ibrt.bin" | tee -a $LOG_FILE
	python2 generate_crc32_of_image.py ../out/best2500p_ibrt/best2500p_ibrt.bin 2>&1 | tee -a $LOG_FILE
	if [ $result -ne 0 ]; then
		echo "generate best2500p_ibrt.bin.converted.bin failed: "$result | tee -a $LOG_FILE
		exit 1
	fi
	
	return 0
}

download_bes_code
build_bes2500
converted_bin_generation

echo -e "\nBES2500 Branch $BRANCH Build completed at `date +%Y%m%d%H%M`" | tee -a $LOG_FILE

exit 0
