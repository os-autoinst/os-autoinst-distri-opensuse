# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Replacement of patch_and_reboot, does everything else but patch and reboot,
#          adding repos and patching is not done as it's done during installation,
#          thus reboot is not needed
# - Stop packagekit service (unless DESKTOP is textmode)
# - Disable nvidia repository
# - Enable basesystem repository on TERADATA without SCC reg
# - Upload kernel changelog
#
# Maintainer: QE Core <qe-core@suse.com>

use base "opensusebasetest";
use testapi;
use utils qw(zypper_call quit_packagekit);
use serial_terminal qw(select_serial_terminal);
use registration qw(add_suseconnect_product get_addon_fullname);
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    quit_packagekit unless check_var('DESKTOP', 'textmode');

    zypper_call(q{mr -d $(zypper lr | awk -F '|' '{IGNORECASE=1} /nvidia/ {print $2}')}, exitcode => [0, 3]);
    zypper_call(q{mr -e $(zypper lr | awk -F '|' '/Basesystem-Module/ {print $2}')}, exitcode => [0, 3]) if get_var('FLAVOR') =~ /TERADATA/;

    add_suseconnect_product(get_addon_fullname('phub')) if check_var('PATTERNS', 'all') && is_sle('15-SP6+') && is_sle('<16');

    assert_script_run("rpm -ql --changelog --whatprovides kernel > /tmp/kernel_changelog.log");
    zypper_call("lr -u", log => 'repos_list.txt');
    assert_script_run('grep "ibs/SUSE:/Maintenance:" /tmp/repos_list.txt', fail_message => 'Maintenance update repos are missing') if main_common::is_updates_tests() && is_sle;
    upload_logs('/tmp/kernel_changelog.log');
    upload_logs('/tmp/repos_list.txt');

    if (get_var('SAVE_LIST_OF_PACKAGES')) {
        assert_script_run("rpm -qa > /tmp/rpm_packages_list_after_patch.txt");
        upload_logs('/tmp/rpm_packages_list_after_patch.txt');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
