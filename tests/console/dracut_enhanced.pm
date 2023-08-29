# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dracut
# Summary: Run dracut testsuite
# - Test suitable only for dracut 0.44 (SLE12SP2+)
# - Fetches a tarball containing patches to be applied to dracut tests
# - Install dracut src.rpm and some dependencies
# - Patch dracut tests (remove references for qemu)
# - Creates a initramfs and boots the system
# - Cleanup
# Based on code from Sergio Lindo Mansilla <slindomansilla@suse.com> and
# Thomas Blume <tblume@suse.com>

# Maintainer: Ednilson Miura <emiura@suse.com>

use base "consoletest";
use warnings;
use strict;
use testapi;
use utils 'zypper_call';
use power_action_utils 'power_action';
use version_utils 'is_sle';
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;
    my $dracut_test = get_var('DRACUT_TEST');
    # dracut on SLE15SP2 was updated to 049
    my $dracut_version = "dracut-patches.tar.gz";
    if (is_sle('>=15-SP2')) {
        $dracut_version = "dracut-patches-SLE15SP2.tar.gz";
        # Enable source repositories (not needed 12SP2 ~ 15SP1)
        assert_script_run 'for r in `zypper lr|awk \'/Source-Pool/ {print $5}\'`;do zypper mr -e --refresh $r;done';
    }
    if (is_sle('<12-SP2')) {
        die "Unsupported dracut version";
    }
    else {
        assert_script_run "curl -v -o /tmp/dracut-patches.tar.gz " . data_url("qam/dracut/$dracut_version");
        assert_script_run 'tar xvf /tmp/dracut-patches.tar.gz -C /tmp';
        zypper_call "in rpmbuild dhcp-client strace";
        zypper_call "si -D dracut";
        assert_script_run('cd /usr/src/packages/SPECS');
        assert_script_run('rpmbuild -bp dracut.spec --nodeps');
        assert_script_run('cd /usr/src/packages/BUILD/dracut-*');
        assert_script_run('cp /tmp/dracut*.patch .');
        assert_script_run('for p in *patch; do patch -p0 < $p; done');
        assert_script_run "cd /usr/src/packages/BUILD/dracut-*/test/$dracut_test";
        assert_script_run 'mkdir /tmp/logs';
        assert_script_run "./test.sh --setup |& tee /tmp/logs/$dracut_test-setup.log", 300;
        assert_script_run "grep -q dracut-root-block-created /tmp/logs/$dracut_test-setup.log";
        power_action('reboot', textmode => 1);
        wait_still_screen(10, 60);
        assert_screen("linux-login", 300);
        enter_cmd "root";
        wait_still_screen 3;
        type_password;
        wait_still_screen 3;
        send_key 'ret';
        assert_script_run "cd /usr/src/packages/BUILD/dracut-*/test/$dracut_test";
        assert_script_run './test.sh --clean';
    }
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    assert_script_run('tar -cjf dracut-testsuite-logs.tar.bz2 /tmp/logs', 600);
    upload_logs('dracut-testsuite-logs.tar.bz2');
}

1;
