# VIRTUAL MACHINE AMD SEV-SNP FEATURES VERIFICATION MODULE
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module tests whether SEV-SNP virtual machine has
# been successfully installed on SEV-SNP enabled physical host by
# checking SEV-SNP support status on physical host in the first
# place and then virtual machine itself. It supports both traditional
# virt_autotest schedule (main_common.pm driven) and unified guest
# installation schedule.
#
# The module can run in two contexts:
# 1. Maintenance update mode: Uses ENABLE_SEV_SNP_GUEST_VERIFICATION=1
# 2. Unified guest installation: Uses VIRT_SEV_SNP_GUEST_INSTALL=1
#
# The module performs the following checks:
# - Verifies SEV-SNP support on host (kernel parameters, packages, firmware)
# - Configures and verifies SEV-SNP support on guests by:
#   - Updating VM XML configuration to add SEV-SNP security tags
#   - Removing incompatible features like TPM and SMM
#   - Verifying SEV-SNP activation in guest dmesg
#   - Running attestation verification when supported
# - Collects and uploads relevant logs for analysis
#
# Maintainer: QE-Virtualization <qe-virt@suse.de>

package sev_snp_guest_verification;

use base 'virt_feature_test_base';
use strict;
use warnings;
use File::Basename;
use testapi qw(record_soft_failure script_run script_output upload_logs select_console record_info get_var);
use IPC::Run;
use utils;
use virt_utils;
use virt_autotest::common;
use virt_autotest::utils qw(upload_virt_logs);
use version_utils qw(is_sle package_version_cmp);
use Utils::Architectures;
use bmwqemu;
use Utils::Logging;
use bootloader_setup qw(add_grub_cmdline_settings grub_mkconfig);
use power_action_utils 'power_action';
use utils 'zypper_call';

# Define constants for SNP verification
use constant {
    SNP_HOST_TOOLS     => ['sevctl', 'snphost', 'snpguest'],
    SNP_GUEST_TOOLS    => ['snpguest'],
    SNP_MIN_KERNEL_VER => '6.4.0',
    
    # Log files to collect
    HOST_LOG_FILES     => [
        '/var/log/messages',
        '/var/log/syslog',
        '/var/log/dmesg',
        '/proc/cmdline',
        '/sys/module/kvm_amd/parameters/sev',
        '/sys/module/kvm_amd/parameters/sev_es',
        '/sys/module/kvm_amd/parameters/sev_snp'
    ],
    GUEST_LOG_FILES    => [
        '/var/log/messages',
        '/var/log/syslog',
        '/var/log/dmesg',
        '/proc/cmdline'
    ],
    
    # Log directory for collecting all test artifacts
    LOG_DIR            => '/tmp/sev_snp_test_logs'
};

sub run_test {
    my $self = shift;
    
    # Create log directory for test run
    script_run("mkdir -p " . LOG_DIR);
    my $log_file = LOG_DIR . "/sev_snp_test.log";
    script_run("echo 'SEV-SNP verification test started at $(date)' > $log_file");

    # Determine test context
    my $is_unified_guest_install = get_var("VIRT_UNIFIED_GUEST_INSTALL", 0) || get_var("VIRT_SEV_SNP_GUEST_INSTALL", 0);
    my $is_maintenance_update_mode = get_var("ENABLE_SEV_SNP_GUEST_VERIFICATION", 1);
    
    # Log test context based on mode
    $self->_log_test_context($is_unified_guest_install, $is_maintenance_update_mode, $log_file);
    
    # Check SEV-SNP on host
    $self->check_sev_snp_on_host($log_file);
    
    # Check SEV-SNP on each guest
    foreach my $guest (keys %virt_autotest::common::guests) {
        script_run("echo '\\nChecking guest: $guest' >> $log_file");
        virt_autotest::utils::wait_guest_online($guest, 50, 1);    # 50 retries * ~7 seconds/retry, long enough
        $self->check_sev_snp_on_guest(guest_name => "$guest", log_file => $log_file);
    }
    
    # Upload logs at end of test
    script_run("echo 'SEV-SNP verification test completed at $(date)' >> $log_file");
    upload_logs($log_file, failok => 1, timeout => 180);
    
    return $self;
}

# Helper method to log test context
sub _log_test_context {
    my ($self, $is_unified_guest_install, $is_maintenance_update_mode, $log_file) = @_;
    
    # For unified guest installation context
    if ($is_unified_guest_install) {
        record_info('Unified Guest Context', 'Running in unified guest installation context');
        script_run("echo 'Running in unified guest installation context' >> $log_file");
        
        # Wait for guests to be available
        my $max_wait = 300; # 5 minutes max
        my $waited = 0;
        
        while ((keys %virt_autotest::common::guests) == 0 && $waited < $max_wait) {
            sleep(30);
            $waited += 30;
            script_run("echo 'Waiting for guests, elapsed time: $waited seconds' >> $log_file");
        }
        
        # Check if guests are available after waiting
        if ((keys %virt_autotest::common::guests) == 0) {
            record_info('No Guests Found', 'No guests were found after waiting for 5 minutes');
            script_run("echo 'ERROR: No guests were found after waiting for 5 minutes' >> $log_file");
            upload_logs($log_file, failok => 1, timeout => 180);
            return 0; # Indicates no guests found
        }
        
        return 1; # Guests found
    }
    # For maintenance update mode
    elsif ($is_maintenance_update_mode) {
        record_info('Maintenance Update Context', 'Running in maintenance update verification context');
        script_run("echo 'Running in maintenance update verification context' >> $log_file");
        return 1;
    }
    # No known mode specified
    else {
        record_info('Warning', 'Neither VIRT_SEV_SNP_GUEST_INSTALL nor ENABLE_SEV_SNP_GUEST_VERIFICATION is set');
        script_run("echo 'WARNING: Neither VIRT_SEV_SNP_GUEST_INSTALL nor ENABLE_SEV_SNP_GUEST_VERIFICATION is set' >> $log_file");
        return 1;
    }
}

=head2 check_sev_snp_on_host

  check_sev_snp_on_host($self)

Check whether AMD SEV-SNP feature is enabled and active on physical host
under test. This function checks the host system architecture, OS version,
kernel parameters, required packages, and kernel version.

Required kernel parameters for SEV-SNP:
- amd_iommu=on: Enables AMD IOMMU support (required for memory encryption)
- iommu=nopt: Enables IOMMU no pass-through mode
- mem_encrypt=on: Enables memory encryption features
- kvm_amd.sev=1: Enables AMD SEV (Secure Encrypted Virtualization) base functionality
- kvm-amd.sev_snp=1: Enables AMD SEV-SNP (Secure Nested Paging) functionality

=cut

