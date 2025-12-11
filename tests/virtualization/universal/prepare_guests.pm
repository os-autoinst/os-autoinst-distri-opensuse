# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Installation of HVM and PV guests
#
# PATCH_WITH_ZYPPER: switching between zypper and autoyast install.
# UPDATE_PACKAGE: check if the MU package is installed from testing repo.
# PATCH_WITH_ZYPPER and UPDATE_PACKAGE are not defined in settings. They
# should be specified on command line when scheduling tests.
#
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use File::Copy 'copy';
use File::Path 'make_path';
use virt_autotest::utils qw(is_sles16_mu_virt_test);
use autoyast qw(expand_agama_secrets);

sub create_agama_profile {
    my ($vm_name, $arch, $mac, $ip) = @_;

    # Determine the appropriate Agama configuration for SLES16 guests
    # Note: Full vs Online difference is handled by virt-install location parameter,
    # not by different Agama configurations
    # Only staging mode is supported
    my $test_mode = 'staging';

    # Select appropriate Agama configuration file (only staging supported)
    my $agama_config_file = "sle_virt_guest_staging.jsonnet";
    my $config_path = "virtualization/agama_virt_auto/$agama_config_file";

    record_info("SLES16 Agama Profile", "Using config: $agama_config_file for guest: $vm_name");

    # Get the Agama configuration template
    my $profile = get_test_data($config_path);

    # Expand Agama secrets ({{_SECRET_ED25519_PUB_KEY}} and {{_SECRET_ED25519_PRIV_KEY}})
    $profile = expand_agama_secrets($profile);
    record_info("SSH Key Injection", "Expanded Agama secrets for SSH public key authentication");

    # Replace placeholders with actual values needed by Agama jsonnet

    # Set Agama product ID for SLES16
    my $agama_product_id = get_var('AGAMA_PRODUCT_ID', 'SLES');
    $profile =~ s/\{\{AGAMA_PRODUCT_ID\}\}/$agama_product_id/g;

    # Handle SCC registration for SLES16
    if (my $scc_code = get_var("SCC_REGCODE")) {
        $profile =~ s/\{\{SCC_REGCODE\}\}/$scc_code/g;
    }

    # Handle password and SUT_IP for IP reporting script
    my $sut_ip = get_required_var("SUT_IP");
    $profile =~ s/\{\{PASS\}\}/$testapi::password/g;
    $profile =~ s/\{\{SUT_IP\}\}/$sut_ip/g;
    $profile =~ s/\{\{GUEST\}\}/$vm_name/g;

    # Handle repositories - only staging mode supported
    my $incident_repo = get_var('INCIDENT_REPO', '');
    $profile =~ s/\{\{INCIDENT_REPO\}\}/$incident_repo/g;
    record_info("Staging Repos", "Using INCIDENT_REPO: $incident_repo") if $incident_repo;

    # Save the generated Agama profile
    my $profile_filename = "${vm_name}_agama.jsonnet";
    save_tmp_file($profile_filename, $profile);

    # Copy profile to ulogs directory for debugging
    make_path('ulogs');
    copy(hashed_string($profile_filename), "ulogs/$profile_filename");

    record_info("Agama Profile Generated", "Created profile: $profile_filename");

    return autoinst_url . "/files/$profile_filename";
}

