# VIRTUAL MACHINE INSTALLATION AND CONFIGURATION BASE MODULE
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module provides framework and APIs to install virtual
# machine by using virt-install comman line.It supports configuration
# and modification to virtualation,platform,name,memory,cpu,metadata,
# xml,installation method,network selection,storage types,boot settings,
# graphics,videos,consoles,power management and other features of vm.
# It also provides installation monitoring,power cycle,results recording,
# environment cleanup,logs collecting and etc.
# Please refer to %guest_params for detailed parameters usage and
# description before each subroutine for its purpose.
#
# Maintainer: Wayne Chen <wchen@suse.com> or <qe-virt@suse.de>
package guest_installation_and_configuration_base;

use base "opensusebasetest";
use base "guest_installation_and_configuration_metadata";
use strict;
use warnings;
use POSIX;
use File::Basename;
use Net::SSH2;
use File::Copy 'copy';
use File::Path 'make_path';
use Data::Dumper;
use XML::Writer;
use IO::File;
use List::Util;
use Carp;
use IO::Scalar;
use Utils::Logging qw(upload_coredumps);
use testapi;
use utils;
use ipmi_backend_utils qw(reconnect_when_ssh_console_broken);
use virt_utils;
use virt_autotest::utils;
use virt_autotest::virtual_network_utils;
use version_utils;
use Utils::Systemd;
use mm_network;
use Utils::Architectures;
use Utils::Backends;
use guest_installation_and_configuration_metadata;

our $AUTOLOAD;

=head2 reveal_myself
    
  reveal_myself($self)
    
Any subroutine calls this subroutine announces its identity and it is being executed.
    
=cut

sub reveal_myself {
    my $self = shift;

    my $_my_identity = (caller(1))[3];
    diag("Test execution inside $_my_identity.");
    return $self;
}

=head2 create
    
  create($self)
    
Create guest instance by assigning values to its parameters but do no install it.
 
=cut

sub create {
    my $self = shift;

    $self->reveal_myself;
    $self->initialize_guest_params;
    $self->config_guest_params(@_);
    $self->print_guest_params;
    return $self;
}

=head2 initialize_guest_params
    
  initialize_guest_params($self)
    
Initialize all guest parameters to avoid uninitialized parameters.
 
=cut

sub initialize_guest_params {
    my $self = shift;

    $self->reveal_myself;
    $self->{$_} //= '' foreach (keys %_guest_params);
    $self->{start_run} = time();
    return $self;
}

=head2 config_guest_params

  config_guest_params($self, %_guest_params)

Assign real values to guest instance parameters. Reset [guest_name] to guest name
used in [guest_metadata] if they are different. The subroutine can be called
mainly in two different ways: Firstly, config_guest_params can be called in
another subroutine, for example, create which takes a hash/dictionary as argument.
my %testhash = ('key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3'),
$self->create(%testhash) which calls $self->config_guest_params(@_). Secondly,
config_guest_params can also be called direcly, for example, 
$self->config_guest_params(%testhash). Call revise_guest_version_and_build to
correct guest version and build parameters to avoid mismatch if necessary.

=cut

sub config_guest_params {
    my $self = shift;
    my %_guest_params = @_;

    $self->reveal_myself;
    if ((scalar(@_) % 2 eq 0) and (scalar(@_) gt 0)) {
        record_info("Configuring guest instance by using following parameters:", Dumper(\%_guest_params));
        map { $self->{$_} = $_guest_params{$_} } keys %_guest_params;
    }
    else {
        record_info("Can not configure guest instance with empty or odd number of arguments.Mark it as failed.", Dumper(\%_guest_params), result => 'fail');
        $self->record_guest_installation_result('FAILED') if ($self->{guest_installation_result} eq '');
        return $self;
    }

    if ((defined $self->{guest_metadata}) and (grep { /name=/ } split(',', $self->{guest_metadata}))) {
        my $_guest_name_in_metadata = grep { /name=(.*)/ } split(',', $self->{guest_metadata});
        if (($self->{guest_name} ne $_guest_name_in_metadata) and ($self->{guest_installation_result} eq '')) {
            record_info("The guest instance has a different name $_guest_name_in_metadata in metadata than $self->{guest_name}.", "Reset guest name to $_guest_name_in_metadata.");
            $self->{guest_name} = $_guest_name_in_metadata;
        }
    }

    $self->revise_guest_version_and_build;
    return $self;
}

=head2 revise_guest_version_and_build

  revise_guest_version_and_build($self, %_guest_params)

Correct [guest_version], [guest_version_major], [guest_version_minor] and
[guest_build] if they are not set correctly or mismatch with each other. Set
[guest_version] to the developing product version if it is not given. Set
[guest_version_major] and [guest_version_minor] from [guest_version] it they do
not match with [guest_version]. Set [guest_build] to get_required_var('BUILD')
if it is empty and developing [guest_version], or 'GM' if non-developing
[guest_version]. This subroutine help make things better and life easier but
the end user should always pay attention and use meaningful and correct guest
parameter and profile.

=cut

sub revise_guest_version_and_build {
    my $self = shift;
    my %_guest_params = @_;

    $self->reveal_myself;
    if ($self->{guest_version} eq '') {
        $self->{guest_version} = ((get_var('REPO_0_TO_INSTALL', '') eq '') ? (lc get_required_var('VERSION')) : (lc get_required_var('VERSION_TO_INSTALL')));
        record_info("Guest $self->{guest_name} does not have guest_version set.Set it to test suite setting VERSION", "Please pay attention ! It is now $self->{guest_version}");
    }

    if ($self->{guest_os_name} =~ /sles|oraclelinux|slem|slm/im) {
        if (($self->{guest_version_major} eq '') or (!($self->{guest_version} =~ /^(r)?$self->{guest_version_major}((-|\.)?(sp|u)?(\d*))?$/im))) {
            ($self->{guest_version_major}) = $self->{guest_version} =~ /(\d+)[-|\.]?.*$/im;
            record_info("Guest $self->{guest_name} does not have guest_version_major set or it does not match with guest_version.Set it from guest_version", "Please pay attention ! It is now $self->{guest_version_major}");
        }
        if (($self->{guest_version_minor} eq '') or (!($self->{guest_version} =~ /^(r)?(\d+)(-|\.)?(sp|u)?$self->{guest_version_minor}$/im))) {
            $self->{guest_version} =~ /^.*(-|\.)(sp|u)?(\d*)$/im;
            $self->{guest_version_minor} = (($3 eq '') ? 0 : $3);
            record_info("Guest $self->{guest_name} does not have guest_version_minor set or it does not match with guest_version.Set it from guest_version", "Please pay attention ! It is now $self->{guest_version_minor}");
        }
    }

    if ($self->{guest_build} eq '') {
        if ((!get_var('REPO_0_TO_INSTALL') and ($self->{guest_version} eq lc get_required_var('VERSION'))) or (get_var('REPO_0_TO_INSTALL') and ($self->{guest_version} eq lc get_required_var('TARGET_DEVELOPING_VERSION')))) {
            # BUILD is not the only parameter to indicate real build numbe of installation media,
            # for example, openQA SLE Micro group use BUILD_ISO to do this and the BUILD is being
            # used for grouping all relevant test suites together under the same goup. Thus it is
            # necessary to have BUILD_ISO here as well to generate correct build number for guest.
            $self->{guest_build} = lc get_var('BUILD_ISO', get_required_var('BUILD'));
        }
        else {
            $self->{guest_build} = 'gm';
        }
        record_info("Guest $self->{guest_name} does not have guest_build set.Set it to test suite setting BUILD or GM according to guest_version", "Please pay attention ! It is now $self->{guest_build}");
    }
    return $self;
}

=head2 print_guest_params

  print_guest_params($self)

Print out guest instance parameters.

=cut

sub print_guest_params {
    my $self = shift;

    $self->reveal_myself;
    diag("The guest instance $self->{guest_name} created is as below:");
    foreach (keys %{$self}) {
        if (defined $self->{$_}) {
            if (ref($self->{$_}) eq 'HASH') {
                diag $_ . ' => ' . Dumper(\%{$self->{$_}});
            }
            elsif (ref($self->{$_}) eq 'ARRAY') {
                diag $_ . ' => ' . @{$self->{$_}};
            }
            else {
                diag $_ . ' => ' . $self->{$_};
            }
        }
        else {
            diag $_ . ' => ' . 'undef';
        }
    }
    return $self;
}

=head2 prepare_common_environment

  prepare_common_environment($self)

Install necessary packages, patterns, setup ssh config, create [common_log_folder].
These are common environment affairs which will be used for all guest instances.

=cut

sub prepare_common_environment {
    my $self = shift;

    $self->reveal_myself;
    if ($_host_params{common_environment_prepared} eq 'false') {
        $self->clean_up_all_guests;
        disable_and_stop_service('named.service', ignore_failure => 1);
        script_run("rm -f -r $_host_params{common_log_folder}");
        assert_script_run("mkdir -p $_host_params{common_log_folder}");
        my @stuff_to_backup = ('/root/.ssh/config', '/etc/ssh/ssh_config', '/etc/hosts');
        virt_autotest::utils::backup_file(\@stuff_to_backup);
        script_run("rm -f -r /root/.ssh/config");
        virt_autotest::utils::setup_common_ssh_config(ssh_id_file => $_host_params{ssh_key_file});
        script_run("[ -f /etc/ssh/ssh_config ] && sed -i -r -n \'s/^.*IdentityFile.*\$/#&/\' /etc/ssh/ssh_config");
        enable_debug_logging;
        $_host_params{host_sutip} = get_required_var('SUT_IP') if (is_ipmi);
        my $_default_route = script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+", proceed_on_failure => 1);
        my $_default_device = ((!$_default_route) ? 'br0' : (split(' ', script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+ | head -1")))[4]);
        $_host_params{host_ipaddr} = (split('/', (split(' ', script_output("ip addr show dev $_default_device | grep \"inet \"")))[1]))[0];
        $_host_params{host_sutip} = $_host_params{host_ipaddr} if (is_qemu);
        $_host_params{host_name} = script_output("hostname");
        # For SUTs with multiple interfaces, `dnsdomainname` sometimes does not work
        $_host_params{host_domain_name} = script_output("dnsdomainname", proceed_on_failure => 1);
        ($_host_params{host_version_major},
            $_host_params{host_version_minor},
            $_host_params{host_version_id}) = get_os_release;
        record_info("Host running $_host_params{host_version_id} "
              . "with version major $_host_params{host_version_major} "
              . "minor $_host_params{host_version_minor}", script_output("cat /etc/os-release"));
        $self->prepare_ssh_key;
        $self->prepare_non_transactional_environment;
        $_host_params{common_environment_prepared} = 'true';
        diag("Common environment preparation is done now.");
    }
    else {
        diag("Common environment preparation had already been done.");
    }
    return $self;
}

=head2 prepare_ssh_key

  prepare_ssh_key($self)

Prepare ssh key [ssh_public_key] and [ssh_private_key] for passwordless ssh login
from host to guest. [ssh_command] stores options and username to be used with ssh
login.

=cut

sub prepare_ssh_key {
    my $self = shift;

    $self->reveal_myself;
    if (!((script_run("[[ -f $_host_params{ssh_key_file}.pub ]] && [[ -f $_host_params{ssh_key_file}.pub.bak ]]") == 0) and (script_run("cmp $_host_params{ssh_key_file}.pub $_host_params{ssh_key_file}.pub.bak") == 0))) {
        assert_script_run("rm -f -r $_host_params{ssh_key_file}*");
        assert_script_run("ssh-keygen -f $_host_params{ssh_key_file} -q -P \"\" <<<y");
        assert_script_run("cp $_host_params{ssh_key_file}.pub $_host_params{ssh_key_file}.pub.bak");
    }
    assert_script_run("chmod 600 $_host_params{ssh_key_file} $_host_params{ssh_key_file}.pub");
    $_host_params{ssh_public_key} = script_output("cat $_host_params{ssh_key_file}.pub");
    $_host_params{ssh_private_key} = script_output("cat $_host_params{ssh_key_file}");
    if (is_sle('16+')) {
        $_host_params{ssh_command} = "ssh -vvv -o HostKeyAlgorithms=+ssh-ed25519 ";
    } else {
        $_host_params{ssh_command} = "ssh -vvv -o HostKeyAlgorithms=+ssh-rsa ";
    }
    if ($_host_params{host_version_id} eq 'sles' and
        is_sle("<=15-sp5", "$_host_params{host_version_major}-SP$_host_params{host_version_minor}")) {
        $_host_params{ssh_command} .= "-o PubkeyAcceptedKeyTypes=+ssh-rsa ";
    }
    else {
        if (is_sle('16+')) {
            $_host_params{ssh_command} .= "-o PubkeyAcceptedAlgorithms=+ssh-ed25519 ";
        } else {
            $_host_params{ssh_command} .= "-o PubkeyAcceptedAlgorithms=+ssh-rsa ";
        }
    }
    $_host_params{ssh_command} .= "-i $_host_params{ssh_key_file} root";
    return $self;
}

=head2 prepare_non_transactional_environment

  prepare_non_transactional_environment($self)

Do preparation on non-transactional server.

=cut

sub prepare_non_transactional_environment {
    my $self = shift;

    $self->reveal_myself;
    if (!is_transactional) {
        virt_autotest::utils::setup_rsyslog_host($_host_params{common_log_folder}) if (is_sle('<16'));
        my $_packages_to_check = 'wget curl screen dnsmasq xmlstarlet python3 nmap';
        $_packages_to_check .= ' yast2-schema' if (is_sle('<16'));
        zypper_call("install -y $_packages_to_check");
        # There is already the highest version for kvm/xen packages on TW
        zypper_call("install -y -t pattern $self->{host_virt_type}_server $self->{host_virt_type}_tools") if (is_sle);
    }
    return $self;
}

=head2 clean_up_all_guests

  clean_up_all_guests($self)

Remove all existing guests and affecting storage files.

=cut

sub clean_up_all_guests {
    my $self = shift;

    $self->reveal_myself;
    my @_guests_to_clean_up = split(/\n/, script_output("virsh list --all --name | grep -v Domain-0", proceed_on_failure => 1));
    # Clean up all guests
    if (scalar(@_guests_to_clean_up) gt 0) {
        diag("Going to clean up all guests on $_host_params{host_name}");
        foreach (@_guests_to_clean_up) {
            script_run("virsh destroy $_");
            script_run("virsh undefine $_ --nvram") if (script_run("virsh undefine $_") ne 0);
        }
        save_screenshot;
        record_info("Cleaned all existing vms.");
    }
    else {
        diag("No guests reside on this host $_host_params{host_name}");
    }

    # Clean up all guest images
    foreach (split(/,/, get_required_var('UNIFIED_GUEST_LIST'))) {
        script_run("rm -f -r /var/lib/libvirt/images/$self->{guest_name}.*");
        script_run("rm -f -r /var/lib/libvirt/images/$self->{guest_name}");
    }
    save_screenshot;
    record_info("Cleaned all potential affecting disk files.");

    return $self;
}

=head2 prepare_guest_environment

  prepare_guest_environment($self)

Create individual guest log folder using its name and remove existing entry in /etc/hosts.

=cut

sub prepare_guest_environment {
    my $self = shift;

    $self->reveal_myself;
    $self->{guest_image_folder} = '/var/lib/libvirt/images/' . $self->{guest_name};
    $self->{guest_log_folder} = $_host_params{common_log_folder} . '/' . $self->{guest_name};
    script_run("rm -f -r $self->{guest_image_folder} $self->{guest_log_folder}");
    assert_script_run("mkdir -p $self->{guest_image_folder} $self->{guest_log_folder}");
    script_run("sed -i -r \'/^.*$self->{guest_name}.*\$/d\' /etc/hosts");
    return $self;
}

=head2 config_guest_name

  config_guest_name($self, @_)

Configure [guest_domain_name] and [guest_name_options].User can still change
[guest_name] and [guest_domain_name] by passing non-empty arguments using hash.

=cut

sub config_guest_name {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_installation_result} eq '') {
        if ($self->{guest_network_type} eq 'bridge' and $self->{guest_network_mode} eq 'host') {
            $self->{guest_domain_name} = $_host_params{host_domain_name};
        }
        $self->{guest_domain_name} = 'testvirt.net' if ($self->{guest_domain_name} eq '');
        $self->{guest_name_options} = "--name $self->{guest_name}";
    }
    return $self;
}

=head2 config_guest_metadata

  config_guest_metadata($self[, guest_metadata => 'metadata'])

Configure [guest_metadata_options]. User can still change [guest_metadata] by
assing non-empty arguments using hash. If installation already passes,
modify_guest_params will be called to modify [guest_metadata] using already
modified [guest_metadata_options].

=cut

sub config_guest_metadata {
    my $self = shift;

    $self->reveal_myself;
    my $_current_metadata_options = $self->{guest_metadata_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_metadata} ne '') {
        $self->{guest_metadata_options} = "--metadata $self->{guest_metadata}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_metadata_options ne $self->{guest_metadata_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_metadata_options');
        }
    }
    return $self;
}

=head2 config_guest_vcpus

  config_guest_vcpus($self[, guest_vcpus => 'vcpus'])

Configure [guest_vcpus_options].User can still change [guest_vcpus] by passing
non-empty arguments using hash. If installations already passes,modify_guest_params
will be called to modify [guest_vcpus] using already modified [guest_vcpus_options].

=cut

sub config_guest_vcpus {
    my $self = shift;

    $self->reveal_myself;
    my $_current_vcpus_options = $self->{guest_vcpus_options};
    my $_current_cpumodel_options = $self->{guest_cpumodel_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_vcpus} = 2 if ($self->{guest_vcpus} eq '');
    $self->{guest_vcpus_options} = "--vcpus $self->{guest_vcpus}";
    $self->{guest_cpumodel_options} = "--cpu $self->{guest_cpumodel}" if ($self->{guest_cpumodel} ne '');
    if ($self->{guest_installation_result} eq 'PASSED') {
        $self->modify_guest_params($self->{guest_name}, 'guest_vcpus_options') if ($_current_vcpus_options ne $self->{guest_vcpus_options});
        $self->modify_guest_params($self->{guest_name}, 'guest_cpumodel_options') if ($_current_cpumodel_options ne $self->{guest_cpumodel_options});
    }
    return $self;
}

=head2 config_guest_memory

  config_guest_memory($self[, guest_memory => 'memory'])

Configure [guest_memory_options]. User can still change [guest_memory],
[guest_memballoon], [guest_memdev], [guest_memtune] and [guest_memorybacking] by
passing non-empty arguments using hash. If installation already passes,
modify_guest_params will be called to modify [guest_memory], [guest_memballoon],
[guest_memdev], [guest_memtune] and [guest_memorybacking] using already modified
[guest_memory_options].

=cut

sub config_guest_memory {
    my $self = shift;

    $self->reveal_myself;
    my $_current_memory_options = $self->{guest_memory_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_memory} = 2048 if ($self->{guest_memory} eq '');
    $self->{guest_memory_options} = "--memory $self->{guest_memory}";
    $self->{guest_memory_options} .= " --memballoon $self->{guest_memballoon}" if ($self->{guest_memballoon} ne '');
    $self->{guest_memory_options} .= " --memdev $self->{guest_memdev}" if ($self->{guest_memdev} ne '');
    $self->{guest_memory_options} .= " --memtune $self->{guest_memtune}" if ($self->{guest_memtune} ne '');
    $self->{guest_memory_options} .= " --memorybacking $self->{guest_memorybacking}" if ($self->{guest_memorybacking} ne '');
    if (($self->{guest_installation_result} eq 'PASSED') and ($_current_memory_options ne $self->{guest_memory_options})) {
        $self->modify_guest_params($self->{guest_name}, 'guest_memory_options');
    }
    return $self;
}

