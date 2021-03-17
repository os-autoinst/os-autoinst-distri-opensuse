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
use version_utils 'check_os_release';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal();
    if (check_os_release('suse', 'PRETTY_NAME')) {
        ensure_ca_certificates_suse_installed();
    }
    else {
        assert_script_run "dhclient -v";
        assert_script_run "curl http://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/ssl/certs/SUSE_Trust_Root.crt";
        # Stop unattended-upgrades on Ubuntu hosts to prevent interference from automatic updates
        assert_script_run "sed -i 's/Unattended-Upgrade \"1\"/Unattended-Upgrade \"0\"/' /etc/apt/apt.conf.d/20auto-upgrades" if check_os_release("ubuntu", "PRETTY_NAME");
    }
}

1;
