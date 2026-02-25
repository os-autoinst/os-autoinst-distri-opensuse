# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Virtualization SEV-SNP guest verification test
# Supports: SLES 15-SP7 host (guests: 15-SP6, 15-SP7), SLES 16+ host (guests: SLES 16+)
# Note: SLES 15-SP6 was Technology Preview (TP) and is not supported as host
#
# Test description:
# This module tests whether SEV-SNP virtual machine has been successfully
# installed on SEV-SNP enabled physical host by checking support status
# on the host first and then on the virtual machine itself.
#
# Test flow:
# - Verifies SEV-SNP support on host (kernel parameters, packages, firmware)
# - Configures and verifies SEV-SNP support on guests:
#   - Updates VM XML configuration to add SEV-SNP security tags
#   - Removes incompatible features (TPM, SMM, memoryBacking)
#   - Verifies SEV-SNP activation in guest dmesg
#   - Runs attestation verification when supported
# - Collects and uploads relevant logs
#
# Modes:
# - Maintenance update: ENABLE_SEV_SNP=1
# - Unified guest installation: VIRT_SEV_SNP_GUEST_INSTALL=1
#
# Maintainer: QE-Virtualization <qe-virt@suse.de> Roy.cai@suse.com

package sev_snp_validation;

use base 'virt_feature_test_base';
use POSIX 'strftime';
use testapi qw(:DEFAULT);
use serial_terminal qw(select_serial_terminal);
use virt_autotest::common;
use virt_autotest::utils qw(guest_is_sle wait_guest_online is_guest_online execute_over_ssh upload_virt_logs);
use version_utils qw(is_sle package_version_cmp);
use Utils::Architectures;
use package_utils;
use bootloader_setup qw(add_grub_cmdline_settings grub_mkconfig);
use power_action_utils 'power_action';

# Define constants for SNP verification
use constant {
    SNP_HOST_TOOLS => ['snphost', 'sevctl', 'snpguest'],
    SNP_GUEST_TOOLS => ['snpguest'],
    SNP_MIN_KERNEL_VER => '5.19.0',

    # Log directory for collecting all test artifacts
    LOG_DIR => '/tmp/sev_snp_test_logs'
};

###########################################
#  SECTION 1: CORE TEST FLOW FUNCTIONS   #
###########################################

=head2 run_test

  run_test($self)

Main entry point for the test. This function:
1. Determines the test context (unified guest install or maintenance update)
2. Checks SEV-SNP support on the host
3. Checks SEV-SNP support on each guest
4. Records overall test status

=cut

sub run_test {
    my $self = shift;

    record_info('SEV-SNP Test Started', 'SEV-SNP verification test started');

    # Determine test context
    my $is_unified_guest_install = get_var("VIRT_UNIFIED_GUEST_INSTALL", 0) || get_var("VIRT_SEV_SNP_GUEST_INSTALL", 0);
    my $is_maintenance_update_mode = get_var("ENABLE_SEV_SNP", 1);

    # Log test context based on mode
    $self->_log_test_context($is_unified_guest_install, $is_maintenance_update_mode);

    # Check SEV-SNP on host
    $self->check_sev_snp_on_host;

    # Check SEV-SNP on each guest
    foreach my $guest (keys %virt_autotest::common::guests) {
        $self->check_sev_snp_on_guest(guest_name => $guest);
    }

    record_info('SEV-SNP Test Completed', 'SEV-SNP verification test completed successfully');

    # Upload all collected logs to job logs & assets
    $self->upload_all_logs();

    return $self;
}

# Helper method to log test context
sub _log_test_context {
    my ($self, $is_unified_guest_install, $is_maintenance_update_mode) = @_;

    # For unified guest installation context
    if ($is_unified_guest_install) {
        record_info('Test Context -- Developing product test', 'Running in unified guest installation mode with SEV-SNP');
    }
    # For maintenance update mode
    elsif ($is_maintenance_update_mode) {
        record_info('Test Context -- MU test', 'Running in unified guest installation mode with SEV-SNP');
    }
    # No known mode specified - record error and exit
    else {
        record_info('Test Context Error', 'No valid test mode specified. Either VIRT_SEV_SNP_GUEST_INSTALL or ENABLE_SEV_SNP must be set.', result => 'fail');
        die "SEV-SNP verification requires a valid test mode. Please set either VIRT_SEV_SNP_GUEST_INSTALL=1 or ENABLE_SEV_SNP=1";
    }
}

###########################################
#  SECTION 2: HOST VERIFICATION FUNCTIONS #
###########################################

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
    my $self = shift;

    record_info('Check SEV-SNP support status on host', 'SLES 15-SP7 and SLES 16+ hosts support AMD SEV-SNP.');

    # Collect CPU information for debugging
    my $cpu_info = script_output("grep -m1 'model name' /proc/cpuinfo");
    record_info('CPU Info', "CPU: $cpu_info");

    # Display system information
    $self->display_system_info();

    # Check architecture
    unless (is_x86_64) {
        record_info('Architecture', 'Non-x86_64 architecture detected, SEV-SNP is not supported', result => 'fail');
        die "SEV-SNP verification requires x86_64 architecture. Test cannot continue on non-x86_64 platforms.";
    }

    # Check OS version - Only SLES 15-SP7 or SLES 16+ supported for host
    unless (is_sle('=15-sp7') or is_sle('>=16')) {
        record_info('OS Version', 'Host OS version is not SLE 15-SP7 or SLE 16+, SEV-SNP is not supported', result => 'fail');
        die "SEV-SNP verification requires SLE 15-SP7 or SLE 16+ for host. Test cannot continue on unsupported OS version.";
    }

    # Activate Confidential Computing module if needed
    $self->activate_coco_module();

    # Configure SEV-SNP kernel parameters
    $self->configure_sev_snp_kernel_parameters();

    # Install and verify required packages
    record_info('Installing SNP packages', "Installing SEV-SNP packages: " . join(', ', @{+SNP_HOST_TOOLS}));
    install_package(join(' ', @{+SNP_HOST_TOOLS}));

    # Simple verification of package installation - check first package in list
    my $primary_package = SNP_HOST_TOOLS->[0];    # snphost for both SLE15 and SLE16
    my $pkg_found = script_run("rpm -q $primary_package") == 0;
    if (!$pkg_found) {
        record_info('Package Installation Failed', "Failed to install primary SEV-SNP package: $primary_package", result => 'fail');
        die "SEV-SNP verification requires SEV-SNP packages to be installed. Test cannot continue.";
    } else {
        # Record installed package versions for debugging
        my $installed_pkgs_info = script_output("rpm -q " . join(' ', @{+SNP_HOST_TOOLS}) . " 2>/dev/null || echo 'Some packages not found'", proceed_on_failure => 1);
        record_info('Installed SEV-SNP Packages', $installed_pkgs_info);
    }

    # Check kernel version
    my $kernel_ver = script_output('uname -r');
    record_info('Kernel version', "Current kernel version: $kernel_ver");

    unless ($kernel_ver =~ /^([\d\.]+)/) {
        record_info('Kernel version parse error', "Could not parse kernel version", result => 'fail');
        die "SEV-SNP verification requires a valid kernel version format. Test cannot continue.";
    }
    my $kern_base_ver = $1;
    # Using package_version_cmp to compare versions
    if (package_version_cmp($kern_base_ver, SNP_MIN_KERNEL_VER) < 0) {
        record_info('Kernel version too old', "Kernel version $kernel_ver is below minimum required version " . SNP_MIN_KERNEL_VER, result => 'fail');
        die "SEV-SNP verification requires kernel version " . SNP_MIN_KERNEL_VER . " or newer. Test cannot continue with kernel $kernel_ver.";
    }
    record_info('Kernel version check', "Kernel version $kernel_ver meets minimum requirement");

    # Load MSR module if needed
    $self->setup_msr_module();

    # Check SEV-SNP capability
    $self->check_sev_snp_host_capability();

    return $self;
}

