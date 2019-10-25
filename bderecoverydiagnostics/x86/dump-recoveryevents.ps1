Import-Module ".\BdeRecoveryDiagnostics.psd1"

# Enumerate all "bitlocker-events.evtx" files under 
dir -path "\\winsect\scratch\BdeDiagnostics\data" -Recurse -filter "bitlocker-events.evtx" |
    ForEach-Object {
        # Get the full path to the events file.
        $eventsPath = $_.FullName;

        # Get "keyring" events from the events file
        $events = Get-BitLockerEvents $eventsPath -KeyRing |

                  # Only look at the most recent 5 keyring events
                  select -first 5 |
              
                  # Filter out TpmSealInfo events (which are included by default from Get-BitLockerEvents).
                  where {$_.GetType().Name -ne "TpmSealInfoEvent"};
    
        # If there are any remaining events after the above filters have applied,
        # write the events path and the keyring events to the output pipeline.

        if ($events -ne $null) {
            Write-Output $eventsPath, $events | fl
        }
    }