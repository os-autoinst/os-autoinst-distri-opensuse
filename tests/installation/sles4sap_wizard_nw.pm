#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen "sles4sap-wizard-nw-swpm-welcome", 120;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-nw-swpm-params", 60;
    type_string 'QNW',                              1;    # Sid
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-nw-swpm-master-password", 60;
    type_password;
    send_key 'tab', 1;                                    #password confirmation
    type_password;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-nw-swpm-db-params", 120;
    type_string 'QDB';
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-nw-swpm-sld-params", 120;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-nw-swpm-skey-generation", 120;
    send_key 'alt-e',                                        1;     #dEfault key
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-nw-swpm-diag-agents", 120;
    send_key $cmd{"next"}, 1;
}

1;
# vim: set sw=4 et:
