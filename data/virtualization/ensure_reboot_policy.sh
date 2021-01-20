#!/bin/bash
#
# Summary: Ensure the reboot policy is set to restart for a guest
#

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 GUEST"
	exit 1
fi

DOMAIN="$1"
XML="${DOMAIN}.xml"
POLICY="restart"

function cleanup() {
	set +e
	rm -f "$XML"
}
trap cleanup EXIT
set -e

virsh dumpxml "$DOMAIN" > $XML
sed 's!.*<on_reboot>.*</on_reboot>!<on_reboot>'"$POLICY"'</on_reboot>!' -i "$XML"
virsh define "$XML"

# Ensure the setting is applied
# Note: Running guests will not apply this directly but after the next reboot
if ! virsh list | grep "$DOMAIN"; then
	# Test only if guest is not running
	virsh dumpxml "$DOMAIN" | grep -e '.*<on_reboot>'"$POLICY"'</on_reboot>' > /dev/null
fi

# All good
echo "OK: $DOMAIN - on_reboot = $POLICY"