sub create_autoyast_profile {
    my ($vm_name, $arch, $mac, $ip) = @_;

    # Original autoyast profile creation logic
    my $version = $vm_name =~ /sp/ ? $vm_name =~ s/\D*(\d+)sp(\d)\D*/$1.$2/r : $vm_name =~ s/\D*(\d+)\D*/$1/r;
    my $path = $version >= 15 ? "virtualization/autoyast/guest_15.xml.ep" : "virtualization/autoyast/guest_12.xml.ep";
    my $scc_code = get_required_var("SCC_REGCODE");
    my %ltss_products = @{get_var_array("LTSS_REGCODES_SECRET")};
    my %ltss_es_products = @{get_var_array("LTSS_ES_REGCODES_SECRET")};
    my $ca_str = "SLE_" . $version =~ s/\./_SP/r;
    my $sut_ip = get_required_var("SUT_IP");
    my $profile = get_test_data($path);
    $profile =~ s/\{\{GUEST\}\}/$vm_name/g;
    $profile =~ s/\{\{SCC_REGCODE\}\}/$scc_code/g;
    $profile =~ s/\{\{ARCH\}\}/$arch/g;
    $profile =~ s/\{\{MAC\}\}/$mac/g;
    $profile =~ s/\{\{IP\}\}/$ip/g;
    $profile =~ s/\{\{VERSION\}\}/$version/g;
    $profile =~ s/\{\{CA_STR\}\}/$ca_str/g;
    $profile =~ s/\{\{PASS\}\}/$testapi::password/g;
    $profile =~ s/\{\{SUT_IP\}\}/$sut_ip/g;

    # Handle EFI boot configuration for UEFI guests
    my %guests = %virt_autotest::common::guests;
    if (exists $guests{$vm_name} && exists $guests{$vm_name}->{boot_firmware} && $guests{$vm_name}->{boot_firmware} eq 'efi') {
        $profile =~ s/<loader_type>grub2<\/loader_type>/<loader_type>grub2-efi<\/loader_type>/;
        record_info("UEFI Config", "Modified autoyast profile for $vm_name to use grub2-efi for UEFI boot");
    }

    my $host_os_version = get_var('DISTRI') . "s" . lc(get_var('VERSION') =~ s/-//r);
    my $incident_repos = "";
    $incident_repos = get_var('INCIDENT_REPO', '') if ($vm_name eq $host_os_version || $vm_name eq "${host_os_version}PV" || $vm_name eq "${host_os_version}HVM");
    my $vars = {
        vm_name => $vm_name,
        ltss_code => $ltss_products{$version},
        ltss_es_code => $ltss_es_products{$version},
        repos => [split(/,/, $incident_repos)],
        check_var => \&check_var,
        get_var => \&get_var
    };
    my $output = Mojo::Template->new(vars => 1)->render($profile, $vars);
    save_tmp_file("$vm_name.xml", $output);
    # Copy profile to ulogs directory, so profile is available in job logs
    make_path('ulogs');
    copy(hashed_string("$vm_name.xml"), "ulogs/$vm_name.xml");
    return autoinst_url . "/files/$vm_name.xml";
}

sub create_profile {
    my ($vm_name, $arch, $mac, $ip) = @_;

    # Intelligent profile selection: use Agama for SLES16 MU tests, autoyast for others
    if (is_sles16_mu_virt_test() && $vm_name =~ /sles16/i) {
        record_info("Profile Selection", "Using Agama profile for SLES16 guest: $vm_name");
        return create_agama_profile($vm_name, $arch, $mac, $ip);
    } else {
        record_info("Profile Selection", "Using AutoYaST profile for guest: $vm_name");
        return create_autoyast_profile($vm_name, $arch, $mac, $ip);
    }
}

sub gen_osinfo {
    my ($vm_name) = @_;
    my $h_version = get_var("VERSION") =~ s/-SP/./r;
    my $g_version = $vm_name =~ /sp/ ? $vm_name =~ s/\D*(\d+)sp(\d)\D*/$1.$2/r : $vm_name =~ s/\D*(\d+)\D*/$1/r;
    my $info_op = $h_version > 15.2 ? "--osinfo" : "--os-variant";

    # Clean VM name by removing virtualization type suffixes (order matters: longer matches first)
    my $clean_name = $vm_name =~ s/(efi_online|efi_full|HVM|PV|-efi-sev-es|efi).*$//r;

    # Generate OS identifier based on guest version
    my $info_val;
    if ($g_version >= 16) {
        # SLES16 series: keep sles prefix, support SP versions
        # sles16efi_online -> sles16
        # sles16sp1efi -> sles16sp1
        # sles16sp2efi_full -> sles16sp2
        $info_val = $clean_name;    # Keep original sles16[spX] format
    } elsif ($g_version > 12.5) {
        $info_val = $clean_name =~ s/sles/sle/r;    # SLES15: convert sles->sle
    } else {
        $info_val = $clean_name;    # SLES12: keep as-is
    }

    # Handle host/guest version compatibility issues
    if ($h_version == 12.3 && $g_version > 15.1) { $info_val = "sle15-unknown"; }
    if ($h_version == 12.3 && $g_version == 12.5) { $info_val = "sles12-unknown"; }
    if ($h_version == 12.4 && $g_version > 15.2) { $info_val = "sle15-unknown"; }
    if ($h_version == 15 && $g_version > 15.1) { $info_val = "sle15-unknown"; }

    return "$info_op $info_val";
}

sub run {
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    #    select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;
    select_console('root-console');
    # Note: TBD for modular libvirt. See poo#129086 for detail.
    restart_libvirtd;
    assert_script_run('for i in $(virsh list --name|grep -v Domain-0);do virsh destroy $i;done');
    assert_script_run('for i in $(virsh list --name --inactive); do if [[ $i == win* ]]; then virsh undefine $i; else virsh undefine $i --remove-all-storage; fi; done');
    script_run("[ -f /root/.ssh/known_hosts ] && > /root/.ssh/known_hosts");
    script_run 'rm -rf /tmp/guests_ip';


    # Ensure additional package is installed
    zypper_call '-t in libvirt-client iputils nmap supportutils';
    if (script_run("virsh net-list --all | grep default") != 0) {
        assert_script_run "curl " . data_url("virt_autotest/default_network.xml") . " -o ~/default_network.xml";
        assert_script_run "virsh net-define --file ~/default_network.xml";
    }
    assert_script_run "virsh net-start default || true", 90;
    assert_script_run "virsh net-autostart default", 90;

    # Show all guests
    assert_script_run 'virsh list --all';
    wait_still_screen 1;

    # Disable bash monitoring, so the output of completed background jobs doesn't confuse openQA
    script_run("set +m");

    # Install or import defined guests
    foreach my $guest (values %virt_autotest::common::guests) {
        my $method = $guest->{method} // 'virt-install'; # by default install guest using virt-install. SLES11 gets installed via importing a pre-installed guest however
        if ($method eq "virt-install") {
            $guest->{autoyast} = create_profile($guest->{name}, "x86_64", $guest->{macaddress}, $guest->{ip});
            record_info("$guest->{autoyast}");
            $guest->{osinfo} = gen_osinfo($guest->{name});

            # For SLES16 VMs with kernel update, disable secure boot
            if ($guest->{name} =~ /sles16/i && get_var("UPDATE_PACKAGE", "") =~ /kernel/) {
                if ($guest->{boot_firmware} && $guest->{boot_firmware} =~ /^efi/) {
                    $guest->{boot_firmware_disable_secure} = 1;
                    record_info("Secure Boot", "Disabling secure boot for $guest->{name} due to kernel update");
                }
            }

            create_guest($guest, $method);
        } elsif ($method eq "import") {
            # Download the diskimage. Note: this could be merged with download_image.pm at some point
            my $source = $guest->{source};
            my $disk = $guest->{disk};
            script_retry("curl $source -o $disk", retry => 3, delay => 60, timeout => 300);
            import_guest($guest);
        } else {
            die "Unsupported method '$method' for guest $guest";
        }
    }
}

sub post_fail_hook {
    my ($self) = @_;
    collect_virt_system_logs();
    $self->SUPER::post_fail_hook;
}

1;
