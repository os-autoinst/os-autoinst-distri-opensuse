# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary:  ssh login 
# Maintainer: Joyce Na <jna@suse.de>


package login_console;
use base "y2logsstep";
use strict;
use warnings;
use File::Basename;
use testapi;
use ipmi_backend_utils;


sub login_to_console {
    my ($self, $timeout) = @_;
    $timeout //= 80;

    select_console 'sol', await_console => 0;
    if (check_screen('login_screen', $timeout)) {
        #use console based on ssh to avoid unstable ipmi
        use_ssh_serial_console;
    }
    else {
        use_ssh_serial_console;
    }
}

sub run {
    my $self = shift;
    $self->login_to_console;
}

1;

