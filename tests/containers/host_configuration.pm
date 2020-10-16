# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup system which will host containers
# - setup networking via dhclient
# - make sure that ca certifications were installed
# - import SUSE CA certificates
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use scheduler 'get_test_suite_data';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $test_data = get_test_suite_data();
    unless ($test_data->{host_os}) {
        ensure_ca_certificates_suse_installed();
    }
    else {
        assert_script_run "dhclient -v";
        assert_script_run "curl http://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/ssl/certs/SUSE_Trust_Root.crt";
    }
}

1;

