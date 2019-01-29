# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Wait for guests so they finish the installation
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use testapi;
use utils;

sub run {
    my $self   = shift;
    my $domain = get_required_var('QAM_XEN_DOMAIN');

    zypper_call '-t in nmap';

    foreach my $guest (keys %xen::guests) {
        for (my $i = 1; $i <= 60; $i++) {
            if (script_run("nmap $guest.$domain -PN -p ssh | grep open") == 0) {
                last;
            }
            sleep 60;
        }
    }

    # All guests should be now installed, show them
    assert_script_run 'xl list';
    save_screenshot;

    assert_script_run "virsh shutdown $_" foreach (keys %xen::guests);
    for (my $i = 0; $i <= 120; $i++) {
        if (script_run("virsh list --all | grep -v Domain-0 | grep running") == 1) {
            last;
        }
        sleep 1;
    }
}

1;
