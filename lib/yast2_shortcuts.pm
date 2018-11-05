# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Shortcuts for yast modules
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

package yast2_shortcuts;

use strict;
use warnings;
use testapi;
use version_utils qw(is_leap is_sle is_opensuse);

use Exporter 'import';
our @EXPORT_OK = qw($is_older_product %remote_admin %firewall_settings %firewall_details $confirm);

our $is_older_product = is_sle('<15') || is_leap('<15.0');
our %remote_admin = (
    allow_remote_admin_with_session    => 'alt-a',
    allow_remote_admin_without_session => 'alt-l',
    do_not_allow_remote_admin          => 'alt-n'
);
our %firewall_settings = (
    open_port => $is_older_product ? 'alt-p' : 'alt-f',
    details => 'alt-d'
);
our %firewall_details = (
    network_interfaces => 'alt-e',
    select_all         => 'alt-a'
);
our $confirm = $is_older_product ? $cmd{ok} : $cmd{next};

1;
