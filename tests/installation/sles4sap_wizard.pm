# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add SLES4SAP tests
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run {
    my ($swpm_proto, $swpm_path) = split m|://|, get_var('SWPM');
    my ($sapinst_proto, $sapinst_path);
    my $sap_product = get_var('TREX') ? 'trex' : 'nw';
    assert_screen "sles4sap-wizard-welcome", 90;
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-network";
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-installation-mode";
    send_key $cmd{next};
    if (check_screen('sles4sap-wizard-installation-servers-detected', 30)) {
        #sap-installation-wizard found sapinst shared over NFS, don't use it
        send_key 'alt-o';    #Okay
    }
    assert_screen "sles4sap-wizard-sapinst";
    send_key 'tab';          # select protocol droplist
    save_screenshot;
    send_key 'home';
    send_key_until_needlematch 'sles4sap-wizard-proto-' . $swpm_proto . '-selected', 'down';
    send_key 'tab';
    type_string $swpm_path;
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-copying-media";
    mouse_hide;
    assert_screen "sles4sap-wizard-product-selection";
    if ($sap_product eq 'nw') {
        ($sapinst_proto, $sapinst_path) = split m|://|, get_var('NW');
        send_key 'alt-t';    # sap sTandard system
        send_key 'alt-p';    # saP maxdb
    }
    else {                   #TREX installation
        ($sapinst_proto, $sapinst_path) = split m|://|, get_var('TREX');
        send_key 'alt-l';    # sap standaLone engines
    }
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-choose-product";
    send_key 'alt-y';        # move focus to list of products
    send_key_until_needlematch 'sles4sap-wizard-product-' . $sap_product . '-selected', 'down';
    send_key $cmd{next};
    send_key 'alt-c';        # Copy a medium
    send_key 'tab';
    send_key 'home';
    send_key_until_needlematch 'sles4sap-wizard-sapinst-proto-' . $sapinst_proto . '-selected', 'down';
    send_key 'tab';
    type_string $sapinst_path;
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-copying-media";
    assert_screen "sles4sap-wizard-more-media";
    send_key 'alt-n';        # No
    assert_screen "sles4sap-wizard-supplement-media";
    send_key 'alt-n';        # No
    assert_screen "sles4sap-wizard-add-repo";
    send_key $cmd{next};
    if ($sap_product eq 'nw') {
        assert_screen "sles4sap-wizard-system-sizing";
        send_key 'alt-o';    #Ok
        assert_screen "sles4sap-wizard-virtual-ip";
        send_key 'alt-o';    #Ok
    }
    save_screenshot;
}

1;