sub check_sev_snp_on_host {
    my ($self, $log_file) = @_;
    $log_file //= LOG_DIR . "/sev_snp_host_check.log";

    record_info('Check SEV-SNP support status on host', 'Only 15-SP6+ and SLE16+ host supports AMD SEV-SNP.');
    script_run("echo '\\n=== Checking SEV-SNP support on host ===' >> $log_file");
    
    # Collect CPU information
    my $cpu_info = script_output("grep -m1 'model name' /proc/cpuinfo");
    script_run("echo 'CPU: $cpu_info' >> $log_file");
    
    # Check architecture
    unless (is_x86_64) {
        record_info('No AMD SEV-SNP feature available on host', 'Non x86_64 host does not support AMD SEV-SNP feature');
        script_run("echo 'Architecture: Non-x86_64 (Not Supported)' >> $log_file");
        upload_logs($log_file, failok => 1, timeout => 180);
        return $self;
    }
    
    script_run("echo 'Architecture: x86_64 (Supported)' >> $log_file");
    
    # Check OS version
    unless (is_sle('>=15-sp6') or is_sle('>=16')) {
        record_info('No AMD SEV-SNP feature available on host', 'Host is older than 15-SP6');
        script_run("echo 'OS Version: Older than SLES 15-SP6 (Not Supported)' >> $log_file");
        upload_logs($log_file, failok => 1, timeout => 180);
        return $self;
    }
    
    script_run("echo 'OS Version: SLES 15-SP6+ or 16+ (Supported)' >> $log_file");
    
    # For SLES 15-SP6 or 15-SP7, we need to activate the Confidential Computing module
    if (is_sle('=15-sp6') || is_sle('=15-sp7')) {
        # Get the SP version to form the correct module path
        my $sp_version = is_sle('=15-sp6') ? '15.6' : '15.7';
        record_info('Activating COCO module', "Activating Confidential Computing module for SLES $sp_version");
        script_run("echo 'Activating Confidential Computing module for SLES $sp_version' >> $log_file");
        
        my $module_path = "sle-module-confidential-computing/$sp_version/x86_64";
        my $ret = script_run("suseconnect -p $module_path");
        if ($ret != 0) {
            record_info('Module activation failed', 'Failed to activate Confidential Computing module', result => 'fail');
            script_run("echo 'ERROR: Failed to activate Confidential Computing module. This is required for SEV-SNP support.' >> $log_file");
            script_run("echo 'Please manually run: suseconnect -p $module_path' >> $log_file");
        } else {
            record_info('Module activated', 'Successfully activated Confidential Computing module');
            script_run("echo 'Successfully activated Confidential Computing module' >> $log_file");
            
            # Refresh repositories after module activation
            zypper_call('ref');
            script_run("echo 'Refreshed repositories after module activation' >> $log_file");
        }
    }
    
    # Check for SEV-SNP kernel boot parameters
    my $cmdline = script_output("cat /proc/cmdline");
    script_run("echo 'Kernel cmdline: $cmdline' >> $log_file");
    
    # Check for required kernel parameters
    my $has_amd_iommu = ($cmdline =~ /amd_iommu=on/);
    my $has_iommu_nopt = ($cmdline =~ /iommu=nopt/);
    my $has_mem_encrypt = ($cmdline =~ /mem_encrypt=on/);
    my $has_kvm_amd_sev = ($cmdline =~ /kvm_amd\.sev=1/);
    my $has_kvm_amd_sev_snp = ($cmdline =~ /kvm-amd\.sev_snp=1/);
    
    # Determine overall status
    my $all_params_present = $has_amd_iommu && 
                           $has_iommu_nopt && 
                           $has_mem_encrypt && 
                           $has_kvm_amd_sev && 
                           $has_kvm_amd_sev_snp;
    
    if ($all_params_present) {
        script_run("echo 'SEV-SNP boot parameters: All required parameters present' >> $log_file");
    } else {
        script_run("echo 'WARNING: SEV-SNP boot parameters: Missing required parameters' >> $log_file");
        
        # List missing parameters
        my @missing = ();
        push @missing, "amd_iommu=on" unless $has_amd_iommu;
        push @missing, "iommu=nopt" unless $has_iommu_nopt;
        push @missing, "mem_encrypt=on" unless $has_mem_encrypt;
        push @missing, "kvm_amd.sev=1" unless $has_kvm_amd_sev;
        push @missing, "kvm-amd.sev_snp=1" unless $has_kvm_amd_sev_snp;
        
        my $missing_list = join(", ", @missing);
        script_run("echo 'Missing parameters: $missing_list' >> $log_file");
        script_run("echo 'Required parameters (recommended order): amd_iommu=on iommu=nopt mem_encrypt=on kvm_amd.sev=1 kvm-amd.sev_snp=1' >> $log_file");
        
        # Automatically add the missing parameters
        record_info('Fixing GRUB', "Automatically adding missing SEV-SNP parameters to GRUB configuration");
        script_run("echo 'Automatically adding missing parameters to GRUB...' >> $log_file");
        
        # Add each missing parameter using the repository function
        my $update_needed = 0;
        foreach my $param (@missing) {
            script_run("echo 'Adding parameter: $param' >> $log_file");
            add_grub_cmdline_settings($param);
            $update_needed = 1;
        }
        
        # Generate new GRUB configuration if parameters were added
        if ($update_needed) {
            # Generate new GRUB configuration
            script_run("echo 'Updating GRUB configuration with grub2-mkconfig...' >> $log_file");
            
            # Run grub_mkconfig from the repository function
            grub_mkconfig();
            
            my $mkconfig_result = $? >> 8;
            if ($mkconfig_result != 0) {
                script_run("echo 'ERROR: Failed to update GRUB configuration with grub2-mkconfig' >> $log_file");
                record_info('GRUB update failed', "Failed to update GRUB configuration with grub2-mkconfig");
                return 0;
            }
            
            script_run("echo 'Successfully updated GRUB configuration. Rebooting to apply new parameters...' >> $log_file");
            record_info('GRUB update success', "Successfully updated GRUB configuration. Rebooting to apply new parameters.");
            
            # Create flag file for detecting reboot state
            script_run("touch " . LOG_DIR . "/reboot_for_sev_snp_params");
            upload_logs($log_file, failok => 1, timeout => 180);
            
            # Use standard power_action function to reboot the system
            power_action('reboot', textmode => 1);
            
            # Use standard wait_boot method to wait for system to fully boot
            $self->wait_boot(textmode => 1);
            
            # Login to console after reboot
            select_console('root-console');
            
            # Verify if parameters were applied after reboot
            my $new_cmdline = script_output("cat /proc/cmdline");
            script_run("echo 'New kernel cmdline after reboot: $new_cmdline' >> $log_file");
            
            # Check if all required parameters exist
            my $has_all_params = ($new_cmdline =~ /amd_iommu=on/) && 
                               ($new_cmdline =~ /iommu=nopt/) && 
                               ($new_cmdline =~ /mem_encrypt=on/) && 
                               ($new_cmdline =~ /kvm_amd\.sev=1/) && 
                               ($new_cmdline =~ /kvm-amd\.sev_snp=1/);
                               
            if (!$has_all_params) {
                record_info('Parameter Update Failed', "Not all required SEV-SNP parameters were applied after reboot");
                script_run("echo 'ERROR: Not all SEV-SNP parameters were applied despite reboot' >> $log_file");
                upload_logs($log_file, failok => 1, timeout => 180);
                return 0;
            }
            
            record_info('Parameters Applied', "All SEV-SNP parameters successfully applied after reboot");
            script_run("echo 'All SEV-SNP parameters successfully applied after reboot' >> $log_file");
        }
    }
    
    # Check for required packages
    my $missing_pkgs = $self->check_snp_packages(required_pkgs => SNP_HOST_TOOLS, log_file => $log_file);
    if ($missing_pkgs) {
        record_info('Missing SNP packages', "The following packages are missing: $missing_pkgs. Will attempt to install them.");
        script_run("echo 'Missing SEV-SNP packages: $missing_pkgs. Attempting to install...' >> $log_file");
        
        # Convert comma-separated list to space-separated list for zypper
        # check_snp_packages returns comma-separated format (pkg1, pkg2, pkg3)
        # but zypper needs space-separated format (pkg1 pkg2 pkg3)
        $missing_pkgs =~ s/,\s*/ /g;
        
        # Try to install the missing packages using zypper_call
        my $install_result = eval { zypper_call("in $missing_pkgs"); 1 } || 0;
        
        if (!$install_result) {
            record_info('Package Installation Failed', "Failed to install missing packages: $missing_pkgs", result => 'fail');
            script_run("echo 'ERROR: Failed to install missing packages. zypper_call failed' >> $log_file");
            script_run("echo 'Please install these packages manually and try again.' >> $log_file");
            upload_logs($log_file, failok => 1, timeout => 180);
            return $self;
        }
        
        # Verify packages were installed successfully
        my $verify_missing = $self->check_snp_packages(required_pkgs => SNP_HOST_TOOLS, log_file => $log_file);
        if ($verify_missing) {
            record_info('Package Verification Failed', "Some packages are still missing after installation attempt: $verify_missing", result => 'fail');
            script_run("echo 'ERROR: Some packages are still missing after installation attempt: $verify_missing' >> $log_file");
            upload_logs($log_file, failok => 1, timeout => 180);
            return $self;
        }
        
        record_info('Packages Successfully Installed', "All required packages have been successfully installed");
        script_run("echo 'All required SEV-SNP packages were successfully installed' >> $log_file");
    } else {
        record_info('SNP packages installed', 'All required SEV-SNP packages are already installed');
        script_run("echo 'All required SEV-SNP packages are already installed' >> $log_file");
    }
    
    # Check kernel version
    my $kernel_ver = script_output('uname -r');
    script_run("echo 'Kernel version: $kernel_ver' >> $log_file");
    
    unless ($kernel_ver =~ /^([\d\.]+)/) {
        script_run("echo 'Could not parse kernel version' >> $log_file");
        upload_logs($log_file, failok => 1, timeout => 180);
        return $self;
    }
    
    my $kern_base_ver = $1;
    # Using package_version_cmp to compare versions
    if (package_version_cmp($kern_base_ver, SNP_MIN_KERNEL_VER) < 0) {
        record_info('Kernel version too old', "Kernel version $kernel_ver is below minimum required version " . SNP_MIN_KERNEL_VER);
        script_run("echo 'Kernel version check: Failed (< " . SNP_MIN_KERNEL_VER . ")' >> $log_file");
        upload_logs($log_file, failok => 1, timeout => 180);
        return $self;
    }
    
    record_info('Kernel version check', "Kernel version $kernel_ver meets minimum requirement");
    script_run("echo 'Kernel version check: Passed (>= " . SNP_MIN_KERNEL_VER . ")' >> $log_file");
    
    # Run snphost check
    $self->run_snphost_checks($log_file);
    
    # Collect SEV-SNP specific logs from host
    $self->collect_host_logs($log_file);
    
    # Upload the host check log
    upload_logs($log_file, failok => 1, timeout => 180);
    
    return $self;
}

