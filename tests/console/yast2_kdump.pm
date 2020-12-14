# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test scenario which configures Kdump with a YaST module
# and checks configuration without rebooting the system.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use registration;
use kdump_utils;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {
    select_console('root-console');
    my @conf_files = @{get_test_suite_data()->{kdump}};

    # install kdump by adding additional modules
    add_suseconnect_product('sle-module-desktop-applications');
    add_suseconnect_product('sle-module-development-tools');
    zypper_call('in yast2-kdump');

    # Kdump configuration with YaST module
    kdump_utils::activate_kdump;

    # check service (without restarting)
    systemctl('is-enabled kdump');

    # check configuration files
    for my $conf_file (@conf_files) {
        my $path        = $conf_file->{path};
        my $conf_output = script_output("cat $path");
        for my $setting (keys %{$conf_file->{settings}}) {
            my ($conf_line) = grep { /$setting=/ } split(/\n/, $conf_output);
            die "Setting '$setting' not found in $path" unless $conf_line;
            my $value = $conf_file->{settings}->{$setting};
            assert_matches(qr/^$setting=["]?$value["]?$/, $conf_line,
                "Found unexpected setting value in $path.");
        }
    }

    # delete additional modules
    remove_suseconnect_product('sle-module-development-tools');
    remove_suseconnect_product('sle-module-desktop-applications');

    # info for next tests
    record_info('Notice', 'If next modules scheduled after this one will require ' .
          'a reboot, take into account that kdump options will take effect.');
}

1;
