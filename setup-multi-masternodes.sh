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
CONFIG_DIR='.bzedge'
CONFIG_FILE='bzedge.conf'
RPCPORT='1980'
PORT='1990'
SSHPORT='22'
COIN_DAEMON='bzedged'
USERNAME="$(whoami)"
WORK_DIR=/home/$USER
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
echo -e " BZEdge Multiple MNs Setup"
echo -e "=====================================================================${NC}"
echo -e "${CYAN}Setting up multiple masternodes on the same VPS with provided aliases and IPs"
echo -e "Node setup starting, press [CTRL+C] to cancel.${NC}"
sleep 5
if [ "$USERNAME" = "root" ]; then
	echo -e "${CYAN}You are currently logged in as ${GREEN}root${CYAN}! Create a new user with sudo permissions!\n${YELLOW}This can be done with (replace username with an actual username such as bzedge1):\nadduser username\nusermod -aG sudo username\nsu username\ncd ~\n\nYou will be in a new home directory. Make sure you redownload the script or move it from your /root directory!${NC}"
	exit
fi

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

function create_swap() {
	echo -e "${YELLOW}Creating swap if none detected...${NC}" && sleep 1
	MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	gb=$(awk "BEGIN {print $MEM/1048576}")
	GB=$(echo "$gb" | awk '{printf("%d\n",$1 + 0.5)}')
	if [ $GB -lt 2 ]; then
		swap="2"G
	else
		swap="4"G
	fi

	echo -e "${YELLOW}Swap set at $swap...${NC}"
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
			echo -e "${YELLOW}Swipe file already exists. Skipping swap creation...${NC}"
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

function download_bins() {
	if [[ $(lsb_release -r) = *16.04* ]]; then
		wget $UBUNTU_16_ZIP
		sudo unzip $UBUNTU_16_ZIPFILE
		rm -rf $UBUNTU_16_ZIPFILE
	elif [[ $(lsb_release -r) = *18.04* ]]; then
		wget $UBUNTU_18_ZIP
		sudo unzip $UBUNTU_18_ZIPFILE
		rm -rf $UBUNTU_18_ZIPFILE
	elif [[ $(lsb_release -d) = *Debian* ]]; then
		wget $UBUNTU_16_ZIP
		sudo unzip $UBUNTU_16_ZIPFILE
		rm -rf $UBUNTU_16_ZIPFILE
	fi
	sudo chmod 555 ${COIN_NAME}*
	sudo chown $USERNAME:USERNAME ${COIN_NAME}* -R
}

function zk_params() {
  if [ -d ~/.zcash-params ]; then
    echo -e "${YELLOW}zkSNARK params already installed...${NC}"
  else
    echo -e "${YELLOW}Installing zkSNARK params...${NC}"
    wget $FETCHPARAMS
    chmod +x fetch-params.sh && ./fetch-params.sh
    rm fetch-params.sh
	fi
}

function bootstrap() {
  if [ -d ~/chainstate ]; then
    echo -e "${YELLOW}Bootstrap already downloaded...${NC}"
  else
    echo -e "${YELLOW}Downloading and installing wallet bootstrap please be patient...${NC}"
    wget $BOOTSTRAP_ZIP
    unzip $BOOTSTRAP_ZIPFILE
    rm -rf $BOOTSTRAP_ZIPFILE
  fi
}

function basic_security() {
  whiptail --yesno "Do you want to secure your server by enabling the firewall?" 8 56
  if [ $? = 1 ]; then
		echo -e "${YELLOW}Skipping UFW setup...${NC}" && sleep 1
	else
    echo -e "${YELLOW}Configuring firewall and enabling fail2ban...${NC}"
    sudo ufw allow $PORT/tcp
    sudo ufw allow 22/tcp
    sudo ufw logging on
    sudo ufw default deny incoming
    sudo ufw limit OpenSSH
    echo "y" | sudo ufw enable > /dev/null 2>&1
    sudo systemctl enable fail2ban > /dev/null 2>&1
    sudo systemctl start fail2ban > /dev/null 2>&1
	fi
}

function createMN() {
  echo -e "${YELLOW}New Conf File ${2} ${NC}"
  echo -e "${YELLOW}Creating Conf File...${NC}"
	if [ -f ~/$2/$CONFIG_FILE ]; then
		echo -e "${CYAN}Existing conf file found backing up to $COIN_NAME.old ...${NC}"
		mv ~/$2/$CONFIG_FILE ~/$2/$COIN_NAME.old;
	fi
	RPCUSER=$(pwgen -1 8 -n)
	PASSWORD=$(pwgen -1 20 -n)
	if [ "x$PASSWORD" = "x" ]; then
		PASSWORD=${WANIP}-$(date +%s)
	fi

	check_port
	sudo ufw allow $SSHPORT/tcp
	sleep 2

  mkdir ~/$2 > /dev/null 2>&1
  touch ~/$2/$CONFIG_FILE
  echo "rpcuser=$RPCUSER" >> ~/$2/$CONFIG_FILE
  echo "rpcpassword=$PASSWORD" >> ~/$2/$CONFIG_FILE
  echo "rpcport=$RPCPORT" >> ~/$2/$CONFIG_FILE
  echo "daemon=1" >> ~/$2/$CONFIG_FILE
  echo "txindex=1" >> ~/$2/$CONFIG_FILE
  echo "addnode=explorer.bze.zelcore.io/" >> ~/$2/$CONFIG_FILE
  echo "addnode=167.86.99.150" >> ~/$2/$CONFIG_FILE
  echo "addnode=144.91.121.65" >> ~/$2/$CONFIG_FILE
  echo "addnode=144.91.119.59" >> ~/$2/$CONFIG_FILE
  echo "maxconnections=256" >> ~/$2/$CONFIG_FILE
  echo "server=1" >> ~/$2/$CONFIG_FILE
  echo "listen=1" >> ~/$2/$CONFIG_FILE
  echo "externalip=[$1]:$PORT" >> ~/$2/$CONFIG_FILE
  echo "masternodeaddr=[$1]:$PORT" >> ~/$2/$CONFIG_FILE
  echo "rpcbind=[$1]:$RPCPORT" >> ~/$2/$CONFIG_FILE
  echo "bind=[$1]:$PORT" >> ~/$2/$CONFIG_FILE
  echo "masternodeprivkey=$3" >> ~/$2/$CONFIG_FILE
  echo "masternode=1" >> ~/$2/$CONFIG_FILE
  sleep 2

  echo -e "${YELLOW}Copying chainstate...${NC}"
  cp -r ~/chainstate ~/$2/
  sleep 2

  echo -e "${YELLOW}Copying blocks...${NC}"
  cp -r ~/blocks ~/$2/
  sleep 2

  echo -e "${YELLOW}Starting daemon with -datadir=${2}${NC}"
  ./$COIN_DAEMON -d -datadir=$WORK_DIR/$2

  echo -e "${YELLOW}USE THIS IN CONTROL WALLET IN masternode.conf AND REPLACE TXID and TXindex"
  echo -e "======================================================================================${NC}"
  echo -e "${GREEN}$2 [$1]:1990 $3 $4 $5${NC}"
  echo -e "${YELLOW}======================================================================================${NC}"

  sleep 15
}

#
#end of functions

cd ~
create_swap
install_packages
download_bins
zk_params
bootstrap
basic_security

#call as many times needed
#IP = YOUR VPS IP ADDRESS(IPv4 or IPv6 supported. Has to be unique for each MN)
#MNKEY = generate a MN KEY. Keep this secret. This key is the link between your MN and your control wallet
#TX_OF_250K_BZE = a txid of exactly 250,000 BZE for MN collateral
#TX_INDEX = the txindex of collateral transaction.
createMN 'IP' 'MN_LABEL' 'MNKEY' 'TX_OF_250K_BZE' 'TX_INDEX'
