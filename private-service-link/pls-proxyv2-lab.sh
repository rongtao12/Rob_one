#!/bin/bash

# Generate a 5-character random string as suffix
SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 7 | head -n 1)

# Variables
RESOURCE_GROUP="rg-$SUFFIX"
LOCATION="westus2"
VNET_NAME="vnet-$SUFFIX"
VNET_CLIENT_NAME="vnet-client-$SUFFIX"
SUBNET_NAME="subnet-$SUFFIX"
SUBNET_CLIENT_NAME="subnet-client"
SUBNET_CLIENT_PE_NAME="subnet-client_pe"
SUBNET_CLIENT_BASTION_NAME="Azure Bastion"
LB_NAME="lb-$SUFFIX"
PLS_NAME="pls-$SUFFIX"
VM_NAME="vm-$SUFFIX"
NIC_NAME="nic-$SUFFIX"
NIC_CLIENT_NAME="nic-client-$SUFFIX"
VM_CLIENT_NAME="vm-client-$SUFFIX"
NIC_CLIENT_NAME="nic-client-$SUFFIX"
FRONTEND_IP_NAME="lb-frontend-ip-$SUFFIX"
BACKEND_POOL_NAME="lb-backend-pool-$SUFFIX"
PROBE_NAME="lb-probe-$SUFFIX"
RULE_NAME="lb-rule-$SUFFIX"
BASTION_NAME="bastion-$SUFFIX"
PUBLIC_IP_BASTION_NAME="pip-bastion-$SUFFIX"
PUBLIC_IP_NAME="pip--$SUFFIX"
PE_NAME='pe-$SUFFIX'

# Create resource group
echo -e "\e[31mStart to create resource gorup\e[0m"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo -e "\e[31mStart to create server VNET subnet\e[0m"
# Create virtual network and subnet
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefixes 192.168.0.0/16 \
  --subnet-name $SUBNET_NAME \
  --subnet-prefixes 192.168.1.0/24

az network vnet subnet update \
    --name $SUBNET_NAME \
    --vnet-name $VNET_NAME \
    --resource-group $RESOURCE_GROUP \
    --disable-private-link-service-network-policies true

echo -e "\e[31mStart to create server side load balancer \e[0m"
# Create internal standard load balancer
az network lb create \
  --resource-group $RESOURCE_GROUP \
  --name $LB_NAME \
  --sku Standard \
  --frontend-ip-name $FRONTEND_IP_NAME \
  --backend-pool-name $BACKEND_POOL_NAME \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --private-ip-address 192.168.1.10

# Create health probe
az network lb probe create \
  --resource-group $RESOURCE_GROUP \
  --lb-name $LB_NAME \
  --name $PROBE_NAME \
  --protocol Tcp \
  --port 80

# Create load balancing rule
az network lb rule create \
  --resource-group $RESOURCE_GROUP \
  --lb-name $LB_NAME \
  --name $RULE_NAME \
  --protocol Tcp \
  --frontend-ip-name $FRONTEND_IP_NAME \
  --frontend-port 80 \
  --backend-pool-name $BACKEND_POOL_NAME \
  --backend-port 80 \
  --probe-name $PROBE_NAME

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
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --lb-name $LB_NAME \
  --lb-address-pools $BACKEND_POOL_NAME \
  --public-ip-address $PUBLIC_IP_NAME

echo -e "\e[31mStart to create server side  VM\e[0m"
# Create Ubuntu 20.04 VM in the backend pool
# image refers from :https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-cli
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --nics $NIC_NAME \
  --image Canonical:ubuntu-24_04-lts:server:latest   \
  --admin-username "admin1234" \
  --admin-password "QWEasdzxc#1234" \
  --authentication-type password 
 
echo -e "\e[31mStart to install server nginx script\e[0m"
# Install Nginx and configure it to use PROXY Protocol
az vm run-command invoke \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --command-id RunShellScript \
  --scripts "
#!/bin/bash

wget https://raw.githubusercontent.com/rongtao12/Rob_one/refs/heads/main/private-service-link/nginx-startup.sh
sleep 10

