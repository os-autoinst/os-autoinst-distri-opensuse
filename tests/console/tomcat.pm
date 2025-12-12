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
use version_utils qw(is_sle is_opensuse);

sub run() {

    my ($self) = shift;
    select_serial_terminal();

    # install and configure tomcat in console
    Tomcat::Utils->tomcat_setup(get_var('TOMCAT_VER', ''));

    # verify that the tomcat manager works
    Tomcat::Utils->tomcat_manager_test();

    if (is_sle('>=16') || is_opensuse) {
        Tomcat::ApacheProxyTest->mod_proxy_setup();
    }

    if (is_sle('<=16') || is_opensuse) {
        # Install and configure apache2 and apache2-mod_jk connector
        Tomcat::ModjkTest->mod_jk_setup();

        # Connection from apache2 to tomcat: Functionality test
        Tomcat::ModjkTest->func_conn_apache2_tomcat();
    }

}

1;
