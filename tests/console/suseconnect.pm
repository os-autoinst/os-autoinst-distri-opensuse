# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: SUSEConnect
# Summary: Test SUSEConnect by registering system, module and deregistration.
# - De-register system using SUSEConnect (-d, --cleanup,  --status-text)
# - Register product using SCC_REGCODE code
# - Add live patching (extension on SLE 12, module on SLE 15, skipped on SLE 16) using SCC_REGCODE_LIVE
# - Check registering status
# Maintainer: Juraj Hura <jhura@suse.com>
# Tags: poo#207477

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use registration;
use version_utils 'is_sle';

sub run {
    my $reg_code = get_required_var("SCC_REGCODE");
    my $arch = get_required_var("ARCH");
    my $live_reg_code = get_required_var("SCC_REGCODE_LIVE");

    select_serial_terminal;

    # Make sure to start with de-registered system. In case the system is not registered this command will fail
    assert_script_run "SUSEConnect -d || SUSEConnect --cleanup", 240;
    assert_script_run "SUSEConnect --status-text";

    zypper_call('lr', exitcode => [0, 6]);
    zypper_call 'services';
    zypper_call 'products';

    assert_script_run "SUSEConnect -r $reg_code", 360;
    assert_script_run "SUSEConnect --status-text| grep -v 'Not Registered'";
    zypper_call 'ref';
    assert_script_run "SUSEConnect --list-extensions";

    # Products to activate with SCC_REGCODE_LIVE: SLE 12 has the live patching extension,
    # SLE 15 has it as a module. SLE 16 has no such product in SCC (not listed by --list-extensions)
    my @live_products = is_sle('15+') ? ('sle-module-live-patching') : ('sle-live-patching');
    if (is_sle('16+')) {
        record_info('skip live patching', 'No live patching product available in SCC for SLE 16');
        @live_products = ();
    }
    add_suseconnect_product($_, undef, undef, "-r $live_reg_code") for @live_products;

    assert_script_run "SUSEConnect --status";
    assert_script_run "SUSEConnect -d || SUSEConnect --cleanup", 900;
    assert_script_run "SUSEConnect --status-text";

}

sub test_flags {
    return {always_rollback => 1};
}

1;
