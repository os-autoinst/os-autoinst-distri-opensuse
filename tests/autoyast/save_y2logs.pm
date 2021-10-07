# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Summary: run save_y2logs and upload the generated tar.bz2
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>



use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;

sub run {
    my $self = shift;
    assert_script_run 'save_y2logs /tmp/y2logs.tar.bz2';
    upload_logs '/tmp/y2logs.tar.bz2';
}

1;
