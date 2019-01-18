# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: refactor jeos tests a bit
#    - simplyfy by using assert_script_run instead of
#      validate_script_output
#    - move some of the more generic ones to console/
#    - make vim test actually run vim
# G-Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    assert_script_run("grep ^0 /sys/kernel/kexec_crash_loaded", fail_message => 'kdump should be disabled');
}

1;