=head2 display_system_info

  display_system_info($self)

Display system information including BIOS, system details,
and hardware capabilities relevant for SEV-SNP verification.
This provides better visibility into the test environment and helps
with debugging hardware compatibility issues.

=cut

sub display_system_info {
    my $self = shift;

    record_info('BIOS Information', script_output("dmidecode -t bios", proceed_on_failure => 1));
    record_info('System Information', script_output("dmidecode -t system", proceed_on_failure => 1));
    return $self;
}

=head2 activate_coco_module

  activate_coco_module($self)

Activates the Confidential Computing module on SLES 15-SP7 systems.
This module is required for SEV-SNP support on SLES 15-SP7.
The function uses suseconnect to activate the module.

Note: SLES 15-SP6 SEV-SNP support was in Technology Preview (TP) phase and is not supported as host.

=cut

sub activate_coco_module {
    my $self = shift;

    # Only needed for SLES 15-SP7 (SLES 15-SP6 not supported as host - was TP only)
    if (is_sle('=15-sp7')) {
        record_info('Activating COCO module', "Activating Confidential Computing module for SLES 15.7");

        my $module_path = "sle-module-confidential-computing/15.7/x86_64";
        my $ret = script_run("suseconnect -p $module_path");
        if ($ret != 0) {
            record_info('Module activation failed', 'Failed to activate Confidential Computing module. This is required for SEV-SNP support.', result => 'fail');
            die "SEV-SNP verification requires Confidential Computing module. Test cannot continue without this module activated.";
        } else {
            record_info('Module activated', "Successfully activated Confidential Computing module for SLES 15.7");
        }
    }

    return $self;
}

=head2 check_sev_snp_host_capability

  check_sev_snp_host_capability($self)

Check SEV-SNP capability on the host using the snphost tool ("snphost ok").
For SLE 15-SP7 and SLE 16+, we use the snphost tool to verify
hardware and firmware support for SEV-SNP.

This function performs a basic check to verify there are no FAIL entries 
in the output, which would indicate missing SEV-SNP support.

=cut

