# SUSE's openQA tests
#
# Copyright (c) 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add test for yast2_http
# Maintainer: Sergio R Lemke <slemke@suse.com>

use strict;
use warnings;
use base "y2_module_consoletest";
use testapi;
use utils 'zypper_call';
use version_utils qw(is_sle is_leap);
use yast2_widget_utils 'change_service_configuration';

sub run {
    select_console 'root-console';
    zypper_call("-q in yast2-http-server");
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'http-server');

    #checking if NetworkManager or wicked is in use, this will cover all SLE and OS:
    assert_screen([qw(yast2-lan-warning-network-manager http-server)], 180);

    #if NetworkManager manager is in use a confirm command will be send to close the warning popup:
    if (match_has_tag 'yast2-lan-warning-network-manager') {
        send_key $cmd{continue};
    }

    send_key 'alt-i';    # Confirm apache2 and apache2-prefork installation
    wait_still_screen 5;

    # check http server wizard (1/5) -- Network Device Selection
    assert_screen 'http_server_wizard';
    wait_still_screen(3);
    send_key 'alt-n';                               # go to http server wizard (1/5) -- Network Device Selection
    assert_screen 'http_server_modules';            # check modules and enable php, perl, python before go to next step
    wait_still_screen 1;
    send_key 'alt-p';
    assert_screen 'http_modules_enabled_php';       # check php module enabled
    send_key 'alt-e';
    assert_screen 'http_modules_enabled_perl';      # check perl module enabled
    send_key 'alt-y';
    assert_screen 'http_modules_enabled_python';    # check python module enabled
    wait_still_screen 1;
    send_key 'alt-n';
    assert_screen 'http_default_host';              # check http server wizard (3/5) -- default host
    wait_still_screen 1;
    send_key 'down';                                # select Directory for change
    assert_screen 'http_new_directory';             # give a new directory
    wait_still_screen 1;
    send_key 'alt-i';                               # open page dir configuration
    assert_screen 'http_htdocs_new_dir';            # check dir configuration page ready for change directory
    wait_still_screen 1;
    send_key 'alt-d';
    send_key 'left';
    type_string "/new_dir";
    assert_screen 'http_new_dir_created';           # check new dir got created successfully
    send_key 'alt-o';
    assert_screen 'http_default_host';              # check that we got back to page 3/5
                                                    # Sometimes we don't get to the next page after first key press
                                                    # As part of poo#20668 we introduce this workaround to have reliable tests
                                                    # Go to http server wizard (4/5)--virtual hosts and check page (4/5 )is open
    send_key_until_needlematch 'http_add_host', $cmd{next}, 2, 3;
    wait_still_screen 1;
    send_key 'alt-a';
    assert_screen 'http_new_host_info';             # check new host information page got open to edit
    wait_still_screen 1;
    send_key 'alt-e';
    type_string "/srv/www/htdocs/new_dir";          # give path for server contents root
    wait_still_screen 1;
    send_key 'alt-s';
    type_string 'localhost';                        # give server name
    send_key 'alt-a';
    type_string 'admin@localhost';                  # give admin e-mail
    send_key 'alt-g';                               # check change virtual host later
    assert_screen 'http_ip_addresses';              # check all adresses is selected
    send_key 'alt-o';                               # close and go back to previous page
    assert_screen 'http_previous_page';             # check the previous page for nex step
    send_key 'alt-n';
    assert_screen 'http_create_new_dir';            # confirm to create the new directory
    send_key 'alt-y';
    assert_screen 'http_host_details';              # check virtual host details
    send_key 'alt-a';                               # enable CGI
    wait_still_screen 1;
    send_key 'alt-w';                               # open page CGI directory
    assert_screen 'http_cgi_directory';             # check CGI directory -- to be continued...
    send_key 'alt-d';                               # enable detailed view
    assert_screen 'http_detailed_view';             # check permissions, user, group
    send_key 'alt-o';                               # close page cgi directory and go back to previous page
    assert_screen 'http_details_changed';           # now give here directory index
    wait_still_screen 1;
    send_key 'alt-d';
    type_string "http_virtual_01";                  # index name
    send_key 'alt-p';
    assert_screen 'http_all_details';               # check all details added
    send_key 'alt-n';                               # go to page http server wizard (4/5) and confirm with next
    assert_screen 'http_vitual_host_page';          # check wizard page (4/5)
    send_key 'alt-n';                               # go to http server wizard (5/5) --summary
    assert_screen 'http_summary';                   #confirm we are in step 5/5

    # make sure that apache2 server got started when booting
    if (is_sle('<=15') || is_leap('<=15.0')) {
        send_key 'alt-t';
    }
    else {
        change_service_configuration(
            after_writing => {start         => 'alt-t'},
            after_reboot  => {start_on_boot => 'alt-a'}
        );
    }

    assert_screen 'http_start_apache2';    #confirm apache now starts on boot
    send_key 'alt-f';                      # now finish the tests :)

    check_screen 'http_install_apache2_mods', 60;
    send_key 'alt-i';                      # confirm to install apache2_mod_perl, apache2_mod_php, apache2_mod_python

    # if popup, confirm to enable apache2 configuratuion
    if (check_screen('http_enable_apache2', 10)) {
        wait_screen_change { send_key 'alt-o'; };
    }
    wait_serial("$module_name-0", 240) || die "'yast2 http-server' didn't finish";
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    $self->save_and_upload_systemd_unit_log('apache2');
    $self->SUPER::post_fail_hook;
}

1;
