# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provide the functionality for apache2 apache2-mod_jk installation
# and configuration to tests regarding interaction between tomcat and apache2
# via apache2-mod_jk package
# Maintainer: QE Core <qe-core@suse.de>

package Tomcat::ModjkTest;
use base "x11test";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';
use registration;

# install and configure apache2, apache2-mod_jk and verify the interaction between apache2 and tomcat
# via the package apache2-mod_jk
sub mod_jk_setup() {
    my $self = shift;
    select_serial_terminal();

    record_info('install and configure apache2 and apache2-mod_jk connector Setup');
    zypper_call('in apache2 apache2-mod_jk');

    $self->conn_apache2_tomcat();
    $self->load_jk_module();
}

# Connection from apache2 to tomcat: Functionality test
sub func_conn_apache2_tomcat() {
    select_serial_terminal();
    systemctl('stop apache2');
    systemctl('stop tomcat');
    assert_script_run(
        "echo  \"\$(cat <<EOF
JkMount /*       ajp13
JkMount /*.jsp   ajp13
JkMount /*.xhtml ajp13
EOF
        )\"  >> /etc/apache2/conf.d/jk.conf", timeout => 180
    );
    systemctl('start apache2');
    systemctl('status apache2');

    systemctl('start tomcat');
    systemctl('status tomcat');
}

# Connection from apache2 to tomcat: tomcat part and apache2 part
sub conn_apache2_tomcat() {
    systemctl('stop tomcat');

    # Define an AJP 1.3 Connector on IPv6 localhost port 8009
    my $ajp_connector = qq(    <Connector protocol="AJP/1.3" address="::1" port="8009" redirectPort="8443" \/>);
    assert_script_run qq(sed -i '/<\!-- Define an AJP 1.3 Connector on port 8009 -->/ a $ajp_connector\' /etc/tomcat/server.xml);

    # Define a worker "ajp13" which listens behind the above AJP 1.3 Connector address and port
    assert_script_run('cp /usr/share/doc/packages/apache2-mod_jk/workers.properties /etc/tomcat/workers.properties');
    assert_script_run(
        "echo \"\$(cat <<EOF
worker.list=ajp13
worker.ajp13.reference=worker.template
worker.ajp13.host=localhost
worker.ajp13.port=8009
EOF
        )\" >> /etc/tomcat/workers.properties", timeout => 180
    );

    # Connection from apache2 to tomcat: apache2 part
    systemctl('stop apache2');
    assert_script_run('cp -ai /usr/share/doc/packages/apache2-mod_jk/jk.conf /etc/apache2/conf.d');
    if (is_sle('=15') or is_sle('<12-sp4')) {
        # apache2-mod_jk package includes jk.conf is required to specify valid JkShmFile and Aliases.
        record_soft_failure 'boo#1167896 included jk.conf broken';
        assert_script_run(
            "echo \"\$(cat <<EOF
JkShmFile /var/log/tomcat/jk-runtime-status
EOF
        )\" >> /etc/apache2/conf.d/jk.conf", timeout => 180
        );
        assert_script_run("sed -i 's|servlets-examples|examples/servlets|g' /etc/apache2/conf.d/jk.conf");
        assert_script_run("sed -i 's|jsp-examples|examples/jsp|g' /etc/apache2/conf.d/jk.conf");
    }
    systemctl('start tomcat');
}

# Include mod_jk into the apache2 list of modules to load
sub load_jk_module() {
    assert_script_run('cp -a /etc/sysconfig/apache2 sysconfig.apache2-1-no.jk');
    # Configure inclusion of mod_jk into apache2 service
    assert_script_run('a2enmod jk');
    if ((script_run 'diff sysconfig.apache2-1-no.jk /etc/sysconfig/apache2') != 1) {
        die "failed to appended jk to the APACHE_MODULES line";
    }
    systemctl('start apache2');
    validate_script_output("apachectl -M | grep jk_module", sub { ".*jk_module.*" });
    validate_script_output("grep mod_jk /etc/apache2/sysconfig.d/loadmodule.conf", sub { "LoadModule jk_module.*" });
}

1;
