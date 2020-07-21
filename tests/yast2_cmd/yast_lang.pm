# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast language test
# List languages, set default and secondary languages
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    zypper_call "in yast2-country";
    validate_script_output 'yast language list', sub { m/(.*)de_DE(.*)it_IT(.*)/s };
    assert_script_run 'yast language set lang=de_DE languages=it_IT';
    validate_script_output 'yast language summary', sub { m/(.*)de_DE(.*)it_IT(.*)/s };
    assert_script_run 'yast language set lang=en_US';
}

1;
