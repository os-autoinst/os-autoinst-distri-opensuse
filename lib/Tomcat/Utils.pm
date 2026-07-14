# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provide functionality for tomcat installation and configuration,
# accessing the tomcat manager page, and browsing tomcat examples using keyboard.
# Maintainer: QE Core <qe-core@suse.de>

package Tomcat::Utils;
use Mojo::Base 'consoletest';
use testapi;
use utils;
use version_utils 'is_sle';
use registration;
use serial_terminal;

# Install tomcat and set initial configuration
sub tomcat_setup() {
    my ($self, $version) = @_;
    $version //= '';    # default version is tomcat9

    record_info('Initial Setup');
    # we need to disable packagekit because it can block zypper sometimes later
    quit_packagekit if is_sle;

    my $tomcat = 'tomcat' . $version;
    zypper_call("in $tomcat ${tomcat}-webapps ${tomcat}-admin-webapps", timeout => 300);
    zypper_call('in libtcnative-2-0') if is_sle('>=15-sp4');
    assert_script_run("rpm -q $tomcat");

    # start the tomcat daemon and check that it is running
    systemctl('start tomcat');
    systemctl('status tomcat');

    # https://jira.suse.com/browse/PED-16024
    if (is_sle('>=15-sp4')) {
        record_info('Verify bsc#1232390');
        die('Older version Apache Tomcat Native library is installed') if script_run('journalctl -u tomcat.service |grep -i "older version"') == 0;
    }

    # check that tomcat is listening on port 8080
    assert_script_run('lsof -i :8080 | grep tomcat');

    # create manager-gui role
    assert_script_run('curl -v -o /etc/tomcat/tomcat-users.xml ' .
          data_url('lib/tomcat/tomcat-users.xml'));

    # set https connection for sle15sp4+
    # https://jira.suse.com/browse/PED-16024
    if (is_sle('>=15-sp4')) {
        script_run('cp /etc/tomcat/server.xml /etc/tomcat/server.xml.bak');
        assert_script_run('curl -v -o /etc/tomcat/server.xml ' .
              data_url('lib/tomcat/server.xml'));
        assert_script_run('openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/tomcat/localhost.key -out /etc/tomcat/localhost.crt -subj "/C=CN/ST=State/L=City/O=QE/CN=localhost"');
        assert_script_run('chown tomcat:tomcat /etc/tomcat/localhost.key /etc/tomcat/localhost.crt');
        assert_script_run('chmod 600 /etc/tomcat/localhost.key');
        assert_script_run('chmod 644 /etc/tomcat/localhost.crt');
        systemctl('restart tomcat');
        # check that tomcat is listening on port 8443
        assert_script_run('lsof -i :8443 | grep tomcat');
    }
    else {
        # restart tomcat in order to take into account new role
        systemctl('restart tomcat');
    }
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
    assert_script_run('curl -k --connect-timeout 20 --user admin:admin --output servelets https://localhost:8443/examples/servlets', 90) if is_sle('>=15-sp4');
    # curl examples of JSP and Websockets
    assert_script_run('curl --connect-timeout 20 --output jsp localhost:8080/examples/jsp --output websocket 127.0.0.1:8080/examples/websocket', 90);
    assert_script_run('curl -k --connect-timeout 20 --output jsp https://localhost:8443/examples/jsp --output websocket https://127.0.0.1:8443/examples/websocket', 90) if is_sle('>=15-sp4');
}

1;
