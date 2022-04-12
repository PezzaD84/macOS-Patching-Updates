#!/bin/bash
#
# Created by Perry 28/2/2022
#
# Script to update macOS
#
# $4 = API Username
# $5 = API Password
# $6 = JSS URL
#
#################################################################

# Variables

Notify=/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper

processor=$(uname -m)

min_drive_space=45

free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")  # with thanks to Pico

# Free space check

if [[ ! "$free_disk_space" ]]; then
	# fall back to df -h if the above fails
	free_disk_space=$(df -Pk . | column -t | sed 1d | awk '{print $4}')
fi

if [[ $free_disk_space -ge $min_drive_space ]]; then
	echo "OK - $free_disk_space GB free/purgeable disk space detected"
else
	echo "ERROR - $free_disk_space GB free/purgeable disk space detected"
	exit 1
fi

# Run software update

if [[ $processor == arm64 ]]; then
	echo "Mac is M1"
   
	open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane/ --hide
   
	sleep 10
	
	serial=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
	ID=$(curl -u $4:$5 -X GET "https://$6/JSSResource/computers/serialnumber/$serial" | tr '<' '\n' | grep -m 1 id | tr -d 'id>')
	curl -u $4:$5 -X POST "https://$6/JSSResource/computercommands/command/ScheduleOSUpdate/action/InstallForceRestart/id/$ID"
	
	sleep 5
	
"$Notify" \
-windowType hud \
-lockHUD \
-title "MacOS Updates" \
-heading "MacOS Updates Installing" \
-description "MacOS updates are now being installed.
This process can take 20-40min so please do not turn off your device during this time.
Once the update is downloaded and ready to install please click on Restart Now." \
-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
-button1 "Ok" \
-defaultButton 1 \
	
	open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane/
else
	echo "Mac is Intel"
	
	"$Notify" \
	-windowType hud \
	-lockHUD \
	-title "MacOS Updates" \
	-heading "MacOS Updates Installing" \
	-description "MacOS updates are now being installed.
This process can take 20-40min so please do not turn off your device during this time.
Once the update is downloaded and ready to install your device will reboot so please save any open work." \
	-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
	-button1 "Ok" \
	-defaultButton 1 \
	
	sudo softwareupdate -i -r --restart --agree-to-license
fi
