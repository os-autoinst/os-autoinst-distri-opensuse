# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use strict;
use testapi;
use lockapi;
use mmapi;

sub run() {
    my $domainname  = get_var("CLUSTERNAME") . ".ha-test.qa.suse.de";
    my $host1       = "host1";
    my $host2       = "host2";
    my $cts_timeout = get_var("CTS_TIMEOUT");
    wait_for_children_to_start;
    mutex_unlock("MUTEX_HA_" . get_var("CLUSTERNAME") . "_NODE1_WAIT");    #start node1 and node2 jobs
    mutex_unlock("MUTEX_HA_" . get_var("CLUSTERNAME") . "_NODE2_WAIT");    #start node1 and node2 jobs
    assert_screen "tty1-selected";
    type_string "root\n";
    assert_screen "password-prompt";
    type_string "susetesting\n";
    #cts support server
    assert_script_run qq(sed -ie "s/^search/search $domainname/" /etc/resolv.conf);
    assert_script_run "zypper ar dvd:///?devices=/dev/sr1 sleha";
    assert_script_run "ip a";
    type_string "cat /etc/resolv.conf\n";
    assert_script_run "zypper ref";
    assert_script_run "zypper -n in pacemaker-cts";
    assert_script_run "ssh-keygen -qf /root/.ssh/id_rsa -N ''";
    for my $host ($host1, $host2) {
        type_string "for i in `seq 1 300`; do sleep 1; if ping -c 1 $host; then break; fi; done; ping -c 1 $host; echo $host-ping-\$? > /dev/$serialdev\n";
        wait_serial("$host-ping-0", 300) || die "support server cannot ping $host";
    }
    type_string "ssh-copy-id $host1\n";
    assert_screen "ha-ssh-copy-id-fingerprint";
    type_string "yes\n";
    assert_screen "ha-ssh-copy-id-password";
    type_password;
    send_key 'ret';
    type_string "ssh-copy-id $host2\n";
    assert_screen "ha-ssh-copy-id-fingerprint";
    type_string "yes\n";
    assert_screen "ha-ssh-copy-id-password";
    type_password;
    send_key 'ret';
    #    type_string "/usr/share/pacemaker/tests/cts/CTSlab.py --nodes '$host1 $host2' --outputfile pacemaker.log --clobber-cib --stonith 1 --once --stack corosync --stonith-type external/sbd --stonith-args \"SBD_DEVICE=/dev/disk/by-path/ip-172.16.0.1:3260-iscsi-iqn.2015-08.suse.qa:c581b8f2-7e8a-4774-b3f1-6a00c3d65d56-lun-0\" 1; echo CTS_FINISHED>/dev/$serialdev\n";
    mutex_lock("MUTEX_CTS_INSTALLED");
    type_string "/usr/share/pacemaker/tests/cts/CTSlab.py --nodes '$host1 $host2' --outputfile pacemaker.log " . get_var("CTS_PARAMS") . "; echo CTS_FINISHED>/dev/$serialdev\n";
    die "CTS not finished in $cts_timeout seconds" unless wait_serial "CTS_FINISHED", $cts_timeout;
    upload_logs "pacemaker.log";
    mutex_unlock("MUTEX_CTS_FINISHED");    #to be locked by node1
    wait_for_children;                     #don't destroy support server while children are running
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
