# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup Apache2 with SSL enabled and test libserf by using SVN.
# This test validates libserf’s handling of HTTPS, authentication, SSL certs,
# and common SVN operations (checkout, update, commit, diff, log).
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110434, tc#1769948, poo#112550

use base 'consoletest';
use testapi;
use utils;
use Utils::Architectures;
use Utils::Logging qw(tar_and_upload_log);
use serial_terminal 'select_serial_terminal';

my $server_name = 'example-ssl.com';
my $repo_root = '/srv/www/svn/repos';
my $test_project = 'mytestproj';
my $vhost_ssl_conf = '/etc/apache2/vhosts.d/vhost-ssl.conf';
my $svn_conf_file = '/etc/apache2/conf.d/subversion.conf';
my $svn_user = 'testuser';
my $svn_pass = 'testpass';
my $svn_url = "https://$server_name/repos/$test_project";

sub setup_apache {
    zypper_call('in apache2 subversion-server openssl');

    # Host entries for local testing
    assert_script_run("echo '127.0.0.1 $server_name localhost' > /etc/hosts");
    assert_script_run("echo 'ServerName $server_name' > /etc/apache2/conf.d/fqdn.conf");
    assert_script_run("test -d /srv/www/vhosts/$server_name || mkdir -p /srv/www/vhosts/$server_name");

    # Generate self-signed certificate (CN = $server_name)
    assert_script_run("gensslcert -n $server_name -e webmaster\@$server_name -a DNS:example-ssl.com");
    # Configure SSL vhost
    type_string("cat >> $vhost_ssl_conf <<EOF
<IfDefine SSL>
<VirtualHost _default_:443>
    DocumentRoot \"/srv/www/vhosts/$server_name\"
    ServerName $server_name
    ServerAdmin webmaster\@$server_name
    ErrorLog /var/log/apache2/$server_name-error_log
    TransferLog /var/log/apache2/$server_name-access_log
    CustomLog /var/log/apache2/$server_name-ssl_request_log ssl_combined

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl.crt/$server_name-server.crt
    SSLCertificateKeyFile /etc/apache2/ssl.key/$server_name-server.key

    <Directory \"/srv/www/vhosts/$server_name\">
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
</IfDefine>
EOF
");

    # Force Apache SSL
    assert_script_run("sed -i '/^APACHE_SERVER_FLAGS=*/c\\APACHE_SERVER_FLAGS=\"SSL\"' /etc/sysconfig/apache2");
    # Appen dav modules to APACHE_MODULES
    assert_script_run("sed -i 's/^APACHE_MODULES=\"\\(.*\\)\"/APACHE_MODULES=\"\\1 dav dav_fs dav_lock dav_svn\"/' /etc/sysconfig/apache2");
}

sub setup_svn {
    # Configure SVN auth
    assert_script_run("htpasswd -cb /etc/apache2/svn.passwd $svn_user $svn_pass");

    type_string("cat >> $svn_conf_file <<EOF
<IfModule mod_dav_svn.c>
<Location /repos>
    DAV svn
    SVNPath $repo_root
    AuthType Basic
    AuthName \"SVN Repo\"
    AuthUserFile /etc/apache2/svn.passwd
    Require valid-user
</Location>
</IfModule>
EOF
");

    # Start Apache
    systemctl('restart apache2');
    systemctl('is-active apache2');

    assert_script_run('a2enmod -l | grep dav');

    # Create SVN repository
    assert_script_run("mkdir -pZ $repo_root");
    assert_script_run("svnadmin create $repo_root");
    assert_script_run("chown -R wwwrun:wwwrun $repo_root");

    # Import initial project structure
    assert_script_run("cd /tmp && rm -rf $test_project && mkdir $test_project && cd $test_project");
    assert_script_run('mkdir configurations options main');
    assert_script_run('echo "testconf1" > configurations/testconf1.cfg');
    assert_script_run('echo "testopts1" > options/testopts1.cfg');
    assert_script_run('echo "mainfile1" > main/mainfile1.cfg');
    validate_script_output(
        "svn import /tmp/$test_project/ file://$repo_root/$test_project -m \"Init commit\"",
        sub { m/Committed/ }
    );
    assert_script_run("chown -R wwwrun:wwwrun $repo_root/db/rep-cache.db*");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    setup_apache;
    setup_svn;

    my $svn_opts = "--username $svn_user --password $svn_pass --non-interactive --trust-server-cert";

    # SVN initial listing
    assert_script_run("svn ls $svn_url  $svn_opts");

    # Checkout + update + commit
    assert_script_run("cd && svn co $svn_url $svn_opts");
    assert_script_run("cd $test_project && echo 'newline' >> configurations/testconf1.cfg");
    validate_script_output("svn diff $svn_opts", sub { m/^\+newline/m });
    validate_script_output("svn commit -m 'Add a new line' $svn_opts", sub { m/Committed/ });
    assert_script_run("svn update $svn_opts");
    validate_script_output("svn log $svn_opts", sub { m/Add a new line/ });

    # Add + Delete files
    assert_script_run("cp /etc/hosts configurations/");
    validate_script_output("svn add configurations/hosts $svn_opts", sub { m/A\s+configurations\/hosts/ });
    validate_script_output("svn commit -m 'Add hosts file' $svn_opts", sub { m/Committed/ });
    validate_script_output("svn delete configurations/testconf1.cfg $svn_opts", sub { m/D\s+configurations\/testconf1.cfg/ });
    validate_script_output("svn commit -m 'Delete testconf1.cfg' $svn_opts", sub { m/Committed/ });

    # Concurrency test
    assert_script_run("cd && svn co $svn_url $test_project-2 $svn_opts");
    assert_script_run("cd $test_project-2 && echo 'from_second_wc' >> options/testopts1.cfg");
    validate_script_output("svn commit -m 'Commit from second WC' $svn_opts", sub { m/Committed/ });
    assert_script_run("cd ../$test_project && svn update $svn_opts");
    validate_script_output("grep from_second_wc options/testopts1.cfg", sub { m/from_second_wc/ });

    # TLS 1.2 enforcement
    assert_script_run("sed -i '/SSLEngine on/a SSLProtocol -all +TLSv1.2' $vhost_ssl_conf");
    systemctl('restart apache2');
    assert_script_run("openssl s_client -connect localhost:443 -tls1_2 -servername $server_name < /dev/null | grep 'SSL-Session'");
    assert_script_run("svn ls $svn_url $svn_opts");

    # Expired cert test
    script_run("gensslcert -n expired.$server_name -e webmaster\@$server_name -y 0");

    # Point the existing SSL vhost to the expired cert
    assert_script_run("sed -i 's#SSLCertificateFile .*#SSLCertificateFile /etc/apache2/ssl.crt/expired.$server_name-server.crt#' $vhost_ssl_conf");
    assert_script_run("sed -i 's#SSLCertificateKeyFile .*#SSLCertificateKeyFile /etc/apache2/ssl.key/expired.$server_name-server.key#' $vhost_ssl_conf");
    systemctl('restart apache2');
    systemctl('is-active apache2');

    validate_script_output("svn ls $svn_url $svn_opts 2>&1", sub { m/SSL certificate verification failed: certificate has expired/ }, proceed_on_failure => 1);

    # Cleanup
    assert_script_run("cd && rm -rf $test_project $test_project-2");
    assert_script_run("rm -f /etc/apache2/ssl.crt/$server_name* /etc/apache2/ssl.key/$server_name*");
    assert_script_run("rm -f /etc/apache2/ssl.crt/expired.$server_name* /etc/apache2/ssl.key/expired.$server_name*");
}

sub post_fail_hook {
    my ($self) = @_;
    select_console('log-console');
    tar_and_upload_log('/var/log/apache2', '/tmp/apache-logs.tar.bz2');
    tar_and_upload_log($repo_root, '/tmp/svn-repo.tar.bz2');
    upload_logs($vhost_ssl_conf);
    upload_logs($svn_conf_file);
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {always_rollback => 1};
}

1;
