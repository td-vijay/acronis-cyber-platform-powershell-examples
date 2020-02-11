#**************************************************************************************************************
# Copyright © 2019-2020 Acronis International GmbH. This source code is distributed under MIT software license.
#**************************************************************************************************************

# Enum for tenants kinds
enum Kind {
  root
  partner
  folder
  customer
  unit
}

# Simple function to enable all available offering items for child (partner or customer) tenant
function Enable-AllOfferingItems {

  [CmdletBinding()]
  Param(
    [parameter(Mandatory = $true)]
    [string]
    $BaseUrl,
    [parameter(Mandatory = $true)]
    [string]
    $ParentTenantID,
    [parameter(Mandatory = $true)]
    [string]
    $TenantID,
    [parameter(Mandatory = $true)]
    [System.Collections.IDictionary]
    $AuthHeader,
    [parameter(Mandatory = $false)]
    [string]
    $Edition = "standard",
    [parameter(Mandatory = $false)]
    [Kind]
    $Kind = "customer"
  )

  $queryParameters = @{ edition = $Edition; kind = $Kind }

  # Get Offering Items Available for the child tenants
  $response = Invoke-RestMethod -Uri "${BaseUrl}api/2/tenants/${ParentTenantID}/offering_items/available_for_child" -Headers $AuthHeader -Body $queryParameters
  # Take only array offering items
  $offeringItems = $response.items

  # The next API expected to have offering_items root
  # Thus create needed JSON structure using offering_items as a root
  $json = @{ offering_items = $offeringItems } | ConvertTo-Json -Depth 100

  # Enable all offering items for the partner
  Invoke-RestMethod -Method Put -Uri "${BaseUrl}api/2/tenants/${TenantID}/offering_items" -Headers $AuthHeader -Body $json

}

# Check if the token valid at least 15 minutes
function Confirm-Token {

  [CmdletBinding()]
  Param(
  )

  # Read an token info from
  $token = Get-Content "api_token.json" | ConvertFrom-Json

  $unixTime = $token.expires_on

  $expireOnTime = Convert-FromUnixDate -UnixTime $unixTime
  $timeDifference = New-TimeSpan -End $expireOnTime

  $timeDifference.TotalMinutes -gt 15
}

function Convert-FromUnixDate {

  [CmdletBinding()]
  Param(
    [parameter(Mandatory = $true)]
    [int]
    $UnixTime
  )

  [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixTime))
}

function Update-Token {

  [CmdletBinding()]
  Param(
    [parameter(Mandatory = $true)]
    [string]
    $BaseUrl
  )

  # Read an API Client info from a file and store client_idd and client_secret in variables
  $client = Get-Content "api_client.json" | ConvertFrom-Json
  $clientId = $client.client_id
  $clientSecret = $client.client_secret

  # Manually construct Basic Authentication Header
  $pair = "${clientId}:${clientSecret}"
  $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
  $base64 = [System.Convert]::ToBase64String($bytes)
  $basicAuthValue = "Basic $base64"
  $headers = @{ "Authorization" = $basicAuthValue }

  # Use param to tell type of credentials we request
  $postParams = @{ grant_type = "client_credentials" }

  # Add the request content type to the headers
  $headers.Add("Content-Type", "application/x-www-form-urlencoded")

  $token = Invoke-RestMethod -Method Post -Uri "${BaseUrl}api/2/idp/token" -Headers $headers -Body $postParams

  # Save the Token info to file for further usage
  # YOU MUST STORE YOUR CREDENTIALS IN SECURE PLACE
  # A FILE USES FOR CODE SIMPLICITY
  # PLEASE CHECK TOKEN VALIDITY AND REFRESH IT IF NEEDED
  $token | ConvertTo-Json -Depth 100 | Out-File "api_token.json"

  $token.access_token

}