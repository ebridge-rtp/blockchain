#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
# Exit on first error
set -e
export COMPOSE_PROJECT_NAME=net

# don't rewrite paths for Windows Git Bash users
export MSYS_NO_PATHCONV=1
starttime=$(date +%s)
LANGUAGE=${1:-"golang"}
CC_SRC_PATH=github.com/securitization/go
if [ "$LANGUAGE" = "node" -o "$LANGUAGE" = "NODE" ]; then
	CC_SRC_PATH=github.com/securitization/node
fi

# clean the keystore
rm -rf ./hfc-key-store

docker-compose -f docker-compose.yml up -d #ca.example.com orderer.example.com peer0.org1.example.com couchdb

# wait for Hyperledger Fabric to start
export FABRIC_START_TIMEOUT=10
sleep ${FABRIC_START_TIMEOUT}

# Create the channel
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org1.example.com/msp" peer0.org1.example.com peer channel create -o orderer.example.com:7050 -c mychannel -f /etc/hyperledger/configtx/channel.tx
# Join peer0.org1.example.com to the channel.
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org1.example.com/msp" peer0.org1.example.com peer channel join -b mychannel.block


# Now launch the CLI container in order to install, instantiate chaincode
# and prime the ledger with our 10 cars
# docker-compose -f ./docker-compose.yml up -d cli

docker cp ../chaincode/src/ cli:/opt/gopath/src/github.com/securitization

echo "init/install chaincode"
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode install -n securitization -v 1.0 -p github.com/securitization
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode instantiate -o orderer.example.com:7050 -C mychannel -n securitization -v 1.0 -c '{"Args":["101"]}' #-P "OR ('Org1MSP.member','Org2MSP.member')"
echo "chaincode initialized"
sleep 10
echo "test chaincode"
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n securitization -c '{"Args":["read_everything"]}'
