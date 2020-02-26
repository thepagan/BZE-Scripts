#!/bin/bash

###### you must be logged in as a sudo user, not root #######

COIN_NAME='bzedge'

#wallet information
UBUNTU_16_ZIP='https://github.com/bze-alphateam/bzedge/releases/download/v3.0.1/bzedge-3.0.1-ubuntu-16.04.zip'
UBUNTU_16_ZIPFILE='bzedge-3.0.1-ubuntu-16.04.zip'
UBUNTU_18_ZIP='https://github.com/bze-alphateam/bzedge/releases/download/v3.0.1/bzedge-3.0.1-ubuntu-18.04.zip'
UBUNTU_18_ZIPFILE='bzedge-3.0.1-ubuntu-18.04.zip'
FETCHPARAMS='https://raw.githubusercontent.com/bze-alphateam/bzedge/master/zcutil/fetch-params.sh'
BOOTSTRAP_ZIP='https://bootstrap.getbze.com/bootstrap_txindex_latest.zip'
BOOTSTRAP_ZIPFILE='bootstrap_txindex_latest.zip'
UPDATE_SCRIPT='https://raw.githubusercontent.com/bze-alphateam/BZE-Scripts/master/update.sh'
UPDATE_FILE='update.sh'
CONFIG_DIR='.bzedge'
CONFIG_FILE='bzedge.conf'
RPCPORT='1980'
PORT='1990'
SSHPORT='22'
COIN_DAEMON='bzedged'
COIN_CLI='bzedge-cli'
COIN_PATH='/usr/local/bin'
USERNAME="$(whoami)"
WORK_DIR=/home/$USER
SERVICE_NAME="bzedge-${USER}"
STARTINGRPCPORT=1980
ENDINGRPCPORT=2080

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

#end of required details
#

clear
echo -e "${YELLOW}====================================================================="
echo -e " BZEdge Masternode Setup"
echo -e "=====================================================================${NC}"
echo -e "${CYAN}Special thanks to dk808 member of Zel's team and BZE Team member Potato."
echo -e "Node setup starting, press [CTRL+C] to cancel.${NC}"
sleep 5
if [ "$USERNAME" = "root" ]; then
	echo -e "${CYAN}You are currently logged in as ${GREEN}root${CYAN}! Create a new user with sudo permissions!\n${YELLOW}This can be done with (replace username with an actual username such as bzedge1):\nadduser username\nusermod -aG sudo username\nsu username\ncd ~\n\nYou will be in a new home directory. Make sure you redownload the script or move it from your /root directory!${NC}"
	exit
fi

