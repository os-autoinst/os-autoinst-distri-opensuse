# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reconnect s390-consoles after reboot
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

use base "installbasetest";

use testapi;
use utils qw(is_sle sle_version_at_least);

use strict;
use warnings;

sub handle_login_not_found {
    my ($str) = @_;
    diag 'Expected welcome message not found, investigating bootup log content: ' . $str;
    diag 'Checking for bootloader';
    diag "WARNING: bootloader grub menue not found" unless $str =~ /GNU GRUB/;
    diag 'Checking for ssh daemon';
    diag "WARNING: ssh daemon in SUT is not available" unless $str =~ /Started OpenSSH Daemon/;
    diag 'Checking for any welcome message';
    die "no welcome message found, system seems to have never passed the bootloader (stuck or not enough waiting time)" unless $str =~ /Welcome to/;
    diag 'Checking login target reached';
    die "login target not reached" unless $str =~ /Reached target Login Prompts/;
    diag 'Checking for login prompt';
    die "no login prompt found" unless $str =~ /login:/;
    diag 'Checking for known failure';
    return record_soft_failure 'bsc#1040606 - incomplete message when LeanOS is implicitly selected instead of SLES'
      if $str =~ /Welcome to SUSE Linux Enterprise 15/;
    die "unknown error, system couldn't boot";
}

sub run {
    my $login_ready = check_var('VERSION', 'Tumbleweed') ? qr/Welcome to openSUSE Tumbleweed 20.*/ : qr/Welcome to SUSE Linux Enterprise .*\(s390x\)/;
    console('installation')->disable_vnc_stalls;

    # different behaviour for z/VM and z/KVM
    if (check_var('BACKEND', 's390x')) {

        # kill serial ssh connection (if it exists)
        eval { console('iucvconn')->kill_ssh unless get_var('BOOT_EXISTING_S390', ''); };
        diag('ignoring already shut down console') if ($@);

        my $r;
        eval { $r = console('x3270')->expect_3270(output_delim => $login_ready, timeout => 300); };
        if ($@) {
            my $ret = $@;
            handle_login_not_found($ret);
        }
        reset_consoles;

        # reconnect the ssh for serial grab
        select_console('iucvconn');
    }
    else {
        my $r = wait_serial($login_ready, 300);
        if ($r =~ qr/Welcome to SUSE Linux Enterprise 15/) {
            record_soft_failure('bsc#1040606');
        }
        elsif (is_sle) {
            $r =~ qr/Welcome to SUSE Linux Enterprise Server/ || die "Correct welcome string not found";
        }
    }

    # SLE >= 15 does not offer auto-started VNC server in SUT, only login prompt as in textmode
    if (!check_var('DESKTOP', 'textmode') && !sle_version_at_least('15')) {
        select_console('x11', await_console => 0);
    }
}

1;
