# SUSE's openQA tests
#
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package ipmi_backend_utils;
# Summary: This file provides fundamental utilities related with the ipmi backend from test view,
#          like switching consoles between ssh and ipmi supported
# Maintainer: alice <xlai@suse.com>

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use version_utils qw(is_storage_ng is_sle);
use utils;
use power_action_utils 'prepare_system_shutdown';
use Utils::Architectures;
use Carp;

our @EXPORT = qw(set_grub_on_vh switch_from_ssh_to_sol_console adjust_for_ipmi_xen set_pxe_efiboot ipmitool enable_sev_in_kernel add_kernel_options set_grub_terminal_and_timeout);

#With the new ipmi backend, we only use the root-ssh console when the SUT boot up,
#and no longer setup the real serial console for either kvm or xen.
#When needs reboot, we will switch back to sut console which relies on ipmi.
#We will mostly rely on ikvm to continue the test flow.
#TODO: we need the serial output to debug issues in reboot, coolo will help add it.

sub switch_from_ssh_to_sol_console {
    my (%opts) = @_;

    #close root-ssh console
    prepare_system_shutdown;
    #switch to sol console
    set_var('SERIALDEV', '');
    $serialdev = 'ttyS1';
    bmwqemu::save_vars();
    if ($opts{'reset_console_flag'} eq "on") {
        reset_consoles;
    }
    select_console 'sol', await_console => 0;
    save_screenshot;
}

my $grub_ver;

sub get_dom0_serialdev {
    my $root_dir = shift;
    $root_dir //= '/';

    my $dom0_serialdev;

    script_run("clear");
    script_run("cat ${root_dir}/etc/SuSE-release || cat ${root_dir}/etc/os-release");
    save_screenshot;
    assert_screen([qw(on_host_sles_12_sp2_or_above on_host_lower_than_sles_12_sp2)]);

    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        if (match_has_tag("on_host_sles_12_sp2_or_above")) {
            $dom0_serialdev = "hvc0";
        }
        elsif (match_has_tag("on_host_lower_than_sles_12_sp2")) {
            $dom0_serialdev = "xvc0";
        }
    }
    else {
        $dom0_serialdev = get_var("LINUX_CONSOLE_OVERRIDE", "ttyS1");
    }

    if (match_has_tag("grub1")) {
        $grub_ver = "grub1";
    }
    else {
        $grub_ver = "grub2";
    }

    enter_cmd("echo \"Debug info: hypervisor serial dev should be $dom0_serialdev. Grub version is $grub_ver.\"");

    return $dom0_serialdev;
}

