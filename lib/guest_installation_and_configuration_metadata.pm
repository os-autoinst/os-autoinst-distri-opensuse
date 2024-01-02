# VIRTUAL MACHINE INSTALLATION AND CONFIGURATION METADATA MODULE
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module provides metadata which will be used by guest installation
# and configuration program using guest_installation_and_configuration_base.pm
# as base module at the lowest level. Metadata includes global %guest_params which
# contains all parameters and arguments to generate virt-install command for guest
# installation and global %guest_network_matrix which contains all supported types
# of network configuration to create guest network.
#
# Maintainer: Wayne Chen <wchen@suse.com> or <qe-virt@suse.de>
package guest_installation_and_configuration_metadata;

use strict;
use warnings;

# Global data structure %guest_params to specify desired guest to be configured
# and installed. Specifying desired guest by placing guest profile in xml format
# in data/virt_autotest/guest_params_xml_files folder.
our %guest_params = (
    'guest_os_name' => '',    # [guest_os_name]:sles,opensuse,oraclelinux or others.Not virt-install argument.
    'guest_os_word_length' => '',    # [guest_os_word_length]:64 or 32.Not virt-install argument.
    'guest_version' => '',    # [guest_version]:15-sp3 or others.not virt-install argument.
    'guest_version_major' => '',    # [guest_version_major]:15 or others.not virt-install argument.
    'guest_version_minor' => '',    # [guest_version_minor]:3 or others.not virt-install argument.
    'guest_build' => '',    # Build number if developing release or 'gm'.not virt-install argument.it should
                            # be left empty in guest params xml file if developing release will be installed
                            # for the guest.it will be set to the same as build from test suite settings in
                            # config_guest_params. Otherwise it must be set to 'gm' in guest params xml file
                            # if non-developing release will be installed for the guest.
    'host_hypervisor_uri' => '',    # virt-install --connect [host_hypervisor_uri]
    'host_virt_type' => '',    # virt-install --virt-type [host_virt_type]
    'guest_virt_type' => '',    # virt-install --[guest_virt_type(hvm or paravirt)]
    'guest_machine_type' => '',    # virt-install --machine [guest_machine_type]
    'guest_arch' => '',    # virt-install --arch [guest_arch]
    'guest_name' => '',    # virt-install --name [guest_name]
    'guest_domain_name' => '',    # this will be used for dns configuration, not virt-install argument
    'guest_memory' => '',    # virt-install --memory [guest_memory]
    'guest_vcpus' => '',    # virt-install --vcpus [guest_vcpus]
    'guest_cpumodel' => '',    # virt-install --cpu [guest_cpumodel]
    'guest_metadata' => '',    # virt-install --metadata [guest_metadata]
    'guest_xpath' => '',    # virt-install --xml [guest_xpath].it can contain multiple items seperated by hash key
    'guest_installation_automation_method' => '',    # This indicates whether guest uses autoyast, kickstart, ignition, combustion or
                                                     # ignition+combustion for installation, not virt-install argument
    'guest_installation_automation_platform' => '',    # This indicates ignition/combustion platform, not virt-install argument. Please
                                                       # refer to https://coreos.github.io/ignition/supported-platforms
    'guest_installation_automation_file' => '',    # virt-install --extra-args "autoyast=[guest_installation_automation_file] or
                                                   # inst.ks=[guest_installation_automation_file],ignition/combustion in --sysinfo
                                                   # type=fwcfg,entry0.name=opt/com.coreos/config,entry0.file=[guest_installation_automation_file]
                                                   # or --disk type=file,device=disk,source.file=xxxxx,size=1,format=qcow2,driver.type=qcow2,
                                                   # backing_store=xxxxx,target.dev=vdb,target.bus=virtio
    'guest_installation_method' => '',    # virt-install --[guest_installation_method(location, cdrom, pxe, import and etc)]
    'guest_installation_method_others' => '',    # virt-install --[guest_installation_method] [guest_installation_method_others] or
                                                 # --[guest_installation_method] [guest_installation_media],[guest_installation_method_others]
    'guest_installation_extra_args' => '',    # virt-install --extra-args [guest_installation_extra_args].it can contain multiple
                                              # itmes seperated by hash key
    'guest_installation_wait' => '',    # virt-install --wait [guest_installation_wait]
    'guest_installation_media' => '',    # virt-install --location [guest_installation_media] or --cdrom [guest_installation_media]
                                         # It can also specify the imported virtual disk image to be used for installation.
    'guest_installation_fine_grained' => '',    # virt-install --install [guest_installation_fine_grained]
    'guest_boot_settings' => '',    # virt-install --boot [guest_boot_settings]
    'guest_secure_boot' => '',    # This indicates whether uefi secure boot is enabled(true, false or empty) during
                                  # installation in unattended installation file, not virt-install argument
    'guest_os_variant' => '',    # virt-install --os-variant [guest_os_variant]
    'guest_storage_path' => '',    # virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],
                                   # [guest_storage_others] or --disk type=file,device=disk,source.file=[guest_storage_path],
                                   # size=[guest_storage_size],format=[guest_storage_format],driver.type=[guest_storage_format]
    'guest_storage_type' => '',    # This indicates type of storage medium to be used for guest installation, for
                                   # example, disk, usb or etc, --disk type=file,device=[guest_storage_type],source.file=[guest_storage_path],
                                   # size=[guest_storage_size],format=[guest_storage_format],xxxxx". Not always virt-install argument.
    'guest_storage_format' => '',    # virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],
                                     # [guest_storage_others] or --disk type=file,device=disk,source.file=[guest_storage_path],
                                     # size=[guest_storage_size],format=[guest_storage_format],driver.type=[guest_storage_format]
    'guest_storage_label' => '',    # This indicates whether guest disk uses gpt or mbr in unattended installation
                                    # file, not virt-install argument
    'guest_storage_size' => '',    # virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],
                                   # [guest_storage_others]
    'guest_storage_backing_path' => '',    # virt-install --disk xxxxx,backing_store=[guest_storage_backing_path],backing_format=[guest_storage_backing_format]
    'guest_storage_backing_format' => '',   # virt-install --disk xxxxx,backing_store=[guest_storage_backing_path],backing_format=[guest_storage_backing_format]
    'guest_storage_others' => '', # virt-install --disk path=[guest_storage_path],size=[guest_storage_size],format=[guest_storage_format],[guest_storage_others]
    'guest_network_type' => '',    # This indicates whether guest uses bridge, vnet, or other types of network.
                                   # Network configurations nat/route/default in %guest_network_matrix belong to
                                   # vnet network type, host/bridge belong to bridge network type. Not virt-install
                                   # argument
    'guest_network_mode' => '',    # This indicates whether guest uses nat, route, default, host or bridge network
                                   # modes used for network configuration selection with %guest_network_matrix, not
                                   # virt-install argument
    'guest_network_device' => '',    # This indicates the network device to be used for guest installation. It can be
                                     # default, bridge or virtual network name.
    'guest_network_others' => '',    # virt-install --netowrk=bridge=[guest_network_device],mac=[guest_macaddr],[guest_network_others]
                                     # Also can be used with other network type
    'guest_macaddr' => '',    # virt-install --network=bridge=[guest_network_device],mac=[guest_macaddr].
    'guest_netaddr' => '',    # Desired network address to be used for guest network. It takes the form of "ipv4addr/masklen" or empty.
                              # Not virt-install argument.
    'guest_ipaddr' => '',    # virt-install --extra-args "ip=[guest_ipaddr]" if it is a static ip address,
                             # otherwise it is not virt-install argument. It stores the final guest ip address
                             # obtained from ip discovery
    'guest_ipaddr_static' => '',    # This indicates whether guest uses static ip address(true or false), not virt-install argument
    'guest_graphics' => '',    # virt-install --graphics [guest_graphics]
    'guest_controller' => '',    # virt-install --controller [guest_controller].More than one controller can be
                                 # passed to guest, they should be separated by hash. For example, "controller1#controller2#controller3"
                                 # which will be splitted later and passed to individual --controller argument.
    'guest_sysinfo' => '',    # virt-install --sysinfo [guest_sysinfo]
    'guest_input' => '',    # TODO virt-install --input [guest_input]
    'guest_serial' => '',    # virt-install --serial [guest_serial]
    'guest_parallel' => '',    # TODO virt-install --parallel [guest_parallel]
    'guest_channel' => '',    # virt-install --channel [guest_channel]
    'guest_console' => '',    # virt-install --console [guest_console]
    'guest_hostdev' => '',    # TODO virt-install --hostdev [guest_hostdev]
    'guest_filesystem' => '',    # TODO virt-install --filesystem [guest_filesystem]
    'guest_sound' => '',    # TODO virt-install --sound [guest_sound]
    'guest_watchdog' => '',    # TODO virt-install --watchdog [guest_watchdog]
    'guest_video' => '',    # virt-install --video [guest_video]
    'guest_smartcard' => '',    # TODO virt-install --smartcard [guest_smartcard]
    'guest_redirdev' => '',    # TODO virt-install --redirdev [guest_redirdev]
    'guest_memballoon' => '',    # virt-install --memballoon [guest_memballoon]
    'guest_tpm' => '',    # virt-install --tpm [guest_tpm]
    'guest_rng' => '',    # virt-install --rng [guest_rng]
    'guest_panic' => '',    # TODO virt-install --panic [guest_panic]
    'guest_memdev' => '',    # virt-install --memdev [guest_memdev]
    'guest_vsock' => '',    # TODO virt-install --vsock [guest_vsock]
    'guest_iommu' => '',    # TODO virt-install --iommu [guest_iommu]
    'guest_iothreads' => '',    # TODO virt-install --iothreads [guest_iothreads]
    'guest_seclabel' => '',    # virt-install --seclabel [guest_seclabel]
    'guest_keywrap' => '',    # TODO virt-install --keywrap [guest_keywrap]
    'guest_cputune' => '',    # TODO virt-install --cputune [guest_cputune]
    'guest_memtune' => '',    # virt-install --memtune [guest_memtune]
    'guest_blkiotune' => '',    # TODO virt-install --blkiotune [guest_blkiotune]
    'guest_memorybacking' => '',    # virt-install --memorybacking [guest_memorybacking]
    'guest_features' => '',    # virt-install --features [guest_features]
    'guest_clock' => '',    # TODO virt-install --clock [guest_clock]
    'guest_power_management' => '',    # virt-install --pm [guest_power_management]
    'guest_events' => '',    # virt-install --events [guest_events]
    'guest_resource' => '',    # TODO virt-install --resource [guest_resource]
    'guest_qemu_command' => '',    # virt-install --qemu-commandline [guest_qemu_command]
    'guest_launchsecurity' => '',    # virt-install --launchSecurity [guest_launchsecurity]
    'guest_autostart' => '',    # TODO virt-install --[guest_autostart(autostart or empty)]
    'guest_transient' => '',    # TODO virt-install --[guest_transient(transient or empty)]
    'guest_destroy_on_exit' => '',    # TODO virt-install --[guest_destroy_on_exit(true or false)]
    'guest_autoconsole' => '',    # virt-install --autoconsole [guest_autoconsole(text or graphical or none)] or
                                  # empty. For virt-manager earlier than 3.0.0, this option does not exist and
                                  # should be left empty.
    'guest_noautoconsole' => '',    # virt-install --noautoconsole if true.This option should only be given 'true',
                                    # 'false' or empty.
    'guest_noreboot' => '',    # TODO virt-install --[guest_noreboot(true or false)]
    'guest_default_target' => '',    # This indicates whether guest os default target(multi-user, graphical or others),
                                     # not virt-install argument. The following parameters end with 'options' are derived
                                     # from above parameters. They contains options and corresponding values which
                                     # are passed to virt-install command line directly to perform guest installations.
    'guest_do_registration' => '',    # This indicates whether guest to be registered or subscribed with content provider.
                                      # Not virt-install argument. It can be given 'true','false' or empty. Only 'true'
                                      # means do registration/subscription.
    'guest_registration_server' => '',    # This is the address of registration/subscription server of content provider.
                                          # Not virt-install argument. It can be left empty if not needed.
    'guest_registration_username' => '',    # This is the username to be used in registration/subscription. Not virt-install argument.
                                            # It can be email address, free text or empty if not needed.
    'guest_registration_password' => '',    # This is the password to be used in registration/subscription. Not virt-install argument.
                                            # It is normally used together with [guest_registration_username] or empty if not needed.
    'guest_registration_code' => '',    # This is the code or key to used in registraiton/subscription. Not virt-install
                                        # argument. It can be used together with [guest_registration_username], standalone
                                        # or empty if not needed. Do not recommend to use the parameter in guest profile
                                        # directly, use test suite setting UNIFIED_GUEST_REG_CODES.
    'guest_registration_extensions' => '',    # This refers to additional modules/extensions/products to be registered together
                                              # with guest os or by using individual registration/subscription code/key. Multiple
                                              # modules/extensions/products are separated by hash key. For example,
                                              # "sle-module-legacy#sle-module-basesystem#SLES-LTSS". Not virt-install argument.
                                              # Can be left empty if not needed.
    'guest_registration_extensions_codes' => '',    # This refers to registration/subscription codes/keys to be used by modules/
                                                    # extensions/products in [guest_registration_extensions]. Can be empty if not
                                                    # needed, but if anyone in [guest_registration_extensions] needs its own code/key,
                                                    # all the others should also be given theirs even empty. For example,
                                                    # "sle-module-legacy#sle-module-basesystem#SLES-LTSS" needs "##SLES-LTSS-CODE-OR-KEY"
                                                    # to be set in [guest_registration_extensions_codes]. And the codes/keys should
                                                    # be separated by hash key and put in the same order as their corresponding modules/
                                                    # extensions/products in [guest_registration_extensions]. Not virt-install argument.
                                                    # Do not recommend to use the parameter in guest profile directly, use test suite
                                                    # setting UNIFIED_GUEST_REG_EXTS_CODES.
    'guest_virt_options' => '',    # [guest_virt_options] = "--connect [host_hypervisor_uri] --virt-type [host_virt_type]
                                   # --[guest_virt_type]"
    'guest_platform_options' => '',    # [guest_platform_options] = "--arch [guest_arch] --machine [guest_machine_type]"
    'guest_name_options' => '',    # [guest_name_options] = "--name [guest_name]"
    'guest_memory_options' => '',    # [guest_memory_options] = "--memory [guest_memory] --memballoon [guest_memballoon]
                                     # --memdev [guest_memdev] --memtune [guest_memtune] --memorybacking [guest_memorybacking]"
    'guest_vcpus_options' => '',    # [guest_vcpus_options] = "--vcpus [guest_vcpus]"
    'guest_cpumodel_options' => '',    # [guest_cpumodel_options] = "--cpu [guest_cpumodel]"
    'guest_metadata_options' => '',    # [guest_metadata_options] = "--metadata [guest_metadata]"
    'guest_xpath_options' => '',    # [guest_xpath_options] = [guest_xpath_options] . "--xml $_ " foreach ([@guest_xpath])
    'guest_installation_method_options' => '',    # [guest_installation_method_options] = "--location [guest_installation_media]
                                                  # --install [guest_installation_fine_grained] --autoconsole [guest_autoconsole]
                                                  # or --noautoconsole" or "--[guest_installation_method] [guest_installation_media],
                                                  # [guest_installation_method_others]"
    'guest_installation_extra_args_options' => '',    # [guest_installation_extra_args_options] = "[guest_installation_extra_args_options] .
                                                      # --extra-args $_ foreach [@guest_installation_extra_args] --extra-args ip=[guest_ipaddr(if static)]
                                                      # [guest_installation_automation_options]"
    'guest_installation_automation_options' => '', # [guest_installation_automation_options] = "--extra-args [autoyast|inst.ks][ks]=[guest_installation_automation_file]"
    'guest_boot_options' => '',    # [guest_boot_options} = "--boot [guest_boot_settings]"
    'guest_os_variant_options' => '',    # [guest_os_variant_options] = "--os-variant [guest_os_variant]"
    'guest_storage_options' => '',    # [guest_storage_options] = "--disk path=[guest_storage_path],size=[guest_storage_size],
                                      # format=[guest_storage_format],[guest_storage_others]"
    'guest_network_selection_options' => '',    # [guest_network_selection_options] = "--network=bridge=[guest_network_device],
        # mac=[guest_macaddr]", or "--network=network=[guest_virtual_network],mac=[guest_macaddr],[guest_network_others]"
    'guest_sysinfo_options' => '',    # [guest_sysinfo_options] = "--sysinfo [guest_sysinfo]"
    'guest_graphics_and_video_options' => '',    # [guest_graphics_and_video_options] = "--video [guest_video] --graphics [guest_graphics]"
    'guest_serial_options' => '',    # [guest_serial_options] = "--serial [guest_serial]"
    'guest_channel_options' => '',    # [guest_channel_options] = "--console [guest_channel]"
    'guest_console_options' => '',    # [guest_console_options] = "--console [guest_console]"
    'guest_features_options' => '',    # [guest_features_options] = "--features [guest_features]"
    'guest_power_management_options' => '',    # [guest_power_management_options] = "--pm [guest_power_management]"
    'guest_events_options' => '',    # [guest_events_options] = "--events [guest_events]"
    'guest_qemu_command_options' => '',    # [guest_qemu_command_options] = "--qemu-commandline [guest_qemu_command]"
    'guest_security_options' => '',    # [guest_security_options] = "--seclabel [guest_seclabel] --launchSecurity [guest_launchsecurity]"
    'guest_controller_options' => '',    # [guest_controller_options] = "--controller [guest_controller#1] --controller [guest_controller#2]"
    'guest_tpm_options' => '',    # [guest_tpm_options] = "--tpm [guest_tpm]"
    'guest_rng_options' => '',    # [guest_rng_options] = "--rng [guest_rng]"
    'virt_install_command_line' => '',    # This is the complete virt-install command line which is composed of above parameters end with 'options'
    'virt_install_command_line_dryrun' => '',    # This is [virt_install_command_line] appended with --dry-run
    'guest_image_folder' => '',    # Image folder for individual guest /var/lib/libvirt/images/[guest_name]
    'guest_log_folder' => '',    # Log folder for individual guest [common_log_folder]/[guest_name]
    'guest_installation_result' => '',    # PASSED,FAILED,TIMEOUT,UNKNOWN or others
    'guest_installation_session_config' => '',    # Absolute path of screen command config file that will be used in screen -c
                                                  # [guest_installation_session_config] to start guest installation session.
                                                  # The content of the config file includes content of global /etc/screenrc
                                                  # and logfile="absolute path of guest installation log file".
    'guest_installation_session' => '',    # Guest installation process started by "screen -t [guest_name] [virt_install_command_line].
                                           # It is in the form of 3401.pts-1.vh017
    'guest_installation_session_command' => '',    # If there is no [guest_installation_session] or [guest_installation_session] is
                                                   # terminated, start or re-connect to guest installation screen using
                                                   # [guest_installation_session_command] = screen -t [guest_name] virsh console --force [guest_name]
    'guest_installation_attached' => '',    # This indicates whether guest installation screen is already connected or attached(true or false)
    'guest_netaddr_attached' => '',    # Array reference that stores the actual subnets in which guest may reside, for
                                       # example, ('10.10.10.0/24', '11.11.11.0/24').
    'start_run' => '',    # Guest creation start time
    'stop_run' => ''    # Guest creation finish time
);

