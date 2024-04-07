#!/bin/bash

if (( $# < 5 )) ; then
	echo "params error"
	echo "Usage: $0 BRANCH CODE_DIR NEW_VERSION LAST_VERSION GCC_ARM"
	echo "BRANCH: The branch of repository "Mulan-NXP595" you would like to build"
	echo "CODE_DIR: The parent dir of repository "Mulan-NXP595", which must be existing"
	echo "NEW_VERSION: The expected version number"
	echo "LAST_VERSION: To remove any redundant patches, the LAST_VERSION must be real"
	echo "GCC_ARM: The path of gcc arm tool in your local environment"
	logger "params error"
	logger "Usage: $0 CODE_DIR NEW_VERSION LAST_VERSION"
	logger "BRANCH: The branch of repository "Mulan-NXP595" you would like to build"
	logger "CODE_DIR: The parent dir of repository "Mulan-NXP595", which must be existing"
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
LOG_FILE="$CODE_DIR/Mulan-NXP595_build_$TIME_NOW.log"
echo "Mulan-NXP595 build start at $TIME_NOW" | tee $LOG_FILE
echo "CODE_DIR: $CODE_DIR" | tee -a $LOG_FILE
echo "NEW_VERSION: $NEW_VERSION" | tee -a $LOG_FILE
echo "LAST_VERSION: $LAST_VERSION" | tee -a $LOG_FILE
echo "LOG_FILE: $LOG_FILE" | tee -a $LOG_FILE

TARGET_PATH="$CODE_DIR/Mulan-NXP595/target/mulan"
echo "TARGET_PATH: $TARGET_PATH" | tee -a $LOG_FILE

USER_NAME=$(git config --get user.name)
echo "USER_NAME: $USER_NAME" | tee -a $LOG_FILE

function download_nxp_code() {
	# git pull or git clone the latest nxp595 code
	mkdir "$CODE_DIR" 2> /dev/null
	cd "$CODE_DIR"
	echo -e "\ncd $(pwd)" | tee -a $LOG_FILE

	if [ ! -d "Mulan-NXP595" ];then
		for((i=1;i<=50;i++));
		do
			echo -e "\ngit clone Mulan-NXP595 start: $i" | tee -a $LOG_FILE
			echo "git clone -b $BRANCH ssh://$USER_NAME@10.10.192.13:29418/Mulan-NXP595" | tee -a $LOG_FILE
			git clone -b $BRANCH ssh://$USER_NAME@10.10.192.13:29418/Mulan-NXP595 >> $LOG_FILE 2>&1
			result=${PIPESTATUS[0]}

			echo "git clone Mulan-NXP595 finish: $result" | tee -a $LOG_FILE
			if [ $result -eq 0 ]; then
				break
			fi
			if [ $i -eq 50 ]; then
				echo "git clone failed when download Mulan-NXP595!" | tee -a $LOG_FILE
				exit 1
			fi
		done
	else
		cd Mulan-NXP595
		echo "cd $(pwd)" | tee -a $LOG_FILE
		echo "git reset --hard" | tee -a $LOG_FILE
		git reset --hard >> $LOG_FILE 2>&1
		git checkout $BRANCH >> $LOG_FILE 2>&1
		echo "git checkout $BRANCH ${PIPESTATUS[0]}" | tee -a $LOG_FILE
		git reset --hard $LAST_VERSION >> $LOG_FILE 2>&1    # git reset to LAST_VERSION & git clean;
	        echo "git reset --hard $LAST_VERSION ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	        echo "git clean -fxd" | tee -a $LOG_FILE
	        git clean -fxd >> $LOG_FILE 2>&1
		for((i=1;i<=50;i++));
		do
			echo -e "\ngit pull start: $i" | tee -a $LOG_FILE
			git pull >> $LOG_FILE 2>&1
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

function build_nxp595() {
	cd $TARGET_PATH
	echo -e "\ncd $(pwd)" | tee -a $LOG_FILE
	sed -i "s/V0\.1\.0/$NEW_VERSION/" version.h >> $LOG_FILE 2>&1
	echo "Modified GTK_FW_VERSION to $NEW_Version in version.h result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	sed -i "s@../../tools/gcc/bin@$GCC_ARM@" rtconfig.py
	echo "Modified GCC_ARM tool to $GCC_ARM in rtconfig.py result ${PIPESTATUS[0]}" | tee -a $LOG_FILE
	
	echo -e "\nscons -j64" | tee -a $LOG_FILE
	scons -j64 >> $LOG_FILE 2>&1
	result=${PIPESTATUS[0]}
	if [ $result -ne 0 ]; then
		echo "scons -j64 failed: "$result | tee -a $LOG_FILE
		exit 1
	fi

	return 0
}

download_nxp_code
build_nxp595

echo -e "\nNXP595 Branch $BRANCH Build completed at `date +%Y%m%d%H%M`" | tee -a $LOG_FILE

exit 0
