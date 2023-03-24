# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

=head1 Backends

=head1 SYNOPSIS

use Utils::Backends
It defines various functions that allows to check for different backend or console types. It exports C<CONSOLES> and C<BACKEND>

=cut

package Utils::Backends;
use strict;
use warnings;

use base 'Exporter';
use Exporter;
use testapi ':DEFAULT';
use Utils::Architectures 'is_s390x';

use constant {
    BACKEND => [
        qw(
          is_remote_backend
          has_ttys
          has_serial_over_ssh
          is_hyperv
          is_hyperv_in_gui
          is_svirt_except_s390x
          is_pvm
          is_xen_pv
          is_ipmi
          is_qemu
          is_svirt
          is_image_backend
          is_ssh_installation
          is_backend_s390x
          is_spvm
          is_pvm_hmc
          is_generalhw
        )
    ],
    CONSOLES => [
        qw(
          set_sshserial_dev
          unset_sshserial_dev
          use_ssh_serial_console
          set_ssh_console_timeout
          save_serial_console
          get_serial_console
        )
    ]
};

our @EXPORT = (@{(+CONSOLES)}, @{+BACKEND});

our %EXPORT_TAGS = (
    CONSOLES => (CONSOLES),
    BACKEND => (BACKEND)
);

sub save_serial_console {
    my $serialconsole = get_var('SERIALCONSOLE', '');
    return if ($serialconsole ne '');
    $serialconsole = get_var('SERIALDEV', 'ttyS1');
    set_var('SERIALCONSOLE', $serialconsole);
    bmwqemu::save_vars();
}

sub get_serial_console {
    return get_var('SERIALCONSOLE', get_var('SERIALDEV', 'ttyS1'));
}

sub set_sshserial_dev {
    save_serial_console();
    $serialdev = 'sshserial';
    set_var('SERIALDEV', $serialdev);
    bmwqemu::save_vars();
}

sub unset_sshserial_dev {
    $serialdev = get_var('SERIALDEV_');
    set_var('SERIALDEV', $serialdev);
    bmwqemu::save_vars();
}

# Use it after SUT boot finish, as it requires ssh connection to SUT to
# interact with SUT, including window and serial console

=head2 use_ssh_serial_console

Selects the root-ssh and saves it to SERIALDEV

=cut

sub use_ssh_serial_console {
    select_console('root-ssh');
    set_sshserial_dev;
}

=head2 is_remote_backend

Returns true if the current instance is running as remote backend

=cut

sub is_remote_backend {
    # s390x uses only remote repos
    return check_var('ARCH', 's390x') || (get_var('BACKEND', '') =~ /ipmi|svirt/) || is_pvm();
}

# In some cases we are using a VNC connection provided by the hypervisor that
# allows access to the ttys same as for accessing any remote libvirt instance
# but not what we use for s390x-kvm.

=head2 has_ttys

Returns true if the current instance is using ttys

=cut

sub has_ttys {
    return ((get_var('BACKEND', '') !~ /ipmi|s390x|spvm|pvm_hmc/) && !get_var('S390_ZKVM') && !(check_var('BACKEND', 'generalhw') && !defined(get_var('GENERAL_HW_VNC_IP'))) && !get_var('PUBLIC_CLOUD'));
}

=head2 has_serial_over_ssh

Returns true if the current instance is using a serial through ssh

=cut

sub has_serial_over_ssh {
    return ((get_var('BACKEND', '') =~ /^(ikvm|ipmi|spvm|pvm_hmc|generalhw)/) && !defined(get_var('GENERAL_HW_VNC_IP')) && !defined(get_var('GENERAL_HW_SOL_CMD')));
}

=head2 is_hyperv

Returns true if the current instance is running as hyperv backend

=cut

sub is_hyperv {
    my $hyperv_version = shift;
    return 0 unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
    return defined($hyperv_version) ? check_var('HYPERV_VERSION', $hyperv_version) : 1;
}

=head2 is_hyperv_in_gui

Returns true if the current instance is running as hyperv gui backend

=cut

sub is_hyperv_in_gui {
    return is_hyperv && !check_var('VIDEOMODE', 'text');
}

=head2 is_xen_pv

Returns true if the current VM runs in Xen host in paravirtual mode

=cut

sub is_xen_pv {
    return check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux');
}

=head2 is_svirt_except_s390x

Returns true if the current instance is running as svirt backend except s390x

=cut

sub is_svirt_except_s390x {
    return !get_var('S390_ZKVM') && check_var('BACKEND', 'svirt');
}

=head2 is_pvm

Returns true if the current instance is running as PowerVM backend 'spvm' or 'hmc_pvm'

=cut

sub is_pvm {
    return check_var('BACKEND', 'spvm') || check_var('BACKEND', 'pvm_hmc');
}

=head2 is_ipmi

Returns true if the current instance is running as ipmi backend

=cut

sub is_ipmi {
    return check_var('BACKEND', 'ipmi');
}

=head2 is_qemu

Returns true if the current instance is running as qemu backend

=cut

sub is_qemu {
    return check_var('BACKEND', 'qemu');
}

=head2 is_svirt

Returns true if the current instance is running as svirt backend

=cut

sub is_svirt {
    return check_var('BACKEND', 'svirt');
}

=head2 is_image_backend

Returns true if the current instance is running on backend with image support

=cut

sub is_image_backend {
    return (is_qemu || is_svirt);
}

=head2 is_backend_s390x

Returns true if the current instance is running on backend with s390x

=cut

sub is_backend_s390x { check_var('BACKEND', 's390x'); }

=head2 is_spvm

Returns true if the current instance is running as PowerVM backend 'spvm'

=cut

sub is_spvm { check_var('BACKEND', 'spvm'); }

=head2 is_pvm_hmc

Returns true if the current instance is running as PowerVM backend 'hmc_pvm'

=cut

sub is_pvm_hmc { check_var('BACKEND', 'pvm_hmc'); }

=head2 is_generalhw

Returns true if the current instance is running on backend 'generalhw'

=cut

sub is_generalhw { check_var('BACKEND', 'generalhw'); }

#This subroutine takes absolute file path of sshd config file and desired ssh connection timeout as arguments
#The ssh connection timeout is counted as seconds
sub set_ssh_console_timeout {
    my ($sshd_config_file, $sshd_timeout) = @_;
    my $client_count_max = $sshd_timeout / 60;
    if (script_run("ls $sshd_config_file") == 0) {
        script_run("sed -irnE 's/^.*TCPKeepAlive.*\$/TCPKeepAlive yes/g; s/^.*ClientAliveInterval.*\$/ClientAliveInterval 60/g; s/^.*ClientAliveCountMax.*\$/ClientAliveCountMax $client_count_max/g' $sshd_config_file");
        script_run("grep -i Alive $sshd_config_file");
        script_run("service sshd restart") if (script_run("systemctl restart sshd") ne '0');
        record_info("Keep ssh connection alive for long-time run test!");
    }
    else {
        record_info("Fail to set ssh session alive for long-time run test", "Unable to find $sshd_config_file", result => 'softfail');
    }
}

=head2 is_ssh_installation

Returns true if ssh is used for the installation. If ssh can be used with
enabled X forwarding or in textmode.
Textmode is only possible over ssh in case of powerVM, zVM, and zKVM.

=cut

sub is_ssh_installation {
    my $videomode = get_var('VIDEOMODE', '');
    return ($videomode =~ /ssh/ ||
          (($videomode =~ /text/) && (is_pvm || is_s390x)));
}

1;
