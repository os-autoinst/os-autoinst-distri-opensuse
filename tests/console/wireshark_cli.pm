# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wireshark
# Summary: Wireshark cli test
# Maintainer: QE Core <qe-core@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use version_utils 'is_sle';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use network_utils 'iface';

sub run {
    my $iface = iface();
    
    select_serial_terminal();
    zypper_call('in wireshark') if (script_run('rpm -q wireshark'));

    record_info("List interfaces", script_output('tshark -D'));
    script_run("tshark -i $iface -w /tmp/capture.pcap -c 5 > /tmp/tshark.log 2>&1 & echo \$! > /tmp/tshark.pid");
    #script_run("tshark -i $iface -Y 'dns.qry.name==\"www.suse.com\"' -w /tmp/capture.pcap -c 3 > /tmp/tshark.log 2>&1 & echo \$! > /tmp/tshark.pid");
    
    assert_script_run('dig www.suse.com A');
    assert_script_run('host www.suse.com');
    
    script_run('wait $(cat /tmp/tshark.pid) || true');
    record_info("debug -r", script_run('tshark -r /tmp/capture.pcap'));
    record_info("debug -r -Y", script_run('tshark -r /tmp/capture.pcap -Y dns'));
    assert_script_run('test -s /tmp/capture.pcap');
    my $output = script_output(q{tshark -r /tmp/capture.pcap -Y 'dns and dns.qry.name=="www.suse.com"'});
    record_info('output', $output);
}

1;