=head2 config_guest_numa

  config_guest_numa($self[, guest_numatune => 'numatune'])

Configure [guest_numa_options]. User can still change [guest_numatune], by
passing non-empty arguments using hash. If installation already passes,
modify_guest_params will be called to modify [guest_numatune] using already
modified [guest_numa_options].

=cut

sub config_guest_numa {
    my $self = shift;

    $self->reveal_myself;
    my $_current_numa_options = $self->{guest_numa_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_numa_options} .= " --numatune $self->{guest_numatune}" if ($self->{guest_numatune} ne '');
    if (($self->{guest_installation_result} eq 'PASSED') and ($_current_numa_options ne $self->{guest_numa_options})) {
        $self->modify_guest_params($self->{guest_name}, 'guest_numa_options');
    }
    return $self;
}

=head2 config_guest_virtualization

  config_guest_virtualization($self[, host_hypervisor_uri => 'uri', host_virt_type => 'type'])

Configure [guest_virt_options].User can still change [host_hypervisor_uri],
[host_virt_type] and [guest_virt_options] by passing non-empty arguments using
hash.

=cut

sub config_guest_virtualization {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_installation_result} eq '') {
        $self->{guest_virt_options} = "--connect $self->{host_hypervisor_uri} " if ($self->{host_hypervisor_uri} ne '');
        if ($self->{host_virt_type} eq '') {
            $self->{host_virt_type} = 'kvm';
            $self->{host_virt_type} = 'xen' if (script_output("journalctl -b | grep -i \"Hypervisor detected.*Xen\"", proceed_on_failure => 1) ne '');
        }
        $self->{guest_virt_options} = $self->{guest_virt_options} . "--virt-type $self->{host_virt_type} ";
        $self->{guest_virt_type} = 'hvm' if ($self->{guest_virt_type} eq '');
        $self->{guest_virt_options} = $self->{guest_virt_options} . "--$self->{guest_virt_type}";
    }
    return $self;
}

=head2 config_guest_platform

  config_guest_platform($self[, guest_arch => 'arch', guest_machine_type => 'type'])

Configure [guest_platform_options].User can still change [guest_arch] and
[guest_machine_type] by passing non-empty arguments using hash.

=cut

sub config_guest_platform {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_installation_result} eq '') {
        $self->{guest_platform_options} = "--arch $self->{guest_arch}" if ($self->{guest_arch} ne '');
        $self->{guest_platform_options} = $self->{guest_platform_options} . " --machine $self->{guest_machine_type}" if ($self->{guest_machine_type} ne '');
    }
    return $self;
}

=head2 config_guest_os_variant

  config_guest_os_variant($self[, guest_os_variant => 'os'])

Configure [guest_os_variant_options]. User can still change [guest_os_variant]
by passing non-empty arguments using hash. If installations already passes,
modify_guest_params will be called to modify [guest_os_variant] using already
modified [guest_os_variant_options].

=cut

sub config_guest_os_variant {
    my $self = shift;

    $self->reveal_myself;
    my $_current_os_variant_options = $self->{guest_os_variant_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_os_variant} ne '') {
        $self->{guest_os_variant_options} = "--os-variant $self->{guest_os_variant}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_os_variant_options ne $self->{guest_os_variant_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_os_variant_options');
        }
    }
    return $self;
}

=head2 config_guest_graphics_and_video

  config_guest_graphics_and_video($self[, guest_video => 'video', guest_graphics => 'graphics'])

Configure [guest_graphics_and_video_options]. User can still change [guest_video]
and [guest_graphics] by passing non-empty arguments using hash. If installations
already passes,modify_guest_params will be called to modify [guest_video] and
[guest_graphics] using already modified [guest_graphics_and_video_options].

=cut

sub config_guest_graphics_and_video {
    my $self = shift;

    $self->reveal_myself;
    my $_current_graphics_and_video_options = $self->{guest_graphics_and_video_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_graphics_and_video_options} = (($self->{guest_video} eq '') ? '' : "--video $self->{guest_video}");
    $self->{guest_graphics_and_video_options} = (($self->{guest_graphics} eq '') ? $self->{guest_graphics_and_video_options} : "$self->{guest_graphics_and_video_options} --graphics $self->{guest_graphics}");
    if (($self->{guest_installation_result} eq 'PASSED') and ($_current_graphics_and_video_options ne $self->{guest_graphics_and_video_options})) {
        $self->modify_guest_params($self->{guest_name}, 'guest_graphics_and_video_options');
    }
    return $self;
}

=head2 config_guest_channels

  config_guest_channels($self[, guest_channel => 'channel'])

Configure [guest_channel_options]. User can still change [guest_channel] by passing
non-empty arguments using hash. If installations already passes, modify_guest_params
will be called to modify [guest_channel] using already modified [guest_channel_options].
Multiple channels are allowd for a single guest, they should be passed in with hash
symbol '#' as separator, for example, 'type=unix#spicevmc'.

=cut

sub config_guest_channels {
    my $self = shift;

    $self->reveal_myself;
    my $_current_channel_options = $self->{guest_channel_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_channel} ne '') {
        foreach (split('#', $self->{guest_channel})) {
            $self->{guest_channel_options} .= " --channel $_";
        }
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_channel_options ne $self->{guest_channel_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_channel_options');
        }
    }
    return $self;
}

=head2 config_guest_consoles

  config_guest_consoles($self[, guest_console => 'console', guest_serial => 'serial'])

Configure [guest_console_options] and [guest_serial_options]. User can still
change [guest_console] and [guest_serial] by passing non-empty arguments using
hash. If installations already passes, modify_guest_params will be called to
modify [guest_console] and [guest_serial] using already modified [guest_console_options] 
and [guest_serial_options].

=cut

sub config_guest_consoles {
    my $self = shift;

    $self->reveal_myself;
    my $_current_console_options = $self->{guest_console_options};
    my $_current_serial_options = $self->{guest_serial_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_console} ne '') {
        $self->{guest_console_options} = "--console $self->{guest_console}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_console_options ne $self->{guest_console_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_console_options');
        }
    }
    if ($self->{guest_serial} ne '') {
        $self->{guest_serial_options} = "--serial $self->{guest_serial}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_serial_options ne $self->{guest_serial_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_serial_options');
        }
    }
    return $self;
}

=head2 config_guest_features

  config_guest_features($self[, guest_features => 'features'])

Configure [guest_features_options]. User can still change [guest_features] by
passing non-empty arguments using hash. If installations already passes,
modify_guest_params will be called to modify [guest_features] using already
modified [guest_features_options].

=cut

sub config_guest_features {
    my $self = shift;

    $self->reveal_myself;
    my $_current_features_options = $self->{guest_features_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_features} ne '') {
        $self->{guest_features_options} = "--features $self->{guest_features}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_features_options = $self->{guest_features_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_features_options');
        }
    }
    return $self;
}

=head2 config_guest_events

  config_guest_events($self[, guest_events => 'events'])

Configure [guest_events_options]. User can still change [guest_events] by passing
non-empty arguments using hash. If installations already passes,modify_guest_params
will be called to modify [guest_events] using already modified [guest_events_options].

=cut

sub config_guest_events {
    my $self = shift;

    $self->reveal_myself;
    my $_current_events_options = $self->{guest_events_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_events} ne '') {
        $self->{guest_events_options} = "--events $self->{guest_events}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_events_options ne $self->{guest_events_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_events_options');
        }
    }
    return $self;
}

=head2 config_guest_boot_settings

  config_guest_boot_settings($self[, guest_boot_settings => 'settings'])

Configure [guest_boot_options]. User can still change [guest_boot_settings] by
passing non-empty arguments using hash. If installations already passes, 
modify_guest_params will be called to modify [guest_boot_settings] using already
modified [guest_boot_options].

=cut

sub config_guest_boot_settings {
    my $self = shift;

    $self->reveal_myself;
    my $_current_boot_options = $self->{guest_boot_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_boot_settings} ne '') {
        $self->{guest_boot_options} = "--boot $self->{guest_boot_settings}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_boot_options ne $self->{guest_boot_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_boot_options');
        }
    }
    return $self;
}

=head2 config_guest_power_management

  config_guest_power_management($self[, guest_power_management => 'power'])

Configure [guest_power_management_options]. User can still change [guest_power_management]
by passing non-empty arguments using hash. If installations already passes,
modify_guest_params will be called to modify [guest_power_management] using already
modified [guest_power_management_options].

=cut

sub config_guest_power_management {
    my $self = shift;

    $self->reveal_myself;
    my $_current_power_management_options = $self->{guest_power_management_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_power_management} ne '') {
        $self->{guest_power_management_options} = "--pm $self->{guest_power_management}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_power_management_options ne $self->{guest_power_management_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_power_management_options');
        }
    }
    return $self;
}

=head2 config_guest_xpath

  config_guest_xpath($self[, guest_xpath => 'xpath'])

Configure [guest_xpath_options]. User can still change [guest_xpath] by passing
non-empty arguments using hash. If installations already passes, modify_guest_params
will be called to modify [guest_xpath] using already modified [guest_xpath_options].

=cut

sub config_guest_xpath {
    my $self = shift;

    $self->reveal_myself;
    my $_current_xpath_options = $self->{guest_xpath_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_xpath} ne '') {
        my @_guest_xpath = split(/#/, $self->{guest_xpath});
        $self->{guest_xpath_options} = $self->{guest_xpath_options} . "--xml $_ " foreach (@_guest_xpath);
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_xpath_options ne $self->{guest_xpath_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_xpath_options');
        }
    }
    return $self;
}

=head2 config_guest_qemu_command

  config_guest_qemu_command($self[, guest_qemu_command => 'command'])

Configure [guest_qemu_command_options]. User can still change [guest_qemu_command]
by passing non-empty arguments using hash. If installations already passes,
modify_guest_params will be called to modify [guest_qemu_command] using already
modified [guest_qemu_command_options].

=cut

sub config_guest_qemu_command {
    my $self = shift;

    $self->reveal_myself;
    my $_current_qemu_command_options = $self->{guest_qemu_command_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_qemu_command} ne '') {
        $self->{guest_qemu_command_options} = "--qemu-commandline $self->{guest_qemu_command}";
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_qemu_command_options ne $self->{guest_qemu_command_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_qemu_command_options');
        }
    }
    return $self;
}

=head2 config_guest_security

  config_guest_security($self [, guest_seclabel => 'seclabel'] [, guest_launchsecurity => 'launchsecurity'])

Configure [guest_security_options]. User can still change [guest_security] and
[guest_launchsecurity] by passing non-empty arguments using hash. If installation
already passes, modify_guest_params will be called to modify guest_security] and
[guest_launchsecurity] using already modified [guest_security_options].

=cut

sub config_guest_security {
    my $self = shift;

    $self->reveal_myself;
    my $_current_security_options = $self->{guest_security_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_security_options} = "--seclabel $self->{guest_seclabel}" if ($self->{guest_seclabel} ne '');
    $self->{guest_security_options} .= " --launchSecurity $self->{guest_launchsecurity}" if ($self->{guest_launchsecurity} ne '');
    if (($self->{guest_installation_result} eq 'PASSED') and ($_current_security_options ne $self->{guest_security_options})) {
        $self->modify_guest_params($self->{guest_name}, 'guest_security_options');
    }
    return $self;
}

=head2 config_guest_controller

  config_guest_controller($self [, guest_controller => 'controller'])

Configure [guest_controller_options]. User can still change [guest_controller] by
passing non-empty arguments using hash. [guest_controller] can have more than one
type controller which should be separated by hash symbol, for example, 'controller1
_config#controller2_config#controller3_config'. Then it will be splitted and
passed to individual '--controller' argument to form [guest_controller_options]
= '--controller controller1_config --controller controller2_config --controller
controller3_config'. If installation already passes, modify_guest_params will be
called to modify [guest_controller] using already modified [guest_controller_options].

=cut

sub config_guest_controller {
    my $self = shift;

    $self->reveal_myself;
    my $_current_controller_options = $self->{guest_controller_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_controller} ne '') {
        my @_guest_controller = split(/#/, $self->{guest_controller});
        $self->{guest_controller_options} = $self->{guest_controller_options} . "--controller $_ " foreach (@_guest_controller);
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_controller_options ne $self->{guest_controller_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_controller_options');
        }
    }
    return $self;
}

=head2 config_guest_tpm

  config_guest_tpm($self [, guest_tpm => 'tpm'])

Configure [guest_tpm_options]. User can still change [guest_tpm] by passing 
non-empty arguments using hash. If installations already passes, modify_guest_params 
will be called to modify [guest_tpm] using already modified [guest_tpm_options].

=cut

sub config_guest_tpm {
    my $self = shift;

    $self->reveal_myself;
    my $_current_tpm_options = $self->{guest_tpm_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_tpm_options} = "--tpm $self->{guest_tpm}" if ($self->{guest_tpm} ne '');
    if (($self->{guest_installation_result} eq 'PASSED') and ($_current_tpm_options ne $self->{guest_tpm_options})) {
        $self->modify_guest_params($self->{guest_name}, 'guest_tpm_options');
    }
    return $self;
}

=head2 config_guest_rng

  config_guest_rng($self [, guest_rng => 'rng'])

Configure [guest_rng_options]. User can still change [guest_rng] by passing 
non-empty arguments using hash. If installations already passes, modify_guest_params 
will be called to modify [guest_rng] using already modified [guest_rng_options].

=cut

sub config_guest_rng {
    my $self = shift;

    $self->reveal_myself;
    my $_current_rng_options = $self->{guest_rng_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_rng_options} = "--rng $self->{guest_rng}" if ($self->{guest_rng} ne '');
    if (($self->{guest_installation_result} eq 'PASSED') and ($_current_rng_options ne $self->{guest_rng_options})) {
        $self->modify_guest_params($self->{guest_name}, 'guest_rng_options');
    }
    return $self;
}

=head2 config_guest_sysinfo

  config_guest_sysinfo($self[, guest_sysinfo => 'sysinfo'])

Configure [guest_sysinfo_options]. User can still change [guest_sysinfo] by passing
non-empty arguments using hash. Multiple sysinfos are allowd for a single guest, 
they should be passed in with hash symbol '#' as separator, for example, 'sysinfo1#
sysinfo2'. If installation already passes, modify_guest_params will be called to
modify [guest_sysinfo] using already modified [guest_sysinfo_options].

=cut

sub config_guest_sysinfo {
    my $self = shift;

    $self->reveal_myself;
    my $_current_sysinfo_options = $self->{guest_sysinfo_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_sysinfo} ne '') {
        foreach (split('#', $self->{guest_sysinfo})) {
            $self->{guest_sysinfo_options} .= " --sysinfo $_";
        }
        if (($self->{guest_installation_result} eq 'PASSED') and ($_current_sysinfo_options ne $self->{guest_sysinfo_options})) {
            $self->modify_guest_params($self->{guest_name}, 'guest_sysinfo_options');
        }
    }
    return $self;
}

=head2 config_guest_storage

  config_guest_rng($self [, key-value pairs of guest storage arguments])

Configure [guest_storage_options]. User can still change [guest_storage_type],
[guest_storage_size], [guest_storage_format], [guest_storage_label], [guest_storage_path]
and [guest_storage_others] by passing non-empty arguments using hash. If installations
already passes, modify_guest_params will be called to modify [guest_storage_type],
[guest_storage_size], [guest_storage_format], [guest_storage_path] and
[guest_storage_others] using already modified [guest_storage_options].

=cut

sub config_guest_storage {
    my $self = shift;

    $self->reveal_myself;
    my $_current_storage_options = $self->{guest_storage_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_storage_size} = '16' if ($self->{guest_storage_size} eq '');
    $self->{guest_storage_format} = 'qcow2' if ($self->{guest_storage_format} eq '');
    $self->{guest_storage_label} = 'gpt' if ($self->{guest_storage_label} eq '');
    if ($self->{guest_storage_path} eq '') {
        $self->{guest_storage_path} = "$self->{guest_image_folder}/$self->{guest_name}.$self->{guest_storage_format}";
    }
    else {
        $self->{guest_storage_path} = "$self->{guest_storage_path}/$self->{guest_name}.$self->{guest_storage_format}";
    }

    if ($self->{guest_storage_type} eq 'disk') {
        if ($self->{guest_installation_method} eq 'location' or $self->{guest_installation_method} eq 'directkernel') {
            $self->{guest_storage_options} = "--disk path=$self->{guest_storage_path},size=$self->{guest_storage_size},format=$self->{guest_storage_format}";
        }
        elsif ($self->{guest_installation_method} eq 'import') {
            if ($self->{guest_storage_backing_path} eq '') {
                $self->{guest_storage_backing_path} = "$self->{guest_image_folder}/$self->{guest_name}_" . (split('/', $self->{guest_installation_media}))[-1];
            }
            $self->{guest_storage_backing_path} =~ s/12345/$self->{guest_build}/g if ($self->{guest_build} ne 'gm');
            $self->{guest_storage_backing_path} =~ s/\.xz$//i;
            $self->{guest_storage_backing_path} =~ /\.([\w]{1,})$/i;
            $self->{guest_storage_backing_format} = $1;
            $self->{guest_storage_options} = "--disk type=file,device=disk,source.file=$self->{guest_storage_path},size=$self->{guest_storage_size},format=$self->{guest_storage_format},driver.type=$self->{guest_storage_format}";
            $self->{guest_storage_options} = $self->{guest_storage_options} . ",backing_store=$self->{guest_storage_backing_path},backing_format=$self->{guest_storage_backing_format}";
            $self->{guest_storage_options} = $self->{guest_storage_options} . ",target.dev=vda,target.bus=virtio";
        }
    }
    $self->{guest_storage_options} = $self->{guest_storage_options} . ",$self->{guest_storage_others}" if ($self->{guest_storage_others} ne '');
    if (($self->{guest_installation_result} eq 'PASSED') and ($_current_storage_options = $self->{guest_storage_options})) {
        $self->modify_guest_params($self->{guest_name}, 'guest_storage_options');
    }
    return $self;
}

=head2 config_guest_network_selection

  config_guest_network_selection($self [, key-value pairs of guest network arguments])

Create network, type of which is either vnet or bridge, to be used with guest. In 
order to make network configuration consistent, global structure guest_network_matrix
in module guest_installation_and_configuration_metadata.pm will be used for fetching
network configuration. It covers almost all types of network configuration, including
nat/forward/bridge/default mode in vnet and bridge/host mode in bridge networks.
[guest_network_type] and [guest_network_mode] will be used for specifying desired
network configuration, although customized network device name and address can
still be specified by [guest_network_device] and [guest_netaddr]. For guest using
static ip address, address info is derived from [guest_ipaddr] only.

=cut

