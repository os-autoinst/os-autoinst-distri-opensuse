# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
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

# Add qa head repo for kernel testing. If QA_HEAD_REPO is set,
# remove all existing zypper repos first
sub prepare_repos {
    my $self         = shift;
    my $qa_head_repo = get_required_var('QA_HEAD_REPO', '');
    my $qa_web_repo  = get_var('QA_WEB_REPO', '');

    zypper_call("--no-gpg-check ar -f $qa_head_repo qa-ibs");
    if ($qa_web_repo) {
        zypper_call("--no-gpg-check ar -f $qa_web_repo qa-web");
    }

    # sometimes updates.suse.com is busy, so we need to wait for possiblye retries
    zypper_call("--gpg-auto-import-keys ref");
}

sub run {
    select_console 'root-console';
    prepare_repos();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
