#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen "sles4sap-product-installation-mode";
    send_key "alt-p";    # Proceed with standard SLES installation
    assert_screen "sles4sap-standard-sles-selected";
    if (get_var("SLES4SAP_MODE") =~ /sles4sap/) {
        send_key "alt-o";    # prOceed with standard SLES for SAP Application installation
        assert_screen "sles4sap-product-selected";
        if (check_var('SLES4SAP_MODE', 'sles4sap_wizard')) {
            send_key "alt-s";    # Start the SAP Installation Wizard right after the OS installation
            assert_screen "sles4sap-wizard-selected";
        }
    }
    save_screenshot;
    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
