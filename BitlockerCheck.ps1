try {
    $BLinfo = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop

    if ($BLinfo.VolumeStatus -eq 'FullyEncrypted' -and $BLinfo.EncryptionMethod -eq 'XtsAes128') {
        # Recupera tutti i protector
        $KeyProtectors = $BLinfo.KeyProtector

        # Cerca ogni tipo di protector
        $RecoveryProtector = $KeyProtectors | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
        $TPMProtector      = $KeyProtectors | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
        $PasswordProtector = $KeyProtectors | Where-Object { $_.KeyProtectorType -eq 'Password' }

        # Output informazioni sui protector trovati
        if ($TPMProtector) {
            Write-Output "Protector TPM trovato: $($TPMProtector.KeyProtectorId)"
        } else {
            Write-Output "Nessun protector TPM trovato."
        }

        if ($PasswordProtector) {
            Write-Output "Protector Password trovato: $($PasswordProtector.KeyProtectorId)"
        } else {
            Write-Output "Nessun protector Password trovato."
        }

        if (-not $RecoveryProtector) {
            Write-Output "Encryption Method 128bit ma nessun RecoveryPassword trovato."
            exit 1
        }

        # Verifica backup su AAD per il protector RecoveryPassword
        $BLprotectorguid = $RecoveryProtector.KeyProtectorId

        $BLBackupEvent = Get-WinEvent -ProviderName Microsoft-Windows-BitLocker-API `
            -FilterXPath "*[System[(EventID=845)] and EventData[Data[@Name='ProtectorGUID'] and (Data='$BLprotectorguid')]]" `
            -MaxEvents 1 -ErrorAction Stop

        if ($BLBackupEvent) {
            Write-Output "Evento di backup RecoveryPassword trovato:"
            Write-Output $BLBackupEvent.Message
            exit 0
        } else {
            Write-Output "RecoveryPassword trovata ma evento di backup su AAD non presente."
            exit 1
        }
    }
    else {
        Write-Output "Il disco non è completamente criptato con XtsAes128."
        
        # Check TPM status
        try {
            $tpm = Get-Tpm -ErrorAction Stop
            Write-Output "Stato TPM:"
            Write-Output "  TPM presente: $($tpm.TpmPresent)"
            Write-Output "  TPM abilitato: $($tpm.TpmEnabled)"
            Write-Output "  TPM attivo: $($tpm.TpmActivated)"
            Write-Output "  TPM pronto per l'uso: $($tpm.TpmReady)"
        }
        catch {
            Write-Output "Errore nel recupero dello stato TPM: $($_.Exception.Message)"
        }

        exit 1
    }
}
catch {
    Write-Output "Errore: $($_.Exception.Message)"
    exit 1
}
