# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the sshd is running *and* that port 22 is opened,as
# admins may want to connect with ssh right after an ssh installation.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use services::sshd;
use testapi "select_console";

sub run {
    select_console 'root-console';
    services::sshd::check_sshd_service();
    services::sshd::check_sshd_port();
}

1;
