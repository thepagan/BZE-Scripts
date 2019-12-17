#!/bin/bash

## Create Bootstrap

## Prereq (Uncomment if needed)
#sudo apt-get install zip

## Move to home dir
cd ~

## Check if bootstrap exists
if [ -f bzedge_bootstrap_$(date +%d-%m-%Y).zip ]
    then
        rm bzedge_bootstrap_$(date +%d-%m-%Y).zip
fi

if [ -d bootstrap ]
    then
        rm -rfv ./bootstrap
fi

## Recreate bootstrap dir
mkdir bootstrap
cd bootstrap

cp -r ~/.bzedge/blocks .
cp -r ~/.bzedge/chainstate .

cd ~

## Zip
zip -r bzedge_bootstrap_$(date +%d-%m-%Y).zip bootstrap

## Clean up
rm -rfv ./bootstrap
