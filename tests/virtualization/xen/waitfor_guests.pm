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
use caasp 'script_retry';

sub run {
    my $self   = shift;
    my $domain = get_required_var('QAM_XEN_DOMAIN');

    script_retry "nmap $_.$domain -PN -p ssh | grep open", delay => 3, retry => 20 foreach (keys %xen::guests);

    # All guests should be now installed, show them
    assert_script_run 'virsh list --all';
    wait_still_screen 1;

    assert_script_run "virsh shutdown $_" foreach (keys %xen::guests);
    script_retry "virsh list --all | grep $_ | grep running", delay => 3, retry => 20 foreach (keys %xen::guests);
}

1;
