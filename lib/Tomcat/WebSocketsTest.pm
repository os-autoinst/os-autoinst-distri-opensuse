# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the tomcat WebSocket examples
# Maintainer: George Gkioulis <ggkioulis@suse.com>

package Tomcat::WebSocketsTest;
use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use Tomcat::Utils;

# allow a 60 second timeout for asserting needles
use constant TIMEOUT => 90;

# test all WebSocket examples
sub test_all_examples() {
    my ($self) = shift;

    # array with example test function and number of tabs required to select the example
    my @websocket_examples = ([\&echo, 1], [\&chat, 1], [\&snake, 1]);

    # access the tomcat websocket examples page
    $self->firefox_open_url('localhost:8080/examples/websocket');
    send_key_until_needlematch('tomcat-websocket-examples', 'ret');

    # Navigate with keyboard to each example and test it
    for my $i (0 .. $#websocket_examples) {
        Tomcat::Utils->browse_with_keyboard('tomcat-websocket-examples', $websocket_examples[$i][0], $websocket_examples[$i][1]);
    }
}


# test echo example
sub echo() {
    assert_screen('tomcat-echo-example-loaded', TIMEOUT);
    assert_and_click('tomcat-echo-example-select');
    assert_and_click('tomcat-echo-example-connect');
    assert_and_click('tomcat-echo-example-message');
    assert_screen('tomcat-echo-example', TIMEOUT);
}

# test chat example
sub chat() {
    assert_screen('tomcat-chat-example-loaded', TIMEOUT);
    send_key('tab');
    type_string('test');
    send_key('ret');
    assert_screen('tomcat-chat-example', TIMEOUT);
}

# test snake example
sub snake() {
    assert_screen('tomcat-snake-example-loaded', TIMEOUT);
    send_key('right');
    send_key('down');
    assert_screen('tomcat-snake-example', TIMEOUT);
}

1;
