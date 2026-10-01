# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: test the interaction between Apache2 and Tomcat without using mod_jk
#
# Maintainer: QE Core <qe-core@suse.de>

package Tomcat::ApacheProxyTest;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use package_utils 'install_package';
use version_utils 'has_selinux';

sub mod_proxy_setup() {
    my $self = shift;
    select_serial_terminal();

    record_info('install and configure apache2 proxy');
    install_package('apache2', trup_reboot => 1);
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
    assert_script_run('semanage boolean -m --on httpd_can_network_connect') if has_selinux
    # Tomcat serves from /srv/tomcat/webapps. If the examples webapp is
    # already deployed there, leave it as-is; otherwise symlink it in from
    # the package location /usr/share/tomcat/tomcat-webapps/examples.
    assert_script_run(
        'test -e /srv/tomcat/webapps/examples || ' .
          'ln -sfn /usr/share/tomcat/tomcat-webapps/examples /srv/tomcat/webapps/examples'
    );
    systemctl('restart tomcat');
    script_retry('systemctl is-active tomcat', retry => 3, delay => 5);
    script_retry('curl -L -f http://localhost/examples/ | grep websocket', retry => 5, delay => 2);
}
1;
