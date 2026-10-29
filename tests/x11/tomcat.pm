# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox tomcat tomcat-webapps tomcat-admin-webapps
# Summary: Tomcat regression test
# * install and configure tomcat
# * access tomcat manager web page
# * test all Servlet, JSP and WebSocket examples
# * install apache2-mod_jk
# * test the interaction between tomcat and apache2 via apache2-mod_jk
# * apache2-mod_jk is not avaialble on sle16, so we use proxy instead
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Tomcat::Utils;
use Tomcat::ModjkTest;
use Tomcat::ApacheProxyTest;
use utils;
use version_utils 'is_sle';
use serial_terminal 'select_serial_terminal';

sub run() {
    my ($self) = shift;
    select_serial_terminal;
    my ($build) = get_var('BUILD', '') =~ /(tomcat\d*)/;
    my $tomcat_ver = get_var('TOMCAT_VER', '');
    # Resolve pkg version: only 9 becomes 'tomcat', rest become 'tomcat$tomcat_ver'
    my $matching_version = ($tomcat_ver eq '9') ? 'tomcat' : "tomcat$tomcat_ver";
    if ((!defined $build || $build ne $matching_version) && get_var('BUILD', '') =~ /\d*\:tomcat/) {
        record_info('Skip test', "Update $build does not match $matching_version test");
        return;
    }
    # install and configure tomcat in console
    Tomcat::Utils->tomcat_setup($matching_version);

    # verify that the tomcat manager works
    Tomcat::Utils->tomcat_manager_test();

    if (is_sle('>=16')) {
        Tomcat::ApacheProxyTest->mod_proxy_setup();
    }
    else {
        # Install and configure apache2 and apache2-mod_jk connector
        Tomcat::ModjkTest->mod_jk_setup();

        # Connection from apache2 to tomcat: Functionality test
        Tomcat::ModjkTest->func_conn_apache2_tomcat();
    }
}

1;