sudo sh nginx-startup.sh
sleep 60
"

echo -e "\e[31mStart to create client vnet , subnet\e[0m"
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

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_CLIENT_NAME \
  --name $SUBNET_CLIENT_PE_NAME  \
  --address-prefix 10.0.2.0/24


echo -e "\e[31mStart to create vnet peerings\e[0m"
# Add VNet peering from client VNet to backend VNet
az network vnet peering create \
  --name "peering-client-to-backend-$SUFFIX" \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_CLIENT_NAME \
  --remote-vnet $VNET_NAME \
  --allow-vnet-access

# Add VNet peering from backend VNet to client VNet
az network vnet peering create \
  --name "peering-backend-to-client-$SUFFIX" \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --remote-vnet $VNET_CLIENT_NAME \
  --allow-vnet-access



echo -e "\e[31mStart to create Private-link-service\e[0m"
# Create Private Link Service with proxy protocol enabled
az network private-link-service create \
  --name $PLS_NAME \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --lb-name $LB_NAME \
  --lb-frontend-ip-configs $FRONTEND_IP_NAME \
  --location $LOCATION \
  --enable-proxy-protocol true


# Create Private Endpoint in client VNET
PRIVATE_LINK_SERVICE_ID=$(az network private-link-service show \
  --name $PLS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "id" \
  --output tsv )


PRIVATE_LINK_SERVICE_ID="${PRIVATE_LINK_SERVICE_ID/$'\r'/}"

echo -e "\e[31mStart to create Private endpoint \e[0m"
az network private-endpoint create \
  --name $PE_NAME \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_CLIENT_NAME \
  --subnet $SUBNET_CLIENT_PE_NAME \
  --manual-request false  \
  --private-connection-resource-id $PRIVATE_LINK_SERVICE_ID \
  --connection-name "pe-connection-$SUFFIX" 

NIC_ID=$(az network private-endpoint show \
  --name $PE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "networkInterfaces[0].id" -o tsv)

PE_PRIVATE_IP=$(az network nic show \
  --ids $NIC_ID \
  --query "ipConfigurations[0].privateIpAddress" -o tsv)

echo -e "\e[31mStart to create clinet VM \e[0m"
# Create network interface and associate it with the backend pool and public IP address
az network nic create \
  --resource-group $RESOURCE_GROUP \
  --name $NIC_CLIENT_NAME \
  --vnet-name $VNET_CLIENT_NAME \
  --subnet $SUBNET_CLIENT_NAME 


# Create Ubuntu 20.04 VM in the backend pool
# image refers from :https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-cli
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_CLIENT_NAME \
  --nics $NIC_CLIENT_NAME \
  --image Canonical:ubuntu-24_04-lts:server:latest   \
  --admin-username "admin1234" \
  --admin-password "QWEasdzxc#1234" \
  --authentication-type password 

echo -e "\e[31mStart to init client test scripts \e[0m"
# Run a script on the client VM to perform a curl request to the Private Endpoint
az vm run-command invoke \
  --resource-group $RESOURCE_GROUP \
  --name $VM_CLIENT_NAME \
  --command-id RunShellScript \
  --scripts "
#!/bin/bash
while true; do
  curl http://$PE_PRIVATE_IP:80
  sleep 5
done
"

echo -e "\e[31mStart to create bastion public IP and Bastion \e[0m"
# Create a public IP address
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_BASTION_NAME \
  --allocation-method Static \
  --sku Standard

# https://learn.microsoft.com/en-us/cli/azure/network/bastion?view=azure-cli-latest#az-network-bastion-create
# Create Azure Bastion
az network bastion create \
  --name $BASTION_NAME \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_CLIENT_NAME \
  --public-ip-address $PUBLIC_IP_BASTION_NAME \
  --sku Basic \ 
  --location $LOCATION


echo -e "\e[31mDeployment completed. \e[0m"
echo -e "\e[31mDestination private ip: $PE_PRIVATE_IP \e[0m"

