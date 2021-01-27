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

our @EXPORT = qw(is_vmware_virtualization is_hyperv_virtualization is_fv_guest is_pv_guest is_xen_host is_kvm_host
  check_host check_guest print_cmd_output_to_file ssh_setup ssh_copy_id create_guest import_guest install_default_packages
  upload_y2logs ensure_default_net_is_active ensure_online add_guest_to_hosts restart_libvirtd remove_additional_disks
  remove_additional_nic collect_virt_system_logs shutdown_guests wait_guest_online start_guests is_guest_online);

sub restart_libvirtd {
    is_sle '12+' ? systemctl "restart libvirtd", timeout => 180 : assert_script_run "service libvirtd restart", 180;
}

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
#only support simple bash command so far, eg. '|' is not supported in $cmd.
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
    my ($guest, %args) = @_;

    my $username        = $args{username}        // 'root';
    my $authorized_keys = $args{authorized_keys} // '.ssh/authorized_keys';
    my $scp             = $args{scp}             // 0;
    my $mode            = is_sle('=11-sp4')             ? ''                      : '-f';
    my $default_ssh_key = (!(get_var('VIRT_AUTOTEST'))) ? "/root/.ssh/id_rsa.pub" : "/var/testvirt.net/.ssh/id_rsa.pub";
    script_retry "nmap $guest -PN -p ssh | grep open", delay => 15, retry => 12;
    assert_script_run "ssh-keyscan $guest >> ~/.ssh/known_hosts";
    if (script_run("ssh -o PreferredAuthentications=publickey -o ControlMaster=no $username\@$guest hostname") != 0) {
        # Our client key is not authorized, we have to type password with evry command
        my $options = "-o PreferredAuthentications=password,keyboard-interactive -o ControlMaster=no";
        unless ($scp == 1) {
            exec_and_insert_password("ssh-copy-id $options $mode -i $default_ssh_key $username\@$guest");
        } else {
            exec_and_insert_password("ssh $options $username\@$guest 'mkdir .ssh' || true");
            exec_and_insert_password("scp $options $default_ssh_key $username\@$guest:'$authorized_keys'");
            if (script_run("nmap $guest -PN -p ssh -sV | grep Windows") == 0) {
                exec_and_insert_password("ssh $options $username\@$guest 'icacls $authorized_keys /remove \"NT AUTHORITY\\Authenticated Users\"'");
                exec_and_insert_password("ssh $options $username\@$guest 'icacls $authorized_keys /inheritance:r'");
            } else {
                exec_and_insert_password("ssh $options $username\@$guest 'chmod 0700 ~/.ssh/'");
                exec_and_insert_password("ssh $options $username\@$guest 'chmod 0644 ~/.ssh/authorized_keys'");
            }
        }
        assert_script_run "ssh -o PreferredAuthentications=publickey -o ControlMaster=no $username\@$guest hostname";
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
        my ($autoyastURL, $diskformat, $virtinstall);
        $autoyastURL = data_url($autoyast);
        $diskformat  = get_var("VIRT_QEMU_DISK_FORMAT") // "qcow2";

        assert_script_run "qemu-img create -f $diskformat /var/lib/libvirt/images/xen/$name.$diskformat 20G", 180;
        assert_script_run "sync",                                                                             180;
        script_run "qemu-img info /var/lib/libvirt/images/xen/$name.$diskformat";

        $virtinstall = "virt-install $extra_params --name $name --vcpus=2,maxvcpus=4 --memory=2048,maxmemory=4096 --vnc";
        $virtinstall .= " --disk /var/lib/libvirt/images/xen/$name.$diskformat --noautoconsole";
        $virtinstall .= " --network network=default,mac=$macaddress --autostart --location=$location --wait -1";
        $virtinstall .= " --events on_reboot=destroy --extra-args 'autoyast=$autoyastURL'";
        script_run "( $virtinstall >> ~/virt-install_$name.txt 2>&1 & )";

        script_retry("grep -B99 -A99 'initrd' ~/virt-install_$name.txt", delay => 15, retry => 12, die => 0);
    }
}