sub setup_console_in_grub {
    my ($ipmi_console, $root_dir, $virt_type) = @_;
    $ipmi_console //= $serialdev;
    $root_dir //= '/';
    #Ther is no default value for $virt_type, which has to be passed into function explicitly.

    #set grub config file
    my $grub_default_file = "${root_dir}/etc/default/grub";
    my $grub_cfg_file = "";
    my $com_settings = "";
    my $bootmethod = "";
    my $search_pattern = "";
    my $cmd = "";
    if ($grub_ver eq "grub2") {
        #grub2
        $grub_cfg_file = "${root_dir}/boot/grub2/grub.cfg";
        if (${virt_type} eq "xen") {
            $com_settings = get_var('IPMI_CONSOLE') ? "com2=" . get_var('IPMI_CONSOLE') : "";
            $bootmethod = "module";
            $search_pattern = "vmlinuz";

            # autoballoning is disabled since sles15sp1 beta2. we use default dom0_ram which is '10% of total ram + 1G'
            # while for older release, bsc#1107572 "This dom0 memory amount works well with hosts having 4 to 8 Gigs of RAM"
            # considering of one SUT in OSD with 4G ram only, we set dom0_mem=2G
            my $dom0_options = "";
            if (is_sle('<=12-SP4') || is_sle('=15')) {
                $dom0_options = "dom0_mem=2048M,max:2048M";
            }
            if (get_var("ENABLE_SRIOV_NETWORK_CARD_PCI_PASSTHROUGH")) {
                $dom0_options .= " iommu=on";
            }
            $cmd
              = "sed -ri '/multiboot/ "
              . "{s/(console|loglevel|log_lvl|guest_loglvl)=[^ ]*//g; "
              . "/multiboot/ s/\$/ $dom0_options console=com2,115200 log_lvl=all guest_loglvl=all sync_console $com_settings/;}; "
              . "' $grub_cfg_file";
            assert_script_run($cmd);
            save_screenshot;
        }
        elsif (${virt_type} eq "kvm") {
            $bootmethod = "linux";
            $search_pattern = "boot";
        }
        else {
            die "Host Hypervisor is not xen or kvm";
        }

        #enable Intel VT-d for SR-IOV test running on intel SUTs
        my $intel_option = "";
        if (get_var("ENABLE_SRIOV_NETWORK_CARD_PCI_PASSTHROUGH") && script_run("grep Intel /proc/cpuinfo") == 0) {
            $intel_option = "intel_iommu=on";
        }

        $cmd
          = "cp $grub_cfg_file ${grub_cfg_file}.org "
          . "\&\& sed -ri '/($bootmethod\\s*.*$search_pattern)/ "
          . "{s/(console|loglevel|log_lvl|guest_loglvl)=[^ ]*//g; "
          . "/$bootmethod\\s*.*$search_pattern/ s/\$/ console=$ipmi_console,115200 console=tty loglevel=5 $intel_option/;}; "
          . "s/timeout=-{0,1}[0-9]{1,}/timeout=30/g;"
          . "' $grub_cfg_file";
        assert_script_run($cmd);
        save_screenshot;
        $cmd = "sed -rn '/(multiboot|$bootmethod\\s*.*$search_pattern|timeout=)/p' $grub_cfg_file";
        assert_script_run($cmd);
        save_screenshot;

        if (!script_run('grep HPE /sys/class/dmi/id/board_vendor') == 0) {
            $cmd = "sed -ri '/^terminal.*\$/ {:mylabel; n; s/^terminal.*\$//;b mylabel;}' $grub_cfg_file";
            assert_script_run($cmd);
            $cmd = "sed -ri '/^[[:space:]]*\$/d' $grub_cfg_file";
            assert_script_run($cmd);
            $cmd = "sed -ri 's/^terminal.*\$/terminal_input console serial\\nterminal_output console serial\\nterminal console serial/g' $grub_cfg_file";
            assert_script_run($cmd);
        }
        $cmd = "cat $grub_cfg_file $grub_default_file";
        assert_script_run($cmd);
        save_screenshot;
        upload_logs($grub_default_file);
    }
    elsif ($grub_ver eq "grub1") {
        $grub_cfg_file = "${root_dir}/boot/grub/menu.lst";
        $cmd
          = "cp $grub_cfg_file ${grub_cfg_file}.org \&\&  sed -i 's/timeout=-{0,1}[0-9]{1,}/timeout=30/g; /module \\\/boot\\\/vmlinuz/{s/console=.*,115200/console=$ipmi_console,115200/g;}; /kernel .*xen/{s/\$/ dom0_mem=2048M,max:2048M/;}' $grub_cfg_file";
        assert_script_run($cmd);
        save_screenshot;
        $cmd = "sed -rn '/module \\\/boot\\\/vmlinuz/p' $grub_cfg_file";
        assert_script_run($cmd);
    }
    else {
        die "Not supported grub version!";
    }
    save_screenshot;
    upload_logs($grub_cfg_file);
}

sub mount_installation_disk {
    my ($installation_disk, $mount_point) = @_;

    #default from yast installation
    $installation_disk //= "/dev/sda2";
    $mount_point //= "/mnt";

    #mount
    assert_script_run("mkdir -p $mount_point");
    assert_script_run("mount $installation_disk $mount_point");
    assert_script_run("ls ${mount_point}/boot");
}

sub umount_installation_disk {
    my $mount_point = shift;

    #default from yast installation
    $mount_point //= "/mnt";

    #umount
    assert_script_run("umount -l $mount_point");
    assert_script_run("ls $mount_point");
}

# Get the partition where the new installed system is installed to
sub get_installation_partition {
    my $partition = '';

    # Confirmed with dev that the reliable way to get partition for / is via installation log, rather than fdisk
    # For details, please refer to bug 1101806.
    my $cmd = '';
    my $y2log_file = '/var/log/YaST2/y2log';
    if (is_sle('12+')) {
        $cmd = qq{grep -o '/dev/[^ ]\\+ /mnt ' $y2log_file | head -n1 | cut -f1 -d' '};
    }
    else {
        die "Not support finding root partition for products lower than sle12.";
    }
    $partition = script_output($cmd);
    save_screenshot;

    die "Error: can not get installation partition!" unless ($partition);

    enter_cmd "echo Debug info: The partition with the installed system is $partition .";
    save_screenshot;

    return $partition;
}


# This works only on SLES 12+
sub adjust_for_ipmi_xen {
    my ($root_prefix) = @_;
    $root_prefix = "/" if (!defined $root_prefix) || ($root_prefix eq "");
    my $installation_disk = "";

    if ($root_prefix ne "/") {
        $installation_disk = get_installation_partition;
        assert_script_run("cd /");
        mount_installation_disk("$installation_disk", "$root_prefix");
    }

    assert_script_run('mount --rbind /proc /mnt/proc');
    assert_script_run('mount --rbind /sys /mnt/sys');
    assert_script_run('mount --rbind /dev /mnt/dev');
    enter_cmd("chroot /mnt");
    wait_still_screen;

    # Mount Btrfs sub-volumes
    assert_script_run('mount -a');

    assert_script_run ". /etc/default/grub";
    my $xen_dom0_mem = get_var('XEN_DOM0_MEM', '4096M');
    assert_script_run "sed -i '/GRUB_CMDLINE_XEN_DEFAULT/c\\GRUB_CMDLINE_XEN_DEFAULT=\"\$GRUB_CMDLINE_XEN_DEFAULT dom0_mem=$xen_dom0_mem\"' /etc/default/grub";
    assert_script_run "sed -i '/GRUB_DEFAULT/c\\GRUB_DEFAULT=\"2\"' /etc/default/grub";
    assert_script_run "cat /etc/default/grub";
    assert_script_run "grub2-mkconfig -o /boot/grub2/grub.cfg";

    # Exit chroot
    enter_cmd "exit";
    wait_still_screen;

    #cleanup mount
    if ($root_prefix ne "/") {
        assert_script_run("cd /");
        umount_installation_disk("$root_prefix");
    }
}

