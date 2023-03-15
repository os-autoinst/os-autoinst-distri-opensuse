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
# Maintainer: Wayne Chen <wchen@suse.com>
package guest_installation_and_configuration_base;

use base "opensusebasetest";
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
use List::Util qw(first);
use testapi;
use utils;
use ipmi_backend_utils qw(reconnect_when_ssh_console_broken);
use virt_utils;
use virt_autotest::utils;
use virt_autotest::virtual_network_utils;
use alp_workloads::kvm_workload_utils;
use version_utils;
use Utils::Systemd;
use mm_network;

#%guest_params contains all parameters will be used for virtual machine creation, installation and configuration.
#All parameters before those end with 'options' can be included in guest params xml file and used as guest instance configuration file.
#And it recommends that all parameters should be given lower case values all the time in guest params xml file or in hash data structure
#except for those that are copied over and modification will cause invalidation or upper case values have to be given to make them right.
#For example, [guest_installation_media] might be given URL that contains upper case characters which is completely acceptable.
#Please refer to lib/concurrent_guest_installations.pm and tests/virt_autotest/uefi_guest_installation.pm for how to use guest params xml file.
our %guest_params = (
    'guest_os_name' => '',    #[guest_os_name]:sles,opensuse,oraclelinux or others.Not virt-install argument.
    'guest_os_word_length' => '',    #[guest_os_word_length]:64 or 32.Not virt-install argument.
    'guest_version' => '',    #[guest_version]:15-sp3 or others.Not virt-install argument.
    'guest_version_major' => '',    #[guest_version_major]:15 or others.Not virt-install argument.
    'guest_version_minor' => '',    #[guest_version_minor]:3 or others.Not virt-install argument.
    'guest_build' => '',    #Build number if developing release or 'gm'.Not virt-install argument.It should be left empty in guest params xml file
        #if developing release will be installed for the guest.It will be set to the same as BUILD from test suite settings in config_guest_params.
        #Otherwise it must be set to 'gm' in guest params xml file if non-developing release will be installed for the guest.
    'host_hypervisor_uri' => '',    #virt-install --connect [host_hypervisor_uri]
    'host_virt_type' => '',    #virt-install --virt-type [host_virt_type]
    'guest_virt_type' => '',    #virt-install --[guest_virt_type(hvm or paravirt)]
    'guest_machine_type' => '',    #virt-install --machine [guest_machine_type]
    'guest_arch' => '',    #virt-install --arch [guest_arch]
    'guest_name' => '',    #virt-install --name [guest_name]
    'guest_domain_name' => '',    #This will be used for DNS configuration, not virt-install argument
    'guest_memory' => '',    #virt-install --memory [guest_memory]
    'guest_vcpus' => '',    #virt-install --vcpus [guest_vcpus]
    'guest_cpumodel' => '',    #virt-install --cpu [guest_cpumodel]
    'guest_metadata' => '',    #virt-install --metadata [guest_metadata]
    'guest_xpath' => '',    #virt-install --xml [guest_xpath].It can contain multiple items seperated by hash key
    'guest_installation_automation' => '', #This indicates whether guest uses autoyast or kickstart installation (autoyast, kickstart or empty), not virt-install argument
    'guest_installation_automation_file' => '', #virt-install --extra-args "autoyast=[guest_installation_automation_file] or inst.ks=[guest_installation_automation_file]"
    'guest_installation_method' => '',    #virt-install --[guest_installation_method(location, cdrom, pxe, import and etc)]
    'guest_installation_method_others' => '',    #virt-install --[guest_installation_method] [guest_installation_method_others] or
                                                 #--[guest_installation_method] [guest_installation_media],[guest_installation_method_others]
    'guest_installation_extra_args' => '',    #virt-install --extra-args [guest_installation_extra_args].It can contain multiple itmes seperated by hash key
    'guest_installation_wait' => '',    #virt-install --wait [guest_installation_wait]
    'guest_installation_media' => '',    #virt-install --location [guest_installation_media] or --cdrom [guest_installation_media]
    'guest_installation_fine_grained' => '',    #virt-install --install [guest_installation_fine_grained]
    'guest_boot_settings' => '',    #virt-install --boot [guest_boot_settings]
    'guest_secure_boot' => '',    #This indicates whether uefi secure boot is enabled(true, false or empty) during installation in unattended installation file,
                                  #not virt-install argument
    'guest_os_variant' => '',    #virt-install --os-variant [guest_os_variant]
    'guest_storage_path' => '',    #virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],[guest_storage_others]
    'guest_storage_type' => '',    #virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],[guest_storage_others]
    'guest_storage_format' => '',  #virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],[guest_storage_others]
    'guest_storage_label' => '',    #This indicates whether guest disk uses gpt or mbr in unattended installation file, not virt-install argument
    'guest_storage_size' => '',    #virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],[guest_storage_others]
    'guest_storage_others' => '',  #virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],[guest_storage_others]
    'guest_network_type' => '',    #This indicates whether guest uses bridge, nat, virtual_network, or other network types, not virt-install argument
    'guest_network_device' => '',    #virt-install --network=bridge=[guest_network_device],mac=[guest_macaddr] (Also can be used with other network type)
    'guest_network_others' => '',    #virt-install --netowrk=bridge=[guest_network_device],mac=[guest_macaddr],[guest_network_others]
                                     #(Also can be used with other network type)
    'guest_macaddr' => '',    #virt-install --network=bridge=[guest_network_device],mac=[guest_macaddr] (Also can be used with other network type)
    'guest_virtual_network' => '',    # virt-install --network=network=[guest_virtual_network],mac=[guest_macaddr],[guest_network_others]
    'guest_netaddr' => '', #This indicates the subnet to which guest will be connected. It takes the form ip_address/subnet_mask_length and defaults to 192.168.123.255/24,
        #not virt-install argument. If 'host-default' is given, this indicates guest will use host network and host bridge device that already exists
        #and are connected directly to default gateway, for example, br0. If br0 or any other host bridge devices already conneced to host network that
        #do not exist, [guest_network_device] wil be configured to connect to host network and used for guest configuration.
        #If [guest_virtual_network] is configured, please ensure [guest_netaddr] matches the subnet of this virtual network.
    'guest_ipaddr' => '',    #virt-install --extra-args "ip=[guest_ipaddr]" if it is a static ip address, otherwise it is not virt-install argument.
                             #It stores the final guest ip address obtained from ip discovery
    'guest_ipaddr_static' => '',    #This indicates whether guest uses static ip address(true or false), not virt-install argument
    'guest_graphics' => '',    #virt-install --graphics [guest_graphics]
    'guest_controller' => '',  # virt-install --controller [guest_controller].More than one controller can be passed to guest, they should be separated by hash.
                               # For example, "controller1#controller2#controller3" which will be splitted later and passed to individual --controller argument.
    'guest_sysinfo' => '',    #virt-install --sysinfo [guest_sysinfo]
    'guest_input' => '',    #TODO            #virt-install --input [guest_input]
    'guest_serial' => '',    #virt-install --serial [guest_serial]
    'guest_parallel' => '',    #TODO            #virt-install --parallel [guest_parallel]
    'guest_channel' => '',    #TODO            #virt-install --channel [guest_channel]
    'guest_console' => '',    #virt-install --console [guest_console]
    'guest_hostdev' => '',    #TODO            #virt-install --hostdev [guest_hostdev]
    'guest_filesystem' => '',    #TODO            #virt-install --filesystem [guest_filesystem]
    'guest_sound' => '',    #TODO            #virt-install --sound [guest_sound]
    'guest_watchdog' => '',    #TODO            #virt-install --watchdog [guest_watchdog]
    'guest_video' => '',    #virt-install --video [guest_video]
    'guest_smartcard' => '',    #TODO            #virt-install --smartcard [guest_smartcard]
    'guest_redirdev' => '',    #TODO            #virt-install --redirdev [guest_redirdev]
    'guest_memballoon' => '',    # virt-install --memballoon [guest_memballoon]
    'guest_tpm' => '',    #TODO            #virt-install --tpm [guest_tpm]
    'guest_rng' => '',    # virt-install --rng [guest_rng]
    'guest_panic' => '',    #TODO            #virt-install --panic [guest_panic]
    'guest_memdev' => '',    # virt-install --memdev [guest_memdev]
    'guest_vsock' => '',    #TODO            #virt-install --vsock [guest_vsock]
    'guest_iommu' => '',    #TODO            #virt-install --iommu [guest_iommu]
    'guest_iothreads' => '',    #TODO            #virt-install --iothreads [guest_iothreads]
    'guest_seclabel' => '',    # virt-install --seclabel [guest_seclabel]
    'guest_keywrap' => '',    #TODO            #virt-install --keywrap [guest_keywrap]
    'guest_cputune' => '',    #TODO            #virt-install --cputune [guest_cputune]
    'guest_memtune' => '',    # virt-install --memtune [guest_memtune]
    'guest_blkiotune' => '',    #TODO            #virt-install --blkiotune [guest_blkiotune]
    'guest_memorybacking' => '',    # virt-install --memorybacking [guest_memorybacking]
    'guest_features' => '',    #virt-install --features [guest_features]
    'guest_clock' => '',    #TODO            #virt-install --clock [guest_clock]
    'guest_power_management' => '',    #virt-install --pm [guest_power_management]
    'guest_events' => '',    #virt-install --events [guest_events]
    'guest_resource' => '',    #TODO            #virt-install --resource [guest_resource]
    'guest_qemu_command' => '',    #virt-install --qemu-commandline [guest_qemu_command]
    'guest_launchsecurity' => '',    # virt-install --launchSecurity [guest_launchsecurity]
    'guest_autostart' => '',    #TODO            #virt-install --[guest_autostart(autostart or empty)]
    'guest_transient' => '',    #TODO            #virt-install --[guest_transient(transient or empty)]
    'guest_destroy_on_exit' => '',    #TODO            #virt-install --[guest_destroy_on_exit(true or false)]
    'guest_autoconsole' => '',    #virt-install --autoconsole [guest_autoconsole(text or graphical or none)] or empty.
                                  #For virt-manager earlier than 3.0.0, this option does not exist and should be left empty.
    'guest_noautoconsole' => '',    #virt-install --noautoconsole if true.This option should only be given 'true', 'false' or empty.
    'guest_noreboot' => '',    #TODO            #virt-install --[guest_noreboot(true or false)]
    'guest_default_target' => '',    #This indicates whether guest os default target(multi-user, graphical or others), not virt-install argument.
                                     #The following parameters end with 'options' are derived from above parameters. They contains options and
                                     #corresponding values which are passed to virt-install command line directly to perform guest installations.
    'guest_do_registration' => '',    #This indicates whether guest to be registered or subscribed with content provider. Not virt-install argument.
                                      #It can be given 'true','false' or empty. Only 'true' means do registration/subscription.
    'guest_registration_server' => '',    #This is the address of registration/subscription server of content provider.
                                          #Not virt-install argument. It can be left empty if not needed.
    'guest_registration_username' => '',    #This is the username to be used in registration/subscription. Not virt-install argument.
                                            #It can be email address, free text or empty if not needed.
    'guest_registration_password' => '',    #This is the password to be used in registration/subscription. Not virt-install argument.
                                            #It is normally used together with [guest_registration_username] or empty if not needed.
    'guest_registration_code' => '',    #This is the code or key to used in registraiton/subscription. Not virt-install argument.
                                        #It can be used together with [guest_registration_username], standalone or empty if not needed.
                                        #Do not recommend to use the parameter in guest profile directly, use test suite setting UNIFIED_GUEST_REG_CODES.
    'guest_registration_extensions' => '',    #This refers to additional modules/extensions/products to be registered together with guest os or
                                              #by using individual registration/subscription code/key. Multiple modules/extensions/products are
                                              #separated by hash key. For example, "sle-module-legacy#sle-module-basesystem#SLES-LTSS".
                                              #Not virt-install argument. Can be left empty if not needed.
    'guest_registration_extensions_codes' => '',    #This refers to registration/subscription codes/keys to be used by modules/extensions/products in
        #[guest_registration_extensions]. Can be empty if not needed, but if anyone in [guest_registration_extensions] needs its own code/key, all the
        #others should also be given theirs even empty. For example, "sle-module-legacy#sle-module-basesystem#SLES-LTSS" needs "##SLES-LTSS-CODE-OR-KEY"
        #to be set in [guest_registration_extensions_codes]. And the codes/keys should be separated by hash key and put in the same order as their
        #corresponding modules/extensions/products in [guest_registration_extensions]. Not virt-install argument. Do not recommend to use the parameter
        #in guest profile directly, use test suite setting UNIFIED_GUEST_REG_EXTS_CODES.
    'guest_virt_options' => '',    #[guest_virt_options] = "--connect [host_hypervisor_uri] --virt-type [host_virt_type] --[guest_virt_type]"
    'guest_platform_options' => '',    #[guest_platform_options] = "--arch [guest_arch] --machine [guest_machine_type]"
    'guest_name_options' => '',    #[guest_name_options] = "--name [guest_name]"
    'guest_memory_options' => '',    # [guest_memory_options] = "--memory [guest_memory] --memballoon [guest_memballoon] --memdev [guest_memdev]
                                     # --memtune [guest_memtune] --memorybacking [guest_memorybacking]"
    'guest_vcpus_options' => '',    #[guest_vcpus_options] = "--vcpus [guest_vcpus]"
    'guest_cpumodel_options' => '',    #[guest_cpumodel_options] = "--cpu [guest_cpumodel]"
    'guest_metadata_options' => '',    #[guest_metadata_options] = "--metadata [guest_metadata]"
    'guest_xpath_options' => '',    #[guest_xpath_options] = [guest_xpath_options] . "--xml $_ " foreach ([@guest_xpath])
    'guest_installation_method_options' => '', #[guest_installation_method_options] = "--location [guest_installation_media] --install [guest_installation_fine_grained]
                                               #--autoconsole [guest_autoconsole] or --noautoconsole" or
                                               #"--[guest_installation_method] [guest_installation_media],[guest_installation_method_others]"
    'guest_installation_extra_args_options' => '', #[guest_installation_extra_args_options] = "[guest_installation_extra_args_options] . --extra-args $_ foreach
        #[@guest_installation_extra_args] --extra-args ip=[guest_ipaddr(if static)] [guest_installation_automation_options]"
    'guest_installation_automation_options' => '', #[guest_installation_automation_options] = "--extra-args [autoyast|inst.ks][ks]=[guest_installation_automation_file]"
    'guest_boot_options' => '',    #[guest_boot_options} = "--boot [guest_boot_settings]"
    'guest_os_variant_options' => '',    #[guest_os_variant_options] = "--os-variant [guest_os_variant]"
    'guest_storage_options' => '',    #[guest_storage_options] = "--disk path=[guest_storage_path],size=[guest_storage_size],
                                      #format=[guest_storage_format],[guest_storage_others]"
    'guest_network_selection_options' => '',    #[guest_network_selection_options] = "--network=bridge=[guest_network_device],mac=[guest_macaddr]",
                                                #or "--network=network=[guest_virtual_network],mac=[guest_macaddr],[guest_network_others]"
    'guest_sysinfo_options' => '',    #[guest_sysinfo_options] = "--sysinfo [guest_sysinfo]"
    'guest_graphics_and_video_options' => '',    #[guest_graphics_and_video_options] = "--video [guest_video] --graphics [guest_graphics]"
    'guest_serial_options' => '',    #[guest_serial_options] = "--serial [guest_serial]"
    'guest_console_options' => '',    #[guest_console_options] = "--console [guest_console]"
    'guest_features_options' => '',    #[guest_features_options] = "--features [guest_features]"
    'guest_power_management_options' => '',    #[guest_power_management_options] = "--pm [guest_power_management]"
    'guest_events_options' => '',    #[guest_events_options] = "--events [guest_events]"
    'guest_qemu_command_options' => '',    #[guest_qemu_command_options] = "--qemu-commandline [guest_qemu_command]"
    'guest_security_options' => '',    # [guest_security_options] = "--seclabel [guest_seclabel] --launchSecurity [guest_launchsecurity]"
    'guest_controller_options' => '',    # [guest_controller_options] = "--controller [guest_controller#1] --controller [guest_controller#2]"
    'guest_rng_options' => '',    # [guest_rng_options] = "--rng [guest_rng]"
    'virt_install_command_line' => '',    #This is the complete virt-install command line which is composed of above parameters end with 'options'
    'virt_install_command_line_dryrun' => '',    #This is [virt_install_command_line] appended with --dry-run
    'host_ipaddr' => '',    #This is get_required_var('SUT_IP')
    'host_name' => '',    #This is script_output('hostname')
    'host_domain_name' => '',    #This is script_output('dnsdomainname')
                                 #The following five parameters are detailed guest os information,not virt-install arguments
    'guest_log_folder' => '',    #Log folder for individual guest [common_log_folder]/[guest_name]
    'guest_installation_result' => '',    #PASSED,FAILED,TIMEOUT,UNKNOWN or others
    'guest_installation_session_config' => '',   #Absolute path of screen command config file that will be used in screen -c [guest_installation_session_config]
                                                 #to start guest installation session. The content of the config file includes content of global /etc/screenrc
                                                 #and logfile="absolute path of guest installation log file".
    'guest_installation_session' => '', #Guest installation process started by "screen -t [guest_name] [virt_install_command_line]. It is in the form of 3401.pts-1.vh017
    'guest_installation_session_command' => '', #If there is no [guest_installation_session] or [guest_installation_session] is terminated, start or re-connect to
        #guest installation screen using [guest_installation_session_command] = screen -t [guest_name] virsh console --force [guest_name]
    'guest_installation_attached' => '',    #This indicates whether guest installation screen is already connected or attached(true or false)
    'guest_netaddr_attached' => '',  #Array reference that stores the actual subnets in which guest may reside, for example, ('10.10.10.0/24', '11.11.11.0/24').
    'start_run' => '',    #Guest creation start time
    'stop_run' => ''    #Guest creation finish time
);

