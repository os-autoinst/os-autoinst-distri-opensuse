# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provide functionality for tomcat installation and configuration,
# accessing the tomcat manager page, and browsing tomcat examples using keyboard.
# Maintainer: QE Core <qe-core@suse.de>

package Tomcat::Utils;
use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use registration;
use serial_terminal;

# allow a 60 second timeout for asserting needles
use constant TIMEOUT => 90;

# Use keyboard to browse the examples faster
sub browse_with_keyboard {
    my ($self, $fallback_needle, $test_func, $tab_num) = @_;

    assert_screen($fallback_needle, TIMEOUT);
    for (1 .. $tab_num) { send_key('tab'); }
    send_key('ctrl-ret');
    send_key('ctrl-tab');

    $test_func->();
    send_key('ctrl-w');
}

# Install tomcat and set initial configuration
sub tomcat_setup() {
    my $tomcat_users_xml = <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
<role rolename="manager-gui"/>
<user name="admin" password="admin" roles="manager-gui,tomcat"/>
</tomcat-users>
EOF

    # log in to root console
    select_console('root-console');

    record_info('Initial Setup');
    # we need to disable packagekit because it can block zypper sometimes later
    quit_packagekit if is_sle;

    zypper_call('in tomcat tomcat-webapps tomcat-admin-webapps', timeout => 300);
    assert_script_run('rpm -q tomcat');

    # start the tomcat daemon and check that it is running
    systemctl('start tomcat');
    systemctl('status tomcat');

    # check that tomcat is listening on port 8080
    assert_script_run('lsof -i :8080 | grep tomcat');

    # create manager-gui role
    assert_script_run("echo '$tomcat_users_xml' > /etc/tomcat/tomcat-users.xml");

    # restart tomcat in order to take into account new role
    systemctl('restart tomcat');
}


# Check Servlet, JSP and Websocket, the example files can be accessed, login with admin via tomcat manager
sub tomcat_manager_test() {
    select_serial_terminal;

    # sometimes we have sporadic issue with connection to localhost for unknown reason
    # just a short check with ping
    assert_script_run('ping -c 4 localhost');

    record_info('curl examples of Servelt, JSP and Websocket');
    # curl Servlet examples and login with authentification
    assert_script_run('curl --connect-timeout 20 --user admin:admin --output servelets 127.0.0.1:8080/examples/servlets', 90);
    # curl examples of JSP and Websockets
    assert_script_run('curl --connect-timeout 20 --output jsp localhost:8080/examples/jsp --output websocket 127.0.0.1:8080/examples/websocket', 90);
}

# Switch to desktop
sub switch_to_desktop() {

    # switch to desktop
    if (!check_var('DESKTOP', 'textmode')) {
        select_console('x11', await_console => 0);
    }
}

1;
