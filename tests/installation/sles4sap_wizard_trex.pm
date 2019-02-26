# Summary: Add SLES4SAP tests
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run {
    assert_screen "sles4sap-wizard-trex-swpm-welcome", 120;
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-trex-swpm-params", 120;
    type_string "QAD";     # Sid
    send_key 'tab';        # Instance number
    send_key 'tab';        # SAP Mount Directory
    type_string "/srv";    # sapmnt directory
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-swpm-os-user";
    type_password;
    send_key 'tab';
    type_password;
    send_key $cmd{next};
}

1;
