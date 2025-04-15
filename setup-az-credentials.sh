#!/bin/bash

if [ -z "$SUBSCRIPTION_ID" ]; then
  read -p "Enter your Azure Subscription ID: " SUBSCRIPTION_ID
fi

if [ -z "$RESOURCE_GROUP" ]; then
  read -p "Enter Resource Group name (default: uppound-resources): " RESOURCE_GROUP
  RESOURCE_GROUP=${RESOURCE_GROUP:-uppound-resources}
fi

if [ -z "$SP_NAME" ]; then
  read -p "Enter Service Principal name (default: upbound-platform-admin): " SP_NAME
  SP_NAME=${SP_NAME:-upbound-platform-admin}
fi

if [ -z "$LOCATION" ]; then
  read -p "Enter Azure Region (default: eastus): " LOCATION
  LOCATION=${LOCATION:-eastus}
fi

echo "# Checking Azure login #"
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Please login to Azure..."
  az login
fi

echo "# Setting subscription to $SUBSCRIPTION_ID #"
az account set --subscription "$SUBSCRIPTION_ID"

echo "# Ensuring resource group exists #"
az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creating resource group $RESOURCE_GROUP in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
fi

echo "# Creating service principal $SP_NAME #"
SP_OUTPUT=$(az ad sp create-for-rbac --name "$SP_NAME" --role "Contributor" --scopes "/subscriptions/$SUBSCRIPTION_ID" --sdk-auth)
CLIENT_ID=$(echo $SP_OUTPUT | jq -r .clientId)
CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r .clientSecret)
TENANT_ID=$(echo $SP_OUTPUT | jq -r .tenantId)

echo "# Saving credentials to azure-creds.json #"
echo $SP_OUTPUT > azure-creds.json

echo "# Assigning additional roles to service principal #"
roles=(
  "Network Contributor" 
  "AcrPush"
  "AcrPull"
  "Azure Kubernetes Service Cluster Admin Role"
  "Storage Blob Data Contributor"
)

for role in "${roles[@]}"; do
  echo "Adding role: $role"
  az role assignment create \
    --assignee "$CLIENT_ID" \
    --role "$role" \
    --subscription "$SUBSCRIPTION_ID"
done

echo "# Creating Kubernetes secret with Azure credentials #"
kubectl delete secret azure-creds --namespace default || true
kubectl create secret generic azure-creds \
  --namespace default \
  --from-file=creds=./azure-creds.json

echo "# Creating Azure provider config #"
cat <<EOF > azure-provider-config.yaml
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: example
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: default
      name: azure-creds
      key: creds
EOF
kubectl apply -f azure-provider-config.yaml

echo "# Setup complete #"
