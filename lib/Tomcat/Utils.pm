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

    zypper_call('in tomcat tomcat-webapps tomcat-admin-webapps');
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


# Access the tomcat web application manager
sub tomcat_manager_test() {
    my ($self) = shift;

    $self->firefox_open_url('localhost:8080/manager');
    send_key_until_needlematch('tomcat-manager-authentication', 'ret');
    type_string('admin');
    send_key('tab');
    type_string('admin');
    assert_and_click('tomcat-OK-autentication');
    wait_still_screen(2);
    assert_and_click('tomcat-click-save-login');
    assert_screen('tomcat-web-application-manager', TIMEOUT);
}


1;
