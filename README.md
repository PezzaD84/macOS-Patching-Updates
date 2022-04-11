# macOS Patching | Updates

Bash script for managing monthly security and feature updates on Intel and M1 macs. This script has no deferal options like the original larger macOS patching script. This script is designed to be be triggered off monthly or weekly in Jamf without casuing to much disruption for the end users.

# Intel mac patching

The intel mac patching is triggered using the built in softwareupdates command and installs all the latest recommended and important updates and then triggers an automatic reboot if needed.

# M1 mac Patching

M1 devices are triggered using the Jamf API. In Jamf you will need to specify the following variables for your instance.

$4 = API Username

$5 = API Password

$6 = JSS URL

(The script will be updated for the modern API later)

The script will trigger the ScheduleOSUpdate MDM command. The user will be prompted to reboot their device once the updates have been downloaded and are ready to install.

