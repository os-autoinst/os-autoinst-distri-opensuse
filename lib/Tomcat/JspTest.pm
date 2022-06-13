# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the tomcat JSP examples
# Maintainer: QE Core <qe-core@suse.de>

package Tomcat::JspTest;
use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use Tomcat::Utils;
use version_utils 'is_sle';

# allow a 60 second timeout for asserting needles
use constant TIMEOUT => 60;

# test all JSP examples
sub test_all_examples() {
    my ($self, $mod_jk) = @_;

    # array with example test function and number of tabs required to select the example
    # shuffle example is skipped
    my @jsp_examples = ([\&basic_arithmetics, 2], [\&basic_comparisons, 4], [\&implicit_objects, 4], [\&functions, 4], [\&composite_expressions, 4], [\&hello_world_tag, 4]);
    if (!$mod_jk) {
        push(@jsp_examples, ([\&repeat_simple_tag, 4], [\&book_tag, 4], [\&tag_file, 4], [\&panel_tag, 4], [\&display_product, 4], [\&xhtml_basic, 4], [\&attribute_body, 8], [\&dynamic_attributes, 8], [\&jsp_configuration, 4], [\&number_guess, 4], [\&date, 4], [\&snoop, 4], [\&error, 4], [\&carts, 4], [\&checkbox, 4], [\&color, 4], [\&calendar, 4], [\&include, 4], [\&forward, 4], [\&plugin, 4], [\&servlet_jsp, 4], [\&simple_tag, 4], [\&jsp_xml, 4], [\&if, 4], [\&foreach, 4], [\&choose, 4], [\&form, 4]));
    }

    # access the tomcat jsp examples page
    if ($mod_jk) {
        $self->firefox_open_url('localhost/examples/jsp');
    } else {
        $self->firefox_open_url('localhost:8080/examples/jsp');
    }
    send_key_until_needlematch('tomcat-jsp-examples', 'ret');

    # Navigate with keyboard to each example and test it
    for my $i (0 .. $#jsp_examples) {
        Tomcat::Utils->browse_with_keyboard('tomcat-jsp-fallback', $jsp_examples[$i][0], $jsp_examples[$i][1]);
    }
    # test xhtml svg example
    if (!$mod_jk) {
        $self->firefox_open_url('localhost:8080/examples/jsp/jsp2/jspx/textRotate.jspx?name=testing');
        send_key_until_needlematch('tomcat-xhtml-svg', 'ret');
    }
}


# test basic arithmetics example
sub basic_arithmetics() {
    assert_screen('tomcat-jsp-basic-arithmetics', TIMEOUT);
}

# test basic comparisons example
sub basic_comparisons() {
    assert_screen('tomcat-jsp-basic-comparisons', TIMEOUT);
}

# test implicit objects example
sub implicit_objects() {
    assert_screen('tomcat-jsp-implicit-objects', TIMEOUT);
    send_key('tab');
    type_string('test');
    send_key('ret');
    assert_screen('tomcat-jsp-implicit-objects-result', TIMEOUT);
}

# test functions example
sub functions() {
    assert_screen('tomcat-jsp-functions', TIMEOUT);
    send_key('tab');
    type_string('test');
    send_key('ret');
    assert_screen('tomcat-jsp-fuctions-result', TIMEOUT);
}

# test composite expressions example
sub composite_expressions() {
    assert_screen('tomcat-jsp-composite-expressions', TIMEOUT);
}

# test composite hello world tag example
sub hello_world_tag() {
    assert_screen('tomcat-hello-world-tag', TIMEOUT);
}

# test repeate simple tag example
sub repeat_simple_tag() {
    assert_screen('tomcat-repeat-simple-tag', TIMEOUT);
}

# test book tag example
sub book_tag() {
    assert_screen('tomcat-book-tag', TIMEOUT);
}

# test world tag file example
sub tag_file() {
    assert_screen('tomcat-hello-world-tag-file', TIMEOUT);
}

# test panels using tag files example
sub panel_tag() {
    assert_screen('tomcat-panels-using-tag-files', TIMEOUT);
}

# test display products tag file example
sub display_product() {
    assert_screen('tomcat-display-products-tag-file', TIMEOUT);
}

# test xhtml basic example
sub xhtml_basic() {
    assert_screen('tomcat-xhtml-basic', TIMEOUT);
}

# test attribute body example
sub attribute_body() {
    assert_screen('tomcat-attribute-body', TIMEOUT);
}

# test dynamic attributes example
sub dynamic_attributes() {
    assert_screen('tomcat-dynamic-attributes', TIMEOUT);
}

# test jsp configuration example
sub jsp_configuration() {
    assert_screen('tomcat-jsp-configuration', TIMEOUT);
}

# test number guess example
sub number_guess() {
    assert_screen('tomcat-number-guess', TIMEOUT);
    send_key('tab');
    type_string('0');
    send_key('ret');
    assert_screen('tomcat-number-guess-result', TIMEOUT);
}

# test date example
sub date() {
    assert_screen('tomcat-date-example', TIMEOUT);
}

# test snoop example
sub snoop() {
    assert_screen('tomcat-snoop-example', TIMEOUT);
}

# test error example
sub error() {
    assert_screen('tomcat-error-example', TIMEOUT);
    send_key('tab');
    for (1 .. 4) { send_key('down'); }
    send_key('tab');
    send_key('ret');
    assert_screen('tomcat-error-example-result', TIMEOUT);
}

# test carts example
sub carts() {
    assert_screen('tomcat-carts-example', TIMEOUT);
    send_key('tab');
    for (1 .. 4) { send_key('down'); }
    send_key('tab');
    send_key('ret');
    assert_screen('tomcat-carts-example-result', TIMEOUT);
}

# test checkbox example
sub checkbox() {
    assert_screen('tomcat-checkbox-example', TIMEOUT);
    for (1 .. 4) { send_key('tab'); }
    send_key('spc');
    send_key('ret');
    assert_screen('tomcat-checkbox-example-result', TIMEOUT);
}

# test color example
sub color() {
    assert_screen('tomcat-color-example', TIMEOUT);
    send_key('tab');
    type_string('red');
    send_key('ret');
    assert_screen('tomcat-color-example-result', TIMEOUT);
}

# test calendar example
sub calendar() {
    assert_screen('tomcat-calendar-example', TIMEOUT);
    send_key('tab');
    type_string('George');
    send_key('tab');
    type_string('test@test.test');
    send_key('ret');
    assert_screen('tomcat-calendar-example-result1', TIMEOUT);
    assert_and_click('tomcat-calendar-time');
    assert_screen('tomcat-calendar-event-confirmation', TIMEOUT);
    send_key('tab');
    type_string('test');
    send_key('ret');
    assert_screen('tomcat-calendar-example-result2', TIMEOUT);
}

# test include example
sub include() {
    assert_screen('tomcat-include-example', TIMEOUT);
}

# test forward example
sub forward() {
    assert_screen('tomcat-forward-example', TIMEOUT);
}

# test plugin example
sub plugin() {
    assert_screen('tomcat-plugin-example', TIMEOUT);
}

# test servlet-to-jsp example
sub servlet_jsp() {
    assert_screen('tomcat-servlet-to-sjp', TIMEOUT);
}

# test simple tag example
sub simple_tag() {
    assert_screen('tomcat-simple-tag', TIMEOUT);
}

# test jsp in xml example
sub jsp_xml() {
    assert_screen('tomcat-jsp-in-xml', TIMEOUT);
}

# test if example
sub if() {
    assert_screen('tomcat-if-example', TIMEOUT);
}

# test foreach example
sub foreach() {
    assert_screen('tomcat-foreach-example', TIMEOUT);
}

# test choose example
sub choose() {
    assert_screen('tomcat-choose-example', TIMEOUT);
}

# test form example
sub form() {
    assert_screen('tomcat-form-example', TIMEOUT);
    send_key('tab');
    send_key('down');
    for (1 .. 2) { send_key('ret'); }

    if (check_screen('tomcat-click-save-login', 60)) {
        assert_and_click('tomcat-click-save-login', timeout=> TIMEOUT);
    }

    send_key('tab');
    type_string('tomcat');
    send_key('ret');
    wait_still_screen;
    assert_screen('tomcat-form-example-result', TIMEOUT);
}

1;
