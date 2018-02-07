# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run installcheck on iso
#    reusing the support server image to get an install check log - to be
#    added to big staging projects with many changes
# Maintainer: Stephan Kulow <coolo@suse.de>

use base 'opensusebasetest';
use strict;
use testapi;
use version_utils qw(is_sle sle_version_at_least);

sub run {
    # Xen PV does not emulate CDROM, treats everything as block device
    my $cddev = check_var('VIRSH_VMM_TYPE', 'linux') ? 'xvdc2' : 'sr0';
    my $ignore = get_var('INSTALLCHECK_IGNORE', is_sle && sle_version_at_least('15') ? 'skelcd-control-SLE' : '');
    my $blacklist = $ignore ? "| grep -v $ignore" : '';
    assert_script_run "mount -o ro /dev/$cddev /mnt";
    assert_script_run 'cd /tmp; rpm2cpio $(find /mnt -name libsolv-tools*.rpm) | cpio -dium';
    assert_script_run 'export PATH=/tmp/usr/bin:$PATH; usr/bin/repo2solv.sh /mnt > /tmp/solv';
    script_run 'installcheck ' . get_var("ARCH") . ' /tmp/solv ' . $blacklist . ' > /tmp/installcheck.log 2>&1';
    script_run 'cat /tmp/installcheck.log';
    save_screenshot;
    script_run "cat /tmp/installcheck.log > /dev/$serialdev";
    # non-zero file size == problems reported
    assert_script_run 'size=$(wc -c </tmp/installcheck.log); echo "size: $size" && test $size -le 1';
}

1;
# vim: set sw=4 et:
