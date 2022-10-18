# VM smoke tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh
# Summary: Perform some stress tests on VM
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub run_test {
    my $self = shift;
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;
    # Fetch the test script to local host, before distributing it to the guests
    script_run('curl -v -o /var/tmp/stresstest.sh ' . data_url('virtualization/stresstest.sh'));
    script_run('chmod 0755 /var/tmp/stresstest.sh');
    my ($sles_running_version, $sles_running_sp);
    foreach my $guest (keys %virt_autotest::common::guests) {
        # sysbench only available on SLE15+
        ($sles_running_version, $sles_running_sp) = get_os_release("ssh root\@$guest");
        if ($sles_running_version >= 15) {
            # Push test script to guest and execute it
            assert_script_run("scp /var/tmp/stresstest.sh root\@$guest:/var/tmp/stresstest.sh");
            script_run("ssh root\@$guest bash -x /var/tmp/stresstest.sh | tee /var/tmp/stresstest-$guest.txt", timeout => 900);
            upload_logs("/var/tmp/stresstest-$guest.txt");
            if (script_run("grep 'OK' /var/tmp/stresstest-$guest.txt", timeout => 300)) {
                record_info 'Softfail', "stresstest failed on $guest", result => 'softfail';
            }
        } else {
            record_info "sysbench not available on $guest";
        }
    }
}

1;
