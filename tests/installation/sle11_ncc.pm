# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;

sub ncc_continue_actions() {
    # untrusted gnupg keys may appear
    while (check_screen([qw/ncc-import-key ncc-configuration-done/], 120)) {
        last if match_has_tag('ncc-configuration-done');
        send_key "alt-i";
    }
}

sub run() {
    my $self = shift;

    assert_screen 'novell-customer-center', 30;

    send_key $cmd{'next'};
    assert_screen 'ncc-manual-interaction', 60;    # contacting server take time
    send_key 'alt-o';
    assert_screen 'ncc-security-warning', 30;
    send_key 'ret';

    my $emailaddr = get_var("NCC_EMAIL");
    my $ncc_code  = get_var("NCC_CODE");

    assert_screen 'ncc-input-emailaddress', 20;
    type_string $emailaddr;
    send_key_until_needlematch 'ncc-confirm-emailaddress', 'tab';
    type_string $emailaddr;
    send_key_until_needlematch 'ncc-input-activationcode', 'tab';
    type_string $ncc_code;

    if (get_var("ADDONS")) {
        foreach $a (split(/,/, get_var("ADDONS"))) {
            next if ($a =~ /sdk/);
            if ($a eq 'ha') {
                my $hacode = get_var("NCC_HA_CODE");
                send_key_until_needlematch 'ncc-input-hacode', 'tab';
                type_string $hacode;
            }
            if ($a eq 'geo') {
                my $geocode = get_var("NCC_GEO_CODE");
                send_key_until_needlematch 'ncc-input-geocode', 'tab';
                type_string $geocode;
            }
        }
    }

    send_key_until_needlematch 'ncc-submit', 'tab';
    send_key 'ret';

    send_key_until_needlematch 'ncc-continue-process', 'tab';
    send_key 'ret';

    ncc_continue_actions();
    send_key 'alt-o';    # done
}

1;
