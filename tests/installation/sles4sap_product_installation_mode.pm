# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle "Choose Operation System Edition" screen for SLES4SAP installation flow
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub run {
    if (is_sle('15+')) {
        my $expected_needle = check_var('SLES4SAP_MODE', 'sles4sap_wizard') ? "sles4sap-wizard-option-selected" : "sles4sap-wizard-option-not-selected";
        assert_screen [qw(sles4sap-wizard-option-selected sles4sap-wizard-option-not-selected)];
        send_key "alt-a" unless (match_has_tag($expected_needle));
        assert_screen $expected_needle;
    }
    else {
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
    }
    save_screenshot;
    send_key $cmd{next};
}

1;