our $AUTOLOAD;
our $common_log_folder = '/var/log/guest_installation_and_configuration';
our $common_environment_prepared = 'false';

#Any subroutine calls this subroutine announces its identity and it is being executed
sub reveal_myself {
    my $self = shift;

    my $_my_identity = (caller(1))[3];
    diag("Test execution inside $_my_identity.");
    return $self;
}

#Create guest instance by assigning values to its parameters but do no install it
sub create {
    my $self = shift;

    $self->reveal_myself;
    $self->initialize_guest_params;
    $self->config_guest_params(@_);
    $self->print_guest_params;
    return $self;
}

#Initialize all guest parameters to avoid uninitialized parameters
sub initialize_guest_params {
    my $self = shift;

    $self->reveal_myself;
    $self->{$_} //= '' foreach (keys %guest_params);
    $self->{host_ipaddr} = get_required_var('SUT_IP');
    $self->{host_name} = script_output("hostname");
    # For SUTs with multiple interfaces, `dnsdomainname` sometimes does not work
    $self->{host_domain_name} = script_output("dnsdomainname", proceed_on_failure => 1);
    $self->{start_run} = time();
    return $self;
}

#Assign real values to guest instance parameters.Reset [guest_name] to guest name used in [guest_metadata] if they are different.
#The subroutine can be called mainly in two different ways:
#Firstly,config_guest_params can be called in another subroutine for example, create which takes a hash/dictionary as argument.
#my %testhash = ('key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3'),$self->create(%testhash) which calls $self->config_guest_params(@_).
#Secondly,config_guest_params can also be called direcly, for example,$self->config_guest_params(%testhash).
#Call revise_guest_version_and_build to correct guest version and build parameters to avoid mismatch if necessary.
sub config_guest_params {
    my $self = shift;
    my %_guest_params = @_;

    $self->reveal_myself;
    if ((scalar(@_) % 2 eq 0) and (scalar(@_) gt 0)) {
        record_info("Configuring guest instance by using following parameters:", Dumper(\%_guest_params));
        map { $self->{$_} = $_guest_params{$_} } keys %_guest_params;
    }
    else {
        record_info("Can not configure guest instance with empty or odd number of arguments.Mark it as failed.", Dumper(\%_guest_params));
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

#Correct [guest_version],[guest_version_major],[guest_version_minor] and [guest_build] if they are not set correctly or mismatch with each other.
#Set [guest_version] to the developing SLES version if it is not given. Set [guest_version_major] and [guest_version_minor] from [guest_version]
#it they do not match with [guest_version].
#Set [guest_build] to get_required_var('BUILD') if it is empty and developing [guest_version], or 'GM' if non-developing [guest_version].
#Replace all vm config values which refer to [guest_build] via "##guest_build##".
#This subroutine help make things better and life easier but the end user should always pay attention and use
#meaningful and correct guest parameter and profile.
sub revise_guest_version_and_build {
    my $self = shift;
    my %_guest_params = @_;

    $self->reveal_myself;
    if ($self->{guest_version} eq '') {
        $self->{guest_version} = (get_var('REPO_0_TO_INSTALL', '') eq '' ? lc get_required_var('VERSION') : lc get_required_var('TARGET_DEVELOPING_VERSION'));
        record_info("Guest $self->{guest_name} does not have guest_version set.Set it to test suite setting VERSION", "Please pay attention ! It is now $self->{guest_version}");
    }

    if ($self->{guest_os_name} =~ /sles|oraclelinux/im) {
        if (($self->{guest_version_major} eq '') or (!($self->{guest_version} =~ /^(r)?$self->{guest_version_major}(-(sp|u)?(\d*))?$/im))) {
            ($self->{guest_version_major}) = $self->{guest_version} =~ /(\d+)[-]?.*$/im;
            record_info("Guest $self->{guest_name} does not have guest_version_major set or it does not match with guest_version.Set it from guest_version", "Please pay attention ! It is now $self->{guest_version_major}");
        }
        if (($self->{guest_version_minor} eq '') or (!($self->{guest_version} =~ /^(r)?(\d+)-(sp|u)$self->{guest_version_minor}$/im))) {
            $self->{guest_version} =~ /^.*(sp|u)(\d+)$/im;
            $self->{guest_version_minor} = ($2 eq '' ? 0 : $2);
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

        # Replace all guest config values which refer to guest_build via ##guest_build##
        map { $self->{$_} =~ s/##guest_build##/$self->{guest_build}/g } keys %guest_params;

        record_info("Guest $self->{guest_name} does not have guest_build set.Set it to test suite setting BUILD or GM according to guest_version", "Please pay attention ! It is now $self->{guest_build}");
    }
    return $self;
}

#Print out guest instance parameters
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

#Install necessary packages, patterns, setup ssh config, create [common_log_folder].These are common environment affairs which will be used for all guest instances.
sub prepare_common_environment {
    my $self = shift;

    $self->reveal_myself;
    if ($common_environment_prepared eq 'false') {
        $self->clean_up_all_guests;
        disable_and_stop_service('named.service', ignore_failure => 1) unless version_utils::is_alp;
        script_run("rm -f -r $common_log_folder");
        assert_script_run("mkdir -p $common_log_folder");
        my @stuff_to_backup = ('/root/.ssh/config', '/etc/ssh/ssh_config', '/etc/hosts');
        virt_autotest::utils::backup_file(\@stuff_to_backup);
        script_run("rm -f -r /root/.ssh/config");
        virt_autotest::utils::setup_common_ssh_config('/root/.ssh/config');
        script_run("[ -f /etc/ssh/ssh_config ] && sed -i -r -n \'s/^.*IdentityFile.*\$/#&/\' /etc/ssh/ssh_config");
        enable_debug_logging;
        $self->prepare_non_transactional_environment;
        $common_environment_prepared = 'true';
        diag("Common environment preparation is done now.");
    }
    else {
        diag("Common environment preparation had already been done.");
    }
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
        virt_autotest::utils::setup_rsyslog_host($common_log_folder);
        my $_packages_to_check = 'wget curl screen dnsmasq xmlstarlet yast2-schema python3 nmap';
        zypper_call("install -y $_packages_to_check");
        # There is already the highest version for kvm/xen packages on TW
        if (is_sle) {
            my $_patterns_to_check = 'kvm_server kvm_tools';
            $_patterns_to_check = 'xen_server xen_tools' if ($self->{host_virt_type} eq 'xen');
            zypper_call("install -y -t pattern $_patterns_to_check");
        }
    }
    return $self;
}

#Remove all existing guests and affecting storage files
sub clean_up_all_guests {
    my $self = shift;

    $self->reveal_myself;
    my @_guests_to_clean_up = split(/\n/, script_output("virsh list --all --name | grep -v Domain-0", proceed_on_failure => 1));
    if (scalar(@_guests_to_clean_up) gt 0) {
        diag("Going to clean up all guests on $self->{host_name}");
        foreach (@_guests_to_clean_up) {
            script_run("virsh destroy $_");
            script_run("virsh undefine $_ --nvram") if (script_run("virsh undefine $_") ne 0);
        }
        save_screenshot;
        record_info("Cleaned all existing vms.");
    }
    else {
        diag("No guests reside on this host $self->{host_name}");
    }

    # With `import` installation method supported,
    # storage root path shoud not be cleaned, but to delete potential affecting storage files
    foreach my $_vm (split(/,/, get_required_var('UNIFIED_GUEST_LIST'))) {
        script_run("rm -f -r /var/lib/libvirt/images/${_vm}.*");
        script_run("rm -f -r $self->{guest_storage_path}/${_vm}.*") if ($self->{guest_storage_path} ne '');
    }
    save_screenshot;
    record_info("Cleaned all potential affecting disk files.");

    return $self;
}

#Create individual guest log folder using its name and remove existing entry in /etc/hosts
sub prepare_guest_environment {
    my $self = shift;

    $self->reveal_myself;
    $self->{guest_log_folder} = $common_log_folder . '/' . $self->{guest_name};
    script_run("rm -f -r $self->{guest_log_folder}");
    assert_script_run("mkdir -p $self->{guest_log_folder}");
    script_run("sed -i -r \'/^.*$self->{guest_name}.*\$/d\' /etc/hosts") unless version_utils::is_alp;
    return $self;
}

#Configure [guest_domain_name] and [guest_name_options].User can still change [guest_name] and [guest_domain_name] by passing non-empty arguments using hash.
sub config_guest_name {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_installation_result} eq '') {
        $self->{guest_domain_name} = 'testvirt.net' if ($self->{guest_domain_name} eq '');
        $self->{guest_domain_name} = $self->{host_domain_name} if ($self->{guest_netaddr} eq 'host-default');
        $self->{guest_name_options} = "--name $self->{guest_name}";
    }
    return $self;
}

#Configure [guest_metadata_options].User can still change [guest_metadata] by passing non-empty arguments using hash.
#If installation already passes,modify_guest_params will be called to modify [guest_metadata] using already modified [guest_metadata_options].
sub config_guest_metadata {
    my $self = shift;

    $self->reveal_myself;
    my $_current_metadata_options = $self->{guest_metadata_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_metadata} ne '') {
        $self->{guest_metadata_options} = "--metadata $self->{guest_metadata}";
        $self->modify_guest_params($self->{guest_name}, 'guest_metadata_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_metadata_options ne $self->{guest_metadata_options}));
    }
    return $self;
}

#Configure [guest_vcpus_options].User can still change [guest_vcpus] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_vcpus] using already modified [guest_vcpus_options].
sub config_guest_vcpus {
    my $self = shift;

    $self->reveal_myself;
    my $_current_vcpus_options = $self->{guest_vcpus_options};
    my $_current_cpumodel_options = $self->{guest_cpumodel_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_vcpus} = 2 if ($self->{guest_vcpus} eq '');
    $self->{guest_vcpus_options} = "--vcpus $self->{guest_vcpus}";
    $self->{guest_cpumodel_options} = "--cpu $self->{guest_cpumodel}" if ($self->{guest_cpumodel} ne '');
    $self->modify_guest_params($self->{guest_name}, 'guest_vcpus_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_vcpus_options ne $self->{guest_vcpus_options}));
    $self->modify_guest_params($self->{guest_name}, 'guest_cpumodel_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_cpumodel_options ne $self->{guest_cpumodel_options}));
    return $self;
}

=head2 config_guest_memory

  config_guest_memory($self [, guest_memory => 'memory'] [, guest_memballoon => 'memballoon']
  [, guest_memdev => 'memdev'] [, guest_memtune => 'memtune'] [, guest_memorybacking => 'memorybacking'])

Configure [guest_memory_options]. User can still change [guest_memory],[guest_memballoon],
[guest_memdev], [guest_memtune] and [guest_memorybacking] by passing non-empty arguments 
using hash. If installation already passes, modify_guest_params will be called to modify 
[guest_memory], [guest_memballoon], [guest_memdev], [guest_memtune] and [guest_memorybacking] 
using already modified [guest_memory_options].

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
    $self->modify_guest_params($self->{guest_name}, 'guest_memory_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_memory_options ne $self->{guest_memory_options}));
    return $self;
}

#Configure [guest_virt_options].User can still change [host_hypervisor_uri],[host_virt_type] and [guest_virt_options] by passing non-empty arguments using hash.
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

#Configure [guest_platform_options].User can still change [guest_arch] and [guest_machine_type] by passing non-empty arguments using hash.
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

#Configure [guest_os_variant_options].User can still change [guest_os_variant] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_os_variant] using already modified [guest_os_variant_options].
sub config_guest_os_variant {
    my $self = shift;

    $self->reveal_myself;
    my $_current_os_variant_options = $self->{guest_os_variant_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_os_variant} ne '') {
        $self->{guest_os_variant_options} = "--os-variant $self->{guest_os_variant}";
        $self->modify_guest_params($self->{guest_name}, 'guest_os_variant_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_os_variant_options ne $self->{guest_os_variant_options}));
    }
    return $self;
}

#Configure [guest_graphics_and_video_options].User can still change [guest_video] and [guest_graphics] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_video] and [guest_graphics] using already modified [guest_graphics_and_video_options].
sub config_guest_graphics_and_video {
    my $self = shift;

    $self->reveal_myself;
    my $_current_graphics_and_video_options = $self->{guest_graphics_and_video_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->{guest_graphics_and_video_options} = ($self->{guest_video} eq '' ? '' : "--video $self->{guest_video}");
    $self->{guest_graphics_and_video_options} = ($self->{guest_graphics} eq '' ? $self->{guest_graphics_and_video_options} : "$self->{guest_graphics_and_video_options} --graphics $self->{guest_graphics}");
    $self->modify_guest_params($self->{guest_name}, 'guest_graphics_and_video_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_graphics_and_video_options ne $self->{guest_graphics_and_video_options}));
    return $self;
}

#Configure [guest_console_options] and [guest_serial_options].User can still change [guest_console] and [guest_serial] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_console] and [guest_serial] using already modified [guest_console_options] and
#[guest_serial_options].
sub config_guest_consoles {
    my $self = shift;

    $self->reveal_myself;
    my $_current_console_options = $self->{guest_console_options};
    my $_current_serial_options = $self->{guest_serial_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_console} ne '') {
        $self->{guest_console_options} = "--console $self->{guest_console}";
        $self->modify_guest_params($self->{guest_name}, 'guest_console_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_console_options ne $self->{guest_console_options}));
    }
    if ($self->{guest_serial} ne '') {
        $self->{guest_serial_options} = "--serial $self->{guest_serial}";
        $self->modify_guest_params($self->{guest_name}, 'guest_serial_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_serial_options ne $self->{guest_serial_options}));
    }
    return $self;
}

#Configure [guest_features_options].User can still change [guest_features] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_features] using already modified [guest_features_options].
sub config_guest_features {
    my $self = shift;

    $self->reveal_myself;
    my $_current_features_options = $self->{guest_features_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_features} ne '') {
        $self->{guest_features_options} = "--features $self->{guest_features}";
        $self->modify_guest_params($self->{guest_name}, 'guest_features_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_features_options = $self->{guest_features_options}));
    }
    return $self;
}

#Configure [guest_events_options].User can still change [guest_events] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_events] using already modified [guest_events_options].
sub config_guest_events {
    my $self = shift;

    $self->reveal_myself;
    my $_current_events_options = $self->{guest_events_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_events} ne '') {
        $self->{guest_events_options} = "--events $self->{guest_events}";
        $self->modify_guest_params($self->{guest_name}, 'guest_events_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_events_options ne $self->{guest_events_options}));
    }
    return $self;
}

#Configure [guest_boot_options].User can still change [guest_boot_settings] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_boot_settings] using already modified [guest_boot_options].
sub config_guest_boot_settings {
    my $self = shift;

    $self->reveal_myself;
    my $_current_boot_options = $self->{guest_boot_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_boot_settings} ne '') {
        $self->{guest_boot_options} = "--boot $self->{guest_boot_settings}";
        $self->modify_guest_params($self->{guest_name}, 'guest_boot_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_boot_options ne $self->{guest_boot_options}));
    }
    return $self;
}

#Configure [guest_power_management_options].User can still change [guest_power_management] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_power_management] using already modified [guest_power_management_options].
sub config_guest_power_management {
    my $self = shift;

    $self->reveal_myself;
    my $_current_power_management_options = $self->{guest_power_management_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_power_management} ne '') {
        $self->{guest_power_management_options} = "--pm $self->{guest_power_management}";
        $self->modify_guest_params($self->{guest_name}, 'guest_power_management_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_power_management_options ne $self->{guest_power_management_options}));
    }
    return $self;
}

#Configure [guest_xpath_options].User can still change [guest_xpath] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_xpath] using already modified [guest_xpath_options].
sub config_guest_xpath {
    my $self = shift;

    $self->reveal_myself;
    my $_current_xpath_options = $self->{guest_xpath_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_xpath} ne '') {
        my @_guest_xpath = split(/#/, $self->{guest_xpath});
        $self->{guest_xpath_options} = $self->{guest_xpath_options} . "--xml $_ " foreach (@_guest_xpath);
        $self->modify_guest_params($self->{guest_name}, 'guest_xpath_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_xpath_options ne $self->{guest_xpath_options}));
    }
    return $self;
}

#Configure [guest_qemu_command_options].User can still change [guest_qemu_command] by passing non-empty arguments using hash.
#If installations already passes,modify_guest_params will be called to modify [guest_qemu_command] using already modified [guest_qemu_command_options].
sub config_guest_qemu_command {
    my $self = shift;

    $self->reveal_myself;
    my $_current_qemu_command_options = $self->{guest_qemu_command_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_qemu_command} ne '') {
        $self->{guest_qemu_command_options} = "--qemu-commandline $self->{guest_qemu_command}";
        $self->modify_guest_params($self->{guest_name}, 'guest_qemu_command_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_qemu_command_options ne $self->{guest_qemu_command_options}));
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
    $self->modify_guest_params($self->{guest_name}, 'guest_security_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_security_options ne $self->{guest_security_options}));
    return $self;
}

=head2 config_guest_controller

  config_guest_controller($self [, guest_controller => 'controller'])

Configure [guest_controller_options]. User can still change [guest_controller] by
passing non-empty arguments using hash. [guest_controller] can have more than one
type controller which should be separated by hash symbol, for example, "controller1
_config#controller2_config#controller3_config". Then it will be splitted and passed 
to individual "--controller" argument to form [guest_controller_options] = "--controller
controller1_config --controller controller2_config --controller controller3_config". 
If installation already passes, modify_guest_params will be called to modify
[guest_controller] using already modified [guest_controller_options].

=cut

sub config_guest_controller {
    my $self = shift;

    $self->reveal_myself;
    my $_current_controller_options = $self->{guest_controller_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_controller} ne '') {
        my @_guest_controller = split(/#/, $self->{guest_controller});
        $self->{guest_controller_options} = $self->{guest_controller_options} . "--controller $_ " foreach (@_guest_controller);
        $self->modify_guest_params($self->{guest_name}, 'guest_controller_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_controller_options ne $self->{guest_controller_options}));
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
    $self->modify_guest_params($self->{guest_name}, 'guest_rng_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_rng_options ne $self->{guest_rng_options}));
    return $self;
}

#Configure [guest_storage_options].User can still change [guest_storage_type],[guest_storage_size],[guest_storage_format],[guest_storage_label],[guest_storage_path]
#and [guest_storage_others] by passing non-empty arguments using hash.If installations already passes,modify_guest_params will be called to modify [guest_storage_type],
#[guest_storage_size],[guest_storage_format],[guest_storage_path] and [guest_storage_others] using already modified [guest_storage_options].
sub config_guest_storage {
    my $self = shift;

    $self->reveal_myself;
    my $_current_storage_options = $self->{guest_storage_options};
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_storage_type} eq 'disk') {
        $self->{guest_storage_size} = '16' if ($self->{guest_storage_size} eq '');
        $self->{guest_storage_format} = 'qcow2' if ($self->{guest_storage_format} eq '');
        $self->{guest_storage_label} = 'gpt' if ($self->{guest_storage_label} eq '');
        if ($self->{guest_storage_path} eq '') {
            $self->{guest_storage_path} = "/var/lib/libvirt/images/$self->{guest_name}.$self->{guest_storage_format}";
        }
        else {
            $self->{guest_storage_path} = "$self->{guest_storage_path}/$self->{guest_name}.$self->{guest_storage_format}";
        }
        $self->{guest_storage_options} = "--disk path=$self->{guest_storage_path},size=$self->{guest_storage_size},format=$self->{guest_storage_format}";
        $self->{guest_storage_options} = $self->{guest_storage_options} . ",$self->{guest_storage_others}" if ($self->{guest_storage_others} ne '');
    }
    $self->modify_guest_params($self->{guest_name}, 'guest_storage_options') if (($self->{guest_installation_result} eq 'PASSED') and ($_current_storage_options = $self->{guest_storage_options}));
    return $self;
}

#Configure [guest_network_selection_options].User can still change [guest_macaddr],[guest_network_type],[guest_network_device],[guest_ipaddr_static],[guest_ipaddr],[guest_netaddr],and [guest_virtual_network] by passing non-empty arguments using hash.
#If [guest_network_type] is `bridge`,
#    Set [guest_network_device] to br0 if it is not given and guest chooses to use host network.Set [guest_network_device]
#    to br123 and [guest_netaddr] to 192.168.123.255/24 if they are not given and guest does not choose to use host network.After enusre [guest_network_device] and [guest_netaddr]
#    have non-empty values, reset [guest_network_device] to already active host bridge device connected to host network if user chooses to use host network or intends to use a new
#    non-existed bridge deivce which is only created and configured to connect to host network if host does not have a active bridge device.Calls config_guest_macaddr to generate
#    guest mac address if it has not been set.Calls config_guest_network_bridge to create [guest_network_device] in subnet [guest_netaddr].Turn off firewall/apparmor,loosen iptables
#    rules and enable forwarding by calling config_guest_network_bridge_policy.
#
#If [guest_network_type] is `virtual_network`,
#    the [guest_virtual_network] should be created on host by users
#    before calling this guest installation automation.
#    It supports "--network=network=[guest_virtual_network],mac=[guest_macaddr],[guest_network_others]".
sub config_guest_network_selection {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->config_guest_macaddr if ($self->{guest_macaddr} eq '');
    if ($self->{guest_network_type} eq 'bridge') {
        if ($self->{guest_network_device} eq '') {
            if ($self->{guest_netaddr} eq 'host-default') {
                $self->{guest_network_device} = 'br0';
                record_info("Guest $self->{guest_name} has no given network bridge device although it is configured to use network bridge.", "Set network bridge device to $self->{guest_network_device} because guest chooses to use host network.");
            }
            elsif ($self->{guest_netaddr} eq '') {
                $self->{guest_network_device} = 'br123';
                $self->{guest_netaddr} = '192.168.123.255/24';
                record_info("Guest $self->{guest_name} has no given network bridge device and no given subnet although it is configured to use network bridge.", "Set network bridge device to $self->{guest_network_device} and subnet to $self->{guest_netaddr} because guest chooses to not use host network.");
            }
            else {
                $self->{guest_network_device} = 'br123';
                record_info("Guest $self->{guest_name} has no given network bridge device although it is configured to use network bridge.", "Set network bridge device to $self->{guest_network_device} because guest chooses to not use host network.");
            }
        }
        else {
            if ($self->{guest_netaddr} eq '') {
                $self->{guest_netaddr} = '192.168.123.255/24';
                record_info("Guest $self->{guest_name} has no given subnet although it is configured to use network bridge.", "Set subnet to $self->{guest_netaddr} because guest chooses to not use host network.");
            }
        }
        if ($self->{guest_netaddr} eq 'host-default') {
            my @_host_default_network_interfaces = split(/\n/, script_output("ip route show default | grep -i dhcp | awk \'{print \$5}\'"));
            if ((!(grep { $_ eq $self->{guest_network_device} } @_host_default_network_interfaces)) and ((first { $_ =~ /^br[0-9]+$/im } @_host_default_network_interfaces) ne '')) {
                $self->{guest_network_device} = first { $_ =~ /^br[0-9]+$/im } @_host_default_network_interfaces;
                record_info("Guest $self->{guest_name} chooses to use host network and host $self->{host_name} already has active bridge device $self->{guest_network_device} connected host network.", "Guest $self->{guest_name} will use $self->{guest_network_device} anyway.");
            }
            my @_host_nondefault_network_interfaces = split(/\n/, script_output("ip route show | grep -v default | awk \'{print \$3}\'"));
            if ((!(grep { $_ eq $self->{guest_network_device} } @_host_default_network_interfaces)) and (grep { $_ eq $self->{guest_network_device} } @_host_nondefault_network_interfaces)) {
                record_info("Guest $self->{guest_name} chooses to use host network but bridge device $self->{guest_network_device} has already been used for other purposes.Set it to br9", "Guest $self->{guest_name} will use br9 to be connected to host network anyway.");
                $self->{guest_network_device} = 'br9';
            }
        }
        record_info("Guest $self->{guest_name} has no given static ip address although it is configured to use static ip address.", "Please pay attention !") if (($self->{guest_ipaddr_static} eq 'true') and ($self->{guest_ipaddr} eq ''));
        $self->config_guest_network_bridge($self->{guest_network_device}, $self->{guest_netaddr}, $self->{guest_domain_name});
        $self->config_guest_network_bridge_policy($self->{guest_network_device});
        $self->{guest_network_selection_options} = "--network=bridge=$self->{guest_network_device},mac=$self->{guest_macaddr}";
    }
    elsif ($self->{guest_network_type} eq 'virtual_network') {
        record_info("Guest $self->{guest_name} has been configured to use virtual network $self->{guest_virtual_network}.", "Please ensure its existence on host(no virtual network setup in guest installation code)!");
        $self->{guest_network_selection_options} = "--network=network=$self->{guest_virtual_network}";
        $self->{guest_network_selection_options} .= ",mac=$self->{guest_macaddr}" if ($self->{guest_macaddr} ne '');
        $self->{guest_netaddr_attached} = [$self->{guest_netaddr}];
    }

    $self->{guest_network_selection_options} .= ",$self->{guest_network_others}" if ($self->{guest_network_others} ne '');

    return $self;
}

#Generate nearly random mac address
sub config_guest_macaddr {
    my $self = shift;

    $self->reveal_myself;
    my $_guest_macaddr_lower_half = join ":", map { unpack "H*", chr(rand(256)) } 1 .. 3;
    $self->{guest_macaddr} = ($self->{guest_netaddr} eq 'host-default' ? 'd4:c9:ef:' . $_guest_macaddr_lower_half : '52:54:00:' . $_guest_macaddr_lower_half);
    return $self;
}

#Calls virt_autotest::utils::parse_subnet_address_ipv4 to parse detailed subnet information from [guest_netaddr].Create [guest_network_device] with parsed detailed subnet
#information by calling config_guest_network_bridge_device.Start DHCP and DNS services with parsed detailed subnet information by calling config_guest_network_bridge_services.
#If [guest_netaddr] is equal to 'host-default',guest chooses to use host network which is public facing.So there is no need to do subnet address parsing.
sub config_guest_network_bridge {
    my ($self, $_guest_network_device, $_guest_network_address, $_guest_network_domain) = @_;

    $self->reveal_myself;
    $_guest_network_device //= '';
    $_guest_network_address //= '';
    $_guest_network_domain //= $self->{guest_domain_name};
    diag("This subroutine requires network device and network address as passed in arguments.") if (($_guest_network_device eq '') or ($_guest_network_address eq ''));
    if ($_guest_network_address ne 'host-default') {
        my ($_guest_network_ipaddr, $_guest_network_mask, $_guest_netwok_mask_len, $_guest_network_ipaddr_gw, $_guest_network_ipaddr_start, $_guest_network_ipaddr_end, $_guest_network_ipaddr_rev) = virt_autotest::utils::parse_subnet_address_ipv4($_guest_network_address);
        $self->config_guest_network_bridge_device("$_guest_network_ipaddr_gw/$_guest_netwok_mask_len", "$_guest_network_ipaddr/$_guest_netwok_mask_len", $_guest_network_device);
        $self->config_guest_network_bridge_services($_guest_network_device, $_guest_network_ipaddr_gw, $_guest_network_mask, $_guest_network_ipaddr_start, $_guest_network_ipaddr_end, $_guest_network_ipaddr_rev);
    }
    else {
        $self->config_guest_network_bridge_device("host-default", "host-default", $_guest_network_device);
    }
    return $self;
}

=head2 write_guest_network_bridge_device_config

  write_guest_network_bridge_device_config($self, _name => $_name [, 
  _ipaddr => $_ipaddr, _bootproto => $_bootproto, _startmode => $_startmode, 
  _zone => $_zone, _bridge_type => $_bridge_type, _bridge_ports => $_bridge_ports, 
  _bridge_stp => $_bridge_stp, _bridge_forwarddelay => $_bridge_forwarddelay])

Write network device settings to conventional /etc/sysconfig/network/ifcfg-* or 
/etc/NetworkManager/system-connections/*.nmconnection depends on whether system
network is managed by NetworkManager or not. The supported arguments are listed
out as below:
$_ipaddr: IP address/mask length pair of the interface
$_name: Identifier of the interface
$_bootproto: DHCP automatic or manual configuration, 'static', 'dhcp' or 'none'
$_startmode: Auto start up or connection: 'auto', 'manual' or 'off'
$_zone: The trust level of this network connection
$_bridge_type: 'master' or 'slave' to indicate master or slave interface
$_bridge_port: Specify interface's master or slave interface name
$_bridge_stp: 'on' or 'off' to turn stp on or off
$_bridge_forwarddelay: The stp forwarding delay in seconds
If $_ipaddr given is empty, it means there is no associated specific ip address 
to this interface which might be attached to another bridge interface or will not 
be assigned one ip address from dhcp, so set $_ipaddr to '0.0.0.0'.If $_ipaddr 
given is non-empty but not in ip address format,for example, 'host-default',it 
means the interface will not use a ip address from pre-defined subnet and will 
automically accept dhcp ip address from public facing host network.

=cut

sub write_guest_network_bridge_device_config {
    my ($self, %args) = @_;

    $self->reveal_myself;
    $args{_ipaddr} //= '0.0.0.0';
    $args{_name} //= '';
    $args{_bootproto} //= 'dhcp';
    $args{_startmode} //= 'auto';
    $args{_zone} //= '';
    $args{_bridge_type} //= 'master';
    $args{_bridge_port} //= '';
    $args{_bridge_stp} //= 'off';
    $args{_bridge_forwarddelay} //= '15';
    croak("Interface name must be given otherwise network bridge device config can not be generated.") if ($args{_name} eq '');

    $args{_ipaddr} = '0.0.0.0' if ($args{_ipaddr} eq '');
    $args{_ipaddr} = '' if (!($args{_ipaddr} =~ /\d+\.\d+\.\d+\.\d+/));
    if (is_networkmanager) {
        $self->write_guest_network_bridge_device_nmconnection(%args);
    }
    else {
        $self->write_guest_network_bridge_device_ifcfg(%args);
    }
    return $self;
}

=head2 write_guest_network_bridge_device_ifcfg

  write_guest_network_bridge_device_ifcfg($self, _name => $_name [, 
  _ipaddr => $_ipaddr, _name => $_name, _bootproto => $_bootproto, 
  _startmode => $_startmode, _zone => $_zone, _bridge_type => $_bridge_type, 
  _bridge_ports => $_bridge_ports, _bridge_stp => $_bridge_stp, 
  _bridge_forwarddelay => $_bridge_forwarddelay])

Write bridge device config file to /etc/sysconfig/network/ifcfg-*. Please refer 
to https://github.com/openSUSE/sysconfig/blob/master/config/ifcfg.template for 
config file content. 

=cut

sub write_guest_network_bridge_device_ifcfg {
    my ($self, %args) = @_;

    $self->reveal_myself;
    script_run("cp /etc/sysconfig/network/ifcfg-$args{_name} /etc/sysconfig/network/backup-ifcfg-$args{_name}");
    script_run("cp /etc/sysconfig/network/backup-ifcfg-$args{_name} $common_log_folder");
    my $_bridge_device_config_file = '/etc/sysconfig/network/ifcfg-' . $args{_name};
    my $_is_bridge = ($args{_bridge_type} eq 'master' ? 'yes' : 'no');
    type_string("cat > $_bridge_device_config_file <<EOF
IPADDR=\'$args{_ipaddr}\'
NAME=\'$args{_name}\'
BOOTPROTO=\'$args{_bootproto}\'
STARTMODE=\'$args{_startmode}\'
ZONE=\'$args{_zone}\'
BRIDGE=\'$_is_bridge\'
BRIDGE_PORTS=\'$args{_bridge_port}\'
BRIDGE_STP=\'$args{_bridge_stp}\'
BRIDGE_FORWARDDELAY=\'$args{_bridge_forwarddelay}\'
EOF
");
    script_run("cp $_bridge_device_config_file $common_log_folder");
    record_info("Network device $args{_name} config $_bridge_device_config_file", script_output("cat $_bridge_device_config_file", proceed_on_failure => 0));
    return $self;
}

=head2 write_guest_network_bridge_device_nmconnection
  
  write_guest_network_bridge_device_nmconnection($self, _name => $_name [, 
  _ipaddr => $_ipaddr, _name => $_name, _bootproto => $_bootproto, 
  _startmode => $_startmode, _zone => $_zone, _bridge_type => $_bridge_type, 
  _bridge_ports => $_bridge_ports, _bridge_stp => $_bridge_stp, 
  _bridge_forwarddelay => $_bridge_forwarddelay])

Write bridge device config file to /etc/NetworkManager/system-connections/*. NM
settings are a little bit different from ifcfg settings, but there are definite
mapping between them. So translation from well-known and default ifcfg settings
to NM settings is necessary. Please refer to nm-settings explanation as below:
https://developer-old.gnome.org/NetworkManager/stable/nm-settings-keyfile.html

=cut

sub write_guest_network_bridge_device_nmconnection {
    my ($self, %args) = @_;

    $self->reveal_myself;
    my $_configmethod = ($args{_bootproto} eq 'dhcp' ? 'auto' : 'manual');
    my $_autoconnect = ($args{_startmode} eq 'auto' ? 'true' : 'false');
    $args{_bridge_stp} = ($args{_bridge_stp} eq 'on' ? 'true' : 'false');
    script_run("cp /etc/NetworkManager/system-connections/$args{_name}.nmconnection /etc/NetworkManager/system-connections/backup-$args{_name}.nmconnection");
    script_run("cp /etc/NetworkManager/system-connections/backup-$args{_name}.nmconnection $common_log_folder");
    my $_bridge_device_config_file = '/etc/NetworkManager/system-connections/' . $args{_name} . ".nmconnection";

    if ($args{_bridge_type} eq 'master') {
        type_string("cat > $_bridge_device_config_file <<EOF
[connection]
autoconnect=$_autoconnect
id=$args{_name}
permissions=
interface-name=$args{_name}
type=bridge
zone=$args{_zone}
[ipv4]
method=$_configmethod
address1=$args{_ipaddr}
[bridge]
stp=$args{_bridge_stp}
forward-delay=$args{_bridge_forwarddelay}
EOF
");
    }
    elsif ($args{_bridge_type} eq 'slave') {
        my $_interfacetype = "";
        if (script_run("nmcli connection show $args{_name}") == 0) {
            $_interfacetype = script_output("nmcli connection show $args{_name} | grep connection.type | awk \'{print \$2}\'", proceed_on_failure => 0);
        }
        else {
            my $_interfacename = script_output("nmcli -f NAME,DEVICE connection show | grep $args{_name}", proceed_on_failure => 0);
            $_interfacename =~ s/\s*$args{_name}\s*$//;
            $_interfacetype = script_output("nmcli connection show \"$_interfacename\" | grep connection.type | awk \'{print \$2}\'", proceed_on_failure => 0);
        }
        type_string("cat > $_bridge_device_config_file <<EOF
[connection]
autoconnect=$_autoconnect
id=$args{_name}
permissions=
interface-name=$args{_name}
type=$_interfacetype
zone=$args{_zone}
slave-type=bridge
master=$args{_bridge_port}
[ipv4]
method=$_configmethod
address1=$args{_ipaddr}
EOF
");
    }
    script_run("chmod 700 $_bridge_device_config_file && cp $_bridge_device_config_file $common_log_folder");
    script_retry("nmcli connection load $_bridge_device_config_file", retry => 3, die => 0);
    record_info("Network device $args{_name} config $_bridge_device_config_file", script_output("cat $_bridge_device_config_file", proceed_on_failure => 0));
    return $self;
}

=head2 activate_guest_network_bridge_device

  activate_guest_network_bridge_device($self, _bridge_name => $_bridge_name)

Activate guest network bridge device by using wicked or NetworkManager depends on
system configuration. And also validate whether activation is successful or not.

=cut

sub activate_guest_network_bridge_device {
    my ($self, %args) = @_;

    $self->reveal_myself;
    $args{_host_device} //= '';
    $args{_bridge_device} //= '';
    croak("Bridge device name must be given otherwise activation can not be done.") if ($args{_bridge_device} eq '');
    my $_detect_active_route = '';
    my $_detect_inactive_route = '';
    if ($self->{guest_netaddr} ne 'host-default') {
        if (is_networkmanager) {
            script_retry("nmcli connection up $args{_bridge_device}", retry => 3, die => 0);
        }
        else {
            my $_bridge_device_config_file = '/etc/sysconfig/network/ifcfg-' . $args{_bridge_device};
            if (is_opensuse) {
                # NIC in openSUSE TW guest is unable to get the IP from its network configration file with 'wicked ifup' or 'ifup'
                # Not sure if it is a bug yet. This is just a temporary solution.
                my $_bridge_ipaddr = script_output("grep IPADDR $_bridge_device_config_file | cut -d \"'\" -f2");
                script_retry("ip link add $args{_bridge_device} type bridge; ip addr flush dev $args{_bridge_device}", retry => 3, die => 0);
                script_retry("ip addr add $_bridge_ipaddr dev $args{_bridge_device} && ip link set $args{_bridge_device} up", retry => 3, die => 0);
            }
            else {
                script_retry("wicked ifup $_bridge_device_config_file $args{_bridge_device}", retry => 3, die => 0);
            }
        }
        $_detect_active_route = script_output("ip route show | grep -i $args{_bridge_device}", proceed_on_failure => 1);
    }
    else {
        if (is_networkmanager) {
            script_retry("nmcli connection up $args{_bridge_device}", timeout => 60, delay => 15, retry => 3, die => 0);
            script_retry("nmcli connection up $args{_host_device}", timeout => 60, delay => 15, retry => 3, die => 0);
        }
        else {
            script_retry("systemctl restart network", timeout => 60, delay => 15, retry => 3, die => 0);
        }
        type_string("reset\n");
        select_console('root-ssh') if (!(check_screen('text-logged-in-root')));
        $_detect_active_route = script_output("ip route show default | grep -i $args{_bridge_device}", proceed_on_failure => 1);
        $_detect_inactive_route = script_output("ip route show default | grep -i $args{_host_device}", proceed_on_failure => 1);
    }

    if (($_detect_active_route ne '') and ($_detect_inactive_route eq '')) {
        record_info("Successfully setup bridge device $self->{guest_network_device} to be used by $self->{guest_name}.", script_output("ip addr show;ip route show"));
    }
    else {
        record_info("Failed to setup bridge device $self->{guest_network_device} to be used by $self->{guest_name}.Mark guest $self->{guest_name} installation as FAILED", script_output("ip addr show;ip route show"));
        $self->record_guest_installation_result('FAILED');
    }
    return $self;
}

#Create [guest_network_device] by writing device information into ifcfg file in /etc/sysconfig/network.Mark guest installation as FAILED if [guest_network_device] can not be
#successfully started up.If [guest_network_device] or [guest_netaddr] already exists and active on host judging by "ip route show",both of them will not be created anyway.
sub config_guest_network_bridge_device {
    my $self = shift;

    $self->reveal_myself;
    my $_bridge_network = shift;
    my $_bridge_network_in_route = shift;
    my $_bridge_device = shift;
    $_bridge_device //= $self->{guest_network_device};
    unless ((script_run("ip route show | grep -o $_bridge_device") == 0) or (script_run("ip route show | grep -o $_bridge_network_in_route") == 0)) {
        my $_detect_active_route = '';
        my $_detect_inactive_route = '';
        if ($self->{guest_netaddr} ne 'host-default') {
            $self->write_guest_network_bridge_device_config(_ipaddr => $_bridge_network, _name => $_bridge_device, _bootproto => 'static', _bridge_type => 'master');
            $self->activate_guest_network_bridge_device(_bridge_device => $_bridge_device);
        }
        else {
            my $_host_default_network_interface = script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+ | head -1 | awk \'{print \$5}\'");
            $self->write_guest_network_bridge_device_config(_ipaddr => $_bridge_network, _name => $_bridge_device, _bootproto => 'dhcp', _bridge_type => 'master', _bridge_port => $_host_default_network_interface);
            $self->write_guest_network_bridge_device_config(_ipaddr => '', _name => $_host_default_network_interface, _bootproto => 'none', _bridge_type => 'slave', _bridge_port => $_bridge_device);
            $self->activate_guest_network_bridge_device(_host_device => $_host_default_network_interface, _bridge_device => $_bridge_device);
        }
    }
    else {
        record_info("Guest $self->{guest_name} uses bridge device $_bridge_device or subnet $_bridge_network_in_route which had already been configured and active", script_output("ip addr show;ip route show all"));
    }
    $self->{guest_netaddr_attached} = [split(/\n/, script_output("ip route show all | grep -v default | grep -i $_bridge_device | awk \'{print \$1}\'", proceed_on_failure => 1))];
    return $self;
}

#Start DHCP and DNS services by using dnsmasq command line.Add parsed subnet gateway ip address and [guest_domain_name] into /etc/resolv.conf.Empty NETCONFIG_DNS_POLICY in
#/etc/sysconfig/network/config.Mark guest installation as FAILED if dnsmasq command line can not be successfully fired up.Additionally, write dnsmasq command line used into
#crontab to start DHCP and DNS services automatically on reboot if host reboots somehow unexpectedly.
sub config_guest_network_bridge_services {
    my ($self, $_guest_network_device, $_guest_network_ipaddr_gw, $_guest_network_mask, $_guest_network_ipaddr_start, $_guest_network_ipaddr_end, $_guest_network_ipaddr_rev) = @_;

    $self->reveal_myself;
    my $_detect_signature = script_output("cat /etc/sysconfig/network/config | grep \"#Modified by guest_installation_and_configuration_base module\"", proceed_on_failure => 1);
    if (!($_detect_signature =~ /#Modified by guest_installation_and_configuration_base module/im)) {
        assert_script_run("cp /etc/sysconfig/network/config /etc/sysconfig/network/config_backup");
        assert_script_run("sed -ri \'s/^NETCONFIG_DNS_POLICY.*\$/NETCONFIG_DNS_POLICY=\"\"/g\' /etc/sysconfig/network/config");
        assert_script_run("echo \'#Modified by guest_installation_and_configuration_base module\' >> /etc/sysconfig/network/config");
    }
    record_info("Content of /etc/sysconfig/network/config", script_output("cat /etc/sysconfig/network/config", proceed_on_failure => 1));

    $_detect_signature = script_output("cat /etc/resolv.conf | grep \"#Modified by guest_installation_and_configuration_base module\"", proceed_on_failure => 1);
    my $_detect_name_server = script_output("cat /etc/resolv.conf | grep \"nameserver $_guest_network_ipaddr_gw\"", proceed_on_failure => 1);
    my $_detect_domain_name = script_output("cat /etc/resolv.conf | grep $self->{guest_domain_name}", proceed_on_failure => 1);
    assert_script_run("awk -v dnsvar=$_guest_network_ipaddr_gw \'done != 1 && /^nameserver.*\$/ { print \"nameserver \"dnsvar\"\"; done=1 } 1\' /etc/resolv.conf > /etc/resolv.conf.tmp") if ($_detect_name_server eq '');
    assert_script_run("sed -i -r \'/^search/ s/\$/ $self->{guest_domain_name}/\' /etc/resolv.conf.tmp") if ($_detect_domain_name eq '');
    if ($_detect_signature eq '') {
        assert_script_run("cp /etc/resolv.conf /etc/resolv_backup.conf && mv /etc/resolv.conf.tmp /etc/resolv.conf");
        assert_script_run("echo \'#Modified by guest_installation_and_configuration_base module\' >> /etc/resolv.conf");
    }
    record_info("Content of /etc/resolv.conf", script_output("cat /etc/resolv.conf", proceed_on_failure => 1));

    my $_guest_network_ipaddr_gw_transformed = $_guest_network_ipaddr_gw;
    $_guest_network_ipaddr_gw_transformed =~ s/\./_/g;
    my $_dnsmasq_log = "$common_log_folder/dnsmasq_listen_address_$_guest_network_ipaddr_gw_transformed" . '_log';
    my $_dnsmasq_command = "/usr/sbin/dnsmasq --bind-dynamic --listen-address=$_guest_network_ipaddr_gw --bogus-priv --domain-needed --expand-hosts "
      . "--dhcp-range=$_guest_network_ipaddr_start,$_guest_network_ipaddr_end,$_guest_network_mask,8h --interface=$_guest_network_device "
      . "--dhcp-authoritative --no-negcache --dhcp-option=option:router,$_guest_network_ipaddr_gw --log-queries --local=/$self->{guest_domain_name}/ "
      . "--domain=$self->{guest_domain_name} --log-dhcp --dhcp-fqdn --dhcp-sequential-ip --dhcp-client-update --dns-loop-detect --no-daemon "
      . "--server=/$self->{guest_domain_name}/$_guest_network_ipaddr_gw --server=/$_guest_network_ipaddr_rev/$_guest_network_ipaddr_gw";
    my $_retry_counter = 5;
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    while (($_retry_counter gt 0) and (script_output("ps ax | grep -i \"$_dnsmasq_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '')) {
        script_run("((nohup $_dnsmasq_command  &>$_dnsmasq_log) &)");
        save_screenshot;
        send_key('ret');
        save_screenshot;
        $_retry_counter--;
    }
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    if (script_output("ps ax | grep -i \"$_dnsmasq_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '') {
        record_info("DHCP and DNS services can not start.Mark guest $self->{guest_name} installation as FAILED", "The command used is ((nohup $_dnsmasq_command  &>$_dnsmasq_log) &)");
        $self->record_guest_installation_result('FAILED');
    }
    else {
        record_info("DHCP and DNS services had already been running on $self->{guest_network_device} which is ready for use", "The command used is ((nohup $_dnsmasq_command  &>$_dnsmasq_log) &)");
        $self->schedule_tasks_on_boot(_task => "(nohup $_dnsmasq_command  &>$_dnsmasq_log) &");
    }
    return $self;
}

#Stop firewall/apparmor,loosen iptables rules and enable forwarding globally and on all default route devices and [guest_network_device].
#Additionally,write commands executed into crontab to re-execute them automatically on reboot if host reboots somehow unexpectedly.
sub config_guest_network_bridge_policy {
    my ($self, $_guest_network_device) = @_;

    $self->reveal_myself;
    my @_default_route_devices = split(/\n/, script_output("ip route show default | grep -i dhcp | awk \'{print \$5}\'", proceed_on_failure => 0));
    my $_iptables_default_route_devices = '';
    $_iptables_default_route_devices = "iptables --table nat --append POSTROUTING --out-interface $_ -j MASQUERADE\n" . $_iptables_default_route_devices foreach (@_default_route_devices);
    my $_network_policy_config_file = "$common_log_folder/network_policy_bridge_device_" . $_guest_network_device . "_default_route_device";
    $_network_policy_config_file = $_network_policy_config_file . '_' . $_ foreach (@_default_route_devices);
    $_network_policy_config_file = $_network_policy_config_file . '.sh';
    type_string("cat > $_network_policy_config_file <<EOF
#!/bin/bash
HOME=/root
LOGNAME=root
PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin
LANG=POSIX
SHELL=/bin/bash
PWD=/root
iptables-save > $self->{guest_log_folder}/iptables_before_modification_by_$self->{guest_name}
systemctl stop SuSEFirewall2
systemctl disable SuSEFirewall2
systemctl stop firewalld
systemctl disable firewalld
systemctl stop apparmor
systemctl disable apparmor
sed -i -r \'s/^SELINUX=.*\$/SELINUX=disabled/g\' /etc/selinux/config
systemctl stop named
systemctl disable named
systemctl stop dhcpd
systemctl disable dhcpd
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -F
iptables -X
$_iptables_default_route_devices
iptables --append FORWARD --in-interface $_guest_network_device -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv6.conf.all.forwarding=1
iptables-save > $self->{guest_log_folder}/iptables_after_modification_by_$self->{guest_name}
EOF
");
    assert_script_run("chmod 777 $_network_policy_config_file");
    record_info("Network policy config file", script_output("cat $_network_policy_config_file", proceed_on_failure => 0));
    script_run("$_network_policy_config_file", timeout => 60);
    $self->schedule_tasks_on_boot(_task => "$_network_policy_config_file");
    return $self;
}

=head2 schedule_tasks_on_boot

  schedule_tasks_on_boot($self, _task => $task)

Schedule tasks to be executed on system boot up, please refer to these documents:
https://docs.oracle.com/en/learn/oracle-linux-crontab/ for using crontab utility
and https://linuxconfig.org/how-to-schedule-tasks-with-systemd-timers-in-linux for 
for using systemd service and timer. In order to schedule a task successfully, the
_task argument should not be empty.

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

  schedule_tasks_on_boot_crontab($self, _task => $task)

Schedule tasks on system boot up by using crontab utility.

=cut

sub schedule_tasks_on_boot_crontab {
    my ($self, %args) = @_;

    $self->reveal_myself;
    $args{_task} = "($args{_task})" if $args{_task} =~ /\s*&\s*$/;
    if (script_output("cat $common_log_folder/root_cron_job | grep -i \"$args{_task}\"", proceed_on_failure => 1) eq '') {
        type_string("cat >> $common_log_folder/root_cron_job <<EOF
\@reboot $args{_task}
EOF
");
        script_run("crontab $common_log_folder/root_cron_job;crontab -l");
    }
    return $self;
}



=head2 schedule_tasks_on_boot_systemd

  schedule_tasks_on_boot_systemd($self, _task => $task)

Schedule tasks on system boot up by using systemd service and timer.

=cut

sub schedule_tasks_on_boot_systemd {
    my ($self, %args) = @_;

    $self->reveal_myself;
    $args{_task} =~ s/\s*&\s*$//;
    my $_systemd_unit_path = "/etc/systemd/system";
    my $_systemd_unit_name = "stubnetwork";
    if (script_output("cat $common_log_folder/root_systemd_job | grep -i \"$args{_task}\"", proceed_on_failure => 1) eq '') {
        assert_script_run("echo -e \"$args{_task}\\n\$(cat $common_log_folder/root_systemd_job)\" > $common_log_folder/root_systemd_job");
        assert_script_run("chmod 755 $common_log_folder/root_systemd_job");
        if (script_output("systemctl list-timers | grep $_systemd_unit_name", proceed_on_failure => 1) eq '') {
            type_string("cat > $_systemd_unit_path/$_systemd_unit_name.service <<EOF
[Unit]
Description=Bridge DHCP and DNS Services without Blockage

[Service]
Type=oneshot
ExecStart=/bin/bash $common_log_folder/root_systemd_job
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
            script_run("cp $_systemd_unit_path/$_systemd_unit_name* $common_log_folder");
        }
        disable_and_stop_service("$_systemd_unit_name.timer", ignore_failure => 1);
        systemctl("enable $_systemd_unit_name.timer", ignore_failure => 1);
        systemctl("status $_systemd_unit_name.timer", ignore_failure => 1);
    }
    return $self;
}


#Configure [guest_installation_method_options].User can still change [guest_installation_method],[guest_installation_media],[guest_build],[guest_version],[guest_version_major],
#[guest_version_minor],[guest_installation_fine_grained] and [guest_autoconsole] by passing non-empty arguments using hash.Call config_guest_installation_media to set correct
#installation media.
sub config_guest_installation_method {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);

    if ($self->{guest_installation_method} eq 'import') {
        $self->{guest_installation_method_options} = "--import ";
    }
    else {
        if ($self->{guest_installation_method} eq 'location') {
            $self->config_guest_installation_media;
            $self->{guest_installation_method_options} = "--location $self->{guest_installation_media}";
        }
        $self->{guest_installation_method_options} = $self->{guest_installation_method_options} . ($self->{guest_installation_method_others} ne '' ? ",$self->{guest_installation_method_others}" : '') if ($self->{guest_installation_method_others} ne '');
        $self->{guest_installation_method_options} = $self->{guest_installation_method_options} . ($self->{guest_installation_fine_grained} ne '' ? " --install $self->{guest_installation_fine_grained}" : '') if ($self->{guest_installation_fine_grained} ne '');
    }

    $self->{guest_installation_method_options} = $self->{guest_installation_method_options} . " --autoconsole $self->{guest_autoconsole}" if ($self->{guest_autoconsole} ne '');
    $self->{guest_installation_method_options} = $self->{guest_installation_method_options} . " --noautoconsole" if ($self->{guest_noautoconsole} eq 'true');
    return $self;
}

#Set [guest_installation_media] to the current major and minor version if it does not match with [guest_version].This subroutine also help mount nfs share if guest chooses to
#or has to use iso installation media, for example oracle linux guest uses iso installation media from https://yum.oracle.com/oracle-linux-isos.html. Although this subroutine
#can help correct installation media major and minor version if necessary, it is just auxiliary functionality and end user should always pay attendtion and use the meaningful
#and correct guest parameters and profile.
sub config_guest_installation_media {
    my $self = shift;

    $self->reveal_myself;
    $self->{guest_installation_media} =~ s/12345/$self->{guest_build}/g if ($self->{guest_build} ne 'gm');
#This is just auxiliary functionality to help correct and set correct installation media major and minor version if it mismatches with guest_version.It is not mandatory
  #necessary and can be skipped without causing any issue.The end user should always pay attention and use meaningful and correct guest parameters and profiles.
    if ($self->{guest_os_name} =~ /sles|oraclelinux/im) {
        if (!($self->{guest_installation_media} =~ /-$self->{guest_version}-/im)) {
            record_info("Guest $self->{guest_name} installation media $self->{guest_installation_media} does not match with version $self->{guest_version}", "Going to correct it !");
            my $_guest_version_major_indicator = ($self->{guest_os_name} =~ /sles/im ? '' : 'R');
            my $_guest_version_minor_indicator = ($self->{guest_os_name} =~ /sles/im ? 'SP' : 'U');
            $self->{guest_installation_media} =~ /-((r)?(\d*))-((sp|u)?(\d*))?/im;
            if ($self->{guest_version_minor} ne 0) {
                if ($4 ne '') {
                    $self->{guest_installation_media} =~ s/-$1-$4/-${_guest_version_major_indicator}$self->{guest_version_major}-${_guest_version_minor_indicator}$self->{guest_version_minor}/im;
                }
                else {
                    $self->{guest_installation_media} =~ s/-$1/-${_guest_version_major_indicator}$self->{guest_version_major}-${_guest_version_minor_indicator}$self->{guest_version_minor}/im;
                }
            }
            else {
                if ($4 ne '') {
                    $self->{guest_installation_media} =~ s/-$1-$4/-${_guest_version_major_indicator}$self->{guest_version_major}/im;
                }
                else {
                    $self->{guest_installation_media} =~ s/-$1/-${_guest_version_major_indicator}$self->{guest_version_major}/im;
                }
            }
        }
    }

#If guest chooses to use iso installation media, then this iso media should be available on INSTALLATION_MEDIA_NFS_SHARE and mounted locally at INSTALLATION_MEDIA_LOCAL_SHARE.
    if ($self->{guest_installation_media} =~ /^.*\.iso$/im) {
        my $_installation_media_nfs_share = get_var('INSTALLATION_MEDIA_NFS_SHARE', '');
        my $_installation_media_local_share = get_var('INSTALLATION_MEDIA_LOCAL_SHARE', '');
        if (($_installation_media_nfs_share eq '') or (($_installation_media_local_share eq '') or ($_installation_media_local_share =~ /^$common_log_folder.*$/im))) {
            record_info("Can not mount iso installation media $self->{guest_installation_media}", "Installation media nfs share is not provided or installation media local share should not be empty or the common log folder $common_log_folder or any subfolders in $common_log_folder.Mark guest $self->{guest_name} installation as FAILED !");
            $self->record_guest_installation_result('FAILED');
            return $self;
        }
        if (script_run("ls $_installation_media_local_share/$self->{guest_installation_media}") ne 0) {
            script_run("umount $_installation_media_local_share || umount -f -l $_installation_media_local_share");
            script_run("rm -f -r $_installation_media_local_share");
            assert_script_run("mkdir -p $_installation_media_local_share");
            if (script_retry("mount -t nfs $_installation_media_nfs_share $_installation_media_local_share ", timeout => 60, delay => 15, retry => 3, die => 0) ne 0) {
                record_info("The installation media nfs share $_installation_media_nfs_share can not be mounted as local $_installation_media_local_share.", "Guest $self->{guest_name} installation can not proceed.Mark it as FAILED !");
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
    record_info("Guest $self->{guest_name} is going to use installation media $self->{guest_installation_media}", "Please check it out !");
    return $self;
}

#Configure [guest_installation_extra_args_options].User can still change [guest_installation_extra_args],[guest_ipaddr] and [guest_ipaddr_static] by passing non-empty arguments using hash.
sub config_guest_installation_extra_args {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    if ($self->{guest_installation_extra_args} ne '') {
        my @_guest_installation_extra_args = split(/#/, $self->{guest_installation_extra_args});
        $self->{guest_installation_extra_args_options} = $self->{guest_installation_extra_args_options} . "--extra-args \"$_\" " foreach (@_guest_installation_extra_args);
        $self->{guest_installation_extra_args_options} = $self->{guest_installation_extra_args_options} . "--extra-args \"ip=$self->{guest_ipaddr}\"" if (($self->{guest_ipaddr_static} eq 'true') and ($self->{guest_ipaddr} ne ''));
    }

    if (is_transactional and $self->{guest_os_name} eq 'slem') {
        record_soft_failure("bsc#1202405 - SLE Micro 5.3 media can not be successfully loaded automatically for virtual machine installation");
        $self->{guest_installation_extra_args_options} = $self->{guest_installation_extra_args_options} . " --extra-args \"install=$self->{guest_installation_media}\"";
    }

    if (($self->{guest_installation_automation} ne '') and ($self->{guest_installation_automation_file} ne '')) {
        $self->config_guest_installation_automation;
        $self->{guest_installation_extra_args_options} = "$self->{guest_installation_extra_args_options} $self->{guest_installation_automation_options}" if ($self->{guest_installation_automation_options} ne '');
    }
    else {
        record_info("Skip installation automation configuration for guest $self->{guest_name}", "It has no guest_installation_automation or no guest_installation_automation_file configured.Skip config_guest_installation_automation.");
    }

    return $self;
}

#Configure [guest_installation_automation_options].User can still change [guest_installation_automation],[guest_installation_automation_file],[guest_os_name],[guest_version_major],
#[host_virt_type],[guest_virt_type],[guest_default_target] and [guest_arch] by passing non-empty arguments using hash.Fill in unattended installation file with [guest_installation_media],
#[guest_secure_boot],[guest_boot_settings],[guest_storage_label],[guest_domain_name],[guest_name] and host public rsa key.User can also change [guest_do_registration],[guest_registration_server],
#[guest_registration_username],[guest_registration_password],[guest_registration_code],[guest_registration_extensions] and [guest_registration_extensions_codes] which are used in configuring
#guest installation automation registration.Subroutine config_guest_installation_automation_registration is called to perform this task.Start HTTP server using python3 modules in unattended
#automation file folder to serve unattended guest installation.Mark guest installation as FAILED if HTTP server can not be started up or unattended installation file is not accessible.
#Common varaibles are used in guest unattended installation file and to be replaced with actual values.They are common variables that are relevant to guest itself or its attributes,
#so they can be used in any unattended installation files regardless of autoyast or kickstart or others.For example, if you want to set guest ethernet interface mac address somewhere
#in your customized unattended installation file, put ##Device-MacAddr## there then it will be replaced with the real mac address.The actual kind of automation used matters less here
#than variables used in the unattended installation file, so keep using standardized common varialbes in unattened installation file will make it come alive automatically regardless of
#the actual kind of automation being used.
#Currently the following common variables are supported:[Module-Basesystem,Module-Desktop-Applications,Module-Development-Tools,Module-Legacy,Module-Server-Applications,Module-Web-Scripting,
#Product-SLES,Authorized-Keys,Secure-Boot,Boot-Loader-Type,Disk-Label,Domain-Name,Host-Name,Device-MacAddr,Logging-HostName,Logging-HostPort,Do-Registration,Registration-Server,Registration-UserName,
#Registration-Password and Registration-Code]
sub config_guest_installation_automation {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    diag("Guest $self->{guest_name} is going to use unattended installation file $self->{guest_installation_automation_file}.");
    assert_script_run("curl -s -o $common_log_folder/unattended_installation_$self->{guest_name}_$self->{guest_installation_automation_file} " . data_url("virt_autotest/guest_unattended_installation_files/$self->{guest_installation_automation_file}"));
    $self->{guest_installation_automation_file} = "$common_log_folder/unattended_installation_$self->{guest_name}_$self->{guest_installation_automation_file}";
    assert_script_run("chmod 777  $self->{guest_installation_automation_file}");
    if (($self->{guest_version_major} ge 15) and ($self->{guest_os_name} =~ /sles/im)) {
        my @_guest_installation_media_extensions = ('Module-Basesystem', 'Module-Desktop-Applications', 'Module-Development-Tools', 'Module-Legacy', 'Module-Server-Applications', 'Module-Web-Scripting', 'Product-SLES');
        my $_guest_installation_media_extension_url = '';
        foreach (@_guest_installation_media_extensions) {
            $_guest_installation_media_extension_url = "$self->{guest_installation_media}/$_";
            $_guest_installation_media_extension_url =~ s/\//PLACEHOLDER/img;
            assert_script_run("sed -ri \'s/##$_##/$_guest_installation_media_extension_url/g;\' $self->{guest_installation_automation_file}");
        }
        assert_script_run("sed -ri \'s/PLACEHOLDER/\\\//g;\' $self->{guest_installation_automation_file}");
    }

    if (!((script_run("[[ -f /root/.ssh/id_rsa.pub ]] && [[ -f /root/.ssh/id_rsa.pub.bak ]]") eq 0) and (script_run("cmp /root/.ssh/id_rsa.pub /root/.ssh/id_rsa.pub.bak") eq 0))) {
        assert_script_run("rm -f -r /root/.ssh/id_rsa*");
        assert_script_run("ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P \"\" <<<y");
        assert_script_run("cp /root/.ssh/id_rsa.pub /root/.ssh/id_rsa.pub.bak");
    }
    my $_authorized_key = script_output("cat /root/.ssh/id_rsa.pub", proceed_on_failure => 0);
    $_authorized_key =~ s/\//PLACEHOLDER/img;
    assert_script_run("sed -ri \'s/##Authorized-Keys##/$_authorized_key/g;\' $self->{guest_installation_automation_file}");
    assert_script_run("sed -ri \'s/PLACEHOLDER/\\\//g;\' $self->{guest_installation_automation_file}");
    if ($self->{guest_secure_boot} ne '') {
        assert_script_run("sed -ri \'s/##Secure-Boot##/$self->{guest_secure_boot}/g;\' $self->{guest_installation_automation_file}");
    }
    else {
        assert_script_run("sed -ri \'/##Secure-Boot##/d;\' $self->{guest_installation_automation_file}");
    }
    my $_boot_loader = ($self->{guest_boot_settings} =~ /uefi|ovmf/im ? 'grub2-efi' : 'grub2');
    assert_script_run("sed -ri \'s/##Boot-Loader-Type##/$_boot_loader/g;\' $self->{guest_installation_automation_file}");
    my $_disk_label = ($self->{guest_storage_label} eq 'gpt' ? 'gpt' : 'msdos');
    assert_script_run("sed -ri \'s/##Disk-Label##/$_disk_label/g;\' $self->{guest_installation_automation_file}");
    assert_script_run("sed -ri \'s/##Domain-Name##/$self->{guest_domain_name}/g;\' $self->{guest_installation_automation_file}");
    assert_script_run("sed -ri \'s/##Host-Name##/$self->{guest_name}/g;\' $self->{guest_installation_automation_file}");
    assert_script_run("sed -ri \'s/##Device-MacAddr##/$self->{guest_macaddr}/g;\' $self->{guest_installation_automation_file}");
    assert_script_run("sed -ri \'s/##Logging-HostName##/$self->{host_name}.$self->{host_domain_name}/g;\' $self->{guest_installation_automation_file}");
    assert_script_run("sed -ri \'s/##Logging-HostPort##/514/g;\' $self->{guest_installation_automation_file}");
    $self->config_guest_installation_automation_registration;
    $self->validate_guest_installation_automation_file;

    my $_http_server_command = "python3 -m http.server 8666 --bind $self->{host_ipaddr}";
    my $_retry_counter = 5;
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    while (($_retry_counter gt 0) and (script_output("ps ax | grep -i \"$_http_server_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '')) {
        script_run("cd $common_log_folder && ((nohup $_http_server_command &>$common_log_folder/http_server_log) &) && cd ~");
        save_screenshot;
        send_key("ret");
        save_screenshot;
        $_retry_counter--;
    }
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    if (script_output("ps ax | grep -i \"$_http_server_command\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1) eq '') {
        record_info("HTTP server can not start and serve unattended installation file.Mark guest $self->{guest_name} installation as FAILED", "The command used is ((nohup $_http_server_command &>$common_log_folder/http_server_log) &)");
        $self->record_guest_installation_result('FAILED');
        return $self;
    }
    else {
        record_info("HTTP server already started successfully and serves unattended installation file", "The command used is ((nohup $_http_server_command &>$common_log_folder/http_server_log) &)");
    }
    $self->{guest_installation_automation_file} = "http://$self->{host_ipaddr}:8666/" . basename($self->{guest_installation_automation_file});
    if ($self->{guest_installation_automation} eq 'autoyast') {
        $self->{guest_installation_automation_options} = "--extra-args \"autoyast=$self->{guest_installation_automation_file}\"";
    }
    elsif ($self->{guest_installation_automation} eq 'kickstart') {
        $self->{guest_installation_automation_options} = "--extra-args \"inst.ks=$self->{guest_installation_automation_file}\"";
        $self->{guest_installation_automation_options} = "--extra-args \"ks=$self->{guest_installation_automation_file}\"" if (($self->{guest_os_name} =~ /oraclelinux/im) and ($self->{guest_version_major} lt 7));
    }
    if (script_retry("curl -sSf $self->{guest_installation_automation_file} > /dev/null") ne 0) {
        record_info("Guest $self->{guest_name} unattended installation file hosted on local host can not be reached", "Mark guest installation as FAILED. The unattended installation file url is $self->{guest_installation_automation_file}", result => 'softfail');
        $self->record_guest_installation_result('FAILED');
    }
    return $self;
}

#Configure registration/subscription/activation information in guest unattended installation file using guest parameters, including guest_do_registration,guest_registration_server,
#guest_registration_username,guest_registration_password,guest_registration_code,guest_registration_extensions and guest_registration_extensions_codes].
sub config_guest_installation_automation_registration {
    my $self = shift;

    $self->reveal_myself;
    $self->{guest_do_registration} = 'false' if ($self->{guest_do_registration} eq '');
    record_info("Guest $self->{guest_name} registration status: $self->{guest_do_registration}", "Good luck !");
    if ($self->{guest_do_registration} eq 'false') {
        assert_script_run("sed -ri \'/<suse_register>/,/<\\\/suse_register>/d\' $self->{guest_installation_automation_file}") if ($self->{guest_os_name} =~ /sles/im);
    }
    else {
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
            my $_guest_registration_version = ($self->{guest_version_minor} eq '0' ? $self->{guest_version_major} : $self->{guest_version_major} . '.' . $self->{guest_version_minor});
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
    }
    return $self;
}

# Configure guest sysinfo
sub config_guest_sysinfo {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);

    if ($self->{guest_sysinfo} ne '') {
        $self->{guest_sysinfo_options} .= " --sysinfo $self->{guest_sysinfo} ";
        record_info("Guest $self->{guest_name} has been set sysinfo.");
    }
    return $self;
}

#Validate autoyast file using xmllint and yast2-schema.This is only for reference purpose if guest and host oses have different release major version.
#Output kickstart file content directly because its content can not be validated on SLES or opensuse host by using ksvalidator.
sub validate_guest_installation_automation_file {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_automation} eq 'autoyast') {
        if (script_run("xmllint --noout --relaxng /usr/share/YaST2/schema/autoyast/rng/profile.rng $self->{guest_installation_automation_file}") ne 0) {
            record_info("Autoyast file validation failed for guest $self->{guest_name}.Only for reference purpose", script_output("cat $self->{guest_installation_automation_file}"));
        }
        else {
            record_info("Autoyast file validation succeeded for guest $self->{guest_name}.Only for reference purpose", script_output("cat $self->{guest_installation_automation_file}"));
        }
    }
    elsif ($self->{guest_installation_automation} eq 'kickstart') {
        record_info("Kickstart file for guest $self->{guest_name}", script_output("cat $self->{guest_installation_automation_file}"));
    }
    assert_script_run("cp -f -r $self->{guest_installation_automation_file} $self->{guest_log_folder}");
    return $self;
}

#Calls prepare_guest_installation to do guest configuration.Call start_guest_installation to start guest installation.
#This subroutine also accepts hash/dictionary argument to be passed to prepare_guest_installation to further customize guest object if necessary.
sub guest_installation_run {
    my $self = shift;

    $self->reveal_myself;
    $self->prepare_guest_installation(@_);
    $self->start_guest_installation;
    return $self;
}

#Configure and prepare guest before installation starts.
#This subroutine also accepts hash/dictionary argument to be passed to config_guest_params to further customize guest object if necessary.
sub prepare_guest_installation {
    my $self = shift;

    $self->reveal_myself;
    $self->config_guest_params(@_) if (scalar(@_) gt 0);
    $self->prepare_common_environment;
    $self->prepare_guest_environment;
    $self->config_guest_name;
    $self->config_guest_vcpus;
    $self->config_guest_memory;
    $self->config_guest_os_variant;
    $self->config_guest_virtualization;
    $self->config_guest_platform;
    $self->config_guest_boot_settings;
    $self->config_guest_power_management;
    $self->config_guest_events;
    $self->config_guest_graphics_and_video;
    $self->config_guest_consoles;
    $self->config_guest_features;
    $self->config_guest_xpath;
    $self->config_guest_qemu_command;
    $self->config_guest_security;
    $self->config_guest_controller;
    $self->config_guest_rng;
    $self->config_guest_storage;
    $self->config_guest_network_selection;
    $self->config_guest_installation_method;
    $self->config_guest_installation_extra_args;
    $self->config_guest_sysinfo;
    return $self;
}

#If [virt_install_command_line_dryrun] succeeds,start real guest installation using screen and virt_install_command_line.
sub start_guest_installation {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_result} ne '') {
        record_info("Guest $self->{guest_name} installation has not started due to some errors", "Bad luck !");
        return $self;
    }
    $self->{virt_install_command_line} = "virt-install $self->{guest_virt_options} $self->{guest_platform_options} $self->{guest_name_options} "
      . "$self->{guest_vcpus_options} $self->{guest_memory_options} $self->{guest_cpumodel_options} $self->{guest_metadata_options} "
      . "$self->{guest_os_variant_options} $self->{guest_boot_options} $self->{guest_storage_options} $self->{guest_network_selection_options} "
      . "$self->{guest_installation_method_options} $self->{guest_installation_extra_args_options} $self->{guest_graphics_and_video_options} "
      . "$self->{guest_sysinfo_options} "
      . "$self->{guest_serial_options} $self->{guest_console_options} $self->{guest_features_options} $self->{guest_events_options} "
      . "$self->{guest_power_management_options} $self->{guest_qemu_command_options} $self->{guest_xpath_options} $self->{guest_security_options} "
      . "$self->{guest_controller_options} $self->{guest_rng_options} --debug";
    $self->{virt_install_command_line_dryrun} = $self->{virt_install_command_line} . " --dry-run";
    $self->print_guest_params;

    my $_start_installation_timestamp = localtime();
    $_start_installation_timestamp =~ s/ |:/_/g;
    my $_guest_installation_dryrun_log = "$common_log_folder/$self->{guest_name}/$self->{guest_name}" . "_installation_dryrun_log_" . $_start_installation_timestamp;
    my $_guest_installation_log = "$common_log_folder/$self->{guest_name}/$self->{guest_name}" . "_installation_log_" . $_start_installation_timestamp;
    assert_script_run("touch $_guest_installation_log && chmod 777 $_guest_installation_log");
    # Dry run always timeout when downloading initrd from download.opensuse.org in O3
    my $ret = script_run("set -o pipefail; $self->{virt_install_command_line_dryrun} 2>&1 | tee -a $_guest_installation_dryrun_log", timeout => 600 / get_var('TIMEOUT_SCALE', 1), die_on_timeout => 0);
    save_screenshot;
    unless (defined(script_run('set +o pipefail', die_on_timeout => 0))) {
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

#Get guest installation screen process information and store it in [guest_installation_session] which is in the form of 3401.pts-1.vh017.
sub get_guest_installation_session {
    my $self = shift;

    $self->reveal_myself;
    if ($self->{guest_installation_session} ne '') {
        record_info("Guest $self->{guest_name} installation screen process info had already been known", "$self->{guest_name} $self->{guest_installation_session}");
        return $self;
    }
    my $installation_tty = script_output("tty | awk -F\"/\" 'BEGIN { OFS=\"-\" } {print \$3,\$4}\'", proceed_on_failure => 1);
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    my $installation_pid = script_output("ps ax | grep -i \"SCREEN -t $self->{guest_name}\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1);
    $self->{guest_installation_session} = ($installation_pid eq '' ? '' : $installation_pid . ".$installation_tty." . (split(/\./, $self->{host_name}))[0]);
    record_info("Guest $self->{guest_name} installation screen process info", "$self->{guest_name} $self->{guest_installation_session}");
    return $self;
}

#Kill all guest installation screen processes stored in [guest_installation_session] after test finishes.
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

#Get dynamic allocated guest ip address using nmap scan and store it in [guest_ipaddr].
sub get_guest_ipaddr {
    my $self = shift;
    my @subnets_in_route = @_;

    $self->reveal_myself;
    return $self if ((($self->{guest_ipaddr} ne '') and ($self->{guest_ipaddr} ne 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT')) or ($self->{guest_ipaddr_static} eq 'true'));
    @subnets_in_route = split(/\n+/, script_output("ip route show all | awk \'{print \$1}\' | grep -v default")) if (scalar(@subnets_in_route) eq 0);
    foreach (@subnets_in_route) {
        my $single_subnet = $_;
        next if (!(grep { $_ eq $single_subnet } @{$self->{guest_netaddr_attached}}));
        $single_subnet =~ s/\.|\//_/g;
        my $_scan_timestamp = localtime();
        $_scan_timestamp =~ s/ |:/_/g;
        my $single_subnet_scan_results = "$common_log_folder/nmap_subnets_scan_results/nmap_scan_$single_subnet" . '_' . $_scan_timestamp;
        assert_script_run("mkdir -p $common_log_folder/nmap_subnets_scan_results");
        script_run("nmap -T4 -sn $_ -oX $single_subnet_scan_results", timeout => 600 / get_var('TIMEOUT_SCALE', 1));
        my $_guest_ipaddr = script_output("xmlstarlet sel -t -v //address/\@addr -n $single_subnet_scan_results | grep -i $self->{guest_macaddr} -B1 | grep -iv $self->{guest_macaddr}", proceed_on_failure => 1);
        $self->{guest_ipaddr} = ($_guest_ipaddr ? $_guest_ipaddr : 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT');
        last if ($self->{guest_ipaddr} ne 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT');
    }

    my $record_info = '';
    $self->{guest_ipaddr} = 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT' if ($self->{guest_ipaddr} eq '');
    $record_info = $record_info . $self->{guest_name} . ' ' . $self->{guest_ipaddr} . ' ' . $self->{guest_macaddr} . "\n";
    record_info("Guest $self->{guest_name} address info", $record_info);
    return $self;
}

#Monitor guest installation progress:
#If needle 'guest_installation_failures' is detected,mark it as FAILED.
#If needle 'text-login' is detected,this means guest installations finishes.Mark it as PASSED if ssh connection is good,otherwise mark it as FAILED.
#If needle 'grub2' is detected,this means guest is rebooting.Will check its result in the next round.
#If needle 'text-logged-in-root' is detected,this means installation screen is disconnected, terminated or broken.Will try to re-attach and check its result in the next round.
#If needle 'guest_installation_in_progress' is detected,this means installation is still in progress.Will check its result in the next round.
#If none of above needles is detected,makr it as PASSED if ssh connection to it is good,otherwise mark it as FAILED by calling check_guest_installation_result_via_ssh.
sub monitor_guest_installation {
    my $self = shift;

    $self->reveal_myself;
    save_screenshot;
    if (!(check_screen([qw(text-logged-in-root guest-installation-in-progress guest-installation-failures grub2 linux-login text-login guest-console-text-login)], 180 / get_var('TIMEOUT_SCALE', 1)))) {
        save_screenshot;
        record_info("Can not detect any interested screens on guest $self->{guest_name} installation process", "Going to detach current screen anyway");
        $self->detach_guest_installation_screen;
        my $_detect_installation_result = $self->check_guest_installation_result_via_ssh;
        record_info("Not able to determine guest $self->{guest_name} installation progress or result at the moment", "Installation is still in progress, guest reboot/shutoff, broken ssh connection or unknown") if ($_detect_installation_result eq '');
    }
    elsif (match_has_tag('guest-installation-failures')) {
        save_screenshot;
        $self->detach_guest_installation_screen;
        $self->record_guest_installation_result('FAILED');
        record_info("Installation failed due to errors for guest $self->{guest_name}", "Bad luck ! Mark it as FAILED");
        $self->get_guest_ipaddr if ($self->{guest_ipaddr_static} ne 'true');
    }
    elsif (match_has_tag('linux-login') or match_has_tag('text-login') or match_has_tag('guest-console-text-login')) {
        save_screenshot;
        $self->detach_guest_installation_screen;
        my $_detect_installation_result = $self->check_guest_installation_result_via_ssh;
        if ($_detect_installation_result eq '') {
            record_info("Installation finished with bad ssh connection for guest $self->{guest_name}", "Almost there ! Mark it as FAILED");
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
    elsif (match_has_tag('guest-installation-in-progress')) {
        save_screenshot;
        record_info("Guest $self->{guest_name} installation is still in progress", "Sit back and wait");
    }
    save_screenshot;
    return $self;
}

#Get guest ip address and check whether it is already up and running by using ip address and name sequentially.
#Use very common linux command 'hostname' to do the actual checking because it is almost available on any linux flavor and release.
sub check_guest_installation_result_via_ssh {
    my $self = shift;

    $self->reveal_myself;
    my $_guest_transient_hostname = '';
    record_info("Going to use guest $self->{guest_name} ip address to detect installation result directly.", "No any interested needle or text-login/guest-console-text-login needle is detected.Just a moment");
    $self->get_guest_ipaddr if (($self->{guest_ipaddr_static} ne 'true') and (!($self->{guest_ipaddr} =~ /^\d+\.\d+\.\d+\.\d+$/im)));
    save_screenshot;
    if ($self->{guest_ipaddr} =~ /^\d+\.\d+\.\d+\.\d+$/im) {
        if ($self->{guest_network_type} eq 'virtual_network') {
            # Setup dns in /etc/hosts
            virt_autotest::virtual_network_utils::setup_vm_simple_dns_with_ip($self->{guest_name}, $self->{guest_ipaddr});
        }
        if ($self->{guest_installation_method} eq 'import') {
            # Setup password-less ssh login
            virt_autotest::utils::ssh_copy_id($self->{guest_name}, default_ssh_key => '/root/.ssh/id_rsa');
        }
        $_guest_transient_hostname = script_output("timeout --kill-after=3 --signal=9 30 ssh -vvv root\@$self->{guest_ipaddr} hostname", proceed_on_failure => 1);
        save_screenshot;
        if ($_guest_transient_hostname ne '') {
            record_info("Guest $self->{guest_name} can be connected via ssh using ip $self->{guest_ipaddr} directly", "So far so good.");
            virt_autotest::utils::add_alias_in_ssh_config('/root/.ssh/config', $_guest_transient_hostname, $self->{guest_domain_name}, $self->{guest_name}) if ($self->{guest_netaddr} eq 'host-default');
            save_screenshot;
            $_guest_transient_hostname = script_output("timeout 30 ssh -vvv root\@$self->{guest_name} hostname", proceed_on_failure => 1);
            save_screenshot;
            if ($_guest_transient_hostname ne '') {
                record_info("Installation succeeded with good ssh connection for guest $self->{guest_name}", "Well done ! Mark it as PASSED");
                $self->record_guest_installation_result('PASSED');
            }
        }
    }
    return $_guest_transient_hostname;
}

#Attach guest installation screen before monitoring guest installation progress:
#If [guest_installation_session] is not available and no [guest_autoconsole],call do_attach_guest_installation_screen_without_sesssion.
#If [guest_installation_session] is not available and has [guest_autoconsole],call get_guest_installation_session, then attach based on whether installation session is available.
#If [guest_installation_session] is already available,call do_attach_guest_installation_screen directly.
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

#Call do_attach_guest_installation_screen_with_session anyway.Mark [guest_installation_attached] as true if needle 'text-logged-in-root' can not be detected.
#If fails to attach guest installation screen, [guest_installation_session] may terminate at reboot/shutoff or be in mysterious state or just broken somehow,
#call do_attach_guest_installation_screen_without_sesssion to re-attach.
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

#Retry attach [guest_installation_session] and detect needle 'text-logged-in-root'.
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

#If [guest_installation_session] is already terminated at reboot/shutoff or somehow, power it on and retry attaching using [guest_installation_session_command] and detect
#needle 'text-logged-in-root'.Mark it as FAILED if needle 'text-logged-in-root' can still be detected and poweron can not bring it back.
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
            my $_guest_installation_log = "$common_log_folder/$self->{guest_name}/$self->{guest_name}" . "_installation_log_" . $_attach_timestamp;
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
            record_info("Guest $self->{guest_name} installation process terminates somehow due to unexpected errors", "Guest disappears or stays at shutoff state even after poweron.Mark it as FAILED");
            $self->record_guest_installation_result('FAILED');
        }
    }
    return $self;
}

#Detach guest installation screen by calling do_detach_guest_installation_screen.Try to get guest installation screen information if [guest_installation_session] is not available.
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

#Retry doing real guest installation screen detach using send_key('ctrl-a-d') and detecting needle 'text-logged-in-root' or 'in-libvirtd-container-bash'.
#If either of the needles is detected,this means successful detach.
#If neither of the needle can be detected, recover ssh console by select_console('root-ssh').
sub do_detach_guest_installation_screen {
    my $self = shift;

    $self->reveal_myself;
    wait_still_screen;
    save_screenshot;
    my $_retry_counter = 3;
    while (!(check_screen([qw(text-logged-in-root in-libvirtd-container-bash)], timeout => 5))) {
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
        reset_consoles;
        select_console('root-ssh');
        alp_workloads::kvm_workload_utils::enter_kvm_container_sh if version_utils::is_alp;
        $self->get_guest_installation_session if ($self->{guest_installation_session} eq '');
        type_string("reset\n");
        wait_still_screen;
    }
    $self->{guest_installation_attached} = 'false';
    return $self;
}

#Return true if guest has [guest_autoconsole] and [guest_noautoconsole] that are not equal to 'none', 'true' or empty which indicates guest definitely has autoconsole.
#Empty value may indicate there is autoconsole or the opposite which depends on detailed configuration of guest.
sub has_autoconsole_for_sure {
    my $self = shift;

    $self->reveal_myself;
    return (($self->{guest_autoconsole} ne 'none') and ($self->{guest_autoconsole} ne '') and ($self->{guest_noautoconsole} ne 'true') and ($self->{guest_noautoconsole} ne ''));
}

#Return true if guest has [guest_autoconsole] or [guest_noautoconsole] that are equal to 'none' or 'true' which indicates guest definitely has no autoconsole.
#Empty value may indicate there is autoconsole or the opposite which depends on detailed configuration of guest.
sub has_noautoconsole_for_sure {
    my $self = shift;

    $self->reveal_myself;
    return (($self->{guest_autoconsole} eq 'none') or ($self->{guest_noautoconsole} eq 'true'));
}

#Record final guest installation result in [guest_installation_result] and set [stop_run] and [stop_timestamp].
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

#Collect guest y2logs via ssh and save guest config xml file.
sub collect_guest_installation_logs_via_ssh {
    my $self = shift;

    $self->reveal_myself;
    $self->get_guest_ipaddr;
    if ((script_run("nmap $self->{guest_ipaddr} -PN -p ssh | grep -i open") eq 0) and ($self->{guest_ipaddr} ne '') and ($self->{guest_ipaddr} ne 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT')) {
        record_info("Guest $self->{guest_name} has ssh port open on ip address $self->{guest_ipaddr}.", "Try to collect logs via ssh but may fail.Open ssh port does not mean good ssh connection.");
        script_run("ssh -vvv root\@$self->{guest_ipaddr} \"save_y2logs /tmp/$self->{guest_name}_y2logs.tar.gz\"");
        script_run("scp -r -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$self->{guest_ipaddr}:/tmp/$self->{guest_name}_y2logs.tar.gz $self->{guest_log_folder}");
    }
    else {
        record_info("Guest $self->{guest_name} has no ssh connection available at all.Not able to collect logs from it via ssh", "Guest ip address is $self->{guest_ipaddr}");
    }
    script_run("virsh dumpxml $self->{guest_name} > $self->{guest_log_folder}/virsh_dumpxml_$self->{guest_name}.xml");
    script_run("rm -f -r $common_log_folder/unattended*");
    return $self;
}

#Upload logs collect by collect_guest_installation_logs_via_ssh.
sub upload_guest_installation_logs {
    my $self = shift;

    $self->reveal_myself;
    assert_script_run("tar czvf /tmp/guest_installation_and_configuration_logs.tar.gz $common_log_folder");
    upload_logs("/tmp/guest_installation_and_configuration_logs.tar.gz");
    return $self;
}

#Unmount all mounted nfs shares to avoid unnecessary logs to be collected by supportconfig or sosreport which may take extremely long time.
sub detach_all_nfs_mounts {
    my $self = shift;

    $self->reveal_myself;
    script_run("umount -a -f -l -t nfs,nfs4") if (script_run("umount -a -t nfs,nfs4") ne 0);
    return $self;
}

#Power cycle guest by force:virsh destroy,grace:virsh shutdown,reboot:virsh reboot and poweron:virsh start.
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

#Modify guest parameters after guest installation passes using virt-xml.
sub modify_guest_params {
    my ($self, $_guest_name, $_guest_option, $_modify_operation) = @_;

    $self->reveal_myself;
    $_modify_operation //= 'define';
    assert_script_run("virt-xml $_guest_name --edit --print-diff --$_modify_operation $self->{$_guest_option}");
    $self->power_cycle_guest('force');
    return $self;
}

#Add device to guest after guest installation passes using virt-xml.
sub add_guest_device {
    #TODO
}

#Remove device from guest after guest installation passes using virt-xml.
sub remove_guest_device {
    #TODO
}

#AUTOLOAD to be called if called subroutine does not exist.
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

#Collect logs and gues extra log '/root' by using virt_utils::collect_host_and_guest_logs.
#'Root' directory on guest contains very valuable content that is generated automatically after guest installation finishes.
sub post_fail_hook {
    my $self = shift;

    $self->reveal_myself;
    $self->upload_guest_installation_logs;
    save_screenshot;
    virt_utils::collect_host_and_guest_logs("", "", "/root /var/log");
    save_screenshot;
    $self->upload_coredumps;
    save_screenshot;
    return $self;
}

1;
