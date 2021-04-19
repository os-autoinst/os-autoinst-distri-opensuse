# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Validate the sshd is running *and* that port 22 is opened,as
# admins may want to connect with ssh right after an ssh installation.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use services::sshd;
use testapi "select_console";

sub run {
    select_console 'root-console';
    services::sshd::check_sshd_service();
    services::sshd::check_sshd_port();
}

1;
