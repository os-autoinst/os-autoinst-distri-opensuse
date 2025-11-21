# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: test the interaction between Apache2 and Tomcat without using mod_jk
#
# Maintainer: QE Core <qe-core@suse.de>

package Tomcat::ApacheProxyTest;
use base "x11test";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub mod_proxy_setup() {
    my $self = shift;
    select_serial_terminal();

    record_info('install and configure apache2 proxy');
    zypper_call('in apache2');
    script_output(
        "echo  \"\$(cat <<EOF
<VirtualHost *:80>
    ServerName localhost

    # Forward requests for '/examples' to Tomcat using HTTP
    ProxyPass /examples/ http://localhost:8080/examples/
    ProxyPassReverse /examples/ http://localhost:8080/examples/
</VirtualHost>
EOF
        )\"  >> /etc/apache2/vhosts.d/myapp.conf"
    );
    assert_script_run('a2enmod proxy');
    assert_script_run('a2enmod proxy_http');
    systemctl('restart apache2');
    # bsc#1253707 set the booleans that allow httpd_can_network_connect
    # with semanage boolean
    assert_script_run('semanage boolean -m --on httpd_can_network_connect');
    assert_script_run('curl -L http://localhost/examples/ | grep websocket');
}

1;