# This is get_required_var('SUT_IP')
our $host_ipaddr;
# This is script_output('hostname')
our $host_name;
# This is script_output('dnsdomainname')
our $host_domain_name;
# Major version of host os release from /etc/os-release on host
our $host_version_major;
# Minor version of host os release from /etc/os-release on host
our $host_version_minor;
# Version ID of host os release from /etc/os-release on host
our $host_version_id;
# Public key used for ssh login to guest
our $ssh_public_key;
# Private key used for ssh login to guest
our $ssh_private_key;
# SSH command used for ssh login, for example, "ssh -vvv -i identity_file username"
our $ssh_command;

# Global data structure %guest_network_matrix to specify network devices to be
# used for guest configuring and installing. Virtual networks, including nat,
# route, bridge and default modes, and bridge networks, including host and bridge
# modes, are covered.
our %guest_network_matrix = (
    vnet => {    # Virtual networks to be created by using virsh net-define. [guest_network_type] = vnet
        nat => {    # Virtual network in NAT mode. [guest_network_mode] = nat
            device => 'virbr124',
            ipaddr => '192.168.124.1',
            netmask => '255.255.255.0',
            masklen => '24',
            startaddr => '192.168.124.2',
            endaddr => '192.168.124.254'
        },
        route => {    # Virtual network in ROUTE mode. [guest_network_mode] = route
            device => 'virbr125',
            ipaddr => '192.168.125.1',
            netmask => '255.255.255.0',
            masklen => '24',
            startaddr => '192.168.125.2',
            endaddr => '192.168.125.254'
        },
        default => {    # Virtual network in default mode means using network created by default on virtualization host.
            device => 'virbr0',    # [guest_network_mode] = default
            ipaddr => '192.168.127.1',
            netmask => '255.255.255.0',
            masklen => '24',
            startaddr => '192.168.127.2',
            endaddr => '192.168.127.254'
        }
    },
    bridge => {    # Bridge networks to be created by using wicked or nmcli. [guest_network_type] = bridge
        host => {    # Bridge network in host mode means using bridge created by default on virtualization host.
            device => 'br0',    # [guest_network_mode] = host
            ipaddr => '192.168.127.1',
            netmask => '255.255.255.0',
            masklen => '24',
            startaddr => '192.168.127.2',
            endaddr => '192.168.127.254'
        },
        bridge => {    # Bridge network in bridge mode means using non-default bridge device on virtualization host.
            device => 'br123',    # [guest_network_mode] = bridge
            ipaddr => '192.168.123.1',
            netmask => '255.255.255.0',
            masklen => '24',
            startaddr => '192.168.123.2',
            endaddr => '192.168.123.254'
        }
    }
);

1;
