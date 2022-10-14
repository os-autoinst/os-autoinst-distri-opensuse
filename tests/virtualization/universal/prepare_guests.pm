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
# Maintainer: Pavel Dostál <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils qw(import_guest collect_virt_system_logs);
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use File::Copy 'copy';
use File::Path 'make_path';

my $h_version = get_var("VERSION") =~ s/-SP/./r;
sub create_profile {
    my ($vm_name, $arch, $mac, $ip) = @_;
    my $version = $vm_name =~ /sp/ ? $vm_name =~ s/\D*(\d+)sp(\d)\D*/$1.$2/r : $vm_name =~ s/\D*(\d+)\D*/$1/r;
    my $path = $version >= 15 ? "virtualization/autoyast/guest_15.xml.ep" : "virtualization/autoyast/guest_12.xml.ep";
    my $scc_code = get_required_var("SCC_REGCODE");
    my %ltss_products = @{get_var_array("LTSS_REGCODES_SECRET")};
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
    my $host_os_version = get_var('DISTRI') . "s" . lc(get_var('VERSION') =~ s/-//r);
    my $incident_repos = "";
    $incident_repos = get_var('INCIDENT_REPO', '') if ($vm_name eq $host_os_version || $vm_name eq "${host_os_version}PV" || $vm_name eq "${host_os_version}HVM");
    my $vars = {
        vm_name => $vm_name,
        ltss_code => $ltss_products{$version},
        repos => [split(/,/, $incident_repos)],
        check_var => \&check_var,
        get_var => \&get_required_var
    };
    my $output = Mojo::Template->new(vars => 1)->render($profile, $vars);
    save_tmp_file("$vm_name.xml", $output);
    # Copy profile to ulogs directory, so profile is available in job logs
    make_path('ulogs');
    copy(hashed_string("$vm_name.xml"), "ulogs/$vm_name.xml");
    return autoinst_url . "/files/$vm_name.xml";
}

sub gen_osinfo {
    my ($vm_name) = @_;
    #    my $h_version = get_var("VERSION") =~ s/-SP/./r;
    my $g_version = $vm_name =~ /sp/ ? $vm_name =~ s/\D*(\d+)sp(\d)\D*/$1.$2/r : $vm_name =~ s/\D*(\d+)\D*/$1/r;
    my $info_op = $h_version > 15.2 ? "--osinfo" : "--os-variant";
    my $info_val = $g_version > 12.5 ? $vm_name =~ s/HVM|PV//r =~ s/sles/sle/r : $vm_name =~ s/PV|HVM//r;
    if ($h_version == 12.3) {
        $info_val = "sle15-unknown" if ($g_version > 15.1);
        $info_val = "sles12-unknown" if ($g_version == 12.5);
    } elsif ($h_version == 12.4) {
        $info_val = "sle15-unknown" if ($g_version > 15.2);
    } elsif ($h_version == 15) {
        $info_val = "sle15-unknown" if ($g_version > 15.1);
    }
    # Return osinfo parameters (--osinfo/--variant OSNAME) for virt-install depends on supported status on different host os versions.
    return "$info_op $info_val";
}

sub create_guest {
    my ($guest, $method) = @_;
    my $v_type = $guest->{name} =~ /HVM/ ? "-v" : "";

    my $g_version = $guest->{name} =~ /sp/ ? $guest->{name} =~ s/\D*(\d+)sp(\d)\D*/$1.$2/r : $guest->{name} =~ s/\D*(\d+)\D*/$1/r;
    my $install_location = uc($guest->{name}) =~ s/SLES/SLE-/r =~ s/SP/-SP/r =~ s/HVM|PV//r;
    $install_location .= $g_version < 15 ? "-Server-GM" : $g_version < 15.2 ? "-Installer-LATEST" : "-Full-GM";
    $guest->{location} = "http://mirror.suse.cz/install/SLP/$install_location/x86_64/DVD1/";

    my $virt_install = "/usr/bin/virt-install --noautoconsole --network bridge=br0 --vcpus 2,maxvcpus=4 --memory 2048,maxmemory=4096 --events on_reboot=destroy --video=vga --serial pty";
    $guest->{install_cmd} = "$virt_install $guest->{osinfo} --name $guest->{name} $v_type --disk path=/var/lib/libvirt/images/$guest->{name}.qcow2,size=20 --location $guest->{location} -x autoyast=$guest->{autoyast} -x 'sshd=1 password=work' --graphics vnc,listen=0.0.0.0";
    record_info($guest->{install_cmd});
    assert_script_run($guest->{install_cmd});
}

sub run {
    select_console('root-console');
    systemctl("restart libvirtd");
    assert_script_run('for i in $(virsh list --name|grep -v Domain-0);do virsh destroy $i;done');
    assert_script_run('for i in $(virsh list --name --inactive); do if [[ $i == win* ]]; then virsh undefine $i; else virsh undefine $i --remove-all-storage; fi; done');
    script_run("[ -f /root/.ssh/known_hosts ] && > /root/.ssh/known_hosts");
    script_run('rm -rf /tmp/guests_ip');
    script_run("sed -i '/test_guest/d' /etc/hosts");

    #    my $guests_str = "sles12sp5,sles15sp3,sles15,sles15sp1,sles15sp4";
    #    my $guests_str = "sles12sp5,sles15sp3,sles15,sles15sp4";
    #    my $guests_str = "sles12sp3,sles15sp3,sles15sp1";
    #    VM_LIST = "sles12sp3,sles15sp3,sles15sp1";
    my @vms = split(',', get_required_var("VM_LIST"));
    my %guests = {};
    if (get_var('SYSTEM_ROLE') eq "kvm") {
        %guests = map(($_ => {name => $_}), @vms);
    } elsif (get_var('SYSTEM_ROLE') eq "xen") {
        %guests = map(($_ . HVM => {name => $_ . "HVM"}, $_ . PV => {name => $_ . "PV"}), @vms);
    } else {
        %guests = %virt_autotest::common::guests;
    }

    # Install or import defined guests
    foreach my $guest (values %guests) {
        my $method = $guest->{method} // 'virt-install'; # by default install guest using virt-install. SLES11 gets installed via importing a pre-installed guest however
        if ($method eq "virt-install") {
            $guest->{autoyast} = create_profile($guest->{name}, "x86_64", $guest->{macaddress}, $guest->{ip});
            record_info("$guest->{autoyast}");
            $guest->{osinfo} = gen_osinfo($guest->{name});
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
    assert_script_run "cat /etc/hosts";

    my $n = keys %guests;    #the number of guest to install
    my $time_cont = 0;
    #Check each guest if the IP address file is created and ip is written to /etc/hosts on host
    while ($n > 0) {
        if ($time_cont >= 20) {
            my $unfinished_install = join(',', map($_->{finish} != 1 ? $_->{name} : (), values(%guests)));
            record_soft_failure("$unfinished_install install incomplete after " . $time_cont * 2 . " minutes! poo#55555");
            last;
        }
        while (my ($vm_name, $vm_info) = each %guests) {
            next if ($vm_info->{finish} == 1);
            #check if vm write its IP address in /tmp/guests_ip/$vm_name on host.
            if (script_run("[[ -f /tmp/guests_ip/$vm_name ]]") == 0) {
                $vm_info->{finish} = 1;
                record_info("$vm_name: install finished");
                assert_script_run(qq(echo "\$(cat /tmp/guests_ip/$vm_name) $vm_name #test_guest" >> /etc/hosts));
                $n--;
            } else {
                my $vm_state = script_output("virsh domstate --domain $vm_name");
                if ($vm_state eq "shut off") {
                    $h_version < 15.4 ? assert_script_run("virt-xml $vm_name --add-device --controller type=pci,index=11,model=pcie-to-pci-bridge") : assert_script_run("virt-xml $vm_name --add-device --controller type=pci,model=pcie-to-pci-bridge") if ($h_version > 15 && get_var("KVM"));
                    assert_script_run("virsh start $vm_name");
                    record_info("Reboot: $vm_name");
                }
            }
        }
        sleep 120 if ($n != 0);
        $time_cont++;
        record_info("$time_cont");
    }
}

sub post_fail_hook {
    my ($self) = @_;
    #    collect_virt_system_logs();
    #    $self->SUPER::post_fail_hook;
}

1;
