#!/bin/sh
# emulate $LTPROOT/testscripts/network.sh

load_tst_net()
{
	export TCID="network_settings"
	export TST_ID="$TCID"

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

	# new API
	unset TST_ID TST_NO_DEFAULT_RUN
	# legacy API
	unset TCID TST_TOTAL TST_LIB_LOADED

	return $ret
}

load_tst_net
