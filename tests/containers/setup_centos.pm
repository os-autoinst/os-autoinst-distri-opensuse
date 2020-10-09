# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup Centos
# - setup networking via dhclient
# - import SUSE CA certificates
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    assert_script_run "dhclient -v";
    assert_script_run "curl http://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/ssl/certs/SUSE_Trust_Root.crt";
}

1;

