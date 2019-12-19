#!/bin/bash

### Change to home dir (just in case)
cd ~

### Prereq
echo -e "Setting up prerequisites and updating the server..."
sudo apt-get update -y
sudo apt-get install build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool ncurses-dev unzip git python python-zmq zlib1g-dev wget libcurl4-gnutls-dev bsdmainutils automake curl bc dc jq nano gpw -y

### Setup Vars
GENPASS="$(date +%s | sha256sum | base64 | head -c 32 ; echo)"
confFile=~/.bzedge/bzedge.conf
HIGHESTBLOCK="$(wget -nv -qO - https://explorer.getbze.com/insight-api-bzedge-v2/blocks\?limit=1 | jq .blocks[0].height)"

### Font Colors
BLACK='\e[30m'
RED='\e[91m'
GREEN='\e[92m'
YELLOW='\e[93m'
BLUE='\e[94m'
PINK='\e[95m'
CYAN='\e[96m'
WHITE='\e[97m'
NC='\033[0m'

read -p "${CYAN}Press any key to begin...${NC}"

### Check user
if [ "$EUID" -eq 0 ]
    then
        clear
        echo -e "${RED}Warning:${NC} You should not run this as root! Create a new user with sudo permissions!\nThis can be done with (replace username with an actual username such as node):\nadduser username\nusermod -aG sudo username\nsu username\ncd ~\n\nYou will be in a new home directory. Make sure you redownload the script or move it from your /root directory!"
        exit
fi

starting_port=1980
ending_port=2080
function check_port {
    for NEXTPORT in $(seq $starting_port $ending_port); do
        if ! sudo lsof -Pi :$NEXTPORT -sTCP:LISTEN -t >/dev/null; then
            echo "$NEXTPORT not in use. Using it for rpcport"
            port_to_use=$NEXTPORT
            return $NEXTPORT
        elif [ "$NEXTPORT" == "$ending_port" ]; then
            echo "No port to use"
            exit
        fi
    done
}

### Kill any existing processes
echo -e "Stopping any existing BZEdge services..."
sudo systemctl stop bzedgenode-$USER
killall -9 bzedged

### Backup wallet.dat
if [ -f .bzedge/wallet.dat ]; then
    echo -e "Backing up wallet.dat"
    if [ ! -d bzedge-backup ]; then
        mkdir bzedge-backup
    fi
    cp ~/.bzedge/wallet.dat ~/bzedge-backup/wallet$(date "+%Y.%m.%d-%H.%M.%S").dat
fi

### Fetch Params
echo -e "Fetching Zcash-params..."
bash -c "$(wget -qO - https://raw.githubusercontent.com/bze-alphateam/bzedge/master/zcutil/fetch-params.sh)"

### Setup Swap
echo -e "Adding swap if needed..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

### Check if old binaries exist
clear
if [ -f bzedged ]; then
    echo -e "Found old binaries... Deleting them..."
    rm bzedged
    rm bzedge-cli
fi

### Prompt user to build or download
echo -e "Would you prefer to build the daemon from source or download an existing daemon binary?"
echo -e "1 - Build from source"
echo -e "2 - Download binary"
read -p "Choose: " downloadOption

### Compile or Download based on user selection
if [ "$downloadOption" == "1" ]; then
    ### Build Daemon
    echo -e "Begin compiling of daemon..."
    if [ ! -d bzedge ]
    then
        cd ~ && git clone https://github.com/bze-alphateam/bzedge --branch master --single-branch
    else
        cd bzedge && git pull
    fi
    cd bzedge
    ./zcutil/build.sh -j$(nproc)
    cd ~
    cp bzedge/src/bzedged bzedge/src/bzedge-cli .
    chmod +x bzedged bzedge-cli
    strip -s bzedge*
else
    ### Download Daemon
    echo -e "Grabbing the latest daemon..."
    wget -N https://github.com/bze-alphateam/bzedge/releases/download/v3.0.0/bzedge-3.0.0-ubuntu-18.04.tar.gz -O ~/binary.zip
    unzip -o ~/binary.zip -d ~
    rm ~/binary.zip
    chmod +x bzedged bzedge-cli
fi

### Initial .bzedge/
if [ ! -d ~/.bzedge ]; then
    echo -e "Created .bzedge directory..."
    mkdir .bzedge
fi

### Download bootstrap
if [ ! -d ~/.bzedge/blocks ]; then
    echo -e "Grabbing the latest bootstrap (to speed up syncing)..."
    wget -N https://bootstrap.getbze.com/bootstrap_txindex_latest.zip
    unzip -o ~/bootstrap_txindex_latest.zip 'bootstrap/*' -d ~/.bzedge
    rm ~/bootstrap_txindex_latest.zip
fi

### Check if bzedge.conf exists and prompt user about overwriting it
if [ -f "$confFile" ]
then
    clear
    echo -e "A bzedge.conf already exists. Do you want to overwrite it?"
    read -p "Y/n: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            rm -fv $confFile
        fi
fi

