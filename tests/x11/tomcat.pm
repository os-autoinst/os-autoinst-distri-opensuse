# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Tomcat regression test
# * install and configure tomcat
# * access tomcat manager web page
# * test all Servlet, JSP and WebSocket examples
# Maintainer: George Gkioulis <ggkioulis@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use Tomcat::ServletTest;
use Tomcat::JspTest;
use Tomcat::WebSocketsTest;
use Tomcat::Utils;
use utils;
use x11utils 'ensure_unlocked_desktop';

sub run() {
    my ($self) = shift;

    # install and configure tomcat in console
    Tomcat::Utils->tomcat_setup();

    # switch to desktop
    if (!check_var('DESKTOP', 'textmode')) {
        select_console('x11', await_console => 0);
        ensure_unlocked_desktop;
    }

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


    # close firefox
    send_key('alt-f4');

    # delete firefox.log and close xterm
    send_key('alt-tab');
    send_key('ret');
    type_string_slow 'rm firefox.log';
    send_key('ret');
    type_string_slow 'killall xterm';
    send_key('ret');

    assert_screen('generic-desktop');
}

1;
