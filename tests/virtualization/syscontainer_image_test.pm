# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: tests running system containers images with libvirt-lxc
# Maintainer: Cédric Bosdonnat <cbosdonnat@suse.de>

use base "basetest";
use testapi;
use strict;
use warnings;
use version_utils 'is_sle';

sub run() {
    select_console 'root-console';

    return if is_sle && !(get_var('SCC_REGCODE') || get_var('HDD_SCC_REGISTERED'));

    # Check the repositories on the host first
    assert_script_run("zypper lr");

    my $url    = get_required_var('SYSCONTAINER_IMAGE_URL');
    my $rootfs = '/tmp/rootfs';

    # Create XML file
    assert_script_run('curl -f ' . autoinst_url . '/data/virtualization/syscontainer.xml -o /tmp/test.xml');

    if (is_sle) {
        my $scccredentials_mount
          = '<filesystem type=\"mount\" accessmode=\"passthrough\">'
          . '  <source dir=\"/etc/zypp/credentials.d/SCCcredentials\"/>'
          . '  <target dir=\"/etc/zypp/credentials.d/SCCcredentials\"/>'
          . '</filesystem>';
        assert_script_run("sed -i -e \'s:</devices>:$scccredentials_mount</devices>:\' /tmp/test.xml");
    }

    # Setup root filesystem

    #   - Unpack the image
    my ($ext) = $url =~ /\.([^.]+)$/;
    assert_script_run("curl -L -o syscontainer-image.tar.$ext $url");
    assert_script_run("mkdir $rootfs");
    assert_script_run("tar xf syscontainer-image.tar.$ext -C $rootfs");

    #   - Set root password
    assert_script_run("echo 'root:test' | chpasswd --root $rootfs");

    # Create the container
    script_run('virsh -c lxc:/// create --console /tmp/test.xml', 0);

    # Check that the container actually started
    assert_screen('syscontainer-login');

    # Tests on the container

    # Test login on the container
    type_string("root\n");
    type_password("test\n");

    # Wait for the login to be done before continuing
    assert_screen('syscontainer-prompt');

    # Sort by command since we can't check the PIDs:
    # this makes the needle more robust
    script_run('ps -e --sort ucmd', 0);
    assert_screen('syscontainer-procs');

    # Test mounts
    script_run('mount | sort', 0);
    assert_screen('syscontainer-mounts');

    # Test repositories
    script_run('zypper lr');
    assert_screen('syscontainer-repos');

    # shutdown the container
    script_run('poweroff', 0);
    assert_screen('syscontainer-shutdown');
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
