# SUSE's Apache+SSL tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable SSL module on Apache2 server
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use testapi;
use strict;

sub run() {
    select_console 'root-console';

    # Make sure the apache2 package is installed
    assert_script_run 'zypper -n in apache2', 180;

    # Enable the ssl module for apache
    assert_script_run 'a2enmod ssl';
    assert_script_run "sed -i '/^APACHE_SERVER_FLAGS=/s/^/#/' /etc/sysconfig/apache2";
    assert_script_run 'echo APACHE_SERVER_FLAGS="SSL" >> /etc/sysconfig/apache2';

    # Create x509 certificate for this apache server
    assert_script_run 'gensslcert -n localhost -C localhost -e webmaster@localhost', 300;
    assert_script_run 'ls /etc/apache2/ssl.crt/localhost-server.crt /etc/apache2/ssl.key/localhost-server.key';

    # Prepare vhost file
    assert_script_run 'cp /etc/apache2/vhosts.d/vhost-ssl.template /etc/apache2/vhosts.d/vhost-ssl.conf';
    assert_script_run "sed -i -e 's/vhost-example.crt/localhost-server.crt/g' -e 's/vhost-example.key/localhost-server.key/g' /etc/apache2/vhosts.d/vhost-ssl.conf";

    # Start apache service
    assert_script_run 'systemctl start apache2';
    assert_script_run 'systemctl is-active apache2';

    # Create a test html page
    assert_script_run 'echo "<html><h2>Hello Linux</h2></html>" > /srv/www/htdocs/hello.html';

    # Verify apache+ssl works
    validate_script_output "curl -k https://localhost/hello.html", sub { m/Hello Linux/ };
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
