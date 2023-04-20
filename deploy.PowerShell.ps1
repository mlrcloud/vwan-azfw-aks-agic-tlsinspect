param (
  [string]
  $location = "westeurope",
  [string] 
  $templateFile = ".\agwAksDiffVnets\main.bicep",
  [string]
  $parameterFile = ".\agwAksDiffVnets\parameters.json",
  [string] 
  $deploymentPrefix='vwan-azfw-agw-tlsinspect'
  )

$deploymentName="$deploymentPrefix-$(New-Guid)"

New-AzDeployment -Name $deploymentName `
                -Location $location `
                -TemplateFile $templateFile `
                -TemplateParameterFile  $parameterFile `
                -Verbose

