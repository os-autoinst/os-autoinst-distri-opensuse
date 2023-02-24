# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2
# Summary: yast2_hostnames check hostnames and add/delete hostsnames
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils qw(type_string_slow_extended clear_console);
use version_utils qw(is_sle);
use YaST::workarounds;

sub run {
    my $module = "host";
    my $hosts_params = {
        ip => '195.135.221.134',
        fqdn => 'download.opensuse.org',
        alias => 'download-srv'
    };

    select_console 'root-console';
    #   add 1 entry to /etc/hosts and edit it later
    script_run "echo '80.92.65.53    n-tv.de ntv' >> /etc/hosts";
    clear_console;
    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11($module, match_timeout => 90);
    apply_workaround_poo124652('yast2_hostnames_added', 180) if (is_sle('>=15-SP4'));
    assert_screen 'yast2_hostnames_added', timeout => 180;
    assert_and_click "yast2_hostnames_added";
    send_key 'alt-i';
    assert_screen 'yast2_hostnames_edit_popup';
    send_key 'alt-i';
    type_string_slow_extended($hosts_params->{ip});
    send_key 'tab';
    type_string_slow_extended($hosts_params->{fqdn});
    send_key 'tab';
    type_string_slow_extended($hosts_params->{alias});
    assert_screen 'yast2_hostnames_changed_ok';
    send_key 'alt-o';
    assert_screen "yast2-$module-ui", 30;
    #   OK => Exit
    send_key "alt-o";
    wait_serial("yast2-$module-status-0") || die 'Fail! YaST2 - Hostnames dialog is not closed or non-zero code returned.';
    # Check that entry was correctly edited in /etc/hosts
    select_console "root-console";
    assert_script_run qq{grep -E '$hosts_params->{ip}\\s+$hosts_params->{fqdn}\\s+$hosts_params->{alias}' /etc/hosts};
}

# Test ends in root-console, default post_run_hook does not work here
sub post_run_hook {
    set_var('YAST2_GUI_TERMINATE_PREVIOUS_INSTANCES', 1);
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    upload_logs('/etc/hosts');
}

1;
