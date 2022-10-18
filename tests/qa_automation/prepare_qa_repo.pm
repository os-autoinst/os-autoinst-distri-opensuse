# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: the step to prepare QA:Head repository
# Maintainer: Yong Sun <yosun@suse.com>

use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use base "opensusebasetest";
use repo_tools qw(add_qa_head_repo add_qa_web_repo);

sub run {
    my $self = shift;
    select_serial_terminal;
    add_qa_head_repo;
    add_qa_web_repo;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
