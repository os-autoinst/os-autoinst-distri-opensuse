# PARALLEL GUEST MIGRATION BASE MODULE
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Base module for parallel guest migration test run.
#
# Global structures:
# %guest_matrix to record information about guest under test.
# %guest_network_matrix to specify guest network information.
# %guest_migration_matrix to store all guest migration tests.
# %test_result to record test reults for all guests and tests.
#
# Run-time settings:
# LOCAL_IPADDR, LOCAL_FQDN, PEER_IPADDR and PEER_FQDN store
# ip address and FQDN of source and destination hosts.
# GUEST_UNDER_TEST stores guest to be tested.
# GUEST_UNDER_TEST_MACADDR, GUEST_UNDER_TEST_IPADDR,
# GUEST_UNDER_TEST_NETTYPE, GUEST_UNDER_TEST_NETNAME,
# GUEST_UNDER_TEST_NETMODE and GUEST_UNDER_TEST_STATICIP are
# derived from %guest_matrix for source and destination hosts
# to be on the same picture about about during test runs.
# TEST_RUN_PROGRESS stores running subroutine name as progress.
# TEST_RUN_RESULT stores the final test run result.
#
# Member subroutines to support guest migraton test:
# Check hosts health and do logs cleanup in the first place
# Initialize above global structures to facilitate test run
# Check hosts meet requirements for guest migration test
# Check guets meet requirements for guest migration test
# Restore and create environment for guest to start
# Check and update information about guest during test run
# Check final test results and create junit logs
# Synchronization between peers in pass/fail situations
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt <qe-virt@suse.de>
package parallel_guest_migration_base;

use base "opensusebasetest";
use strict;
use warnings;
use POSIX 'strftime';
use DateTime;
use testapi;
use Data::Dumper;
use upload_system_log;
use XML::LibXML;
use Tie::IxHash;
use lockapi;
use mmapi;
use Carp;
use Utils::Systemd;
use List::MoreUtils qw(firstidx);
use List::Util 'first';
use version_utils qw(is_opensuse is_sle is_alp is_microos get_os_release);
use virt_utils qw(collect_host_and_guest_logs cleanup_host_and_guest_logs enable_debug_logging);
use virt_autotest::utils qw(is_kvm_host is_xen_host check_host_health check_guest_health is_fv_guest is_pv_guest add_guest_to_hosts parse_subnet_address_ipv4 check_port_state setup_common_ssh_config is_monolithic_libvirtd);
use virt_autotest::domain_management_utils qw(construct_uri create_guest remove_guest shutdown_guest show_guest check_guest_state);
use utils qw(zypper_call systemctl script_retry define_secret_variable);
use virt_autotest::common;

tie our %guest_matrix, 'Tie::IxHash', ();
tie our %guest_network_matrix, 'Tie::IxHash', ();
tie our %test_result, 'Tie::IxHash', ();
%guest_network_matrix = (
    nat => {
        device => 'virbrX',
        ipaddr => '192.168.X.1',
        netmask => '255.255.255.0',
        masklen => '24',
        startaddr => '192.168.X.2',
        endaddr => '192.168.X.254'
    },
    route => {
        device => 'virbrX',
        ipaddr => '192.168.X.1',
        netmask => '255.255.255.0',
        masklen => '24',
        startaddr => '192.168.X.2',
        endaddr => '192.168.X.254'
    },
    default => {
        device => 'virbr0',
        ipaddr => '',
        netmask => '',
        masklen => '',
        startaddr => '',
        endaddr => ''
    },
    host => {
        device => 'br0',
        ipaddr => '',
        netmask => '',
        masklen => '',
        startaddr => '',
        endaddr => ''
    },
    bridge => {
        device => 'brX',
        ipaddr => '192.168.X.1',
        netmask => '255.255.255.0',
        masklen => '24',
        startaddr => '192.168.X.2',
        endaddr => '192.168.X.254'
    }
);
tie our %guest_migration_matrix_kvm, 'Tie::IxHash', (
    virsh_live_native => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --unsafe guest dsturi',
    virsh_live_native_p2p => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --persistent --change-protection --unsafe --compressed --abort-on-error --undefinesource guest dsturi',
    virsh_live_tunnel_p2p => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --tunnelled --persistent --change-protection --unsafe --compressed --abort-on-error --undefinesource guest dsturi',
    virsh_live_native_p2p_auto_postcopy => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --persistent --change-protection --unsafe --compressed --abort-on-error --postcopy --postcopy-after-precopy --undefinesource guest dsturi',
    virsh_live_native_p2p_manual_postcopy => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --persistent --change-protection --unsafe --compressed --abort-on-error --postcopy --undefinesource guest dsturi#virsh --connect=srcuri --debug=0 migrate-postcopy guest',
    virsh_offline_native_p2p => 'virsh --connect=srcuri --debug=0 migrate --verbose --offline --p2p --persistent --unsafe --undefinesource guest dsturi');
