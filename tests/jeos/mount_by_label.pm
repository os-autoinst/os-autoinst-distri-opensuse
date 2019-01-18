# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that volumes are mounted by label
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    assert_script_run('lsblk');
    assert_script_run('blkid');
    # Valid mounts are by label. Invalid mounts are by e.g. UUID, PARTUUID,
    # and path. Except for Hyper-V where the product uses UUID by design.
    assert_script_run('cat /etc/fstab');
    my $uuid = check_var('VIRSH_VMM_FAMILY', 'hyperv') ? '-e ^UUID' : '';
    assert_script_run("! grep -v $uuid -e ^LABEL= /etc/fstab");
}

1;
