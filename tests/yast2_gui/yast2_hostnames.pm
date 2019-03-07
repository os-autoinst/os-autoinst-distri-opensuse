# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_hostnames check hostnames and add/delete hostsnames
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2x11test";
use strict;
use warnings;
use testapi;
use utils 'clear_console';
use x11utils qw(turn_off_kde_screensaver turn_off_gnome_screensaver);

sub run {
    my $self         = shift;
    my $module       = "host";
    my $dm           = lc get_var('DESKTOP');
    my $hosts_params = {
        ip    => '195.135.221.134',
        fqdn  => 'download.opensuse.org',
        alias => 'download-srv'
    };
    my %execute = (
        gnome => \&turn_off_gnome_screensaver,
        kde   => \&turn_off_kde_screensaver
    );
    $execute{$dm}->();
    select_console 'root-console';
    #	add 1 entry to /etc/hosts and edit it later
    script_run "echo '80.92.65.53    n-tv.de ntv' >> /etc/hosts";
    clear_console;
    select_console 'x11';
    $self->launch_yast2_module_x11($module, match_timeout => 90);
    assert_and_click "yast2_hostnames_added";
    send_key 'alt-i';
    assert_screen 'yast2_hostnames_edit_popup';
    send_key 'alt-i';
    type_string($hosts_params->{ip}, max_interval => 13, wait_still_screen => 0.05, timeout => 5, similarity_level => 38);
    send_key 'tab';
    type_string($hosts_params->{fqdn}, max_interval => 13, wait_still_screen => 0.05, timeout => 5, similarity_level => 38);
    send_key 'tab';
    type_string($hosts_params->{alias}, max_interval => 13, wait_still_screen => 0.05, timeout => 5, similarity_level => 38);
    assert_screen 'yast2_hostnames_changed_ok';
    send_key 'alt-o';
    assert_screen "yast2-$module-ui", 30;
    #	OK => Exit
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
