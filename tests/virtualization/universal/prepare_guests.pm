# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-client iputils nmap xen-tools
# Summary: Installation of HVM and PV guests
# Maintainer: Pavel Dostál <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use File::Copy 'copy';
use File::Path 'make_path';

sub create_profile {
    my ($vm_name, $arch, $mac, $ip) = @_;
    my $version = $vm_name =~ /sp/ ? $vm_name =~ s/\D*(\d+)sp(\d)\D*/$1.$2/r : $vm_name =~ s/\D*(\d+)\D*/$1/r;
    my $path = $version >= 15 ? "virtualization/autoyast/guest_15.xml.ep" : "virtualization/autoyast/guest_12.xml.ep";
    my $scc_code = get_required_var("SCC_REGCODE");
    my %ltss_products = @{get_var_array("LTSS_REGCODES_SECRET")};
    my $ca_str = "SLE_" . $version =~ s/\./_SP/r;
    record_info("$ca_str");
    my $profile = get_test_data($path);
    $profile =~ s/\{\{GUEST\}\}/$vm_name/g;
    $profile =~ s/\{\{SCC_REGCODE\}\}/$scc_code/g;
    $profile =~ s/\{\{ARCH\}\}/$arch/g;
    $profile =~ s/\{\{MAC\}\}/$mac/g;
    $profile =~ s/\{\{IP\}\}/$ip/g;
    $profile =~ s/\{\{VERSION\}\}/$version/g;
    $profile =~ s/\{\{CA_STR\}\}/$ca_str/g;
    $profile =~ s/\{\{PASS\}\}/$testapi::password/g;
    my $host_os_version = get_var('DISTRI') . "s" . lc(get_var('VERSION') =~ s/-//r);
    my $incident_repos = "";
    $incident_repos = get_var('INCIDENT_REPO', '') if ($vm_name eq $host_os_version || $vm_name eq "${host_os_version}PV" || $vm_name eq "${host_os_version}HVM");
    my $vars = {
        vm_name => $vm_name,
        ltss_code => $ltss_products{$version},
        repos => [split(/,/, $incident_repos)]
    };
    my $output = Mojo::Template->new(vars => 1)->render($profile, $vars);
    save_tmp_file("$vm_name.xml", $output);
    # Copy profile to ulogs directory, so profile is available in job logs
    make_path('ulogs');
    copy(hashed_string("$vm_name.xml"), "ulogs/$vm_name.xml");
    return autoinst_url . "/files/$vm_name.xml";
}

sub run {
    my $self = shift;
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    #    $self->select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;
    select_console('root-console');
    systemctl("restart libvirtd");
    assert_script_run('for i in $(virsh list --name|grep sles);do virsh destroy $i;done');
    assert_script_run('for i in $(virsh list --name --inactive); do virsh undefine $i --remove-all-storage;done');
    script_run 'rm -rf guests_ip';


    # Ensure additional package is installed
    zypper_call '-t in libvirt-client iputils nmap supportutils';

    assert_script_run "mkdir -p /var/lib/libvirt/images/xen/";

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

    script_run 'history -a';
    assert_script_run('cat ~/virt-install*', 30);
    script_run('xl dmesg |grep -i "fail\|error" |grep -vi Loglevel') if (is_xen_host());
}

sub post_fail_hook {
    my ($self) = @_;
    collect_virt_system_logs();
    $self->SUPER::post_fail_hook;
}

1;
