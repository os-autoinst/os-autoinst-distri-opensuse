#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen "sles4sap-wizard-trex-swpm-welcome", 120;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-trex-swpm-params", 120;
    type_string "QAD",                                1;     # Sid
    send_key 'tab',                                   1;     # Instance number
    send_key 'tab',                                   1;     # SAP Mount Directory
    type_string "/srv",                               1;     # sapmnt directory
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-swpm-os-user", 60;
    type_password;
    send_key 'tab', 1;
    type_password;
    send_key $cmd{"next"}, 1;
}

1;
# vim: set sw=4 et:
