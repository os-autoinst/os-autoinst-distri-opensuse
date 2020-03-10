# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Apply patches to the all of our guests and reboot them
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use warnings;
use strict;
use testapi;
use qam 'ssh_add_test_repositories';
use utils;
use xen;

sub run {
    my ($self) = @_;
    my $version = get_var('VERSION');
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));

    foreach my $guest (keys %xen::guests) {
        my $distro = $xen::guests{$guest}->{distro};
        $distro =~ tr/_/-/;
        $distro =~ s/SLE-//;

        record_info "$guest", "Adding test repositories and patching the $guest system";
        if ($distro =~ m/$version/) {
            ssh_add_test_repositories "$guest";

            script_run "ssh root\@$guest zypper lr -d";
            script_run "ssh root\@$guest rpm -qa > /tmp/patch_and_reboot-$guest-before.txt";
            upload_logs("/tmp/patch_and_reboot-$guest-before.txt");

            ssh_fully_patch_system "$guest";
        }

        record_info "REBOOT", "Rebooting the $guest";

        assert_script_run "ssh root\@$guest 'reboot' || true";
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, die => 0)) {
            record_soft_failure "Reboot on $guest failed";
            script_run "virsh destroy $guest",      90;
            assert_script_run "virsh start $guest", 60;
        }

        script_run "ssh root\@$guest rpm -qa > /tmp/patch_and_reboot-$guest-after.txt";
        upload_logs("/tmp/patch_and_reboot-$guest-after.txt");
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

