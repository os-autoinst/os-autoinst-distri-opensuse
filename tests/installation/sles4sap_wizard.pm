#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my ($swpm_proto, $swpm_path) = split m|://|, get_var('SWPM');
    my ($sapinst_proto, $sapinst_path);
    my $sap_product = get_var('TREX') ? 'trex' : 'nw';
    assert_screen "sles4sap-wizard-welcome", 180;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-network", 60;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-installation-mode", 180;
    send_key $cmd{"next"}, 1;
    if (check_screen('sles4sap-wizard-installation-servers-detected', 30)) {
        #sap-installation-wizard found sapinst shared over NFS, don't use it
        send_key 'alt-o';    #Okay
    }
    assert_screen "sles4sap-wizard-sapinst", 180;
    send_key 'tab',                          1;     # select protocol droplist
    save_screenshot;
    send_key 'home', 1;
    send_key_until_needlematch 'sles4sap-wizard-proto-' . $swpm_proto . '-selected', 'down';
    send_key 'tab', 1;
    type_string $swpm_path;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-copying-media", 120;
    mouse_hide;
    assert_screen "sles4sap-wizard-product-selection", 360;
    if ($sap_product eq 'nw') {
        ($sapinst_proto, $sapinst_path) = split m|://|, get_var('NW');
        send_key 'alt-t', 1;                        # sap sTandard system
        send_key 'alt-p', 1;                        # saP maxdb
    }
    else {                                          #TREX installation
        ($sapinst_proto, $sapinst_path) = split m|://|, get_var('TREX');
        send_key 'alt-l', 1;                        # sap standaLone engines
    }
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-choose-product", 3;
    send_key 'alt-y',                               1;    # move focus to list of products
    send_key_until_needlematch 'sles4sap-wizard-product-' . $sap_product . '-selected', 'down';
    send_key $cmd{"next"}, 1;
    send_key 'alt-c', 1;                                  # Copy a medium
    send_key 'tab',   1;
    send_key 'home',  1;
    send_key_until_needlematch 'sles4sap-wizard-sapinst-proto-' . $sapinst_proto . '-selected', 'down';
    send_key 'tab', 1;
    type_string $sapinst_path;
    send_key $cmd{"next"}, 1;
    assert_screen "sles4sap-wizard-copying-media",    600;
    assert_screen "sles4sap-wizard-more-media",       360;
    send_key 'alt-n',                                 1;     # No
    assert_screen "sles4sap-wizard-supplement-media", 120;
    send_key 'alt-n',                                 1;     # No
    assert_screen "sles4sap-wizard-add-repo",         60;
    send_key $cmd{"next"}, 1;
    if ($sap_product eq 'nw') {
        assert_screen "sles4sap-wizard-system-sizing", 600;
        send_key 'alt-o',                              1;     #Ok
        assert_screen "sles4sap-wizard-virtual-ip",    600;
        send_key 'alt-o',                              1;     #Ok
    }
    save_screenshot;
}

1;
# vim: set sw=4 et:
