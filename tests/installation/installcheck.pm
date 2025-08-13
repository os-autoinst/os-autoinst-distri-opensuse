# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run installcheck on iso
#    reusing the support server image to get an install check log - to be
#    added to big staging projects with many changes
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "opensusebasetest";
use testapi;

sub run {
    # Xen PV does not emulate CDROM, treats everything as block device
    my $cddev = check_var('VIRSH_VMM_TYPE', 'linux') ? 'xvdc2' : 'sr0';
    assert_script_run "mount -o ro /dev/$cddev /mnt";
    assert_script_run 'cd /tmp; rpm2cpio $(find /mnt -name libsolv-tools*.rpm) | cpio -dium';
    assert_script_run 'export PATH=/tmp/usr/bin:$PATH; usr/bin/repo2solv.sh /mnt > /tmp/solv';
    script_run 'installcheck ' . get_var("ARCH") . ' /tmp/solv > /tmp/installcheck.log 2>&1 && touch /tmp/WORKED';
    script_run 'cat /tmp/installcheck.log';
    save_screenshot;
    script_run "cat /tmp/installcheck.log > /dev/$serialdev";
    assert_script_run 'test -f /tmp/WORKED';
}

1;
