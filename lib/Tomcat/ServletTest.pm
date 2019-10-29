# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the tomcat Servlet examples
# Maintainer: George Gkioulis <ggkioulis@suse.com>

package Tomcat::ServletTest;
use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use Tomcat::Utils;
use version_utils 'is_sle';

# allow a TIMEOUT second timeout for asserting needles
use constant TIMEOUT => 60;

# test all Servlet examples
sub test_all_examples() {
    my ($self) = shift;

    # array with example test function and number of tabs required to select the example
    # the two servlet 4.0 examples are skipped
    my @servlet_examples = ([\&hello, 2], [\&request_information, 4], [\&request_header, 4], [\&request_parameters, 4], [\&cookies, 4], [\&sessions, 4], [\&async0, 3], [\&async1, 1], [\&async2, 1], [\&async3, 1], [\&stocksticker, 1], [\&byte_counter, is_sle('<12-sp4') ? 2 : 1], [\&number_writer, 1]);

    # access the tomcat servlets examples page
    $self->firefox_open_url('localhost:8080/examples/servlets');
    send_key_until_needlematch('tomcat-servlet-examples-page', 'ret');

    # Navigate with keyboard to each example and test it
    for my $i (0 .. $#servlet_examples) {
        Tomcat::Utils->browse_with_keyboard('tomcat-servlet-fallback', $servlet_examples[$i][0], $servlet_examples[$i][1]);
    }
}


# test hello example
sub hello() {
    assert_screen('tomcat-hello-world-example', TIMEOUT);
}

# test request information example
sub request_information() {
    assert_screen('tomcat-request-information-example', TIMEOUT);
}

# test request header example
sub request_header() {
    assert_screen('tomcat-request-header-example', TIMEOUT);
}

# test request parameters example
sub request_parameters() {
    assert_screen('tomcat-request-parameters-example-start', TIMEOUT);
    assert_and_dclick('tomcat-request-parameters-example-1');
    send_key('left');
    type_string 'george';
    send_key('tab');
    type_string 'qam';
    send_key('ret');
    assert_screen('tomcat-request-parameters-example-2', TIMEOUT);
}

# test cookies example
sub cookies() {
    assert_screen('tomcat-cookies-example-start', TIMEOUT);
    assert_and_dclick('tomcat-cookies-example-1');
    send_key('left');
    type_string 'biscuit';
    send_key('tab');
    type_string '5';
    send_key('ret');
    assert_screen('tomcat-cookies-example-2', TIMEOUT);
}

# test sessions example
sub sessions() {
    assert_screen('tomcat-sessions-example-start', TIMEOUT);
    assert_and_dclick('tomcat-sessions-example-1');
    send_key('left');
    type_string('attr1');
    send_key('tab');
    type_string('1');
    send_key('ret');
    assert_screen('tomcat-sessions-example-result-1', TIMEOUT);
    assert_and_dclick('tomcat-sessions-example-2');
    type_string('attr2');
    send_key('tab');
    type_string('2');
    send_key('ret');
    assert_screen('tomcat-sessions-example-result-2', TIMEOUT);
}

# test async0 example
sub async0() {
    assert_screen('tomcat-async0-example', TIMEOUT);
}

# test async1 example
sub async1() {
    assert_screen('tomcat-async1-example', TIMEOUT);
}

# test async2 example
sub async2() {
    assert_screen('tomcat-async2-example', TIMEOUT);
}

# test async3 example
sub async3() {
    assert_screen('tomcat-async3-example', TIMEOUT);
}

# test stocksticker
sub stocksticker() {
    assert_screen('tomcat-stocksticker-example', TIMEOUT);
}

# test byte counter example
sub byte_counter() {
    assert_screen('tomcat-byte-counter-start', TIMEOUT);
    assert_and_dclick('tomcat-byte-counter-example');
    send_key('left');
    type_string('test');
    for (1 .. 2) { send_key('tab'); }
    send_key('ret');
    assert_screen('tomcat-byte-counter-example-result', TIMEOUT);
}

# test number writer example
sub number_writer() {
    assert_screen('tomcat-number-writer-example', TIMEOUT);
}

1;
