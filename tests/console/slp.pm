# SUSE's openSLP regression test
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test functionality of the openSLP package
#  * Install the openslp and openslp-server package
#  * Enable, start and inspect the systemd unit
#  * List available srvtypes, look for SSH
#  * Discover SSH announced services
#  * Register two NTP services
#  * Deregister one service
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils qw(zypper_call systemctl);
use Utils::Systemd 'disable_and_stop_service';

sub run {
    my ($self) = @_;
    select_console 'root-console';

    zypper_call 'in openslp openslp-server';

    disable_and_stop_service($self->firewall);

    systemctl 'enable slpd';
    systemctl 'start slpd';
    systemctl 'status slpd';

    # Show the version
    assert_script_run 'slptool -v';

    # List all available services
    assert_script_run 'slptool findsrvtypes | grep -A99 -B99 "service:ssh"';
    assert_script_run 'slptool -s DEFAULT findsrvtypes | grep -A99 -B99 "service:ssh"';

    # Find all visible SSH services
    assert_script_run 'slptool findsrvs ssh | grep -A99 -B99 "ssh://\|:22,"';
    assert_script_run 'slptool -p findsrvs ssh | grep -A99 -B99 "ssh://\|:22,"';
    assert_script_run 'slptool findsrvs service:ssh | grep -A99 -B99 "ssh://\|:22,"';

    # Display attributes of the SSH service
    assert_script_run 'slptool findattrs ssh | grep -A99 -B99 "Secure Shell Daemon"';

    # Register and find two NTP services
    assert_script_run 'slptool register ntp://tik.cesnet.cz:123,en,65535';
    assert_script_run 'slptool register ntp://tak.cesnet.cz:123,en,65535';
    assert_script_run 'if [[ $(slptool findsrvs ntp | grep "tik\|tak" | wc -l) = "2" ]]; then echo "Both NTP announcements were found"; else false; fi';

    # Deregister one NTP service and find the other one
    assert_script_run 'slptool deregister ntp://tik.cesnet.cz:123,en,65535';
    assert_script_run 'if [[ $(slptool findsrvs ntp | grep "tik\|tak" | wc -l) = "1" ]]; then echo "One remaining NTP announcement was found"; else false; fi';
}

1;

