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