sub config_guest_network_selection {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->config_guest_macaddr if ($self->{guest_macaddr} eq '');
    my ($_ipaddr, $_netmask, $_masklen, $_startaddr, $_endaddr) = ('', '', '', '', '');
    if ($self->{guest_network_device} eq '') {
        $self->{guest_network_device} = $_guest_network_matrix{$self->{guest_network_type}}{$self->{guest_network_mode}}{device};
    }
    if ($self->{guest_netaddr} eq '') {
        $_netmask = $_guest_network_matrix{$self->{guest_network_type}}{$self->{guest_network_mode}}{netmask};
        $_masklen = $_guest_network_matrix{$self->{guest_network_type}}{$self->{guest_network_mode}}{masklen};
        if ($self->{guest_ipaddr_static} eq 'true') {
            croak("Guest $self->{guest_name} has no given static ip address although it is configured to use static ip address") if ($self->{guest_ipaddr} eq '');
            $_ipaddr = (split(/\.([^\.]+)$/, $self->{guest_ipaddr}))[0] . '.1';
            $_startaddr = (split(/\.([^\.]+)$/, $self->{guest_ipaddr}))[0] . '.2';
            $_endaddr = (split(/\.([^\.]+)$/, $self->{guest_ipaddr}))[0] . '.254';
        }
        else {
            $_ipaddr = $_guest_network_matrix{$self->{guest_network_type}}{$self->{guest_network_mode}}{ipaddr};
            $_startaddr = $_guest_network_matrix{$self->{guest_network_type}}{$self->{guest_network_mode}}{startaddr};
            $_endaddr = $_guest_network_matrix{$self->{guest_network_type}}{$self->{guest_network_mode}}{endaddr};
        }
        $self->{guest_netaddr} = $_ipaddr . '/' . $_masklen;
    }
    else {
        (my $_temp, $_netmask, $_masklen, $_ipaddr, $_startaddr, $_endaddr,) = virt_autotest::utils::parse_subnet_address_ipv4($self->{guest_netaddr});
    }

    record_info("Create network device $self->{guest_network_device} for $self->{guest_name}", "Skip if $self->{guest_name} network device $self->{guest_network_device} is already configured");
    if ($self->{guest_network_type} eq 'vnet') {
        $self->config_guest_network_vnet(_device => $self->{guest_network_device}, _ipaddr => $_ipaddr, _netmask => $_netmask, _startaddr => $_startaddr, _endaddr => $_endaddr);
        $self->config_guest_network_vnet_policy(_device => $self->{guest_network_device});
        my $_network_selected = ((($self->{guest_network_mode}) eq 'default') ? 'default' : $self->{guest_network_device});
        $self->{guest_network_selection_options} = "--network=network=$_network_selected,mac=$self->{guest_macaddr}";
    }
    elsif ($self->{guest_network_type} eq 'bridge') {
        $self->config_guest_network_bridge($self->{guest_network_device}, $_ipaddr . '/24', $self->{guest_domain_name});
        $self->config_guest_network_bridge_policy($self->{guest_network_device});
        $self->{guest_network_selection_options} = "--network=bridge=$self->{guest_network_device},mac=$self->{guest_macaddr}";
    }
    if ($self->{guest_network_others} ne '') {
        $self->{guest_network_selection_options} .= ",$self->{guest_network_others}";
        if ($self->{guest_version} eq '15-sp6' and check_var('VERSION_TO_INSTALL', '12-SP5') and $self->{guest_network_others} =~ /rom_bar=off/) {
            record_soft_failure("bsc#1217359 - [SLES][12-SP5][x86_64][kvm][uefi] Failed to install 15-SP6 uefi guest on 12-SP5 KVM host due to efi exception");
        }
    }
    save_screenshot;
    record_info("Guest network configuration done", script_output("ip addr show;ip route show all;virsh net-list --all;(for i in \`virsh net-list --all --name\`;do virsh net-dumpxml \$i;done);ps axu | grep dnsmasq", type_command => 1, proceed_on_failure => 1));
    return $self;
}

=head2 config_guest_macaddr

  config_guest_macaddr($self)

Generate nearly random mac address.

=cut

sub config_guest_macaddr {
    my $self = shift;

    $self->reveal_myself;
    my $_guest_macaddr_lower_half = join ':', map { unpack "H*", chr(rand(256)) } 1 .. 3;
    if ($self->{guest_network_type} eq 'bridge' and $self->{guest_network_mode} eq 'host') {
        $self->{guest_macaddr} = 'd4:c9:ef:' . $_guest_macaddr_lower_half;
    }
    else {
        $self->{guest_macaddr} = '52:54:00:' . $_guest_macaddr_lower_half;
    }
    return $self;
}

=head2 config_guest_network_vnet

  config_guest_network_vent($self[, _device => 'device', _ipaddr => 'ip', 
  _netmask => 'mask', _startaddr => 'start', _endaddr => 'end'])

Create virtual network to be used with guest based on [guest_network_device] and
passed in arguments, $_ipaddr, $_netmask, $_startaddr and $_endaddr. Skip creating
already existing and active virtual network. Call subroutine virt_autotest::
virtual_network_utils::config_virtual_network_device to do the actual work.

=cut

sub config_guest_network_vnet {
    my ($self, %args) = @_;
    $args{_device} //= '';
    $args{_ipaddr} //= '';
    $args{_netmask} //= '';
    $args{_startaddr} //= '';
    $args{_endaddr} //= '';

    $self->reveal_myself;
    if (!$args{_device} or !$args{_ipaddr} or !$args{_netmask} or !$args{_startaddr} or !$args{_endaddr}) {
        croak("Network device, ip address, network mask, start and end address must be given to create virtual network for guest $self->{guest_name}");
    }
    my $_vnet_name = (($self->{guest_network_mode} eq 'default') ? 'default' : $args{_device});
    unless (script_run("virsh net-list | grep \"$_vnet_name .*active\"") == 0) {
        my $_forward_mode = (($self->{guest_network_mode} eq 'default') ? 'nat' : $self->{guest_network_mode});
        $_forward_mode = (($self->{guest_network_mode} eq 'host') ? 'bridge' : $_forward_mode);
        my $_ret = virt_autotest::virtual_network_utils::config_virtual_network_device(fwdmode => $_forward_mode, name => $_vnet_name, device => $args{_device},
            ipaddr => $args{_ipaddr}, netmask => $args{_netmask}, startaddr => $args{_startaddr}, endaddr => $args{_endaddr}, domainname => $self->{guest_domain_name});
        $self->record_guest_installation_result('FAILED') if ($_ret != 0);
    }
    else {
        record_info("Guest $self->{guest_name} uses vnet $_vnet_name which had already been configured and active", script_output("virsh net-list --all;ip addr show;ip route show all"));
    }
    $self->config_guest_network_vnet_services(_ipaddr => $args{_ipaddr}) if ($_vnet_name ne 'default');
    return $self;
}


=head2 config_guest_network_vnet_services

  config_guest_network_vent_services($self[, )

Make sure virtual network provides services as expected by adding ip address
of [guest_network_device] as nameserver and [guest_domain_name] as search domain
in /etc/resolv.conf. Call subroutine virt_autotest::virtual_network_utils::
config_domain_resolver to do the actual work.

=cut

sub config_guest_network_vnet_services {
    my ($self, %args) = @_;
    $args{_ipaddr} //= '';

    $self->reveal_myself;
    croak("IP address of virtual network device must be given to configure its services") if (!$args{_ipaddr});
    virt_autotest::virtual_network_utils::config_domain_resolver(resolvip => $args{_ipaddr}, domainname => $self->{guest_domain_name});
    return $self;
}

=head2 config_guest_network_vnet_policy

  config_guest_network_vent_policy($self)

Loosen iptables rules for [guest_network_device]. Additionally, write commands
executed into crontab to re-execute them automatically on reboot if host reboots
somehow unexpectedly. IPv6 forwarding should not be enabled due to product bug
bsc#1222229. Calling virt_autotest::virtual_network_utils::config_network_device_policy
to do the actual work.

=cut

sub config_guest_network_vnet_policy {
    my $self = shift;

    $self->reveal_myself;
    my $_network_policy_config_file = virt_autotest::virtual_network_utils::config_network_device_policy(logdir => $self->{guest_log_folder}, name => $self->{guest_name}, netdev => $self->{guest_network_device});
    $self->schedule_tasks_on_boot(_task => "$_network_policy_config_file");
    return $self;
}

=head2 config_guest_network_bridge

  config_guest_network_bridge($self)

Calls virt_autotest::utils::parse_subnet_address_ipv4 to parse detailed subnet
information from [guest_netaddr].Create [guest_network_device] with parsed detailed
subnet information by calling config_guest_network_bridge_device.Start DHCP and
DNS services with parsed detailed subnet information by calling 
config_guest_network_bridge_services. If [guest_network_mode] is equal to 'host',
guest chooses to use host network which is public facing. So there is no need to
do subnet address parsing.

=cut

sub config_guest_network_bridge {
    my ($self, $_guest_network_device, $_guest_network_address, $_guest_network_domain) = @_;

    $self->reveal_myself;
    $_guest_network_device //= '';
    $_guest_network_address //= '';
    $_guest_network_domain //= $self->{guest_domain_name};
    diag("This subroutine requires network device and network address as passed in arguments.") if (($_guest_network_device eq '') or ($_guest_network_address eq ''));
    if ($self->{guest_network_mode} ne 'host') {
        my ($_guest_network_ipaddr, $_guest_network_mask, $_guest_netwok_mask_len, $_guest_network_ipaddr_gw, $_guest_network_ipaddr_start, $_guest_network_ipaddr_end, $_guest_network_ipaddr_rev) = virt_autotest::utils::parse_subnet_address_ipv4($_guest_network_address);
        $self->config_guest_network_bridge_device("$_guest_network_ipaddr_gw/$_guest_netwok_mask_len", "$_guest_network_ipaddr/$_guest_netwok_mask_len", $_guest_network_device);
        $self->config_guest_network_bridge_services($_guest_network_device, $_guest_network_ipaddr_gw, $_guest_network_mask, $_guest_netwok_mask_len, $_guest_network_ipaddr_start, $_guest_network_ipaddr_end, $_guest_network_ipaddr_rev);
    }
    else {
        $self->config_guest_network_bridge_device("host", "host", $_guest_network_device);
    }
    return $self;
}

=head2 config_guest_network_bridge_device

  config_guest_network_bridge_device($self, $_bridge_network,
  $_bridge_network_in_route, $_bridge_device)

Create [guest_network_device] by writing device information into ifcfg file in
/etc/sysconfig/network. Mark guest installation as FAILED if [guest_network_device]
can not be successfully started up. If [guest_network_device] or [guest_netaddr]
already exists and active on host judging by 'ip route show', both of them will
not be created anyway. Call subroutine virt_autotest::virtual_network_utils::
write_network_bridge_device_config and virt_autotest::virtual_network_utils::
activate_network_bridge_device to do the actual work.

=cut

sub config_guest_network_bridge_device {
    my $self = shift;
    my $_bridge_network = shift;
    my $_bridge_network_in_route = shift;
    my $_bridge_device = shift;
    $_bridge_device //= '';
    $self->reveal_myself;
    croak("Bridge device name must be given otherwise configuration can not be done.") if ($_bridge_device eq '');

    unless ((script_run("ip route show | grep -o $_bridge_device") == 0) or (script_run("ip route show | grep -o $_bridge_network_in_route") == 0)) {
        my $_detect_active_route = '';
        my $_detect_inactive_route = '';
        if ($self->{guest_network_mode} ne 'host') {
            virt_autotest::virtual_network_utils::write_network_bridge_device_config(ipaddr => $_bridge_network, name => $_bridge_device, bootproto => 'static', bridge_type => 'master', backup_folder => $_host_params{common_log_folder});
            my $_ret = virt_autotest::virtual_network_utils::activate_network_bridge_device(bridge_device => $_bridge_device, network_mode => $self->{guest_network_mode}, reconsole_counter => $_host_params{reconsole_counter});
            $self->record_guest_installation_result('FAILED') if ($_ret != 0);
        }
        else {
            my $_host_default_network_interface = script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+ | head -1 | awk \'{print \$5}\'");
            virt_autotest::virtual_network_utils::write_network_bridge_device_config(ipaddr => $_bridge_network, name => $_bridge_device, bootproto => 'dhcp', bridge_type => 'master', bridge_port => $_host_default_network_interface, backup_folder => $_host_params{common_log_folder});
            virt_autotest::virtual_network_utils::write_network_bridge_device_config(ipaddr => '', name => $_host_default_network_interface, bootproto => 'none', bridge_type => 'slave', bridge_port => $_bridge_device, backup_folder => $_host_params{common_log_folder});
            my $_ret = virt_autotest::virtual_network_utils::activate_network_bridge_device(host_device => $_host_default_network_interface, bridge_device => $_bridge_device, network_mode => $self->{guest_network_mode}, reconsole_counter => $_host_params{reconsole_counter});
            $self->record_guest_installation_result('FAILED') if ($_ret != 0);
        }
    }
    else {
        record_info("Guest $self->{guest_name} uses bridge device $_bridge_device or subnet $_bridge_network_in_route which had already been configured and active", script_output("ip addr show;ip route show all"));
    }
    $self->{guest_netaddr_attached} = [split(/\n/, script_output("ip route show all | grep -v default | grep -i $_bridge_device | awk \'{print \$1}\'", proceed_on_failure => 1))];
    return $self;
}

=head2 config_guest_network_bridge_services

  config_guest_network_bridge_services($self, $_guest_network_device,
  $_guest_network_ipaddr_gw, $_guest_network_mask, $_guest_network_ipaddr_start,
  $_guest_network_ipaddr_end, $_guest_network_ipaddr_rev)

Start DHCP and DNS services by using dnsmasq command line. Call subroutine 
virt_autotest::virtual_network_utils::config_domain_resolver to add parsed subnet
gateway ip address and [guest_domain_name] into /etc/resolv.conf and empty
NETCONFIG_DNS_POLICY in /etc/sysconfig/network/config. Mark guest installation as
FAILED if dnsmasq command line can not be successfully fired up. Additionally,
write dnsmasq command line used into crontab to start DHCP and DNS services
automatically on reboot if host reboots somehow unexpectedly.

=cut

sub config_guest_network_bridge_services {
    my ($self, $_guest_network_device, $_guest_network_ipaddr_gw, $_guest_network_mask, $_guest_netwok_mask_len, $_guest_network_ipaddr_start, $_guest_network_ipaddr_end, $_guest_network_ipaddr_rev) = @_;

    $self->reveal_myself;
    virt_autotest::virtual_network_utils::config_domain_resolver(resolvip => $_guest_network_ipaddr_gw, domainname => $self->{guest_domain_name});
    my $_guest_network_ipaddr_gw_transformed = $_guest_network_ipaddr_gw;
    $_guest_network_ipaddr_gw_transformed =~ s/\./_/g;
    my $_dnsmasq_log = "$_host_params{common_log_folder}/dnsmasq_listen_address_$_guest_network_ipaddr_gw_transformed" . '_log';
    my $_dnsmasq_command = "/usr/sbin/dnsmasq --bind-dynamic --listen-address=$_guest_network_ipaddr_gw --bogus-priv --domain-needed --expand-hosts "
      . "--dhcp-range=$_guest_network_ipaddr_start,$_guest_network_ipaddr_end,$_guest_network_mask,8h --interface=$_guest_network_device "
      . "--dhcp-authoritative --no-negcache --dhcp-option=option:router,$_guest_network_ipaddr_gw --log-queries --local=/$self->{guest_domain_name}/ "
      . "--domain=$self->{guest_domain_name} --log-dhcp --dhcp-fqdn --dhcp-sequential-ip --dhcp-client-update --dns-loop-detect --no-daemon "
      . "--server=/$self->{guest_domain_name}/$_guest_network_ipaddr_gw --server=/$_guest_network_ipaddr_rev/$_guest_network_ipaddr_gw";
    my $_retry_counter = 5;
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    while (($_retry_counter gt 0) and (script_output("ps ax | grep -i \"$_dnsmasq_command\" | grep -v grep | awk \'{print \$1}\'", timeout => 180, proceed_on_failure => 1) eq '')) {
        script_run("((nohup $_dnsmasq_command  &>$_dnsmasq_log) &)", timeout => 180);
        save_screenshot;
        send_key('ret');
        save_screenshot;
        $_retry_counter--;
    }
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    if (script_output("ps ax | grep -i \"$_dnsmasq_command\" | grep -v grep | awk \'{print \$1}\'", timeout => 180, proceed_on_failure => 1) eq '') {
        record_info("DHCP and DNS services can not start.Mark guest $self->{guest_name} installation as FAILED", "The command used is ((nohup $_dnsmasq_command  &>$_dnsmasq_log) &)", result => 'fail');
        $self->record_guest_installation_result('FAILED');
    }
    else {
        record_info("DHCP and DNS services had already been running on $_guest_network_device which is ready for use", "The command used is ((nohup $_dnsmasq_command  &>$_dnsmasq_log) &)");
        $self->schedule_tasks_on_boot(_task => "(nohup $_dnsmasq_command  &>$_dnsmasq_log) &");
    }
    return $self;
}

=head2 config_guest_network_bridge_policy

  config_guest_network_bridge_policy($self, $_guest_network_device)

Stop firewall/apparmor, loosen iptables rules and enable forwarding globally and
on all default route devices and [guest_network_device]. Additionally, write
commands executed into crontab to re-execute them automatically on reboot if host
reboots somehow unexpectedly. IPv6 forwarding should not be enabled due to product
bug bsc#1222229. Calling virt_autotest::virtual_network_utils::config_network_device_policy
to do the actual work.

=cut

sub config_guest_network_bridge_policy {
    my ($self, $_guest_network_device) = @_;

    $self->reveal_myself;
    my $_network_policy_config_file = virt_autotest::virtual_network_utils::config_network_device_policy(logdir => $self->{guest_log_folder}, name => $self->{guest_name}, netdev => $_guest_network_device);
    $self->schedule_tasks_on_boot(_task => "$_network_policy_config_file");
    return $self;
}

=head2 schedule_tasks_on_boot

  schedule_tasks_on_boot($self, _task => $_task)

Schedule tasks to be executed on system boot up, please refer to these documents:
https://docs.oracle.com/en/learn/oracle-linux-crontab/ for using crontab utility
and https://linuxconfig.org/how-to-schedule-tasks-with-systemd-timers-in-linux 
for using systemd service and timer. In order to schedule a task successfully,
the _task argument should not be empty.

=cut

sub schedule_tasks_on_boot {
    my ($self, %args) = @_;

    $self->reveal_myself;
    $args{_task} //= '';

    croak("Jobs to be scheduled should have _task arguments set.") if ($args{_task} eq '');
    if (script_run('systemctl is-active cron.service') != 0) {
        $self->schedule_tasks_on_boot_systemd(%args);
    }
    else {
        $self->schedule_tasks_on_boot_crontab(%args);
    }
    return $self;
}

=head2 schedule_tasks_on_boot_crontab

  schedule_tasks_on_boot_crontab($self, _task => $_task)

Schedule tasks on system boot up by using crontab utility.

=cut

sub schedule_tasks_on_boot_crontab {
    my ($self, %args) = @_;

    $self->reveal_myself;
    $args{_task} = "($args{_task})" if $args{_task} =~ /\s*&\s*$/;
    if (script_output("cat $_host_params{common_log_folder}/root_cron_job | grep -i \"$args{_task}\"", proceed_on_failure => 1) eq '') {
        type_string("cat >> $_host_params{common_log_folder}/root_cron_job <<EOF
\@reboot $args{_task}
EOF
");
        script_run("crontab $_host_params{common_log_folder}/root_cron_job;crontab -l");
    }
    return $self;
}



=head2 schedule_tasks_on_boot_systemd

  schedule_tasks_on_boot_systemd($self, _task => $_task)

Schedule tasks on system boot up by using systemd service and timer.

=cut

sub schedule_tasks_on_boot_systemd {
    my ($self, %args) = @_;

    $self->reveal_myself;
    $args{_task} =~ s/\s*&\s*$//;
    my $_systemd_unit_path = '/etc/systemd/system';
    my $_systemd_unit_name = 'stubnetwork';
    if (script_output("cat $_host_params{common_log_folder}/root_systemd_job | grep -i \"$args{_task}\"", timeout => 180, proceed_on_failure => 1) eq '') {
        assert_script_run("echo -e \"$args{_task}\\n\$(cat $_host_params{common_log_folder}/root_systemd_job)\" > $_host_params{common_log_folder}/root_systemd_job", timeout => 180);
        assert_script_run("chmod 755 $_host_params{common_log_folder}/root_systemd_job");
        if (script_output("systemctl list-timers | grep $_systemd_unit_name", proceed_on_failure => 1) eq '') {
            type_string("cat > $_systemd_unit_path/$_systemd_unit_name.service <<EOF
[Unit]
Description=Bridge DHCP and DNS Services without Blockage

[Service]
Type=oneshot
ExecStart=/bin/bash $_host_params{common_log_folder}/root_systemd_job
EOF
");
            type_string("cat > $_systemd_unit_path/$_systemd_unit_name.timer <<EOF
[Unit]
Description=Bridge DHCP and DNS services without Blockage

[Timer]
Unit=stubnetwork.service
OnBootSec=10

[Install]
WantedBy=timers.target
EOF
");
            script_run("cp $_systemd_unit_path/$_systemd_unit_name* $_host_params{common_log_folder}");
        }
        disable_and_stop_service("$_systemd_unit_name.timer", ignore_failure => 1);
        systemctl("enable $_systemd_unit_name.timer", ignore_failure => 1);
        systemctl("status $_systemd_unit_name.timer", ignore_failure => 1);
    }
    return $self;
}

=head2 config_guest_installation_method

  config_guest_installation_method($self[, key-value pairs of guest installation arguments])

Configure [guest_installation_method_options]. User can still change [guest_installation_method],
[guest_installation_media], [guest_build], [guest_version], [guest_version_major],
[guest_version_minor], [guest_installation_fine_grained] and [guest_autoconsole]
by passing non-empty arguments using hash.Call config_guest_installation_media to
set correct installation media. For directkernel installation method which uses
virt-install --install, please also refer to following link for more information
https://manpages.opensuse.org/Tumbleweed/virt-install/virt-install.1.en.html
For 'location' installation method, virt-install command looks like:
--location [guest_installation_media],[guest_installation_method_others]
--extra-args root=live:[guest_installation_fine_grained_media]
--extra-args inst.install_url=[guest_installation_fine_grained_repos]
--extra-args [guest_installation_extra_args] 
For 'directkernel' installation method, virt-install command looks like:
--install kernel=[guest_installation_fine_grained_media]/linux,
initrd=[guest_installation_fine_grained_media]/initrd,
kernel_args=root=live:[guest_installation_media],inst.install_url=
[guest_installation_fine_grained_repos],[guest_installation_fine_grained_kernel_args]
For 'import' installation method, virt-install command looks like:
virt-install --import --disk [guest_storage_options]
=cut

sub config_guest_installation_method {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);

    $self->config_guest_installation_media;
    my $_guest_installation_media = render_autoinst_url(url => $self->{guest_installation_media});
    if ($_guest_installation_media =~ /^http\:\/\//im and script_output("curl --silent -I $_guest_installation_media | grep -E \"^HTTP\" | awk -F \" \" \'{print \$2}\'") != "200") {
        record_info("Installation media $_guest_installation_media does not exist", script_output("curl -I $_guest_installation_media", proceed_on_failure => 1), result => 'fail');
        $self->record_guest_installation_result('FAILED');
    }

    my $_guest_installation_fine_grained_media = '';
    if ($self->{guest_installation_fine_grained_media} ne '') {
        $self->{guest_installation_fine_grained_media} =~ s/12345/$self->{guest_build}/g if ($self->{guest_build} ne 'gm');
        $_guest_installation_fine_grained_media = render_autoinst_url(url => $self->{guest_installation_fine_grained_media});
        my $_guest_arch = ($self->{guest_arch} ? $self->{guest_arch} : get_required_var('ARCH'));
        if (script_output("curl --silent -I $_guest_installation_fine_grained_media | grep -E \"^HTTP\" | awk -F \" \" \'{print \$2}\'") == "200") {
            if ($self->{guest_installation_method} eq 'directkernel') {
                assert_script_run("curl -s -o $self->{guest_image_folder}/linux $_guest_installation_fine_grained_media/boot/$_guest_arch/loader/linux");
                assert_script_run("curl -s -o $self->{guest_image_folder}/initrd $_guest_installation_fine_grained_media/boot/$_guest_arch/loader/initrd");
            }
        }
        else {
            record_info("Fine-grained installation media $self->{guest_installation_fine_grained_media} does not exist", script_output("curl -I $_guest_installation_fine_grained_media", proceed_on_failure => 1), result => 'fail');
            $self->record_guest_installation_result('FAILED');
        }
    }

    my $_guest_installation_fine_grained_repos = '';
    if ($self->{guest_installation_fine_grained_repos} ne '') {
        $self->{guest_installation_fine_grained_repos} =~ s/12345/$self->{guest_build}/g if ($self->{guest_build} ne 'gm');
        foreach (split(',', $self->{guest_installation_fine_grained_repos})) {
            my $_guest_installation_fine_grained_repo = render_autoinst_url(url => $_);
            if (script_output("curl --silent -I $_guest_installation_fine_grained_repo | grep -E \"^HTTP\" | awk -F \" \" \'{print \$2}\'") != "200") {
                record_info("Fine-grained repo $_guest_installation_fine_grained_repo does not exist", script_output("curl -I $_guest_installation_fine_grained_repo", proceed_on_failure => 1), result => 'fail');
                $self->record_guest_installation_result('FAILED');
            }
            $_guest_installation_fine_grained_repos .= $_guest_installation_fine_grained_repo . ',';
        }
        $_guest_installation_fine_grained_repos =~ s/,$//g;
    }

    $self->{guest_installation_method_options} = '--autoconsole ' . $self->{guest_autoconsole} if ($self->{guest_autoconsole} ne '');
    $self->{guest_installation_method_options} = '--noautoconsole' if ($self->{guest_noautoconsole} eq 'true');

    if ($self->{guest_installation_method} eq 'directkernel') {
        $self->{guest_installation_method_options} .= ' --install kernel=' . $self->{guest_image_folder} . '/linux,initrd=' . $self->{guest_image_folder} . '/initrd';
        $self->{guest_installation_method_options} .= ',' . $self->{guest_installation_fine_grained_others} if ($self->{guest_installation_fine_grained_others} ne '');
        $self->{guest_installation_fine_grained_kernel_args} .= ' root=live:' . $_guest_installation_media;
        $self->{guest_installation_fine_grained_kernel_args} .= ' inst.install_url=' . $_guest_installation_fine_grained_repos if (is_agama_guest(guest => $self->{guest_name}) and $_guest_installation_fine_grained_repos ne '');
    }
    elsif ($self->{guest_installation_method} eq 'location') {
        $self->{guest_installation_method_options} .= ' --location ' . $_guest_installation_media;
        $self->{guest_installation_method_options} .= ",$self->{guest_installation_method_others}" if ($self->{guest_installation_method_others} ne '');
        $self->{guest_installation_extra_args} .= '#root=live:' . $_guest_installation_fine_grained_media if ($_guest_installation_fine_grained_media ne '');
        $self->{guest_installation_extra_args} .= '#inst.install_url=' . $_guest_installation_fine_grained_repos if (is_agama_guest(guest => $self->{guest_name}) and $_guest_installation_fine_grained_repos ne '');
    }
    elsif ($self->{guest_installation_method} eq 'import') {
        $self->{guest_installation_method_options} .= ' --import ';
    }

    return $self;
}

=head2 config_guest_installation_media

  config_guest_installation_media($self)

Set [guest_installation_media] to the current major and minor version if it does
not match with [guest_version]. This subroutine also help mount nfs share if guest
chooses to or has to use iso installation media, for example oracle linux guest
uses iso installation media from https://yum.oracle.com/oracle-linux-isos.html.
For guest using pre-built virtual disk image which will be downloaded and saved
to [guest_storage_backing_path]. Although this subroutine can help correct 
installation media major and minor version if necessary, it is just auxiliary 
functionality and end user should always pay attendtion and use the meaningful
and correct guest parameters and profile. If guest chooses to use iso installation
media, then this iso media should be available on INSTALLATION_MEDIA_NFS_SHARE and
mounted locally at INSTALLATION_MEDIA_LOCAL_SHARE. If guest_installation_media
contains URL address to ISO media, it is supposed to be used directly instead of
being mounted from INSTALLATION_MEDIA_NFS_SHARE.

=cut

sub config_guest_installation_media {
    my $self = shift;

    $self->reveal_myself;
    $self->{guest_installation_media} =~ s/12345/$self->{guest_build}/g if ($self->{guest_build} ne 'gm');

    if ($self->{guest_installation_media} =~ /^.*\.iso$/im) {
        return if ($self->{guest_installation_media} =~ /^(http|https)\:\/\//im);
        my $_installation_media_nfs_share = get_var('INSTALLATION_MEDIA_NFS_SHARE', '');
        my $_installation_media_local_share = get_var('INSTALLATION_MEDIA_LOCAL_SHARE', '');
        if (($_installation_media_nfs_share eq '') or (($_installation_media_local_share eq '') or ($_installation_media_local_share =~ /^$_host_params{common_log_folder}.*$/im))) {
            record_info("Can not mount iso installation media $self->{guest_installation_media}", "Installation media nfs share is not provided or installation media local share should not be empty or the common log folder $_host_params{common_log_folder} or any subfolders in $_host_params{common_log_folder}.Mark guest $self->{guest_name} installation as FAILED !", result => 'fail');
            $self->record_guest_installation_result('FAILED');
            return $self;
        }
        if (script_run("ls $_installation_media_local_share/$self->{guest_installation_media}") ne 0) {
            script_run("umount $_installation_media_local_share || umount -f -l $_installation_media_local_share");
            script_run("rm -f -r $_installation_media_local_share");
            assert_script_run("mkdir -p $_installation_media_local_share");
            if (script_retry("mount -t nfs $_installation_media_nfs_share $_installation_media_local_share ", timeout => 60, delay => 15, retry => 3, die => 0) ne 0) {
                record_info("The installation media nfs share $_installation_media_nfs_share can not be mounted as local $_installation_media_local_share.", "Guest $self->{guest_name} installation can not proceed.Mark it as FAILED !", result => 'fail');
                $self->record_guest_installation_result('FAILED');
            }
            else {
                $self->{guest_installation_media} = $_installation_media_local_share . '/' . $self->{guest_installation_media};
                record_info("The installation media nfs share $_installation_media_nfs_share has been mounted as local $_installation_media_local_share successfully.", "Cheers !");
            }
        }
        else {
            $self->{guest_installation_media} = $_installation_media_local_share . '/' . $self->{guest_installation_media};
            record_info("The installation media nfs share $_installation_media_nfs_share had already been mounted as local $_installation_media_local_share successfully.", "Cheers !");
        }
    }
    elsif ($self->{guest_installation_media} =~ /^.*\.(raw|raw\.xz|qcow2)$/i) {
        if (script_output("curl --silent -I " . render_autoinst_url(url => $self->{guest_installation_media}) . " | grep -E \"^HTTP\" | awk -F \" \" \'{print \$2}\'") == "200") {
            if ($self->{guest_installation_media} =~ /^.*\.raw\.xz$/i) {
                assert_script_run("curl -s -o $self->{guest_storage_backing_path}.xz " . render_autoinst_url(url => $self->{guest_installation_media}), timeout => 1200);
                assert_script_run("xz -d $self->{guest_storage_backing_path}.xz", timeout => 120);
            }
            else {
                assert_script_run("curl -s -o $self->{guest_storage_backing_path} " . render_autoinst_url(url => $self->{guest_installation_media}), timeout => 3600);
            }
        }
        else {
            record_info("Installation media $self->{guest_installation_media} does not exist", script_output("curl -I " . render_autoinst_url(url => $self->{guest_installation_media}), proceed_on_failure => 1), result => 'fail');
            $self->record_guest_installation_result('FAILED');
        }
    }
    record_info("Guest $self->{guest_name} is going to use installation media $self->{guest_installation_media}", "Please check it out !");
    return $self;
}

=head2 config_guest_installation_extra_args

  config_guest_installation_extra_args($self[, key-value pairs of extra arguments])

Configure [guest_installation_extra_args_options]. User can still change
[guest_installation_extra_args], [guest_ipaddr] and [guest_ipaddr_static] by
passing non-empty arguments using hash. [guest_installation_fine_grained_kernel_args]
and [guest_installation_fine_grained_kernel_args_overwrite] are also extra kernel
arguments which can be appended to the arguments that virt-install will try to set
by default for most --location installs. If you want to override the virt-install
default, additionally specify kernel_args_overwrite=yes. Please also refer to
https://manpages.opensuse.org/Tumbleweed/virt-install/virt-install.1.en.html for
information about [guest_installation_fine_grained_kernel_args].

=cut

sub config_guest_installation_extra_args {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_installation_extra_args} ne '') {
        my @_guest_installation_extra_args = split(/#/, $self->{guest_installation_extra_args});
        foreach (@_guest_installation_extra_args) {
            $self->{guest_installation_extra_args_options} = $self->{guest_installation_extra_args_options} . "--extra-args \"$_\" " if ($_ ne '');
        }
        $self->{guest_installation_extra_args_options} = $self->{guest_installation_extra_args_options} . "--extra-args \"ip=$self->{guest_ipaddr}\"" if (($self->{guest_ipaddr_static} eq 'true') and ($self->{guest_ipaddr} ne ''));
    }

    if ($self->{guest_installation_fine_grained_kernel_args} ne '' or $self->{guest_installation_fine_grained_kernel_args_overwrite} ne '') {
        $self->{guest_installation_method_options} = (($self->{guest_installation_method} ne 'directkernel') ? ($self->{guest_installation_method_options} . ' --install ') : ($self->{guest_installation_method_options} . ','));
        if ($self->{guest_installation_fine_grained_kernel_args} ne '') {
            $self->{guest_installation_method_options} .= 'kernel_args="' . $self->{guest_installation_fine_grained_kernel_args};
            $self->{guest_installation_method_options} .= '"';
            $self->{guest_installation_method_options} .= ',' if ($self->{guest_installation_fine_grained_kernel_args_overwrite} ne '');
        }
        if ($self->{guest_installation_fine_grained_kernel_args_overwrite} ne '') {
            $self->{guest_installation_fine_grained_kernel_args_overwrite} =~ s/true/yes/g;
            $self->{guest_installation_fine_grained_kernel_args_overwrite} =~ s/false/no/g;
            $self->{guest_installation_method_options} .= 'kernel_args_overwrite=' . $self->{guest_installation_fine_grained_kernel_args_overwrite};
        }
    }

    # From SLE Micro 6.0 onwards, only pre-built disk images are used for guest installation.
    if (is_transactional and $self->{guest_os_name} eq 'slem' and is_sle_micro('<6.0')) {
        record_soft_failure("bsc#1202405 - SLE Micro 5.3 media can not be successfully loaded automatically for virtual machine installation");
        $self->{guest_installation_extra_args_options} = $self->{guest_installation_extra_args_options} . " --extra-args \"install=$self->{guest_installation_media}\"";
    }

    return $self;
}

=head2 config_guest_installation_automation_registration

  config_guest_installation_automation_registration($self)

Configure registration/subscription/activation information in guest unattended
installation file using guest parameters, including guest_do_registration,
guest_registration_server, guest_registration_username, guest_registration_password,
guest_registration_code, guest_registration_extensions and guest_registration_extensions_codes].

=cut

sub config_guest_installation_automation_registration {
    my $self = shift;

    $self->reveal_myself;
    $self->{guest_do_registration} = 'false' if ($self->{guest_do_registration} eq '');
    record_info("Guest $self->{guest_name} registration status: $self->{guest_do_registration}", "Good luck !");
    if ($self->{guest_do_registration} eq 'false') {
        if ($self->{guest_installation_automation_method} =~ /autoyast/im) {
            assert_script_run("sed -i -r \'/<suse_register>/,/<\\\/suse_register>/d\' $self->{guest_installation_automation_file}");
        }
        elsif ($self->{guest_installation_automation_method} =~ /autoagama/im) {
            assert_script_run("sed -i -r \'/registrationCode/d\' $self->{guest_installation_automation_file}");
            assert_script_run("sed -i -r \'/registrationEmail/d\' $self->{guest_installation_automation_file}");
        }
    }
    else {
        $self->{guest_registration_server} =~ s/12345/$self->{guest_build}/g if ($self->{guest_build} ne 'gm');
        assert_script_run("sed -ri \'s/##Do-Registration##/$self->{guest_do_registration}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Registration-Server##/$self->{guest_registration_server}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Registration-UserName##/$self->{guest_registration_username}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Registration-Password##/$self->{guest_registration_password}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Registration-Code##/$self->{guest_registration_code}/g;\' $self->{guest_installation_automation_file}");
        if (($self->{guest_registration_extensions} ne '') and ($self->{guest_os_name} =~ /sles/im)) {
            my @_guest_registration_extensions = split(/#/, $self->{guest_registration_extensions});
            my @_guest_registration_extensions_codes = ('') x scalar @_guest_registration_extensions;
            @_guest_registration_extensions_codes = split(/#/, $self->{guest_registration_extensions_codes}) if ($self->{guest_registration_extensions_codes} ne '');
            my %_store_of_guest_registration_extensions;
            @_store_of_guest_registration_extensions{@_guest_registration_extensions} = @_guest_registration_extensions_codes;
            my $_guest_registration_version = (($self->{guest_version_minor} eq '0') ? $self->{guest_version_major} : ($self->{guest_version_major} . '.' . $self->{guest_version_minor}));
            foreach (keys %_store_of_guest_registration_extensions) {
                my $_guest_registration_extension_clip = "  <addon>\\n" .
                  "        <name>$_<\\\/name>\\n" .
                  "        <version>$_guest_registration_version<\\\/version>\\n" .
                  "        <arch>$self->{guest_arch}<\\\/arch>\\n" .
                  "        <reg_code>$_store_of_guest_registration_extensions{$_}<\\\/reg_code>\\n" .
                  "      <\\\/addon>";
                assert_script_run("sed -zri \'s/<\\\/addons>.*\\n.*<\\\/suse_register>/$_guest_registration_extension_clip\\n    <\\\/addons>\\n  <\\\/suse_register>/\' $self->{guest_installation_automation_file}");
            }
        }
        my $_guest_registration_server = ($self->{guest_registration_server} ? $self->{guest_registration_server} : get_var('SCC_URL', 'https://scc.suse.com'));
        if (is_agama_guest(guest => $self->{guest_name}) and $self->{guest_do_registration} eq 'true') {
            if ($self->{guest_installation_method} eq 'directkernel') {
                $self->{guest_installation_fine_grained_kernel_args} .= ' inst.register_url=' . $_guest_registration_server;
            }
            elsif ($self->{guest_installation_method} eq 'location') {
                $self->{guest_installation_extra_args} .= '#inst.register_url=' . $_guest_registration_server;
            }
        }
    }
    return $self;
}

=head2 config_guest_firstboot_provision

  config_guest_firstboot_provision($self)

Configure guest to use provisioning tool to configure system according to desired
sepcification on first boot. The well-known provisioning tools are ignition and
combustion which are specified by [guest_installation_automation_method]. Use 
flavors of supported platform from igntion as [guest_installation_automation_platform].
If provisioning config is passed in to [guest_sysinfo], user does not need to 
specify [guest_sysinfo] in guest profile. Instead only [guest_installation_automation_file]
needs to be specified, all the others are taken care by this subroutine. Please
refer to documentation: https://coreos.github.io/ignition/ and
https://github.com/openSUSE/combustion.

=cut

sub config_guest_firstboot_provision {
    my $self = shift;

    $self->reveal_myself;
    record_info("Guest $self->{guest_name} uses $self->{guest_installation_automation_method} as firstboot provision");
    if ($self->{guest_installation_automation_method} eq 'ignition') {
        $self->config_guest_provision_ignition;
    }
    elsif ($self->{guest_installation_automation_method} eq 'ignition+combustion') {
        $self->config_guest_provision_ignition;
        $self->config_guest_provision_combustion;
    }
    $self->validate_guest_installation_automation_file;
    return $self;
}

=head2 config_guest_provision_ignition

  config_guest_provision_ignition($self)

Configure ignition config file based on template specified by [guest_installation_automation_file].
If [guest_installation_automation_file] is empty, default ones will be used. If 
[guest_installation_automation_method] is 'ignition+combustion', their respective 
configuration files will be specified and joined with '#', for example, 'ignition_config
#combustion_config', and their names should be prefixed with 'ignition' or 'combustion'
respectively. Based on [guest_installation_automation_platform], for example,
'qemu' or 'metal', different ways of generating the final [guest_installation_automation_options]
will be adopted. If [guest_installation_automation_platform] is 'qemu', ignition
config file will be passed in via '--sysinfo' directly. If [guest_installation_automation_platform]
is 'metal', ignition config file will be placed in the secondary disk vdb which
is created by calling config_guest_provision_disk. 

=cut

sub config_guest_provision_ignition {
    my $self = shift;

    $self->reveal_myself;
    record_info("Guest $self->{guest_name} $self->{guest_installation_automation_platform} ignition config creating");
    my $_ignition_config = $self->{guest_installation_automation_file};
    if ($self->{guest_installation_automation_file} ne '') {
        $_ignition_config = (grep(/^ignition/i, split('#', $_ignition_config)))[0];
    }
    else {
        $_ignition_config = (($self->{guest_storage_backing_path} =~ /encrypted/i) ? 'ignition_config_encrypted_image.ign' : 'ignition_config_non_encrypted_image.ign');
    }
    assert_script_run("curl -s -o $self->{guest_log_folder}/config.ign " . data_url("virt_autotest/guest_unattended_installation_files/$_ignition_config"));
    $_ignition_config = $self->{guest_log_folder} . '/config.ign';
    my $_ssh_public_key = $_host_params{ssh_public_key};
    $_ssh_public_key =~ s/\//PLACEHOLDER/img;
    assert_script_run("sed -i \'s/##Authorized-Keys##/$_ssh_public_key/g\' $_ignition_config");
    assert_script_run("sed -i \'s/##FQDN##/$self->{guest_name}\\.$self->{guest_domain_name}/g\' $_ignition_config");
    assert_script_run("sed -i \'s/PLACEHOLDER/\\\//g;\' $_ignition_config");
    $self->config_guest_provision_ignition_luks if (script_run("grep -E \"\\\"luks\\\"\:\" $_ignition_config") == 0);

    if ($self->{guest_installation_automation_platform} eq 'qemu') {
        $self->{guest_installation_automation_options} .= " --sysinfo type=fwcfg,entry0.name=opt/com.coreos/config,entry0.file=$_ignition_config";
    }
    elsif ($self->{guest_installation_automation_platform} eq 'metal') {
        $self->config_guest_provision_disk(_provision_tool => 'ignition');
        if ($self->{guest_installation_automation_method} ne 'ignition+combustion') {
            $self->{guest_installation_automation_options} .= " --disk type=file,device=disk,source.file=$self->{guest_image_folder}/ignition.img,size=1,format=qcow2,driver.type=qcow2";
            $self->{guest_installation_automation_options} .= ",backing_store=$self->{guest_image_folder}/ignition.qcow2,backing_format=qcow2,target.dev=vdb,target.bus=virtio";
        }
    }
    return $self;
}

=head2 config_guest_provision_ignition_luks

  config_guest_provision_ignition_luks($self[, _ignition_config => 'config'])

This subroutine is responsible for configuring luks devices in ignition config
file. For details of luks devices in ignition, please refer to
https://coreos.github.io/ignition/configuration-v3_2/.

=cut

sub config_guest_provision_ignition_luks {
    my $self = shift;
    my %_args = @_;
    $_args{_ignition_config} //= $self->{guest_log_folder} . '/config.ign';

    $self->reveal_myself;
    assert_script_run("dd bs=512 count=4 if=/dev/random of=$self->{guest_log_folder}/ignition_config_luks_random_keyfile iflag=fullblock");
    my $_keyfile_sha512_hash = script_output("sha512sum $self->{guest_log_folder}/ignition_config_luks_random_keyfile");
    $_keyfile_sha512_hash = (split(' ', $_keyfile_sha512_hash))[0];
    my $_http_server_command = "python3 -m http.server 8666 --bind $_host_params{host_ipaddr}";
    my $_retry_counter = 5;
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    while (($_retry_counter gt 0) and (script_output("ps ax | grep -i \"$_http_server_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '')) {
        script_run("cd $_host_params{common_log_folder} && ((nohup $_http_server_command &>$_host_params{common_log_folder}/http_server_log) &) && cd ~");
        save_screenshot;
        send_key("ret");
        save_screenshot;
        $_retry_counter--;
    }
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    if (script_output("ps ax | grep -i \"$_http_server_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '') {
        record_info("HTTP server can not start and serve luks keyfile. Mark guest $self->{guest_name} installation as FAILED", "The command used is ((nohup $_http_server_command &>$_host_params{common_log_folder}/http_server_log) &)", result => 'fail');
        $self->record_guest_installation_result('FAILED');
        return $self;
    }
    else {
        record_info("HTTP server already started successfully and serves lusk keyfile", "The command used is ((nohup $_http_server_command &>$_host_params{common_log_folder}/http_server_log) &)");
        my $_luks_keyfile_url = "http://$_host_params{host_ipaddr}:8666/$self->{guest_name}/ignition_config_luks_random_keyfile";
        $_luks_keyfile_url =~ s/\//PLACEHOLDER/img;
        $_keyfile_sha512_hash =~ s/\//PLACEHOLDER/img;
        assert_script_run("sed -i \'s/##LUKS-KEYFILE-URL##/$_luks_keyfile_url/g\' $_args{_ignition_config}");
        assert_script_run("sed -i \'s/##LUKS-KEYFILE-HASH##/$_keyfile_sha512_hash/g;\' $_args{_ignition_config}");
        assert_script_run("sed -i \'s/PLACEHOLDER/\\\//g;\' $_args{_ignition_config}");
    }
    return $self;
}

=head2 config_guest_provision_combustion

  config_guest_provision_combustion($self)

If [guest_installation_automation_method] is 'ignition+combustion', configuring
combustion will be done after ignition. Combustion only is not supported, because
'ignition' or 'ignition+combustion' can already cover all scenarios. If
[guest_installation_automation_file] is empty, default ones will be used. If
[guest_installation_automation_method] is 'ignition+combustion', their respective
configuration files will be specified and joined with '#', for example, 'ignition_config
#combustion_config', and their names should be prefixed with 'ignition' or 'combustion'
respectively. Based on [guest_installation_automation_platform], for example, 'qemu'
or 'metal', different ways of generating the final [guest_installation_automation_options]
will be adopted. If [guest_installation_automation_platform] is 'qemu', ignition
config file will be passed in via '--sysinfo' directly. If [guest_installation_automation_platform]
is 'metal', ignition config file will be placed in the secondary disk vdb which
is created by calling config_guest_provision_disk.
 
=cut

sub config_guest_provision_combustion {
    my $self = shift;

    $self->reveal_myself;
    record_info("Guest $self->{guest_name} $self->{guest_installation_automation_platform} combustion config creating");
    my $_combustion_config = $self->{guest_installation_automation_file};
    if ($self->{guest_installation_automation_file} ne '') {
        $_combustion_config = (grep(/^combustion/i, split('#', $_combustion_config)))[0];
    }
    else {
        $_combustion_config = 'combustion_script';
    }
    assert_script_run("curl -s -o $self->{guest_log_folder}/script " . data_url("virt_autotest/guest_unattended_installation_files/$_combustion_config"));
    $_combustion_config = "$self->{guest_log_folder}/script";
    my $_ssh_public_key = $_host_params{ssh_public_key};
    $_ssh_public_key =~ s/\//PLACEHOLDER/img;
    assert_script_run("sed -i \'s/##Authorized-Keys##/$_ssh_public_key/g\' $_combustion_config");
    assert_script_run("sed -i \'s/##FQDN##/$self->{guest_name}\\.$self->{guest_domain_name}/g\' $_combustion_config");
    my $_scc_regcode = get_required_var('SCC_REGCODE');
    $_scc_regcode =~ s/\//PLACEHOLDER/img;
    assert_script_run("sed -i \'s/##Registration-Code##/$_scc_regcode/g\' $_combustion_config");
    my $_scc_url = get_var("SCC_URL", "https://scc.suse.com");
    $_scc_url =~ s/\//PLACEHOLDER/img;
    assert_script_run("sed -i \'s/##Registration-Server##/$_scc_url/g\' $_combustion_config");
    assert_script_run("sed -i \'s/PLACEHOLDER/\\\//g;\' $_combustion_config");

    if ($self->{guest_installation_automation_platform} eq 'qemu') {
        $self->{guest_installation_automation_options} .= " --sysinfo type=fwcfg,entry1.name=opt/org.opensuse.combustion/script,entry1.file=$_combustion_config";
    }
    elsif ($self->{guest_installation_automation_platform} eq 'metal') {
        $self->config_guest_provision_disk(_provision_tool => 'combustion');
        $self->{guest_installation_automation_options} .= " --disk type=file,device=disk,source.file=$self->{guest_image_folder}/ignition.img,size=1,format=qcow2,driver.type=qcow2";
        $self->{guest_installation_automation_options} .= ",backing_store=$self->{guest_image_folder}/ignition.qcow2,backing_format=qcow2,target.dev=vdb,target.bus=virtio";
    }
    return $self;
}

=head2 config_guest_provision_disk

  config_guest_provision_disk($self[, _provision_tool => 'tool'])

If [guest_installation_automation_platform] is 'metal', both ignition and combustion
configurations will be placed in respective folders in the secondary disk vdb which 
is labeled as 'ignition"'. Because only 'ignition' or 'ignition+combustion' is
supported, config_guest_provision_ignition will create a new ignition disk and
config_guest_provision_combustion will only open an existing ignition disk to
place combustion configuration in it.

=cut

sub config_guest_provision_disk {
    my ($self, %args) = @_;
    $args{_provision_tool} //= 'ignition';

    $self->reveal_myself;
    record_info("Guest $self->{guest_name} $args{_provision_tool} disk creating");
    if (script_run("ls $self->{guest_image_folder}/ignition.img") != 0 and script_run("ls $self->{guest_image_folder}/ignition.qcow2") != 0) {
        assert_script_run("rm -f -r $self->{guest_image_folder}/ignition.img $self->{guest_image_folder}/ignition.qcow2");
        assert_script_run("truncate --size=30M $self->{guest_image_folder}/ignition.img && mkfs.vfat -n ignition $self->{guest_image_folder}/ignition.img");
        assert_script_run("mkdir -p $self->{guest_image_folder}/mountpoint && mount $self->{guest_image_folder}/ignition.img $self->{guest_image_folder}/mountpoint");
    }
    else {
        assert_script_run("modprobe nbd max_part=8");
        assert_script_run("qemu-nbd --connect=/dev/nbd0 $self->{guest_image_folder}/ignition.qcow2");
        assert_script_run("mount /dev/nbd0 $self->{guest_image_folder}/mountpoint");
    }

    assert_script_run("mkdir -p $self->{guest_image_folder}/mountpoint/$args{_provision_tool}");
    if ($args{_provision_tool} eq 'ignition') {
        assert_script_run("cp $self->{guest_log_folder}/config.ign $self->{guest_image_folder}/mountpoint/$args{_provision_tool}");
    }
    elsif ($args{_provision_tool} eq 'combustion') {
        assert_script_run("cp $self->{guest_log_folder}/script $self->{guest_image_folder}/mountpoint/$args{_provision_tool}");
    }

    script_retry("umount $self->{guest_image_folder}/mountpoint || umount -f -l $self->{guest_image_folder}/mountpoint", retry => 3);
    script_retry("qemu-nbd --disconnect /dev/nbd0 && rmmod --force nbd", retry => 3) if (script_run("lsmod | grep nbd") == 0);
    if (script_run("ls $self->{guest_image_folder}/ignition.qcow2") != 0) {
        assert_script_run("qemu-img convert -O qcow2 $self->{guest_image_folder}/ignition.img $self->{guest_image_folder}/ignition.qcow2");
        assert_script_run("rm -f -r $self->{guest_image_folder}/ignition.img");
    }
    return $self;
}

=head2 config_guest_installation_automation

  config_guest_installation_automation($self[, key-value of automated installation arguments])

Configure guest automatic installation. Based on [guest_installation_automation_method],
either calling config_guest_firstboot_provision or config_guest_unattended_installation.
The former is responsible for generating configuration for automatic firstboot
provision which is used by booting from virtual disk image directly. The latter
is responsible for generating unattended installation configuration for a fresh
installation from installation media.

=cut

sub config_guest_installation_automation {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);

    if ($self->{guest_installation_automation_method} =~ /ignition|ignition+combustion/i) {
        $self->config_guest_firstboot_provision;
    }
    elsif ($self->{guest_installation_automation_method} =~ /autoyast|kickstart|autoagama/i) {
        $self->config_guest_unattended_installation;
    }
    return $self;
}

=head2 config_guest_unattended_installation

  config_guest_unattended_installation($self)

Configure [guest_installation_automation_options]. Fill in unattended installation
file with [guest_installation_media], [guest_secure_boot], [guest_boot_settings],
[guest_storage_label], [guest_domain_name], [guest_name] and host public ssh key.
User can also change [guest_do_registration], [guest_registration_server],
[guest_registration_username], [guest_registration_password], [guest_registration_code],
[guest_registration_extensions] and [guest_registration_extensions_codes] which
are used in configuring guest installation automation registration. Subroutine
config_guest_installation_automation_registration is called to perform this task.
Start HTTP server using python3 modules in unattended automation file folder to 
serve unattended guest installation.Mark guest installation as FAILED if HTTP 
server can not be started up or unattended installation file is not accessible.
Common varaibles are used in guest unattended installation file and to be replaced
with actual values.They are common variables that are relevant to guest itself or
its attributes, so they can be used in any unattended installation files regardless
of autoyast or kickstart or others.For example, if you want to set guest ethernet
interface mac address somewhere in your customized unattended installation file,
put ##Device-MacAddr## there then it will be replaced with the real mac address.
The actual kind of automation used matters less here than variables used in the
unattended installation file, so keep using standardized common varialbes in
unattened installation file will make it come alive automatically regardless of
the actual kind of automation being used. Currently the following common variables
are supported:[Module-Basesystem, Module-Desktop-Applications, Module-Development-Tools,
Module-Legacy, Module-Server-Applications, Module-Web-Scripting, Product-SLES,
Authorized-Keys, Secure-Boot, Boot-Loader-Type, Disk-Label, Domain-Name, Host-Name,
Device-MacAddr, Logging-HostName, Logging-HostPort, Do-Registration, Registration-Server,
Registration-UserName, Registration-Password and Registration-Code].

=cut

sub config_guest_unattended_installation {
    my $self = shift;

    $self->reveal_myself;
    if (($self->{guest_installation_automation_method} =~ /autoyast|kickstart|autoagama/i) and ($self->{guest_installation_automation_file} ne '')) {
        diag("Guest $self->{guest_name} is going to use unattended installation file $self->{guest_installation_automation_file}.");
        assert_script_run("curl -s -o $_host_params{common_log_folder}/unattended_installation_$self->{guest_name}_$self->{guest_installation_automation_file} " . data_url("virt_autotest/guest_unattended_installation_files/$self->{guest_installation_automation_file}"));
        $self->{guest_installation_automation_file} = "$_host_params{common_log_folder}/unattended_installation_$self->{guest_name}_$self->{guest_installation_automation_file}";
        assert_script_run("chmod 777  $self->{guest_installation_automation_file}");

        if (($self->{guest_version_major} ge 15) and ($self->{guest_version_major} lt 16) and ($self->{guest_os_name} =~ /sles/im)) {
            my @_guest_installation_media_extensions = ('Module-Basesystem', 'Module-Desktop-Applications', 'Module-Development-Tools', 'Module-Legacy', 'Module-Server-Applications', 'Module-Web-Scripting', 'Module-Python3', 'Product-SLES');
            my $_guest_installation_media_extension_url = '';
            foreach (@_guest_installation_media_extensions) {
                $_guest_installation_media_extension_url = $self->{guest_installation_media} . '/' . $_;
                $_guest_installation_media_extension_url =~ s/\//PLACEHOLDER/img;
                assert_script_run("sed -ri \'s/##$_##/$_guest_installation_media_extension_url/g;\' $self->{guest_installation_automation_file}");
            }
            assert_script_run("sed -ri \'s/PLACEHOLDER/\\\//g;\' $self->{guest_installation_automation_file}");
        }

        my $_authorized_key = $_host_params{ssh_public_key};
        $_authorized_key =~ s/\//PLACEHOLDER/img;
        assert_script_run("sed -ri \'s/##Authorized-Keys##/$_authorized_key/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/PLACEHOLDER/\\\//g;\' $self->{guest_installation_automation_file}");
        if ($self->{guest_secure_boot} ne '') {
            assert_script_run("sed -ri \'s/##Secure-Boot##/$self->{guest_secure_boot}/g;\' $self->{guest_installation_automation_file}");
        }
        else {
            assert_script_run("sed -ri \'/##Secure-Boot##/d;\' $self->{guest_installation_automation_file}");
        }
        my $_boot_loader = (($self->{guest_boot_settings} =~ /uefi|ovmf/im) ? 'grub2-efi' : 'grub2');
        assert_script_run("sed -ri \'s/##Boot-Loader-Type##/$_boot_loader/g;\' $self->{guest_installation_automation_file}");
        my $_disk_label = (($self->{guest_storage_label} eq 'gpt') ? 'gpt' : 'msdos');
        assert_script_run("sed -ri \'s/##Disk-Label##/$_disk_label/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Domain-Name##/$self->{guest_domain_name}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Host-Name##/$self->{guest_name}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Device-MacAddr##/$self->{guest_macaddr}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Logging-HostName##/$_host_params{host_name}.$_host_params{host_domain_name}/g;\' $self->{guest_installation_automation_file}");
        assert_script_run("sed -ri \'s/##Logging-HostPort##/514/g;\' $self->{guest_installation_automation_file}");
        $self->config_guest_installation_automation_registration;
        $self->validate_guest_installation_automation_file;

        my $_http_server_command = "python3 -m http.server 8666 --bind $_host_params{host_ipaddr}";
        my $_retry_counter = 5;
        #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
        while (($_retry_counter gt 0) and (script_output("ps ax | grep -i \"$_http_server_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '')) {
            script_run("cd $_host_params{common_log_folder} && ((nohup $_http_server_command &>$_host_params{common_log_folder}/http_server_log) &) && cd ~");
            save_screenshot;
            send_key("ret");
            save_screenshot;
            $_retry_counter--;
        }
        #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
        if (script_output("ps ax | grep -i \"$_http_server_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '') {
            record_info("HTTP server can not start and serve unattended installation file.Mark guest $self->{guest_name} installation as FAILED", "The command used is ((nohup $_http_server_command &>$_host_params{common_log_folder}/http_server_log) &)", result => 'fail');
            $self->record_guest_installation_result('FAILED');
            return $self;
        }
        else {
            record_info("HTTP server already started successfully and serves unattended installation file", "The command used is ((nohup $_http_server_command &>$_host_params{common_log_folder}/http_server_log) &)");
        }
        $self->{guest_installation_automation_file} = "http://$_host_params{host_ipaddr}:8666/" . basename($self->{guest_installation_automation_file});
        if ($self->{guest_installation_automation_method} eq 'autoyast') {
            $self->{guest_installation_automation_options} = "--extra-args \"autoyast=$self->{guest_installation_automation_file}\"";
        }
        elsif ($self->{guest_installation_automation_method} eq 'kickstart') {
            $self->{guest_installation_automation_options} = "--extra-args \"inst.ks=$self->{guest_installation_automation_file}\"";
            $self->{guest_installation_automation_options} = "--extra-args \"ks=$self->{guest_installation_automation_file}\"" if (($self->{guest_os_name} =~ /oraclelinux/im) and ($self->{guest_version_major} lt 7));
        }
        elsif ($self->{guest_installation_automation_method} eq 'autoagama') {
            if ($self->{guest_installation_method} eq 'directkernel') {
                $self->{guest_installation_fine_grained_kernel_args} .= ' inst.auto=' . $self->{guest_installation_automation_file} . ' inst.finish=stop';
            }
            elsif ($self->{guest_installation_method} eq 'location') {
                $self->{guest_installation_extra_args} .= '#inst.auto=' . $self->{guest_installation_automation_file} . '#inst.finish=stop';
            }
        }
        if (script_retry("curl -sSf $self->{guest_installation_automation_file} > /dev/null") ne 0) {
            record_info("Guest $self->{guest_name} unattended installation file hosted on local host can not be reached", "Mark guest installation as FAILED. The unattended installation file url is $self->{guest_installation_automation_file}", result => 'fail');
            $self->record_guest_installation_result('FAILED');
        }
    }
    else {
        record_info("Skip installation automation configuration for guest $self->{guest_name}", "It has no qualified guest_installation_automation_method or no guest_installation_automation_file configured.Skip config_guest_installation_automation.");
    }
    return $self;
}

=head2 validate_guest_installation_automation_file

  validate_guest_installation_automation_file($self)

Validate autoyast file using xmllint and yast2-schema. This is only for reference
purpose if guest and host oses have different release major version. Output
kickstart file content directly because its content can not be validated on SLES
or opensuse host by using ksvalidator.

=cut

sub validate_guest_installation_automation_file {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_automation_method} eq 'autoyast') {
        if (script_run("xmllint --noout --relaxng /usr/share/YaST2/schema/autoyast/rng/profile.rng $self->{guest_installation_automation_file}") ne 0) {
            record_info("Autoyast file validation failed for guest $self->{guest_name}.Only for reference purpose", script_output("cat $self->{guest_installation_automation_file}"));
        }
        else {
            record_info("Autoyast file validation succeeded for guest $self->{guest_name}.Only for reference purpose", script_output("cat $self->{guest_installation_automation_file}"));
        }
    }
    elsif ($self->{guest_installation_automation_method} eq 'kickstart') {
        record_info("Kickstart file for guest $self->{guest_name}", script_output("cat $self->{guest_installation_automation_file}"));
    }
    elsif ($self->{guest_installation_automation_method} =~ /ignition|ignition+combustion/i) {
        if (script_run("ignition-validate $self->{guest_log_folder}/config.ign") ne 0) {
            record_info("Ignition file validation failed for guest $self->{guest_name}", script_output("cat $self->{guest_log_folder}/config.ign"), result => 'fail');
        }
        else {
            record_info("Ignition file validation succeeded for guest $self->{guest_name}", script_output("cat $self->{guest_log_folder}/config.ign"));
        }
        if ($self->{guest_installation_automation_method} eq 'ignition+combustion') {
            record_info("Combustion file for guest $self->{guest_name}", script_output("cat $self->{guest_log_folder}/script"));
        }
    }
    elsif ($self->{guest_installation_automation_method} eq 'autoagama') {
        unless (is_x86_64) {
            record_info("Skip autoagama file validation for non-x86 arch due to no agama-cli pkg.");
        } else {
            if (script_run("agama --insecure profile validate $self->{guest_installation_automation_file}") != 0) {
                record_info("Autoagama file validation failed for guest $self->{guest_name}", script_output("cat $self->{guest_installation_automation_file}"), result => 'fail');
            }
            else {
                record_info("Autoagama file validation succeeded for guest $self->{guest_name}", script_output("cat $self->{guest_installation_automation_file}"));
            }
        }
    }
    return $self;
}

=head2 config_guest_installation_command

  config_guest_installation_command($self)

Assemble all configured options into one virt-install command line to be fired
up for guest installation. If certain options that have special settings need
to be further tweaked before final virt-install is formed, corresponding work
should also be done in this subroutine as well, for example, applying authentic
plain passwords to be used. This subroutine does not receive any other passed in
arguments.

=cut

sub config_guest_installation_command {
    my $self = shift;

    $self->reveal_myself;
    $self->{virt_install_command_line} = "virt-install $self->{guest_virt_options} $self->{guest_platform_options} $self->{guest_name_options} "
      . "$self->{guest_vcpus_options} $self->{guest_memory_options} $self->{guest_numa_options} $self->{guest_cpumodel_options} $self->{guest_metadata_options} "
      . "$self->{guest_os_variant_options} $self->{guest_boot_options} $self->{guest_storage_options} $self->{guest_network_selection_options} "
      . "$self->{guest_installation_method_options} $self->{guest_installation_automation_options} $self->{guest_installation_extra_args_options} "
      . "$self->{guest_graphics_and_video_options} $self->{guest_sysinfo_options} $self->{guest_serial_options} $self->{guest_channel_options} "
      . "$self->{guest_console_options} $self->{guest_features_options} $self->{guest_events_options} $self->{guest_power_management_options} "
      . "$self->{guest_qemu_command_options} $self->{guest_xpath_options} $self->{guest_security_options} $self->{guest_controller_options} "
      . "$self->{guest_tpm_options} $self->{guest_rng_options} --debug";
    $self->{virt_install_command_line_dryrun} = $self->{virt_install_command_line} . " --dry-run";
    $self->config_guest_plain_password;
    return $self;
}

=head2 config_guest_plain_password

  config_guest_plain_password($self)

Before guest installation starts or during its installation, plain passwords might
be used to facilitate configuring, installing or investigating guest, for example,
a ssh root password is usually used to enable password access to linuxrc via ssh
when performing guest installation with autoyast or kickstart. User can put HOLDER
ROOTPASSWORD in guest profile to indicate that plain password is expected. If a
different plain password is used at the same time, a different HOLDER name can be
used as well in either guest profile or provision/unattended installation file.
Root plain password should be saved in $testapi::apassword, but customized one 
can be chosen by specific setting _SECRET_ROOT_PASSWORD. This subroutine does not
receive any other passed in arguments. 

=cut

sub config_guest_plain_password {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{virt_install_command_line} =~ /ROOTPASSWORD/) {
        unless ($testapi::password) {
            my $_root_password = get_required_var('_SECRET_ROOT_PASSWORD');
            $self->{virt_install_command_line} =~ s/ROOTPASSWORD/$_root_password/;
            $self->{virt_install_command_line_dryrun} =~ s/ROOTPASSWORD/$_root_password/;
        }
        else {
            $self->{virt_install_command_line} =~ s/ROOTPASSWORD/$testapi::password/;
            $self->{virt_install_command_line_dryrun} =~ s/ROOTPASSWORD/$testapi::password/;
        }
    }
    return $self;
}

=head2 guest_installation_run

  guest_installation_run($self, @_)

Calls prepare_guest_installation to do guest configuration. Call start_guest_installation
to start guest installation. This subroutine also accepts hash/dictionary argument
to be passed to prepare_guest_installation to further customize guest object if
necessary.

=cut

sub guest_installation_run {
    my $self = shift;

    $self->reveal_myself;
    $self->prepare_guest_installation(@_);
    $self->start_guest_installation;
    return $self;
}

=head2 prepare_guest_installation

  prepare_guest_installation($self, @_)

Configure and prepare guest before installation starts. This subroutine also
accepts hash/dictionary argument to be passed to config_guest_params to further
customize guest object if necessary.

=cut

sub prepare_guest_installation {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->prepare_common_environment;
    $self->prepare_guest_environment;
    $self->config_guest_name;
    $self->config_guest_vcpus;
    $self->config_guest_memory;
    $self->config_guest_numa;
    $self->config_guest_os_variant;
    $self->config_guest_virtualization;
    $self->config_guest_platform;
    $self->config_guest_boot_settings;
    $self->config_guest_power_management;
    $self->config_guest_events;
    $self->config_guest_graphics_and_video;
    $self->config_guest_channels;
    $self->config_guest_consoles;
    $self->config_guest_features;
    $self->config_guest_xpath;
    $self->config_guest_qemu_command;
    $self->config_guest_security;
    $self->config_guest_controller;
    $self->config_guest_tpm;
    $self->config_guest_rng;
    $self->config_guest_sysinfo;
    $self->config_guest_storage;
    $self->config_guest_network_selection;
    $self->config_guest_installation_method;
    $self->config_guest_installation_automation;
    $self->config_guest_installation_extra_args;
    $self->config_guest_installation_command;
    $self->print_guest_params;
    return $self;
}

=head2 start_guest_installation

  start_guest_installation($self)

If [virt_install_command_line_dryrun] succeeds, start real guest installation
using screen and virt_install_command_line.

=cut

sub start_guest_installation {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_result} ne '') {
        record_info("Guest $self->{guest_name} installation has not started due to some errors", "Bad luck !");
        return $self;
    }

    my $_start_installation_timestamp = localtime();
    $_start_installation_timestamp =~ s/ |:/_/g;
    my $_guest_installation_dryrun_log = "$_host_params{common_log_folder}/$self->{guest_name}/$self->{guest_name}" . "_installation_dryrun_log_" . $_start_installation_timestamp;
    my $_guest_installation_log = "$_host_params{common_log_folder}/$self->{guest_name}/$self->{guest_name}" . "_installation_log_" . $_start_installation_timestamp;
    assert_script_run("touch $_guest_installation_log && chmod 777 $_guest_installation_log");
    # Dry run always timeout when downloading initrd from download.opensuse.org in O3
    my $ret = script_run("set -o pipefail; timeout 580 $self->{virt_install_command_line_dryrun} 2>&1 | tee -a $_guest_installation_dryrun_log", timeout => 600);
    save_screenshot;
    enter_cmd "set +o pipefail; echo DONE > /dev/$serialdev";
    unless (defined(wait_serial('DONE', timeout => 30))) {
        reconnect_when_ssh_console_broken;
        script_run("set +o pipefail");
    }
    if ($ret ne 0) {
        record_info("Guest $self->{guest_name} installation dry run failed", "The virt-install command used is $self->{virt_install_command_line_dryrun}", result => 'fail');
        $self->record_guest_installation_result('FAILED');
        return $self;
    }
    record_info("Guest $self->{guest_name} installation dry run succeeded", "Going to install by using $self->{virt_install_command_line}");
    #Use "screen" in the most compatible way, screen -t "title (window's name)" -c "screen configuration file" -L(turn on output logging) "command to run".
    #The -Logfile option is only supported by more recent operating systems.
    $self->{guest_installation_session_config} = script_output("cd ~;pwd") . '/' . $self->{guest_name} . '_installation_screen_config';
    script_run("rm -f -r $self->{guest_installation_session_config};touch $self->{guest_installation_session_config};chmod 777 $self->{guest_installation_session_config}");
    script_run("cat /etc/screenrc > $self->{guest_installation_session_config};sed -in \'/^logfile .*\$/d\' $self->{guest_installation_session_config}");
    script_run("echo \"logfile $_guest_installation_log\" >> $self->{guest_installation_session_config}");
    type_string("screen -t $self->{guest_name} -L -c $self->{guest_installation_session_config} $self->{virt_install_command_line}\n", timeout => 600 / get_var('TIMEOUT_SCALE', 1));
    record_info("Guest $self->{guest_name} installation started", "The virt-install command line is $self->{virt_install_command_line}");
    return $self;
}

=head2 get_guest_installation_session

  get_guest_installation_session($self)

Get guest installation screen process information and store it in
[guest_installation_session] which is in the form of 3401.pts-1.vh017.

=cut

sub get_guest_installation_session {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_session} ne '') {
        record_info("Guest $self->{guest_name} installation screen process info had already been known", "$self->{guest_name} $self->{guest_installation_session}");
        return $self;
    }
    my $installation_tty = script_output("tty | awk -F\"/\" \'{print \$3}'", proceed_on_failure => 1);
    my $installation_tty_num = script_output("tty | awk -F\"/\" \'{print \$4}\'", proceed_on_failure => 1);
    $installation_tty = $installation_tty . '-' . $installation_tty_num if ($installation_tty_num ne '');
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    my $installation_pid = script_output("ps ax | grep -i \"SCREEN -t $self->{guest_name}\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1);
    $self->{guest_installation_session} = (($installation_pid eq '') ? '' : ($installation_pid . ".$installation_tty." . (split(/\./, $_host_params{host_name}))[0]));
    record_info("Guest $self->{guest_name} installation screen process info", "$self->{guest_name} $self->{guest_installation_session}");
    return $self;
}

=head2 terminate_guest_installation_session

  terminate_guest_installation_session($self)

Kill all guest installation screen processes stored in [guest_installation_session]
after test finishes.

=cut

sub terminate_guest_installation_session {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_session} ne '') {
        script_run("screen -X -S $self->{guest_installation_session} kill");
        record_info("Guest $self->{guest_name} installation screen process $self->{guest_installation_session} has already been terminated now", "Installation already passed or failed");
    }
    else {
        record_info("Guest $self->{guest_name} has no associated installation screen process to be terminated", "This looks weird");
    }
    return $self;
}

=head2 get_guest_ipaddr

  get_guest_ipaddr($self, @subnets_in_route)

Get dynamic allocated guest ip address using nmap scan and store it in [guest_ipaddr].
Sometimes guest may have more than one ip address assigned to a single interface, which
is valid scenario. Getting the first one is enough to interact with the guest. Tumbleweed
or agama guest may change ip addresses after reboot, so their ip addresses should always
be refreshed after reboot.

=cut

sub get_guest_ipaddr {
    my $self = shift;
    my @subnets_in_route = @_;

    $self->reveal_myself;
    # Tumbleweed or agama guest's IP will change after reboot, so we need check IP multiple times even if an IP has been detected.
    return $self if ((!is_agama_guest(guest => $self->{guest_name}) and !is_tumbleweed and ($self->{guest_ipaddr} ne '') and ($self->{guest_ipaddr} ne 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT')) or ($self->{guest_ipaddr_static} eq 'true'));
    my $_guest_ipaddr = '';
    if ($self->{guest_network_type} eq 'bridge') {
        @subnets_in_route = split(/\n+/, script_output("ip route show all | awk \'{print \$1}\' | grep -v default")) if (scalar(@subnets_in_route) eq 0);
        foreach (@subnets_in_route) {
            my $single_subnet = $_;
            next if (!(grep { $_ eq $single_subnet } @{$self->{guest_netaddr_attached}}));
            $single_subnet =~ s/\.|\//_/g;
            my $_scan_timestamp = localtime();
            $_scan_timestamp =~ s/ |:/_/g;
            my $single_subnet_scan_results = "$_host_params{common_log_folder}/nmap_subnets_scan_results/nmap_scan_$single_subnet" . '_' . $_scan_timestamp;
            assert_script_run("mkdir -p $_host_params{common_log_folder}/nmap_subnets_scan_results");
            script_run("nmap -T4 -sn $_ -oX $single_subnet_scan_results", timeout => 600 / get_var('TIMEOUT_SCALE', 1));
            $_guest_ipaddr = script_output("xmlstarlet sel -t -v //address/\@addr -n $single_subnet_scan_results | grep -i $self->{guest_macaddr} -B1 | grep -iv $self->{guest_macaddr}", proceed_on_failure => 1);
            $self->{guest_ipaddr} = ($_guest_ipaddr ? $_guest_ipaddr : 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT');
            last if ($self->{guest_ipaddr} ne 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT');
        }
    }
    elsif ($self->{guest_network_type} eq 'vnet') {
        my $_network_selected = (($self->{guest_network_mode} eq 'default') ? 'default' : $self->{guest_network_device});
        script_retry("virsh net-dhcp-leases --network $_network_selected | grep -ioE \"$self->{guest_macaddr}.*([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", retry => 30, delay => 10, die => 0);
        my $_guest_ipaddr = script_output("virsh net-dhcp-leases --network $_network_selected | grep -i $self->{guest_macaddr} | awk \'{print \$5}\'", type_command => 1, proceed_on_failure => 1);
        $self->{guest_ipaddr} = ($_guest_ipaddr ? ((split(/\//, $_guest_ipaddr))[0]) : 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT');
        save_screenshot;
    }

    my $record_info = '';
    $self->{guest_ipaddr} = 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT' if ($self->{guest_ipaddr} eq '');
    $self->{guest_ipaddr} = (split(/\n/, $self->{guest_ipaddr}))[0];
    $record_info = $record_info . $self->{guest_name} . ' ' . $self->{guest_ipaddr} . ' ' . $self->{guest_macaddr} . "\n";
    record_info("Guest $self->{guest_name} address info", $record_info);
    return $self;
}

=head2 monitor_guest_installation

  monitor_guest_installation($self)

Monitor guest installation progress:
If needle 'guest_installation_failures' is detected,mark it as FAILED.
If needle 'text-login' is detected,this means guest installations finishes. Mark
it as PASSED if ssh connection is good,otherwise mark it as FAILED.
If needle 'grub2' is detected,this means guest is rebooting. Will check its result
in the next round.
If needle 'text-logged-in-root' is detected,this means installation screen is
disconnected, terminated or broken.Will try to re-attach and check its result in
the next round.
If needle 'guest_installation_in_progress' is detected,this means installation is
still in progress. Will check its result in the next round.
If none of above needles is detected, makr it as PASSED if ssh connection to it
is good, otherwise mark it as FAILED by calling check_guest_installation_result_via_ssh.

=cut

sub monitor_guest_installation {
    my $self = shift;

    $self->reveal_myself;
    save_screenshot;
    if (!(check_screen([qw(autoyast-packages-being-installed agama-installer-live-root text-logged-in-root guest-installation-in-progress guest-installation-failures grub2 linux-login text-login guest-console-text-login emergency-mode)], 180 / get_var('TIMEOUT_SCALE', 1)))) {
        save_screenshot;
        record_info("Can not detect any interested screens on guest $self->{guest_name} installation process", "Going to detach current screen anyway");
        $self->detach_guest_installation_screen;
        my $_detect_installation_result = $self->check_guest_installation_result_via_ssh;
        record_info("Not able to determine guest $self->{guest_name} installation progress or result at the moment", "Installation is still in progress, guest reboot/shutoff, broken ssh connection or unknown") if ($_detect_installation_result eq '');
    }
    elsif (match_has_tag('emergency-mode')) {
        wait_still_screen;
        send_key('ret') for (0 .. 2);
        wait_still_screen;
        enter_cmd("echo -e \"\\n########## Beginning of journalctl ##########\\n\"");
        enter_cmd("journalctl --dmesg --all --no-pager");
        wait_still_screen;
        enter_cmd("echo -e \"\\n########## End of journalctl ##########\\n\"");
        enter_cmd("echo -e \"\\n########## Beginning of /run/initramfs/rdsosreport.txt ##########\\n\"");
        enter_cmd("cat /run/initramfs/rdsosreport.txt");
        wait_still_screen;
        enter_cmd("echo -e \"\\n########## End of /run/initramfs/rdsosreport.txt ##########\\n\"");
        enter_cmd("mkdir /sysroot/emergency_mode");
        enter_cmd("journalctl --dmesg --all --no-pager > /sysroot/emergency_mode/journalctl");
        enter_cmd("cp /run/initramfs/rdsosreport.txt /sysroot/emergency_mode/rdsosreport.txt");
        enter_cmd("chroot /sysroot");
        enter_cmd("sync");
        wait_still_screen;
        enter_cmd('exit');
        enter_cmd('exit');
        wait_still_screen;
        $self->detach_guest_installation_screen;
        $self->record_guest_installation_result('FAILED');
        record_info("Installation failed for guest $self->{guest_name}", "Guest $self->{guest_name} in emergency/maintenance mode", result => 'fail');
        $self->get_guest_ipaddr if ($self->{guest_ipaddr_static} ne 'true');
    }
    elsif (match_has_tag('guest-installation-failures')) {
        save_screenshot;
        $self->detach_guest_installation_screen;
        $self->record_guest_installation_result('FAILED');
        record_info("Installation failed due to errors for guest $self->{guest_name}", "Bad luck ! Mark it as FAILED", result => 'fail');
        $self->get_guest_ipaddr if ($self->{guest_ipaddr_static} ne 'true');
    }
    elsif (match_has_tag('agama-installer-live-root')) {
        save_screenshot;
        $self->detach_guest_installation_screen;
        $self->monitor_guest_agama_installation;
        $self->get_guest_ipaddr if ($self->{guest_ipaddr_static} ne 'true');
    }
    elsif (match_has_tag('linux-login') or match_has_tag('text-login') or match_has_tag('guest-console-text-login')) {
        save_screenshot;
        $self->detach_guest_installation_screen;
        my $_detect_installation_result = $self->check_guest_installation_result_via_ssh;
        if ($_detect_installation_result eq '') {
            record_info("Installation finished with bad ssh connection for guest $self->{guest_name}", "Almost there ! Mark it as FAILED", result => 'fail');
            $self->record_guest_installation_result('FAILED');
        }
    }
    elsif (match_has_tag('grub2')) {
        save_screenshot;
        diag("Guest $self->{guest_name} installation finished and is about to boot up. Will check later.");
    }
    elsif (match_has_tag('text-logged-in-root')) {
        save_screenshot;
        if (!($self->has_autoconsole_for_sure)) {
            record_info("Can not monitor and obtain guest $self->{guest_name} installation progress", "Installation screen process $self->{guest_installation_session} is not attached currently or already terminated on reboot/shutoff after installation finished or at certain stage or guest $self->{guest_name} has no autoconsole");
        }
        else {
            record_info("Can not monitor and obtain guest $self->{guest_name} installation progress", "Installation screen process $self->{guest_installation_session} is not attached currently");
        }
        $self->{guest_installation_attached} = 'false';
    }
    elsif (match_has_tag('guest-installation-in-progress') or match_has_tag('autoyast-packages-being-installed')) {
        save_screenshot;
        if (match_has_tag('autoyast-packages-being-installed')) {
            send_key('ret');
            save_screenshot;
        }
        record_info("Guest $self->{guest_name} installation is still in progress", "Sit back and wait");
    }
    save_screenshot;
    return $self;
}

=head2 monitor_guest_agama_installation

  monitor_guest_agama_installation($self)

Monitor guest installation progress using Agama installer. The process includes:
setup_guest_agama_installation_shell
verify_guest_agama_installation_done
save_guest_agama_installation_logs
=cut

sub monitor_guest_agama_installation {
    my $self = shift;

    $self->setup_guest_agama_installation_shell;
    $self->verify_guest_agama_installation_done;
    $self->save_guest_agama_installation_logs;

    return $self;
}

=head2 setup_guest_agama_installation_shell

  setup_guest_agama_installation_shell($self)

Password is required to access Agama installer shell using ssh. Passwordless ssh
connection is more convenient for automation purpose, but password will still be
used if passwordless ssh connection fails. Guest installation will be marked as
'FAILED' if there is no way to establish ssh connection to Agama installer shell
using publibc key, because Agama installe shell does support full ssh capability.
=cut

sub setup_guest_agama_installation_shell {
    my $self = shift;

    my $_ssh_command_options = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ";
    $_ssh_command_options .= is_sle('16+') ? "-o PubkeyAcceptedAlgorithms=+ssh-ed25519 " : "-o PubkeyAcceptedAlgorithms=+ssh-rsa ";
    $_ssh_command_options .= "-i $_host_params{ssh_key_file}";
    $self->get_guest_ipaddr if ($self->{guest_ipaddr_static} ne 'true');
    if ($self->{guest_ipaddr} eq 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT') {
        $self->record_guest_installation_result('FAILED');
        record_info("Guest $self->{guest_name} agama installer shell can not ssh login", "Guest $self->{guest_name} ip address is $self->{guest_ipaddr}", result => 'fail');
    }
    else {
        enter_cmd("clear", wait_still_screen => 3);
        if (script_run("timeout --kill-after=1 --signal=9 60 ssh-copy-id -f $_ssh_command_options root\@$self->{guest_ipaddr}") != 0) {
            type_string("reset\n");
            wait_still_screen;
            enter_cmd("timeout --kill-after=1 --signal=9 180 ssh-copy-id -f $_ssh_command_options root\@$self->{guest_ipaddr}", wait_still_screen => 5, timeout => 210);
            assert_screen('password-prompt', timeout => 30);
            enter_cmd("novell", wait_screen_change => 60, max_interval => 1, timeout => 90);
        }
        wait_still_screen(15);
        if (script_run("timeout --kill-after=1 --signal=9 60 ssh $_ssh_command_options root\@$self->{guest_ipaddr} ls") != 0) {
            $self->record_guest_installation_result('FAILED');
            record_info("Guest $self->{guest_name} agama installer shell ssh pubkey login failed", "Try login with password to guest $self->{guest_name} agama installer shell", result => 'fail');
            enter_cmd("clear", wait_still_screen => 3);
            enter_cmd("timeout --kill-after=1 --signal=9 1800 ssh $_ssh_command_options root\@$self->{guest_ipaddr}", wait_still_screen => 5, timeout => 1850);
            assert_screen('password-prompt', timeout => 30);
            enter_cmd("novell", wait_screen_change => 60, max_interval => 1, timeout => 90);
            wait_still_screen(15);
            enter_cmd("timeout --kill-after=1 --signal=9 120 ip addr show", wait_still_screen => 5, timeout => 150);
        }
        else {
            record_info("Guest $self->{guest_name} agama installer shell ssh pubkey login succeeded");
        }
    }

    return $self;
}

=head2 verify_guest_agama_installation_done

  verify_guest_agama_installation_done($self)

Verify progress of guest installation using Agama installer which is achieved by
querying 'Install phase done' string in journal log. Ony for displaying purpose
if ssh connection is established with password only. Guest installation has been
already marked as 'FAILED' for this case in setup_guest_agama_installation_shell.
=cut

sub verify_guest_agama_installation_done {
    my $self = shift;

    my $_wait_timeout = get_var('AGAMA_INSTALL_TIMEOUT', 600);
    my $_ssh_command_options = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    if ($self->{guest_installation_result} eq 'FAILED') {
        if ($self->{guest_ipaddr} eq 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT') {
            record_info("Can not verify agama install for guest $self->{guest_name}", "Guest $self->{guest_name} has no ip address $self->{guest_ipaddr}", result => 'fail');
            return $self;
        }
        while ($_wait_timeout > 0) {
            enter_cmd("timeout --kill-after=1 --signal=9 120 journalctl -u agama | grep \'Install phase done\'", timeout => 150);
            wait_still_screen(20);
            $_wait_timeout -= 20;
        }
        enter_cmd("exit");
        wait_still_screen(15);
        if (!check_screen('text-logged-in-root', timeout => 30)) {
            select_backend_console(init => 0);
            $self->get_guest_installation_session if ($self->{guest_installation_session} eq '');
            type_string("reset\n");
            wait_still_screen;
        }
    }
    else {
        $_ssh_command_options = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ";
        $_ssh_command_options .= is_sle('16+') ? "-o PubkeyAcceptedAlgorithms=+ssh-ed25519 " : "-o PubkeyAcceptedAlgorithms=+ssh-rsa ";
        $_ssh_command_options .= "-i $_host_params{ssh_key_file}";
        while ($_wait_timeout > 0) {
            if (script_run("timeout --kill-after=1 --signal=9 120 ssh $_ssh_command_options root\@$self->{guest_ipaddr} \"journalctl -u agama | grep \'Install phase done\'\"", timeout => 150) == 0) {
                record_info("Guest $self->{guest_name} agama install phase done", "Guest $self->{guest_name} ip address is $self->{guest_ipaddr}");
                $self->record_guest_installation_result('AGAMA_INSTALL_PHASE_DONE');
                return $self;
            }
            sleep 20;
            $_wait_timeout -= 20;
        }
    }
    $self->record_guest_installation_result('FAILED');
    record_info("Guest $self->{guest_name} agama install phase not done", "Installation failed, verification timed out or failed passwordless ssh login", result => 'fail');

    return $self;
}

=head2 save_guest_agama_installation_logs

  save_guest_agama_installation_logs($self)

Save guest agama installation logs regardless of whether a successful or failed
installation. For 'FAILED' installation, transferring saved logs in guest system
still requires password login.
=cut

sub save_guest_agama_installation_logs {
    my $self = shift;

    my $_ssh_command_options = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ";
    $_ssh_command_options .= is_sle('16+') ? "-o PubkeyAcceptedAlgorithms=+ssh-ed25519" : "-o PubkeyAcceptedAlgorithms=+ssh-rsa";
    $_ssh_command_options .= " -i $_host_params{ssh_key_file}";
    if ($self->{guest_installation_result} eq 'FAILED' and script_run("timeout --kill-after=1 --signal=9 60 ssh $_ssh_command_options root\@$self->{guest_ipaddr} ls") != 0) {
        if ($self->{guest_ipaddr} eq 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT') {
            record_info("Can not save agama install logs for guest $self->{guest_name}", "Guest $self->{guest_name} has no ip address $self->{guest_ipaddr}", result => 'fail');
            return $self;
        }
        record_info("Save guest $self->{guest_name} agama install logs", "Use password ssh login");
        $_ssh_command_options = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
        enter_cmd("clear", wait_still_screen => 3);
        enter_cmd("timeout --kill-after=1 --signal=9 1800 ssh $_ssh_command_options root\@$self->{guest_ipaddr}", wait_still_screen => 5, timeout => 1850);
        assert_screen('password-prompt', timeout => 30);
        enter_cmd("novell", wait_screen_change => 60, max_interval => 1, timeout => 90);
        wait_still_screen(15);
        enter_cmd("timeout --kill-after=1 --signal=9 120 mkdir /agama_installation_logs", timeout => 150);
        enter_cmd("timeout --kill-after=1 --signal=9 180 agama logs store -d /agama_installation_logs", timeout => 210);
        enter_cmd("timeout --kill-after=1 --signal=9 180 agama config show > /agama_installation_logs/agama_config.txt", timeout => 210);
        enter_cmd("timeout --kill-after=1 --signal=9 120 sync", timeout => 150);
        wait_still_screen;
        enter_cmd("exit");
        wait_still_screen(15);
        if (!check_screen('text-logged-in-root', timeout => 30)) {
            select_backend_console(init => 0);
            $self->get_guest_installation_session if ($self->{guest_installation_session} eq '');
            type_string("reset\n");
            wait_still_screen;
        }
        my @_agama_installation_logs = ('/agama_installation_logs/agama-logs.tar.gz', '/agama_installation_logs/agama_config.txt');
        foreach (@_agama_installation_logs) {
            enter_cmd("timeout --kill-after=1 --signal=9 180 scp -r $_ssh_command_options root\@$self->{guest_ipaddr}:$_ $self->{guest_log_folder}", timeout => 210);
            assert_screen('password-prompt', timeout => 30);
            enter_cmd("novell", wait_screen_change => 60, max_interval => 1, timeout => 90);
            wait_still_screen(15);
        }
    }
    else {
        record_info("Save guest $self->{guest_name} agama install logs", "Use passwordless ssh login");
        $_ssh_command_options = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ";
        $_ssh_command_options .= is_sle('16+') ? "-o PubkeyAcceptedAlgorithms=+ssh-ed25519" : "-o PubkeyAcceptedAlgorithms=+ssh-rsa";
        $_ssh_command_options .= " -i $_host_params{ssh_key_file}";
        script_run("timeout --kill-after=1 --signal=9 120 ssh $_ssh_command_options root\@$self->{guest_ipaddr} \"mkdir /agama_installation_logs\"", timeout => 150);
        script_run("timeout --kill-after=1 --signal=9 180 ssh $_ssh_command_options root\@$self->{guest_ipaddr} \"agama logs store -d /agama_installation_logs\"", timeout => 210);
        script_run("timeout --kill-after=1 --signal=9 180 ssh $_ssh_command_options root\@$self->{guest_ipaddr} \"agama config show > /agama_installation_logs/agama_config.txt\"", timeout => 210);
        script_run("timeout --kill-after=1 --signal=9 180 scp -r $_ssh_command_options root\@$self->{guest_ipaddr}:/agama_installation_logs/{agama-logs.tar.gz,agama_config.txt} $self->{guest_log_folder}", timeout => 210);
        script_run("timeout --kill-after=1 --signal=9 120 ssh $_ssh_command_options root\@$self->{guest_ipaddr} \"sync\"", timeout => 150);
        if ($self->{guest_installation_result} ne 'FAILED') {
            record_info("Reboot guest $self->{guest_name} to disk boot", "Saved guest $self->{guest_name} agama installation logs");
            $self->power_cycle_guest('force') if (script_run("timeout --kill-after=1 --signal=9 180 ssh $_ssh_command_options root\@$self->{guest_ipaddr} \"reboot --reboot\"", timeout => 210) != 0);
        }
    }
    $self->upload_guest_installation_logs;

    return $self;
}

=head2 check_guest_installation_result_via_ssh

  check_guest_installation_result_via_ssh($self)

Get guest ip address and check whether it is already up and running by using ip
address and name sequentially. Use very common linux command 'hostname' to do
the actual checking because it is almost available on any linux flavor and release.
For guest having [guest_network_type]='bridge' and [guest_network_mode]='host',
FQDN is to be used on ssh command because it might not be reached by using its
name only due to broader DHCP/DNS configuration problem in testing network.

=cut

sub check_guest_installation_result_via_ssh {
    my $self = shift;

    $self->reveal_myself;
    my $_guest_transient_hostname_via_ipaddr = '';
    my $_guest_transient_hostname_via_name = '';
    my $_ret = 1;
    record_info("Going to use guest $self->{guest_name} ip address to detect installation result directly.", "No any interested needle or text-login/guest-console-text-login needle is detected.Just a moment");
    $self->get_guest_ipaddr if (is_agama_guest(guest => $self->{guest_name}) or is_tumbleweed or (($self->{guest_ipaddr_static} ne 'true') and (!($self->{guest_ipaddr} =~ /^\d+\.\d+\.\d+\.\d+$/im))));
    save_screenshot;
    if ($self->{guest_ipaddr} =~ /^\d+\.\d+\.\d+\.\d+$/im) {
        $_ret = script_run("timeout --kill-after=3 --signal=9 30 " . $_host_params{ssh_command} . "\@$self->{guest_ipaddr} hostname", timeout => 60);
        $_guest_transient_hostname_via_ipaddr = script_output("timeout --kill-after=3 --signal=9 30 " . $_host_params{ssh_command} . "\@$self->{guest_ipaddr} hostname", proceed_on_failure => 1);
        save_screenshot;
        if ($_guest_transient_hostname_via_ipaddr ne '' and $_ret == 0) {
            record_info("Guest $self->{guest_name} can be connected via ssh using ip $self->{guest_ipaddr} directly", "So far so good.");
            if ($self->{guest_network_type} eq 'bridge' and $self->{guest_network_mode} eq 'host') {
                $_guest_transient_hostname_via_ipaddr =~ s/\.$self->{guest_domain_name}//g;
                virt_autotest::utils::add_alias_in_ssh_config('/root/.ssh/config', $_guest_transient_hostname_via_ipaddr, $self->{guest_domain_name}, $self->{guest_name});
            }
            save_screenshot;
            $_ret = script_run("timeout 30 " . $_host_params{ssh_command} . "\@$self->{guest_name} hostname", timeout => 60);
            $_guest_transient_hostname_via_name = script_output("timeout 30 " . $_host_params{ssh_command} . "\@$self->{guest_name} hostname", proceed_on_failure => 1);
            save_screenshot;
            if ($_guest_transient_hostname_via_name ne '' and $_ret == 0) {
                record_info("Installation succeeded with good ssh connection for guest $self->{guest_name}", "Well done ! Mark it as PASSED");
                $self->record_guest_installation_result('PASSED');
            }
            else {
                if ($self->{guest_network_type} eq 'bridge' and $self->{guest_network_mode} eq 'host') {
                    virt_autotest::utils::add_guest_to_hosts("$_guest_transient_hostname_via_ipaddr", $self->{guest_ipaddr});
                    virt_autotest::utils::add_guest_to_hosts("$_guest_transient_hostname_via_ipaddr.$self->{guest_domain_name}", $self->{guest_ipaddr});
                    $_ret = script_run("timeout 30 " . $_host_params{ssh_command} . "\@$_guest_transient_hostname_via_ipaddr.$self->{guest_domain_name} hostname", timeout => 60);
                    $_guest_transient_hostname_via_name = script_output("timeout 30 " . $_host_params{ssh_command} . "\@$_guest_transient_hostname_via_ipaddr.$self->{guest_domain_name} hostname", proceed_on_failure => 1);
                }
                else {
                    virt_autotest::utils::add_guest_to_hosts($self->{guest_name}, $self->{guest_ipaddr});
                    $_ret = script_run("timeout 30 " . $_host_params{ssh_command} . "\@$self->{guest_name} hostname", timeout => 60);
                    $_guest_transient_hostname_via_name = script_output("timeout 30 " . $_host_params{ssh_command} . "\@$self->{guest_name} hostname", proceed_on_failure => 1);
                }
                if ($_guest_transient_hostname_via_name ne '' and $_ret == 0) {
                    record_info("Installation succeeded with good ssh connection for guest $self->{guest_name} using /etc/hosts", "Although querying guest with FQDN failed, still mark installation as PASSED", result => 'fail');
                    $self->record_guest_installation_result('PASSED');
                }
                else {
                    record_info("Installation succeeded with bad ssh connection for guest $self->{guest_name}", "Querying guest with /etc/hosts failed. Mark installation as FAILED", result => 'fail');
                    $self->record_guest_installation_result('FAILED');
                }
            }
        }
        elsif (is_agama_guest(guest => $self->{guest_name}) and !($self->is_guest_installation_done)) {
            $self->detach_guest_installation_screen;
            $self->monitor_guest_agama_installation;
            $_guest_transient_hostname_via_name = "TO_BE_CHECKED_FURTHER";
            $self->get_guest_ipaddr if ($self->{guest_ipaddr_static} ne 'true');
        }
    }
    return $_guest_transient_hostname_via_name;
}

=head2 attach_guest_installation_screen

  attach_guest_installation_screen($self)

Attach guest installation screen before monitoring guest installation progress:
If [guest_installation_session] is not available and no [guest_autoconsole],
call do_attach_guest_installation_screen_without_sesssion.
If [guest_installation_session] is not available and has [guest_autoconsole],
call get_guest_installation_session, then attach based on whether installation
session is available.
If [guest_installation_session] is already available,call
do_attach_guest_installation_screen directly.

=cut

sub attach_guest_installation_screen {
    my $self = shift;

    $self->reveal_myself;
    save_screenshot;
    record_info("Attaching $self->{guest_name} installation screen process $self->{guest_installation_session}", "Trying hard");
    if (($self->{guest_installation_attached} eq 'false') or ($self->{guest_installation_attached} eq '')) {
        if (($self->{guest_installation_session} eq '') and (!($self->has_autoconsole_for_sure))) {
            record_info("Guest $self->{guest_name} has no autoconsole or installation screen process $self->{guest_installation_session} may terminate on reboot/shutoff after installation finishes or at certain stage", "Reconnect by using screen -t $self->{guest_name} virsh console $self->{guest_name}");
            $self->do_attach_guest_installation_screen_without_session;
        }
        elsif (($self->{guest_installation_session} eq '') and ($self->has_autoconsole_for_sure)) {
            record_info("Guest $self->{guest_name} has autoconsole but no installation screen session info to attach", "Trying to get installation screen session info");
            $self->get_guest_installation_session;
            if ($self->{guest_installation_session} eq '') {
                record_info("Guest $self->{guest_name} has autoconsole but installation process terminated somehow, so can not get its installation screen session info", "Reconnect by using screen -t $self->{guest_name} virsh console $self->{guest_name}");
                $self->do_attach_guest_installation_screen_without_session;
            }
            else {
                $self->do_attach_guest_installation_screen_with_session;
            }
        }
        else {
            $self->do_attach_guest_installation_screen;
        }
    }
    else {
        record_info("Guest $self->{guest_name} installation screen process $self->{guest_installation_session} had already been attached", "Good news !");
    }
    return $self;
}

=head2 do_attach_guest_installation_screen

  do_attach_guest_installation_screen($self)

Call do_attach_guest_installation_screen_with_session anyway. Mark
[guest_installation_attached] as true if needle 'text-logged-in-root' can not be
detected. If fails to attach guest installation screen, [guest_installation_session]
may terminate at reboot/shutoff or be in mysterious state or just broken somehow,
call do_attach_guest_installation_screen_without_sesssion to re-attach.

=cut

sub do_attach_guest_installation_screen {
    my $self = shift;

    $self->reveal_myself;
    $self->do_attach_guest_installation_screen_with_session;
    if (!(check_screen('text-logged-in-root'))) {
        $self->{guest_installation_attached} = 'true';
        record_info("Attached $self->{guest_name} installation screen process $self->{guest_installation_session} successfully", "Well done !");
    }
    else {
        if (!($self->has_autoconsole_for_sure)) {
            record_info("Guest $self->{guest_name} has no autoconsole or installation screen process $self->{guest_installation_session} may terminate on reboot/shutoff after installaton finishes or at certain stage", "Reconnect by using screen -t $self->{guest_name} virsh console $self->{guest_name}");
        }
        else {
            record_info("Failed to attach $self->{guest_name} installation screen process $self->{guest_installation_session}", "Bad luck ! Try to re-connect by using screen -t $self->{guest_name} virsh console $self->{guest_name}");
        }
        $self->do_attach_guest_installation_screen_without_session;
    }
    return $self;
}

=head2 do_attach_guest_installation_screen_with_session

  do_attach_guest_installation_screen_with_session($self)

Retry attach [guest_installation_session] and detect needle 'text-logged-in-root'.

=cut

sub do_attach_guest_installation_screen_with_session {
    my $self = shift;

    $self->reveal_myself;
    assert_screen('text-logged-in-root');
    type_string("reset\n");
    save_screenshot;
    my $_retry_counter = 3;
    while (check_screen('text-logged-in-root', timeout => 5)) {
        if ($_retry_counter gt 0) {
            wait_screen_change {
                type_string("screen -d -r $self->{guest_installation_session}\n");
            };
            save_screenshot;
            $_retry_counter--;
        }
        else {
            save_screenshot;
            last;
        }
        save_screenshot;
    }
    save_screenshot;
    return $self;
}

=head2 do_attach_guest_installation_screen_without_session

  do_attach_guest_installation_screen_without_session($self)

If [guest_installation_session] is already terminated at reboot/shutoff or somehow,
power it on and retry attaching using [guest_installation_session_command] and
detect needle 'text-logged-in-root'.Mark it as FAILED if needle 'text-logged-in-root'
can still be detected and poweron can not bring it back.

=cut

sub do_attach_guest_installation_screen_without_session {
    my $self = shift;

    $self->reveal_myself;
    script_run("screen -X -S $self->{guest_installation_session} kill");
    $self->{guest_installation_session} = '';
    save_screenshot;
    $self->power_cycle_guest('poweron');
    type_string("reset\n");
    assert_screen('text-logged-in-root');
    my $_retry_counter = 3;
    while (check_screen('text-logged-in-root', timeout => 5)) {
        if ($_retry_counter gt 0) {
            my $_attach_timestamp = localtime();
            $_attach_timestamp =~ s/ |:/_/g;
            my $_guest_installation_log = "$_host_params{common_log_folder}/$self->{guest_name}/$self->{guest_name}" . "_installation_log_" . $_attach_timestamp;
            $self->{guest_installation_session_config} = script_output("cd ~;pwd") . '/' . $self->{guest_name} . '_installation_screen_config' if ($self->{guest_installation_session_config} eq '');
            script_run("> $self->{guest_installation_session_config};cat /etc/screenrc > $self->{guest_installation_session_config};sed -in \'/^logfile .*\$/d\' $self->{guest_installation_session_config}");
            script_run("echo \"logfile $_guest_installation_log\" >> $self->{guest_installation_session_config}");
         #Use "screen" in the most compatible way, screen -t "title (window's name)" -c "screen configuration file" -L(turn on output logging) "command to run".
            #The -Logfile option is only supported by more recent operating systems.
            $self->{guest_installation_session_command} = "screen -t $self->{guest_name} -L -c $self->{guest_installation_session_config} virsh console --force $self->{guest_name}";
            wait_screen_change {
                type_string("$self->{guest_installation_session_command}\n");
            };
            send_key('ret') for (0 .. 2);
            save_screenshot;
            $_retry_counter--;
            sleep 10;
        }
        else {
            save_screenshot;
            last;
        }
        save_screenshot;
    }
    save_screenshot;
    if (!(check_screen('text-logged-in-root'))) {
        $self->{guest_installation_attached} = 'true';
        record_info("Opened guest $self->{guest_name} installation window successfully", "Well done !");
    }
    else {
        $self->{guest_installation_attached} = 'false';
        record_info("Failed to open guest $self->{guest_name} installation window", "Bad luck !");
        $self->power_cycle_guest('poweron');
        if ((script_output("virsh list --all --name | grep $self->{guest_name}", proceed_on_failure => 1) eq '') or (script_output("virsh list --all | grep \"$self->{guest_name}.*running\"", proceed_on_failure => 1) eq '')) {
            record_info("Guest $self->{guest_name} installation process terminates somehow due to unexpected errors", "Guest disappears or stays at shutoff state even after poweron.Mark it as FAILED", result => 'fail');
            $self->record_guest_installation_result('FAILED');
        }
    }
    return $self;
}

=head2 detach_guest_installation_screen

  detach_guest_installation_screen($self)

Detach guest installation screen by calling do_detach_guest_installation_screen.
Try to get guest installation screen information if [guest_installation_session]
is not available.

=cut

sub detach_guest_installation_screen {
    my $self = shift;

    $self->reveal_myself;
    save_screenshot;
    record_info("Detaching $self->{guest_name} installation screen process $self->{guest_installation_session}", "Trying hard");
    if ($self->{guest_installation_attached} eq 'true') {
        $self->do_detach_guest_installation_screen;
    }
    else {
        record_info("Guest $self->{guest_name} installation screen process $self->{guest_installation_session} had already been detached", "Good news !");
        $self->get_guest_installation_session if ($self->{guest_installation_session} eq '');
    }
    return $self;
}

=head2 do_detach_guest_installation_screen

  do_detach_guest_installation_screen($self)

Retry doing real guest installation screen detach using send_key('ctrl-a-d') and
detecting needle 'text-logged-in-root'. If either of the needles is detected, this
means successful detach. If neither of the needle can be detected, recover ssh 
console by select_console('root-ssh').

=cut

sub do_detach_guest_installation_screen {
    my $self = shift;

    $self->reveal_myself;
    wait_still_screen;
    save_screenshot;
    my $_retry_counter = 3;
    while (!(check_screen([qw(text-logged-in-root)], timeout => 5))) {
        if ($_retry_counter gt 0) {
            send_key('ctrl-a-d');
            save_screenshot;
            type_string("reset\n");
            wait_still_screen;
            save_screenshot;
            $_retry_counter--;
        }
        else {
            last;
        }
    }
    save_screenshot;
    if (check_screen([qw(text-logged-in-root in-libvirtd-container-bash)], timeout => 5)) {
        record_info("Detached $self->{guest_name} installation screen process $self->{guest_installation_session} successfully", "Well Done !");
        $self->get_guest_installation_session if ($self->{guest_installation_session} eq '');
        type_string("reset\n");
        wait_still_screen;
    }
    else {
        record_info("Failed to detach $self->{guest_name} installation screen process $self->{guest_installation_session}", "Bad luck !");
        select_backend_console(init => 0);
        $self->get_guest_installation_session if ($self->{guest_installation_session} eq '');
        type_string("reset\n");
        wait_still_screen;
    }
    $self->{guest_installation_attached} = 'false';
    return $self;
}

=head2 has_autoconsole_for_sure

  has_autoconsole_for_sure($self)

Return true if guest has [guest_autoconsole] and [guest_noautoconsole] that are
not equal to 'none', 'true' or empty which indicates guest definitely has autoconsole.
Empty value may indicate there is autoconsole or the opposite which depends on
detailed configuration of guest.

=cut

sub has_autoconsole_for_sure {
    my $self = shift;

    $self->reveal_myself;
    return (($self->{guest_autoconsole} ne 'none') and ($self->{guest_autoconsole} ne '') and ($self->{guest_noautoconsole} ne 'true') and ($self->{guest_noautoconsole} ne ''));
}

=head2 has_noautoconsole_for_sure

  has_noautoconsole_for_sure($self)

Return true if guest has [guest_autoconsole] or [guest_noautoconsole] that are
equal to 'none' or 'true' which indicates guest definitely has no autoconsole.
Empty value may indicate there is autoconsole or the opposite which depends on
detailed configuration of guest.

=cut

sub has_noautoconsole_for_sure {
    my $self = shift;

    $self->reveal_myself;
    return (($self->{guest_autoconsole} eq 'none') or ($self->{guest_noautoconsole} eq 'true'));
}

=head2 record_guest_installation_result

  record_guest_installation_result($self, $_guest_installation_result)

Record final guest installation result in [guest_installation_result] and set
[stop_run] and [stop_timestamp].

=cut

sub record_guest_installation_result {
    my ($self, $_guest_installation_result) = @_;

    $self->reveal_myself;
    $_guest_installation_result //= '';
    $self->{guest_installation_result} = $_guest_installation_result;
    record_info("Guest $self->{guest_name} installation has already been marked as $self->{guest_installation_result}", "It is done !");
    $self->{stop_run} = time();
    $self->{stop_timestamp} = localtime($self->{stop_run});
    return $self;
}

=head2 is_guest_installation_done

  is_guest_installation_done($self)

Check whether guest installation finishes completely and has final successful
or failing result. Take agama guest as an example, AGAMA_INSTALL_PHASE_DONE
does not and should not indicates a complete successful or failing installation
. It only passes the initial configuration and installation by employing agama.
Final result can only be determined after rebooting and detecting system. 

=cut

sub is_guest_installation_done {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_result} ne '') {
        if (is_agama_guest(guest => $self->{guest_name}) and ($self->{guest_installation_result} eq 'AGAMA_INSTALL_PHASE_DONE')) {
            return 0;
        }
        return 1;
    }
    return 0;
}

=head2 collect_guest_installation_logs_via_ssh

  collect_guest_installation_logs_via_ssh($self)

Collect guest y2logs via ssh and save guest config xml file.

=cut

sub collect_guest_installation_logs_via_ssh {
    my $self = shift;

    $self->reveal_myself;
    $self->get_guest_ipaddr;
    if ((script_run("nmap $self->{guest_ipaddr} -PN -p ssh | grep -i open") eq 0) and ($self->{guest_ipaddr} ne '') and ($self->{guest_ipaddr} ne 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT')) {
        record_info("Guest $self->{guest_name} has ssh port open on ip address $self->{guest_ipaddr}.", "Try to collect logs via ssh but may fail.Open ssh port does not mean good ssh connection.");
        script_retry($_host_params{ssh_command} . "\@$self->{guest_ipaddr} \"save_y2logs /tmp/$self->{guest_name}_y2logs.tar.gz\"", timeout => 180, retry => 3);
        script_run("scp -r -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$self->{guest_ipaddr}:/tmp/$self->{guest_name}_y2logs.tar.gz $self->{guest_log_folder}");
    }
    else {
        record_info("Guest $self->{guest_name} has no ssh connection available at all.Not able to collect logs from it via ssh", "Guest ip address is $self->{guest_ipaddr}");
    }
    script_run("virsh dumpxml $self->{guest_name} > $self->{guest_log_folder}/virsh_dumpxml_$self->{guest_name}.xml");
    script_run("rm -f -r $_host_params{common_log_folder}/unattended*");
    return $self;
}

=head2 upload_guest_installation_logs

  upload_guest_installation_logs($self)

Upload logs collect by collect_guest_installation_logs_via_ssh.

=cut

sub upload_guest_installation_logs {
    my $self = shift;

    $self->reveal_myself;
    assert_script_run("tar czvf /tmp/guest_installation_and_configuration_logs.tar.gz $_host_params{common_log_folder}");
    upload_logs("/tmp/guest_installation_and_configuration_logs.tar.gz");
    return $self;
}

=head2 detach_all_nfs_mounts

  detach_all_nfs_mounts($self)

Unmount all mounted nfs shares to avoid unnecessary logs to be collected by
supportconfig or sosreport which may take extremely long time.

=cut

sub detach_all_nfs_mounts {
    my $self = shift;

    $self->reveal_myself;
    script_run("umount -a -f -l -t nfs,nfs4") if (script_run("umount -a -t nfs,nfs4") ne 0);
    return $self;
}

=head2 power_cycle_guest

  power_cycle_guest($self, _power_cycle_style => $_power_cycle_style)

Power cycle guest by force:virsh destroy, grace:virsh shutdown, reboot:virsh
reboot and poweron:virsh start.

=cut

sub power_cycle_guest {
    my ($self, $_power_cycle_style) = @_;

    $self->reveal_myself;
    $_power_cycle_style //= 'grace';
    my $_guest_name = '';
    my $_time_out = '600';
    if ($_power_cycle_style eq 'force') {
        script_run("virsh destroy $self->{guest_name}");
    }
    elsif ($_power_cycle_style eq 'grace') {
        script_run("virsh shutdown $self->{guest_name}");
    }
    elsif ($_power_cycle_style eq 'reboot') {
        script_run("virsh reboot $self->{guest_name}");
        return $self;
    }
    elsif ($_power_cycle_style eq 'poweron') {
        script_run("virsh start $self->{guest_name}");
        return $self;
    }

    while (($_guest_name ne "$self->{guest_name}") and ($_time_out lt 600)) {
        $_guest_name = script_output("virsh list --name  --state-shutoff | grep -o $self->{guest_name}", timeout => 30, proceed_on_failure => 1);
        $_time_out += 5;
    }
    script_run("virsh start $self->{guest_name}");
    return $self;
}

=head2 modify_guest_params

  modify_guest_params($self, $_guest_name, $_guest_option, $_modify_operation)

Modify guest parameters after guest installation passes using virt-xml.

=cut

sub modify_guest_params {
    my ($self, $_guest_name, $_guest_option, $_modify_operation) = @_;

    $self->reveal_myself;
    $_modify_operation //= 'define';
    assert_script_run("virt-xml $_guest_name --edit --print-diff --$_modify_operation $self->{$_guest_option}");
    $self->power_cycle_guest('force');
    return $self;
}

=head2 add_guest_device

  add_guest_device()

Add device to guest after guest installation passes using virt-xml.

=cut

sub add_guest_device {
    #TODO
}

=head2 remove_guest_device

  remove_guest_device()

Remove device from guest after guest installation passes using virt-xml.

=cut

sub remove_guest_device {
    #TODO
}

=head2 AUTOLOAD

  AUTOLOAD($self)

AUTOLOAD to be called if called subroutine does not exist.

=cut

sub AUTOLOAD {
    my $self = shift;

    $self->reveal_myself;
    my $type = ref($self) || croak "$self is not an object";
    my $field = $AUTOLOAD;
    $field =~ s/.*://;
    unless (exists $self->{$field}) {
        croak "$field does not exist in object/class $type";
    }
    if (@_) {
        return $self->{funcname} = shift;
    }
    else {
        return $self->{domain_name};
    }
}

=head2 post_fail_hook

  post_fail_hook($self)

Collect logs and gues extra log '/root' by using virt_utils::collect_host_and_guest_logs.
'Root' directory on guest contains very valuable content that is generated automatically
after guest installation finishes.

=cut

sub post_fail_hook {
    my $self = shift;

    $self->reveal_myself;
    $self->upload_guest_installation_logs;
    save_screenshot;
    virt_utils::collect_host_and_guest_logs(extra_host_log => '/var/log', extra_guest_log => '/root /var/log /emergency_mode /agama_installation_logs', full_supportconfig => get_var('FULL_SUPPORTCONFIG', 1), token => '_guest_installation');
    save_screenshot;
    upload_coredumps;
    save_screenshot;
    return $self;
}

1;
