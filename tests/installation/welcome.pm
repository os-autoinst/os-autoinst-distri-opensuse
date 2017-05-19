# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for installer welcome screen. Covers loading linuxrc
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils 'ensure_fullscreen';

sub run() {
    while (1) {
        my @welcome_tags = ('inst-welcome-confirm-self-update-server', 'scc-invalid-url');
        if (get_var('BETA')) {
            push @welcome_tags, 'inst-betawarning';
        }
        else {
            push @welcome_tags, 'inst-welcome';
        }
        ensure_fullscreen;
        assert_screen \@welcome_tags, 500;
        if (match_has_tag 'scc-invalid-url') {
            die 'SCC reg URL is invalid' if !get_var('SCC_URL_VALID');
            send_key 'alt-r';    # registration URL field
            send_key_until_needlematch 'scc-invalid-url-deleted', 'backspace';
            type_string get_var('SCC_URL_VALID');
            wait_still_screen 2;
            wait_screen_change { send_key 'alt-o' };    # OK
        }
        if (match_has_tag('inst-welcome-confirm-self-update-server')) {
            wait_screen_change { send_key $cmd{ok} };
        }
        # this is needed because of race condition, there is shortly visible
        # welcome screen before Beta pop-up
        if (match_has_tag 'inst-betawarning') {
            send_key 'ret';
            assert_screen 'inst-welcome';
            last;
        }
        if (match_has_tag('inst-welcome')) {
            last;
        }
    }
    wait_idle;
    mouse_hide;

    # license+lang
    if (get_var('HASLICENSE')) {
        send_key $cmd{next};
        assert_screen 'license-not-accepted';
        send_key $cmd{ok};
        send_key $cmd{accept};    # accept license
    }
    assert_screen 'languagepicked';
    send_key $cmd{next};
    if (!check_var('INSTLANG', 'en_US') && check_screen 'langincomplete', 1) {
        send_key 'alt-f';
    }
}

sub post_fail_hook {
    my ($self) = @_;
    # system might be stuck on bootup showing only splash screen so we press
    # esc to show console logs
    send_key 'esc';
    select_console('install-shell');
    # in case we could not even reach the installer welcome screen and logs
    # could not be collected on the serial output:
    $self->save_upload_y2logs;
    $self->get_ip_address;
    upload_logs '/var/log/linuxrc.log';
}

1;
# vim: set sw=4 et:
