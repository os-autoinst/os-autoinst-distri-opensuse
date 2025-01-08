# SUSE's openQA tests
#
# Copyright 2020-2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: virtualization test utilities.
# Maintainer: Julie CAO <jcao@suse.com>, qe-virt@suse.de

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
use LWP::Simple 'head';
use Utils::Architectures;
use IO::Socket::INET;
use Carp;

our @EXPORT = qw(
  is_vmware_virtualization
  is_hyperv_virtualization
  is_fv_guest
  is_pv_guest
  is_sev_es_guest
  guest_is_sle
  is_guest_ballooned
  is_xen_host
  is_kvm_host
  is_sles_mu_virt_test
  is_monolithic_libvirtd
  turn_on_libvirt_debugging_log
  restart_libvirtd
  check_libvirtd
  restart_modular_libvirt_daemons
  check_modular_libvirt_daemons
  reset_log_cursor
  check_failures_in_journal
  check_host_health
  check_guest_health
  print_cmd_output_to_file
  collect_virt_system_logs
  setup_rsyslog_host
  download_script
  download_script_and_execute
  upload_virt_logs
  enable_nm_debug
  upload_nm_debug_log
  ssh_setup
  setup_common_ssh_config
  add_alias_in_ssh_config
  install_default_packages
  parse_subnet_address_ipv4
  backup_file
  manage_system_service
  check_port_state
  is_registered_sles
  is_registered_system
  do_system_registration
  check_system_registration
  subscribe_extensions_and_modules
  check_activate_network_interface
  wait_for_host_reboot
  create_guest
  import_guest
  ssh_copy_id
  add_guest_to_hosts
  ensure_default_net_is_active
  ensure_guest_started
  remove_additional_disks
  remove_additional_nic
  start_guests
  is_guest_online
  ensure_online
  wait_guest_online
  restore_downloaded_guests
  save_original_guest_xmls
  restore_original_guests
  save_guests_xml_for_change
  restore_xml_changed_guests
  shutdown_guests
  wait_guests_shutdown
  remove_vm
  recreate_guests
  download_vm_import_disks
  get_guest_regcode
  execute_over_ssh
  reboot_virtual_machine
);

my %log_cursors;

# helper function: Trim string
sub trim {
    my $text = shift;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

#return 1 if test is expected to run on XEN hypervisor
sub is_xen_host {
    return get_var("XEN") || check_var("SYSTEM_ROLE", "xen") || check_var("HOST_HYPERVISOR", "xen") || check_var("REGRESSION", "xen-hypervisor");
}

# Usage: check_modular_libvirt_daemons([daemon1_name daemon2_name ...]). For example:
# to specify daemons which will be checked: check_modular_libvirt_daemons(qemu storage ...)
# to check all required modular daemons without any daemons passed
sub check_modular_libvirt_daemons {
    my @daemons = @_;

    if (!@daemons) {
        @daemons = qw(network nodedev nwfilter secret storage lock);
        # For details, please refer to poo#137096
        (is_xen_host) ? push @daemons, 'xen' : push @daemons, ('qemu', 'log');
    }

    foreach my $daemon (@daemons) {
        systemctl("status virt${daemon}d.service");
        if (($daemon eq 'lock') || ($daemon eq 'log')) {
            systemctl("status virt${daemon}d\{,-admin\}.socket");
        } else {
            systemctl("status virt${daemon}d\{,-ro,-admin\}.socket");
        }
    }
    save_screenshot;

    record_info("Modular libvirt daemons checked, all active for", join(' ', @daemons));
}

# Usage: restart_modular_libvirt_daemons([daemon1_name daemon2_name ...]). For example:
# to specify daemons which will be restarted: restart_modular_libvirt_daemons(virtqemud virtstoraged ...)
# to restart all modular daemons without any daemons passed
sub restart_modular_libvirt_daemons {
    my @daemons = @_;

    if (!@daemons) {
        @daemons = qw(network nodedev nwfilter secret storage lock);
        # For details, please refer to poo#137096
        (is_xen_host) ? push @daemons, 'xen' : push @daemons, ('qemu', 'log');
    }

    if (is_alp) {
        record_soft_failure("Restarting modular libvirt daemons has not been implemented in ALP. See poo#129086");
    } else {
        # Restart the sockets first
        foreach my $daemon (@daemons) {
            if (($daemon eq 'lock') || ($daemon eq 'log')) {
                systemctl("restart virt${daemon}d\{,-admin\}.socket");
            } else {
                systemctl("restart virt${daemon}d\{,-ro,-admin\}.socket");
            }
        }

        # Introduce idle time here (e.g., sleep 5) if necessary
        sleep 5;

        # Restart the services after a brief idle time
        foreach my $daemon (@daemons) {
            systemctl("restart virt${daemon}d.service");
        }
    }
    save_screenshot;

    record_info("Modular Libvirt daemons restarted, all active for", join(' ', @daemons));
}

#return 1 if it is a VMware test judging by REGRESSION variable
sub is_vmware_virtualization {
    return get_var("REGRESSION", '') =~ /vmware/;
}

#return 1 if it is a Hyper-V test judging by REGRESSION variable
sub is_hyperv_virtualization {
    return get_var("REGRESSION", '') =~ /hyperv/;
}

# Return 1 if it is SLES MU virt test, otherwise return 0
sub is_sles_mu_virt_test {
    return is_sle && get_var('REGRESSION') =~ /xen|kvm|qemu|hyperv|vmware/ && !get_var("VIRT_AUTOTEST");
}

#return 1 if it is a fv guest judging by name
#feel free to extend to support more cases
sub is_fv_guest {
    my $guest = shift;
    return $guest =~ /\bfv\b/ || $guest =~ /hvm/i;
}

#return 1 if it is a pv guest judging by name
#feel free to extend to support more cases
sub is_pv_guest {
    my $guest = shift;
    return $guest =~ /pv/i;
}

#Check if guest is SLE with optional filter for:
#Version: <=12-sp3 =12-sp1 >11-sp1 >=15 15+ (>=15 and 15+ are equivalent)
#usage: guest_is_sle($guest_name, '<=12-sp2')
sub guest_is_sle {
    my $guest_name = lc shift;
    my $query = shift;

    return 0 unless $guest_name =~ /sle/;
    return 1 unless $query;

    # Version check
    $guest_name =~ /sles-*(\d{2})(?:-*sp(\d))?/;
    my $version = $2 eq '' ? "$1-sp0" : "$1-sp$2";
    return check_version($query, $version, qr/\d{2}(?:-sp\d)?/);
}


#return 1 if max_mem > memory in vm configuration file in libvirt
sub is_guest_ballooned {
    my $guest = shift;

    my $mem = "";
    my $cur_mem = "";
    $mem = script_output "virsh dumpxml $guest | xmlstarlet sel -t -v //memory";
    $cur_mem = script_output "virsh dumpxml $guest | xmlstarlet sel -t -v //currentMemory";
    return $mem > $cur_mem;
}

#return 1 if test is expected to run on KVM hypervisor
sub is_kvm_host {
    return check_var("SYSTEM_ROLE", "kvm") || check_var("HOST_HYPERVISOR", "kvm") || check_var("REGRESSION", "qemu-hypervisor");
}

#retrun 1 if libvirt 9.0- is running which monolithic libvirtd is the default service
sub is_monolithic_libvirtd {
    record_info('WARNING', 'Libvirt package is not installed', result => 'fail') if (script_run('rpm -q libvirt-libs'));
    unless (is_alp) {
        return 1 if script_run('systemctl is-enabled libvirtd.service') == 0;
    }
    return 0;
}

# Restart libvirt daemon
sub restart_libvirtd {
    if (is_sle('<12')) {
        assert_script_run('rclibvirtd restart', 180);
    }
    elsif (is_alp) {
        my $_libvirtd_pid = script_output(q@ps -ef |grep [l]ibvirtd | gawk '{print $2;}'@);
        my $_libvirtd_cmd = script_output("ps -o command $_libvirtd_pid | tail -1");
        assert_script_run("kill -9 $_libvirtd_pid");
        assert_script_run("$_libvirtd_cmd");
    }
    elsif (is_monolithic_libvirtd) {
        systemctl("restart libvirtd", timeout => 180);
    } else {
        restart_modular_libvirt_daemons;
    }
    save_screenshot;

    record_info("Libvirtd Daemon has been restarted!");
}

# Check libvirt daemon
sub check_libvirtd {
    is_monolithic_libvirtd ? systemctl("status libvirtd") : check_modular_libvirt_daemons;

    record_info("Libvirtd Daemon has been checked!");
}

# For legacy libvird, set debug level logging for libvirtd services
# For modular libvirt, do the same settings to /etc/libvirt/virt{qemu,xen,driver}d.conf.
# virt{qemu,xen}d daemons provide the most important libvirt log(sufficient for most issues).
# virt{driver}.d daemons is only required by specific issues, eg virtual network failures may need virtnetworkd log.
# But our automation is better to set them to collect more logs as we could as possible.
# Developer asked to use different log file as log_output per daemon.
sub turn_on_libvirt_debugging_log {

    my @libvirt_daemons = is_monolithic_libvirtd ? "libvirtd" : qw(virtqemud virtstoraged virtnetworkd virtnodedevd virtsecretd virtnwfilterd virtlockd);
    # For details, please refer to poo#137096
    push @libvirt_daemons, 'virtlogd' if is_kvm_host;

    #turn on debug and log filter for libvirt services
    #disable log_level = 1 'debug' as it generage large output
    #the size of libvirtd with debug level and without any filter on sles15sp3 xen is over 100G,
    #which consumes all the disk space. Now get comfirmation from virt developers,
    #log filter is set to store component logs with different levels.
    foreach my $daemon (@libvirt_daemons) {
        my $conf_file = "/etc/libvirt/$daemon.conf";
        if (script_run("ls $conf_file") == 0) {
            script_run "sed -i 's/^[ ]*log_level *=/#&/' $conf_file";
            script_run "sed -i '/^[# ]*log_outputs *=/{h;s%^[# ]*log_outputs *=.*[0-9].*\$%log_outputs = \"1:file:/var/log/libvirt/$daemon.log\"%};\${x;/^\$/{s%%log_outputs = \"1:file:/var/log/libvirt/$daemon.log\"%;H};x}' $conf_file";
            script_run "sed -i '/^[# ]*log_filters *=/{h;s%^[# ]*log_filters *=.*[0-9].*\$%log_filters = \"1:qemu 1:libvirt 4:object 4:json 4:event 3:util 1:util.pci\"%};\${x;/^\$/{s%%log_filters = \"1:qemu 1:libvirt 4:object 4:json 4:event 3:util 1:util.pci\"%;H};x}' $conf_file";
        }
    }
    script_run "grep -e 'log_level.*=' -e 'log_outputs.*=' -e 'log_filters.*=' /etc/libvirt/*d.conf";
    save_screenshot;

    restart_libvirtd;
}

# Reset journalctl cursor used by check_failures_in_journal() to skip already
# reported errors. The next health check will rescan all messages since boot.
# reset_log_cursor($machine) will reset cursor only for given machine
# reset_log_cursor() will reset cursors for all machines
sub reset_log_cursor {
    my $machine = shift;

    if (defined($machine)) {
        delete $log_cursors{$machine};
    }
    else {
        %log_cursors = ();
    }
}

# Grep keywords from journals and report warnings, support x86_64 only
# Usage: check_failures_in_journal([machine], [no_cursor => 0]);
# [machine]: an IP or QUDN of ssh accesible machine. "localhost" ie. the SUT itself, by default.
# [no_cursor => 0]: value '0' means grep keywords from incremenal journal output only,
# ie. Start searching from the place you previously searched.
# value '1' means searching in the entire journal output(also including previous boots)
# keywords: only "Coredump" and "Call trace" have been included so far
# Work flow:
# - save journal output to a tmp file
# - get cursor from the saved file unless you'd like to search in the entire journals
# - grep each keywords in the saved file
# - if keywords are found, give warnings and upload the saved log
sub check_failures_in_journal {
    return unless is_x86_64 and (is_sle or is_opensuse);
    my ($machine, %args) = @_;
    $machine //= 'localhost';
    $args{no_cursor} //= 0;

    # Save journal log to a tmp file
    my $logfile = "/tmp/journalctl-$machine.log";
    my $failures = "";
    reset_log_cursor if $args{no_cursor} == 1;
    my $cursor = $log_cursors{$machine};
    my $cmd = "journalctl --show-cursor ";
    $cmd .= "--cursor='$cursor'" if defined($cursor);
    $cmd .= " > $logfile";
    $cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$machine " . "\"$cmd\"" if $machine ne 'localhost';
    if (script_run($cmd) != 0) {
        $failures = "Fail to get journal logs from $machine";
        record_info("Warning", "$failures when checking its health", result => 'softfail');
        return $failures;
    }

    # Get the cursor of the journal log file
    unless ($args{no_cursor}) {
        $cmd = "grep -oe \'-- cursor: *[^ ]*\' $logfile | cut -d ' ' -f3";
        $cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$machine " . "\"$cmd\"" if $machine ne 'localhost';
        $log_cursors{$machine} = script_output("$cmd", type_command => 1);
    }

    # Search warnings from the journal log file
    my @warnings = ('Started Process Core Dump', 'Call Trace');
    foreach (@warnings) {
        $cmd = "grep '$_' $logfile";
        $cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$machine " . "\"$cmd\"" if $machine ne 'localhost';
        $failures .= "\"$_\" in journals on $machine \n" if script_run("$cmd") == 0;
    }

    # In case of failures, print message and upload journal log
    if ($failures) {
        if (get_var('KNOWN_BUGS_FOUND_IN_JOURNAL')) {
            record_soft_failure("Found failures: \n" . $failures . "There are known kernel bugs " . get_var('KNOWN_BUGS_FOUND_IN_JOURNAL') . ". Please look into journal files to determine if it is a known bug. If it is a new issue, please take action as described in poo#151361.");
            record_info("Found failures in journal log", "Found failures: \n" . $failures . "There are known kernel bugs " . get_var('KNOWN_BUGS_FOUND_IN_JOURNAL') . ". Please look into journal files to determine if it is a known bug. If it is a new issue, please take action as described in poo#151361.", result => 'fail');
        }
        else {
            record_soft_failure("Found new failures: " . $failures . " please take actions as described in poo#151361.\n");
            record_info("Found failures in journal log", "Found new failures: " . $failures . " please take actions as described in poo#151361.\n", result => 'fail');
        }
        # ignore the attempt timing out with "timeout 20" which exits before
        # the script_run internal timeout
        script_run("timeout 20 rsync root\@$machine:$logfile $logfile") if $machine ne 'localhost';
        upload_logs($logfile);
    }
    return $failures;
}

# Do some basic check to host to see if it is working well
# Support x86_64 only
# Return 'pass' and 'fail' if there are or are not failures.
# Welcome everybody to extend this function
sub check_host_health {
    return unless is_x86_64 and (is_sle or is_opensuse);

    my $failures = caller 0 eq 'validate_system_health' ? check_failures_in_journal('localhost', no_cursor => 1) : check_failures_in_journal();
    unless ($failures) {
        record_info("Healthy host!");
        return 'pass';
    }
    record_info("Unhealthy host", $failures, result => 'fail');
    return 'fail';
}

# Do some basic check to specified guest tto see if it is working well
# Return 'pass' and 'fail' if there are or are not failures.
# Support x86_64 only
# Welcome everybody to extend this function
sub check_guest_health {
    my $vm = shift;
    return unless is_x86_64 and ($vm =~ /sle|alp/i);

    #check if guest is still alive
    my $vmstate = "nok";
    my $failures = "";
    if (script_run("virsh list --all | grep \"$vm \"") == 0) {
        $vmstate = "ok" if (script_run("virsh domstate $vm | grep running") == 0);
    }
    elsif (is_xen_host and script_run("xl list $vm") == 0) {
        script_retry("xl list $vm | grep \"\\-b\\-\\-\\-\\-\"", delay => 10, retry => 1, die => 0) for (0 .. 3);
        $vmstate = "ok" if script_run("xl list $vm | grep \"\\-b\\-\\-\\-\\-\"");
    }
    if ($vmstate eq "ok") {
        $failures = caller 0 eq 'validate_system_health' ? check_failures_in_journal($vm, no_cursor => 1) : check_failures_in_journal($vm);
        return 'fail' if $failures;
        record_info("Healthy guest!", "$vm looks good so far!");
    }
    else {
        record_info("Skip check_failures_in_journal for $vm", "$vm is not in desired state judged by either virsh or xl tool stack", result => 'softfail');
    }
    return 'pass';
}

#ammend the output of the command to an existing log file
#$machine=<guest_ip> to pass guest name or an remote IP if running command in a remote machine
#default $machine is the current SUT, ie. the host.
#make sure '$file' is present in current SUT(host), it wastes time to check the file in each call.
#only support simple bash command so far, eg. '|' is not supported in $cmd.
sub print_cmd_output_to_file {
    my ($cmd, $file, $machine) = @_;

    $cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$machine \"" . $cmd . "\"" unless (!$machine or $machine eq 'localhost');
    script_run "echo -e \"\n# $cmd\" >> $file";
    script_run "$cmd >> $file";
}

sub download_script_and_execute {
    my ($script_name, %args) = @_;
    $args{output_file} //= "$args{script_name}.log";
    $args{machine} //= 'localhost';
    $args{proceed_on_failure} //= 0;

    download_script($script_name, script_url => $args{script_url}, machine => $args{machine}, proceed_on_failure => $args{proceed_on_failure});
    my $cmd = "~/$script_name";
    $cmd = "ssh root\@$args{machine} " . "\"$cmd\"" if ($args{machine} ne 'localhost');
    script_run("$cmd >> $args{output_file} 2>&1");
}

sub download_script {
    my ($script_name, %args) = @_;
    my $script_url = $args{script_url} // data_url("virt_autotest/$script_name");
    my $machine = $args{machine} // 'localhost';
    $args{proceed_on_failure} //= 0;

    unless (head($script_url)) {
        if ($args{proceed_on_failure}) {
            record_info("URL is not accessible", "$script_url", result => 'fail');
            return;
        }
        else {
            die "$script_url is not accessible!";
        }
    }

    my $cmd = "curl -o ~/$script_name $script_url";
    $cmd = "ssh root\@$machine " . "\"$cmd\"" if ($machine ne 'localhost');
    unless (script_retry($cmd, timeout => 900, retry => 2, die => 0) == 0) {
        record_info("Failed to download", "Fail to download $script_url on $machine, however it is accessible from worker instance!", result => 'fail');
        unless ($machine eq 'localhost') {
            # Have to output debug info at here because no logs will be uploaded if there are connection problems
            if (script_run("ssh root\@$machine 'hostname'") == 0) {
                $script_url =~ /^https?:\/\/([\w\.]+)(:\d+)?\/.*/;
                script_run("ssh root\@$machine 'ping $1'");
                script_run("ssh root\@$machine 'traceroute $1'");
                script_run("ssh root\@$machine 'ping -c3 openqa.suse.de'");
                script_run("ssh root\@$machine 'nslookup " . get_var('WORKER_HOSTNAME', 'openqa.suse.de') . "'");
                script_run("ssh root\@$machine 'cat /etc/resolv.conf'");
            }
            else {
                record_info("machine is not ssh accessible", "$machine", result => 'fail');
            }
        }
        $args{proceed_on_failure} ? return : die "Failed to download $script_url on $machine!";
    }
    $cmd = "chmod +x ~/$script_name";
    $cmd = "ssh root\@$machine " . "\"$cmd\"" if ($machine ne 'localhost');
    script_run($cmd);
}

sub ssh_setup {
    my $default_ssh_key = shift;

    $default_ssh_key //= (!(get_var('VIRT_AUTOTEST'))) ? "/root/.ssh/id_rsa" : "/var/testvirt.net/.ssh/id_rsa";
    my $dt = DateTime->now;
    my $comment = "openqa-" . $dt->mdy . "-" . $dt->hms('-') . get_var('NAME');
    if (script_run("[[ -s $default_ssh_key ]]") != 0) {
        my $default_ssh_key_dir = dirname($default_ssh_key);
        script_run("mkdir -p $default_ssh_key_dir");
        assert_script_run "ssh-keygen -t rsa -P '' -C '$comment' -f $default_ssh_key";
        record_info("Created ssh rsa key in $default_ssh_key successfully.");
    } else {
        record_info("Skip ssh rsa key recreation in $default_ssh_key, which exists.");
    }
    assert_script_run("ls `dirname $default_ssh_key`");
    save_screenshot;
}

sub ssh_copy_id {
    my ($guest, %args) = @_;

    my $username = $args{username} // 'root';
    my $authorized_keys = $args{authorized_keys} // '.ssh/authorized_keys';
    my $scp = $args{scp} // 0;
    my $mode = is_sle('=11-sp4') ? '' : '-f';
    my $default_ssh_key = $args{default_ssh_key};
    $default_ssh_key //= (!(get_var('VIRT_AUTOTEST'))) ? "/root/.ssh/id_rsa.pub" : "/var/testvirt.net/.ssh/id_rsa.pub";
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
    my $v_type = $guest->{name} =~ /HVM/ ? "-v" : "";

    my $name = $guest->{name};
    my $location = $guest->{location};
    my $autoyast = $guest->{autoyast};
    my $macaddress = $guest->{macaddress};
    my $on_reboot = $guest->{on_reboot} // "restart";    # configurable on_reboot policy
    my $extra_params = $guest->{extra_params} // "";    # extra-parameters
    my $memory = $guest->{memory} // "2048";
    # poo#11786, set maxmemory bigger
    my $maxmemory = $guest->{maxmemory} // $memory + 1536;    # use by default just a bit more, so that we don't waste memory but still use the functionality
    my $vcpus = $guest->{vcpus} // "2";
    my $maxvcpus = $guest->{maxvcpus} // $vcpus + 1;    # same as for memory, test functionality but don't waste resources
    my $extra_args = get_var("VIRTINSTALL_EXTRA_ARGS", "") . " " . get_var("VIRTINSTALL_EXTRA_ARGS_" . uc($name), "");
    $extra_args = trim($extra_args);

    if ($method eq 'virt-install') {
        send_key 'ret';    # Make some visual separator

        # Run unattended installation for selected guest
        my ($autoyastURL, $diskformat, $virtinstall);
        $autoyastURL = $autoyast;
        $diskformat = get_var("VIRT_QEMU_DISK_FORMAT") // "qcow2";
        $extra_args = "autoyast=$autoyastURL $extra_args";
        $extra_args = trim($extra_args);
        $virtinstall = "virt-install $v_type $guest->{osinfo} --name $name --vcpus=$vcpus,maxvcpus=$maxvcpus --memory=$memory,maxmemory=$maxmemory --vnc";
        $virtinstall .= " --disk path=/var/lib/libvirt/images/$name.$diskformat,size=20,format=$diskformat --noautoconsole";
        $virtinstall .= " --network bridge=br0 --autostart --location=$location --wait -1";
        $virtinstall .= " --events on_reboot=$on_reboot" unless ($on_reboot eq '');
        $virtinstall .= " --extra-args '$extra_args'" unless ($extra_args eq '');
        record_info("$name", "Creating $name guests:\n$virtinstall");
        script_run "$virtinstall >> ~/virt-install_$name.txt 2>&1 & true";    # true required because & terminator is not allowed

        # wait for initrd to ensure the installation is starting
        script_retry("grep -B99 -A99 'initrd' ~/virt-install_$name.txt", delay => 15, retry => 12, die => 0);
    } else {
        die "unsupported create_guest method '$method'";
    }
}

sub import_guest {
    my ($guest, $method) = @_;

    my $name = $guest->{name};
    my $disk = $guest->{disk};
    my $macaddress = $guest->{macaddress};
    my $extra_params = $guest->{extra_params} // "";
    my $memory = $guest->{memory} // "2048";
    my $maxmemory = $guest->{maxmemory} // $memory + 256;    # use by default just a bit more, so that we don't waste memory but still use the functionality
    my $vcpus = $guest->{vcpus} // "2";
    my $maxvcpus = $guest->{maxvcpus} // $vcpus + 1;    # same as for memory, test functionality but don't waste resources
    my $network_model = $guest->{network_model} // "";

    if ($method eq 'virt-install' || $method eq '') {
        record_info "$name", "Going to import $name guest";
        send_key 'ret';    # Make some visual separator

        my $network = "network=default,mac=$macaddress,";
        $network .= ",model=$network_model" unless ($network_model eq "");

        # Run unattended installation for selected guest
        my $virtinstall = "virt-install $extra_params --name $name --vcpus=$vcpus,maxvcpus=$maxvcpus --memory=$memory,maxmemory=$maxmemory --cpu host";
        $virtinstall .= " --graphics vnc --disk $disk --network $network --noautoconsole  --autostart --import";
        assert_script_run $virtinstall;
    } else {
        die "unsupported import_guest method '$method'";
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

    my $hypervisor = defined $args{HYPERVISOR} ? $args{HYPERVISOR} : (get_var('VIRT_AUTOTEST') ? "192.168.123.1" : "192.168.122.1");
    my $dns_host = $args{DNS_TEST_HOST} // "www.suse.com";
    my $skip_ssh = $args{skip_ssh} // 0;
    my $skip_network = $args{skip_network} // 0;
    my $skip_ping = $args{skip_ping} // 0;
    my $ping_delay = $args{ping_delay} // 15;
    my $ping_retry = $args{ping_retry} // 60;
    my $use_virsh = $args{use_virsh} // 1;

    # Ensure guest is running
    # Only xen/kvm support to reboot guest at the moment
    if ($use_virsh && (is_xen_host || is_kvm_host)) {
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
            die "$guest does not start ssh" if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 12, timeout => 360) != 0);
            die "$guest not ssh-reachable" if (script_run("ssh $guest uname") != 0);
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
                # Note: TBD for modular libvirt. See poo#129086 for detail.
                restart_libvirtd;
                die "name resolution failed for $guest" if (script_retry("ssh $guest ping -c 3 -w 120 $dns_host", delay => 1, retry => 10, timeout => 180) != 0);
            }
        }
    }
}

