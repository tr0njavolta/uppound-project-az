# UpPound Demo App Deployment

This repository is the code companion to the Upbound Docs Getting Started guide.
This project deploys an example pet adoption website on AWS EKS using Upbound.

## Prerequisites
- The Upbound CLI
- An Upbound Account
- An Azure account
- kubectl

## Get started

Clone this repository and run the authentication setup script:

```shell
./setup-az-credentials
```

Build and run the project:

```shell
up project build && up project run
```


Move the project to your Upbound account:

```shell
up project move ${yourUpboundaccount}/up-pound-project
```


Deploy your resources:

```shell
kubectl apply -f examples/xapp/example.yaml
```
