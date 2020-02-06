# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Install kiwi templates for JeOS
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    zypper_call 'in kiwi-templates-JeOS';
    script_run 'rpm -ql kiwi-templates-JeOS';
}

1;