=head2 configure_guest_for_sev_snp

  configure_guest_for_sev_snp($self, guest_name => 'name', log_file => 'path')

Configure a guest VM with SEV-SNP support by:
1. Dumping the current XML configuration
2. Modifying it to include SEV-SNP configuration
3. Undefining the VM and redefining it with the new configuration
4. Starting the VM with the new configuration

=cut

sub configure_guest_for_sev_snp {
    my ($self, %args) = @_;
    $args{guest_name} //= '';
    $args{log_file} //= LOG_DIR . "/sev_snp_guest_config.log";
    
    die 'Guest name must be given to configure SEV-SNP for a guest VM.' if ($args{guest_name} eq '');
    
    my $guest_name = $args{guest_name};
    my $log_file = $args{log_file};
    
    record_info('SEV-SNP Configuration', "Configuring SEV-SNP for guest $guest_name");
    script_run("echo '\\n=== Configuring SEV-SNP for guest: $guest_name ===' >> $log_file");
    
    # Check if VM is running, if so, shut it down
    my $vm_state = script_output("virsh domstate $guest_name 2>/dev/null || echo 'not-found'", proceed_on_failure => 1);
    if ($vm_state eq 'running') {
        record_info('Shutting down VM', "Guest $guest_name is running, shutting it down");
        script_run("echo 'VM $guest_name is running, shutting it down' >> $log_file");
        
        # Try graceful shutdown first
        my $shutdown_ret = script_run("virsh shutdown $guest_name");
        if ($shutdown_ret == 0) {
            # Wait for VM to shut down gracefully (max 60 seconds)
            script_run("echo 'Waiting for VM to shut down gracefully...' >> $log_file");
            my $wait_count = 0;
            while ($wait_count < 60) {
                my $state = script_output("virsh domstate $guest_name 2>/dev/null || echo 'not-found'", proceed_on_failure => 1);
                if ($state eq 'shut off' || $state eq 'not-found') {
                    script_run("echo 'VM successfully shut down' >> $log_file");
                    last;
                }
                sleep(1);
                $wait_count++;
            }
            
            # If VM is still running after 60 seconds, force it off
            my $final_state = script_output("virsh domstate $guest_name 2>/dev/null || echo 'not-found'", proceed_on_failure => 1);
            if ($final_state eq 'running') {
                record_info('Forcing VM off', "Guest $guest_name did not shut down gracefully, forcing off");
                script_run("echo 'VM did not shut down gracefully, forcing off' >> $log_file");
                script_run("virsh destroy $guest_name");
            }
        } else {
            # If shutdown failed, force it off
            record_info('Forcing VM off', "Could not gracefully shut down guest $guest_name, forcing off");
            script_run("echo 'Could not gracefully shut down VM, forcing off' >> $log_file");
            script_run("virsh destroy $guest_name");
        }
    } elsif ($vm_state eq 'not-found') {
        record_info('VM not found', "Guest $guest_name not found, checking domain list");
        script_run("echo 'VM $guest_name not found, checking domain list' >> $log_file");
        script_run("virsh list --all >> $log_file");
        die "Guest VM $guest_name not found, cannot continue with SEV-SNP configuration";
    }
    
    # Step 1: Dump the current XML configuration
    script_run("echo 'Step 1: Dumping current XML configuration for $guest_name' >> $log_file");
    my $xml_file = "/tmp/$guest_name.xml";
    my $dump_ret = script_run("virsh dumpxml $guest_name > $xml_file");
    if ($dump_ret != 0) {
        record_info('XML Dump Failed', "Failed to dump XML for guest $guest_name", result => 'fail');
        script_run("echo 'Failed to dump XML configuration' >> $log_file");
        return 0;
    }
    
    # Get QEMU version to determine the machine type
    script_run("echo 'Checking QEMU version to determine machine type' >> $log_file");
    my $qemu_version = script_output("qemu-system-x86_64 --version | head -1 | awk '{print \$4}' | cut -d'.' -f1,2", proceed_on_failure => 1);
    my $machine_type = "pc-q35-$qemu_version";
    script_run("echo 'Detected QEMU version: $qemu_version, will use machine type: $machine_type' >> $log_file");
    
    # Step 2: Create a new XML configuration with SEV-SNP support
    script_run("echo 'Step 2: Creating new XML configuration with SEV-SNP support' >> $log_file");
    
    # First, check if SEV-SNP is already configured
    my $sev_snp_check = script_run("grep -q '<launchSecurity type=\"sev-snp\">' $xml_file");
    if ($sev_snp_check == 0) {
        record_info('SEV-SNP Already Configured', "SEV-SNP already configured for guest $guest_name, no changes needed");
        script_run("echo 'SEV-SNP already configured for guest, no changes needed' >> $log_file");
        return 1;
    }
    
    # Create backup of original XML
    script_run("cp $xml_file ${xml_file}.backup");
    
    # Remove TPM and SMM tags as they're incompatible with SEV-SNP
    script_run("echo 'Removing TPM and SMM tags (incompatible with SEV-SNP)' >> $log_file");
    
    # Check for TPM and SMM tags in the XML file and remove them if found
    my $tpm_check = script_output("grep -c '<tpm' $xml_file || echo '0'", proceed_on_failure => 1);
    my $smm_check = script_output("grep -c '<smm' $xml_file || echo '0'", proceed_on_failure => 1);
    
    # Handle TPM tags if found
    if ($tpm_check ne '0') {
        script_run("echo 'TPM configuration details:' >> $log_file");
        script_run("grep -A10 -B2 '<tpm' $xml_file >> $log_file");
        record_soft_failure("bsc#1244308 - TPM device configuration found in VM XML which is incompatible with SEV-SNP");
        script_run("echo 'WARNING: TPM device found, incompatible with SEV-SNP (bsc#1244308)' >> $log_file");
        
        # Remove TPM tags (including all content between opening and closing tags)
        script_run("echo 'Removing TPM tags from XML file' >> $log_file");
        script_run("sed -i '/<tpm/,/<\\/tpm>/d' $xml_file");
    } else {
        script_run("echo 'No TPM configuration detected (good)' >> $log_file");
    }
    
    # Handle SMM tags if found
    if ($smm_check ne '0') {
        script_run("echo 'SMM configuration details:' >> $log_file");
        script_run("grep -A2 -B2 '<smm' $xml_file >> $log_file");
        record_info('SMM Incompatibility', "SMM configuration found in VM XML which is incompatible with SEV-SNP, will be removed", result => 'softfail');
        script_run("echo 'WARNING: SMM configuration found, incompatible with SEV-SNP' >> $log_file");
        
        # Remove SMM tags (any SMM tag regardless of attributes)
        script_run("echo 'Removing SMM tags from XML file' >> $log_file");
        script_run("sed -i '/<smm[^>]*>/d' $xml_file");
    } else {
        script_run("echo 'No SMM configuration detected (good)' >> $log_file");
    }
    
    # Check if we need to update the OS/machine type section
    my $os_section_check = script_output("grep -A3 '<os' $xml_file | grep -c 'machine=' || echo '0'", proceed_on_failure => 1);
    
    # Prepare sed commands for XML modifications
    my $os_section_update = '';
    if ($os_section_check ne '0') {
        # Update existing OS section with correct machine type and loader
        $os_section_update = "sed -i '/<os/,/<\\/os>/c\\
<os>\\
  <type arch=\"x86_64\" machine=\"$machine_type\">hvm</type>\\
  <loader readonly=\"yes\" type=\"rom\">/usr/share/qemu/ovmf-x86_64-sev.bin</loader>\\
  <boot dev=\"hd\"/>\\
</os>' $xml_file";
    } else {
        # Add new OS section before </domain>
        $os_section_update = "sed -i '/<\\/domain>/i\\
<os>\\
  <type arch=\"x86_64\" machine=\"$machine_type\">hvm</type>\\
  <loader readonly=\"yes\" type=\"rom\">/usr/share/qemu/ovmf-x86_64-sev.bin</loader>\\
  <boot dev=\"hd\"/>\\
</os>' $xml_file";
    }
    
    # Execute the OS section update
    script_run($os_section_update);
    
    # Add the SEV-SNP launch security section before </domain>
    script_run("sed -i '/<\\/domain>/i\\
<launchSecurity type=\"sev-snp\">\\
  <policy>0x00030000</policy>\\
</launchSecurity>' $xml_file");
    
    # Step 3: Undefine the current guest and define with new XML
    script_run("echo 'Step 3: Undefining current guest and defining with new SEV-SNP XML' >> $log_file");
    my $undefine_ret = script_run("virsh undefine $guest_name --vnram");
    if ($undefine_ret != 0) {
        record_info('Undefine Failed', "Failed to undefine guest $guest_name", result => 'fail');
        script_run("echo 'Failed to undefine guest, attempting to restore from backup' >> $log_file");
        # Try to restore from backup
        script_run("virsh define ${xml_file}.backup");
        return 0;
    }
    
    # Define the VM with the new XML
    my $define_ret = script_run("virsh define $xml_file");
    if ($define_ret != 0) {
        record_info('Define Failed', "Failed to define guest $guest_name with new XML", result => 'fail');
        script_run("echo 'Failed to define guest with new XML, attempting to restore from backup' >> $log_file");
        # Try to restore from backup
        script_run("virsh define ${xml_file}.backup");
        return 0;
    }
    
    script_run("echo 'Guest successfully redefined with SEV-SNP support' >> $log_file");
    
    # Step 4: Start the guest with the new configuration
    script_run("echo 'Step 4: Starting guest with SEV-SNP configuration' >> $log_file");
    my $start_ret = script_run("virsh start $guest_name");
    if ($start_ret != 0) {
        record_info('Start Failed', "Failed to start guest $guest_name with SEV-SNP configuration", result => 'fail');
        script_run("echo 'Failed to start guest with SEV-SNP configuration' >> $log_file");
        script_run("echo 'Error details:' >> $log_file");
        script_run("virsh start $guest_name --verbose 2>&1 >> $log_file");
        
        # Try to start with original configuration
        script_run("echo 'Attempting to restore and start with original configuration' >> $log_file");
        script_run("virsh undefine $guest_name");
        script_run("virsh define ${xml_file}.backup");
        script_run("virsh start $guest_name");
        
        return 0;
    }
    
    record_info('SEV-SNP Configured', "Guest $guest_name successfully configured with SEV-SNP support and started");
    script_run("echo 'Guest successfully started with SEV-SNP configuration' >> $log_file");
    
    # Wait for the VM to boot
    script_run("echo 'Waiting for guest to become available...' >> $log_file");
    virt_autotest::utils::wait_guest_online($guest_name, 50, 1);
    return 1;
}

=head2 check_sev_snp_on_guest

  check_sev_snp_on_guest($self, guest_name => 'name')

Check whether AMD SEV-SNP feature is enabled and active on virtual machine. 
This function configures the guest for SEV-SNP support and then verifies if 
SEV-SNP is active in the guest's dmesg output by checking for the "SEV-SNP" 
keyword in the "Memory Encryption Features active" line.

=cut

sub check_sev_snp_on_guest {
    my ($self, %args) = @_;
    $args{guest_name} //= '';
    $args{log_file} //= LOG_DIR . "/sev_snp_guest_check.log";
    
    die 'Guest name must be given to perform following operations.' if ($args{guest_name} eq '');

    my $guest_name = $args{guest_name};
    my $log_file = $args{log_file};
    my $guest_type = 'unknown'; # Will be set to 'sev-snp' if verification passes

    record_info("Check SEV-SNP support status on guest $guest_name", "Guest can be installed with SEV-SNP enabled by specifying corresponding policy.");
    script_run("echo '\\n=== Checking SEV-SNP support on guest: $guest_name ===' >> $log_file");

    # Configure guest for SEV-SNP if not already configured
    my $config_result = $self->configure_guest_for_sev_snp(guest_name => $guest_name, log_file => $log_file);
    if (!$config_result) {
        record_info('SEV-SNP Configuration Failed', "Failed to configure SEV-SNP for guest $guest_name", result => 'fail');
        script_run("echo 'ERROR: Failed to configure SEV-SNP for guest $guest_name' >> $log_file");
        script_run("echo 'Continuing with verification to check current status' >> $log_file");
    } else {
        record_info('SEV-SNP Configured', "Successfully configured SEV-SNP for guest $guest_name");
        script_run("echo 'Successfully configured SEV-SNP for guest $guest_name' >> $log_file");
    }
    
    # Check if SEV-SNP is enabled in guest's dmesg
    script_run("echo 'Checking for SEV-SNP in guest dmesg...' >> $log_file");
    
    # First try to search specifically for the Memory Encryption Features line
    my $dmesg_cmd = "ssh root\@$guest_name \"dmesg | grep -i 'Memory Encryption Features active'\" 2>/dev/null";
    my $dmesg_output = script_output($dmesg_cmd, proceed_on_failure => 1);
    
    # Define the expected pattern for SEV-SNP
    my $expected_pattern = 'Memory Encryption Features active.*AMD SEV SEV-ES SEV-SNP';
    
    # Check if pattern is found
    if ($dmesg_output =~ /$expected_pattern/) {
        record_info('SEV-SNP Active', "SEV-SNP is active in guest $guest_name", result => 'ok');
        script_run("echo 'SEV-SNP active in guest dmesg: $dmesg_output' >> $log_file");
        
        # Set guest type for later use
        $guest_type = 'sev-snp';
        script_run("echo 'Guest type confirmed as: $guest_type' >> $log_file");
    } else {
        record_info('SEV-SNP Not Active', "SEV-SNP is not active in guest $guest_name", result => 'fail');
        script_run("echo 'ERROR: SEV-SNP not found in guest dmesg' >> $log_file");
        
        die "SEV-SNP is not active for guest $guest_name";
    }
    
    # For SEV-SNP guests, perform additional verification
    if ($guest_type eq 'sev-snp') {
        # Wait for guest to be online before further checks
        virt_autotest::utils::wait_guest_online($guest_name, 50, 1);
        
        # Check for required packages on guest
        my $missing_pkgs = $self->check_snp_packages(
            required_pkgs => SNP_GUEST_TOOLS,
            dst_machine => $guest_name,
            log_file => $log_file
        );
        
        if ($missing_pkgs) {
            record_info("Missing packages on guest", "The following packages are missing on guest: $missing_pkgs. Will attempt to install them.");
            script_run("echo 'Missing SEV-SNP packages on guest: $missing_pkgs. Attempting to install...' >> $log_file");
            
            # Convert comma-separated list to space-separated list for zypper
            # check_snp_packages returns comma-separated format (pkg1, pkg2, pkg3)
            # but zypper needs space-separated format (pkg1 pkg2 pkg3)
            $missing_pkgs =~ s/,\s*/ /g;
            
            # Try to install the missing packages on the guest using zypper_call remotely
            my $install_cmd = "ssh root\@$guest_name \"zypper --non-interactive in $missing_pkgs\"";
            my $install_result = script_run($install_cmd);
            
            if ($install_result != 0) {
                record_info('Guest Package Installation Failed', "Failed to install missing packages on guest: $missing_pkgs", result => 'warn');
                script_run("echo 'WARNING: Failed to install missing packages on guest. Command \"$install_cmd\" returned: $install_result' >> $log_file");
                script_run("echo 'Continuing with limited functionality due to missing packages.' >> $log_file");
            } else {
                # Verify packages were installed successfully
                my $verify_missing = $self->check_snp_packages(
                    required_pkgs => SNP_GUEST_TOOLS,
                    dst_machine => $guest_name,
                    log_file => $log_file
                );
                
                if ($verify_missing) {
                    record_info('Guest Package Verification Failed', "Some packages are still missing after installation attempt: $verify_missing", result => 'warn');
                    script_run("echo 'WARNING: Some packages are still missing on guest after installation attempt: $verify_missing' >> $log_file");
                    script_run("echo 'Continuing with limited functionality due to missing packages.' >> $log_file");
                } else {
                    record_info('Guest Packages Successfully Installed', "All required packages have been successfully installed on guest");
                    script_run("echo 'All required SEV-SNP packages were successfully installed on guest' >> $log_file");
                }
            }
        } else {
            record_info("SNP packages installed on guest", "All required SEV-SNP packages are already installed on guest");
            script_run("echo 'All required SEV-SNP packages are already installed on guest' >> $log_file");
        }
        
        # Verify attestation report if possible
        $self->verify_guest_attestation(guest_name => $guest_name, log_file => $log_file);
    }
    
    # Collect guest logs regardless of verification result
    $self->collect_guest_logs($guest_name, $log_file);
    
    # Upload the guest check log immediately
    upload_logs($log_file, failok => 1, timeout => 180);
    
    return $self;
}

=head2 check_snp_packages

  check_snp_packages($self, required_pkgs => ['pkg1', 'pkg2'], [dst_machine => 'machine'])

Check whether the required packages for SEV-SNP are installed on the system.
Returns a string with missing packages or empty string if all packages are installed.

This function:
1. Takes a list of required packages to check
2. Optionally checks on a remote machine via SSH (specify dst_machine parameter)
3. Returns a comma-separated list of missing packages, or empty string if all are installed
4. Logs the results to the specified log file if provided

=cut

sub check_snp_packages {
    my ($self, %args) = @_;
    $args{required_pkgs} //= [];
    $args{dst_machine} //= 'localhost';
    $args{log_file} //= '';
    
    my @missing_pkgs;
    my $is_local = ($args{dst_machine} eq 'localhost');
    
    if ($args{log_file}) {
        script_run("echo '\\n--- Checking required packages ---' >> $args{log_file}");
        script_run("echo 'Checking packages on $args{dst_machine}: " . join(', ', @{$args{required_pkgs}}) . "' >> $args{log_file}");
    }
    
    foreach my $pkg (@{$args{required_pkgs}}) {
        my $ret;
        
        if ($is_local) {
            # For localhost, use script_run directly
            $ret = script_run("rpm -q $pkg");
        } else {
            # For remote machines, use SSH
            $ret = script_run("ssh root\@$args{dst_machine} \"rpm -q $pkg\"");
        }
        
        if ($args{log_file}) {
            my $status = ($ret == 0) ? "installed" : "missing";
            script_run("echo 'Package $pkg: $status' >> $args{log_file}");
        }
        
        push @missing_pkgs, $pkg if $ret != 0;
    }
    
    my $result = join(', ', @missing_pkgs);
    
    if ($args{log_file}) {
        if ($result) {
            script_run("echo 'Missing packages: $result' >> $args{log_file}");
        } else {
            script_run("echo 'All required packages are installed' >> $args{log_file}");
        }
    }
    
    return $result;
}

=head2 run_snphost_checks

  run_snphost_checks($self, $log_file)

Run various snphost commands to verify SEV-SNP functionality on the host.
This function:
1. Sets up the MSR module required for SEV-SNP verification
2. Runs snphost tool to verify SEV-SNP status on the host
3. Validates the output for any FAIL statuses that would indicate problems
4. Logs all results to the specified log file

=cut

sub run_snphost_checks {
    my ($self, $log_file) = @_;
    $log_file //= '';
    
    if ($log_file) {
        script_run("echo '\\n--- Running snphost commands ---' >> $log_file");
    }
    
    # Implement MSR module loading workaround for bugzilla #1237858
    $self->setup_msr_module($log_file);
    
    # Run snphost tool to verify SEV-SNP status on host
    my $snphost_cmd = 'snphost ok';
    if ($log_file) {
        script_run("echo 'Running command: $snphost_cmd' >> $log_file");
    }
    
    my $snphost_output = script_output($snphost_cmd, proceed_on_failure => 1);
    
    # Parse the output to count successes and failures
    my $fail_count = () = $snphost_output =~ /\[ FAIL \]/g;
    my $pass_count = () = $snphost_output =~ /\[ PASS \]/g;
    
    if ($log_file) {
        script_run("echo 'SNPHost results: $pass_count passes, $fail_count failures' >> $log_file");
        script_run("echo 'SNPHost Output:\\n$snphost_output' >> $log_file");
    }
    
    if ($fail_count > 0) {
        record_info('SNPHost Status FAILED', "snphost check failed with $fail_count failure(s):\n$snphost_output", result => 'fail');
        if ($log_file) {
            script_run("echo 'SNPHost Status: FAILED with $fail_count failure(s)' >> $log_file");
        }
        # Terminate the test if there are any FAIL results
        die "SNPHost verification failed with $fail_count FAIL results. Test terminated.";
    } else {
        record_info('SNPHost Status PASSED', "snphost status passed with $pass_count passes and no failures", result => 'ok');
        if ($log_file) {
            script_run("echo 'SNPHost Status: PASSED with no failures' >> $log_file");
        }
    }
    
    return;
}

=head2 setup_msr_module

  setup_msr_module($self, $log_file)

Set up the MSR module required for SEV-SNP functionality. This function:
1. Creates /etc/modules-load.d/msr.conf to ensure the module is loaded on boot
2. Loads the MSR module immediately using modprobe
3. Verifies the module was loaded successfully

This addresses bugzilla #1237858 by implementing a proper workaround.

=cut

sub setup_msr_module {
    my ($self, $log_file) = @_;
    
    # Record soft failure with reference to the bugzilla issue
    record_soft_failure("bsc#1237858 - MSR module might not be loaded, implementing workaround");
    
    if ($log_file) {
        script_run("echo 'Setting up MSR module for SEV-SNP tests' >> $log_file");
    }
    
    # Step 1: Create /etc/modules-load.d/msr.conf to ensure module is loaded on reboot
    if ($log_file) {
        script_run("echo 'Step 1: Creating /etc/modules-load.d/msr.conf' >> $log_file");
    }
    
    # Create directory and file in one operation, overwriting if it exists
    script_run("mkdir -p /etc/modules-load.d/");
    script_run("echo 'msr' > /etc/modules-load.d/msr.conf");
    
    record_info('MSR Config', "Created /etc/modules-load.d/msr.conf with content: msr");
    
    # Step 2: Load the MSR module
    if ($log_file) {
        script_run("echo 'Step 2: Loading MSR module with modprobe' >> $log_file");
    }
    
    # Always run modprobe regardless of current state
    script_run("modprobe msr");
    
    # Step 3: Verify MSR module was loaded successfully
    if ($log_file) {
        script_run("echo 'Step 3: Verifying MSR module is loaded' >> $log_file");
    }
    
    my $verify_msr = script_run("lsmod | grep -q msr");
    if ($verify_msr != 0) {
        record_info('MSR Module Error', "Failed to load MSR module which is required for snphost commands", result => 'fail');
        if ($log_file) {
            script_run("echo 'ERROR: Failed to load MSR module. This may cause snphost commands to fail.' >> $log_file");
        }
        return 0;  # Return failure
    } else {
        record_info('MSR Module Loaded', "MSR module is loaded and ready for use");
        if ($log_file) {
            script_run("echo 'MSR module is loaded and ready for use' >> $log_file");
            script_run("lsmod | grep msr >> $log_file");
        }
        return 1;  # Return success
    }
}

=head2 verify_guest_attestation

  verify_guest_attestation($self, guest_name => 'name')

Generate and verify an attestation report for an SEV-SNP guest.

=cut

sub verify_guest_attestation {
    my ($self, %args) = @_;
    $args{guest_name} //= '';
    $args{log_file} //= '';
    
    die 'Guest name must be given to perform attestation verification.' if ($args{guest_name} eq '');
    
    my $guest_name = $args{guest_name};
    my $log_file = $args{log_file};
    
    if ($log_file) {
        script_run("echo '\\n--- Verifying guest attestation for $guest_name ---' >> $log_file");
    }
    
    # Make sure guest is online
    virt_autotest::utils::wait_guest_online($guest_name, 50, 1);
    
    # Create a temporary directory for attestation artifacts
    my $temp_dir = "/tmp/sev_snp_attestation_" . time();
    my $mkdir_cmd = "ssh root\@$guest_name \"mkdir -p $temp_dir\"";
    script_run($mkdir_cmd);
    
    if ($log_file) {
        script_run("echo 'Created attestation directory: $temp_dir' >> $log_file");
    }
    
    # Generate a request file with random data
    my $dd_cmd = "ssh root\@$guest_name \"dd if=/dev/urandom of=$temp_dir/request-file.bin bs=64 count=1\"";
    script_run($dd_cmd);
    
    if ($log_file) {
        script_run("echo 'Generated random request file' >> $log_file");
    }
    
    # Generate attestation report
    my $report_cmd = "ssh root\@$guest_name \"snpguest report $temp_dir/attestation-report.bin $temp_dir/request-file.bin\"";
    my $report_ret = script_run($report_cmd, timeout => 60);
    
    if ($report_ret != 0) {
        record_info('Attestation Report Failed', "Failed to generate attestation report on guest $guest_name");
        if ($log_file) {
            script_run("echo 'FAILED: Could not generate attestation report' >> $log_file");
        }
        $self->_cleanup_attestation_dir($guest_name, $temp_dir, $log_file);
        return;
    }
    
    record_info('Attestation Report Generated', "Successfully generated attestation report on guest $guest_name");
    if ($log_file) {
        script_run("echo 'Successfully generated attestation report' >> $log_file");
    }
    
    # Create directory for certificates
    my $certs_cmd = "ssh root\@$guest_name \"mkdir -p $temp_dir/certs-kds\"";
    script_run($certs_cmd);
    
    # Fetch AMD CA certificates
    if ($log_file) {
        script_run("echo 'Fetching AMD CA certificates...' >> $log_file");
    }
    
    my $ca_cmd = "ssh root\@$guest_name \"snpguest fetch ca der milan $temp_dir/certs-kds\"";
    my $ca_ret = script_run($ca_cmd, timeout => 90);
    
    if ($ca_ret != 0) {
        record_info('CA Fetch Failed', "Failed to fetch CA certificates on guest $guest_name");
        if ($log_file) {
            script_run("echo 'FAILED: Could not fetch CA certificates' >> $log_file");
        }
        $self->_cleanup_attestation_dir($guest_name, $temp_dir, $log_file);
        return;
    }
    
    # Fetch VCEK certificate
    if ($log_file) {
        script_run("echo 'Fetching VCEK certificate...' >> $log_file");
    }
    
    my $vcek_cmd = "ssh root\@$guest_name \"snpguest fetch vcek der milan $temp_dir/certs-kds $temp_dir/attestation-report.bin\"";
    my $vcek_ret = script_run($vcek_cmd, timeout => 90);
    
    if ($vcek_ret != 0) {
        record_info('VCEK Fetch Failed', "Failed to fetch VCEK certificate on guest $guest_name");
        if ($log_file) {
            script_run("echo 'FAILED: Could not fetch VCEK certificate' >> $log_file");
        }
        $self->_cleanup_attestation_dir($guest_name, $temp_dir, $log_file);
        return;
    }
    
    # Verify attestation report
    if ($log_file) {
        script_run("echo 'Verifying attestation report...' >> $log_file");
    }
    
    my $verify_cmd = "ssh root\@$guest_name \"snpguest verify attestation $temp_dir/certs-kds $temp_dir/attestation-report.bin\"";
    my $verify_output = script_output($verify_cmd, proceed_on_failure => 1);
    
    # Check if verification was successful
    my $is_verified = $verify_output =~ /VEK signed the Attestation Report/;
    
    if ($is_verified) {
        record_info('Attestation Verified', "Attestation report verified successfully on guest $guest_name:\n$verify_output");
        if ($log_file) {
            script_run("echo 'SUCCESS: Attestation report verified successfully' >> $log_file");
            script_run("echo '$verify_output' >> $log_file");
        }
        
        # Save attestation report for upload
        my $save_cmd = "ssh root\@$guest_name \"cp $temp_dir/attestation-report.bin /tmp/\"";
        script_run($save_cmd);
        my $get_cmd = "scp root\@$guest_name:/tmp/attestation-report.bin " . LOG_DIR . "/attestation-report-$guest_name.bin";
        script_run($get_cmd);
    } 
    else {
        record_info('Attestation Verification Failed', "Failed to verify attestation report on guest $guest_name:\n$verify_output");
        if ($log_file) {
            script_run("echo 'FAILED: Attestation report verification failed' >> $log_file");
            script_run("echo '$verify_output' >> $log_file");
        }
    }
    
    # Cleanup temporary directory
    $self->_cleanup_attestation_dir($guest_name, $temp_dir, $log_file);
    
    return;
}

# Helper function to clean up attestation directory
sub _cleanup_attestation_dir {
    my ($self, $guest_name, $temp_dir, $log_file) = @_;
    
    # Clean up
    my $cleanup_cmd = "ssh root\@$guest_name \"rm -rf $temp_dir\"";
    script_run($cleanup_cmd);
    
    if ($log_file) {
        script_run("echo 'Cleaned up temporary attestation files' >> $log_file");
    }
    
    return;
}
=head2 collect_host_logs

  collect_host_logs($self, $log_file)

Collect relevant log files from the host system for SEV-SNP verification.
These logs are stored in the LOG_DIR directory and uploaded to the test server.

=cut

sub collect_host_logs {
    my ($self, $log_file) = @_;
    $log_file //= LOG_DIR . "/host_log_collection.log";
    
    script_run("echo '\\n=== Collecting host logs for SEV-SNP verification ===' >> $log_file");
    
    # Create host logs directory
    my $host_logs_dir = LOG_DIR . "/host_logs";
    script_run("mkdir -p $host_logs_dir");
    
    # Collect basic host information
    script_run("echo 'Collecting basic host information...' >> $log_file");
    script_run("uname -a > $host_logs_dir/uname.txt");
    script_run("cat /etc/os-release > $host_logs_dir/os-release.txt");
    script_run("dmidecode > $host_logs_dir/dmidecode.txt 2>&1");
    script_run("cat /proc/cmdline > $host_logs_dir/cmdline.txt");
    
    # Collect CPU information
    script_run("echo 'Collecting CPU information...' >> $log_file");
    script_run("cat /proc/cpuinfo > $host_logs_dir/cpuinfo.txt");
    script_run("lscpu > $host_logs_dir/lscpu.txt");
    script_run("lscpu -e > $host_logs_dir/lscpu_extended.txt");
    
    # Collect kernel module information
    script_run("echo 'Collecting kernel module information...' >> $log_file");
    script_run("lsmod > $host_logs_dir/lsmod.txt");
    script_run("find /sys/module/kvm_amd/parameters -type f -exec sh -c 'echo {} : $(cat {})' \\; > $host_logs_dir/kvm_amd_params.txt 2>&1");
    script_run("modinfo kvm_amd > $host_logs_dir/kvm_amd_modinfo.txt 2>&1");
    
    # Collect dmesg and kernel logs
    script_run("echo 'Collecting kernel logs...' >> $log_file");
    script_run("dmesg > $host_logs_dir/dmesg.txt");
    script_run("dmesg | grep -i 'sev\\|snp\\|amd memory encryption' > $host_logs_dir/dmesg_sev_filtered.txt 2>&1");
    script_run("journalctl -k > $host_logs_dir/journalctl_kernel.txt 2>&1");
    script_run("journalctl -b | grep -i 'sev\\|snp\\|amd memory encryption' > $host_logs_dir/journal_sev_filtered.txt 2>&1");
    
    # Collect standard log files
    script_run("echo 'Collecting standard log files...' >> $log_file");
    foreach my $log_file (@{HOST_LOG_FILES()}) {
        my $basename = basename($log_file);
        # Use cat instead of cp to handle files that may not exist or special files
        script_run("cat $log_file > $host_logs_dir/$basename 2>/dev/null || echo 'Failed to collect $log_file' >> $log_file");
    }
    
    # Collect SEV-SNP specific information
    script_run("echo 'Collecting SEV-SNP specific information...' >> $log_file");
    script_run("snphost ok > $host_logs_dir/snphost_ok.txt 2>&1 || echo 'Failed to run snphost ok' >> $log_file");
 
    # Collect VM-related information
    script_run("echo 'Collecting VM-related information...' >> $log_file");
    script_run("virsh list --all > $host_logs_dir/virsh_list.txt 2>&1 || echo 'Failed to run virsh list' >> $log_file");
    script_run("virsh capabilities > $host_logs_dir/virsh_capabilities.txt 2>&1 || echo 'Failed to run virsh capabilities' >> $log_file");
    
    # Collect VM XML definitions, especially focusing on SEV-SNP related settings
    script_run("echo 'Collecting VM XML definitions...' >> $log_file");
    script_run("mkdir -p $host_logs_dir/vm_xml");
    script_run("for vm in \$(virsh list --all --name); do virsh dumpxml \$vm > $host_logs_dir/vm_xml/\${vm}_xml.txt 2>&1; done");
    script_run("grep -r 'launchSecurity\\|sev\\|snp' $host_logs_dir/vm_xml/ > $host_logs_dir/vm_sev_config.txt 2>&1 || echo 'No SEV configuration found in VMs' >> $log_file");
    
    # Check OVMF firmware packages
    script_run("echo 'Checking OVMF firmware packages...' >> $log_file");
    script_run("rpm -qa | grep -i 'ovmf\\|edk2' > $host_logs_dir/ovmf_packages.txt 2>&1");
    
    # Create a tar archive of all collected logs
    script_run("echo 'Creating tar archive of host logs...' >> $log_file");
    
    # Use upload_virt_logs instead of manual tar and upload
    script_run("echo 'Uploading host logs to test server...' >> $log_file");
    upload_virt_logs($host_logs_dir, "host_logs");
    
    # Clean up to save disk space but keep the tar archive
    script_run("echo 'Cleaning up individual log files...' >> $log_file");
    script_run("rm -rf $host_logs_dir");
    
    script_run("echo 'Host log collection completed.' >> $log_file");
    
    return;
}

=head2 collect_guest_logs

  collect_guest_logs($self, $guest_name, $log_file)

Collect relevant log files from a guest system for SEV-SNP verification.
These logs are stored in the LOG_DIR directory and uploaded to the test server.

=cut

sub collect_guest_logs {
    my ($self, $guest_name, $log_file) = @_;
    die 'Guest name must be given to collect guest logs.' if (!$guest_name);
    $log_file //= LOG_DIR . "/guest_log_collection_$guest_name.log";
    
    script_run("echo '\\n=== Collecting logs from guest: $guest_name ===' >> $log_file");
    
    # Make sure guest is reachable
    if (script_run("ping -c 1 $guest_name") != 0) {
        script_run("echo 'ERROR: Guest $guest_name is not reachable, skipping log collection' >> $log_file");
        return;
    }
    
    # Create guest logs directory
    my $guest_logs_dir = LOG_DIR . "/guest_logs_$guest_name";
    script_run("mkdir -p $guest_logs_dir");
    
    # Collect basic guest information
    script_run("echo 'Collecting basic guest information...' >> $log_file");
    script_run("ssh root\@$guest_name 'uname -a' > $guest_logs_dir/uname.txt 2>&1 || echo 'Failed to collect uname information' >> $log_file");
    script_run("ssh root\@$guest_name 'cat /etc/os-release' > $guest_logs_dir/os-release.txt 2>&1 || echo 'Failed to collect OS information' >> $log_file");
    
    # Collect CPU information
    script_run("echo 'Collecting CPU information...' >> $log_file");
    script_run("ssh root\@$guest_name 'cat /proc/cpuinfo' > $guest_logs_dir/cpuinfo.txt 2>&1 || echo 'Failed to collect CPU information' >> $log_file");
    script_run("ssh root\@$guest_name 'lscpu' > $guest_logs_dir/lscpu.txt 2>&1 || echo 'Failed to collect lscpu information' >> $log_file");
    
    # Collect dmesg with grep for SEV-related messages
    script_run("echo 'Collecting kernel logs with SEV information...' >> $log_file");
    script_run("ssh root\@$guest_name 'dmesg' > $guest_logs_dir/dmesg.txt 2>&1 || echo 'Failed to collect dmesg' >> $log_file");
    script_run("ssh root\@$guest_name 'dmesg | grep -i \"\\(SEV\\|Memory Encryption\\)\"' > $guest_logs_dir/dmesg_sev.txt 2>&1 || echo 'No SEV information in dmesg' >> $log_file");
    
    # Collect standard log files from guest
    script_run("echo 'Collecting standard log files...' >> $log_file");
    foreach my $log_file (@{GUEST_LOG_FILES()}) {
        my $basename = basename($log_file);
        script_run("ssh root\@$guest_name 'cat $log_file' > $guest_logs_dir/$basename 2>/dev/null || echo 'Failed to collect $log_file from guest' >> $log_file");
    }
    
    # Collect SEV-SNP specific information if snpguest is available
    script_run("echo 'Collecting SEV-SNP specific information...' >> $log_file");
    my $has_snpguest = script_run("ssh root\@$guest_name 'which snpguest' >/dev/null 2>&1") == 0;
    
    if ($has_snpguest) {
        script_run("ssh root\@$guest_name 'snpguest info' > $guest_logs_dir/snpguest_info.txt 2>&1 || echo 'Failed to run snpguest info' >> $log_file");
        script_run("ssh root\@$guest_name 'snpguest report /tmp/report.bin' >/dev/null 2>&1 && ssh root\@$guest_name 'hexdump -C /tmp/report.bin' > $guest_logs_dir/attestation_report_hex.txt 2>&1 || echo 'Failed to generate attestation report' >> $log_file");
        script_run("scp root\@$guest_name:/tmp/report.bin $guest_logs_dir/report.bin >/dev/null 2>&1 || echo 'Failed to copy attestation report' >> $log_file");
    } else {
        script_run("echo 'snpguest tool not available on guest, skipping SNP-specific information' >> $log_file");
    }
    
    # Create a tar archive of all collected logs
    script_run("echo 'Creating tar archive of guest logs...' >> $log_file");
    
    # Use upload_virt_logs instead of manual tar and upload
    script_run("echo 'Uploading guest logs to test server...' >> $log_file");
    upload_virt_logs($guest_logs_dir, "guest_logs_${guest_name}");
    
    # Clean up handled by upload_virt_logs, just note it in the log
    script_run("echo 'Cleaning up individual log files (handled by upload_virt_logs)...' >> $log_file");
    
    script_run("echo 'Guest log collection completed for $guest_name.' >> $log_file");
    
    return;
}

=head2 post_fail_hook

  post_fail_hook($self)

Test run jumps into this subroutine if it fails somehow. It calls post_fail_hook
in base class.

=cut

sub post_fail_hook {
    my $self = shift;
    
    # Collect logs even in case of failure
    my $failure_log = LOG_DIR . "/failure.log";
    
    script_run("echo 'Test failed at: $(date)' > $failure_log");
    script_run("echo 'Collecting host logs after failure...' >> $failure_log");
    
    # Try to collect basic host logs
    eval {
        $self->collect_host_logs($failure_log);
    };
    if ($@) {
        script_run("echo 'Host log collection failed: $@' >> $failure_log");
    }
    
    # Try to collect guest logs if guests are available
    my @guests = keys %virt_autotest::common::guests;
    
    if (@guests) {
        foreach my $guest (@guests) {
            script_run("echo 'Attempting to collect logs from guest: $guest' >> $failure_log");
            eval {
                $self->collect_guest_logs($guest, $failure_log);
            };
            script_run("echo 'Guest log collection " . ($@ ? "failed: $@" : "completed") . "' >> $failure_log");
        }    }
    else {
        script_run("echo 'No guests found, skipping guest log collection' >> $failure_log");
    }
    
    # Upload failure log using standard upload_logs with failok and extended timeout
    upload_logs($failure_log, failok => 1, timeout => 180);
    
    # Call parent's post_fail_hook
    $self->SUPER::post_fail_hook;
    return $self;
}

1;
