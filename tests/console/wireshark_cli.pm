# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wireshark
# Summary: Basic wireshark cli test
# Maintainer: QE Core <qe-core@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use network_utils 'iface';

sub run {
    my $iface = iface();
    my $pid_file = '/tmp/tshark.pid';
    my $cap_file = '/tmp/capture.pcap';

    select_serial_terminal();
    zypper_call('in wireshark') if (script_run('rpm -q wireshark'));

    record_info("List interfaces", script_output('tshark -D'));
    script_run("tshark -i $iface -f 'udp port 53' -w $cap_file -a duration:10 > /tmp/tshark.log 2>&1 & echo \$! > $pid_file");
    script_retry("test -s $cap_file", delay => 1, retry => 2, fail_message => 'Capture file is empty');

    record_info('dig output', script_output('dig +short www.suse.com A'));
    record_info('host output', script_output('host www.suse.com'));

    assert_script_run("wait \$(cat $pid_file)");
    assert_script_run("tshark -r $cap_file -Y 'dns.qry.name==\"www.suse.com\"' | grep www.suse.com", fail_message => 'No DNS query for www.suse.com found');
    record_info('Filtered DNS', script_output("tshark -r $cap_file -Y 'dns.qry.name==\"www.suse.com\"'"));
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs('/tmp/tshark.log');
}

1;
