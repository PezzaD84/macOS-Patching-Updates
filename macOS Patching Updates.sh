#!/bin/bash
#
# Created by Perry 28/2/2022
#
# Script to update macOS
#
# $4 = JSS URL
# $5 = Encrypted API creds
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

# Deferment notification

day1=/var/tmp/postponed.txt
day2=/var/tmp/postponed2.txt
day3=/var/tmp/postponed3.txt
day4=/var/tmp/postponed4.txt

deferment(){
message=$("$Notify" \
-windowType hud \
-lockHUD \
-title "MacOS Updates" \
-heading "MacOS Updates Available" \
-description "MacOS updates are available to install.
This process can take 20-40min so please do not turn off your device during this time.
Your device will reboot by itself once completed." \
-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
-button1 "Install now" \
-button2 "Postpone" \
-defaultButton 1 \
)

if [[ $message == 0 ]]; then
	echo "User agreed to install macOS updates"
	rm $day1
	rm $day2
	rm $day3
	rm $day4
elif [[ ! -f $day1 ]]; then
	echo "User postponed the macOS updates 1st Day" > $day1
	echo "User postponed the macOS updates 1st Day"
	exit 0
elif [[ -f $day1 ]] && [[ ! -f $day2 ]]; then
	echo "User postponed the macOS updates 2nd Day" > $day2
	echo "User postponed the macOS updates 2nd Day"
	exit 0
elif [[ -f $day1 ]] && [[ -f $day2 ]] && [[ ! -f $day3 ]]; then
	echo "User postponed the macOS updates 3rd Day" > $day3
	echo "User postponed the macOS updates 3rd Day"
	exit 0
elif [[ -f $day1 ]] && [[ -f $day2 ]] && [[ -f $day3 ]] && [[ ! -f $day4 ]]; then
	echo "User postponed the macOS updates 4th Day" > $day4
	echo "User postponed the macOS updates 4th Day"
	exit 0
elif [[ -f $day4 ]]; then

message=$("$Notify" \
-windowType hud \
-lockHUD \
-title "MacOS Updates" \
-heading "MacOS Updates Available" \
-description "Update postponement has passed 4 days.
Your device will now be updated.

This process can take 20-40min so please do not turn off your device during this time.
Your device will reboot by itself once completed." \
-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
-button1 "Install now" \
-defaultButton 1 \
)
	rm $day1
	rm $day2
	rm $day3
	rm $day4
fi
}

deferment

# Run software update

if [[ $processor == arm64 ]]; then
	echo "Mac is M1"
   
	open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane/ --hide
	sudo launchctl kickstart -k system/com.apple.softwareupdated
   
	sleep 10
	
	# API Credentials
	encryptedcreds="$5"

	token=$(curl -s -H "Content-Type: application/json" -H "Authorization: Basic ${encryptedcreds}" -X POST "$4/api/v1/auth/token" | grep 'token' | tr -d '"',',' | sed -e 's#token :##' | xargs)
	serial=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
	ID=$(curl -X GET "$4/JSSResource/computers/serialnumber/$serial" -H "Accept: application/xml" -H "Authorization:Bearer ${token}" | tr '<' '\n' | grep -m 1 id | tr -d 'id>')
	curl -X POST "$4/JSSResource/computercommands/command/ScheduleOSUpdate/action/InstallForceRestart/id/$ID" -H "Accept: application/json" -H "Authorization:Bearer ${token}"
	
	sleep 5
	
SUPending=$(log show --predicate '(subsystem == "com.apple.SoftwareUpdateMacController") && (eventMessage CONTAINS[c] "reported progress (end): phase:PREPARED")' | grep phase:PREPARED)
	
	while [[ $SUPending == '' ]]; do
		echo "Updates downloading....."
		
		SUPending=$(log show --predicate '(subsystem == "com.apple.SoftwareUpdateMacController") && (eventMessage CONTAINS[c] "reported progress (end): phase:PREPARED")' | grep phase:PREPARED)
		sleep 20
	done
	
	echo "Pending Updates require a reboot"
	"$Notify" \
	-windowType hud \
	-lockHUD \
	-title "MacOS Updates" \
	-heading "MacOS Updates Pending" \
	-description "MacOS updates are pending a reboot.
This process can take 20-40min so please save your work and then click on Ok." \
	-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
	-button1 "Ok" \
	-defaultButton 1
	
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
