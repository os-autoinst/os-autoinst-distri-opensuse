# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test https://documentation.suse.com/suse-distribution-migration-system/15/html/distribution-migration-system/index.html
#
# Maintainer: QE C <qe-c@suse.de>
#
use base 'consoletest';
use testapi;
use utils;
use registration qw(runtime_registration deregister_addons_cmd);
use version_utils qw(get_os_release);
use Config::Tiny;
use Test::Assert ':all';
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';
use upload_system_log 'upload_supportconfig_log';


my $suse_migration_services_repo = get_var("SUSE_MIGRATION_SERVICES_REPO", "https://download.opensuse.org/repositories/home:/marcus.schaefer:/dms/SLE_12_SP5");
my $upgrade_expected_os_version = get_var("UPGRADE_EXPECTED_OS_VERSION", "15");
my $upgrade_expected_os_service_pack = get_var("UPGRADE_EXPECTED_OS_SERVICE_PACK", "5");

sub collect_debug_info {
    select_serial_terminal;
    upload_system_log::upload_supportconfig_log();
    record_info("DEBUG", script_output("python3 --version", proceed_on_failure => 1));
    record_info("DEBUG", script_output("cat /usr/bin/suse-migration-pre-checks", proceed_on_failure => 1));
}

sub register_scc {
    select_serial_terminal;

    runtime_registration();
    record_info("SUSEConnect --status", script_output("SUSEConnect --status"));
    record_info("SUSEConnect --list-extensions", script_output("SUSEConnect --list-extensions"));
}

sub install_suse_migration_services {
    my $sms_repo_name = "Migration";

    select_serial_terminal;

    zypper_call("ar $suse_migration_services_repo $sms_repo_name");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("in suse-migration-sle15-activation");
    zypper_call("rr $sms_repo_name");
    deregister_addons_cmd();
}

sub validate_product_upgraded {
    select_serial_terminal;

    my ($os_version, $os_service_pack, $distro_name) = get_os_release();

    assert_equals(
        $upgrade_expected_os_version,
        $os_version,
        ('Unexpected OS Version. Expected: ' . $upgrade_expected_os_version . ' actual: ' . $os_version)
    );
    assert_equals(
        $upgrade_expected_os_service_pack,
        $os_service_pack,
        ('Unexpected Service Pack. Expected: ' . $upgrade_expected_os_service_pack . ' actual: ' . $os_service_pack)
    );
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    collect_debug_info();

    register_scc();
    install_suse_migration_services();

    collect_debug_info();

    power_action 'reboot';

    assert_screen("suse-migration-services-running", timeout => 300);
    assert_screen("tty1-selected", timeout => 900);

    collect_debug_info();

    validate_product_upgraded();
}

1;