sub import_guest {
    my ($guest, $method) = @_;

    my $name         = $guest->{name};
    my $disk         = $guest->{disk};
    my $macaddress   = $guest->{macaddress};
    my $extra_params = $guest->{extra_params} // "";

    if ($method eq 'virt-install') {
        record_info "$name", "Going to import $name guest";
        send_key 'ret';    # Make some visual separator

        # Run unattended installation for selected guest
        my $virtinstall = "virt-install $extra_params --name $name --vcpus=4,maxvcpus=4 --memory=4096,maxmemory=4096 --cpu host";
        $virtinstall .= " --graphics vnc --disk $disk --network network=default,mac=$macaddress,model=e1000 --noautoconsole  --autostart --import";
        assert_script_run $virtinstall;
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

    my $hypervisor   = $args{HYPERVISOR}    // "192.168.122.1";
    my $dns_host     = $args{DNS_TEST_HOST} // "suse.de";
    my $skip_ssh     = $args{skip_ssh}      // 0;
    my $skip_network = $args{skip_network}  // 0;
    my $skip_ping    = $args{skip_ping}     // 0;
    my $ping_delay   = $args{ping_delay}    // 15;
    my $ping_retry   = $args{ping_retry}    // 60;

    # Ensure guest is running
    # Only xen/kvm support to reboot guest at the moment
    if (is_xen_host || is_kvm_host) {
        if (script_run("virsh list | grep '$guest'") != 0) {
            assert_script_run("virsh start '$guest'");
            script_retry("ping -c 1 '$guest'", delay => 10, retry => 30);
        }
    }
    unless ($skip_network == 1) {
        # Check if we can ping guest
        unless ($skip_ping == 1) {
            die "$guest does not respond to ICMP" if (script_retry("ping -c 1 '$guest'", delay => $ping_delay, retry => $ping_retry) != 0);
        }
        unless ($skip_ssh == 1) {
            # Wait for ssh to come up
            die "$guest does not start ssh" if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 15, retry => 12) != 0);
            die "$guest not ssh-reachable"  if (script_run("ssh $guest uname") != 0);
            # Ensure default route is set
            if (script_run("ssh $guest ip r s | grep default") != 0) {
                assert_script_run("ssh $guest ip r a default via $hypervisor");
            }
            # Check if we can ping hypervizor from the guest
            unless ($skip_ping == 1) {
                die "Pinging hypervisor failed for $guest" if (script_retry("ssh $guest ping -c 3 $hypervisor", delay => 1, retry => 10, timeout => 90) != 0);
            }
            # Check also if name resolution works - restart libvirtd if not
            if (script_run("ssh $guest ping -c 3 -w 120 $dns_host", timeout => 180) != 0) {
                restart_libvirtd                        if (is_xen_host || is_kvm_host);
                die "name resolution failed for $guest" if (script_retry("ssh $guest ping -c 3 -w 120 $dns_host", delay => 1, retry => 10, timeout => 180) != 0);
            }
        }
    }
}

sub upload_y2logs {
    # Create and Upload y2log for analysis
    assert_script_run "save_y2logs /tmp/y2logs.tar.bz2", 180;
    upload_logs("/tmp/y2logs.tar.bz2");
    save_screenshot;
}

sub ensure_default_net_is_active {
    if (script_run("virsh net-list --all | grep default | grep ' active'", 90) != 0) {
        restart_libvirtd;
        if (script_run("virsh net-list --all | grep default | grep ' active'", 90) != 0) {
            assert_script_run "virsh net-start default";
        }
    }
}

sub add_guest_to_hosts {
    my ($hostname, $address) = @_;
    assert_script_run "sed -i '/ $hostname /d' /etc/hosts";
    assert_script_run "echo '$address $hostname # virtualization' >> /etc/hosts";
}

