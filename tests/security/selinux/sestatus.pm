# SUSE's openQA tests
#
# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

#
# Summary: Test "sestatus" command gets the right status of a system running SELinux
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#40358, tc#1682592

use base 'selinuxtest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->set_sestatus("permissive", "minimum");
}

sub test_flags {
    return {fatal => 1};
}

1;
