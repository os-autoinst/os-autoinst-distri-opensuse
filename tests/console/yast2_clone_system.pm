# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Clone system and use the autoyast file in chained tests
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_opensuse is_staging);
use utils 'zypper_call';
use repo_tools 'get_repo_var_name';

my $xml_schema_path = "/usr/share/YaST2/schema/autoyast/rng/profile.rng";

sub run {
    my $self = shift;
    select_console 'root-console';

    # Install for TW and generate profile
    zypper_call "in autoyast2";

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'clone_system');
    wait_serial("$module_name-0", 360) || die "'yast2 clone_system' didn't finish";

    # Workaround for aarch64, as ncurces UI is not updated properly sometimes
    script_run('clear');

    $self->select_serial_terminal;
    my $ay_profile_path = '/root/autoinst.xml';
    # Replace unitialized email variable - bsc#1015158
    assert_script_run "sed -i \"/server_email/ s/postmaster@/\\0suse.com/\" $ay_profile_path";

    # Check and upload profile for chained tests
    upload_asset $ay_profile_path;

    unless (is_opensuse) {
        # As developement_tools are not build for staging, we will attempt to get the package
        # otherwise MODULE_DEVELOPMENT_TOOLS should be used
        my $uri = get_ftp_uri();
        zypper_call "ar -c $uri devel-repo";
    }
    zypper_call '--gpg-auto-import-keys ref';

    zypper_call 'install jing';
    zypper_call "rr devel-repo" if (is_staging);
    my $rc_jing = script_run "jing $xml_schema_path $ay_profile_path";

    if ($rc_jing) {
        if (is_sle('<15')) {
            record_soft_failure 'bsc#1103712';
        }
        else {
            die "$ay_profile_path does not validate";
        }
    }

    # Remove for autoyast_removed test - poo#11442
    assert_script_run "rm $ay_profile_path";
    # Return from VirtIO console
    select_console 'root-console';
}

sub get_ftp_uri {
    my $devel_repo;
    if (is_staging) {
        $devel_repo = uc(get_required_var('DISTRI')) . '-' . get_required_var('VERSION') .
          '-Module-Development-Tools-POOL-' . get_required_var('ARCH') . '-CURRENT-Media1';
    } else {
        $devel_repo = get_required_var(is_sle('>=15') ? get_repo_var_name("MODULE_DEVELOPMENT_TOOLS") : 'REPO_SLE_SDK');
    }
    return "$utils::OPENQA_FTP_URL/" . $devel_repo;
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    upload_logs($xml_schema_path);
}

1;
