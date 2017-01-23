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

sub run() {
    # Valid mounts are by text(proc,mem), label, partlabel. Invalid mounts are by UUID, PARTUUID,
    # and path (note that /dev/disk/by-(part)label/ is considered 'as a (part)label mount', just
    # in different format).
    my $invalid
      = script_output "! grep -e '^/dev/disk/by-[^\\(label,partlabel\\)]' -e '^UUID' -e '^PARTUUID' /etc/fstab";

    if ($invalid) {
        die "Mount is by non-label path, non-partlabel path, UUID, or PARTUUID and hence invalid";
    }
}

1;
