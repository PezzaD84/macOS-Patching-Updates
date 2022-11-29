#!/bin/bash
#
# Created by Perry 28/2/2022
#
# Script to update macOS
#
#################################################################

##############################################################
# Variables
##############################################################

Notify=/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper

processor=$(uname -m)

CURRENT_USER=$(ls -l /dev/console | awk '{ print $3 }')

min_drive_space=10

free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")  # with thanks to Pico

elevate(){
	# Check user has Securetoken
	token=$(sudo dscl . -read /Users/$CURRENT_USER AuthenticationAuthority | grep -o 'SecureToken')
	
	if [[ $token == SecureToken ]]; then
		echo "$CURRENT_USER has a secure token. Continuing to elevate user."
	else
		echo "$CURRENT_USER does not have a secure token. A local admin will be needed to run upgrades."
	fi
	
	# Elevate user account
	dscl . -append /groups/admin GroupMembership $CURRENT_USER
	
}

##############################################################
# Free space check
##############################################################

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

##############################################################
# Deferment notification
##############################################################

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
This process can take 20-60min so please do not turn off your device during this time.
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

This process can take 20-60min so please do not turn off your device during this time.
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

##############################################################
# Check Battery state
##############################################################

bat=$(pmset -g batt | grep 'AC Power')

model=$(ioreg -l | awk '/product-name/ { split($0, line, "\""); printf("%s\n", line[4]); }')

if [[ "$model" = *"Book"* ]]; then
	until [[ $bat == "Now drawing from 'AC Power'" ]]; do
	
	echo "Device not connected to power source"
	
	"$Notify" \
		-windowType hud \
		-lockHUD \
		-title "MacOS Updates" \
		-heading "Connect Charger" \
		-description "Please connect your device to a charger to continue installing updates." \
		-icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns \
		-button1 "Continue" \
		-defaultButton 1 \
	
		bat=$(pmset -g batt | grep 'AC Power')
		sleep 2
	done
fi

echo "Device connected to power source"

##############################################################
# Run software update
##############################################################

if [[ $processor == arm64 ]]; then
	echo "Mac is M1"
	launchctl kickstart -k system/com.apple.softwareupdated
	
	if dscl . read /Groups/admin | grep $CURRENT_USER; then
		echo "$CURRENT_USER is admin. Checking Secure Token status....."
		
		token=$(sudo dscl . -read /Users/$CURRENT_USER AuthenticationAuthority | grep -o 'SecureToken')
		if [[ $token == SecureToken ]]; then
			echo "$CURRENT_USER has a secure token. Continuing updates....."
		else
			echo "$CURRENT_USER does not have a secure token. A local admin will be needed to run upgrades."
			"$Notify" \
			-windowType hud \
			-lockHUD \
			-title "MacOS Updates" \
			-heading "MacOS Update Error" \
			-description "MacOS Updates cannot be installed.
The user account does not have a secure token. Please contact your administrator." \
			-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
			-button1 "Ok" \
			-defaultButton 1 \
			exit 1
		fi
	else
		echo "$CURRENT_USER is not admin"
		elevate
		
		# Create plist to remove admin at next login
		
		# Create directory and removal script 
		
		mkdir -p /Library/.TRAMS/Scripts/
		
		cat << EOF > /Library/.TRAMS/Scripts/RemoveAdmin.sh
#!/bin/bash

dseditgroup -o edit -d $user -t user admin
EOF
		
		chown root:wheel /Library/.TRAMS/Scripts/RemoveAdmin.sh
		chmod 755 /Library/.TRAMS/Scripts/RemoveAdmin.sh
		
		# Create plist to remove admin at next login
		
		cat << EOF > /Library/LaunchDaemons/com.Trams.adminremove.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.Trams.adminremove</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Library/.TRAMS/Scripts/RemoveAdmin.sh</string>
	</array>
	<key>RunAtLoad</key> 
	<true/>
</dict>
</plist>
EOF
		
		# Permission plist
		chown root:wheel /Library/LaunchDaemons/com.Trams.adminremove.plist
		chmod 644 /Library/LaunchDaemons/com.Trams.adminremove.plist
		
		# Check secure token status
		
		token=$(sudo dscl . -read /Users/$CURRENT_USER AuthenticationAuthority | grep -o 'SecureToken')
		if [[ $token == SecureToken ]]; then
			echo "$CURRENT_USER has a secure token. Continuing updates....."
		else
			echo "$CURRENT_USER does not have a secure token. A local admin will be needed to run upgrades."
			"$Notify" \
			-windowType hud \
			-lockHUD \
			-title "MacOS Updates" \
			-heading "MacOS Update Error" \
			-description "MacOS Updates cannot be installed.
The user account does not have a secure token. Please contact your administrator." \
			-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
			-button1 "Ok" \
			-defaultButton 1 \
			exit 1
		fi
	fi
    
# Get Password for updates

	adminPswd=$(osascript -e 'Tell application "System Events" to display dialog "To install the available macOS updates please enter your password" buttons {"Continue"} default button 1 with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
	
    pswdCheck=$(dscl /Local/Default -authonly $CURRENT_USER $adminPswd)
		
		until [[ $pswdCheck == "" ]]
		do
			echo "Password was incorrect"
	adminPswd=$(osascript -e 'Tell application "System Events" to display dialog "Password is incorrect. Please try again." buttons {"Continue"} default button 1 with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
			
			pswdCheck=$(dscl /Local/Default -authonly $CURRENT_USER $adminPswd)
			echo $pswdCheck
		done
		
		echo "Password Validation passed. Continuing Updates....."
    sleep 5
    
# Run Updates
    
    "$Notify" \
	-windowType hud \
	-lockHUD \
	-title "MacOS Updates" \
	-heading "MacOS Updates Installing" \
	-description "MacOS updates are now being installed.
This process can take 20-60min so please do not turn off your device during this time.
Once the update is downloaded and ready to install your device will reboot so please save any open work." \
	-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns &
	
	expect -c "
		set timeout -1
		spawn softwareupdate --install --all --restart --force --no-scan --agree-to-license
		expect \"Password:\"
		send {${adminPswd}}
		send \r
		expect eof
		wait
		"
else
	echo "Mac is Intel"
	
	"$Notify" \
	-windowType hud \
	-lockHUD \
	-title "MacOS Updates" \
	-heading "MacOS Updates Installing" \
	-description "MacOS updates are now being installed.
This process can take 20-60min so please do not turn off your device during this time.
Once the update is downloaded and ready to install your device will reboot so please save any open work." \
	-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns &
	
	softwareupdate --install --all --agree-to-license --restart --force
fi
