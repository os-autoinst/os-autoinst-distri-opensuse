# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test that volumes are mounted by label
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    # Valid mounts are by text(proc,mem), LABEL, PARTLABEL
    # Invalid mounts are by path, UUID, PARTUUID
    my $invalid = script_output "grep -e '^/' -e '^UUID' -e '^PARTUUID' /etc/fstab";

    if ($invalid) {
        # Kiwi limitations - some volumes are mounted from /dev/disk/by-(part)label/ = soft fail
        my @error = grep(!/^\/dev\/disk\/by-(part)?label\/.+$/, split(/\n/, $invalid));
        if (@error) {
            die "Not all partitions are mounted by label";
        }
        else {
            die "Mount is by path, UUID or PARTUUID and hence invalid";
        }
    }
}

1;
