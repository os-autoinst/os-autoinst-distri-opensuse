# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic systemtap functions
# * Test simple hello world
# * Test stap-server output
# * Test simple probing
# Maintainer: Anastasiadis Vasileios <vasilios.anastasiadis@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use kdump_utils;
use version_utils qw(is_sle);

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    prepare_for_kdump();
    zypper_call("in systemtap systemtap-docs kernel-devel systemtap-server");
    assert_script_run("stap /usr/share/doc/packages/systemtap/examples/general/helloworld.stp | grep 'hello world'");
    assert_script_run("stap-server condrestart | grep --line-buffered \"managed\"");
    assert_script_run("stap -v -e 'probe vfs.read {printf(\"read performed\\n\"); exit()}'");
}

1;