tie our %guest_migration_matrix_xen, 'Tie::IxHash', (
    xl_online => 'xl -vvv migrate guest dstip',
    virsh_online => 'virsh --connect=srcuri --debug=0 migrate --verbose --undefinesource guest dsturi',
    virsh_live => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --undefinesource guest dsturi');
tie our %guest_migration_matrix, 'Tie::IxHash', (kvm => \%guest_migration_matrix_kvm, xen => \%guest_migration_matrix_xen);


=head2 run

Main subroutine to execute test.
=cut

sub run {
    my ($self) = @_;

    $self->set_test_run_progress;
    $self->pre_run_test;
    $self->{"start_run"} = time();
    $self->run_test;
    $self->{"stop_run"} = time();
    $self->post_run_test;
}

=head2 pre_run_test

Run before test run starts. Check host healthy state and do logs cleanup.
=cut

sub pre_run_test {
    my $self = shift;

    $self->set_test_run_progress;
    check_host_health;
    cleanup_host_and_guest_logs;
}

=head2 run_test

Actual test is executed in this subroutine which needs to be overloaded in test
module which uses this module as base.
=cut

sub run_test {
    my $self = shift;

    $self->set_test_run_progress;
    croak("Please overload this subroutine in children modules to run desired tests");
}

=head2 post_run_test

Run after test run finishes. Judge overall test run result and die if test fails. 
=cut

sub post_run_test {
    my $self = shift;

    $self->set_test_run_progress;
    print "Final Test Results Are:\n", Dumper(\%test_result);
    foreach my $_guest (keys %test_result) {
        foreach my $_test (keys %{$test_result{$_guest}}) {
            if ($test_result{$_guest}{$_test}{status} eq 'FAILED') {
                set_var('TEST_RUN_RESULT', 'FAILED');
                bmwqemu::save_vars();
                bmwqemu::load_vars();
                croak("Test run failed because certain test case did not pass");
            }
        }
    }
    $self->create_junit_log;
    set_var('TEST_RUN_RESULT', 'PASSED');
    bmwqemu::save_vars();
    bmwqemu::load_vars();
}

=head2 get_parallel_role

Get role (parent or children) of job based on whether PARALLEL_WITH is given.
=cut

sub get_parallel_role {
    my $self = shift;

    return get_var('PARALLEL_WITH', '') ? 'children' : 'parent';
}

=head2 create_barrier

Create barriers to be used for synchronization between peers.
=cut

sub create_barrier {
    my ($self, %args) = @_;
    $args{signal} //= '';
    croak("Signal to be created must be given") if (!$args{signal});

    foreach my $_signal (split(/ /, $args{signal})) {
        barrier_create($_signal, 2);
        record_info("$_signal(x2) barrier created");
    }
}

=head2 set_test_run_progress

Any subroutine calls this set_test_run_progress will set TEST_RUN_PROGRESS to
the name of FILE::SUBROUTINE. If argument token is not empty, it will be added
to the end of the name of FILE::SUBROUTINE.
=cut

sub set_test_run_progress {
    my ($self, %args) = @_;
    $args{token} //= '';

    my $_test_run_progress = (caller(1))[3];
    $_test_run_progress .= "_$args{token}" if ($args{token});
    set_var('TEST_RUN_PROGRESS', $_test_run_progress);
    bmwqemu::save_vars();
    bmwqemu::load_vars();
}

=head2 get_test_run_progress

Return TEST_RUN_PROGRESS of peer or self job depends on whether argument peer is
set (1) or not (0);
=cut

sub get_test_run_progress {
    my ($self, %args) = @_;
    $args{peer} //= 1;

    return get_var('TEST_RUN_PROGRESS', '') if ($args{peer} == 0);
    my $_role = $self->get_parallel_role;
    my ($_peer_info, $_peer_vars) = $self->get_peer_info(role => $_role);
    return $_peer_vars->{'TEST_RUN_PROGRESS'} if (defined $_peer_vars->{'TEST_RUN_PROGRESS'});
    return '';
}

=head2 get_test_run_result

Return TEST_RUN_RESULT of peer or self job depends on whether argument peer is
set (1) or not (0);
=cut

sub get_test_run_result {
    my ($self, %args) = @_;
    $args{peer} //= 1;

    return get_var('TEST_RUN_RESULT', '') if ($args{peer} == 0);
    my $_role = $self->get_parallel_role;
    my ($_peer_info, $_peer_vars) = $self->get_peer_info(role => $_role);
    return $_peer_vars->{'TEST_RUN_RESULT'} if (defined $_peer_vars->{'TEST_RUN_RESULT'});
    return '';
}

=head2 do_local_initialization

Initialization information about local host and save it into variables.
=cut

sub do_local_initialization {
    my $self = shift;
    $self->set_test_run_progress;

    record_info("Local initialization");
    my $_localip = '';
    my $_localfqdn = '';
    set_var('LOCAL_IPADDR', $_localip);
    set_var('LOCAL_FQDN', $_localfqdn);
    $_localip = script_output("hostname -i", type_command => 1) if (script_retry("hostname -i", option => '--kill-after=1 --signal=9', delay => 1, retry => 60) == 0);
    (($_localip eq '' or $_localip eq '127.0.0.1' or $_localip eq '::1 127.0.0.1') and (is_sle('15+') or !is_sle)) ? set_var('LOCAL_IPADDR', (split(/ /, script_output("hostname -I", type_command => 1)))[0]) : set_var('LOCAL_IPADDR', $_localip);
    $_localfqdn = script_output("hostname -f", type_command => 1) if (script_retry("hostname -f", option => '--kill-after=1 --signal=9', delay => 1, retry => 60) == 0);
    (($_localfqdn eq '' or $_localfqdn eq 'localhost') and (is_sle('15+') or !is_sle)) ? set_var('LOCAL_FQDN', (split(/ /, script_output("hostname -A", type_command => 1)))[0]) : set_var('LOCAL_FQDN', $_localfqdn);
    save_screenshot;
    set_var('TEST_RUN_RESULT', '');
    bmwqemu::save_vars();
    bmwqemu::load_vars();
}

=head2 do_peer_initialization

Initialization information about peer, save it into variables and setup passwordless
ssh connection to it.
=cut

sub do_peer_initialization {
    my $self = shift;
    $self->set_test_run_progress;

    record_info("Peer initialization");
    my $_role = $self->get_parallel_role;
    my ($_peer_info, $_peer_vars) = $self->get_peer_info(role => $_role);
    set_var('PEER_IPADDR', $_peer_vars->{'LOCAL_IPADDR'});
    set_var('PEER_FQDN', $_peer_vars->{'LOCAL_IPADDR'});
    bmwqemu::save_vars();
    bmwqemu::load_vars();
    assert_script_run("sed -i -r \'/^PreferredAuthentications.*\$/d\' /root/.ssh/config") if (script_run("ls /root/.ssh/config") == 0);
    $self->config_ssh_pubkey_auth(addr => get_required_var('PEER_IPADDR'), overwrite => 0);
}

=head2 get_peer_info

Get peer job info and variables.
=cut

sub get_peer_info {
    my $self = shift;

    my $_peer = '';
    my $_peerid = '';
    my $_role = $self->get_parallel_role;
    if ($_role eq 'parent') {
        $_peer = get_children();
        $_peerid = (keys %$_peer)[0];
    }
    elsif ($_role eq 'children') {
        $_peer = get_parents();
        $_peerid = $_peer->[0];
    }

    my $_peerinfo = get_job_info($_peerid);
    my $_peervars = get_job_autoinst_vars($_peerid);
    print "Peer Job Info:", Dumper($_peerinfo);
    print "Peer Job Vars:", Dumper($_peervars);
    return ($_peerinfo, $_peervars);
}

=head2 config_ssh_pubkey_auth

Configure SSH Public Key Authentication to host or guest. Main arguments are
address to which ssh connects, whether overwrite (1) or not (0) existing keys,
either host (1) or guest (0) on which operation will be done and whether die
(1) or not (0) if any failures happen.
=cut

sub config_ssh_pubkey_auth {
    my ($self, %args) = @_;
    $args{addr} //= '';
    $args{overwrite} //= 0;
    $args{host} //= 1;
    $args{die} //= 0;
    croak("The address of ssh connnection must be given") if (!$args{addr});

    assert_script_run("clear && ssh-keygen -b 2048 -t rsa -q -N \"\" -f ~/.ssh/id_rsa <<< y") if ($args{overwrite} == 1 or script_run("ls ~/.ssh/id_rsa") != 0);
    my $_ret = 0;
    foreach my $_addr (split(/ /, $args{addr})) {
        record_info("Config $_addr SSH PubKey auth");
        next if (script_run("timeout --kill-after=1 --signal=9 15 ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_addr ls") == 0);
        enter_cmd("clear", wait_still_screen => 3);
        enter_cmd("timeout --kill-after=1 --signal=9 30 ssh-copy-id -f -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root\@$_addr", wait_still_screen => 3);
        if ($args{host} == 1) {
            susedistribution::handle_password_prompt();
        }
        else {
            check_screen("password-prompt", 60);
            enter_cmd(get_var('_SECRET_GUEST_PASSWORD', ''), wait_screen_change => 50, max_interval => 1);
            wait_still_screen(35);
        }
        my $_temp = 1;
        $_temp = script_run("timeout --kill-after=1 --signal=9 15 ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_addr ls");
        $_ret |= $_temp;
        record_info("Machine $_addr SSH PubKeyAuth failed", "Can not establish ssh connection to machine $_addr using Public Key Authentication", result => 'fail') if ($_temp != 0);
    }
    croak("SSH public key authentication setup failed for certain system") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 check_host_architecture

Check source and destination hosts have the same architecture, otherwise test run
can not proceed.
=cut

sub check_host_architecture {
    my ($self, %args) = @_;

    record_info("Check host architecture");
    my $_localip = get_var('LOCAL_IPADDR');
    my $_localarch = script_output("uname -i", type_command => 1);
    my $_peerip = get_var('PEER_IPADDR');
    my $_peerarch = script_output("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_peerip uname -i", type_command => 1);
    save_screenshot;
    croak("Architecture $_localarch on $_localip does not match $_peerarch on $_peerip") if ($_localarch ne $_peerarch);
}

=head2 check_host_os

Check source and destination hosts operating system version. Guest migration can
not be done from the newer to the older. Main argument is host role (src or dst).
=cut

sub check_host_os {
    my ($self, %args) = @_;
    $args{role} //= 'src';

    record_info("Check host os");
    my $_ret = 0;
    my $_localip = get_var('LOCAL_IPADDR');
    my $_peerip = get_var('PEER_IPADDR');
    if (is_sle) {
        my ($_localosver, $_localossp,) = get_os_release;
        my ($_peerosver, $_peerossp,) = get_os_release("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_peerip");
        save_screenshot;
        unless (($_peerosver > $_localosver) or ($_peerosver == $_localosver and $_peerossp >= $_localossp)) {
            $_ret = 1;
            if ($args{role} eq 'src') {
                croak("Destination os $_peerosver-sp$_peerossp falls behind source os $_localosver-sp$_localossp");
            }
            elsif ($args{role} eq 'dst') {
                record_info("Source os $_peerosver-sp$_peerossp  falls behind destination os $_localosver-sp$_localossp");
            }
        }
    }
    return $_ret;
}

=head2 check_host_virtualization

Check virtualization modules and services are ready, otherwise test run can not
proceed.
=cut

sub check_host_virtualization {
    my $self = shift;

    record_info("Check host virtualization");
    if (is_kvm_host) {
        assert_script_run("lsmod | grep kvm");
    }
    elsif (is_xen_host) {
        assert_script_run("lsmod | grep xen");
    }

    # Note: TBD for modular libvirt. See poo#129086 for detail.
    if (!is_alp and is_monolithic_libvirtd) {
        if (script_run("systemctl is-active libvirtd") != 0) {
            systemctl("stop libvirtd", ignore_failure => 1);
            systemctl("start libvirtd");
            systemctl("is-active libvirtd");
        }
        else {
            systemctl("restart libvirtd");
        }
        systemctl("status libvirtd");
    }
    save_screenshot;
}

=head2 check_host_package

Install necessary packages to facilitate test run down the road. Main argument
is packages to be installed.
=cut

sub check_host_package {
    my ($self, %args) = @_;
    $args{package} //= '';

    record_info("Check host package");
    zypper_call("--gpg-auto-import-keys ref");
    is_kvm_host ? zypper_call("in -t pattern kvm_tools") : zypper_call("in -t pattern xen_tools") if (!is_alp and !is_microos);
    zypper_call("in iputils nmap libguestfs* libguestfs0 guestfs-tools virt-install libvirt-client");
    zypper_call("in $args{package}") if ($args{package});
}

=head2 check_host_uid

Check source and destination hosts have the same user id for user qemu. If any 
discrepancy, set the same group id on both side by using the value provided in 
_user.
=cut

sub check_host_uid {
    my $self = shift;

    my %_user = (qemu => 996);
    my $_local = get_var('LOCAL_IPADDR');
    my $_peer = get_var('PEER_IPADDR');
    my $_localuid = '';
    my $_peeruid = '';
    foreach my $_single_user (keys %_user) {
        record_info("Check $_single_user uid on host");
        $_localuid = script_output("id -u $_single_user", type_command => 1);
        $_peeruid = script_output("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_peer id -u $_single_user", type_command => 1);
        if ($_localuid != $_peeruid) {
            my $_ret = script_run("usermod -u $_user{$_single_user} $_single_user");
            croak("$_single_user UID modification failed on $_local") if ($_ret != 0 and $_ret != 12);
            $_ret = script_run("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_peer usermod -u $_user{$_single_user} $_single_user");
            croak("$_single_user UID modification failed on $_peer") if ($_ret != 0 and $_ret != 12);
        }
        save_screenshot;
    }
}

=head2 check_host_gid

Check source and destination hosts have the same group id for groups qemu, kvm and
libvirt. If any discrepancy, set the same group id on both side by using the value
provided in _group.
=cut

sub check_host_gid {
    my $self = shift;

    my %_group = (qemu => 999,
        kvm => 998,
        libvirt => 997
    );
    my $_local = get_var('LOCAL_IPADDR');
    my $_peer = get_var('PEER_IPADDR');
    my $_localgid = '';
    my $_peergid = '';
    foreach my $_single_group (keys %_group) {
        record_info("Check $_single_group gid on host");
        $_localgid = script_output("grep ^$_single_group /etc/group|cut -d \":\" -f 3", type_command => 1);
        $_peergid = script_output("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_peer grep ^$_single_group /etc/group|cut -d \":\" -f 3", type_command => 1);
        save_screenshot;
        if ($_localgid != $_peergid) {
            my $_ret = script_run("groupmod -g $_group{$_single_group} $_single_group");
            save_screenshot;
            croak("$_single_group GID modification failed on $_local") if ($_ret != 0);
            $_ret = script_run("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_peer groupmod -g $_group{$_single_group} $_single_group");
            save_screenshot;
            croak("$_single_group GID modification failed on $_peer") if ($_ret != 0);
        }
    }
}

=head2 config_host_shared_storage

Configure shared nfs storage on server and mount it on client. Main arguments
are type of shared storage, path of exported shared storage, server or client 
and mount path on client. 
=cut

sub config_host_shared_storage {
    my ($self, %args) = @_;
    $args{type} //= 'nfs';
    $args{exppath} //= '/var/lib/libvirt/images';
    $args{role} //= 'server';
    $args{mntpath} //= '/var/lib/libvirt/images';

    record_info("Configure host shared storage");
    if ($args{type} eq 'nfs') {
        my $_temppath = get_var('EXTERNAL_NFS_SHARE', '');
        if ($_temppath) {
            script_run("umount $args{mntpath} || umount -f -l $args{mntpath}");
            assert_script_run("mount -t nfs $_temppath $args{mntpath}");
            $args{role} eq 'server' ? assert_script_run("rm -f -r $args{mntpath}/nfsok; touch $args{mntpath}/nfsok") : assert_script_run("cd ~ && ls -lah $args{mntpath}/nfsok");
        }
        elsif ($args{role} eq 'server') {
            if (script_run("ls /etc/nfs.conf") == 0) {
                my $_cpu_num = 0;
                $_cpu_num = script_output("grep -c ^processor /proc/cpuinfo", type_command => 1, proceed_on_failure => 1);
                $_cpu_num = 1 if ($_cpu_num == 0 or $_cpu_num eq '');
                my $_nfs_threads = 32 * $_cpu_num;
                assert_script_run("sed -i -r \'s/^.*threads=.*\$/ threads=$_nfs_threads/g\' /etc/nfs.conf");
            }
            $_temppath = $args{exppath};
            $_temppath =~ s/\//\\\//g;
            assert_script_run("sed -i \'/^.*$_temppath.*\$/d\' /etc/exports");
            assert_script_run("echo \"$args{exppath} *(rw,sync,no_root_squash,no_subtree_check)\" >> /etc/exports");
            assert_script_run("exportfs -a");
            systemctl('restart nfs-server.service');
            systemctl('status nfs-server.service');
            assert_script_run("rm -f -r $args{exppath}/nfsok; touch $args{exppath}/nfsok");
            save_screenshot;
        }
        elsif ($args{role} eq 'client') {
            my $_nfsserver = get_var('PEER_IPADDR');
            script_run("umount $args{mntpath} || umount -f -l $args{mntpath}");
            assert_script_run("mount -t nfs $_nfsserver:$args{exppath} $args{mntpath}");
            assert_script_run("cd ~ && ls -lah $args{mntpath}/nfsok");
            save_screenshot;
        }
    }
}

=head2 config_host_security

Get rid of limitations come from security services and rules which may have impact
on connectivity between host and guest.
=cut

sub config_host_security {
    my $self = shift;

    record_info("Config host security");
    my @_security_service = ('SuSEFirewall2', 'firewalld', 'apparmor');
    foreach my $_ss (@_security_service) {
        if (script_run("systemctl is-enabled $_ss") == 0) {
            systemctl("stop $_ss");
            systemctl("disable $_ss");
            save_screenshot;
        }
    }

    if (script_run("cat /etc/selinux/config | grep -i ^SELINUX=enforcing\$") == 0) {
        assert_script_run("sed -i -r \'s/^SELINUX=enforcing\$/SELINUX=permissive/g\' /etc/selinux/config");
    }

    script_run("iptables -P INPUT ACCEPT;
iptables -P FORWARD ACCEPT;
iptables -P OUTPUT ACCEPT;
iptables -t nat -F;
iptables -F;
sysctl -w net.ipv4.ip_forward=1;
sysctl -w net.ipv4.conf.all.forwarding=1;
sysctl -w net.ipv6.conf.all.forwarding=1"
    );
    save_screenshot;
    setup_common_ssh_config;
}

=head2 guest_under_test

Obtain all guests to be tested, either from test suite level setting GUEST_LIST
or those already on host. Destination host retrieves such information from source.
At last, initialize guest_matrix to empty.
=cut

sub guest_under_test {
    my ($self, %args) = @_;
    $args{role} //= '';
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    $self->set_test_run_progress;
    croak("Role used to differentiate migration source from destination must be given") if (!$args{role});

    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    if ($args{role} eq 'src') {
        my $_guest_under_test = get_var('GUEST_LIST', '');
        if (!$_guest_under_test) {
            $_guest_under_test = join(" ", split(/\n/, script_output("virsh $_uri list --all --name | grep -v Domain-0", type_command => 1)));
        }
        else {
            $_guest_under_test = join(" ", split(/,/, $_guest_under_test));
        }
        set_var('GUEST_UNDER_TEST', $_guest_under_test);
        bmwqemu::save_vars();
        bmwqemu::load_vars();
    }
    elsif ($args{role} eq 'dst') {
        my ($_peer_info, $_peer_vars) = $self->get_peer_info(role => $self->get_parallel_role);
        set_var('GUEST_UNDER_TEST', $_peer_vars->{'GUEST_UNDER_TEST'});
        bmwqemu::save_vars();
        bmwqemu::load_vars();
    }

    foreach my $_guest (split(/ /, get_required_var('GUEST_UNDER_TEST'))) {
        tie my %_single_guest_matrix, 'Tie::IxHash', (macaddr => '', ipaddr => '', nettype => '', netname => '', netmode => '', staticip => 'no');
        $guest_matrix{$_guest} = \%_single_guest_matrix;
    }
    print "Guest Matrix After Initialization:\n", Dumper(\%guest_matrix);
    return get_required_var('GUEST_UNDER_TEST');
}

=head2 initialize_test_result

Initialize hash structure test_result, which contains all tests specified by
test suite level setting GUEST_MIGRATION_TEST, to 'FAILED' and TEST_RUN_RESULT
to empty. The detailed test commands are stored in guest_migration_matrix.
=cut

sub initialize_test_result {
    my $self = shift;

    $self->set_test_run_progress;
    my @_guest_migration_test = split(/,/, get_var('GUEST_MIGRATION_TEST', ''));
    my $_full_test_matrix = is_kvm_host ? $parallel_guest_migration_base::guest_migration_matrix{kvm} : $parallel_guest_migration_base::guest_migration_matrix{xen};
    @_guest_migration_test = keys(%$_full_test_matrix) if (scalar @_guest_migration_test == 0);
    my $_localip = get_required_var('LOCAL_IPADDR');
    my $_peerip = get_required_var('PEER_IPADDR');
    my $_localuri = virt_autotest::domain_management_utils::construct_uri();
    my $_peeruri = virt_autotest::domain_management_utils::construct_uri(host => $_peerip);

    foreach my $_guest (keys %parallel_guest_migration_base::guest_matrix) {
        tie my %_single_guest_matrix, 'Tie::IxHash', ();
        while (my ($_testindex, $_test) = each(@_guest_migration_test)) {
            my $_command = $_full_test_matrix->{$_test};
            $_command =~ s/guest/$_guest/g;
            $_command =~ s/srcuri/$_localuri/g;
            $_command =~ s/dsturi/$_peeruri/g;
            $_command =~ s/dstip/$_peerip/g;
            tie my %_single_test_matrix, 'Tie::IxHash', (status => 'FAILED', test_time => strftime("\%H:\%M:\%S", gmtime(0)), shortname => $_test);
            $_single_guest_matrix{$_command} = \%_single_test_matrix;
        }
        $test_result{$_guest} = \%_single_guest_matrix;
    }
    set_var('TEST_RUN_RESULT', '');
    bmwqemu::save_vars();
    bmwqemu::load_vars();
    print "Test Results After Initialization:\n", Dumper(\%test_result);
}

=head2 save_guest_asset

Save guest xml config for use down the road. Main arguments are guest to be manipulated
, directory in which xml config is stored and whether die (1) or not (0) if any failures 
happen. This subroutine also calls construct_uri to determine the desired URI to be used
if the interested party is not localhost. Please refer to subroutine construct_uri for 
the arguments related.
=cut

sub save_guest_asset {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be saved must be given") if (!$args{guest});

    my $_ret = 0;
    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Save $_guest asset");
        my $_temp = 1;
        $_temp = script_run("virsh $_uri dumpxml $_guest > $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/target\" $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/alias\" $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/source/\@portid\" $args{confdir}/$_guest.xml");
        if (script_output("xmlstarlet sel -T -t -v \"//devices/interface/\@type\" $args{confdir}/$_guest.xml", type_command => 1, proceed_on_failure => 1) eq 'network') {
            $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/source/\@bridge\" $args{confdir}/$_guest.xml");
        }
        $_ret |= $_temp;
        record_info("Guest $_guest asset saving failed", "Failed to save guest $_guest asset", result => 'fail') if ($_temp != 0);
    }
    save_screenshot;
    croak("Guest asset saving for certain guest failed") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 restore_guest_asset

Find guest disk and xml config with domain name, restore them to their original
names and places. Main arguments are guest to be manipulated, whether die (1) 
or not (0) if any failures happen, directories in which guest asset and config 
are stored. This subroutine also calls construct_uri to determine the desired 
URI to be connected if the interested party is not localhost. Please refer to 
subroutine construct_uri for the arguments related.
=cut

sub restore_guest_asset {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{assetdir} //= '/var/lib/libvirt/images';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be restored must be given") if (!$args{guest});

    my $_ret = 0;
    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Restore $_guest asset");
        my $_temp = 1;
        my $_guest_asset_name = $_guest . '_on-host_' . get_required_var('DISTRI') . '-' . get_required_var('VERSION') . '*' . get_required_var('SYSTEM_ROLE') . '_' . get_required_var('ARCH');
        my $_guest_disk_downloaded = script_output("find $args{assetdir} -type f \\( -iname \"*$_guest_asset_name*disk\" -o -iname \"*$_guest_asset_name*raw\" -o -iname \"*$_guest_asset_name*qcow2\" \\) | head -1", type_command => 1, proceed_on_failure => 1);
        my $_guest_config = script_output("find $args{assetdir} -type f -iname \"*$_guest_asset_name*xml\" | head -1", type_command => 1, proceed_on_failure => 1);
        my $_guest_disk_original = script_output("xmlstarlet sel -T -t -v \"//devices/disk/source/\@file\" $_guest_config", type_command => 1, proceed_on_failure => 1);
        $_temp = script_run("nice ionice qemu-img convert -p -f qcow2 $_guest_disk_downloaded -O qcow2 $_guest_disk_original && rm -f -r $_guest_disk_downloaded", timeout => 300);
        $_temp |= script_run("mv $_guest_config $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/target\" $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/alias\" $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/source/\@portid\" $args{confdir}/$_guest.xml");
        if (script_output("xmlstarlet sel -T -t -v \"//devices/interface/\@type\" $args{confdir}/$_guest.xml", type_command => 1, proceed_on_failure => 1) eq 'network') {
            $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/interface/source/\@bridge\" $args{confdir}/$_guest.xml");
        }
        $_ret |= $_temp;
        save_screenshot;
        record_info("Guest $_guest asset restoring failed", "Failed to restoring guest $_guest asset", result => 'fail') if ($_temp != 0);
    }
    croak("Guest asset restoring for certain guest failed") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 config_guest_clock

