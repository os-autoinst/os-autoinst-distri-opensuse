#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $sap_product = get_var('TREX') ? 'trex' : 'nw';
    assert_screen "sles4sap-wizard-swpm-overview", 600;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-installation-profile", 60;
    send_key 'alt-n',                                     1;     # No
    assert_screen "sles4sap-wizard-tuned-profile",        60;
    send_key 'alt-p',                                     1;     # Profile name
    assert_screen "sles4sap-wizard-tuned-profile-nw",     180;
    if ($sap_product eq 'trex') {
        send_key 'up',                                            1;     # select throughput-performance
        assert_screen "sles4sap-wizard-tuned-profile-throughput", 180;
    }
    send_key $cmd{"next"}, 1;
    if (check_screen 'sles4sap-wizard-tuned-profile-confirmation', 10) {
        send_key 'alt-y', 1;                                             # Yes
    }
    assert_screen "sles4sap-wizard-tuned-profile-applied", 180;
    send_key 'alt-o',                                      1;            # Ok
    send_key $cmd{"next"}, 1;
    if (check_screen('sles4sap-wizard-no-space-left', 180)) {
        send_key 'alt-o';                                                #Okay
        record_soft_failure;                                             #this is a bug, there is plenty of space
    }
    assert_screen "sles4sap-wizard-swpm-overview", 180;                  #the same screen as at the beginning of sles4sap_wizard_swpm
    send_key $cmd{"next"}, 1;
    save_screenshot;
    assert_screen "sles4sap-wizard-swpm-progress", 600;
    assert_screen "sles4sap-wizard-completed",     18000;                # 5 hours timeout should be enough even for NW
    send_key 'alt-f';                                                    #Finish
}

1;
# vim: set sw=4 et:
