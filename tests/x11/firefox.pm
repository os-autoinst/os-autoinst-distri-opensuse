# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Very basic firefox test opening an html-test
# - Start firefox with url "https://html5test.opensuse.org"
# - Open about window and check
# - Exit firefox
# Maintainer: Stephan Kulow <coolo@suse.com>

package firefox;
use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_opensuse is_tumbleweed);
use Utils::Architectures 'is_s390x';
use serial_terminal 'select_serial_terminal';

sub run() {
    my ($self) = shift;

    # we have sometime issue with firefox crash, export setting of automatic sending of crash report
    # save the minidump and then force the application to close, see bsc#1205511
    if (is_opensuse) {
        select_serial_terminal;
        assert_script_run('echo -en "MOZ_CRASHREPORTER_AUTO_SUBMIT=1\n MOZ_CRASHREPORTER_SHUTDOWN=1" > ~/.profile');
    }

    $self->prepare_firefox_autoconfig;
    $self->start_firefox;
    wait_still_screen;
    send_key('alt');
    send_key_until_needlematch('firefox-top-bar-highlighted', 'alt-h', 5, 10);

    send_key('alt-h');
    wait_still_screen;
    assert_screen('firefox-help-menu');

    send_key_until_needlematch([qw(test-firefox-3 test-firefox-s390-discoloration)], 'a', 10, 6);
    if (match_has_tag 'test-firefox-s390-discoloration') {
        die "This should only happen on s390x" unless is_s390x;
        record_soft_failure("bsc#1203578");
    }

    # close About
    # Send crash report manually if automatic sending of crash reprot doesn't work, see bsc#1205511
    send_key "alt-f4";
    assert_screen([qw(firefox-crash-reporter firefox-html-test)], timeout => 90);
    if (match_has_tag 'firefox-crash-reporter') {
        assert_and_click 'send-crashreport';
        assert_and_click 'quit-firefox';
        record_soft_failure 'firefox got crashed, sending crash report. see bsc#1205511';
    }
    elsif (match_has_tag 'firefox-html-test') {
        send_key "alt-f4";
    }
    assert_screen([qw(firefox-save-and-quit generic-desktop not-responding)], timeout => 90);
    if (match_has_tag 'not-responding') {
        record_soft_failure "firefox is not responding, see boo#1174857";
        # confirm "save&quit"
        send_key_until_needlematch('generic-desktop', 'ret', 10, 6);
    }
    elsif (match_has_tag 'firefox-save-and-quit') {
        # confirm "save&quit"
        send_key_until_needlematch('generic-desktop', 'ret', 10, 6);
    }
}

1;
