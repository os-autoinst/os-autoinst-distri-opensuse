# VIRTUAL MACHINE AMD SEV/SEV-ES FEATURES VERIFICATION MODULE
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module tests whether SEV/SEV-ES virtual machine has
# been successfully installed on SEV/SEV-ES enabled physical host by
# checking SEV/SEV-ES support status on physical host in the first
# place and then virtual machine itself.
#
# Maintainer: Wayne Chen <wchen@suse.com>
package sev_es_guest_verification;

use base 'virt_feature_test_base';
use strict;
use warnings;
use POSIX 'strftime';
use File::Basename;
use testapi;
use IPC::Run;
use utils;
use virt_utils;
use virt_autotest::common;
use virt_autotest::utils;
use version_utils qw(is_sle is_tumbleweed);
use Utils::Architectures;

sub run_test {
    my $self = shift;

    $self->check_sev_es_on_host;
    foreach (keys %virt_autotest::common::guests) {
        virt_autotest::utils::wait_guest_online($_, 180, 1);
        $self->check_sev_es_on_guest(guest_name => "$_");
    }
    return $self;
}

=head2 check_sev_es_on_host

  check_sev_es_on_host($self)

Check whether AMD SEV or SEV-ES feature is enabled and active on physical host
under test. It calls check_sev_es_parameter to perform the task. There is no
additional argument supported by this subroutine. 

=cut

sub check_sev_es_on_host {
    my $self = shift;

    record_info('Check SEV/SEV-ES support status on host', 'Only 15-SP2+ host supports AMD SEV and only 15-SP4+ supports AMD SEV-ES.');
    if (is_x86_64) {
        if (is_sle('>=15-SP4') or is_tumbleweed) {
            record_info('No AMD SEV or SEV-ES feature available on host', 'Host is a 15-SP4 or newer produdct') unless ($self->check_sev_es_parameter(params_to_check => 'sev sev_es') == 0);
        }
        elsif (is_sle('>=15-SP2')) {
            record_info('No AMD SEV feature available on host', 'Host is a 15-SP2 or newer produdct but older than 15-SP4') unless ($self->check_sev_es_parameter(params_to_check => 'sev') == 0);
        }
        else {
            record_info('No AMD SEV feature available on host', 'Host is older than 15-SP2');
        }
    }
    else {
        record_info('No AMD SEV/SEV-ES feature available on host', 'Non x86_64 host does not support AMD SEV/SEV-ES feature');
    }
    return $self;
}

=head2 check_sev_es_on_guest

  check_sev_es_on_guest($self, guest_name => 'name')

Check whether AMD SEV or SEV-ES feature is enabled and active on virtual machine. 
It calls is_sev_es_guest and check_sev_es_dmesg to perform the task. There is one
named argument guest_name is supported by this subroutine.

=cut

sub check_sev_es_on_guest {
    my ($self, %args) = @_;
    $args{guest_name} //= '';
    die 'Guest name must be given to perform following operations.' if ($args{guest_name} eq '');

    record_info("Check SEV/SEV-ES support status on guest $args{guest_name}", "Guest can be installed with SEV or SEV-ES enabled by specifying corresponding policy.");
    my $guest_type = virt_autotest::utils::is_sev_es_guest($args{guest_name});
    if ($guest_type eq 'sev-es') {
        die "SEV or SEV-ES is not enabled or active for SEV-ES guest $args{guest_name}" unless ($self->check_sev_es_dmesg(dst_machine => "$args{guest_name}", flags_to_check => 'SEV SEV-ES') == 0);
    }
    elsif ($guest_type eq 'sev') {
        die "SEV is not enabled or active for SEV guest $args{guest_name}" unless ($self->check_sev_es_dmesg(dst_machine => "$args{guest_name}", flags_to_check => 'SEV') == 0);
    }
    else {
        record_info('Skip non-sev(es) guest checking', "Guest $args{guest_name} is not a sev or sev-es guest, so skip sev(es) checking on it.");
    }
    return $self;
}

=head2 check_sev_es_parameter

  check_sev_es_parameter($self, params_to_check => 'param1 param2' [, dst_machine => 'machine'])

Check whether AMD SEV or SEV-ES is enabled and active on the system under test.
The sev or sev_es parameter under /sys/module/kvm_amd/parameters/ is the most
authoritative indicator that indicates whether the corresponding feature is active,
especially on the linux physical host. This subroutine has two named argument. 
params_to_check which is kvm_amd module parameter, sev or sev_es to be examined.
Multiple parameters can be passed in as a single string text separated by space.
dst_machine, which has the default value of 'localhost' or specific ip or fqdn
address, is the system on which operations will be performed. This subroutine 
only returns 0 if values of all params_to_check are all Ys or all 1s.

=cut

sub check_sev_es_parameter {
    my ($self, %args) = @_;
    $args{params_to_check} //= '';
    $args{dst_machine} //= 'localhost';
    die 'Argument params_to_check should not be empty.' if ($args{params_to_check} eq '');

    my @parameters = split(/ /, $args{params_to_check});
    my $ret = 0;
    foreach (@parameters) {
        my $cmd = "cat /sys/module/kvm_amd/parameters/$_";
        $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
        my $value = script_output($cmd, proceed_on_failure => 0);
        save_screenshot;
        $ret |= (($value eq 'Y' or $value eq '1') ? 0 : 1);
        record_info("$_ has value $value", "Parameter /sys/module/kvm_amd/parameters/$_ has value $value on $args{dst_machine}.");
    }
    return $ret;
}

=head2 check_sev_es_dmesg

  check_sev_es_dmesg($self, flags_to_check => 'flag' [, dst_machine => 'machine'])

Check whether AMD SEV or SEV-ES is active on the system under test when it boots
up by looking into dmesg output. This is not the most authoraive way to be used,
but it is the only way on some systems, for example, linux virtual machine. This 
subroutine has two named arguments, dst_machine which is ip or fqdn address of 
the system under test or default value 'localhost', flags_to_check which is SEV
or SEV-ES flag to be examined. Multiple flags can be passed in as a single string 
text separated by sapce to the flags_to_check. The dst_machine is optional and the 
flags_to_check is mandatory. This subroutine only returns 0 if the values of all 
flags_to_check are Ys or 1s.

=cut

sub check_sev_es_dmesg {
    my ($self, %args) = @_;
    $args{dst_machine} //= 'localhost';
    $args{flags_to_check} //= '';
    die 'Argument flags_to_check should not be empty' if ($args{flags_to_check} eq '');

    my @flags = split(/ /, $args{flags_to_check});
    my $ret = 0;
    my $cmd1 = '';
    my $cmd2 = '';
    foreach (@flags) {
        $cmd1 = ($args{dst_machine} eq 'localhost' ? "\"$_( |\$)\"" : "\\\"$_( |\$)\\\"");
        $cmd1 = "grep -i -E -o " . $cmd1;
        $cmd2 = ($args{dst_machine} eq 'localhost' ? "\"Memory Encryption Features active\"" : "\\\"Memory Encryption Features active\\\"");
        $cmd2 = "grep -i " . $cmd2;
        $cmd1 = "dmesg | $cmd2 | $cmd1";
        $cmd1 = "ssh root\@$args{dst_machine} " . "\"$cmd1\"" if ($args{dst_machine} ne 'localhost');
        my $flag_ret = script_retry($cmd1, retry => 30, delay => 10, timeout => 60, die => 0);
        my $flag_status = ($flag_ret == 0 ? 'active' : 'inactive');
        record_info("Flag $_ $flag_status in dmesg", "AMD flag $_ is currently $flag_status in dmesg on guest $args{dst_machine}.");
        $ret |= $flag_ret;
    }
    return $ret;
}

=head2 post_fail_hook

  post_fail_hook($self)

Test run jumps into this subroutine if it fails somehow. It calls post_fail_hook
in base class.

=cut

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook;
    return $self;
}

1;
