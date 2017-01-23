# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add test for yast2_http
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "consoletest";
use testapi;



sub run() {

    select_console 'root-console';
    # install http server
    assert_script_run("/usr/bin/zypper -n -q in yast2-http-server");
    script_run("yast2 http-server; echo yast2-http-server-status-\$? > /dev/$serialdev", 0);
    assert_screen 'http-server';              # check page "Initializing HTTP Server Configuration"
    send_key 'alt-i';                         # make sure that apache2, apache2-prefork packages needs to be installed
    assert_screen 'http_server_wizard';       # check http server wizard (1/5) -- Network Device Selection
    send_key 'alt-n';                         # go to http server wizard (1/5) -- Network Device Selection
    assert_screen 'http_server_modules';      # check modules and enable php, perl, python before go to next step
    send_key 'alt-p';
    send_key 'alt-e';
    send_key 'alt-y';
    assert_screen 'http_modules_enabled';     # check 3 modules enabled
    send_key 'alt-n';
    assert_screen 'http_default_host';        # check http server wizard (3/5) -- default host
    send_key 'down';                          # select Directory for change
    assert_screen 'http_new_directory';       # give a new directory
    send_key 'alt-i';                         # open page dir configuration
    assert_screen 'http_htdocs_new_dir';      # check dir configuration page ready for change directory
    send_key 'alt-d';
    send_key 'left';
    type_string "/new_dir";
    assert_screen 'http_new_dir_created';     # check new dir got created successfully
    send_key 'alt-o';
    wait_still_screen;
    send_key 'alt-n';                         # now go to http server wizard (4/5)--virtual hosts
    assert_screen 'http_add_host';            # check the page (4/5) is open and ready for adding a new virtual host
    send_key 'alt-a';
    assert_screen 'http_new_host_info';       # check new host information page got open to edit
    send_key 'alt-e';
    type_string "/srv/www/htdocs/new_dir";    # give path for server contents root
    send_key 'alt-s';
    type_string 'localhost';                  # give server name
    send_key 'alt-a';
    type_string 'admin@localhost';            # give admin e-mail
    send_key 'alt-g';                         # check change virtual host later
    assert_screen 'http_ip_addresses';        # check all adresses is selected
    send_key 'alt-o';                         # close and go back to previous page
    assert_screen 'http_previous_page';       # check the previous page for nex step
    send_key 'alt-n';
    assert_screen 'http_create_new_dir';      # confirm to create the new directory
    send_key 'alt-y';
    assert_screen 'http_host_details';        # check virtual host details
    send_key 'alt-a';                         # enable CGI
    send_key 'alt-w';                         # open page CGI directory
    assert_screen 'http_cgi_directory';       # check CGI directory -- to be continued...
    send_key 'alt-d';                         # enable detailed view
    assert_screen 'http_detailed_view';       # check permissions, user, group
    send_key 'alt-o';                         # close page cgi directory and go back to previous page
    assert_screen 'http_details_changed';     # now give here directory index
    send_key 'alt-d';
    type_string "http_virtual_01";            # index name
    send_key 'alt-p';
    assert_screen 'http_all_details';         # check all details added
    send_key 'alt-n';                         # go to page http server wizard (4/5) and confirm with next
    assert_screen 'http_vitual_host_page';    # check wizard page (4/5)
    send_key 'alt-n';                         # go to http server wizard (5/5) --summary
    assert_screen 'http_summary';             # check the summary page and go to select start apache2 sever when booting
    send_key 'alt-t';
    assert_screen 'http_start_apache2';       # make sure that apache2 server got started when booting
    send_key 'alt-f';                         # now finish the tests :)
    check_screen 'http_install_apache2_mods';
    send_key 'alt-i';    # confirm to install apache2_mod_perl, apache2_mod_php5, apache2_mod_python

    # if popup, confirm to enable apache2 configuratuion
    if (check_screen('http_enable_apache2', 10)) {
        send_key 'alt-o';
    }
    wait_serial("yast2-http-server-status-0", 60) || die "'yast2 http-server' didn't finish";
}
1;

# vim: set sw=4 et:
