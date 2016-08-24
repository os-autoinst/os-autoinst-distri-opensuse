#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen "sles4sap-product-installation-mode";
    send_key "alt-s";    # SUSE Linux Enterprise Server
    save_screenshot;
    assert_screen "sles4sap-standard-sles-selected";
    if (get_var("SLES4SAP_MODE") =~ /sles4sap/) {
        send_key "alt-u";    # SLES for SAP
        assert_screen "sles4sap-product-selected";
        if (check_var('SLES4SAP_MODE', 'sles4sap_wizard')) {
            send_key "alt-a";    # lAunch SAP product installation wizard
            assert_screen "sles4sap-wizard-selected";
        }
    }
    save_screenshot;
    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
