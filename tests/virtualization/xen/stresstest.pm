# VM smoke tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Perform some stress tests on VM
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    # Fetch the test script to local host, before distributing it to the guests
    script_run('curl -v -o /var/tmp/stresstest.sh ' . data_url('virtualization/stresstest.sh'));
    script_run('chmod 0755 /var/tmp/stresstest.sh');
    my ($sles_running_version, $sles_running_sp);
    foreach my $guest (keys %xen::guests) {
        # sysbench only available on SLE15+
        ($sles_running_version, $sles_running_sp) = get_sles_release("ssh root\@$guest");
        if ($sles_running_version >= 15) {
            # Push test script to guest and execute it
            assert_script_run("scp /var/tmp/stresstest.sh root\@$guest:/var/tmp/stresstest.sh");
            script_run("ssh root\@$guest bash -x /var/tmp/stresstest.sh | tee /var/tmp/stresstest-$guest.txt", timeout => 600);
            upload_logs("/var/tmp/stresstest-$guest.txt");
            if (script_run("grep 'OK' /var/tmp/stresstest-$guest.txt", timeout => 300)) {
                record_soft_failure "stresstest failed on $guest";
            }
        } else {
            record_info "sysbench not available on $guest";
        }
    }
}

1;
