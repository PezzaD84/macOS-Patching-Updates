# macOS Patching | Updates

Bash script for managing monthly security and feature updates on Intel and M1 macs. This script has a 4 day deferal options like the original larger macOS patching script. This script is designed to be be triggered off monthly or weekly in Jamf without casuing to much disruption for the end users.

Updates are triggered by the local softwareupdate command on M1 and Intel macs. If the device is M1 then additional checks are made to see if the user is Admin and has a secure token. The user is elevated to Admin if they are a standard user and then demoted to standard once the updates are installed.

Updates and new features are listed in the change log.

