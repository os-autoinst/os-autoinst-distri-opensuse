# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup system which will host containers
# - setup networking via dhclient when is needed
# - make sure that ca certifications were installed
# - import SUSE CA certificates
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use Utils::Systemd qw(disable_and_stop_service);
use version_utils qw(check_os_release is_sle);

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $interface;
    if (check_os_release('suse', 'PRETTY_NAME')) {
        $interface = script_output q@ip r s default 0.0.0.0/0 | awk '{printf $5}'@;
        validate_script_output "ip a s '$interface'", sub { m/((\d{1,3}\.){3}\d{1,3}\/\d{1,2})/ };
        ensure_ca_certificates_suse_installed();
        disable_and_stop_service(opensusebasetest::firewall, ignore_failure => 1);
    }
    else {
        # Re-running dhclient on RHEL is confusing the routing tables
        assert_script_run "dhclient -v" unless get_var("HDD_1") =~ /rhel/;
        $interface = script_output q@ip r s default | head -1 | awk '{printf $5}'@;
        validate_script_output "ip a s '$interface'", sub { m/((\d{1,3}\.){3}\d{1,3}\/\d{1,2})/ };
        assert_script_run "curl http://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/ssl/certs/SUSE_Trust_Root.crt" if is_sle();
        # Stop unattended-upgrades on Ubuntu hosts to prevent interference from automatic updates
        assert_script_run "sed -i 's/Unattended-Upgrade \"1\"/Unattended-Upgrade \"0\"/' /etc/apt/apt.conf.d/20auto-upgrades" if check_os_release("ubuntu", "PRETTY_NAME");
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
