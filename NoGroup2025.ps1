# Install module if needed
# Install-Module Microsoft.Graph -Scope CurrentUser

# Connessione a Microsoft Graph
Connect-MgGraph -Scopes "Device.Read.All", "Group.Read.All", "Directory.Read.All"

# Gruppi da escludere
$excludedGroupNames = @("All Italia Devices", "All USA Devices", "All Korea Devices", "All China Devices", "All Switzerland Devices",
"All Poland Devices", "All India Devices", "All Italia Devices Dynamic", "All USA Devices Dynamic", "All Korea Devices Dynamic" ,"All Switzerland Devices Dynamic", "All Brasil devices")

# Ottieni gli ID dei gruppi da escludere
$excludedGroupIds = @()
foreach ($groupName in $excludedGroupNames) {
    $group = Get-MgGroup -Filter "displayName eq '$groupName'"
    if ($group) {
        $excludedGroupIds += $group.Id
    }
}

# Ottieni tutti i dispositivi registrati
$allDevices = Get-MgDevice -All

# Filtra dispositivi
$filteredDevices = @()
foreach ($device in $allDevices) {
    if (
        $device.OperatingSystem -like "Windows*" -and
        $device.ApproximateLastSignInDateTime -and
        $device.ApproximateLastSignInDateTime.Year -eq 2025 -and
        $device.TrustType -ne "Workplace" -and
        $device.ManagementType -eq "MDM"
    ) {
        # Verifica l'appartenenza ai gruppi esclusi
        $deviceGroupMemberships = Get-MgDeviceMemberOf -DeviceId $device.Id

        $isMemberOfExcludedGroup = $false
        foreach ($membership in $deviceGroupMemberships) {
            if ($excludedGroupIds -contains $membership.Id) {
                $isMemberOfExcludedGroup = $true
                break
            }
        }

        if (-not $isMemberOfExcludedGroup) {
            $filteredDevices += $device
        }
    }
}

# Esporta in CSV
$filteredDevices | Select-Object DisplayName, Id, DeviceId, OperatingSystem, OperatingSystemVersion, TrustType, ApproximateLastSignInDateTime, ManagementType |
    Export-Csv -Path "D:\Dispositivi_Windows_2025_Validi.csv" -NoTypeInformation -Encoding UTF8

Write-Host "CSV esportato in: Dispositivi_Windows_2025_Validi.csv"
