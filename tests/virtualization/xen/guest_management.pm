# XEN regression tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test basic VM guest management
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use testapi;
use utils;

sub run {
    my $self = shift;

    # Start, Stop, Reboot, Autostart, Suspend and Listing should work
    assert_script_run "virsh shutdown $_" foreach (keys %xen::guests);
    assert_script_run 'virsh list --all';

    assert_script_run "virsh start $_" foreach (keys %xen::guests);
    assert_script_run 'virsh list --all';

    assert_script_run "virsh reboot $_" foreach (keys %xen::guests);
    assert_script_run 'virsh list --all';

    assert_script_run "virsh autostart $_" foreach (keys %xen::guests);
    assert_script_run 'virsh list --all';

    assert_script_run "virsh autostart --disable $_" foreach (keys %xen::guests);
    assert_script_run 'virsh list --all';

    assert_script_run "virsh suspend $_" foreach (keys %xen::guests);
    assert_script_run 'virsh list --all';

    assert_script_run "virsh resume $_" foreach (keys %xen::guests);
    assert_script_run 'virsh list --all';
}

1;
