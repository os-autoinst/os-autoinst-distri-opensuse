# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that there is access to the local hard disk from rescuesystem
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    my $hdddev = check_var('VIRSH_VMM_FAMILY', 'xen') ? 'xvda2' : 'vda2';
    assert_script_run "mount /dev/$hdddev /mnt";
    type_string "cat /mnt/etc/SuSE-release > /dev/$serialdev\n";
    wait_serial("SUSE Linux Enterprise Server", 10) || die "Not SLES found";
}

sub test_flags {
    return {fatal => 1};
}

1;
