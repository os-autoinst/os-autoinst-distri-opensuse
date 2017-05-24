# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that volumes are mounted by label
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    # Valid mounts are by text(proc,mem), label, partlabel. Invalid mounts are by UUID, PARTUUID,
    # and path (note that /dev/disk/by-(part)label/ is considered 'as a (part)label mount', just
    # in different format). Except for Hyper-V where the product uses UUID by design.
    my $invalid;
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $invalid = script_output "! grep -e '^/dev/disk/by-[^\\(label,partlabel,uuid\\)]' -e '^PARTUUID' /etc/fstab";
    }
    else {
        $invalid = script_output "! grep -e '^/dev/disk/by-[^\\(label,partlabel\\)]' -e '^UUID' -e '^PARTUUID' /etc/fstab";
    }

    if ($invalid) {
        die "Mount point definitions are invalid";
    }
}

1;
