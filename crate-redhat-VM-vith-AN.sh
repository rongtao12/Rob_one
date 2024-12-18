#!/bin/bash
# Date : 2024-12-18
# One Redhat VM wit accelerate network 
# Attach azure bastion for login

# Generate a 5-character random string as suffix
SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 7 | head -n 1)

# Variables
RESOURCE_GROUP="rg-$SUFFIX"
LOCATION="westus2"
NIC_NAME="nic-$SUFFIX"
VNET_CLIENT_NAME="vnet-client-$SUFFIX"
SUBNET_CLIENT_NAME="subnet-client"
BASTION_NAME="bastion-$SUFFIX"
PUBLIC_IP_BASTION_NAME="pip-bastion-$SUFFIX"
PUBLIC_IP_NAME="pip--$SUFFIX"

# Create resource group
echo -e "\e[31mStart to create resource gorup : $RESOURCE_GROUP\e[0m"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo -e "\e[31mStart to create VNET subnet\e[0m"
# Create virtual network and subnet
# Can only create on subnet
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_CLIENT_NAME \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name $SUBNET_CLIENT_NAME \
  --subnet-prefixes 10.0.1.0/24 


az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_CLIENT_NAME \
  --name AzureBastionSubnet \
  --address-prefix 10.0.3.0/24

echo -e "\e[31mStart to create server side public IP, nic \e[0m"
# Create a public IP address
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --allocation-method Static \
  --sku Standard

# Create network interface and associate it with the backend pool and public IP address
az network nic create \
  --resource-group $RESOURCE_GROUP \
  --name $NIC_NAME \
  --vnet-name $VNET_CLIENT_NAME \
  --subnet $SUBNET_CLIENT_NAME \
  --accelerated-networking true \
  --public-ip-address $PUBLIC_IP_NAME


echo -e "\e[31mStart to create Redhat VM\e[0m"
# Create Ubuntu 20.04 VM in the backend pool
# image refers from :https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-cli
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_CLIENT_NAME \
  --nics $NIC_NAME \
  --image RedHat:RHEL:8-lvm-gen2:latest   \
  --size Standard_B2ts_v2  \
  --admin-username "admin1234" \
  --admin-password "QWEasdzxc#1234" \
  --authentication-type password 


 echo -e "\e[31mStart to create public IP\e[0m"
# Create a public IP address
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_BASTION_NAME \
  --allocation-method Static \
  --sku Standard

# https://learn.microsoft.com/en-us/cli/azure/network/bastion?view=azure-cli-latest#az-network-bastion-create
# Create Azure Bastion
echo -e "\e[31mStart to create Bastion\e[0m"
az network bastion create \
  --name $BASTION_NAME \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_CLIENT_NAME \
  --public-ip-address $PUBLIC_IP_BASTION_NAME \
  --sku Basic 

 echo -e "\e[31mComplete all the stuff\e[0m"
