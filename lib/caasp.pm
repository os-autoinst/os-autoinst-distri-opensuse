# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package caasp;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils qw(power_action assert_shutdown_and_restore_system);

our @EXPORT = qw(get_utt_packages handle_simple_pw process_reboot trup_call write_detail_output);

# Download files needed for transactional update test
sub get_utt_packages {
    assert_script_run 'curl -O ' . data_url('caasp/utt.tgz');
    assert_script_run 'curl -O ' . data_url('caasp/utt.repo');
    assert_script_run 'tar xzvf utt.tgz';
}

# Weak password warning should be displayed only once - bsc#1025835
sub handle_simple_pw {
    return if get_var 'SIMPLE_PW_CONFIRMED';

    assert_screen 'inst-userpasswdtoosimple';
    send_key 'alt-y';
    set_var 'SIMPLE_PW_CONFIRMED', 1;
}

# Process reboot with an option to trigger it
sub process_reboot {
    my $trigger = shift;
    power_action('reboot') if $trigger;
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        assert_shutdown_and_restore_system unless $trigger;
    }
    else {
        reset_consoles;
    }

    # No grub bootloader on xen-pv
    unless (check_var('VIRSH_VMM_TYPE', 'linux')) {
        assert_screen 'grub2', 60;
        send_key 'ret';
    }

    assert_screen 'linux-login-casp', 90;
    select_console 'root-console';
}

# Optionally skip exit status check in case immediate reboot is expected
sub trup_call {
    my $cmd = shift;
    my $check = shift // 1;
    $cmd .= " > /dev/$serialdev";
    $cmd .= " ; echo trup-\$?- > /dev/$serialdev" if $check;

    save_screenshot;
    send_key "ctrl-l";

    script_run "transactional-update $cmd", 0;
    if ($cmd =~ /ptf /) {
        if (wait_serial "Continue?") {
            send_key "ret";
        }
        else {
            die "Confirmation dialog not shown";
        }
    }
    wait_serial 'trup-0-' if $check;
}

# Function for writing custom text boxes for the test job
# After fixing poo#17462 it should be replaced by record_info from testlib
sub write_detail_output {
    my ($self, $title, $output, $result) = @_;

    $result =~ /^(ok|fail|softfail)$/ || die "Result value: $result not allowed.";

    my $filename = $self->next_resultname('txt');
    my $detail   = {
        title  => $title,
        result => $result,
        text   => $filename,
    };
    push @{$self->{details}}, $detail;

    open my $fh, '>', bmwqemu::result_dir() . "/$filename";
    print $fh $output;
    close $fh;

    # Set overall result for the job
    if ($result eq 'fail') {
        $self->{result} = $result;
    }
    elsif ($result eq 'ok') {
        $self->{result} ||= $result;
    }
}

1;