### Final conf setup
if [ ! -f $confFile ]; then
    ### Grab current height
    HIGHESTBLOCK="$(wget -nv -qO - https://explorer.getbze.com/insight-api-bzedge-v2/blocks/?limit=1 | jq .blocks[0].height)"
    if [ -z "$HIGHESTBLOCK" ]
    then
        clear
        echo -e "Unable to fetch current block height from explorer. Please enter it manually. You can obtain it from https://explorer.getbze.com/"
        read -p "Current Height: " HIGHESTBLOCK
    fi

    ### Checking ports
    check_port

    ### Write to bzedge.conf
    touch $confFile
    rpcuser=$(gpw 1 30)
    echo "rpcuser="$rpcuser >> $confFile
    rpcpassword=$(gpw 1 30)
    echo "rpcpassword="$rpcpassword >> $confFile
    echo "rpcport=$NEXTPORT" >> $confFile
    if [ "$NEXTPORT" != 1981 ]; then
        echo "listen=0" >> $confFile
    else
        echo "listen=1" >> $confFile
    fi
    echo "port=1980" >> $confFile
    echo "server=1" >> $confFile
    echo "txindex=1" >> $confFile
    echo "daemon=1" >> $confFile
    echo -e "\n#From your wallet, copy your masternode config.\n#Paste your bzedge.conf data at the bottom of this file.\n#If the paste does not correctly format, be sure to change everything to be on its own line in this file.\n#To save, use combo Ctr + X, then type y then Enter.\n\n" >> $confFile

    nano $confFile
else
    clear
    echo -e "bzedge.conf exists. Skipping..."
fi

### Choose to setup service or not
clear
echo -e "Would you like to setup a service to automatically start/restart bzedged on reboots/failures?"
read -p "Y/n: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        ### Setup Service
        echo -e "Creating service file..."
        createdService="1"

        ### Remove old service file >= 0.14.1
        if [ -f /lib/systemd/system/bzedgenode.service ]; then
            echo -e "Removing old service file..."
            sudo systemctl disable --now bzedgenode.service &>/dev/null
            sudo rm /lib/systemd/system/bzedgenode.service &>/dev/null
        fi

        ### Remove old service file >= v0.16.2
        if [ -f /lib/systemd/system/bzedgenode-$USER.service ]; then
            echo -e "Removing old service file..."
            sudo systemctl disable --now bzedgenode-$USER.service &>/dev/null
            sudo rm /lib/systemd/system/bzedgenode-$USER.service &>/dev/null
        fi

        ### Remove old service file
        if [ -f /etc/systemd/system/bzedgenode-$USER.service ]; then
            echo -e "Removing old service file..."
            sudo systemctl disable --now bzedgenode-$USER.service
            sudo rm /etc/systemd/system/bzedgenode-$USER.service
        fi

        service="echo '[Unit]
        Description=BZEdge daemon
        After=network-online.target
        [Service]
        User=$USER
        Group=$USER
        Type=forking
        Restart=always
        RestartSec=120
        RemainAfterExit=true
        ExecStart=$HOME/bzedged -daemon
        ProtectSystem=full
        [Install]
        WantedBy=multi-user.target' >> /etc/systemd/system/bzedgenode-$USER.service"

        #echo $service
        sudo sh -c "$service"

        ### Fire up the engines
        sudo systemctl enable bzedgenode-$USER.service
        sudo systemctl start bzedgenode-$USER

    else

        ### Remove old service file
        if [ -f /etc/systemd/system/bzedgenode-$USER.service ]; then
            echo -e "Removing old service file..."
            sudo systemctl disable --now bzedgenode-$USER.service
            sudo rm /etc/systemd/system/bzedgenode-$USER.service
        fi

        echo -e "${WHITE}No service was created...${NC} ${CYAN}Starting daemon...${NC}"
        ~/bzedged -daemon
    fi

echo -e "${CYAN}BZEdge started...${NC} Waiting 2 minutes for startup to finish"
sleep 120
newHighestBlock="$(wget -nv -qO - https://explorer.getbze.com/api/blocks\?limit=1 | jq .blocks[0].height)"
currentBlock="$(~/bzedge-cli getblockcount)"

### We need to add some failed start detection here with troubleshooting steps
### error code: -28

if [ -z "$newHighestBlock" ]
then
    echo
    echo -e "Unable to fetch current block height from explorer. Please enter it manually. You can obtain it from https://explorer.getbze.com"
    read -p "Current Height: " newHighestBlock
    newHighestBlockManual="$newHighestBlock"
fi

echo -e "Current Height is now $newHighestBlock"

while  [ "$newHighestBlock" != "$currentBlock" ]
do
    clear
    if [ -z "$newHighestBlockManual" ]
        then
            newHighestBlock="$(wget -nv -qO - https://explorer.getbze.com/api/blocks\?limit=1 | jq .blocks[0].height)"
        else
            newHighestBlock="$newHighestBlockManual"
    fi
    currentBlock="$(~/bzedge-cli getblockcount)"
    echo -e "${WHITE}Comparing block heights to ensure server is fully synced every 10 seconds${NC}";
    echo -e "${CYAN}Highest: $newHighestBlock ${NC}";
    echo -e "${PINK}Currently at: $currentBlock ${NC}";
    echo -e "${WHITE}Checking again in 10 seconds... The install will continue once it's synced.";echo
    echo -e "Last 10 lines of the log for error checking...";
    echo -e "===============";
    tail -10 ~/.bzedge/debug.log
    echo -e "===============";
    echo -e "Just ensure the current block height is rising over time...${NC}";
    sleep 10
done

clear
echo -e "${WHITE}Chain is fully synced with explorer height!${NC}"
echo
echo -e "${PINK}BZEdge masternode${NC}${WHITE} successfully configured and launched!${NC}"
echo
echo -e "${WHITE}You may now start the masternode in your wallet!${NC}"
echo
echo -e "${WHITE}##################################################${NC}"
echo
echo -e "Checking the bzedged service status...${NC}"

### Check health of service
if [ ! -z "$createdService" ]
then
    sudo systemctl --no-pager status bzedgenode-$USER
    echo
fi

~/bzedge-cli masternodedebug

if [ -d ~/bzedge ]
then
    echo -e "Cleaning up... Do you want to remove your bzedge build directory?"
    read -p "Y/n: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            rm -rf ~/bzedge
            echo -e "Build directory removed..."
        fi
fi

exit
