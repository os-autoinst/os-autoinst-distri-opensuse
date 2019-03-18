# SUSE's Apache tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package apachetest;

use base Exporter;
use Exporter;

use strict;
use warnings;

use testapi;
use utils;
use version_utils 'is_sle';

our @EXPORT = qw(setup_apache2 setup_pgsqldb destroy_pgsqldb test_pgsql test_mysql);

# Setup apache2 service in different mode: SSL, NSS, NSSFIPS, PHP7
# Example: setup_apache2(mode => 'SSL');
sub setup_apache2 {
    my %args      = @_;
    my $mode      = uc $args{mode} || "";
    my $nsspasswd = "httptest";
    my @packages  = qw(apache2);

    if (($mode eq "NSS") && get_var("FIPS")) {
        $mode = "NSSFIPS";
    }
    if ($mode =~ m/NSS/) {
        push @packages, qw(apache2-mod_nss mozilla-nss-tools expect);
    }

    if ($mode eq "PHP7") {
        push @packages, qw(apache2-mod_php7 php7);
        zypper_call("rm -u apache2-mod_php5 php5", exitcode => [0, 104]);
    }

    # Make sure the packages are installed
    zypper_call("in @packages");

    # Enable php7
    if ($mode eq "PHP7") {
        assert_script_run 'a2enmod -d php5';
        assert_script_run 'a2enmod php7';
    }

    # Enable the ssl
    if ($mode eq "SSL") {
        assert_script_run 'a2enmod ssl';
    }
    elsif ($mode =~ m/NSS/) {
        # mod_nss is conflict with mod_ssl
        assert_script_run 'a2dismod ssl';
        assert_script_run 'a2enmod nss';
    }
    if ($mode =~ m/SSL|NSS/) {
        assert_script_run "sed -i '/^APACHE_SERVER_FLAGS=/s/^/#/' /etc/sysconfig/apache2";
        assert_script_run 'echo APACHE_SERVER_FLAGS="SSL" >> /etc/sysconfig/apache2';
    }
    # Create x509 certificate for this apache server
    if ($mode eq "SSL") {
        my $gensslcert_C_opt = !is_sle('15+') ? '-C $(hostname)' : '';
        assert_script_run "gensslcert -n \$(hostname) $gensslcert_C_opt -e webmaster@\$(hostname)", 900;
        assert_script_run 'ls /etc/apache2/ssl.crt/$(hostname)-server.crt /etc/apache2/ssl.key/$(hostname)-server.key';
    }

    # Check server certificate is available, which should be generated during apache2-mod_nss installation
    if ($mode =~ m/NSS/) {
        assert_script_run 'certutil -d /etc/apache2/mod_nss.d/ -L -n Server-Cert';
    }

    # Prepare vhost file
    script_run 'for x in /etc/apache2/vhosts.d/*.conf; do mv $x ${x}.save; done';
    if ($mode eq "SSL") {
        my $file = '/etc/apache2/vhosts.d/vhost-ssl.conf';
        assert_script_run "cp /etc/apache2/vhosts.d/vhost-ssl.template $file";
        assert_script_run 'sed -i "s|\(^[[:space:]]*SSLCertificateFile\).*|\1 /etc/apache2/ssl.crt/$(hostname)-server.crt|g" ' . $file;
        assert_script_run 'sed -i "s|\(^[[:space:]]*SSLCertificateKeyFile\).*|\1 /etc/apache2/ssl.key/$(hostname)-server.key|g" ' . $file;
    }
    elsif ($mode =~ m/NSS/) {
        script_run 'grep "^Include .*mod_nss.d" /etc/apache2/conf.d/mod_nss.conf && touch /etc/apache2/mod_nss.d/test.conf';
        assert_script_run 'cp /etc/apache2/vhosts.d/vhost-nss.template /etc/apache2/vhosts.d/vhost-nss.conf';
        if ($mode eq "NSSFIPS") {
            assert_script_run "sed -i '/NSSEngine/a NSSFips on' /etc/apache2/vhosts.d/vhost-nss.conf";
        }
    }
    else {
        assert_script_run 'cp /etc/apache2/vhosts.d/vhost.template /etc/apache2/vhosts.d/vhost.conf';
    }
    my $files = '/etc/apache2/vhosts.d/vhost*.conf';
    assert_script_run 'sed -i -e "/^[[:space:]]*ServerAdmin/s/^/#/g" -e "/^[[:space:]]*ServerName/s/^/#/g" -e "/^[[:space:]]*DocumentRoot/s/^/#/g" ' . $files;
    assert_script_run 'sed -i "/^<VirtualHost/a ServerAdmin webmaster@$(hostname)\nServerName $(hostname)\nDocumentRoot /srv/www/htdocs/\n" ' . $files;

    # Start apache service
    systemctl 'stop apache2';
    if ($mode eq "NSS") {
        assert_script_run "expect -c 'spawn systemctl start apache2; expect \"Enter SSL pass phrase for internal (NSS)\"; send \"$nsspasswd\\n\"; interact'";
    }
    elsif ($mode eq "NSSFIPS") {
        assert_script_run
"expect -c 'spawn systemctl start apache2; expect \"Enter SSL pass phrase for NSS FIPS 140-2 Certificate DB (NSS)\"; send \"$nsspasswd\\n\"; interact'";
    }
    else {
        systemctl 'start apache2';
    }
    systemctl 'is-active apache2';

    # Create a test html page
    assert_script_run 'echo "<html><h2>Hello Linux</h2></html>" > /srv/www/htdocs/hello.html';

    # create a test php page
    assert_script_run qq{echo -e "<?php\nphpinfo()\n?>" > /srv/www/htdocs/index.php};

    # Verify apache+ssl works
    my $curl_option = ($mode =~ m/SSL|NSS/) ? '-k https' : 'http';
    assert_script_run "curl $curl_option://localhost/hello.html | grep 'Hello Linux'";

    if ($mode =~ /PHP5|PHP7/) {
        assert_script_run "curl --no-buffer http://localhost/index.php | grep \"\$(uname -s -n -r -v -m)\"";
    }
}
sub setup_pgsqldb {
    # without changing current working directory we get:
    # 'could not change directory to "/root": Permission denied'
    assert_script_run 'pushd /tmp';
    assert_script_run "curl " . data_url('console/postgres_openqadb.sql') . " -o /tmp/postgres_openqadb.sql";
    # requires running postgresql server
    # test basic functionality - require postgresql
    assert_script_run "sudo -u postgres psql -f /tmp/postgres_openqadb.sql";
    assert_script_run "sudo -u postgres psql -d openQAdb -c \"SELECT * FROM test\" | grep \"can you read this\"";

    assert_script_run 'popd';    # back to previous directory
}