sub check_sev_snp_host_capability {
    my $self = shift;

    record_info('SNP Host Check', "Running SEV-SNP capability checks to verify hardware/firmware support");

    # Use snphost for SLE 15-SP7 and SLE 16+
    my $tool_name = "snphost";
    my $check_cmd = "snphost ok";

    # First check if the tool is available
    my $has_tool = script_run("which $tool_name") == 0;

    if (!$has_tool) {
        record_info('SEV-SNP Tool Missing', "$tool_name tool not found, required for SEV-SNP hardware verification", result => 'fail');
        die "$tool_name tool not found. This tool is required for SEV-SNP hardware verification.";
    }

    # Run the check command and capture the output
    my $check_output = script_output("$check_cmd 2>&1", proceed_on_failure => 1);
    save_screenshot;

    # Remove ANSI color codes for clean display
    my $clean_output = $check_output;
    $clean_output =~ s/\e\[[0-9;]*m//g;

    record_info('SNP Host Results', "\nOutput:\n$clean_output");

    # Store output for later reference (regardless of success or failure)
    my $output_file = LOG_DIR . "/${tool_name}_output.txt";
    script_run("mkdir -p " . LOG_DIR);
    script_run("echo '$check_output' > $output_file");

    # Just check if there are any FAIL entries in the output
    if ($check_output =~ /FAIL/) {
        record_info('SNP Host Check Failed', "$tool_name reports FAIL for some SEV-SNP requirements. Check the detailed output for more information.\n\nOutput:\n$check_output", result => 'fail');
        die "SEV-SNP verification failed. Hardware or firmware does not fully support SEV-SNP requirements.";
    }

    # If we got here, there were no FAIL entries
    record_info('SNP Host Check Passed', "$tool_name reports no failures for SEV-SNP support.", result => 'ok');

    return $self;
}

=head2 setup_msr_module

  setup_msr_module($self)

Ensure the MSR (Model-Specific Register) kernel module is loaded.
This module provides access to CPU Model-Specific Registers which are critical for:
1. Reading CPU security features and capabilities
2. Allowing the snphost tool to verify SEV-SNP hardware support
3. Enabling proper attestation verification

Without the MSR module, some SEV-SNP diagnostics and attestation functions may fail,
but the basic SEV-SNP functionality should still work (see bsc#1237858).

=cut

sub setup_msr_module {
    my $self = shift;

    # Reference bug for MSR module issues with SEV-SNP
    record_soft_failure("bsc#1237858 - Failed to load msr module may cause SNP attestation to fail");

    # Try to load the MSR module using script_run for better error handling
    record_info('MSR Module', "Checking and loading MSR module for SEV-SNP verification");

    # First check if module is already loaded
    if (script_run("lsmod | grep -q '^msr'") == 0) {
        record_info('MSR Module', "MSR module is already loaded in kernel");
        return $self;
    }

    # Module not loaded, try to load it
    if (script_run("modprobe msr") != 0) {
        record_info('MSR Module Load Failed', "Failed to load MSR module, some SEV-SNP diagnostics and attestation may fail", result => 'softfail');
    } else {
        record_info('MSR Module Loaded', "Successfully loaded MSR module for SEV-SNP verification");
    }

    return $self;
}

=head2 configure_sev_snp_kernel_parameters

  configure_sev_snp_kernel_parameters($self)

Configure the necessary kernel parameters for SEV-SNP support using bootloader_setup library.
This function checks for the required parameters, adds any missing ones,
updates GRUB configuration, and verifies the changes after reboot.

Required kernel parameters for SEV-SNP:
- amd_iommu=on: Enables AMD IOMMU support (required for memory encryption)
- iommu=nopt: Enables IOMMU no pass-through mode
- mem_encrypt=on: Enables memory encryption features
- kvm_amd.sev=1: Enables AMD SEV (Secure Encrypted Virtualization) base functionality
- kvm-amd.sev_snp=1: Enables AMD SEV-SNP (Secure Nested Paging) functionality

=cut

sub configure_sev_snp_kernel_parameters {
    my $self = shift;

    # Required kernel parameters for SEV-SNP
    my %required_params = (
        'amd_iommu=on' => 'AMD IOMMU support',
        'iommu=nopt' => 'IOMMU no pass-through mode',
        'mem_encrypt=on' => 'Memory encryption',
        'kvm_amd.sev=1' => 'SEV base functionality',
        'kvm-amd.sev_snp=1' => 'SEV-SNP functionality'
    );

    # Check current kernel parameters
    my $cmdline = script_output("cat /proc/cmdline");
    record_info('Kernel cmdline', $cmdline);

    # Find missing parameters
    my @missing;
    foreach my $param (keys %required_params) {
        push @missing, $param unless $cmdline =~ /\b$param\b/;
    }

    # If all parameters are present, return success
    if (!@missing) {
        record_info('SEV-SNP boot parameters', 'All required parameters present');
        return 1;
    }

    # Log missing parameters - this is expected on first run, will attempt to fix automatically
    my $missing_list = join(", ", @missing);
    record_info('Missing SEV-SNP parameters', "Missing parameters detected (will attempt to fix automatically): $missing_list");

    # Add missing parameters using bootloader_setup library
    record_info('Fixing GRUB', "Adding missing SEV-SNP parameters to GRUB configuration");
    foreach my $param (@missing) {
        add_grub_cmdline_settings($param);
    }

    # Update GRUB configuration
    grub_mkconfig();
    record_info('GRUB updated', 'GRUB configuration updated with missing parameters');

    # Reboot to apply changes
    record_info('Reboot required', 'Rebooting to apply new parameters');
    power_action('reboot', textmode => 1);

    # Wait for boot completion - increased timeout for IPMI/SOL console where GRUB can take >180s
    $self->wait_boot(textmode => 1, bootloader_time => 100, ready_time => 200);
    select_serial_terminal;

    # Verify parameters after reboot
    my $new_cmdline = script_output("cat /proc/cmdline");
    record_info('New kernel cmdline', $new_cmdline);

    # Check if all parameters are now present
    my $all_present = 1;
    foreach my $param (keys %required_params) {
        if ($new_cmdline !~ /\b$param\b/) {
            record_info("Parameter missing", "Required parameter '$param' (${required_params{$param}}) not applied", result => 'fail');
            $all_present = 0;
        }
    }

    if (!$all_present) {
        die "SEV-SNP verification requires specific kernel parameters. Not all parameters were applied after reboot. Test cannot continue.";
    }

    record_info('Parameters Applied', "All SEV-SNP parameters successfully applied after reboot");
    return 1;
}

###########################################
#  SECTION 3: GUEST VERIFICATION FUNCTIONS #
###########################################

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

    die 'Guest name must be given to perform following operations.' if ($args{guest_name} eq '');

    my $guest_name = $args{guest_name};
    my $guest_type = 'unknown';    # Will be set to 'sev-snp' if verification passes

    # SEV-SNP requires UEFI. Match 'efi' (MU tests) or 'sev-snp' (new products)
    if ($guest_name !~ /efi|sev-snp/) {
        record_info("SEV-SNP Skip", "Skipping guest $guest_name: SEV-SNP requires UEFI boot.\n" .
              "Guest name must contain 'efi' (for MU tests) or 'sev-snp' (for new product tests).", result => 'ok');
        return 1;    # Return success but skip the test
    }

    record_info("Check SEV-SNP on guest", "Verifying SEV-SNP support status on guest $guest_name");

    # Configure guest for SEV-SNP if not already configured
    my $config_result = $self->configure_guest_for_sev_snp(guest_name => $guest_name);
    if (!$config_result) {
        record_info('SEV-SNP Config', "Failed to configure SEV-SNP for guest $guest_name", result => 'fail');
        die "Failed to configure SEV-SNP for guest $guest_name. Test cannot continue with unconfigured guest.";
    } else {
        record_info('SEV-SNP Config', "Successfully configured SEV-SNP for guest $guest_name");
    }

    # Check if SEV-SNP is enabled in guest's dmesg
    record_info('Guest dmesg', "Checking for SEV-SNP features in guest $guest_name dmesg");

    # Search for Memory Encryption Features line
    my $dmesg_output = script_output("ssh root\@$guest_name \"dmesg | grep -i 'Memory Encryption Features active'\" 2>/dev/null", proceed_on_failure => 1);
    save_screenshot;

    # Define the expected pattern for SEV-SNP
    my $expected_pattern = 'Memory Encryption Features active.*AMD SEV SEV-ES SEV-SNP';

    # Check if pattern is found
    if ($dmesg_output =~ /$expected_pattern/) {
        record_info('SEV-SNP Status', "SEV-SNP is active in guest $guest_name dmesg", result => 'ok');

        # Set guest type for later use
        $guest_type = 'sev-snp';
        record_info('Guest Type', "Guest $guest_name confirmed as: $guest_type");
    } else {
        record_info('SEV-SNP Status', "SEV-SNP is not active in guest $guest_name", result => 'fail');

        # Collect complete dmesg for debugging when SEV-SNP check fails
        record_info('Collecting Debug Info', "SEV-SNP check failed, collecting complete guest dmesg for analysis");
        my $complete_dmesg = script_output("ssh root\@$guest_name \"dmesg\" 2>/dev/null", proceed_on_failure => 1);

        # Save complete dmesg to log directory for upload
        script_run("mkdir -p " . LOG_DIR);
        my $dmesg_file = LOG_DIR . "/guest_${guest_name}_dmesg_fail.txt";
        script_run("echo '$complete_dmesg' > $dmesg_file");
        record_info('Debug Logs Saved', "Complete guest dmesg saved to: $dmesg_file");

        # Also record a subset of dmesg output for immediate visibility
        my $filtered_dmesg = script_output("ssh root\@$guest_name \"dmesg | grep -i -E '(sev|snp|memory.encryption|amd|ccp)' || echo 'No SEV-related messages found'\" 2>/dev/null", proceed_on_failure => 1);
        record_info('SEV-related dmesg', "SEV/SNP related messages from guest dmesg:\n$filtered_dmesg");

        die "SEV-SNP is not enabled or active for guest $guest_name";
    }

    # For SEV-SNP guests, perform additional verification
    if ($guest_type eq 'sev-snp') {
        # Wait for guest to be online before further checks
        wait_guest_online($guest_name, 50, 1);

        # Install required packages on guest
        record_info('Package Installation', "Installing required SEV-SNP packages on guest $guest_name");
        if (!$self->install_snp_packages_on_guest(guest_name => $guest_name, packages => +SNP_GUEST_TOOLS)) {
            record_info("Package Install Warning", "Some packages could not be installed on guest $guest_name. Proceeding with verification anyway.", result => 'softfail');
        }

        # Verify at least one package installed successfully
        if (!$self->verify_any_snp_package_installed(required_pkgs => +SNP_GUEST_TOOLS, dst_machine => $guest_name)) {
            record_info('Package Verification Failed', "No required SEV-SNP packages are installed on guest $guest_name", result => 'fail');
            die "SEV-SNP verification requires at least one SEV-SNP package to be installed on the guest. Test cannot continue.";
        }

        # Verify attestation report
        $self->verify_guest_attestation(guest_name => $guest_name);
    }

    return $self;
}

=head2 configure_guest_for_sev_snp

  configure_guest_for_sev_snp($self, guest_name => 'name')

Configure a guest VM with SEV-SNP support by:
1. Dumping the current XML configuration
2. Modifying it to include SEV-SNP configuration
3. Undefining the VM and redefining it with the new configuration
4. Starting the VM with the new configuration

=cut

sub configure_guest_for_sev_snp {
    my ($self, %args) = @_;
    $args{guest_name} //= '';

    die 'Guest name must be given to configure SEV-SNP for a guest VM.' if ($args{guest_name} eq '');

    my $guest_name = $args{guest_name};
    record_info('SEV-SNP Config', "Configuring SEV-SNP for guest $guest_name");

    # Step 1: Check VM state and shutdown if needed
    my $vm_state = script_output("virsh domstate $guest_name 2>/dev/null || echo 'not-found'", proceed_on_failure => 1);

    if ($vm_state eq 'not-found') {
        record_info('VM Not Found', "Guest $guest_name not found", result => 'fail');
        script_run("virsh list --all");
        save_screenshot;
        die "Guest VM $guest_name not found, cannot continue with SEV-SNP configuration";
    }

    # If VM is running, shut it down
    if ($vm_state eq 'running') {
        record_info('VM State', "Guest $guest_name is running, shutting it down");

        # Try graceful shutdown first
        script_run("virsh shutdown $guest_name");

        # Wait up to 30 seconds for shutdown
        sleep 5;
        if (script_run("virsh domstate $guest_name | grep -q 'shut off'") != 0) {
            # Force shutdown if still running after 30 seconds
            record_info('Force Off', "Forcing off guest $guest_name");
            script_run("virsh destroy $guest_name");
        }
    }

    # Make sure the VM is now off
    if (script_run("virsh domstate $guest_name | grep -q 'shut off'") != 0) {
        record_info('VM State Error', "Failed to shut down guest $guest_name", result => 'fail');
        die "Guest $guest_name must be shut off to continue with SEV-SNP configuration";
    }

    # Step 2: Dump and modify XML configuration
    record_info('XML Config', "Configuring XML for SEV-SNP support");

    # Note: We're using XML modification instead of virt-install due to a known bug
    record_soft_failure("bsc#1240006 - [jsc#PED-5898][SEV-SNP] Virt-install fails to start SEV-SNP enabled VM with ISO on SLES 15 SP7. " .
          "Using XML modification as a workaround. When this bug is fixed, consider using virt-install directly.");

    # Create test directory if it doesn't exist
    script_run("mkdir -p " . LOG_DIR);

    my $xml_file = LOG_DIR . "/$guest_name.xml";
    my $backup_file = LOG_DIR . "/$guest_name.xml.backup";

    # Dump the XML and create backup
    if (script_run("virsh dumpxml $guest_name > $xml_file") != 0) {
        record_info('XML Dump', "Failed to dump XML for guest $guest_name", result => 'fail');
        return 0;
    }

    script_run("cp $xml_file $backup_file");

    # Check if SEV-SNP is already configured
    if (script_run("grep -q '<launchSecurity type=\"sev-snp\">' $xml_file") == 0) {
        record_info('SEV-SNP Configured', "SEV-SNP already configured for guest $guest_name, no changes needed");
        return 1;
    }

    # Get QEMU version for machine type
    my $qemu_version = script_output("qemu-system-x86_64 --version | head -1 | awk '{print \$4}' | cut -d'.' -f1,2", proceed_on_failure => 1);
    my $machine_type = "pc-q35-$qemu_version";
    record_info('Machine Type', "Using machine type: $machine_type");

    # Remove incompatible features (TPM, SMM, memoryBacking)
    # Check for TPM devices
    my $tpm_count = script_output("grep -c '<tpm' $xml_file || echo '0'", proceed_on_failure => 1);
    if ($tpm_count ne '0') {
        my $tpm_details = script_output("grep -A10 -B2 '<tpm' $xml_file || echo 'No TPM details found'", proceed_on_failure => 1);
        record_soft_failure("bsc#1244308 - TPM device configuration found in VM XML which is incompatible with SEV-SNP: $tpm_details");
        script_run("sed -i '/<tpm/,/<\\/tpm>/d' $xml_file");
        record_info('TPM Removal', 'Removed TPM tags from XML file');
    }

    # Check for SMM configuration
    my $smm_count = script_output("grep -c '<smm' $xml_file || echo '0'", proceed_on_failure => 1);
    if ($smm_count ne '0') {
        my $smm_details = script_output("grep -A2 -B2 '<smm' $xml_file || echo 'No SMM details found'", proceed_on_failure => 1);
        record_info('SMM Incompatibility', "SMM configuration found in VM XML which is incompatible with SEV-SNP: $smm_details", result => 'softfail');
        script_run("sed -i '/<smm[^>]*>/d' $xml_file");
        record_info('SMM Removal', 'Removed SMM tags from XML file');
    }

    # Check for memoryBacking with locked configuration
    my $memory_backing_count = script_output("grep -c '<memoryBacking>' $xml_file || echo '0'", proceed_on_failure => 1);
    if ($memory_backing_count ne '0') {
        my $memory_backing_details = script_output("grep -A3 -B1 '<memoryBacking>' $xml_file || echo 'No memoryBacking details found'", proceed_on_failure => 1);
        record_info('MemoryBacking Incompatibility', "memoryBacking configuration found in VM XML which is incompatible with SEV-SNP: $memory_backing_details", result => 'softfail');
        script_run("sed -i '/<memoryBacking>/,/<\\/memoryBacking>/d' $xml_file");
        record_info('MemoryBacking Removal', 'Removed memoryBacking tags from XML file');
    }

    # Delete existing OS section and insert SEV-compatible OS configuration
    record_info('OS Section', "Updating OS section for SEV-SNP compatibility");

    # First delete the existing OS section (if exists)
    script_run("sed -i '/<os/,/<\\/os>/d' $xml_file");

    # Define new OS section with SEV-compatible settings
    my $os_section = <<EOL;
<os>
  <type arch="x86_64" machine="$machine_type">hvm</type>
  <loader readonly="yes" type="rom">/usr/share/qemu/ovmf-x86_64-sev.bin</loader>
  <boot dev="hd"/>
</os>
EOL

    # A safer approach: Write OS section to a temporary file and insert it using sed
    script_run("echo '$os_section' > " . LOG_DIR . "/os_section.xml");
    # Insert the OS section right before the </domain> tag - using sed -e command
    script_run("sed -i -e '/<\\/domain>/e cat " . LOG_DIR . "/os_section.xml' $xml_file");

    # Verify that changes were applied successfully
    my $new_os_section = script_output("grep -A5 '<os>' $xml_file || echo 'OS section not found'", proceed_on_failure => 1);
    if ($new_os_section !~ /ovmf-x86_64-sev\.bin/) {
        record_info('OS Config Error', "Failed to properly update OS section. SEV-SNP firmware not configured.", result => 'fail');
        return 0;
    } else {
        record_info('OS Config Success', "Successfully configured SEV-SNP compatible OS section");
    }

    # Add the SEV-SNP launch security section before </domain>
    my $launch_security = <<EOL;
<launchSecurity type="sev-snp">
  <policy>0x00030000</policy>
</launchSecurity>
EOL
    script_run("echo '$launch_security' > " . LOG_DIR . "/launch_security.xml");
    # Insert the launch security section right before the </domain> tag - using sed -e command
    script_run("sed -i -e '/<\\/domain>/e cat " . LOG_DIR . "/launch_security.xml' $xml_file");

    # Display the modified XML file path for debugging purposes
    record_info('XML Modified', "Updated VM configuration saved to: $xml_file");

    # Display XML file content for debugging
    my $xml_content = script_output("cat $xml_file", proceed_on_failure => 1);
    record_info('XML Content', "Modified VM XML configuration:\n$xml_content");

    # Step 3: Undefine and redefine VM with new XML
    record_info('VM Redefine', "Applying new SEV-SNP configuration");

    my $error = 0;
    if (script_run("virsh undefine $guest_name --nvram") != 0) {
        record_info('Undefine Failed', "Failed to undefine guest $guest_name", result => 'fail');
        $error = 1;
    }
    # Check if virsh define command fails using return code (not output content)
    elsif (script_run("virsh define $xml_file") != 0) {
        # Capture the error output for analysis
        my $define_output = script_output("virsh define $xml_file 2>&1", proceed_on_failure => 1);

        # Check if the error message indicates SEV-SNP is not supported by QEMU
        if ($define_output =~ /unsupported configuration: 'sev-snp' launch security is not supported with this QEMU binary/) {
            # Restore original VM config
            script_run("virsh define $backup_file");
            record_soft_failure("bsc#1245733 - [sev-snp][sles15sp6]QEMU binary does not support AMD SEV-SNP launch security configuration");
            die "SEV-SNP is not supported by this QEMU binary. Skipping test.";
        }
        # Handle other definition errors
        record_info('Define Failed', "Failed to define guest $guest_name with new XML: $define_output", result => 'fail');
        $error = 1;
    }

    # Handle errors by restoring from backup
    if ($error) {
        record_info('Restore Backup', "Attempting to restore from backup XML");
        script_run("virsh define $backup_file");
        return 0;
    }

    record_info('XML Defined', "Guest successfully redefined with SEV-SNP support");

    # Step 4: Start the VM with new configuration
    record_info('VM Start', "Starting guest with SEV-SNP configuration");

    if (script_run("virsh start $guest_name") != 0) {
        record_info('Start Failed', "Failed to start guest $guest_name with SEV-SNP configuration", result => 'fail');

        # Restore original configuration
        record_info('Restore Original', "Restoring original configuration");
        script_run("virsh undefine $guest_name 2>/dev/null");
        script_run("virsh define $backup_file");
        script_run("virsh start $guest_name");

        return 0;
    }

    record_info('SEV-SNP Ready', "Guest $guest_name successfully configured with SEV-SNP support and started");

    # Wait for the VM to boot
    record_info('VM Boot', "Waiting for guest to become available...");
    wait_guest_online($guest_name, 60, 1);

    return 1;
}

#############################################
#  SECTION 4: PACKAGE VERIFICATION FUNCTIONS #
#############################################

=head2 verify_any_snp_package_installed

  verify_any_snp_package_installed($self, required_pkgs => ['pkg1', 'pkg2'], [dst_machine => 'machine'])

Verifies that at least one of the required SEV-SNP packages is installed on the system.
Returns true if at least one package is installed, false otherwise.

This function:
1. Takes a list of required packages to check
2. Optionally checks on a remote machine via SSH (specify dst_machine parameter)
3. Returns true if at least one package is installed, false otherwise

Note: This is a specialized function for SEV-SNP verification. For general package 
checking on the local system, use the more general is_package_installed function
from hacluster.pm or package_utils module.

=cut

sub verify_any_snp_package_installed {
    my ($self, %args) = @_;
    $args{required_pkgs} //= [];
    $args{dst_machine} //= 'localhost';

    my $is_local = ($args{dst_machine} eq 'localhost');
    my $location = $is_local ? "host" : "guest $args{dst_machine}";

    record_info("Verifying packages", "Checking for at least one installed package on $location: " . join(', ', @{$args{required_pkgs}}));

    foreach my $pkg (@{$args{required_pkgs}}) {
        my $ret;

        if ($is_local) {
            # Check package locally using rpm command
            $ret = script_run("rpm -q $pkg");
        } else {
            # For remote machines, use SSH
            $ret = execute_over_ssh(
                address => $args{dst_machine},
                command => "rpm -q $pkg",
                assert => 0
            );
        }

        # If package is installed, return true immediately
        if ($ret == 0) {
            record_info("Package found", "Package $pkg is installed on $location", result => 'ok');
            return 1;
        }
    }

    # If we get here, none of the packages were installed
    record_info('No packages found', "None of the required packages are installed on $location", result => 'fail');
    return 0;
}

=head2 install_snp_packages_on_guest

  install_snp_packages_on_guest($self, guest_name => 'name', packages => ['pkg1', 'pkg2'])

Install the necessary SEV-SNP packages on a guest machine.
This function uses SSH to install packages on the remote guest.
Returns 1 for success, 0 for failure.

=cut

sub install_snp_packages_on_guest {
    my ($self, %args) = @_;
    $args{guest_name} //= '';
    $args{packages} //= [];

    die 'Guest name must be provided for remote package installation' if ($args{guest_name} eq '');
    die 'Package list must be provided for installation' if (!@{$args{packages}});

    my $guest_name = $args{guest_name};
    my $package_list = join(' ', @{$args{packages}});

    record_info("Installing Packages", "Installing packages on guest $guest_name: $package_list");

    # Use execute_over_ssh with better error handling and longer timeout for package installation
    my $install_result = execute_over_ssh(
        address => $guest_name,
        command => "zypper --non-interactive in $package_list",
        assert => 0,
        timeout => 180    # Increased timeout for package installation
    );
    save_screenshot;

    if ($install_result != 0) {
        record_info('Installation Failed', "Failed to install packages on guest $guest_name: $package_list", result => 'softfail');
        return 0;
    }

    record_info('Installation Attempted', "Attempted to install all required packages on guest $guest_name");
    return 1;
}

##############################################
#  SECTION 5: ATTESTATION VERIFICATION FUNCTIONS #
##############################################

=head2 verify_guest_attestation

  verify_guest_attestation($self, guest_name => 'name')

Generate and verify an attestation report for an SEV-SNP guest.

=cut

sub verify_guest_attestation {
    my ($self, %args) = @_;
    $args{guest_name} //= '';

    die 'Guest name must be given to perform attestation verification.' if ($args{guest_name} eq '');

    my $guest_name = $args{guest_name};

    record_info('Guest Attestation', "Verifying guest attestation for $guest_name");

    # Make sure guest is online
    wait_guest_online($guest_name, 50, 1);

    # Display snpguest version for debugging
    my $snpguest_version = execute_over_ssh(
        address => $guest_name,
        command => "snpguest --version 2>&1 || snpguest -V 2>&1 || echo 'Unable to determine snpguest version'",
        timeout => 30,
        assert => 0
    );
    record_info('SNPGuest Version', "snpguest version on guest $guest_name: $snpguest_version");

    # Create a temporary directory for attestation artifacts
    my $temp_dir = LOG_DIR . "/sev_snp_attestation_" . time();
    execute_over_ssh(
        address => $guest_name,
        command => "mkdir -p $temp_dir",
        timeout => 30
    );

    record_info('Attestation Prep', "Created attestation directory: $temp_dir on guest $guest_name");

    # Generate a request file with random data
    execute_over_ssh(
        address => $guest_name,
        command => "dd if=/dev/urandom of=$temp_dir/request-file.bin bs=64 count=1",
        timeout => 30
    );
    save_screenshot;

    # Generate attestation report
    record_info('Generate Report', "Generating attestation report on guest $guest_name");
    my $report_ret = execute_over_ssh(
        address => $guest_name,
        command => "snpguest report $temp_dir/attestation-report.bin $temp_dir/request-file.bin",
        timeout => 60,
        assert => 0
    );
    save_screenshot;

    if ($report_ret != 0) {
        record_info('Report Generation', "Failed to generate attestation report on guest $guest_name", result => 'softfail');
        $self->_cleanup_attestation_dir($guest_name, $temp_dir);
        return;
    }

    record_info('Report Generated', "Successfully generated attestation report on guest $guest_name");

    # Create directory for certificates
    execute_over_ssh(
        address => $guest_name,
        command => "mkdir -p $temp_dir/certs-kds",
        timeout => 30
    );

    # Fetch AMD CA certificates
    record_info('CA Certificates', "Fetching AMD CA certificates on guest $guest_name");

    # Adapt command format based on guest SLES version due to snpguest version changes
    my $ca_cmd;
    if (guest_is_sle($guest_name, '>=16')) {
        # SLES 16+ uses newer snpguest command format
        $ca_cmd = "snpguest fetch ca der $temp_dir/certs-kds milan";
    } else {
        # SLES 15-SP7 uses older snpguest command format
        $ca_cmd = "snpguest fetch ca der milan $temp_dir/certs-kds";
    }

    my $ca_ret = execute_over_ssh(
        address => $guest_name,
        command => "$ca_cmd",
        timeout => 90,
        assert => 0
    );
    save_screenshot;

    if ($ca_ret != 0) {
        record_info('CA Fetch', "Failed to fetch CA certificates on guest $guest_name", result => 'fail');
        $self->_cleanup_attestation_dir($guest_name, $temp_dir);
        return;
    }

    # Fetch VCEK certificate
    record_info('VCEK Certificate', "Fetching VCEK certificate on guest $guest_name");

    # Adapt command format based on guest SLES version due to snpguest version changes
    my $vcek_cmd;
    if (guest_is_sle($guest_name, '>=16')) {
        # SLES 16+ uses newer snpguest command format
        $vcek_cmd = "snpguest fetch vcek der $temp_dir/certs-kds $temp_dir/attestation-report.bin";
    } else {
        # SLES 15-SP7 uses older snpguest command format
        $vcek_cmd = "snpguest fetch vcek der milan $temp_dir/certs-kds $temp_dir/attestation-report.bin";
    }

    my $vcek_ret = execute_over_ssh(
        address => $guest_name,
        command => "$vcek_cmd",
        timeout => 90,
        assert => 0
    );
    save_screenshot;

    if ($vcek_ret != 0) {
        record_info('VCEK Fetch', "Failed to fetch VCEK certificate on guest $guest_name", result => 'fail');
        $self->_cleanup_attestation_dir($guest_name, $temp_dir);
        return;
    }

    # Verify attestation report
    record_info('Verify Report', "Verifying attestation report on guest $guest_name");
    my $verify_output = script_output("ssh root\@$guest_name \"snpguest verify attestation $temp_dir/certs-kds $temp_dir/attestation-report.bin\"", proceed_on_failure => 1);
    save_screenshot;

    # Check if verification was successful - accept both VEK and VCEK signature verification
    # VEK (Versioned Endorsement Key) is standard verification path
    # VCEK (Versioned Chip Endorsement Key) is chip-specific verification path
    # Both are valid for confirming successful SEV-SNP attestation
    my $is_verified = $verify_output =~ /(?:VEK|VCEK) signed the Attestation Report/;

    if ($is_verified) {
        record_info('Attestation', "Attestation report verified successfully on guest $guest_name", result => 'ok');

        # Save attestation report for upload
        execute_over_ssh(
            address => $guest_name,
            command => "cp $temp_dir/attestation-report.bin " . LOG_DIR . "/",
            timeout => 30
        );

        script_run("scp root\@$guest_name:" . LOG_DIR . "/attestation-report.bin " . LOG_DIR . "/attestation-report-$guest_name.bin >/dev/null 2>&1");
        record_info('Report Saved', "Attestation report saved to " . LOG_DIR . "/attestation-report-$guest_name.bin");
    }
    else {
        record_info('Attestation', "Failed to verify attestation report on guest $guest_name", result => 'fail');
        record_info('Verification Output', $verify_output);
    }

    # Cleanup temporary directory
    $self->_cleanup_attestation_dir($guest_name, $temp_dir);

    return;
}

# Helper function to clean up attestation directory
sub _cleanup_attestation_dir {
    my ($self, $guest_name, $temp_dir) = @_;

    record_info('Cleanup', "Cleaning up temporary attestation directory on guest $guest_name");
    execute_over_ssh(
        address => $guest_name,
        command => "rm -rf $temp_dir",
        timeout => 30,
        assert => 0
    );

    return;
}

###########################################
#  SECTION 6: LOG COLLECTION FUNCTIONS   #
###########################################

=head2 upload_all_logs

  upload_all_logs($self)

Upload all logs collected in LOG_DIR to job logs & assets.
This function creates a comprehensive tarball of all SEV-SNP test artifacts
and uploads it to the openQA job for later analysis.

=cut

sub upload_all_logs {
    my $self = shift;

    record_info('Upload All Logs', "Uploading all SEV-SNP test logs from " . LOG_DIR);

    # Create LOG_DIR if it doesn't exist
    script_run("mkdir -p " . LOG_DIR);

    # Check if LOG_DIR has any content
    my $log_count = script_output("ls -la " . LOG_DIR . " | wc -l", proceed_on_failure => 1);
    if ($log_count <= 2) {    # Only . and .. entries means empty directory
        record_info('No Logs Found', "No logs found in " . LOG_DIR . " to upload", result => 'softfail');
        return;
    }

    # Use upload_virt_logs to compress and upload all logs
    upload_virt_logs(LOG_DIR, "sev_snp_test_logs");

    record_info('Log Upload Complete', "All SEV-SNP test logs uploaded successfully");

    return;
}

=head2 collect_host_logs

  collect_host_logs($self)

Collect relevant log files from the host system for SEV-SNP verification.
These logs are stored in the LOG_DIR directory and uploaded to the test server.

=cut

sub collect_host_logs {
    my $self = shift;

    record_info('Host Logs', "Collecting host logs for SEV-SNP verification");

    # Create host logs directory
    my $host_logs_dir = LOG_DIR . "/host_logs";
    script_run("mkdir -p $host_logs_dir");

    # Collect basic host information
    record_info('Host Info', "Collecting basic host information");
    script_run("uname -a > $host_logs_dir/uname.txt");
    script_run("cat /etc/os-release > $host_logs_dir/os-release.txt");
    script_run("dmidecode > $host_logs_dir/dmidecode.txt 2>&1");
    script_run("cat /proc/cmdline > $host_logs_dir/cmdline.txt");

    # Collect CPU information
    record_info('CPU Info', "Collecting CPU information");
    script_run("cat /proc/cpuinfo > $host_logs_dir/cpuinfo.txt");
    script_run("lscpu > $host_logs_dir/lscpu.txt");
    script_run("lscpu -e > $host_logs_dir/lscpu_extended.txt");

    # Collect kernel module information
    record_info('Kernel Modules', "Collecting kernel module information");
    script_run("lsmod > $host_logs_dir/lsmod.txt");
    script_run("find /sys/module/kvm_amd/parameters -type f -exec sh -c 'echo {} : $(cat {})' \\; > $host_logs_dir/kvm_amd_params.txt 2>&1");
    script_run("modinfo kvm_amd > $host_logs_dir/kvm_amd_modinfo.txt 2>&1");

    # Collect dmesg and kernel logs
    record_info('Kernel Logs', "Collecting dmesg and kernel logs");
    script_run("dmesg > $host_logs_dir/dmesg.txt");
    script_run("dmesg | grep -i 'sev\\|snp\\|amd memory encryption' > $host_logs_dir/dmesg_sev_filtered.txt 2>&1");
    script_run("journalctl -k > $host_logs_dir/journalctl_kernel.txt 2>&1");
    script_run("journalctl -b | grep -i 'sev\\|snp\\|amd memory encryption' > $host_logs_dir/journal_sev_filtered.txt 2>&1");

    # Collect SEV-SNP specific parameter files
    record_info('SEV-SNP Parameters', "Collecting SEV-SNP parameter files");
    script_run("cat /sys/module/kvm_amd/parameters/sev_snp > $host_logs_dir/sev_snp 2>/dev/null || echo 'Failed to collect /sys/module/kvm_amd/parameters/sev_snp'");

    # Collect SEV-SNP specific information
    record_info('SEV-SNP Info', "Collecting SEV-SNP specific information");

    # Use snphost for all SLE versions
    script_run("snphost ok > $host_logs_dir/snphost_ok.txt 2>&1");
    save_screenshot;

    # Collect VM-related information
    record_info('VM Info', "Collecting VM-related information");
    script_run("virsh list --all > $host_logs_dir/virsh_list.txt 2>&1");
    script_run("virsh capabilities > $host_logs_dir/virsh_capabilities.txt 2>&1");

    # Collect VM XML definitions, especially focusing on SEV-SNP related settings
    record_info('VM XML', "Collecting VM XML definitions");
    script_run("mkdir -p $host_logs_dir/vm_xml");
    script_run("for vm in \$(virsh list --all --name); do virsh dumpxml \$vm > $host_logs_dir/vm_xml/\${vm}_xml.txt 2>&1; done");
    script_run("grep -r 'launchSecurity\\|sev\\|snp' $host_logs_dir/vm_xml/ > $host_logs_dir/vm_sev_config.txt 2>&1");

    # Check OVMF firmware packages
    record_info('OVMF Packages', "Checking OVMF firmware packages");
    script_run("rpm -qa | grep -i 'ovmf\\|edk2' > $host_logs_dir/ovmf_packages.txt 2>&1");

    # Use upload_virt_logs to compress and upload the collected logs
    # This function will also clean up the original log directory
    record_info('Upload Logs', "Uploading host logs to test server");
    upload_virt_logs($host_logs_dir, "host_logs");
    save_screenshot;

    record_info('Log Collection', "Host log collection completed");

    return;
}

=head2 collect_guest_logs

  collect_guest_logs($self, $guest_name)

Collect relevant log files from a guest system for SEV-SNP verification.
These logs are stored in the LOG_DIR directory and uploaded to the test server.

=cut

sub collect_guest_logs {
    my ($self, $guest_name) = @_;
    die 'Guest name must be given to collect guest logs.' if (!$guest_name);

    record_info('Guest Logs', "Collecting logs from guest: $guest_name");

    # Make sure guest is reachable
    if (!is_guest_online($guest_name)) {
        record_info('Guest Unreachable', "ERROR: Guest $guest_name is not reachable, skipping log collection", result => 'fail');
        return;
    }

    # Create guest logs directory
    my $guest_logs_dir = LOG_DIR . "/guest_logs_$guest_name";
    script_run("mkdir -p $guest_logs_dir");

    # Collect basic guest information
    record_info('Guest Info', "Collecting basic guest information");
    script_run("ssh root\@$guest_name 'uname -a' > $guest_logs_dir/uname.txt 2>/dev/null");
    script_run("ssh root\@$guest_name 'cat /etc/os-release' > $guest_logs_dir/os-release.txt 2>/dev/null");

    # Collect CPU information
    record_info('CPU Info', "Collecting CPU information from guest");
    script_run("ssh root\@$guest_name 'cat /proc/cpuinfo' > $guest_logs_dir/cpuinfo.txt 2>/dev/null");
    script_run("ssh root\@$guest_name 'lscpu' > $guest_logs_dir/lscpu.txt 2>/dev/null");

    # Collect dmesg with grep for SEV-related messages
    record_info('Kernel Logs', "Collecting kernel logs with SEV information");
    script_run("ssh root\@$guest_name 'dmesg' > $guest_logs_dir/dmesg.txt 2>/dev/null");
    script_run("ssh root\@$guest_name 'dmesg | grep -i \"\\(SEV\\|Memory Encryption\\)\"' > $guest_logs_dir/dmesg_sev.txt 2>/dev/null");

    # Collect kernel boot parameters
    record_info('Kernel Parameters', "Collecting kernel boot parameters from guest");
    script_run("ssh root\@$guest_name 'cat /proc/cmdline' > $guest_logs_dir/cmdline.txt 2>/dev/null");

    # Check if snpguest is available on the guest
    my $has_snpguest = execute_over_ssh(
        address => $guest_name,
        command => "which snpguest",
        assert => 0
    ) == 0;

    if ($has_snpguest) {
        record_info('SNPGuest Available', "snpguest tool found on guest, collecting SNP-specific information");
        script_run("ssh root\@$guest_name 'snpguest info' > $guest_logs_dir/snpguest_info.txt 2>/dev/null");
        execute_over_ssh(
            address => $guest_name,
            command => "snpguest report " . LOG_DIR . "/report.bin",
            assert => 0
        );
        script_run("ssh root\@$guest_name 'hexdump -C " . LOG_DIR . "/report.bin' > $guest_logs_dir/attestation_report_hex.txt 2>/dev/null");
        script_run("scp root\@$guest_name:" . LOG_DIR . "/report.bin $guest_logs_dir/report.bin >/dev/null 2>&1");
        save_screenshot;
    } else {
        record_info('SNPGuest Missing', "snpguest tool not available on guest, skipping SNP-specific information", result => 'softfail');
    }

    # Use upload_virt_logs to compress and upload the collected logs
    # This function will also clean up the original log directory
    record_info('Upload Logs', "Uploading guest logs to test server");
    upload_virt_logs($guest_logs_dir, "guest_logs_${guest_name}");
    save_screenshot;

    record_info('Log Collection', "Guest log collection completed for $guest_name");

    return;
}

###########################################
#  SECTION 7: ERROR HANDLING FUNCTIONS   #
###########################################

=head2 post_fail_hook

  post_fail_hook($self)

Test failure handler that collects diagnostic logs from both host and guests
to aid in debugging. Calls parent's post_fail_hook when complete.

=cut

sub post_fail_hook {
    my $self = shift;

    record_info('Failure Hook', "Test failed, collecting logs for diagnosis");

    # Create log directory if it doesn't exist
    script_run("mkdir -p " . LOG_DIR);

    # Try to collect basic host logs
    eval {
        record_info('Host Logs', "Collecting host logs after failure");
        $self->collect_host_logs();
    };
    if ($@) {
        record_info('Host Log Error', "Host log collection failed: $@", result => 'fail');
    }

    # Try to collect guest logs if guests are available
    my @guests = keys %virt_autotest::common::guests;

    if (@guests) {
        foreach my $guest (@guests) {
            eval {
                # Check if guest is online before attempting to collect logs
                if (is_guest_online($guest)) {
                    record_info('Guest Logs', "Attempting to collect logs from guest: $guest");
                    $self->collect_guest_logs($guest);
                } else {
                    record_info('Guest Offline', "Guest $guest is not reachable, skipping log collection", result => 'softfail');
                }
            };
            if ($@) {
                record_info('Guest Log Error', "Guest log collection for $guest failed: $@", result => 'fail');
            } else {
                record_info('Guest Logs Complete', "Successfully collected logs from guest: $guest");
            }
        }
    }
    else {
        record_info('No Guests', "No guests found, skipping guest log collection", result => 'softfail');
    }

    # Create a simple failure marker file for reference
    my $failure_marker = LOG_DIR . "/test_failed_at_" . strftime("%Y%m%d-%H%M%S", localtime);
    script_run("touch $failure_marker");

    # Take a final screenshot for documentation
    save_screenshot;

    # Upload all collected logs after failure
    eval {
        record_info('Upload Failure Logs', "Uploading all collected logs after failure");
        $self->upload_all_logs();
    };
    if ($@) {
        record_info('Log Upload Error', "Failed to upload logs after failure: $@", result => 'fail');
    }

    # Call parent's post_fail_hook
    record_info('Parent Hook', "Calling parent post_fail_hook");
    $self->SUPER::post_fail_hook;
    return $self;
}

1;


