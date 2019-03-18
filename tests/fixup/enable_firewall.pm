# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable firewall after updating openSUSE 13.1 image
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>
# Tags: boo#977659

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'systemctl';

sub run {
    my ($self) = @_;
    select_console 'root-console';
    systemctl 'start ' . $self->firewall;
}

sub test_flags {
    return {milestone => 1};
}

1;
