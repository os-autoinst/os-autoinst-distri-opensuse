# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup Apache2 with SSL enabled and test libserf by using SVN.
# Maintainer: Starry Wang <starry.wang@suse.com> Ben Chou <bchou@suse.com>
# Tags: poo#110434, tc#1769948

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;

sub run {
    my ($self) = @_;

    select_console('root-console');

    # Setup Apache2 server with SSL enabled
    zypper_call('in apache2 subversion-server');
    # Activate the SSL Module
    assert_script_run('a2enmod ssl');
    assert_script_run('echo "127.0.0.1 example-ssl.com" > /etc/hosts');
    # Prepare certificates
    assert_script_run('gensslcert -n example-ssl.com -e webmaster@example.com');
    my $vhost_ssl_conf_path = '/etc/apache2/vhosts.d/vhost-ssl.conf';
    type_string("cat >> $vhost_ssl_conf_path << EOF
<IfDefine SSL>
<IfDefine !NOSSL>
<VirtualHost _default_:443>

    DocumentRoot \"/srv/www/vhosts/example-ssl.com\"
    ServerName example-ssl.com
    ServerAdmin webmaster\@example-ssl.com
    ErrorLog /var/log/apache2/example-ssl.com-error_log
    TransferLog /var/log/apache2/example-ssl.com-access_log
    CustomLog /var/log/apache2/example-ssl_request_log   ssl_combined

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl.crt/example-ssl.com-server.crt
    SSLCertificateKeyFile /etc/apache2/ssl.key/example-ssl.com-server.key
    SSLCertificateChainFile /etc/apache2/ssl.crt/example-ssl.com-ca.crt

    <Directory \"/srv/www/vhosts/example-ssl.com\">
    Options Indexes FollowSymLinks
    AllowOverride None
    <IfModule !mod_access_compat.c>
        Require all granted
    </IfModule>
    <IfModule mod_access_compat.c>
        Order allow,deny
        Allow from all
    </IfModule>
    </Directory>
</VirtualHost>

</IfDefine>
</IfDefine>
EOF
");
    assert_script_run("cat $vhost_ssl_conf_path | grep SSLCertificate");
    assert_script_run("sed -i \"/^APACHE_SERVER_FLAGS=*/c\\APACHE_SERVER_FLAGS=\\\"SSL\\\"\" /etc/sysconfig/apache2");
    assert_script_run('cat /etc/sysconfig/apache2 | grep APACHE_SERVER_FLAGS=');
    save_screenshot;

    # Setup subversion configration for apache
    my $svn_conf_file = '/etc/apache2/conf.d/subversion.conf';
    type_string("cat >> $svn_conf_file << EOF
LoadModule dav_module       /usr/lib64/apache2/mod_dav.so
LoadModule dav_svn_module   /usr/lib64/apache2/mod_dav_svn.so
<IfModule mod_dav_svn.c>
<Location /repos>
    DAV svn
    SVNPath /srv/svn/repos
</Location>
</IfModule>
EOF
");
    systemctl('restart apache2');
    systemctl('status apache2');

    # Create test repository
    assert_script_run('mkdir -p /srv/svn/ && cd /srv/svn/');
    assert_script_run('svnadmin create repos');
    assert_script_run('chown -R wwwrun:wwwrun repos');
    # Layout test repo
    assert_script_run('cd /tmp && mkdir mytestproj && cd mytestproj');
    assert_script_run('mkdir configurations options main');
    # Create some test files
    assert_script_run('echo "testconf1" > configurations/testconf1.cfg');
    assert_script_run('echo "testopts1" > options/testopts1.cfg');
    assert_script_run('echo "mainfile1" > main/mainfile1.cfg');
    # Import test repo
    validate_script_output('svn import /tmp/mytestproj/ file:///srv/svn/repos/mytestproj -m "Init commit"', sub { m/Committed/ });
    # Check the repo
    enter_cmd('svn ls https://localhost/repos');
    wait_still_screen(5);
    # Allow the certificate permanently
    enter_cmd('p');
    wait_still_screen(5);

    # Checkout SVN repo
    assert_script_run('cd');
    validate_script_output('svn co https://localhost/repos/mytestproj/', sub { m/Checked out revision/ });
    assert_script_run('cd mytestproj && echo "newline" >> configurations/testconf1.cfg');
    validate_script_output('svn commit -m "Add a new line to testconf1.cfg"', sub { m/Committed/ });
    # Add or delete items
    assert_script_run('cd && rm -rf mytestproj');
    validate_script_output('svn co https://localhost/repos/mytestproj/', sub { m/Checked out revision/ });
    assert_script_run('cd mytestproj && cp /etc/hosts configurations/');
    validate_script_output('svn add configurations/hosts', sub { m/configurations\/hosts/ });
    validate_script_output('svn commit -m "Add hosts file"', sub { m/Committed/ });
    validate_script_output('svn delete configurations/testconf1.cfg', sub { m/configurations\/testconf1.cfg/ });
    validate_script_output('svn commit -m "Delete testconf1.cfg file"', sub { m/Committed/ });
    validate_script_output('svn ls https://localhost/repos/mytestproj/configurations/', sub { m/hosts/ });

    # Clean up
    assert_script_run('cd && rm -rf mytestproj');
}

1;
