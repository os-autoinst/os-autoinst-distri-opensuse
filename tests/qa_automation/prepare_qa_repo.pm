# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: the step to prepare QA:Head repository
# Maintainer: Yong Sun <yosun@suse.com>

use strict;
use warnings;
use testapi;
use utils;
use base "opensusebasetest";
use repo_tools qw(add_qa_head_repo add_qa_web_repo);

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    add_qa_head_repo;
    add_qa_web_repo;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
