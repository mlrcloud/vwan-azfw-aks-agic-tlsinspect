#!/bin/bash
location='westeurope'
templateFile='./agwAksDiffVnets/main.bicep'
parameterFile='./agwAksDiffVnets/parameters.json'
deploymentPrefix='vwan-azfw-agw-tlsinspect'
deploymentName="$deploymentPrefix-$RANDOM"

az deployment sub create -l $location -n $deploymentName --template-file $templateFile --parameters $parameterFile 
