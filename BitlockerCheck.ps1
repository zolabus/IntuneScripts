try {
    $BLinfo = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop

    if ($BLinfo.VolumeStatus -eq 'FullyEncrypted' -and $BLinfo.EncryptionMethod -eq 'XtsAes128') {
        # Cerca il RecoveryPassword protector
        $BLRecoveryProtector = $BLinfo.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

        if ($BLRecoveryProtector -eq $null) {
            Write-Output "Encryption Method 128bit ma nessun RecoveryPassword trovato."
            exit 1
        }

        $BLprotectorguid = $BLRecoveryProtector.KeyProtectorId

        # Controlla l’evento di backup su AAD
        $BLBackupEvent = Get-WinEvent -ProviderName Microsoft-Windows-BitLocker-API `
            -FilterXPath "*[System[(EventID=845)] and EventData[Data[@Name='ProtectorGUID'] and (Data='$BLprotectorguid')]]" `
            -MaxEvents 1 -ErrorAction Stop

        if ($BLBackupEvent) {
            Write-Output "Evento di backup trovato:"
            Write-Output $BLBackupEvent.Message
            exit 0
        }
        else {
            Write-Output "Evento di backup della chiave BitLocker non trovato su AAD."
            exit 1
        }
    }
    else {
        Write-Output "Il disco non è completamente criptato con XtsAes128."
        exit 1
    }
}
catch {
    Write-Output "Errore: $($_.Exception.Message)"
    exit 1
}
