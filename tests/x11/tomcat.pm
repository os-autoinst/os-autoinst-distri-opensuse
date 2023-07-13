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
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Tomcat::Utils;
use Tomcat::ModjkTest;
use utils;
use version_utils 'is_sle';
use x11utils qw(turn_off_screensaver);

sub run() {

    my ($self) = shift;
    # install and configure tomcat in console
    turn_off_screensaver;
    Tomcat::Utils->tomcat_setup();

    # verify that the tomcat manager works
    Tomcat::Utils->tomcat_manager_test();

    # Install and configure apache2 and apache2-mod_jk connector
    Tomcat::ModjkTest->mod_jk_setup();

    # Connection from apache2 to tomcat: Functionality test
    Tomcat::ModjkTest->func_conn_apache2_tomcat();

    # switch to desktop
    Tomcat::Utils->switch_to_desktop();
}

1;
