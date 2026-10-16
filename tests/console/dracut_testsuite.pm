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

use Mojo::Base 'consoletest';
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use serial_terminal qw(select_serial_terminal);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    select_serial_terminal;

    my $dracut_version = script_output("rpm -q dracut | cut -d '-' -f2 | cut -d '+' -f1");
    die 'Failed to get dracut version' unless $dracut_version;

    my $repo_name_pattern = "Basesystem.*Source";
    if (is_sle '>=16.0') {
        $repo_name_pattern = "SLE-Product.*Source";
    }

    # phub for ShellCheck package
    add_suseconnect_product(get_addon_fullname('phub'));
    # install build and testsuite dependencies
    my $dracut_deps = 'cargo rust nbd dbus-broker strace rpm-build dhcp-server dhcp-client dash asciidoc libkmod-devel git qemu-kvm qemu tgt iscsiuio open-iscsi ShellCheck tree';
    if ($dracut_version >= 108) {
        $dracut_deps .= ' systemd-devel';
    }
    zypper_call("in $dracut_deps");

    assert_script_run "for r in `zypper lr|awk \'/$repo_name_pattern/ {print \$5}\'`;do zypper mr -e --refresh \$r;done";
    zypper_call('si dracut');
    assert_script_run "for r in `zypper lr|awk \'/$repo_name_pattern/ {print \$5}\'`;do zypper mr -d --no-refresh \$r;done";
    assert_script_run('mkdir /tmp/logs');
    assert_script_run('cd /usr/src/packages/SPECS');
    assert_script_run('rpmbuild -bc dracut.spec');
    my $src_path = script_output("find /usr/src/packages/BUILD/ -type f -name 'dracut.sh' -exec dirname {} \;");
    die 'Failed to get path to dracut source' unless $src_path;
    if ($dracut_version >= 104) {
        my @dracut_test_conf = qw(test test-makeroot test-root);
        foreach (@dracut_test_conf) {
            assert_script_run("ln -s $src_path/dracut.conf.d/$_ /usr/lib/dracut/dracut.conf.d/$_");
        }
        my @dracut_test_modules = qw(70test-makeroot 70test-root);
        foreach (@dracut_test_modules) {
            assert_script_run("ln -s $src_path/modules.d/$_ /usr/lib/dracut/modules.d/$_");
        }
    }

    my $dracut_test = get_var('DRACUT_TEST');
    if ($dracut_test) {
        assert_script_run("cd $src_path/test/$dracut_test");
        assert_script_run("make V=1 clean setup run |& tee /tmp/logs/$dracut_test.log", 600);
    }
    else {
        my @tests = qw();
        if ($dracut_version >= 106) {
            @tests = qw(TEST-10-BASIC TEST-20-STORAGE TEST-40-SYSTEMD TEST-41-FULL-SYSTEMD TEST-80-GETARG TEST-82-DRACUT-CPIO);
        }
        else {
            @tests = qw(TEST-01-BASIC TEST-02-SYSTEMD TEST-04-FULL-SYSTEMD TEST-10-RAID TEST-11-LVM TEST-17-LVM-THIN);
            push(@tests, qw(TEST-63-DRACUT-CPIO TEST-98-GETARG)) if ($dracut_version > 49);
            push(@tests, qw(TEST-15-BTRFSRAID)) if (is_sle('15-sp5+') && is_sle('<16.0'));
        }
        foreach (@tests) {
            assert_script_run("cd $src_path/test/$_");
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