sub destroy_pgsqldb {
    assert_script_run 'pushd /tmp';

    assert_script_run "sudo -u postgres dropdb openQAdb";

    assert_script_run 'popd';    # back to previous directory
}

sub test_pgsql {
    # configuration so that PHP can access PostgreSQL
    # setup password
    type_string "sudo -u postgres psql postgres\n";
    wait_still_screen(1);
    type_string "\\password postgres\n";
    wait_still_screen(1);
    type_string "postgres\n";
    wait_still_screen(1);
    type_string "postgres\n";
    wait_still_screen(1);
    type_string "\\q\n";
    wait_still_screen(1);
    # comment out default configuration
    assert_script_run "sed -i 's/^host/#host/g' /var/lib/pgsql/data/pg_hba.conf";
    # allow postgres to access the db with password authentication
    assert_script_run "echo 'host openQAdb postgres 127.0.0.1/32 password' >> /var/lib/pgsql/data/pg_hba.conf";
    assert_script_run "echo 'host openQAdb postgres      ::1/128 password' >> /var/lib/pgsql/data/pg_hba.conf";
    systemctl 'restart postgresql.service';

    # configure the PHP code that:
    #  1. reads table 'test' from the 'openQAdb' database (created in 'console/postgresql...' test)
    #  2. inserts a new element 'can php write this?' into the same table
    type_string "curl " . data_url('console/test_postgresql_connector.php') . " -o /srv/www/htdocs/test_postgresql_connector.php\n";
    systemctl 'restart apache2.service';

    # access the website and verify that it can read the database
    assert_script_run "curl --no-buffer http://localhost/test_postgresql_connector.php | grep 'can you read this?'";

    # verify that PHP successfully wrote the element in the database
    assert_script_run "sudo -u postgres psql -d openQAdb -c \"SELECT * FROM test\" | grep 'can php write this?'";

    # add sudo rights to switch postgresql version and run script to determine oldest and latest version
    assert_script_run 'echo "postgres ALL=(root) NOPASSWD: ALL" >>/etc/sudoers';
    assert_script_run "gpasswd -a postgres \$(stat -c %G /dev/$serialdev)";
    type_string "su - postgres\n", wait_still_screen => 1;
    type_string "PS1='# '\n",      wait_still_screen => 1;
    # upgrade db from oldest version to latest version
    if (script_run('test $(sudo update-alternatives --list postgresql|wc -l) -gt 1') == 0) {
        assert_script_run 'for v in $(sudo update-alternatives --list postgresql); do rpm -q ${v##*/};done';
        # due to orderless numbering untill version 94 is gone
        my $pg_versions = <<'EOF';
#!/bin/bash
PG_VER=$(update-alternatives --list postgresql)
if [[ $(echo $PG_VER|grep 94) ]]; then
    export PG_OLDEST='postgresql94'
elif [[ $(echo $PG_VER|grep 96) ]]; then
    export PG_OLDEST='postgresql96'
elif [[ $(echo $PG_VER|grep 10) ]]; then
    export PG_OLDEST='postgresql10'
elif [[ $(echo $PG_VER|grep 11) ]]; then
    export PG_OLDEST='postgresql11'
fi
echo PG_OLDEST=/usr/lib/$PG_OLDEST >/tmp/pg_versions
if [[ $(echo $PG_VER|grep 11) ]]; then
    export PG_LATEST='postgresql11'
elif [[ $(echo $PG_VER|grep 10) ]]; then
    export PG_LATEST='postgresql10'
elif [[ $(echo $PG_VER|grep 96) ]]; then
    export PG_LATEST='postgresql96'
elif [[ $(echo $PG_VER|grep 94) ]]; then
    export PG_LATEST='postgresql94'
fi
echo PG_LATEST=/usr/lib/$PG_LATEST >>/tmp/pg_versions
EOF
        script_run "echo '$pg_versions' > pg_versions.sh";
        assert_script_run 'pg_ctl -D /var/lib/pgsql/data stop';
        assert_script_run 'sudo bash pg_versions.sh && . /tmp/pg_versions';
        assert_script_run 'sudo update-alternatives --set postgresql $PG_OLDEST';
        assert_script_run 'initdb -D /tmp/psql';
        assert_script_run 'pg_ctl -D /tmp/psql start';
        assert_script_run 'pg_ctl -D /tmp/psql status';
        assert_script_run 'pg_ctl -D /tmp/psql stop';
        assert_script_run 'sudo update-alternatives --set postgresql $PG_LATEST';
        assert_script_run 'initdb -D /var/lib/pgsql/data2';
        assert_script_run 'pg_upgrade -b $PG_OLDEST/bin/ -B $PG_LATEST/bin/ -d /tmp/psql -D /var/lib/pgsql/data2';
        assert_script_run 'pg_ctl -D /var/lib/pgsql/data start';
        assert_script_run './analyze_new_cluster.sh';
        assert_script_run './delete_old_cluster.sh';
    }
    # turn off pager, othwerwise assert_script_run can time out
    assert_script_run 'export PAGER=cat';
    assert_script_run 'alias p="psql -E"';
    assert_script_run 'curl -O ' . data_url('console/dvdrental.zip');
    assert_script_run 'unzip dvdrental.zip';
    assert_script_run 'p -c "CREATE DATABASE dvdrental"';
    assert_script_run 'psql -a -E -c "\l"|grep dvdrental';
    assert_script_run 'pg_restore -d dvdrental -1 dvdrental.tar';
    assert_script_run 'p -d dvdrental -c "\dt"';
    assert_script_run 'p -d dvdrental -c "SELECT * FROM customer"|grep Davidson';
    assert_script_run 'p -d dvdrental -c "INSERT INTO customer VALUES (\'600\', \'1\', \'openQA\', \'openQA\', \'openqa@openqa.com\', \'1\')"';
    assert_script_run 'pg_dump --format=t dvdrental > dvdrental_dump.tar';
    assert_script_run 'dropdb dvdrental';
    assert_script_run 'p -c "CREATE DATABASE dvdrental"';
    assert_script_run 'p -c "\l"|grep dvdrental';
    assert_script_run 'pg_restore -d dvdrental -1 dvdrental_dump.tar';
    # check if db contains old and new table row
    assert_script_run 'p -d dvdrental -c "SELECT * FROM customer WHERE first_name = \'openQA\'"|grep openQA';
    assert_script_run 'p -d dvdrental -c "SELECT * FROM customer WHERE last_name = \'Davidson\'"|grep Davidson';
    type_string "exit\n", wait_still_screen => 1;
}

sub test_mysql {
    # create the 'openQAdb' database with table 'test' and insert one element 'can php read this?'
    assert_script_run
qq{mysql -u root -e "CREATE DATABASE openQAdb; USE openQAdb; CREATE TABLE test (id int NOT NULL AUTO_INCREMENT, entry varchar(255) NOT NULL, PRIMARY KEY(id)); INSERT INTO test (entry) VALUE ('can you read this?');"};

    # configure the PHP code that:
    #  1. reads table 'test' from the 'openQAdb' database
    #  2. inserts a new element 'can php write this?' into the same table
    assert_script_run "curl " . data_url('console/test_mysql_connector.php') . " -o /srv/www/htdocs/test_mysql_connector.php";
    systemctl 'restart apache2.service';

    # access the website and verify that it can read the database
    assert_script_run "curl --no-buffer http://localhost/test_mysql_connector.php | grep 'can you read this?'";

    # verify that PHP successfully wrote the element in the database
    assert_script_run "mysql -u root -e 'USE openQAdb; SELECT * FROM test;' | grep 'can php write this?'";

    assert_script_run qq{mysql -u root -e "DROP DATABASE openQAdb;"};
}

1;
