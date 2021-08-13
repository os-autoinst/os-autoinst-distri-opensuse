# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
use Tomcat::ServletTest;
use Tomcat::JspTest;
use Tomcat::WebSocketsTest;
use Tomcat::Utils;
use Tomcat::ModjkTest;
use utils;
use version_utils 'is_sle';
use x11utils 'ensure_unlocked_desktop';

sub run() {

    my ($self) = shift;
    # install and configure tomcat in console
    Tomcat::Utils->tomcat_setup();

    # switch to desktop
    $self->switch_to_desktop();

    # start firefox
    $self->start_firefox_with_profile();

    # check that the tomcat web service works
    $self->firefox_open_url('localhost:8080');
    send_key_until_needlematch('tomcat-succesfully-installed', 'ret');

    # verify that the tomcat manager page works
    Tomcat::Utils->tomcat_manager_test($self);

    # Servlet testing
    record_info('Servlet Testing');
    my $servlet_test = Tomcat::ServletTest->new();
    $servlet_test->test_all_examples();

    # JSP testing
    record_info('JSP Testing');
    my $jsp_test = Tomcat::JspTest->new();
    $jsp_test->test_all_examples();

    # WebSocket testing
    record_info('WebSocket Testing');
    my $websocket_test = Tomcat::WebSocketsTest->new();
    $websocket_test->test_all_examples();

    # Install and configure apache2 and apache2-mod_jk connector
    Tomcat::ModjkTest->mod_jk_setup();
    $self->switch_to_desktop();

    $self->firefox_open_url('http://localhost/examples/servlets');
    send_key_until_needlematch('tomcat-servlet-examples-page', 'ret');

    $self->firefox_open_url('http://localhost/examples/jsp');
    send_key_until_needlematch('tomcat-jsp-examples', 'ret');

    $self->select_serial_terminal();
    systemctl('start tomcat');

    record_info("Test modjk");

    my $with_modjk = 1;
    $self->switch_to_desktop();

    record_info('Servlet Testing');
    $servlet_test->test_all_examples($with_modjk);

    record_info('JSP Testing');
    $jsp_test->test_all_examples($with_modjk);

    # Connection from apache2 to tomcat: Functionality test
    Tomcat::ModjkTest->func_conn_apache2_tomcat();

    # switch to desktop
    $self->switch_to_desktop();

    $self->firefox_open_url('http://localhost');
    send_key_until_needlematch('tomcat-succesfully-installed', 'ret');

    $self->firefox_open_url('http://localhost:8080');
    send_key_until_needlematch('tomcat-succesfully-installed', 'ret');

    $self->close_firefox();
    assert_screen('generic-desktop');

}

sub switch_to_desktop {

    # switch to desktop
    if (!check_var('DESKTOP', 'textmode')) {
        select_console('x11', await_console => 0);
        ensure_unlocked_desktop;
    }
}

sub close_firefox {

    # close firefox
    send_key('alt-f4');

    # delete firefox.log and close xterm
    send_key('alt-tab');
    send_key('ret');
    type_string_slow 'rm firefox.log';
    send_key('ret');
    type_string_slow 'killall xterm';
    send_key('ret');
}

1;
