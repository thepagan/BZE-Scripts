# BZEdge scripts - life made easier

## bootstrap.sh
Creates a bootstrap with blockchain data and stores it.\
Latest .zip is symlinked to bootstrap_txindex_latest.zip.

## setup-masternode.sh
Sets up a daemon prepared to become a MN for ubuntu 16, 18 and Debian for the user that runs it.\
The following steps are followed: 
1. Cleanup: Stops any bzedge service running for current user and removes old binaries and bootsrap.(if any)
2. Checks the SSH port used to connect to the machine and whitelists it in the firewall.
3. Checks for ports used between STARTINGRPCPORT(=1980) and ENDINGRPCPORT(=2080) in order to use one of them as RPC port for BZE daemon.
4. Detects the IP address of the VPS and prompts the user to use it in MN settings or provide another IP.
5. Creates swap file depending on the memory available on the system.
6. Installs dependencies packages for BZEdge daemons to run on the system
7. Creates configuration file in current user's data dir
8. Installs binaries fetched from latest BZE daemon release
9. Installs sapling/sprout params
10. Downloads and unzips bootstrap
11. Creates a system service for BZE daemon. 
12. Enables firewall if user accepts
13. Starts BZE daemon service and checks the sync status
14. Checks MN's sync status and displays it on screen until MN is fully synced.

## usage

`bash -c "$(wget -O - https://raw.githubusercontent.com/zzzpotato/BZE-Scripts/master/bootstrap.sh)"`

`bash -c "$(wget -O - https://raw.githubusercontent.com/zzzpotato/BZE-Scripts/master/setup-masternode.sh)"`
