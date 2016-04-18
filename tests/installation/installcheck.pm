# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_script_run "mount /dev/sr0 /mnt";
    assert_script_run 'cd /tmp; rpm2cpio /mnt/suse/*/libsolv-tools*.rpm | cpio -dium';
    assert_script_run 'export PATH=/tmp/usr/bin:$PATH; usr/bin/repo2solv.sh /mnt > /tmp/solv';
    script_run 'installcheck ' . get_var("ARCH") . ' /tmp/solv > /tmp/installcheck.log 2>&1 && touch /tmp/WORKED';
    script_run 'cat /tmp/installcheck.log';
    save_screenshot;
    script_run "cat /tmp/installcheck.log > /dev/$serialdev";
    assert_script_run 'test -f /tmp/WORKED';
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
