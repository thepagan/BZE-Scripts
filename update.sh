#!/bin/bash

COIN_NAME='bzedge'

#wallet information
UBUNTU_16_ZIP='https://github.com/bze-alphateam/bzedge/releases/download/v3.0.0/bzedge-3.0.0-ubuntu-16.04.zip'
UBUNTU_16_ZIPFILE='bzedge-3.0.0-ubuntu-16.04.zip'
UBUNTU_18_ZIP='https://github.com/bze-alphateam/bzedge/releases/download/v3.0.0/bzedge-3.0.0-ubuntu-18.04.zip'
UBUNTU_18_ZIPFILE='bzedge-3.0.0-ubuntu-18.04.zip'
COIN_DAEMON='bzedged'
COIN_CLI='bzedge-cli'
COIN_PATH='/usr/local/bin'
USERNAME=$(whoami)

#color codes
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE="\\033[38;5;27m"
SEA="\\033[38;5;49m"
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

#emoji codes
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xE2\x9D\x8C${NC}"
PIN="${RED}\xF0\x9F\x93\x8C${NC}"

#
#end of required details


#functions
function stop_instances() {
	clear
	echo -e "${YELLOW}Removing any instances of ${COIN_NAME^}${NC}"
	sudo systemctl stop $COIN_NAME > /dev/null 2>&1 && sleep 2
	$COIN_CLI stop > /dev/null 2>&1 && sleep 2
	sudo killall $COIN_DAEMON > /dev/null 2>&1
	sudo rm -rf $COIN_PATH/${COIN_NAME}* > /dev/null 2>&1
}

function spinning_timer() {
	animation=( â ‹ â ™ â ¹ â ¸ â ¼ â ´ â ¦ â § â ‡ â  )
	end=$((SECONDS+$NUM))
	while [ $SECONDS -lt $end ];
	do
		for i in ${animation[@]};
		do
			echo -ne "${RED}\r$i ${CYAN}${MSG1}${NC}"
			sleep 0.1
		done
	done
	echo -e "${MSG2}"
}

function install_bins() {
	if [[ $(lsb_release -r) = *16.04* ]]; then
		wget $UBUNTU_16_ZIP
		sudo unzip $UBUNTU_16_ZIPFILE -d $COIN_PATH
		sudo chmod 555 $COIN_PATH/${COIN_NAME}*
		rm -rf $UBUNTU_16_ZIPFILE
	elif [[ $(lsb_release -r) = *18.04* ]]; then
		wget $UBUNTU_18_ZIP
		sudo unzip $UBUNTU_18_ZIPFILE -d $COIN_PATH
		sudo chmod 555 $COIN_PATH/${COIN_NAME}*
		rm -rf $UBUNTU_18_ZIPFILE
	elif [[ $(lsb_release -d) = *Debian* ]]; then
		wget $UBUNTU_16_ZIP
		sudo unzip $UBUNTU_16_ZIPFILE -d $COIN_PATH
		sudo chmod 555 $COIN_PATH/${COIN_NAME}*
		rm -rf $UBUNTU_16_ZIPFILE
	fi
}

function start_daemon() {
    echo -e "${YELLOW}Starting updated daemon please be patient this will take about a min...${NC}"
    $COIN_DAEMON
    NUM='60'
    MSG1="${CYAN}Starting updated daemon please be patient this will take about a min...${NC}"
    MSG2=''
    spinning_timer
}

function status_loop() {
	while true
	do
		clear
		echo -e "${YELLOW}======================================================================================"
		echo -e "${GREEN} MASTERNODE SYNC STATUS"
		echo -e " THIS SCREEN REFRESHES EVERY 30 SECONDS"
		echo -e " TO VIEW THE CURRENT BLOCK GO TO https://explorer.bze.zelcore.io/"
		echo -e " ONCE SCRIPT HAS FINISHED UPDATING CHECK STATUS OF THE MASTERNODE IF NOT ENABLED RESTART IT"
		echo -e "${YELLOW}======================================================================================${NC}"
		echo
		$COIN_CLI getinfo
		sleep 1
		$COIN_CLI mnsync status
		sudo chown -R $USERNAME:$USERNAME /home/$USERNAME
		NUM='30'
		MSG1="${CYAN}Refreshes every 30 seconds until your masternode finishes syncing to the masternode list and will stop the loop on its own.${NC}"
		MSG2="\e[2K\r"
		spinning_timer
		if [[ $(${COIN_CLI} mnsync status) = *999* ]]; then
			break
		fi
	done
    echo -e "${YELLOW}Update has completed you may need to restart the masternode from your control wallet...${NC}"
}

#run functions
  stop_instances
  install_bins
  start_daemon
  status_loop
