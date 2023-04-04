param (
  [string]
  $location = "westeurope",
  [string] 
  $templateFile = ".\agwAksDiffVnets\main.bicep",
  [string]
  $parameterFile = ".\agwAksDiffVnets\parameters.json",
  [string] 
  $deploymentPrefix='vwan-azfw-agic-tlsinspect'
  )

$deploymentName="$deploymentPrefix-$(New-Guid)"

az deployment sub create -l $location -n $deploymentName --template-file $templateFile --parameters $parameterFile 