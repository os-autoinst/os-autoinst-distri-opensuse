#!/bin/sh
# emulate $LTPROOT/testscripts/network.sh

export TCID="network_settings"

if [ -f "$LTPROOT/testcases/bin/tst_net.sh" ]; then
	export TST_NO_DEFAULT_RUN=1
	file="tst_net.sh"
	echo "Using new API ($file)"
else
	export TST_TOTAL=1
	file="test_net.sh"
	echo "Using legacy API ($file)"
fi

. $file
ret=$?
echo $ret

# new API
unset TCID TST_NO_DEFAULT_RUN
# legacy API
unset TST_TOTAL TST_LIB_LOADED

exit $ret