sub ensure_default_net_is_active {
    if (script_run("virsh net-list --all | grep default | grep ' active'", 90) != 0) {
        # Note: TBD for modular libvirt. See poo#129086 for detail.
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
    my $guest = $_[0];
    my $pattern = $_[1] // "x?vd[b-z]";

    return if ($guest == 0);
    my $cmd = 'for i in `virsh domblklist ' . "'$guest'" . ' | grep ' . "'$pattern'" . ' | awk "{print $1}"`; do virsh detach-disk ' . "'$guest' " . '"$i"; done';
    return script_run($cmd);
}

# Remove additional network interfaces from $guest. The NIC needs to be identified by it's mac address of mac address prefix (e.g. '00:16:3f:32')
# returns the status code of the remove command
sub remove_additional_nic {
    my $guest = $_[0] // '';
    my $mac_prefix = $_[1] // '';

    return if ($guest == 0);
    die "mac_prefix not defined" if ($mac_prefix == 0);

    my $cmd = 'for i in `virsh domiflist ' . "'$guest'" . ' | grep ' . "'$mac_prefix'" . ' | awk "{print $5}"`; do virsh detach-interface ' . "'$guest'" . ' bridge --mac "$i"; done';
    return script_run($cmd);
}

sub collect_virt_system_logs {
    if (script_run("test -f /var/log/libvirt/*d.log") == 0) {
        script_run('tar czvf /tmp/libvirt_daemons.tar.gz /var/log/libvirt/*d.log');
        upload_asset("/tmp/libvirt_daemons.tar.gz");
    }
    else {
        record_info "File /var/log/libvirt/*d.log does not exist.";
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
# If [$state_check] is not zero, guest state checking will be performed to ensure it is in running state and retry
sub wait_guest_online {
    my $guest = shift;
    my $retries = shift // 300;
    my $state_check = shift // 0;
    # Wait until guest is reachable via ssh
    if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 1, retry => $retries, die => 0) != 0) {
        # Ensure guest is running
        if (($state_check != 0) and (script_run("virsh list --name --state-running | grep $guest") != 0)) {
            script_run("virsh destroy $guest");
            assert_script_run("virsh start $guest");
            script_retry("nmap $guest -PN -p ssh | grep open", delay => 1, retry => $retries);
        }
        else {
            die "Guest $guest ssh service is not up and running";
        }
    }
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
    # Firstly wait for guest shutdown for a while, turn it off forcibly using "virsh destroy" if timed-out.
    # Then wait for guest shutdown again with default "die => 1".
    if (script_retry("! virsh list | grep -v Domain-0 | grep running", timeout => 60, delay => 1, retry => $retries, die => 0) != 0) {
        script_run("virsh destroy $_") foreach (keys %virt_autotest::common::guests);
    }
    script_retry("! virsh list | grep -v Domain-0 | grep running", timeout => 60, delay => 1, retry => $retries);
}

# Start all guests and wait until they are online
sub start_guests {
    script_run("virsh start '$_'") foreach (keys %virt_autotest::common::guests);
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
    $real_name //= '';
    $domain_name //= '';
    $alias_name //= '';
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
    my $subnet = NetAddr::IP->new($subnet_address);
    my $subnet_mask = $subnet->mask();
    my $subnet_mask_len = $subnet->masklen();
    my $subnet_ipaddr = (split(/\//, $subnet->network()))[0];
    my $subnet_ipaddr_rev = ip_reverse($subnet_ipaddr, $subnet_mask_len);
    my $subnet_ipaddr_gw = (split(/\//, $subnet->first()))[0];
    my $subnet_ipaddr_start = (split(/\//, $subnet->nth(1)))[0];
    my $subnet_ipaddr_end = (split(/\//, $subnet->last()))[0];
    return ($subnet_ipaddr, $subnet_mask, $subnet_mask_len, $subnet_ipaddr_gw, $subnet_ipaddr_start, $subnet_ipaddr_end, $subnet_ipaddr_rev);
}

#This subroutine receives array reference that contains file or folder name in absolute path form as $backup_target. Then back it up by appending 'backup' and timestamp to its
#original name. If $destination_folder is given, the file or folder will be backed up in it. Otherwise it will be backed up in the orginal parent folder. For example,
#my @something_to_be_backed_up = ('file1', 'folder2', 'folder3'); backup_file(\@something_to_be_backed_up) or backup_file(\@something_to_be_backed_up, '/tmp').
sub backup_file {
    my ($backup_target, $destination_folder) = @_;

    $backup_target //= '';
    $destination_folder //= '';
    croak("The file or folder to be backed up must be given.") if ($backup_target eq '');
    my $backup_timestamp = localtime();
    $backup_timestamp =~ s/ |:/_/g;
    $destination_folder =~ s/\/$//g;
    my @backup_target_array = @$backup_target;
    foreach (@backup_target_array) {
        my $backup_target_basename = basename($_);
        my $backup_target_dirname = dirname($_);
        my $destination_target = $backup_target_basename . '_backup_' . $backup_timestamp;
        $destination_target = ($destination_folder eq '' ? "$backup_target_dirname/$destination_target" : "$destination_folder/$destination_target");
        script_run("cp -f -r $_ $destination_target");
    }
    return;
}

#This subroutine use systemctl or service command to manage system service operations, for example, start, stop, disable and etc.
#The system service name to be managed is passed in as the first argument $service_name. The operations to be performed is passed in as the second argument $manage_operation.
#For example, my @myoperations = ('stop', 'disable'); manage_system_service('named', \@myoperations);
sub manage_system_service {
    my ($service_name, $manage_operation) = @_;

    $service_name //= '';
    $manage_operation //= '';
    croak("The operation and service name must be given.") if (($service_name eq '') or ($manage_operation eq ''));
    my @manage_operations = @$manage_operation;
    foreach (@manage_operations) {
        script_run("service $service_name $_") if (script_run("systemctl $_ $service_name") ne 0);
    }
    return;
}

#Standardized system logging is implemented by the rsyslog service. System programs can send syslog messages to the local rsyslogd service which will then redirect those messages
#to remote log servers, namely the centralized log host. The centralized log host can be customized by modifying /etc/rsyslog.conf with desired communication protocol, port, log
#file and log folder. Once syslog reception has been activated and the desired rules for log separation by host has been created, restart the rsyslog service for the configuration
#changes to take effect. An examaple of how to call this subroutine is setup_centralized_log_host('/tmp/temp_log_folder', 'udp', '555').
sub setup_rsyslog_host {
    my ($log_host_folder, $log_host_protocol, $log_host_port) = @_;

    $log_host_folder //= '/var/log/loghost';
    $log_host_protocol //= 'udp';
    $log_host_port //= '514';

    # Add --gpg-auto-import-keys to zypper_call("in rsyslog")
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("--gpg-auto-import-keys in rsyslog");
    assert_script_run("mkdir -p $log_host_folder");
    my $log_host_protocol_directive = ($log_host_protocol eq 'udp' ? '\$UDPServerRun' : '\$InputTCPServerRun');
    if (script_output("cat /etc/rsyslog.conf | grep \"#Setup centralized rsyslog host\"", proceed_on_failure => 1) eq '') {
        save_screenshot;
        type_string("cat >> /etc/rsyslog.conf <<EOF
#Setup centralized rsyslog host
\\\$ModLoad im${log_host_protocol}.so
$log_host_protocol_directive ${log_host_port}
\\\$template DynamicFile,\"${log_host_folder}/%HOSTNAME%/%syslogfacility-text%.log\"
EOF
");
    }
    save_screenshot;
    record_info("Content of /etc/rsyslog.conf after configured as centralized rsyslog host", script_output("cat /etc/rsyslog.conf"));
    my @myoperations = ('start', 'restart', 'status --no-pager');
    manage_system_service('syslog', \@myoperations);
    save_screenshot;
    return;
}

=head2 check_port_state

  check_port_state($dst_machine, $dst_port, $retries, $delay)

Check whether given port is open on remote machine. This subroutine accepts four
arguments, dst_machine, dst_port, retries and delay, which are fqdn or ip addr 
of remote machine, port on remote machine, the number of retries and delay value
respectively. Default retries is 1 and default delay is 30 seconds. dst_machine 
and dst_port have no default value and test will die if the subroutine is called
without being passed value to dst_machine or dst_port.The subroutine will return 
1 if the given port is open on the specified remote machine, otherwise it will 
return 0.

=cut

sub check_port_state {
    my ($dst_machine, $dst_port, $retries, $delay) = @_;
    $dst_machine //= "";
    $dst_port //= "";
    $retries //= 1;
    $delay //= 30;
    croak('IP address or FQDN should be provided as argument dst_machine or port number should be given as argument dst_port.') if (($dst_machine eq "") or ($dst_port eq ""));

    my $port_state = 0;
    foreach (1 .. $retries) {
        save_screenshot;
        if (IO::Socket::INET->new(PeerAddr => "$dst_machine", PeerPort => "$dst_port")) {
            save_screenshot;
            record_info("Port $dst_port is open", "The port $dst_port is open on machine $dst_machine");
            $port_state = 1;
            last;
        }
        save_screenshot;
        sleep $delay if ($_ != $retries);
    }
    record_info("Port $dst_port is not open", "The port $dst_port is not open on machine $dst_machine") if ($port_state == 0);
    return $port_state;
}

#Detect whether SUT host is installed with scc registration
sub is_registered_sles {
    if ((!get_var('SCC_REGISTER') or check_var('SCC_REGISTER', 'none')) and (!get_var('REGISTER') or check_var('REGISTER', 'none'))) {
        return 0;
    }
    else {
        return 1;
    }
}

=head2 is_registered_system

  is_registered_system(dst_machine => $machine)

Detect whether system under test is registered. If [dst_machine] is not given,
the default value 'localhost' will be used. Using "transactional-update register"
if 1 is given to [usetrup], otherwise keeping using SUSEConnect.

=cut

sub is_registered_system {
    my (%args) = @_;
    $args{dst_machine} //= 'localhost';
    $args{usetrup} //= 0;

    my $cmd1 = $args{usetrup} == 1 ? "transactional-update register" : "SUSEConnect";
    $cmd1 .= " --status-text";
    my $cmd2 = $cmd1 . " | grep -i \"Not Registered\"";
    $cmd2 = "ssh root\@$args{dst_machine} " . "\"$cmd2\"" if ($args{dst_machine} ne 'localhost');
    save_screenshot;
    if (script_run($cmd2) == 0) {
        record_info("System Not Registered");
        return 0;
    }
    record_info("System Registered");
    return 1;
}

=head2 do_system_registration

  do_system_registration(dst_machine => $machine, activate => 1/0)

Register/de-register system according to argument [activate]. If argument [dst_machine]
is not given, the default value 'localhost' will be used. Using "transactional-update 
register" if 1 is given to [usetrup], otherwise keeping using SUSEConnect.

=cut

sub do_system_registration {
    my (%args) = @_;
    $args{dst_machine} //= 'localhost';
    $args{activate} //= 1;
    $args{usetrup} //= 0;

    my $cmd = $args{usetrup} == 1 ? "transactional-update register" : "SUSEConnect";
    $cmd .= $args{activate} == 1 ? " -r " . get_required_var('SCC_REGCODE') . " --url " . get_required_var('SCC_URL') : " -d";
    $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
    script_run($cmd);
    save_screenshot;
    is_registered_system;
}

=head2 check_system_registration

  check_system_registration(dst_machine => $machine)

Check current system registration status. If argument [dst_machine] is not given,
the default value 'localhost' will be used. Using "transactional-update register"
if 1 is given to [usetrup], otherwise keeping using SUSEConnect.

=cut

sub check_system_registration {
    my (%args) = @_;
    $args{dst_machine} //= 'localhost';
    $args{usetrup} //= 0;

    my $cmd = $args{usetrup} == 1 ? "transactional-update register" : "SUSEConnect";
    $cmd .= " --status-text";
    $cmd = "ssh root\@$args{dst_machine} " . "\"$cmd\"" if ($args{dst_machine} ne 'localhost');
    record_info("System Registration Status", script_output($cmd, proceed_on_failure => 1));
}

=head2 subscribe_extensions_and_modules

  subscribe_extensions_and_modules(dst_machine => $machine, activate => 1/0, reg_exts => $exts)

Any available extensions and modules listed out by SUSEConnect --list-extensions
that do not require additional regcode can be subscribe directly by using command
SUSEConnect -p [extension or module]. Subscription is to be performed on localhost
by default if argument dst_machine is not given any other address, and successful
access to dst_machine via ssh should be guaranteed in advance if dst_machine points 
to a remote machine. Deactivation is also supported if argument activate is given 
0 explicitly. Multiple extensions or modules can be passed in as a single string 
separated by space to argument reg_exts to be subscribed one by one. Using
"transactional-update register" for newer OS like SLE Micro 6.0, which is the more
preferred way to do registration.

=cut

sub subscribe_extensions_and_modules {
    my (%args) = @_;
    $args{dst_machine} //= 'localhost';
    $args{activate} //= 1;
    $args{reg_exts} //= '';

    my $registered_system = is_registered_system;
    if (!$registered_system and !$args{activate}) {
        return;
    }
    elsif ($registered_system and !$args{activate}) {
        my @to_be_unsubscribed = split(/ /, $args{reg_exts});
        if (!@to_be_unsubscribed) {
            record_info('No specified extension or module to be unsubscribed. Deregistering entire system.');
            do_system_registration(activate => 0);
        }
        else {
            foreach (@to_be_unsubscribed) {
                my $cmd = is_sle_micro('>=6.0') ? "transactional-update register" : "SUSEConnect";
                $cmd .= " -d -p " . "\$($cmd -l | grep -o \"\\b$_\\/.*\\/.*\\b\")";
                $cmd = "ssh root\@$args{dst_machine} " . "\'$cmd\'" if ($args{dst_machine} ne 'localhost');
                script_run($cmd, timeout => 120);
                save_screenshot;
            }
        }
    }
    else {
        do_system_registration if (!$registered_system);
        my @to_be_subscribed = split(/ /, $args{reg_exts});
        if (@to_be_subscribed) {
            foreach (@to_be_subscribed) {
                my $cmd = is_sle_micro('>=6.0') ? "transactional-update register" : "SUSEConnect";
                $cmd .= " -p " . "\$($cmd -l | grep -o \"\\b$_\\/.*\\/.*\\b\")";
                $cmd = "ssh root\@$args{dst_machine} " . "\'$cmd\'" if ($args{dst_machine} ne 'localhost');
                script_run($cmd, timeout => 120);
                save_screenshot;
            }
        }
        else {
            record_info('No specified extension or module to be subscribed.');
        }
    }
    check_system_registration(dst_machine => $args{dst_machine});
}

=head2 is_sev_es_guest

  is_sev_es_guest($guest_name)

Check whether a guest is sev-es, sev only or not sev/sev-es guest by searching
whether sev-es or sev word is available in its name. The only argument for the
subroutine is guest_name. It returns sev-es or sev if either is found in guest
name, otherwise it returns 0.

=cut

sub is_sev_es_guest {
    my ($guest_name) = @_;
    $guest_name //= '';
    croak('Arugment guest_name should not be empty') if ($guest_name eq '');

    if ($guest_name =~ /(sev-es|sev)/img) {
        record_info("$guest_name is $1 guest", "Guest $guest_name is a $1 enabled guest judging by its name.");
        return $1;
    } else {
        record_info("$guest_name is not sev(es) guest", "Guest $guest_name is not a sev or sev-es enabled guest judging by its name.");
        return 'notsev';
    }
}

# remove a vm listed via 'virsh list'
sub remove_vm {
    my $vm = shift;
    my $is_persistent_vm = script_output "virsh dominfo $vm | sed -n '/Persistent:/p' | awk '{print \$2}'";
    my $vm_state = script_output "virsh domstate $vm";
    if ($vm_state ne "shut off") {
        assert_script_run("virsh destroy $vm", 30);
    }
    if ($is_persistent_vm eq "yes") {
        assert_script_run("virsh undefine $vm || virsh undefine $vm --keep-nvram", 30);
    }
}

#Start the guest from the downloaded vm xml and vm disk file
sub restore_downloaded_guests {
    my ($guest, $vm_xml_dir) = @_;
    record_info("Guest restored", "$guest");
    assert_script_run("virsh define $vm_xml_dir/$guest.xml", 30);
}

sub save_original_guest_xmls {
    my ($save_dir, @guests) = @_;
    $save_dir //= "/tmp/download_vm_xml";
    @guests = keys %virt_autotest::common::guests unless @guests;
    assert_script_run "mkdir -p $save_dir" unless script_run("ls $save_dir") == 0;
    foreach my $guest (@guests) {
        unless (script_run("ls $save_dir/$guest.xml") == 0) {
            assert_script_run "virsh dumpxml --inactive $guest > $save_dir/$guest.xml";
        }
    }
}

sub restore_original_guests {
    my ($save_dir, @guests) = @_;
    $save_dir //= "/tmp/download_vm_xml";
    @guests = keys %virt_autotest::common::guests if @guests == 0;
    foreach my $guest (@guests) {
        remove_vm($guest);
        if (script_run("ls $save_dir/$guest.xml") == 0) {
            restore_downloaded_guests($guest, $save_dir);
            record_info "Guest $guest is restored.";
            assert_script_run "virsh start $guest";
            wait_guest_online($guest);
        }
        else {
            record_info("Fail to restore guest!", "$guest", result => 'softfail');
        }
    }
    script_run("virsh list --all");
}


#save the guest configuration files into a folder
#create a dir for storing changed guest configuration files only
sub save_guests_xml_for_change {
    my ($save_dir, @guests) = @_;
    $save_dir //= "/tmp/download_vm_xml";
    save_original_guest_xmls($save_dir, @guests);
    my $changed_xml_dir = "$save_dir/changed_xml";
    script_run("[ -d $changed_xml_dir ] && rm -rf $changed_xml_dir/*");
    script_run("mkdir -p $changed_xml_dir");
}

#restore guest which xml configuration files were changed in a test
sub restore_xml_changed_guests {
    my $changed_xml_dir = shift;
    $changed_xml_dir //= "/tmp/download_vm_xml/changed_xml";
    my @changed_guests = split('\n', script_output("ls -1 $changed_xml_dir | cut -d '.' -f1"));
    foreach my $guest (@changed_guests) {
        remove_vm($guest);
        restore_downloaded_guests($guest, $changed_xml_dir);
        assert_script_run "virsh start $guest";
        wait_guest_online($guest);
    }
}

sub upload_virt_logs {
    my ($log_dir, $compressed_log_name) = @_;

    my $full_compressed_log_name = "/tmp/$compressed_log_name.tar.gz";
    script_run("tar -czf $full_compressed_log_name $log_dir", 60);
    script_run("for log in $log_dir; do if [ -d \$log ]; then cd \$log && rm -r *; else rm -r \$log; fi; done");
    save_screenshot;
    upload_logs "$full_compressed_log_name";
    save_screenshot;
}

#recreate all defined guests
sub recreate_guests {
    my $based_guest_dir = shift;
    return if get_var('INCIDENT_ID');    # QAM does not recreate guests every time
    my $get_vm_hostnames = "virsh list  --all | grep -e sles -e opensuse -e alp -i | awk \'{print \$2}\'";
    my $vm_hostnames = script_output($get_vm_hostnames, 30, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array)
    {
        script_run("virsh destroy $_");
        script_run("virsh undefine $_ || virsh undefine $_ --keep-nvram");
        script_run("virsh define /$based_guest_dir/$_.xml");
        script_run("virsh start $_");
    }
}

# For vms with imported disks, this function can be used to download the disk from ${OPENQA_URL}/assets/ to SUT.
sub download_vm_import_disks {
    my $download_dir = shift;

    $download_dir //= "/var/lib/libvirt/images";

    my @disks_to_download = split(/,/, get_var("VM_IMPORT_DISK_LOCATION", ''));
    if (not @disks_to_download) {
        record_info "No import disk configured, skip download.";
        return;
    } else {
        record_info "Going to download imported disk...";
    }

    my @checksums_for_disks = split(/,/, get_var("VM_IMPORT_DISK_CHECKSUM", ''));
    assert_script_run("mkdir -p $download_dir");
    my $BASE_URL = get_required_var("OPENQA_URL") . "/assets/";
    while (my ($index, $disk) = each @disks_to_download) {
        my $download_url = $BASE_URL . $disk;
        die "URL is not accessible: $download_url." unless head($download_url);

        $disk =~ /.*\/([^\/]+)\.([^\/\.]+)$/m;
        my $output_name = "$1-back.$2";    # example: name.qcow2 => name-back.qcow2
        my $cmd = "curl -L $download_url -o $download_dir/$output_name";
        script_retry($cmd, retry => 2, delay => 5, timeout => 600, die => 1);
        save_screenshot;

        # Check if the downloaded image is good.
        my $real_disk_checksum = script_output("sha256sum $download_dir/$output_name" . ' |cut -d\' \' -f 1');
        save_screenshot;
        if ($real_disk_checksum eq $checksums_for_disks[$index]) {
            record_info("Disk downloaded successfully for $download_url.");
        } else {
            die "Faulty disk dowmload for $download_url. Please check network or imported disk configuration.";
        }
    }
    assert_script_run("ls -latr $download_dir");
    record_info("All imported disk download is done.");
}

sub enable_nm_debug {
    # Enable Network Manager Debug Log Level
    assert_script_run("nmcli general logging level DEBUG domains ALL", 60);
    record_info("Enable Network Manager in Debug Level successfully for automation test.");
}

sub check_activate_network_interface {
    # Check with activate network interface as required
    my ($network_interface, $target_name) = @_;
    $network_interface //= "br0";
    $target_name //= get_required_var('OPENQA_URL');
    assert_script_run("ping -I $network_interface -c 3 $target_name", 60);
    assert_script_run("nmcli device show $network_interface", 60);
    save_screenshot;
    record_info("Activate Network Interface check successfully for automation test.");
}

sub upload_nm_debug_log {
    script_run("journalctl -u NetworkManager.service > /tmp/NetworkManager.logs");
    upload_virt_logs("/tmp/NetworkManager.logs", "NetworkManager-debug-logs");
    script_run("rm -rf /tmp/NetworkManager.logs");
}

=head2 get_guest_regcode


  get_guest_regcode(separator => 'string separator')

Pass guest registration code in dynamically via GUEST_SCC_REGCODE and
GUEST_SCC_REGCODE_LTSS. If they are not provided, SCC_REGCODE and
SCC_REGCODE_LTSS_15 will be used. If there are multiple guest patterns
, their corresponding registration codes should also be specified in
the same order and separated by separators like pipe, comma or others.
Empty value is allowed. For example, regcode_guest1|regcode_guest2||
regcode_guest4, because regcode_guest3 is emety, empty value is passed
in to preserve order. For multiple guest patterns, an empty registration
code for specific guest pattern will not be filled out by any default
value and at the same time this  means registration code is not needed
for it at all. This subroutine has one argument separator and returns
generated registration codes joined together by specified separator.

=cut

sub get_guest_regcode {
    my (%args) = @_;
    $args{separator} //= ",";

    my $guest = (get_var("GUEST_PATTERN") ? get_var("GUEST_PATTERN") : (get_var("GUEST_LIST") ? get_var("GUEST_LIST") : get_var("GUEST", "")));
    croak("Guest to be involved must be given in GUEST_PATTERN, GUEST_LIST or GUEST exclusively") if (!$guest);

    my $regcode = get_var("GUEST_SCC_REGCODE", "");
    my $regcode_ltss = get_var("GUEST_SCC_REGCODE_LTSS", "");
    my $count = ($args{separator} eq '|' ? scalar(split("\\$args{separator}", $guest)) : scalar(split("$args{separator}", $guest)));
    $regcode = join("$args{separator}", (get_var("SCC_REGCODE", "")) x $count) if (!$regcode);
    if (!$regcode_ltss) {
        my @guest_parts = $args{separator} eq '|' ? split("\\$args{separator}", $guest) : split("$args{separator}", $guest);
        my @regcode_ltss_parts;
        for my $part (@guest_parts) {
            push @regcode_ltss_parts, ($part =~ /12/ ? get_var("SCC_REGCODE_LTSS_12", "") : $part =~ /15/ ? get_var("SCC_REGCODE_LTSS_15", "") : "");
        }
        $regcode_ltss = join($args{separator}, @regcode_ltss_parts);
    }
    return $regcode, $regcode_ltss;
}

sub wait_for_host_reboot {
    select_console 'sol', await_console => 0;
    # Wait for reboot and show screenshots
    foreach (1 .. 10) {
        save_screenshot;
        sleep 20;
    }
    assert_screen([qw(sol-console-wait-typing-ret linux-login text-login)], 120);
    if (match_has_tag('sol-console-wait-typing-ret')) {
        send_key 'ret';
        assert_screen([qw(inux-login text-login)], 120);
    }
    record_info("Host rebooted");
    reset_consoles;
    select_console('root-ssh');
}

=head2 execute_over_ssh

  execute_over_ssh(username => $user, address => $address,
      command => $command, timeout => $timeout, assert => $assert)

Run command over passwordless ssh session. Arguments include username default 
value of which is 'root', address which can take the form of FQDN or IP and is
mandatory, command to be executed, timeout value to wait before next step and
assert which determines assertive call or not.

=cut

sub execute_over_ssh {
    my %args = @_;
    $args{username} //= 'root';
    $args{address} //= '';
    $args{command} //= '';
    $args{timeout} //= 90;
    $args{assert} //= 1;
    croak('Argument address and command must be given to run over ssh') if (!$args{address} or !$args{command});

    wait_guest_online($args{address});
    my $command = "ssh $args{username}\@$args{address} \"$args{command}\"";
    script_retry($command, timeout => $args{timeout}, delay => 15, retry => 3, die => $args{assert});
}

=head2 reboot_virtual_machine

  reboot_virtual_machine(username => $user, address => $address, domain => $domain)

Reboot virtual machine by issuing 'reboot' over ssh and then 'virsh command' if
'reboot' does not succeed and virtual machine domain name is given as arguement
domain which is default to argument address if it is also a domain name. Address
can also takes the form of FQDN and IP as long as it is reachable over ssh. And
another argument username has the default value of 'root' if no passed in value. 

=cut

sub reboot_virtual_machine {
    my %args = @_;
    $args{username} //= 'root';
    $args{address} //= '';
    $args{domain} //= $args{address};
    croak('Argument address must be given to reboot virtual machine') if (!$args{address});

    my $test_ssh_open = "nmap $args{address} -PN -p ssh | grep -i open";
    my $test_ssh_not_open = "nmap $args{address} -PN -p ssh | grep -i -v open";
    if (script_retry($test_ssh_open, delay => 1, retry => 30, die => 0) == 0) {
        script_run("ssh $args{username}\@$args{address} \"reboot\"");
        script_run("virsh destroy $args{domain}") if (script_retry($test_ssh_not_open, delay => 1, retry => 60, die => 0) != 0);
    }
    croak("Virtual machine $args{domain} $args{address} failed to stop") if (script_retry($test_ssh_not_open, delay => 1, retry => 30, die => 0) != 0);
    if (script_retry($test_ssh_open, delay => 1, retry => 30, die => 0) != 0) {
        script_run("virsh destroy $args{domain}");
        script_run("virsh start $args{domain}");
        script_retry($test_ssh_open, delay => 1, retry => 30, die => 1);
    }
}

1;
