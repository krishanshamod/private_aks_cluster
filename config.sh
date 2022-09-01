#!/bin/bash

# Add service principal credentials to the env variables
echo ARM_CLIENT_ID: 
read ARM_CLIENT_ID
ARM_CLIENT_ID=$ARM_CLIENT_ID

echo ARM_CLIENT_SECRET: 
read ARM_CLIENT_SECRET
ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET

echo ARM_SUBSCRIPTION_ID: 
read ARM_SUBSCRIPTION_ID
ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID

echo ARM_TENANT_ID: 
read ARM_TENANT_ID
ARM_TENANT_ID=$ARM_TENANT_ID


# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# echo Azure CLI Version
# az version


# Install Kubernetes CLI
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl

chmod +x ./kubectl

sudo mv ./kubectl /usr/local/bin/kubectl

# echo Kubectl Version
# kubectl version --client


# Enable bash autocompletion for kubectl
source <(kubectl completion bash)


# Login to Azure using service principal
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

# echo Azure account details
# az account show


# Get Kubernetes cluster config
az aks get-credentials --name aks-my-cluster \
    --resource-group rg-private-aks \
    --subscription $ARM_SUBSCRIPTION_ID \
    --admin

# echo Kubernetes Cluster Nodes
# kubectl get nodes


# Install Helm 3
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

# echo Helm Version
# helm version


# Install Traefik ingress controller 
helm repo add traefik https://helm.traefik.io/traefik

helm repo update

helm install traefik traefik/traefik

kubectl create ns traefik-v2

helm install --namespace=traefik-v2 traefik traefik/traefik

echo Traefik ingress controller service
kubectl get svc