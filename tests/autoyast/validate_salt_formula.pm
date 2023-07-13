# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Make sure the salt formula has set message-of-the-day(motd)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my ($self) = @_;
    my $data = get_test_suite_data();
    assert_script_run "grep \"$data->{motd_text}\" /etc/motd";
}

1;