# Remove additional disks from the given guest. We remove all disks that match the given pattern or 'vd[b-z]' if no pattern is given
sub remove_additional_disks {
    my $guest   = $_[0];
    my $pattern = $_[1] // "x?vd[b-z]";

    return if ($guest == 0);
    my $cmd = 'for i in `virsh domblklist ' . "'$guest'" . ' | grep ' . "'$pattern'" . ' | awk "{print $1}"`; do virsh detach-disk ' . "'$guest' " . '"$i"; done';
    return script_run($cmd);
}

# Remove additional network interfaces from $guest. The NIC needs to be identified by it's mac address of mac address prefix (e.g. '00:16:3f:32')
# returns the status code of the remove command
sub remove_additional_nic {
    my $guest      = $_[0] // '';
    my $mac_prefix = $_[1] // '';

    return                       if ($guest == 0);
    die "mac_prefix not defined" if ($mac_prefix == 0);

    my $cmd = 'for i in `virsh domiflist ' . "'$guest'" . ' | grep ' . "'$mac_prefix'" . ' | awk "{print $5}"`; do virsh detach-interface ' . "'$guest'" . ' bridge --mac "$i"; done';
    return script_run($cmd);
}

sub collect_virt_system_logs {
    if (script_run("test -f /var/log/libvirt/libvirtd.log") == 0) {
        upload_logs("/var/log/libvirt/libvirtd.log");
    } else {
        record_info "File /var/log/libvirt/libvirtd.log does not exist.";
    }

    if (script_run("test -d /var/log/libvirt/libxl/") == 0) {
        assert_script_run 'tar czvf /tmp/libxl.tar.gz /var/log/libvirt/libxl/';
        upload_asset '/tmp/libxl.tar.gz';
    } else {
        record_info "Directory /var/log/libvirt/libxl/ does not exist.";
    }

    if (script_run("test -d /var/log/xen/") == 0) {
        assert_script_run 'tar czvf /tmp/xen.tar.gz /var/log/xen/';
        upload_asset '/tmp/xen.tar.gz';
    } else {
        record_info "Directory /var/log/xen/ does not exist.";
    }

    assert_script_run("journalctl -b > /tmp/journalctl-b.txt");
    upload_logs("/tmp/journalctl-b.txt");

    assert_script_run 'virsh list --all';

    assert_script_run 'mkdir -p /tmp/dumpxml';
    assert_script_run 'for guest in `virsh list --all --name`; do virsh dumpxml $guest > /tmp/dumpxml/$guest.xml; done';
    assert_script_run 'tar czvf /tmp/dumpxml.tar.gz /tmp/dumpxml/';
    upload_asset '/tmp/dumpxml.tar.gz';
}

# Check if guest is online by checking if the ssh port is open
sub is_guest_online {
    my $guest = shift;
    return script_run("nmap $guest -PN -p ssh | grep open") == 0;
}

# Shutdown all guests. Wait until they are shutdown
sub shutdown_guests {
    ## Reboot the guest to ensure the settings are applied
    # Shutdown and start the guest because some might have the on_reboot=destroy policy still applied
    script_run("virsh shutdown $_") foreach (keys %virt_autotest::common::guests);
    # Wait until guests are terminated
    # Note: Domain-0 is for xen only, but it does not hurt to exclude this also in KVM runs.
    script_retry("virsh list | grep -v Domain-0 | grep running", delay => 3, retry => 30, expect => 1);
}

sub wait_guest_online {
    my $guest = shift;
    # Wait until guest is reachable via ping
    script_retry("ping -c 1 $guest", delay => 5, retry => 60);
    # Wait until guest is reachable via ssh
    script_retry("nmap $guest -PN -p ssh | grep open", delay => 5, retry => 60);
}

# Start all guests and waits until they are online
sub start_guests {
    script_run "virsh start $_" foreach (keys %virt_autotest::common::guests);
    # Wait until ssh is ready for guest
    wait_guest_online($_) foreach (keys %virt_autotest::common::guests);
}

1;
