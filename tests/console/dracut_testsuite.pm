# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dracut
# Summary: Run dracut testsuite
# - Install dracut source and build dracut
# - Run multiple tests or one defined in DRACUT_TEST
# https://github.com/dracut-ng/dracut-ng/blob/main/docs/HACKING.md
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use serial_terminal qw(select_serial_terminal);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    select_serial_terminal;

    my $repo_name_pattern = "Basesystem.*Source";
    if (is_sle '>=16.0') {
        $repo_name_pattern = "SLE-Product.*Source";
    }

    my $dracut_test = get_var('DRACUT_TEST');
    # phub for ShellCheck package
    add_suseconnect_product(get_addon_fullname('phub'));
    # install build and testsuite dependencies
    zypper_call('in cargo rust nbd dbus-broker strace rpm-build dhcp-server dhcp-client dash asciidoc libkmod-devel git qemu-kvm qemu tgt iscsiuio open-iscsi ShellCheck tree');

    assert_script_run "for r in `zypper lr|awk \'/$repo_name_pattern/ {print \$5}\'`;do zypper mr -e --refresh \$r;done";
    zypper_call('si dracut');
    assert_script_run "for r in `zypper lr|awk \'/$repo_name_pattern/ {print \$5}\'`;do zypper mr -d --no-refresh \$r;done";
    my $version = script_output(q(rpm -q dracut|awk -F"[-.]" '{print$2}'|cut -c2-3));
    assert_script_run('mkdir /tmp/logs');
    assert_script_run('cd /usr/src/packages/SPECS');
    assert_script_run('rpmbuild -bc dracut.spec');
    if ($dracut_test) {
        assert_script_run("cd -- \$(find /usr/src/packages/BUILD/ -type d -name $dracut_test) && ll");
        assert_script_run("make V=1 clean setup run |& tee /tmp/logs/$dracut_test.log", 600);
    }
    else {
        my @tests = qw(TEST-01-BASIC TEST-02-SYSTEMD TEST-04-FULL-SYSTEMD TEST-10-RAID TEST-11-LVM TEST-17-LVM-THIN);
        push(@tests, qw(TEST-63-DRACUT-CPIO TEST-98-GETARG)) if ($version > 49);
        push(@tests, qw(TEST-15-BTRFSRAID)) if is_sle('15-sp5+');
        foreach (@tests) {
            assert_script_run("cd -- \$(find /usr/src/packages/BUILD/ -type d -name $_) && ll");
            record_info("$_", "$_");
            assert_script_run("make V=1 clean setup run |& tee /tmp/logs/$_.log", 3000);
        }
    }
    assert_script_run('tar -cjf dracut-testsuite-logs.tar.bz2 /tmp/logs', 600);
    upload_logs('dracut-testsuite-logs.tar.bz2');
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    assert_script_run('tar -cjf dracut-testsuite-logs.tar.bz2 /tmp/logs', 600);
    upload_logs('dracut-testsuite-logs.tar.bz2');
}

1;
