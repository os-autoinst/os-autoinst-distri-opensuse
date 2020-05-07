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
use utils qw(zypper_call systemctl script_retry);
use Utils::Systemd 'disable_and_stop_service';

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Let's install slpd
    zypper_call 'in openslp-server';

    disable_and_stop_service($self->firewall) if (script_run("which " . $self->firewall) == 0);

    systemctl 'disable slpd';
    systemctl 'is-enabled slpd', expect_false => 1;
    systemctl 'start slpd';
    systemctl 'status slpd';

    # Show the version
    assert_script_run 'slptool -v';
    assert_script_run 'slptool findsrvs service:service-agent | grep service-agent';
    assert_script_run 'slptool findsrvs service:ssh | grep "ssh://\|:22,"';

    # List all available services
    assert_script_run 'slptool findsrvtypes | grep -A99 -B99 "service:ssh"';
    assert_script_run 'slptool -s DEFAULT findsrvtypes | grep -A99 -B99 "service:ssh"';

    # Find all visible SSH services
    assert_script_run 'slptool findsrvs ssh | grep -A99 -B99 "ssh://\|:22,"';
    assert_script_run 'slptool -p findsrvs ssh | grep -A99 -B99 "ssh://\|:22,"';
    assert_script_run 'slptool findsrvs service:ssh | grep -A99 -B99 "ssh://\|:22,"';

    # Register sshd with custom attribute
    assert_script_run 'slptool register service:ssh://localhost "(test=really_a_test)"';
    # Display attributes of the SSH service
    assert_script_run 'slptool findattrs service:ssh://localhost | grep "(test=really_a_test)"';
    assert_script_run 'slptool findattrs service:ssh | grep "(description=Secure Shell Daemon)"';
    # Deregister ssh
    assert_script_run 'slptool deregister service:ssh://localhost';

    # Register and find two NTP services
    assert_script_run 'slptool register ntp://tik.cesnet.cz:123,en,65535';
    assert_script_run 'slptool register ntp://tak.cesnet.cz:123,en,65535';
    script_retry('slptool findsrvs ntp | grep -A9 -B9 "tik" | grep -A9 -B9 "tak"', delay => 15, retry => 5);

    # Deregister one NTP service and find the other one
    assert_script_run 'slptool deregister ntp://tik.cesnet.cz:123,en,65535';
    assert_script_run 'if [[ $(slptool findsrvs ntp | grep "tik\|tak" | wc -l) = "1" ]]; then echo "One remaining NTP announcement was found"; else false; fi';

    # Turn off slpd
    systemctl 'stop slpd';
}

sub post_fail_hook {
    my $self = shift;
    select_console('log-console');

    upload_logs '/var/log/slpd.log';
    upload_logs '/var/log/zypper.log';
    $self->save_and_upload_log('journalctl --no-pager -o short-precise', '/tmp/journal.log',            {screenshot => 1});
    $self->save_and_upload_log('rpm -ql openslp-server',                 '/tmp/openslp-server.content', {screenshot => 1});
    $self->save_and_upload_log('rpm -ql openslp',                        '/tmp/openslp.content',        {screenshot => 1});
    $self->save_and_upload_log('lsmod',                                  '/tmp/loaded_modules.txt',     {screenshot => 1});
}

1;

