# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package qam;

use strict;

use base "Exporter";
use Exporter;

use testapi;
use utils;

our @EXPORT = qw(capture_state check_automounter snap_revert is_patch_needed add_test_repositories);

sub capture_state {
    my ($state, $y2logs) = @_;
    if ($y2logs) {    #save y2logs if needed
        assert_script_run "save_y2logs /tmp/y2logs_$state.tar.bz2";
        upload_logs "/tmp/y2logs_$state.tar.bz2";
        save_screenshot();
    }
    #upload ip status
    script_run("ip a | tee /tmp/ip_a_$state.log");
    upload_logs("/tmp/ip_a_$state.log");
    save_screenshot();
    script_run("ip r | tee /tmp/ip_r_$state.log");
    upload_logs("/tmp/ip_r_$state.log");
    save_screenshot();
    #upload dmesg
    script_run("dmesg > /tmp/dmesg_$state.log");
    upload_logs("/tmp/dmesg_$state.log");
    #upload journal
    script_run("journalctl -b > /tmp/journal_$state.log");
    upload_logs("/tmp/journal_$state.log");
}

sub check_automounter {
    my $ret = 1;
    while ($ret) {
        script_run(qq{[ \$(ls -ld /mounts | cut -d" " -f2) -gt 20 ]; echo automount-\$?- > /dev/$serialdev}, 0);
        $ret = wait_serial(qr/automount-\d-/);
        ($ret) = $ret =~ /automount-(\d)/;
        if ($ret) {
            script_run("rcypbind restart");
            script_run("rcautofs restart");
            sleep 5;
        }
    }
}

sub snap_revert {
    my ($svirt, $vm_name, $snapshot) = @_;
    my $ret = $svirt->run_cmd("virsh snapshot-revert $vm_name $snapshot --running");
    die "Snapshot revert $snapshot failed" if $ret;
}

sub is_patch_needed {
    my $patch = shift;
    my $install = shift // 0;

    my $patch_status = script_output("zypper -n info -t patch $patch");
    if ($patch_status =~ /Status\s*:\s+[nN]ot\s[nN]eeded/) {
        return $install ? $patch_status : 1;
    }
}

# Function that will add all test repos
sub add_test_repositories {
    my $counter = 0;
    my @repos = split(/,/, get_var('MAINT_TEST_REPO', ''));
    for my $var (@repos) {
        zypper_call("--no-gpg-check ar -f $var 'TEST_$counter'");
        $counter++;
    }

    # refresh repositories, inf 106 is accepted because repositories with test
    # can be removed before test start
    zypper_call('ref', exitcode => [0, 106]);
}


1;
