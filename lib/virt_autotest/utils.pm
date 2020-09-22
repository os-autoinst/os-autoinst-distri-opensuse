# SUSE's openQA tests
#
# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: virtualization test utilities.
# Maintainer: Julie CAO <jcao@suse.com>

package virt_autotest::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use utils;
use version_utils;
use testapi;
use DateTime;
use Utils::Architectures 'is_s390x';

our @EXPORT = qw(is_vmware_virtualization is_hyperv_virtualization is_fv_guest is_pv_guest is_xen_host is_kvm_host check_host check_guest print_cmd_output_to_file
  ssh_setup ssh_copy_id create_guest install_default_packages upload_y2logs ensure_online);

#return 1 if it is a VMware test judging by REGRESSION variable
sub is_vmware_virtualization {
    return get_var("REGRESSION", '') =~ /vmware/;
}

#return 1 if it is a Hyper-V test judging by REGRESSION variable
sub is_hyperv_virtualization {
    return get_var("REGRESSION", '') =~ /hyperv/;
}

#return 1 if it is a fv guest judging by name
#feel free to extend to support more cases
sub is_fv_guest {
    my $guest = shift;
    return $guest =~ /\bfv\b/ || $guest =~ /\bhvm\b/;
}

#return 1 if it is a pv guest judging by name
#feel free to extend to support more cases
sub is_pv_guest {
    my $guest = shift;
    return $guest =~ /\bpv\b/;
}

#return 1 if test is expected to run on KVM hypervisor
sub is_kvm_host {
    return check_var("SYSTEM_ROLE", "kvm") || check_var("HOST_HYPERVISOR", "kvm") || check_var("REGRESSION", "qemu-hypervisor");
}

#return 1 if test is expected to run on XEN hypervisor
sub is_xen_host {
    return get_var("XEN") || check_var("SYSTEM_ROLE", "xen") || check_var("HOST_HYPERVISOR", "xen") || check_var("REGRESSION", "xen-hypervisor");
}

#check host to make sure it works well
#welcome everybody to extend this function
sub check_host {

}

#check guest to make sure it works well
#welcome everybody to extend this function
sub check_guest {
    my $vm = shift;

    #check if guest is still alive
    validate_script_output "virsh domstate $vm", sub { /running/ };

    #TODO: other checks like checking journals from guest
    #need check the oops bug

}

#ammend the output of the command to an existing log file
#passing guest name or an remote IP as the 3rd parameter if running command in a remote machine
sub print_cmd_output_to_file {
    my ($cmd, $file, $machine) = @_;

    $cmd = "ssh root\@$machine \"" . $cmd . "\"" if $machine;
    script_run "echo -e \"\n# $cmd\" >> $file";
    script_run "$cmd >> $file";
}

sub ssh_setup {
    my $default_ssh_key = (!(get_var('VIRT_AUTOTEST'))) ? "/root/.ssh/id_rsa" : "/var/testvirt.net/.ssh/id_rsa";
    my $dt              = DateTime->now;
    my $comment         = "openqa-" . $dt->mdy . "-" . $dt->hms('-') . get_var('NAME');
    if (script_run("[[ -s $default_ssh_key ]]") != 0) {
        assert_script_run "ssh-keygen -t rsa -P '' -C '$comment' -f $default_ssh_key";
    }
}

sub ssh_copy_id {
    my $guest           = shift;
    my $mode            = is_sle('=11-sp4')             ? ''                      : '-f';
    my $default_ssh_key = (!(get_var('VIRT_AUTOTEST'))) ? "/root/.ssh/id_rsa.pub" : "/var/testvirt.net/.ssh/id_rsa.pub";
    script_retry "nmap $guest -PN -p ssh | grep open", delay => 15, retry => 12;
    assert_script_run "ssh-keyscan $guest >> ~/.ssh/known_hosts";
    if (script_run("ssh -o PreferredAuthentications=publickey root\@$guest hostname -f") != 0) {
        exec_and_insert_password("ssh-copy-id -i $default_ssh_key -o StrictHostKeyChecking=no $mode root\@$guest");
    }
}

sub create_guest {
    my ($guest, $method) = @_;

    my $name         = $guest->{name};
    my $location     = $guest->{location};
    my $autoyast     = $guest->{autoyast};
    my $macaddress   = $guest->{macaddress};
    my $extra_params = $guest->{extra_params} // "";

    if ($method eq 'virt-install') {
        record_info "$name", "Going to create $name guest";
        send_key 'ret';    # Make some visual separator

        # Run unattended installation for selected guest
        assert_script_run "qemu-img create -f qcow2 /var/lib/libvirt/images/xen/$name.qcow2 20G", 180;
        script_run "( virt-install $extra_params --name $name --vcpus=2,maxvcpus=4 --memory=2048,maxmemory=4096 --disk /var/lib/libvirt/images/xen/$name.qcow2 --network network=default,mac=$macaddress --noautoconsole --vnc --autostart --location=$location --wait -1 --extra-args 'autoyast=" . data_url($autoyast) . "' >> virt-install_$name.txt 2>&1 & )";
    }
}

sub install_default_packages {
    # Install nmap, ip, dig
    if (is_s390x()) {
        # Use static call to avoid cyclical imports
        virt_utils::lpar_cmd("zypper --non-interactive in nmap iputils bind-utils");
    } else {
        zypper_call '-t in nmap iputils bind-utils', exitcode => [0, 4, 102, 103, 106];
    }
}

sub ensure_online {
    my ($guest, %args) = @_;

    my $hypervisor = $args{HYPERVISOR}    // "192.168.122.1";
    my $dns_host   = $args{DNS_TEST_HOST} // "suse.de";
    # Ensure guest is running
    # Only xen/kvm support to reboot guest at the moment
    if (is_xen_host || is_kvm_host) {
        if (script_run("virsh list --all | grep '$guest' | grep running") != 0) {
            assert_script_run("virsh start '$guest'");
        }
    }
    die "$guest does not respond to ICMP" if (script_retry("ping -c 1 '$guest'", delay => 5, retry => 60) != 0);
    # Wait for ssh to come up
    die "$guest does not start ssh" if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 15, retry => 12) != 0);
    die "$guest not ssh-reachable"  if (script_run("ssh $guest uname") != 0);
    # Ensure default route is set
    script_run("ssh $guest ip route add default via $hypervisor");
    die "Pinging hypervisor failed for $guest" if (script_retry("ssh $guest ping -c 1 $hypervisor", delay => 1, retry => 10) != 0);
    # Check also if name resolution works
    die "name resolution failed for $guest" if (script_retry("ssh $guest ping -c 1 -w 120 $dns_host", delay => 1, retry => 10) != 0);
}

sub upload_y2logs {
    # Create and Upload y2log for analysis
    assert_script_run "save_y2logs /tmp/y2logs.tar.bz2", 180;
    upload_logs("/tmp/y2logs.tar.bz2");
    save_screenshot;
}

1;
