#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $sap_product = get_var('TREX') ? 'trex' : 'nw';
    assert_screen "sles4sap-wizard-swpm-overview";
    send_key $cmd{"next"};
    assert_screen "sles4sap-wizard-installation-profile";
    send_key 'alt-n';    # No
    assert_screen "sles4sap-wizard-tuned-profile";
    send_key 'alt-p';    # Profile name
    assert_screen "sles4sap-wizard-tuned-profile-nw";
    if ($sap_product eq 'trex') {
        send_key 'up';    # select throughput-performance
        assert_screen "sles4sap-wizard-tuned-profile-throughput";
    }
    send_key $cmd{"next"};
    if (check_screen 'sles4sap-wizard-tuned-profile-confirmation') {
        send_key 'alt-y';    # Yes
    }
    assert_screen "sles4sap-wizard-tuned-profile-applied";
    send_key 'alt-o';        # Ok
    send_key $cmd{"next"};
    if (check_screen('sles4sap-wizard-no-space-left')) {
        send_key 'alt-o';       #Okay
        record_soft_failure;    #this is a bug, there is plenty of space
    }
    assert_screen "sles4sap-wizard-swpm-overview";    #the same screen as at the beginning of sles4sap_wizard_swpm
    send_key $cmd{"next"};
    save_screenshot;
    assert_screen "sles4sap-wizard-swpm-progress", 600;
    assert_screen "sles4sap-wizard-completed",     18000;    # 5 hours timeout should be enough even for NW
    send_key 'alt-f';                                        #Finish
}

1;
# vim: set sw=4 et:
