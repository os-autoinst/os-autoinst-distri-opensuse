# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Apply patches to the all of our guests
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
        if ($distro =~ m/$version/) {
            record_info "$guest", "Adding test repositories and patching the $guest system";

            # Check the virt-related packages before
            script_run "ssh root\@$guest zypper lr -d";
            script_run "ssh root\@$guest rpm -qa | grep -i xen | nl";
            script_run "ssh root\@$guest rpm -qa | grep -i irt | nl";
            script_run "ssh root\@$guest rpm -qa | grep -i emu | nl";

            ssh_add_test_repositories "$guest";
            ssh_fully_patch_system "$guest";

            # Check the virt-related packages before
            script_run "ssh root\@$guest zypper lr -d";
            script_run "ssh root\@$guest rpm -qa | grep -i xen | nl";
            script_run "ssh root\@$guest rpm -qa | grep -i irt | nl";
            script_run "ssh root\@$guest rpm -qa | grep -i emu | nl";
        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

