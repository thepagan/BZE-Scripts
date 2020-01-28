#!/bin/bash

## Create Bootstrap

## Prereq (Uncomment if needed)
#sudo apt-get install zip

#declare variables
ZIPNAME="bzedge_bootstrap_$(date +%Y-%m-%d).zip"

## Move to home dir
cd ~

## Create bootstraps history dir
if [ ! -d bootstraps ]
    then
        mkdir bootstraps
fi
cd bootstraps

#check if history dir exists
if [ ! -d history ]
    then
        mkdir history
fi
cd history

## Check if bootstrap exists
if [ -f $ZIPNAME ]
    then
        rm $ZIPNAME
fi

cd ~
#check if workdir is there
#directory used to copy chain data to and zip them
if [ ! -d workDir ]
    then
        mkdir workDir
fi
cd workDir

cp -r ~/.bzedge/blocks .
cp -r ~/.bzedge/chainstate .

## Zip
zip -r $ZIPNAME ./blocks ./chainstate

cd ~

## Copy to bootstraps/history dir
cp ./workDir/$ZIPNAME ./bootstraps/history/

#symlink to latest txindex zip
ln -sfn /home/$USER/bootstraps/history/$ZIPNAME /home/$USER/bootstraps/bootstrap_txindex_latest.zip

## Clean up
rm -rfv ./workDir