sub set_pxe_efiboot {
    my ($root_prefix) = @_;
    $root_prefix = "/" if (!defined $root_prefix) || ($root_prefix eq "");
    my $installation_disk = "";

    if ($root_prefix ne "/") {
        $installation_disk = get_installation_partition;
        assert_script_run("cd /");
        mount_installation_disk("$installation_disk", "$root_prefix");
    }

    my $wait_script = "30";
    my $get_active_eif = "ip link show | grep \"state UP\" | grep -v \"lo\" | cut -d: -f2 | cut -d\' \' -f2 | head -1";
    my $active_eif = script_output($get_active_eif, $wait_script, type_command => 1, proceed_on_failure => 0);
    my $get_active_eif_maddr = "ip link show | grep $active_eif -A1 | awk \'/link\\\/ether/ \{print \$2\}\' | awk \'\{print \$1,\$2,\$3,\$4,\$5,\$6\}\' FS=\":\" OFS=\"\"";
    my $active_eif_maddr = script_output($get_active_eif_maddr, $wait_script, type_command => 1, proceed_on_failure => 0);
    my $get_pxeboot_entry_eif = "$root_prefix/usr/sbin/efibootmgr -v | grep -i $active_eif_maddr";
    my $pxeboot_entry_eif = script_output($get_pxeboot_entry_eif, $wait_script, type_command => 1, proceed_on_failure => 0);
    my $pxeboot_entry_eif_count = script_output("$get_pxeboot_entry_eif | wc -l", $wait_script, type_command => 1, proceed_on_failure => 0);
    my $get_pxeboot_entry_ip4 = "";
    my $pxeboot_entry_ip4 = "";
    my $pxeboot_entry_ip4_count = "";
    if ($pxeboot_entry_eif_count gt 1) {
        $get_pxeboot_entry_ip4 = "$get_pxeboot_entry_eif | grep -i -E \"IP4|IPv4\"";
        $pxeboot_entry_ip4 = script_output($get_pxeboot_entry_ip4, $wait_script, type_command => 1, proceed_on_failure => 0);
        $pxeboot_entry_ip4_count = script_output("$get_pxeboot_entry_ip4 | wc -l", $wait_script, type_command => 1, proceed_on_failure => 0);
    }
    my $get_pxeboot_entry_pxe = "";
    my $pxeboot_entry_pxe = "";
    my $pxeboot_entry_pxe_count = "";
    if ($pxeboot_entry_ip4_count gt 1) {
        $get_pxeboot_entry_pxe = "$get_pxeboot_entry_ip4 | grep -i \"PXE\"";
        $pxeboot_entry_pxe = script_output($get_pxeboot_entry_pxe, $wait_script, type_command => 1, proceed_on_failure => 0);
        $pxeboot_entry_pxe_count = script_output("$get_pxeboot_entry_pxe | wc -l", $wait_script, type_command => 1, proceed_on_failure => 0);
        if ($pxeboot_entry_pxe_count gt 1) {
            die "The number of PXE boot entries can not be narrowed down to 1";
        }
    }
    my $get_pxeboot_entry_num_grep = "grep -o -i -e \"Boot[0-9]\\\{1,\\\}\" | grep -o -e \"[0-9]\\\{1,\\\}\"";
    my $get_pxeboot_entry_num = '';
    my $pxeboot_entry_num = '';
    if ($pxeboot_entry_eif_count eq '1') {
        $get_pxeboot_entry_num = "echo \"$pxeboot_entry_eif\" | $get_pxeboot_entry_num_grep";
    }
    elsif ($pxeboot_entry_ip4_count eq '1') {
        $get_pxeboot_entry_num = "echo \"$pxeboot_entry_ip4\" | $get_pxeboot_entry_num_grep";
    }
    else {
        $get_pxeboot_entry_num = "echo \"$pxeboot_entry_pxe\" | $get_pxeboot_entry_num_grep";
    }
    $pxeboot_entry_num = script_output($get_pxeboot_entry_num, $wait_script, type_command => 1, proceed_on_failure => 0);
    my $get_current_boot_num = "$root_prefix/usr/sbin/efibootmgr | grep -i BootCurrent | awk \'{print \$2}\'";
    my $current_boot_num = script_output($get_current_boot_num, $wait_script, type_command => 1, proceed_on_failure => 0);
    my $get_current_boot_order = "$root_prefix/usr/sbin/efibootmgr | grep -i BootOrder | awk \'{print \$2}\'";
    my $current_boot_order = (script_output($get_current_boot_order, $wait_script, type_command => 1, proceed_on_failure => 0));
    my @current_order_list = split(',', $current_boot_order);
    my @new_order_list = grep { $_ ne $current_boot_num && $_ ne $pxeboot_entry_num } @current_order_list;
    my $new_boot_order = '';
    if ($pxeboot_entry_num ne $current_boot_num) {
        $new_boot_order = join(',', $pxeboot_entry_num, $current_boot_num, @new_order_list);
    }
    else {
        $new_boot_order = join(',', $pxeboot_entry_num, @new_order_list);
    }
    assert_script_run("$root_prefix/usr/sbin/efibootmgr -o $new_boot_order");
    assert_script_run("$root_prefix/usr/sbin/efibootmgr -n $pxeboot_entry_num");

    #cleanup mount
    if ($root_prefix ne "/") {
        assert_script_run("cd /");
        umount_installation_disk("$root_prefix");
    }
}

#Usage:
#For post installation, use set_grub_on_vh(,...) directly
#For during installation, use set_grub_on_vh("/mnt",...)
#For custom usage, use set_grub_vh($mount_point, $installation_disk, $virt_type)
#Please pass desired hypervisor type to this function explicitly. There is no default value for $virt_type
sub set_grub_on_vh {
    my ($mount_point, $installation_disk, $virt_type) = @_;

    #prepare accessible grub
    my $root_dir;
    if ($mount_point ne "") {
        #when mount point is not empty, needs to mount installation disk
        if ($installation_disk eq "") {
            #search for the real installation partition on the first disk, which is selected by yast in ipmi installation
            $installation_disk = get_installation_partition;
        }
        #mount partition
        assert_script_run("cd /");
        mount_installation_disk("$installation_disk", "$mount_point");
        $root_dir = $mount_point;
    }
    else {
        $root_dir = "/";
    }

    #set up xen serial console
    my $ipmi_console = get_dom0_serialdev("$root_dir");
    if (${virt_type} eq "xen" || ${virt_type} eq "kvm") { setup_console_in_grub($ipmi_console, $root_dir, $virt_type); }
    else { die "Host Hypervisor is not xen or kvm"; }

    #Enabling SEV on the machine if it is running SEV/SEV-ES test
    enable_sev_in_kernel(root_dir => $root_dir) if (get_var('VIRT_SEV_ES_GUEST_INSTALL') and is_x86_64 and ${virt_type} eq "kvm");

    #cleanup mount
    if ($mount_point ne "") {
        assert_script_run("cd /");
        umount_installation_disk("$mount_point");
    }

}

