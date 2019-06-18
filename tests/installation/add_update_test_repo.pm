# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Support installation testing of SLE 12 with unreleased maint updates
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use qam 'advance_installer_window';
use version_utils 'is_sle';

sub run() {

    if (get_var('SKIP_INSTALLER_SCREEN', 0)) {
        advance_installer_window('inst-addon');
        # Since we already advanced, we don't want to advance more in the add_products_sle tests
        set_var('SKIP_INSTALLER_SCREEN', 0);
    }

    assert_screen 'inst-addon';
    send_key 'alt-k';    # install with a maint update repo
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));

    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        assert_screen('addon-menu-active', 60);
        wait_screen_change { send_key 'alt-u' };    # specify url
        if (check_var('VERSION', '12') and check_var('VIDEOMODE', 'text')) {
            send_key 'alt-x';
        }
        else {
            send_key $cmd{next};
        }
        assert_screen 'addonurl-entry';
        send_key 'alt-u';                           # select URL field
        type_string $maintrepo;
        advance_installer_window('addon-products');
        # if more repos to come, add more
        send_key_until_needlematch('addon-menu-active', 'alt-a', 10, 5) if @repos;
    }
}

sub pre_run_hook {
    if (is_sle('15+') && get_var('FLAVOR', '') =~ /-(Updates|Incidents)$/) {
        select_console 'install-shell';
        wait_still_screen;
        type_string "tcpdump -i eth0 -nn -s0 -vv -w openqa_tcpdump.pcap &>/dev/$serialdev &\n";
        sleep 2;
        save_screenshot;
        select_console 'installation';
    }
}

sub post_run_hook {
    if (is_sle('15+') && get_var('FLAVOR', '') =~ /-(Updates|Incidents)$/) {
        select_console 'install-shell';
        script_run 'killall tcpdump', 0;
        script_run 'rm -f openqa_tcpdump.pcap, 0';
        select_console 'installation';
    }
}

sub post_fail_hook {
    if (is_sle('15+') && get_var('FLAVOR', '') =~ /-(Updates|Incidents)$/) {
        select_console 'install-shell';
        script_run 'killall tcpdump', 0;
        upload_logs 'openqa_tcpdump.pcap';
        select_console 'installation';
    }
}

1;
