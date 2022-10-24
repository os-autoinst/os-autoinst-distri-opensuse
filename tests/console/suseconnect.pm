# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: SUSEConnect
# Summary: Test SUSEConnect by registering system, module and deregistration.
# - De-register system using SUSEConnect (-d, --cleanup,  --status-text)
# - Register product using SCC_REGCODE code
# - Add live patching if SLE < 15 using SCC_REGCODE_LIVE
# - Check registering status
# Maintainer: Juraj Hura <jhura@suse.com>

use base "consoletest";
use strict;
use warnings;
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
    assert_script_run "SUSEConnect -d ||:";
    assert_script_run "SUSEConnect --cleanup";
    assert_script_run "SUSEConnect --status-text";

    zypper_call 'lr';
    zypper_call 'services';
    zypper_call 'products';

    assert_script_run "SUSEConnect -r $reg_code", 180;
    assert_script_run "SUSEConnect --status-text| grep -v 'Not Registered'";
    zypper_call 'ref';
    assert_script_run "SUSEConnect --list-extensions";

    add_suseconnect_product(is_sle('<15') ? 'sle-live-patching' : 'sle-module-live-patching', undef, undef, "-r $live_reg_code");

    assert_script_run "SUSEConnect --status";
    assert_script_run "SUSEConnect -d";
    assert_script_run "SUSEConnect --status-text";

}

1;