#ipmitool to perform server management
sub ipmitool {
    my ($cmd) = @_;

    my @cmd = ('ipmitool', '-I', 'lanplus', '-H', $bmwqemu::vars{IPMI_HOSTNAME}, '-U', $bmwqemu::vars{IPMI_USER}, '-P', $bmwqemu::vars{IPMI_PASSWORD});
    push(@cmd, split(/ /, $cmd));

    my ($stdin, $stdout, $stderr, $ret);
    $ret = IPC::Run::run(\@cmd, \$stdin, \$stdout, \$stderr);
    chomp $stdout;
    chomp $stderr;

    bmwqemu::diag("IPMI: $stdout");
    return $stdout;
}

=head2 enable_sev_in_kernel

  enable_sev_in_kernel(dst_machine => $dst_machine, root_dir => $root_dir)

Enable SEV in the kernel, because it is disabled by default. This is done by putting
the following onto the kernel command line: mem_encrypt=on kvm_amd.sev=1. To make the 
changes persistent, append the above to the variable holding parameters of the kernel
command line in /etc/default/grub to preserve SEV settings across reboots:
$ cat /etc/default/grub
...
GRUB_CMDLINE_LINUX="... mem_encrypt=on kvm_amd.sev=1"
...
mem_encrypt=on turns on the SME memory encryption feature on the host which protects 
against the physical attack on the hypervisor memory. The kvm_amd.sev parameter 
actually enables SEV in the kvm module. This subroutine receives only two arguments,
the dst_machine is the host on which operations will be performed, the root_dir is 
the partition on which grub files reside. If these two arguments are not given any
values, operations will be performed on localhost and '/' partition. This subroutine
calls add_kernel_options to do the actual kernel options adding work.

=cut

sub enable_sev_in_kernel {
    my (%args) = @_;

    $args{dst_machine} //= 'localhost';
    $args{root_dir} //= '';
    $args{root_dir} .= '/' unless $args{root_dir} =~ /\/$/;
    croak("No AMD EPYC cpu on $args{dst_machine}, so sev can not be enabled in kernel.") unless (script_run("lscpu | grep -i \'AMD EPYC\'") == 0);
    add_kernel_options(dst_machine => $args{dst_machine}, root_dir => $args{root_dir}, kernel_opts => 'mem_encrypt=on kvm_amd.sev=1');
}

=head2 add_kernel_options

  add_kernel_options(dst_machine => $dst_machine, root_dir => $root_dir, 
  kernel_opts => $options, grub_to_change => [1|2|3])

