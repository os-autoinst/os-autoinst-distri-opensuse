# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify that yast2-lan does not crash if there are errors
# (like typos or duplicates) in one of the ifcfg files.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_module_guitest';
use strict;
use warnings;
use testapi;
use y2lan_restart_common qw(open_network_settings wait_for_xterm_to_be_visible close_xterm close_network_settings);
use x11utils 'start_root_shell_in_xterm';
use scheduler 'get_test_suite_data';

sub check_errors_in_ifcfg {
    my ($error_in_ifcfg, $ifcfg_file) = @_;
    assert_script_run("$error_in_ifcfg $ifcfg_file");    # Insert an error in ifcfg file
    open_network_settings;
    close_network_settings;
    wait_for_xterm_to_be_visible();
}

sub run {
    my $test_data = get_test_suite_data();
    my $ifcfg_file = '/etc/sysconfig/network/ifcfg-' . $test_data->{net_device};
    record_info('IFCFG', 'Verify that putting wrong settings in ifcfg files do not provoke a crash');
    start_root_shell_in_xterm();
    assert_script_run("cat $ifcfg_file > backup");
    foreach my $error_in_ifcfg (@{$test_data->{errors_in_ifcfg_file}}) {
        check_errors_in_ifcfg($error_in_ifcfg, $ifcfg_file);    # See descriptions of errors in test_data
        assert_script_run("cat backup > $ifcfg_file");
    }
    assert_script_run("rm backup");
    close_xterm();
}

1;