Configure guest clock to kvm-clock or tsc. Please refer to guest migration requirements:
https://susedoc.github.io/doc-sle/main/single-html/SLES-virtualization/#libvirt-admin-live-migration-requirements
Main arguments are guest to be configured, directory in which guest xml config is
stored and whether die (1) or not (0) if any failures happen.
=cut

sub config_guest_clock {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{die} //= 0;
    croak("Guest to be configured must be given") if (!$args{guest});

    my $_ret = 0;
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Config $_guest clock");
        my $_temp = 1;
        script_run("cp $args{confdir}/$_guest.xml $args{confdir}/$_guest.xml.backup");
        $_temp = script_run("xmlstarlet ed --inplace --delete \"/domain/clock\" $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --subnode \"/domain\" --type elem -n clock -v \"\" $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --insert \"/domain/clock\" --type attr -n offset -v utc $args{confdir}/$_guest.xml");
        my $_clock = is_kvm_host ? "kvm-clock" : "tsc";
        $_temp |= script_run("xmlstarlet ed --inplace --insert \"/domain/clock/timer\" --type attr -n name -v $_clock --insert \"/domain/clock/timer\" --type attr -n present -v yes $args{confdir}/$_guest.xml");
        $_ret |= $_temp;
        if ($_temp != 0) {
            script_run("mv $args{confdir}/$_guest.xml.backup $args{confdir}/$_guest.xml");
            record_info("Guest $_guest clock config failed", "Failed to configure guest $_guest clock settings", result => 'fail');
        }
        save_screenshot;
    }
    croak("Clock configuration failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 config_guest_storage

Configure guest storage cache mode to none. Please refer to guest migration requirements:
https://susedoc.github.io/doc-sle/main/single-html/SLES-virtualization/#libvirt-admin-live-migration-requirements
Main arguments are guest to be configured, directory in which guest xml config is
stored and whether die (1) or not (0) if any failures happen.
=cut

sub config_guest_storage {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{die} //= 0;
    croak("Guest to be configured must be given") if (!$args{guest});

    my $_ret = 0;
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Config $_guest storage");
        my $_temp = 1;
        $_temp = script_run("cp $args{confdir}/$_guest.xml $args{confdir}/$_guest.xml.backup");
        $_temp |= script_run("xmlstarlet ed --inplace --delete \"/domain/devices/disk/driver/\@cache\" $args{confdir}/$_guest.xml");
        $_temp |= script_run("xmlstarlet ed --inplace --insert \"/domain/devices/disk/driver[\@name=\'qemu\']\" --type attr -n cache -v none $args{confdir}/$_guest.xml");
        $_ret |= $_temp;
        if ($_temp != 0) {
            script_run("mv $args{confdir}/$_guest.xml.backup $args{confdir}/$_guest.xml");
            record_info("Guest $_guest storage config failed", "Failed to configure guest $_guest storage settings", result => 'fail');
        }
        save_screenshot;
    }
    croak("Storage configuration failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 config_guest_console

Configure serial console for guest by using libguestfs tools. Main arguments are
guest to be configured, directory in which guest xml config is stored and whether
die (1) or not (0) if any failures happen. This subroutine also calls construct_uri
to determine the desired URI to be connected if the interested party is not localhost.
Please refer to subroutine construct_uri for the arguments related.
=cut

sub config_guest_console {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be configured must be given") if (!$args{guest});

    my $_host_console = '';
    my $_guest_console = '';
    if (is_kvm_host) {
        $_host_console = script_output("dmesg | grep -i \"console.*enabled\" | grep -ioE \"tty[A-Z]{1,}\" | head -1", type_command => 1, proceed_on_failure => 1);
        $_guest_console = $_host_console ? $_host_console . 0 : 'ttyS0';
    }

    my $_ret = 0;
    my $_guest_device = '';
    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Config $_guest console");
        my $_temp = 1;
        $_guest_console = (is_fv_guest($_guest) ? 'ttyS0' : 'hvc0') if (is_xen_host);
        script_run("virsh $_uri destroy $_guest");
        $_temp = script_retry("! virsh $_uri list --all | grep \"$_guest \" | grep running", delay => 1, retry => 5, die => 0);
        foreach my $_dev (split(/\/n/, script_output("virt-filesystems $_uri -d $_guest | grep -ioE \"^/dev.*[^@].*\$\"", type_command => 1, proceed_on_failure => 1))) {
            if (script_run("virt-ls $_uri -d $_guest -m $_dev / | grep -ioE \"^boot\$\"") == 0) {
                $_guest_device = $_dev;
                last;
            }
        }
        $_temp |= script_run("virt-edit $_uri -d $_guest -m $_guest_device /boot/grub2/grub.cfg -e \"s/\$/ console=tty console=$_guest_console,115200/ if /.*(linux|kernel).*\\\/boot\\\/(vmlinuz|image).*\$/i\"");
        $_ret |= $_temp;
        save_screenshot;
        record_info("Guest $_guest console config failed", "Failed to configure console $_guest_device for guest $_guest", result => 'fail') if ($_temp != 0);
    }
    croak("Console configuration failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 start_guest

Start guest by using virsh start and wait for it up and running if necessary. Main
arguments are guest to start, virtualization management tool to be used, whether
restart (1) or not (0), whether die (1) or not (0) if any failures happen and whether
wait (1) or not (0) for guest up and running. This subroutine also calls construct_uri
to determine the desired URI to be connected if the interested party is not localhost.
Please refer to subroutine construct_uri for the arguments related.
=cut

sub start_guest {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{restart} //= 0;
    $args{die} //= 0;
    $args{wait} //= 1;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be started must be given") if (!$args{guest});

    my $_ret = 0;
    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $_guest (split(/ /, $args{guest})) {
        my $_temp = 1;
        $_temp = $args{restart} == 0 ? script_run("virsh $_uri start $_guest") : script_run("virsh $_uri reboot $_guest") if ($args{virttool} eq 'virsh');
        $_temp = $args{restart} == 0 ? 0 : script_run("xl reboot -F $_guest") if ($args{virttool} eq 'xl');
        $_temp |= $self->wait_guest(guest => $_guest) if ($_temp == 0 and $args{wait} == 1);
        $_ret |= $_temp;
        save_screenshot;
        record_info("Guest $_guest starting failed", "Failed to start guest $_guest by using $args{virttool} ($_uri) start/create $_guest", result => 'fail') if ($_temp != 0);
    }
    croak("Failed to start all guests") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 wait_guest

Wait for guest up and running by obtaining ip address, adding mapping in /etc/hosts,
and calling wait_guest_ssh. Main arguments are guest to wait, whether check ip 
address (1) or not (0) and whether die (1) or not (0) if any failures happen.
=cut

sub wait_guest {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{checkip} //= 1;
    $args{die} //= 0;
    croak("Guest to wait for must be given") if (!$args{guest});

    my $_ret = 0;
    foreach my $_guest (split(/ /, $args{guest})) {
        my $_temp = 1;
        $self->check_guest_network_address(guest => $_guest) if ($args{checkip} == 1);
        add_guest_to_hosts($_guest, $guest_matrix{$_guest}{ipaddr});
        save_screenshot;
        $_temp = $guest_matrix{$_guest}{ipaddr} eq '' ? 1 : $self->wait_guest_ssh(guest => $_guest);
        $_ret |= $_temp;
        save_screenshot;
        record_info("Guest $_guest waiting failed", "Failed to wait guest up and running", result => 'fail') if ($_temp != 0);
    }
    croak("Waiting for guest up and running failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 wait_guest_ssh

Detect whether guest ssh port is open by using nc. Main arguments are guest to
be detected, times of retry and whether die (1) or not (0) if any failures happen.
=cut

sub wait_guest_ssh {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{retry} //= 60;
    $args{die} //= 0;
    croak("Guest to be waited for must be given") if (!$args{guest});

    my $_ret = 0;
    foreach my $_guest (split(/ /, $args{guest})) {
        my $_temp = 1;
        $_temp = script_retry("nc -zvD $_guest 22", option => '--kill-after=1 --signal=9', delay => 1, retry => $args{retry}, die => 0);
        save_screenshot;
        $_ret |= $_temp;
        record_info("Guest $_guest ssh failed", "Failed to detect open port 22 on guest $_guest", result => 'fail') if ($_temp != 0);
    }
    croak("ssh connection failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 check_guest_network_config

Check and obtain guest network configuration. Guest xml config contains enough
information about network to which guest connects on boot, for example:
<interface type="network">
  <mac address="00:16:3e:4f:5a:35"/>
  <source network="vnet_nat"/>
</interface>
or
<interface type='bridge'>
  <mac address='52:54:00:70:9d:b2'/>
  <source bridge='br123'/>
  <model type='virtio'/>
  <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
</interface>
Interface type, source network/bridge name and model type are those useful ones
determine the network, they will be stored in guest_matrix{guest}{nettype}, 
guest_matrix{guest}{netname} and guest_matrix{guest}{netmode}. In order to obtain
netmode conveniently and consistently, netname should take the form of "vnet_" +
"nat/route/host" + "_other_strings" if virtual network to be used. Addtionally,
guest_matrix{guest}{macaddr} is also upated by querying domiflist and ip address
guest_matrix{guest}{ipaddr} can also be obtained from lib/virt_autotest/common.pm
if static ip address is being used. The main arguments are guest to be checked 
and directory in which guest xml config is stored. This subroutine also calls 
construct_uri to determine the desired URI to be connected if the interested party 
is not localhost. Please refer to subroutine construct_uri for the arguments related.
=cut

sub check_guest_network_config {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be checked must be given") if (!$args{guest});

    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Check $_guest network config", "Check and store $_guest network config from xml config, including ip address if static ip is assigned");
        $guest_matrix{$_guest}{macaddr} = script_output("virsh $_uri domiflist $_guest | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"", type_command => 1, proceed_on_failure => 1);
        $guest_matrix{$_guest}{nettype} = script_output("xmlstarlet sel -T -t -v \"//devices/interface/\@type\" $args{confdir}/$_guest.xml", type_command => 1, proceed_on_failure => 1);
        if ($guest_matrix{$_guest}{nettype} eq 'network' or $guest_matrix{$_guest}{nettype} eq 'bridge') {
            $guest_matrix{$_guest}{netname} = script_output("xmlstarlet sel -T -t -v \"//devices/interface/source/\@$guest_matrix{$_guest}{nettype}\" $args{confdir}/$_guest.xml", type_command => 1, proceed_on_failure => 1);
            if ($guest_matrix{$_guest}{nettype} eq 'network') {
                $guest_matrix{$_guest}{netmode} = $guest_matrix{$_guest}{netname} ne 'default' ? (split(/_/, $guest_matrix{$_guest}{netname}))[1] : 'default';
            }
            if ($guest_matrix{$_guest}{nettype} eq 'bridge') {
                $guest_matrix{$_guest}{netmode} = $guest_matrix{$_guest}{netname} eq 'br0' ? 'host' : 'bridge';
            }
        }
        if (get_var('REGRESSION', '') =~ /xen|kvm|qemu/i and defined $virt_autotest::common::guests{$_guest}->{ip} and $virt_autotest::common::guests{$_guest}->{ip} ne '') {
            $guest_matrix{$_guest}{ipaddr} = $virt_autotest::common::guests{$_guest}->{ip};
            $guest_matrix{$_guest}{staticip} = 'yes';
        }
        save_screenshot;
    }
}

=head2 check_guest_network_address

Check and obtain guest ip address. If static ip address is being used, there is
no need to check it anymore. If guest uses bridge device directly, its ip address 
can be obtained by querying journal log or scanning subnet by using nmap (if host 
bridge device br0 is being used directly) with mac address. If guest uses virtual 
network created by virsh, its ip address can be obtained by querying dhcp leases 
of the virtual network or scanning subnet by using nmap (if host bridge device is 
being used in the virtual network directly) with mac address. The main arguments 
is guest to be checked. This subroutine also calls construct_uri to determine the 
desired URI to be connected if the interested party is not localhost. Please refer 
to subroutine construct_uri for the arguments related.
=cut

sub check_guest_network_address {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be checked must be given") if (!$args{guest});

    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Check $_guest network address", "Check and store $_guest network address assigned by dhcp service. Skip if static ip is being used.");
        return if ($guest_matrix{$_guest}{staticip} eq 'yes');
        if ($guest_matrix{$_guest}{nettype} eq 'network') {
            if ($guest_matrix{$_guest}{netmode} eq 'host') {
                my $_br0_network = script_output("ip route show all | grep -v default | grep \".* br0\" | awk \'{print \$1}\'", type_command => 1, proceed_on_failure => 1);
                script_retry("nmap -sP $_br0_network | grep -i $guest_matrix{$_guest}{macaddr}", option => '--kill-after=1 --signal=9', timeout => 180, retry => 30, delay => 10, die => 0);
                $guest_matrix{$_guest}{ipaddr} = script_output("nmap -sP $_br0_network | grep -i $guest_matrix{$_guest}{macaddr} -B2 | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", type_command => 1, timeout => 180, proceed_on_failure => 1);
            }
            else {
                script_retry("virsh $_uri net-dhcp-leases --network $guest_matrix{$_guest}{netname} | grep -ioE \"$guest_matrix{$_guest}{macaddr}.*([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", retry => 30, delay => 10, die => 0);
                $guest_matrix{$_guest}{ipaddr} = script_output("virsh $_uri net-dhcp-leases --network $guest_matrix{$_guest}{netname} | grep -i $guest_matrix{$_guest}{macaddr} | awk \'{print \$5}\'", type_command => 1, proceed_on_failure => 1);
                $guest_matrix{$_guest}{ipaddr} = (split(/\//, $guest_matrix{$_guest}{ipaddr}))[0];
                save_screenshot;
            }
        }
        elsif ($guest_matrix{$_guest}{nettype} eq 'bridge') {
            if ($guest_matrix{$_guest}{netname} eq 'br0') {
                my $_br0_network = script_output("ip route show all | grep -v default | grep \".* br0\" | awk \'{print \$1}\'", type_command => 1, proceed_on_failure => 1);
                script_retry("nmap -sP $_br0_network | grep -i $guest_matrix{$_guest}{macaddr}", option => '--kill-after=1 --signal=9', timeout => 180, retry => 30, delay => 10, die => 0);
                $guest_matrix{$_guest}{ipaddr} = script_output("nmap -sP $_br0_network | grep -i $guest_matrix{$_guest}{macaddr} -B2 | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", type_command => 1, timeout => 180, proceed_on_failure => 1);
            }
            else {
                script_retry("journalctl --no-pager -n 100 | grep -i \"DHCPACK.*$guest_matrix{$_guest}{netname}.*$guest_matrix{$_guest}{macaddr}\" | tail -1 | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", option => '--kill-after=1 --signal=9', retry => 30, delay => 10, die => 0);
                $guest_matrix{$_guest}{ipaddr} = script_output("journalctl --no-pager -n 100 | grep -i \"DHCPACK.*$guest_matrix{$_guest}{netname}.*$guest_matrix{$_guest}{macaddr}\" | tail -1 | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", type_command => 1, proceed_on_failure => 1);
            }
        }
        save_screenshot;
    }
}

=head2 create_guest_network

Create network, type of which is either network or bridge, to be used with guest.
In order to make this work consistent, data in hash structure guest_network_matrix
will be used for network creating, and the network name should begin with "vnet_"
followed by "nat", "route" or "host" if network type is "network", or be "br0" or 
"br123" if network type is "bridge". For guest using static ip address, network
address info is derived from guest ip address. Main arguments are guest to be 
served, the directory in which network xml config will be stored and whether die 
(1) or not (0) if any error.This subroutine also calls construct_uri to determine 
the desired URI to be connected if the interested party is not localhost. Please 
refer to subroutine construct_uri for the arguments related.
=cut

sub create_guest_network {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    $args{guest} = get_required_var('GUEST_UNDER_TEST') if (!$args{guest});

    my $_ret = 1;
    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    my @_guest_network_configured = ();
    my @_defintfs = split(/\n/, script_output("ip route show default | grep -i dhcp | awk \'{print \$5}\'", type_command => 1, proceed_on_failure => 1));
    while (my ($_intfidx, $_defintf) = each(@_defintfs)) {
        if ($_intfidx == 0) {
            $_ret = script_run("iptables --table nat --append POSTROUTING --out-interface $_defintf -j MASQUERADE");
        }
        else {
            $_ret |= script_run("iptables --table nat --append POSTROUTING --out-interface $_defintf -j MASQUERADE");
        }
    }
    my %_netmode_counter = (nat => 114, route => 115, bridge => 113);
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Create $guest_matrix{$_guest}{netname} network for $_guest", "Skip if $_guest network $guest_matrix{$_guest}{netname} is already configured");
        next if grep(/^$guest_matrix{$_guest}{netname}$/, @_guest_network_configured);
        my $_temp = 1;
        my $_device = $guest_network_matrix{$guest_matrix{$_guest}{netmode}}{device};
        my $_ipaddr = $guest_network_matrix{$guest_matrix{$_guest}{netmode}}{ipaddr};
        my $_netmask = $guest_network_matrix{$guest_matrix{$_guest}{netmode}}{netmask};
        my $_masklen = $guest_network_matrix{$guest_matrix{$_guest}{netmode}}{masklen};
        my $_startaddr = $guest_network_matrix{$guest_matrix{$_guest}{netmode}}{startaddr};
        my $_endaddr = $guest_network_matrix{$guest_matrix{$_guest}{netmode}}{endaddr};
        if ($guest_matrix{$_guest}{netmode} =~ /nat|route|bridge/i) {
            $_netmode_counter{$guest_matrix{$_guest}{netmode}} += 10;
            $_device =~ s/X/$_netmode_counter{$guest_matrix{$_guest}{netmode}}/g;
            $_ipaddr =~ s/X/$_netmode_counter{$guest_matrix{$_guest}{netmode}}/g;
            $_startaddr =~ s/X/$_netmode_counter{$guest_matrix{$_guest}{netmode}}/g;
            $_endaddr =~ s/X/$_netmode_counter{$guest_matrix{$_guest}{netmode}}/g;
        }
        if ($guest_matrix{$_guest}{staticip} eq 'yes') {
            $_ipaddr = (split(/\.([^\.]+)$/, $guest_matrix{$_guest}{ipaddr}))[0] . '.1';
            $_startaddr = (split(/\.([^\.]+)$/, $guest_matrix{$_guest}{ipaddr}))[0] . '.2';
            $_endaddr = (split(/\.([^\.]+)$/, $guest_matrix{$_guest}{ipaddr}))[0] . '.254';
        }
        if ($guest_matrix{$_guest}{nettype} eq 'network') {
            script_run("virsh $_uri net-destroy $guest_matrix{$_guest}{netname}");
            if ($guest_matrix{$_guest}{netname} ne 'default') {
                script_run("virsh $_uri net-undefine $guest_matrix{$_guest}{netname}");
                my $_forward_mode = $guest_matrix{$_guest}{netmode} eq 'host' ? 'bridge' : $guest_matrix{$_guest}{netmode};
                type_string("cat > $args{confdir}/$guest_matrix{$_guest}{netname}.xml <<EOF
<network>
  <name>$guest_matrix{$_guest}{netname}</name>
  <bridge name=\"$_device\"/>
EOF
");
                if ($guest_matrix{$_guest}{netmode} eq 'nat') {
                    type_string("cat >> $args{confdir}/$guest_matrix{$_guest}{netname}.xml <<EOF
  <forward mode=\"$_forward_mode\">
    <nat>
      <port start=\"20232\" end=\"65535\"/>
    </nat>
  </forward>
EOF
");
                }
                else {
                    type_string("cat >> $args{confdir}/$guest_matrix{$_guest}{netname}.xml <<EOF
  <forward mode=\"$_forward_mode\"/>
EOF
");
                }
                type_string("cat >> $args{confdir}/$guest_matrix{$_guest}{netname}.xml <<EOF
  <ip address=\"$_ipaddr\" netmask=\"$_netmask\">
    <dhcp>
      <range start=\"$_startaddr\" end=\"$_endaddr\">
        <lease expiry=\"24\" unit=\"hours\"/>
      </range>
    </dhcp>
  </ip>
EOF
") if ($guest_matrix{$_guest}{netmode} ne 'host');
                type_string("cat >> $args{confdir}/$guest_matrix{$_guest}{netname}.xml <<EOF
</network>
EOF
");
                $_temp = script_run("virsh $_uri net-define $args{confdir}/$guest_matrix{$_guest}{netname}.xml");
            }
            else {
                $_temp = 0;
            }
            if (script_run("virsh $_uri net-start $guest_matrix{$_guest}{netname}") != 0) {
                # Note: TBD for modular libvirt. See poo#129086 for detail.
                if (is_monolithic_libvirtd) {
                    systemctl("restart libvirtd");
                    systemctl("status libvirtd");
                }
                $_temp |= script_run("virsh $_uri net-start $guest_matrix{$_guest}{netname}");
            }
            else {
                $_temp |= 0;
            }
            $_temp |= script_run("iptables --append FORWARD --in-interface $_device -j ACCEPT") if ($_device ne 'br0');
            if (script_run("virsh $_uri net-list | grep \"$guest_matrix{$_guest}{netname} .*active\"") != 0) {
                record_info("Network $guest_matrix{$_guest}{netname} creation failed", script_output("virsh $_uri list --all; virsh $_uri net-dumpxml $guest_matrix{$_guest}{netname};ip route show all", type_command => 1, proceed_on_failure => 1), result => 'fail');
                $_temp |= 1;
            }
        }
        elsif ($guest_matrix{$_guest}{nettype} eq 'bridge') {
            if ($guest_matrix{$_guest}{netname} ne 'br0') {
                if (script_run("ip route show all | grep \"$guest_matrix{$_guest}{netname} \"") != 0) {
                    script_run("ip -d addr del $_ipaddr/$_masklen dev $guest_matrix{$_guest}{netname}; ip -d link set dev $guest_matrix{$_guest}{netname} down; ip -d link del dev $guest_matrix{$_guest}{netname}");
                    $_temp = script_retry("ip -d link add $guest_matrix{$_guest}{netname} type $guest_matrix{$_guest}{nettype}; ip -d addr flush dev $guest_matrix{$_guest}{netname}", option => '--kill-after=1 --signal=9', retry => 3, die => 0);
                    $_temp |= script_retry("ip -d addr add $_ipaddr/$_masklen dev $guest_matrix{$_guest}{netname} && ip -d link set $guest_matrix{$_guest}{netname} up", option => '--kill-after=1 --signal=9', retry => 3, die => 0);
                    $_temp |= script_run("iptables --append FORWARD --in-interface $guest_matrix{$_guest}{netname} -j ACCEPT");
                    my $_find_netdev = grep(/^$guest_matrix{$_guest}{netname}$/, split(/\n/, script_output("ip route show | grep -v default | awk \'{print \$3}\'", type_command => 1, proceed_on_failure => 1)));
                    $_temp |= 1 && record_info("Network $guest_matrix{$_guest}{netname} creation failed", script_output("ip addr show all;ip route show all", type_command => 1, proceed_on_failure => 1), result => 'fail') if (!$_find_netdev);
                }
                else {
                    $_temp = 0;
                }
                my $_dnsmasq_command = "/usr/sbin/dnsmasq --bind-dynamic --listen-address=$_ipaddr --dhcp-range=$_startaddr,$_endaddr,$_netmask,8h --interface=br123 --dhcp-authoritative --no-negcache --dhcp-option=option:router,$_ipaddr --log-queries --log-dhcp --dhcp-sequential-ip --dhcp-client-update --no-daemon";
                if (!script_output("ps ax | grep -i \"$_dnsmasq_command\" | grep -v grep | awk \'{print \$1}\'", type_command => 1, proceed_on_failure => 1)) {
                    $_temp |= script_run("((nohup $_dnsmasq_command) &)");
                    my $_find_dnsmasq = script_output("ps ax | grep -i \"$_dnsmasq_command\" | grep -v grep | awk \'{print \$1}\'", type_command => 1, proceed_on_failure => 1);
                    $_temp |= 1 && record_info("DHCP service failed on $guest_matrix{$_guest}{netname}", "Command to start DHCP service is $_dnsmasq_command", result => 'fail') if (!$_find_dnsmasq);
                }
            }
        }
        push(@_guest_network_configured, $guest_matrix{$_guest}{netname});
        $_ret |= $_temp;
        save_screenshot;
    }
    record_info("Guest network configuration done", script_output("ip addr show;ip route show all;virsh $_uri net-list --all;(for i in \`virsh $_uri net-list --all --name\`;do virsh $_uri net-dumpxml \$i;done);ps axu | grep dnsmasq", type_command => 1, proceed_on_failure => 1));
    croak("Guest network creation failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 initialize_guest_matrix

Initialize guest matrix and associated variables. If variables are not empty, then
update them. These variables will be shared between source and destination host to
facilitate collaborative operations. On source host, putting values of variables
into corresponding arrays which will be filled up or updated by calling fill_up_array.
At last, storing updated values in arrays in variables. On destination host,
initialize or update variables by retrieving corresponding information from source.
=cut

sub initialize_guest_matrix {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{role} //= '';
    croak("Role used to differentiate migration source from destination must be given") if (!$args{role});
    $args{guest} = get_required_var('GUEST_UNDER_TEST') if (!$args{guest});

    if ($args{role} eq 'src') {
        my @_guest_ipaddr = split(/ /, get_var('GUEST_UNDER_TEST_IPADDR', ''));
        my @_guest_macaddr = split(/ /, get_var('GUEST_UNDER_TEST_MACADDR', ''));
        my @_guest_nettype = split(/ /, get_var('GUEST_UNDER_TEST_NETTYPE', ''));
        my @_guest_netname = split(/ /, get_var('GUEST_UNDER_TEST_NETNAME', ''));
        my @_guest_netmode = split(/ /, get_var('GUEST_UNDER_TEST_NETMODE', ''));
        my @_guest_staticip = split(/ /, get_var('GUEST_UNDER_TEST_STATICIP', ''));

        $self->fill_up_array(ref => \@_guest_ipaddr, guest => $args{guest}, var => 'GUEST_UNDER_TEST_IPADDR');
        $self->fill_up_array(ref => \@_guest_macaddr, guest => $args{guest}, var => 'GUEST_UNDER_TEST_MACADDR');
        $self->fill_up_array(ref => \@_guest_nettype, guest => $args{guest}, var => 'GUEST_UNDER_TEST_NETTYPE');
        $self->fill_up_array(ref => \@_guest_netname, guest => $args{guest}, var => 'GUEST_UNDER_TEST_NETNAME');
        $self->fill_up_array(ref => \@_guest_netmode, guest => $args{guest}, var => 'GUEST_UNDER_TEST_NETMODE');
        $self->fill_up_array(ref => \@_guest_staticip, guest => $args{guest}, var => 'GUEST_UNDER_TEST_STATICIP');

        set_var('GUEST_UNDER_TEST_IPADDR', join(" ", @_guest_ipaddr));
        set_var('GUEST_UNDER_TEST_MACADDR', join(" ", @_guest_macaddr));
        set_var('GUEST_UNDER_TEST_NETTYPE', join(" ", @_guest_nettype));
        set_var('GUEST_UNDER_TEST_NETNAME', join(" ", @_guest_netname));
        set_var('GUEST_UNDER_TEST_NETMODE', join(" ", @_guest_netmode));
        set_var('GUEST_UNDER_TEST_STATICIP', join(" ", @_guest_staticip));
        bmwqemu::save_vars();
        bmwqemu::load_vars();
    }
    elsif ($args{role} eq 'dst') {
        my ($_peer_info, $_peer_vars) = $self->get_peer_info(role => $self->get_parallel_role);
        set_var('GUEST_UNDER_TEST_MACADDR', $_peer_vars->{'GUEST_UNDER_TEST_MACADDR'});
        set_var('GUEST_UNDER_TEST_IPADDR', $_peer_vars->{'GUEST_UNDER_TEST_IPADDR'});
        set_var('GUEST_UNDER_TEST_NETTYPE', $_peer_vars->{'GUEST_UNDER_TEST_NETTYPE'});
        set_var('GUEST_UNDER_TEST_NETNAME', $_peer_vars->{'GUEST_UNDER_TEST_NETNAME'});
        set_var('GUEST_UNDER_TEST_NETMODE', $_peer_vars->{'GUEST_UNDER_TEST_NETMODE'});
        set_var('GUEST_UNDER_TEST_STATICIP', $_peer_vars->{'GUEST_UNDER_TEST_STATICIP'});
        bmwqemu::save_vars();
        bmwqemu::load_vars();
        $args{guest} = get_required_var('GUEST_UNDER_TEST');
        my @_guest_under_test = split(/ /, $args{guest});
        while (my ($_index, $_element) = each(@_guest_under_test)) {
            %{$guest_matrix{$_element}} = ();
            $guest_matrix{$_element}{macaddr} = (split(/ /, get_required_var('GUEST_UNDER_TEST_MACADDR')))[$_index];
            $guest_matrix{$_element}{ipaddr} = (split(/ /, get_required_var('GUEST_UNDER_TEST_IPADDR')))[$_index];
            $guest_matrix{$_element}{nettype} = (split(/ /, get_required_var('GUEST_UNDER_TEST_NETTYPE')))[$_index];
            $guest_matrix{$_element}{netname} = (split(/ /, get_required_var('GUEST_UNDER_TEST_NETNAME')))[$_index];
            $guest_matrix{$_element}{netmode} = (split(/ /, get_required_var('GUEST_UNDER_TEST_NETMODE')))[$_index];
            $guest_matrix{$_element}{staticip} = (split(/ /, get_required_var('GUEST_UNDER_TEST_STATICIP')))[$_index];
        }
    }
    print "Guest Matrix After Initialization:\n", Dumper(\%guest_matrix);
}

=head2 fill_up_array

Fill up or update existing array which contains information about running guest,
mac address, ip address, network type, network name, network mode and use static 
ip (yes) or not (no). Updated array will be used to set corresponding variables, 
for example, GUEST_UNDER_TEST_IPADDR. Main arguments are reference to the array, 
guest to be involved and variable related. Guest attribute name is derived from 
corresponding variable, for example, guest_matrix{guest}{netmode} is derived 
from GUEST_UNDER_TEST_NETMODE. At last, array will be filled up or updated by 
the latest guest_matrix{guest}{attribute}.
=cut

sub fill_up_array {
    my ($self, %args) = @_;
    $args{ref} //= '';
    $args{guest} //= '';
    $args{var} //= '';
    croak("Array reference/guest/variable to be filled up must be given") if (!$args{ref} or !$args{guest} or !$args{var});

    my @_guest_under_test = split(/ /, get_required_var('GUEST_UNDER_TEST'));
    my $_guest_var = lc((split(/_/, $args{var}))[-1]);
    foreach my $_guest (split(/ /, $args{guest})) {
        if (get_var($args{var}, '')) {
            my $_index = firstidx { $_ eq $_guest } (@_guest_under_test);
            $args{ref}[$_index] = $guest_matrix{$_guest}{$_guest_var};
        }
        else {
            push(@{$args{ref}}, $guest_matrix{$_guest}{$_guest_var});
        }
    }
}

=head2 test_guest_network

Test networking accessibility of guest. All guests should can be reached on host
and can reach outside from inside. The only guest that can be reached from outside
host is the one uses host bridge network. Main arguments are guest to be tested and 
whether die (1) or not (0) if any error.
=cut

sub test_guest_network {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{die} //= 0;
    croak("Guest to be tested must be given") if (!$args{guest});

    my $_ret = 0;
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Test $_guest network");
        my $_temp = 1;
        my $_ping_target = is_opensuse ? 'openqa.opensuse.org' : 'openqa.suse.de';
        $_temp = script_run("timeout --kill-after=1 --signal=9 20 ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_guest ping -c5 $_ping_target");
        $_temp |= script_run("timeout --kill-after=1 --signal=9 20 ping -c5 $guest_matrix{$_guest}{ipaddr}");
        $_temp |= 1 if (($guest_matrix{$_guest}{netmode} eq 'host') and (check_port_state($guest_matrix{$_guest}{ipaddr}, 22, 3) == 0));
        $_ret |= $_temp;
        save_screenshot;
        record_info("Guest $_guest network connectivity failed", "Network connectivity testing failed for guest $_guest", result => 'fail') if ($_temp != 0);
    }
    croak("Network connectivity testing failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 test_guest_storage

Test whether writing into guest disk is successful and return the result. Main 
arguments are guest to be tested and whether die (1) or not (0) if any error.
=cut

sub test_guest_storage {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{die} //= 0;
    croak("Guest to be tested must be given") if (!$args{guest});

    my $_ret = 0;
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Test $_guest storage");
        my $_temp = 1;
        $_temp = script_run("timeout --kill-after=1 --signal=9 20 ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_guest echo MIGRATION > /tmp/test_guest_storage && rm -f -r /tmp/test_guest_storage");
        $_ret |= $_temp;
        save_screenshot;
        record_info("Guest $_guest storage access failed", "Storage read/write testing failed for guest $_guest") if ($_temp != 0);
    }
    croak("Storage accessbility testing failed for certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 do_guest_administration

Perform basic administration on guest and return overall result. Main arguments
are guest to be manipulated, virttool (virsh or xl) to be used, directory in which 
original guest config file resides and whether die (1) or not (0) if any error. 
This subroutine also calls construct_uri to determine the desired URI to be connected 
if the interested party is not localhost. Please refer to subroutine construct_uri 
for the arguments related.
=cut

sub do_guest_administration {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be administered must be given") if (!$args{guest});

    my $_uri = "--connect=" . virt_autotest::domain_management_utils::construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    my @_administration = $args{virttool} eq 'virsh' ?
      ("virsh $_uri destroy guest",
        "virsh $_uri start guest",
        "wait guest ssh",
        "virsh $_uri list | grep \"guest .*running\"",
        "virsh $_uri save guest /tmp/guest_administration.chckpnt",
        "virsh $_uri restore /tmp/guest_administration.chckpnt",
        "virsh $_uri dumpxml guest > /tmp/guest_administration.xml",
        "virsh $_uri domxml-to-native --format native-format /tmp/guest_administration.xml > /tmp/guest_administration.cfg",
        "virsh $_uri shutdown guest",
        "virsh $_uri undefine guest --managed-save || virsh $_uri undefine guest --keep-nvram --managed-save",
        "wait guest gone",
        "virsh $_uri define --validate --file /tmp/guest_administration.xml",
        "virsh $_uri list --all",
        "virsh $_uri start guest"
      ) :
      ("xl -vvv list | grep \"guest \"",
        "xl -vvv save guest /tmp/guest_administration.chckpnt",
        "xl -vvv restore /tmp/guest_administration.chckpnt",
        "xl -vvv shutdown -F guest",
        "wait guest gone",
        "xl -vvv create /tmp/guest_administration.cfg || xl -vvv create $args{confdir}/guest.cfg"
      );
    my $_native_format = is_xen_host ? "xen-xl" : "qemu-argv";
    my $_ret = 0;
    foreach my $_guest (split(/ /, $args{guest})) {
        record_info("Do $_guest administration");
        my $_temp1 = 0;
        my @_guest_administration = ();
        foreach my $_operation (@_administration) {
            my $_temp2 = 1;
            $_operation =~ s/guest/$_guest/g;
            $_operation =~ s/native-format/$_native_format/g if ($_operation =~ /domxml-to-native/i);
            push(@_guest_administration, $_operation);
            if ($_operation eq "wait $_guest ssh") {
                $_temp2 = $self->wait_guest_ssh(guest => $_guest);
            }
            elsif ($_operation eq "wait $_guest gone") {
                $_temp2 = $args{virttool} eq 'virsh' ? script_retry("! virsh $_uri list --all | grep \"$_guest \"", retry => 120, delay => 1, die => 0) : script_retry("! xl list | grep \"$_guest \"", retry => 60, delay => 1, die => 0);
            }
            else {
                $_temp2 = script_run("$_operation");
            }
            $_temp1 |= $_temp2;
            if ($_temp2 != 0) {
                save_screenshot;
                record_info("Guest $_guest administration failed", "Administraton operation is $_operation", result => 'fail');
            }
        }
        record_info("Guest $_guest administration failed", "Administraton operation is:\n" . join("\n", @_guest_administration), result => 'fail') if ($_temp1 != 0);
        $_ret |= $_temp1;
    }
    croak("Administration failed on certain guest") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 virsh_migrate_manual_postcopy

Perform manual postcopy guest migration which needs an extra command to be executed
alongside main migration command. The return value of this extra command indicates
whether it is a successful manual postcopy guest migration. Main arguments are guest
to be migrated, main migraiton command and whether die (1) or not (0) if any error.
=cut

sub virsh_migrate_manual_postcopy {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{command} //= '';
    $args{die} //= 0;
    croak("Guest and command to be executed must be given") if (!$args{guest} or !$args{command});

    my $_ret = 1;
    my @_command = split(/#/, $args{command});
    enter_cmd("sleep 120 && $_command[0]");
    save_screenshot;
    select_console("root-ssh-virt");
    $testapi::serialdev = "virtsshserial";
    enter_cmd("clear");
    $_ret = script_run("(set -x;unset migrate_postcopy;export migrate_postcopy=1; for i in `seq 87000`;do $_command[1];migrate_postcopy=\$?; if [ \$migrate_postcopy -eq 0 ];then set +x;break;fi; done; if [ \$migrate_postcopy -eq 0 ];then echo -e \"Migrate Postcopy Succeeded! \\n\";else command-not-found;fi)", timeout => 300);
    wait_still_screen(30);
    save_screenshot;
    select_console("root-ssh");
    $testapi::serialdev = "sshserial";
    wait_still_screen(30);
    save_screenshot;
    reset_consoles;
    select_console("root-ssh");
    $_ret |= script_retry("! ps ax | grep migrate | grep -v grep", timeout => 180, retry => 30, delay => 0, die => 0);
    save_screenshot;
    croak("Guest $args{guest} manual postcopy migration failed") if ($_ret != 0 and $args{die} == 1);
    return $_ret;
}

=head2 create_junit_log

Create xml file to be parsed by parse_junit_log by using XML::LibXML. The data
source is a hash structure like test_result which stores test results and some
other side information like product and time. 
=cut

sub create_junit_log {
    my $self = shift;

    my $_start_time = $self->{start_run};
    my $_stop_time = $self->{stop_run};
    $self->{test_time} = strftime("\%H:\%M:\%S", gmtime($_stop_time - $_start_time));
    $self->{product_tested_on} = script_output("cat /etc/issue | grep -io -e \"SUSE.*\$(arch))\" -e \"openSUSE.*[0-9]\"", type_command => 1, proceed_on_failure => 1);
    $self->{product_name} = ref($self);
    $self->{package_name} = ref($self);

    tie my %_result, 'Tie::IxHash', %test_result;
    my @_overall_status = ('pass', 'fail', 'skip', 'softfail', 'timeout', 'unknown');
    foreach my $_guest (keys %_result) {
        foreach my $_test (keys %{$_result{$_guest}}) {
            my $_status = $_result{$_guest}{$_test}{status};
            my $_statustag = first { $_status =~ /^$_/i } (@_overall_status);
            $self->{$_statustag . "_num"} += 1;
        }
    }

    my $_count = 0;
    foreach my $_status (@_overall_status) {
        $self->{$_status . "_num"} = 0 if (!defined $self->{$_status . "_num"});
        $_count += $self->{$_status . "_num"};
    }

    my $_dom = XML::LibXML::Document->createDocument('1.0', 'UTF-8');
    tie my %_attribute, 'Tie::IxHash', ();
    %_attribute = (
        id => "0",
        error => "n/a",
        failures => $self->{fail_num},
        softfailures => $self->{softfail_num},
        name => $self->{product_name},
        skipped => $self->{skip_num},
        tests => $_count,
        time => $self->{test_time}
    );
    my @_attributes = (\%_attribute);
    my @_eles = ('testsuites');
    my ($_testsuites,) = $self->create_junit_element(xmldoc => \$_dom, eles => \@_eles, attrs => \@_attributes);

    %_attribute = (
        id => "0",
        error => "n/a",
        failures => $self->{fail_num},
        softfailures => $self->{softfail_num},
        hostname => get_required_var('LOCAL_FQDN'),
        name => $self->{product_tested_on},
        package => $self->{package_name},
        skipped => $self->{skip_num},
        tests => $_count,
        time => $self->{test_time},
        timestamp => DateTime->now
    );
    @_attributes = (\%_attribute);
    @_eles = ('testsuite');
    my ($_testsuite,) = $self->create_junit_element(xmldoc => \$_dom, parent => \$_testsuites, eles => \@_eles, attrs => \@_attributes);

    foreach my $_guest (keys %_result) {
        my %_test2junit_status = (passed => "success", failed => "failure", skipped => "skipped", softfailed => "softfail", timeout => "timeout_exceeded", unknown => "unknown");
        foreach my $_test (keys %{$_result{$_guest}}) {
            my $_test_status = $_result{$_guest}{$_test}{status};
            $_result{$_guest}{$_test}{status} = $_test2junit_status{first { /^$_test_status/i } (keys(%_test2junit_status))};
            $_result{$_guest}{$_test}{guest} = $_guest;
            %_attribute = (
                classname => $_result{$_guest}{$_test}{shortname},
                name => $_test,
                status => $_result{$_guest}{$_test}{status},
                time => ($_result{$_guest}{$_test}{test_time} ? $_result{$_guest}{$_test}{test_time} : 'n/a')
            );
            @_attributes = (\%_attribute);
            @_eles = ('testcase');
            my ($_testcase,) = $self->create_junit_element(xmldoc => \$_dom, parent => \$_testsuite, eles => \@_eles, attrs => \@_attributes);
            my @_eles = ('system-err', 'system-out', 'failure');
            my @_texts = (
                ($_result{$_guest}{$_test}{error} ? $_result{$_guest}{$_test}{error} : 'n/a'),
                ($_result{$_guest}{$_test}{output} ? $_result{$_guest}{$_test}{output} : 'n/a') . " time cost: $_result{$_guest}{$_test}{test_time}",
                ($_result{$_guest}{$_test}{status} eq 'success' ? '' : "affected subject: $_result{$_guest}{$_test}{guest}")
            );
            $self->create_junit_element(xmldoc => \$_dom, parent => \$_testcase, eles => \@_eles, texts => \@_texts);
        }
    }

    $_dom->setDocumentElement($_testsuites);
    type_string("cat > /tmp/output.xml <<EOF\n" .
          $_dom->toString(1) . "\nEOF\n");
    script_run("cat /tmp/output.xml && chmod 777 /tmp/output.xml");
    save_screenshot;
    parse_junit_log("/tmp/output.xml");

}

=head2 create_junit_element

Create xml elements that may have attributes, text or child and return array 
of created elements. Accepted arguments are references to xml doc object, parent 
of element to be created, array of elements to be created, array of attributes of 
elements and array of texts of elements. The order in which elements appear in 
array of elements to be created should be the same as those respective attributes 
and texts in their arrays.
=cut

sub create_junit_element {
    my ($self, %args) = @_;
    $args{xmldoc} //= "";
    $args{parent} //= "";
    $args{eles} //= ();
    $args{attrs} //= ();
    $args{texts} //= ();
    croak("JUnit xml object must be given") if (!$args{xmldoc});

    my $_index = 0;
    my @_eles = ();
    foreach my $_ele (@{$args{eles}}) {
        my $_element = ${$args{xmldoc}}->createElement($_ele);
        push(@_eles, $_element);
        if ($args{attrs}) {
            tie my %_attrs, 'Tie::IxHash', ();
            %_attrs = %{$args{attrs}->[$_index]};
            foreach my $_attr (keys %_attrs) {
                $_element->setAttribute("$_attr" => "$_attrs{$_attr}");
            }
        }
        $_element->appendText($args{texts}->[$_index]) if ($args{texts});
        ${$args{parent}}->appendChild($_element) if ($args{parent});
        $_index += 1;
    }
    return @_eles;
}

=head2 check_peer_test_run

Check progress of test run of peer job. This subroutine is called to verify whether
peer job is destined to fail or not and return its test run result. This is usually
called by paired job that is already in post_fail_hook to wait for peer job if it 
already failed or is about to fail, so the peer job can finish operations instead of
being cancelled due to paired job fails and terminates. This can be achieved simply
by barrier_wait on certain lock by both jobs if the peer fails as well. There are 
situations in which peer job needs to move pass current running subroutines like,
do_guest_migration or post_run_test, before entering into post_fail_hook, so it is
necessary to wait a period before having the final resolution. But if peer job still
remains any earlier steps, it is not meaningful to wait anymore because locks ahead.
=cut

sub check_peer_test_run {
    my $self = shift;

    my $_peer_test_run_progress = $self->get_test_run_progress;
    my $_peer_test_run_result = $self->get_test_run_result;
    diag("LATEST PEER TEST RUN PROGRESS: $_peer_test_run_progress LATEST PEER TEST RUN RESULT: $_peer_test_run_result");
    my $_wait_start_time = time();
    while ($_peer_test_run_progress =~ /do_guest_migration|post_run_test/i) {
        last if (($_peer_test_run_progress =~ /do_guest_migration/i and time() - $_wait_start_time > 1800) or ($_peer_test_run_progress =~ /post_run_test/i));
        $_peer_test_run_progress = $self->get_test_run_progress;
        $_peer_test_run_result = $self->get_test_run_result;
        diag("LATEST PEER TEST RUN PROGRESS: $_peer_test_run_progress LATEST PEER TEST RUN RESULT: $_peer_test_run_result");
    }
    $_peer_test_run_result = 'FAILED' if ($_peer_test_run_progress =~ /post_fail_hook/i);
    return $_peer_test_run_result;
}

=head2 post_fail_hook

Set TEST_RUN_RESULT to FAILED, create junit log and collect logs.
=cut

sub post_fail_hook {
    my $self = shift;

    save_screenshot;
    reset_consoles;
    select_console("root-ssh");
    $testapi::serialdev = "sshserial";
    $self->set_test_run_progress;
    set_var('TEST_RUN_RESULT', 'FAILED');
    bmwqemu::save_vars();
    bmwqemu::load_vars();

    $self->{"stop_run"} = time();
    $self->create_junit_log;
    collect_host_and_guest_logs('', '', '', "_post_fail_hook");
}

1;
