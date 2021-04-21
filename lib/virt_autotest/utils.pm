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
use upload_system_log 'upload_supportconfig_log';
use version_utils;
use testapi;
use DateTime;
use NetAddr::IP;
use Net::IP qw(:PROC);
use File::Basename;
use Utils::Architectures 'is_s390x';

our @EXPORT = qw(is_vmware_virtualization is_hyperv_virtualization is_fv_guest is_pv_guest is_guest_ballooned is_xen_host is_kvm_host
  check_host check_guest print_cmd_output_to_file ssh_setup ssh_copy_id create_guest import_guest install_default_packages
  upload_y2logs ensure_default_net_is_active ensure_guest_started ensure_online add_guest_to_hosts restart_libvirtd remove_additional_disks
  remove_additional_nic collect_virt_system_logs shutdown_guests wait_guest_online start_guests is_guest_online wait_guests_shutdown
  setup_common_ssh_config add_alias_in_ssh_config parse_subnet_address_ipv4 backup_file);

# helper function: Trim string
sub trim {
    my $text = shift;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

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

#return 1 if max_mem > memory in vm configuration file in libvirt
sub is_guest_ballooned {
    my $guest = shift;

    my $mem     = "";
    my $cur_mem = "";
    $mem     = script_output "virsh dumpxml $guest | xmlstarlet sel -t -v //memory";
    $cur_mem = script_output "virsh dumpxml $guest | xmlstarlet sel -t -v //currentMemory";
    return $mem > $cur_mem;
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
    my $on_reboot    = $guest->{on_reboot}    // "restart";    # configurable on_reboot policy
    my $extra_params = $guest->{extra_params} // "";           # extra-parameters
    my $extra_args   = get_var("VIRTINSTALL_EXTRA_ARGS", "") . " " . get_var("VIRTINSTALL_EXTRA_ARGS_" . uc($name), "");
    $extra_args = trim($extra_args);

    if ($method eq 'virt-install') {
        send_key 'ret';                                        # Make some visual separator

        # Run unattended installation for selected guest
        my ($autoyastURL, $diskformat, $virtinstall);
        $autoyastURL = data_url($autoyast);
        $diskformat  = get_var("VIRT_QEMU_DISK_FORMAT") // "qcow2";

        assert_script_run "qemu-img create -f $diskformat /var/lib/libvirt/images/xen/$name.$diskformat 20G", 180;
        assert_script_run "sync",                                                                             180;
        script_run "qemu-img info /var/lib/libvirt/images/xen/$name.$diskformat";

        $extra_args  = "autoyast=$autoyastURL $extra_args";
        $extra_args  = trim($extra_args);
        $virtinstall = "virt-install $extra_params --name $name --vcpus=2,maxvcpus=4 --memory=2048,maxmemory=4096 --vnc";
        $virtinstall .= " --disk /var/lib/libvirt/images/xen/$name.$diskformat --noautoconsole";
        $virtinstall .= " --network network=default,mac=$macaddress --autostart --location=$location --wait -1";
        $virtinstall .= " --events on_reboot=$on_reboot" unless ($on_reboot eq '');
        $virtinstall .= " --extra-args '$extra_args'"    unless ($extra_args eq '');
        record_info("$name", "Creating $name guests:\n$virtinstall");
        script_run "$virtinstall >> ~/virt-install_$name.txt 2>&1 & true";    # true required because & terminator is not allowed

        # wait for initrd to ensure the installation is starting
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

# ensure_online($guest) - Ensures the given guests is started and fixes some common network issues
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
            wait_guest_online($guest);
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

    upload_system_log::upload_supportconfig_log();
}

# is_guest_online($guest) check if the given guests is online by probing for an open ssh port
sub is_guest_online {
    my $guest = shift;
    return script_run("nmap $guest -PN -p ssh | grep open") == 0;
}

# wait_guest_online($guest, [$timeout]) waits until the given guests is online by probing for an open ssh port
sub wait_guest_online {
    my $guest   = shift;
    my $retries = shift // 300;
    # Wait until guest is reachable via ssh
    script_retry("nmap $guest -PN -p ssh | grep open", delay => 1, retry => $retries);
}

# Shutdown all guests and wait until they are shutdown
sub shutdown_guests {
    ## Reboot the guest to ensure the settings are applied
    # Shutdown and start the guest because some might have the on_reboot=destroy policy still applied
    script_run("virsh shutdown $_") foreach (keys %virt_autotest::common::guests);
    # Wait until guests are terminated
    wait_guests_shutdown();
}

# wait_guests_shutdown([$timeout]) waits for all guests to be shutdown
sub wait_guests_shutdown {
    my $retries = shift // 240;
    # Note: Domain-0 is for xen only, but it does not hurt to exclude this also in kvm runs.
    script_retry("! virsh list | grep -v Domain-0 | grep running", delay => 1, retry => $retries);
}

# Start all guests and wait until they are online
sub start_guests {
    script_run "virsh start $_" foreach (keys %virt_autotest::common::guests);
    # Wait for guests to show up as running
    script_retry("virsh list | grep $_ | grep running", delay => 5, retry => 10) foreach (keys %virt_autotest::common::guests);
    wait_guest_online($_) foreach (keys %virt_autotest::common::guests);
}

#Add common ssh options to host ssh config file to be used for all ssh connections when host tries to ssh to another host/guest.
sub setup_common_ssh_config {
    my $ssh_config_file = shift;

    $ssh_config_file //= '/root/.ssh/config';
    if (script_run("test -f $ssh_config_file") ne 0) {
        script_run "mkdir -p " . dirname($ssh_config_file);
        assert_script_run("touch $ssh_config_file");
    }
    if (script_run("grep \"Host \\\*\" $ssh_config_file") ne 0) {
        type_string("cat >> $ssh_config_file <<EOF
Host *
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    User root
    PreferredAuthentications publickey
EOF
");
    }
    assert_script_run("chmod 600 $ssh_config_file");
    record_info("Content of $ssh_config_file after common ssh config setup", script_output("cat $ssh_config_file;ls -lah $ssh_config_file"));
    return;
}

#If certain host or guest is assigned a transient hostname from DNS server in company wide space, so the transient hostname becomes the real hostname to be indentified
#on the network.In order to ensure its good ssh connection using predefined hostname or just a more desired one, add alias to its real hostname in host ssh config.
sub add_alias_in_ssh_config {
    my ($ssh_config_file, $real_name, $domain_name, $alias_name) = @_;

    $ssh_config_file //= '/root/.ssh/config';
    $real_name       //= '';
    $domain_name     //= '';
    $alias_name      //= '';
    croak("Real name, domain name and alias name have to be given.") if (($real_name eq '') or ($domain_name eq '') or ($alias_name eq ''));
    if (script_run("test -f $ssh_config_file") ne 0) {
        script_run "mkdir -p " . dirname($ssh_config_file);
        assert_script_run("touch $ssh_config_file");
    }
    if (script_run("grep -i \"Host $alias_name\" $ssh_config_file") ne 0) {
        type_string("cat >> $ssh_config_file <<EOF
Host $alias_name
    HostName $real_name.$domain_name
    User root
EOF
");
    }
    assert_script_run("chmod 600 $ssh_config_file");
    record_info("Content of $ssh_config_file after adding alias $alias_name to real $real_name.", script_output("cat $ssh_config_file"));
    return;
}

#Parsed detaild subnet information, including subnet ip address, network mask, network mask length, gateway ip address, start ip address, end ip address and reverse ip address
#from ipv4 subnet address given.
sub parse_subnet_address_ipv4 {
    my $subnet_address = shift;

    $subnet_address //= '';
    croak("Subnet address argument must be given in the form of \"10.11.12.13/24\"") if (!($subnet_address =~ /\d+\.\d+\.\d+\.\d+\/\d+/));
    my $subnet              = NetAddr::IP->new($subnet_address);
    my $subnet_mask         = $subnet->mask();
    my $subnet_mask_len     = $subnet->masklen();
    my $subnet_ipaddr       = (split(/\//, $subnet->network()))[0];
    my $subnet_ipaddr_rev   = ip_reverse($subnet_ipaddr, $subnet_mask_len);
    my $subnet_ipaddr_gw    = (split(/\//, $subnet->first()))[0];
    my $subnet_ipaddr_start = (split(/\//, $subnet->nth(1)))[0];
    my $subnet_ipaddr_end   = (split(/\//, $subnet->last()))[0];
    return ($subnet_ipaddr, $subnet_mask, $subnet_mask_len, $subnet_ipaddr_gw, $subnet_ipaddr_start, $subnet_ipaddr_end, $subnet_ipaddr_rev);
}

#This subroutine receives array reference that contains file or folder name in absolute path form as $backup_target. Then back it up by appending 'backup' and timestamp to its
#original name. If $destination_folder is given, the file or folder will be backed up in it. Otherwise it will be backed up in the orginal parent folder. For example,
#my @something_to_be_backed_up = ('file1', 'folder2', 'folder3'); backup_file(\@something_to_be_backed_up) or backup_file(\@something_to_be_backed_up, '/tmp').
sub backup_file {
    my ($backup_target, $destination_folder) = @_;

    $backup_target      //= '';
    $destination_folder //= '';
    croak("The file or folder to be backed up must be given.") if ($backup_target eq '');
    my $backup_timestamp = localtime();
    $backup_timestamp   =~ s/ |:/_/g;
    $destination_folder =~ s/\/$//g;
    my @backup_target_array = @$backup_target;
    foreach (@backup_target_array) {
        my $backup_target_basename = basename($_);
        my $backup_target_dirname  = dirname($_);
        my $destination_target     = $backup_target_basename . '_backup_' . $backup_timestamp;
        $destination_target = ($destination_folder eq '' ? "$backup_target_dirname/$destination_target" : "$destination_folder/$destination_target");
        script_run("cp -f -r $_ $destination_target");
    }
    return;
}

1;
