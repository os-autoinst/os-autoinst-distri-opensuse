# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add SLES4SAP tests
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    assert_screen "sles4sap-wizard-nw-swpm-welcome";
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-nw-swpm-params";
    type_string 'QNW';    # SAP Sid
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-nw-swpm-master-password";
    type_password;
    send_key 'tab';       #password confirmation
    type_password;
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-nw-swpm-db-params";
    type_string 'QDB';
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-nw-swpm-sld-params";
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-nw-swpm-skey-generation";
    send_key 'alt-e';     #dEfault key
    send_key $cmd{next};
    assert_screen "sles4sap-wizard-nw-swpm-diag-agents";
    send_key $cmd{next};
}

1;