#functions
function wipe_clean() {
	echo -e "${YELLOW}Removing any instances of ${COIN_NAME^}${NC}"
	sudo systemctl stop ${SERVICE_NAME} > /dev/null 2>&1 && sleep 5
	sudo rm ~/${COIN_NAME}* > /dev/null 2>&1 && sleep 1
	rm -rf ~/$BOOTSTRAP_ZIPFILE && sleep 1
	rm update.sh > /dev/null 2>&1
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

function ssh_port() {
	echo -e "${YELLOW}Detecting SSH port being used...${NC}" && sleep 1
	SSHPORT=$(grep -w Port /etc/ssh/sshd_config | sed -e 's/.*Port //')
	whiptail --yesno "Detected you are using $SSHPORT for SSH is this correct?" 8 56
	if [ $? = 1 ]; then
		SSHPORT=$(whiptail --inputbox "Please enter port you are using for SSH" 8 43 3>&1 1>&2 2>&3)
		echo -e "${YELLOW}Using SSH port:${SEA} $SSHPORT${NC}" && sleep 1
	else
		echo -e "${YELLOW}Using SSH port:${SEA} $SSHPORT${NC}" && sleep 1
	fi
}

function check_port() {
    for NEXTPORT in $(seq $STARTINGRPCPORT $ENDINGRPCPORT); do
        if ! sudo lsof -Pi :$NEXTPORT -sTCP:LISTEN -t >/dev/null; then
            echo "$NEXTPORT not in use. Using it for rpcport"
            RPCPORT=$NEXTPORT
            break
        elif [ "$NEXTPORT" == "$ENDINGRPCPORT" ]; then
            echo "No port to use"
            exit
        fi
    done
}

function ip_confirm() {
	echo -e "${YELLOW}Detecting IP address being used...${NC}" && sleep 1
	WANIP=$(wget http://ipecho.net/plain -O - -q)
	whiptail --yesno "Detected IP address is $WANIP is this correct?" 8 60
	if [ $? = 1 ]; then
		WANIP=$(whiptail --inputbox "        Enter IP address" 8 36 3>&1 1>&2 2>&3)
	fi
}

function create_swap() {
	echo -e "${YELLOW}Creating swap if none detected...${NC}" && sleep 1
	MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	gb=$(awk "BEGIN {print $MEM/1048576}")
	GB=$(echo "$gb" | awk '{printf("%d\n",$1 + 0.5)}')
	if [ $GB -lt 2 ]; then
		let swapsize=$GB*2
		swap="$swapsize"G
		echo -e "${YELLOW}Swap set at $swap...${NC}"
	elif [ $GB -ge 2 -a $GB -lt 32 ]; then
		let swapsize=$GB+2
		swap="$swapsize"G
		echo -e "${YELLOW}Swap set at $swap...${NC}"
	elif [ $GB -ge 32 ]; then
		swap="$GB"G
		echo -e "${YELLOW}Swap set at $swap...${NC}"
	fi
	if ! grep -q "swapfile" /etc/fstab; then
		whiptail --yesno "No swapfile detected would you like to create one?" 8 54
		if [ $? = 0 ]; then
			sudo fallocate -l "$swap" /swapfile
			sudo chmod 600 /swapfile
			sudo mkswap /swapfile
			sudo swapon /swapfile
			echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
			echo -e "${YELLOW}Created ${SEA}${swap}${YELLOW} swapfile${NC}"
		else
			echo -e "${YELLOW}You have opted out on creating a swapfile so no swap created...${NC}"
		fi
	fi
	sleep 2
}

function install_packages() {
	echo -e "${YELLOW}Installing Packages...${NC}"
	if [[ $(lsb_release -d) = *Debian* ]] && [[ $(lsb_release -d) = *9* ]]; then
		sudo apt-get install dirmngr apt-transport-https -y
	fi
	sudo apt-get install software-properties-common -y
	sudo apt-get update -y
	sudo apt-get upgrade -y
	sudo apt-get install nano htop pwgen ufw figlet tmux -y
	sudo apt-get install build-essential libtool pkg-config -y
	sudo apt-get install libc6-dev m4 g++-multilib -y
	sudo apt-get install autoconf ncurses-dev unzip git python python-zmq -y
	sudo apt-get install wget curl bsdmainutils automake fail2ban -y
	echo -e "${YELLOW}Packages complete...${NC}"
}

function create_conf() {
	echo -e "${YELLOW}Creating Conf File...${NC}"
	if [ -f ~/$CONFIG_DIR/$CONFIG_FILE ]; then
		echo -e "${CYAN}Existing conf file found backing up to $COIN_NAME.old ...${NC}"
		mv ~/$CONFIG_DIR/$CONFIG_FILE ~/$CONFIG_DIR/$COIN_NAME.old;
	fi
	RPCUSER=$(pwgen -1 8 -n)
	PASSWORD=$(pwgen -1 20 -n)
	if [ "x$PASSWORD" = "x" ]; then
		PASSWORD=${WANIP}-$(date +%s)
	fi
		mkdir ~/$CONFIG_DIR > /dev/null 2>&1
		touch ~/$CONFIG_DIR/$CONFIG_FILE
		echo "rpcuser=$RPCUSER" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "rpcpassword=$PASSWORD" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "rpcport=$RPCPORT" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "daemon=1" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "txindex=1" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "addnode=explorer.bze.zelcore.io/" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "addnode=164.68.125.183" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "addnode=51.15.96.180" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "addnode=51.15.99.37" >> ~/$CONFIG_DIR/$CONFIG_FILE
		echo "maxconnections=256" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo "server=1" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo "listen=1" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo "externalip=[$WANIP]:$PORT" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo "masternodeaddr=[$WANIP]:$PORT" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo "rpcbind=[$WANIP]:$RPCPORT" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo "bind=[$WANIP]:$PORT" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo "txindex=1" >> ~/$CONFIG_DIR/$CONFIG_FILE
    sleep 2
}

function append_conf() {
	masternodeprivkey=$(./${COIN_CLI} masternode genkey)
	./$COIN_CLI stop && sleep 15
	echo "masternode=1" >> ~/$CONFIG_DIR/$CONFIG_FILE
	echo "masternodeprivkey"=$masternodeprivkey >> ~/$CONFIG_DIR/$CONFIG_FILE
	./$COIN_DAEMON
	NUM='60'
	MSG1="${CYAN}Stopping daemon to append masternode info to config and restarting daemon. This should just take a min...${NC}"
	MSG2=''
	spinning_timer
}

  function install_bins() {
	if [[ $(lsb_release -r) = *16.04* ]]; then
		wget $UBUNTU_16_ZIP
		sudo unzip $UBUNTU_16_ZIPFILE
		sudo chmod 555 ${COIN_NAME}*
		rm -rf $UBUNTU_16_ZIPFILE
	elif [[ $(lsb_release -r) = *18.04* ]]; then
		wget $UBUNTU_18_ZIP
		sudo unzip $UBUNTU_18_ZIPFILE
		sudo chmod 555 ${COIN_NAME}*
		rm -rf $UBUNTU_18_ZIPFILE
	elif [[ $(lsb_release -d) = *Debian* ]]; then
		wget $UBUNTU_16_ZIP
		sudo unzip $UBUNTU_16_ZIPFILE
		sudo chmod 555 ${COIN_NAME}*
		rm -rf $UBUNTU_16_ZIPFILE
	fi
}

function zk_params() {
	echo -e "${YELLOW}Installing zkSNARK params...${NC}"
	wget $FETCHPARAMS
	chmod +x fetch-params.sh && ./fetch-params.sh
	rm fetch-params.sh
}

function bootstrap() {
	if [ -e ~/$CONFIG_DIR/blocks -a -e ~/$CONFIG_DIR/chainstate ]; then
		rm -rf ~/$CONFIG_DIR/blocks ~/$CONFIG_DIR/chainstate
		echo -e "${YELLOW}Downloading and installing wallet bootstrap please be patient...${NC}"
		wget $BOOTSTRAP_ZIP
		unzip $BOOTSTRAP_ZIPFILE -d ~/$CONFIG_DIR
		rm -rf $BOOTSTRAP_ZIPFILE
	else
		echo -e "${YELLOW}Downloading and installing wallet bootstrap please be patient...${NC}"
		wget $BOOTSTRAP_ZIP
		unzip $BOOTSTRAP_ZIPFILE -d ~/$CONFIG_DIR
		rm -rf $BOOTSTRAP_ZIPFILE
	fi
}

function update_script() {
	wget $UPDATE_SCRIPT
	chmod +x $UPDATE_FILE
}

function create_service() {
	echo -e "${YELLOW}Creating ${COIN_NAME^} service...${NC}"
	sudo touch /etc/systemd/system/$SERVICE_NAME.service
	sudo chown $USERNAME:$USERNAME /etc/systemd/system/$SERVICE_NAME.service
	ls -al /etc/systemd/system
	cat << EOF > /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
Type=forking
User=$USERNAME
Group=$USERNAME
WorkingDirectory=/home/$USERNAME/$CONFIG_DIR
ExecStart=/home/$USERNAME/$COIN_DAEMON -datadir=/home/$USERNAME/$CONFIG_DIR/ -conf=/home/$USERNAME/$CONFIG_DIR/$CONFIG_FILE -daemon
ExecStop=-/home/$USERNAME/$COIN_CLI stop
Restart=always
RestartSec=3
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF
	sudo chown root:root /etc/systemd/system/$SERVICE_NAME.service
	sudo systemctl daemon-reload
	sleep 4
	sudo systemctl enable $SERVICE_NAME.service > /dev/null 2>&1
}

function basic_security() {
  whiptail --yesno "Do you want to secure your server by enabling the firewall?" 8 56
  if [ $? = 1 ]; then
		echo -e "${YELLOW}Skipping UFW setup...${NC}" && sleep 1
	else
    echo -e "${YELLOW}Configuring firewall and enabling fail2ban...${NC}"
    sudo ufw allow $SSHPORT/tcp
    sudo ufw allow $PORT/tcp
    sudo ufw logging on
    sudo ufw default deny incoming
    sudo ufw limit OpenSSH
    echo "y" | sudo ufw enable > /dev/null 2>&1
    sudo systemctl enable fail2ban > /dev/null 2>&1
    sudo systemctl start fail2ban > /dev/null 2>&1
	fi
}

function start_daemon() {
	NUM='105'
	MSG1='Starting daemon & syncing with chain please be patient this will take about 2 min...'
	MSG2="${CHECK_MARK} ${GREEN}daemon successfully running${NC}"
	sudo systemctl start $SERVICE_NAME.service > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo && spinning_timer
		NUM='10'
		MSG1='Getting info...'
		MSG2="${CHECK_MARK}"
		echo && spinning_timer
		echo
		./$COIN_CLI getinfo
		sleep 5
		sudo chown -R $USERNAME:$USERNAME /home/$USERNAME
	else
		echo -e "${RED}Something is not right the daemon did not start. Will exit out so please log back in and run the script again.${NC}"
		exit
	fi
}

function status_loop() {
	while true
	do
		clear
		echo -e "${YELLOW}======================================================================================"
		echo -e "${GREEN} MASTERNODE SYNC STATUS"
		echo -e " THIS SCREEN REFRESHES EVERY 30 SECONDS"
		echo -e " TO VIEW THE CURRENT BLOCK GO TO https://explorer.getbze.com/"
		echo -e " DO NOT START THE MASTERNODE UNTIL THE MNSYNC STATUS RETURNS WITH SYNCHRONIZATION FINISHED"
		echo -e " AND AT LEAST 15 CONFIRMATIONS OF YOUR COLLATERAL TX"
		echo -e "${YELLOW}======================================================================================${NC}"
		echo
		./$COIN_CLI getinfo
		sleep 1
		./$COIN_CLI mnsync status
		NUM='30'
		MSG1="${CYAN}Refreshes every 15 seconds until your Masternode finishes syncing to the Masternode list and will stop the loop on it's own.${NC}"
		MSG2="\e[2K\r"
		spinning_timer
		if [[ $(${COIN_CLI} mnsync status) = *999* ]]; then
			break
		fi
	done
}

function check() {
	echo && echo && echo
	echo -e "${YELLOW}Running through some checks...${NC}"
	if pgrep bzedged > /dev/null; then
		echo -e "${CHECK_MARK} ${CYAN}${COIN_NAME^} daemon is installed and running${NC}" && sleep 1
	else
		echo -e "${X_MARK} ${CYAN}${COIN_NAME^} daemon is not running${NC}" && sleep 1
	fi
	if [ -d "/home/$USERNAME/.zcash-params" ]; then
		echo -e "${CHECK_MARK} ${CYAN}zkSNARK params installed${NC}" && sleep 1
	else
		echo -e "${X_MARK} ${CYAN}zkSNARK params not installed${NC}" && sleep 1
	fi
	if [ -f "/home/$USERNAME/update.sh" ]; then
		echo -e "${CHECK_MARK} ${CYAN}Update script downloaded${NC}" && sleep 3
	else
		echo -e "${X_MARK} ${CYAN}Update script not installed${NC}" && sleep 3
	fi
	echo && echo && echo
}

function display_banner() {
		echo -e "${BLUE}"
		figlet -t -k "BZEDGE   MASTERNODE"
		echo -e "${NC}"
		echo -e "${YELLOW}================================================================================================================================"
		echo -e " PLEASE COMPLETE THE MASTERNODE SETUP FOR YOUR CONTROL WALLET BY ADDING FOLLOWING LINE TO YOUR MASTERNODE CONF FILE"
		echo -e " JUST REPLACE \"TxID\", \"Output_Index\" and \"your_alias\" WITH CORRECT VALUES${NC}"
		echo -e " your_alias ${WANIP}:${PORT} ${masternodeprivkey} TxID Output_Index"
		echo -e "${CYAN} COURTESY OF DK808${NC}"
		echo
		echo -e "${YELLOW}   Commands to manage ${COIN_NAME} service${NC}"
		echo -e "${PIN} ${CYAN}TO START: ${SEA}systemctl start ${SERVICE_NAME}${NC}"
		echo -e "${PIN} ${CYAN}TO STOP : ${SEA}systemctl stop ${SERVICE_NAME}${NC}"
		echo -e "${PIN} ${CHECK_MARK} ${CYAN}STATUS: ${SEA}systemctl status ${SERVICE_NAME}${NC}"
		echo -e "${CYAN}   In the event server ${RED}reboots${NC}${CYAN} ${COIN_NAME} service will ${GREEN}auto-start${CYAN} the daemon${NC}"
		echo
		echo -e "${PIN} ${YELLOW}To update binaries wait for announcement that update is ready then enter:${NC} ${SEA}./${UPDATE_FILE}${NC}"
		echo -e "${YELLOW}================================================================================================================================${NC}"
		read -n1 -r -p "Press any key to continue..." key
		status_loop
}

#
#end of functions

cd ~
#run functions
  wipe_clean
	ssh_port
	check_port
	ip_confirm
	create_swap
	install_packages
	create_conf
	install_bins
	zk_params
	bootstrap
	update_script
	create_service
	basic_security
	start_daemon
	append_conf
	check
	display_banner