Adding additional kernel options onto kernel command line in grub config file and 
also GRUB_CMDLINE_LINUX_DEFAULT line in default grub config file. This subroutine 
receives only four arguments, dst_machine is the host on which operations will be 
performed, root_dir is the partition on which grub files reside, kernel_opts holds 
a text string this is composed of terminal types separated by spaces, timeout has
the value of desired timeout of grub boot, and the grub_to_change indicates whether 
grub.cfg or default grub will be included to have these changes, including 1(Default 
value. Both grub.cfg and default grub will be changed), 2(Only the grub.cfg will 
be changed, 3(Only the default grub will be changed), and all the other values are 
invalid. If there are no values passed in to dst_machine and root_dir, operations 
will be performed on localhost and root '/' partition by default.

=cut

sub add_kernel_options {
    my (%args) = @_;

    $args{dst_machine} //= 'localhost';
    $args{root_dir} //= '';
    $args{root_dir} .= '/' unless $args{root_dir} =~ /\/$/;
    $args{kernel_opts} //= '';
    $args{grub_to_change} //= 1;
    croak("Nothing to be added onto kernel command line. Argument kernel_opts should not be empty.") if ($args{kernel_opts} eq '');
    if (($args{grub_to_change} != 1) and ($args{grub_to_change} != 2) and ($args{grub_to_change} != 3)) {
        croak("Nothing to be changed. Argument grub_to_change indicates neither grub.cfg nor default grub will be changed.");
    }

    my @options = split(/ /, $args{kernel_opts});
    my $cmd = '';
    if (($args{grub_to_change} == 1) or ($args{grub_to_change} == 2)) {
        my $grub_cfg_file = "$args{root_dir}boot/grub2/grub.cfg";
        foreach (@options) {
            $cmd = "sed -i -r \'s/\\b\\S*$_\\S*\\b//g; /^\\s{1,}(linux|linuxefi)\\s{1,}\\\/boot\\\// s/\$/ $_/g\' $grub_cfg_file";
            $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
            assert_script_run($cmd);
            save_screenshot;
        }
        $cmd = "cat $grub_cfg_file";
        $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
        record_info("Content of $grub_cfg_file on $args{dst_machine}", script_output($cmd, proceed_on_failure => 1));
    }

    if (($args{grub_to_change} == 1) or ($args{grub_to_change} == 3)) {
        my $grub_default_file = "$args{root_dir}etc/default/grub";
        foreach (@options) {
            $cmd = "sed -i -r \'s/\\b\\S*$_\\S*\\b//g; /GRUB_CMDLINE_LINUX_DEFAULT/ s/\\\"\$/ $_\\\"/g\' $grub_default_file";
            $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
            assert_script_run($cmd);
            save_screenshot;
        }
        $cmd = "cat $grub_default_file";
        $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
        record_info("Content of $grub_default_file on $args{dst_machine}", script_output($cmd, proceed_on_failure => 1));
    }
}

=head2 set_grub_terminal_and_timeout

  set_grub_terminal_and_timeou(dst_machine => $dst_machine, root_dir => $root_dir, 
  terminals => $terminals, timeout => $timeout, grub_to_change => [1|2|3])

Change grub boot terminal and timeout settings in grub configuration file and also 
GRUB_TERMINAL and GRUB_TIMEOUT in default grub configuration file. This subroutine
receives only five arguments, dst_machine is the host on which operations will be 
performed, root_dir is the partition on which grub files reside, terminals holds a 
single text string this is composed of kernel options separated by spaces, and
the grub_to_change indicates whether grub.cfg or default grub will be changed to
have the kernel_opts, including 1(Default value. Both grub.cfg and default grub
will be changed), 2(Only the grub.cfg will be changed, 3(Only the default grub will
be changed), and all the other values are invalid. If there are no values passed in
to dst_machine and root_dir, operations will be performed on localhost and root '/'
partition by default.  Almost all regular kernel options can be passed in directly
without modification except for very extreme cases in which very special characters
should be treated specially and even escaped before being used.

=cut

sub set_grub_terminal_and_timeout {
    my (%args) = @_;

    $args{dst_machine} //= 'localhost';
    $args{terminals} //= 'console serial';
    $args{timeout} //= '30';
    $args{root_dir} //= '';
    $args{root_dir} .= '/' unless $args{root_dir} =~ /\/$/;
    $args{grub_to_change} //= 1;
    if (($args{grub_to_change} != 1) and ($args{grub_to_change} != 2) and ($args{grub_to_change} != 3)) {
        croak("Nothing to be changed. Argument grub_to_change indicates neither grub.cfg nor default grub will be changed.");
    }

    my $cmd = '';
    if (($args{grub_to_change} == 1) or ($args{grub_to_change} == 2)) {
        my $grub_cfg_file = "$args{root_dir}boot/grub2/grub.cfg";
        $cmd = "sed -i -r '/^terminal.*\$/ {:mylabel; n; /^terminal.*\$/d;b mylabel;};' $grub_cfg_file; "
          . "sed -i -r 's/^terminal.*\$/terminal_input $args{terminals}\\nterminal_output $args{terminals}/g;' $grub_cfg_file; "
          . "sed -i -r '/set timeout=-{0,1}[0-9]{1,}/ s/timeout.*\$/timeout=$args{timeout}/g;' $grub_cfg_file";
        $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
        assert_script_run($cmd);
        save_screenshot;

        $cmd = "cat $grub_cfg_file";
        $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
        record_info("Content of $grub_cfg_file on $args{dst_machine}", script_output($cmd, proceed_on_failure => 1));
    }

    if (($args{grub_to_change} == 1) or ($args{grub_to_change} == 3)) {
        my $grub_default_file = "$args{root_dir}etc/default/grub";
        $cmd = "sed -i -r \'s/^#{0,}GRUB_TERMINAL=.*\$/GRUB_TERMINAL=\"$args{terminals}\"/' $grub_default_file; "
          . "sed -i -r \'s/^#{0,}GRUB_TIMEOUT=.*\$/GRUB_TIMEOUT=$args{timeout}/' $grub_default_file";
        $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
        assert_script_run($cmd);
        save_screenshot;

        $cmd = "cat $grub_default_file";
        $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
        record_info("Content of $grub_default_file on $args{dst_machine}", script_output($cmd, proceed_on_failure => 1));
    }
}

1;
