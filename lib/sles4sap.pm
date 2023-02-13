# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for SAP tests
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);
package sles4sap;
use Mojo::Base 'opensusebasetest';

use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use hacluster qw(get_hostname ha_export_logs pre_run_hook save_state wait_until_resources_started);
use isotovideo;
use ipmi_backend_utils;
use x11utils qw(ensure_unlocked_desktop);
use power_action_utils qw(power_action);
use Utils::Backends;
use registration qw(add_suseconnect_product);
use version_utils qw(is_sle);
use utils qw(zypper_call);
use Utils::Systemd qw(systemctl);
use Utils::Logging 'save_and_upload_log';

our @EXPORT = qw(
  $instance_password
  $systemd_cgls_cmd
  SAPINIT_RE
  SYSTEMD_RE
  SYSTEMCTL_UNITS_RE
  ensure_serialdev_permissions_for_sap
  fix_path
  set_ps_cmd
  set_sap_info
  user_change
  reset_user_change
  get_total_mem
  prepare_profile
  mount_media
  add_hostname_to_hosts
  test_pids_max
  test_forkbomb
  test_version_info
  test_instance_properties
  test_stop
  test_start
  reboot
  check_replication_state
  check_hanasr_attr
  check_landscape
  do_hana_sr_register
  do_hana_takeover
  install_libopenssl_legacy
  startup_type
);

=head1 SYNOPSIS

Package with common methods and default values for tests on SLES for
SAP Applications.

This package inherits from B<opensusebasetest> and should be used as
a class.

=cut

our $prev_console;
our $sapadmin;
our $sid;
our $instance;
our $product;
our $ps_cmd;
our $instance_password = get_var('INSTANCE_PASSWORD', 'Qwerty_123');
our $systemd_cgls_cmd = 'systemd-cgls --no-pager -u SAP.slice';

=head2 SAPINIT_RE & SYSTEMD_RE

    $self->SAPINIT_RE();
    $self->SAPINIT_RE(qr/some regexp/);
    $self->SYSTEMD_RE();
    $self->SYSTEMD_RE(qr/some regexp/);

Set or get a regular expressions to test on the F</usr/sap/sapservices> file
whether the SAP workload was started via sapinit or systemd.

=cut

has SAPINIT_RE => undef;
has SYSTEMD_RE => undef;

=head2 SYSTEMCTL_UNITS_RE

    $self->SYSTEMCTL_UNITS_RE();
    $self->SYSTEMCTL_UNITS_RE(qr/some regexp/);

Set or get a regular expression to test in the output of C<systemctl --list-unit-files>
whether the SAP workload was started via systemd units.

=cut

has SYSTEMCTL_UNITS_RE => undef;

=head2 ensure_serialdev_permissions_for_sap

Derived from 'ensure_serialdev_permissions' function available in 'utils'.

Grant user permission to access serial port immediately as well as persisting
over reboots. Used to ensure that testapi calls like script_run work for the
test user as well as root.

=cut

sub ensure_serialdev_permissions_for_sap {
    my ($self) = @_;
    # ownership has effect immediately, group change is for effect after
    # reboot an alternative https://superuser.com/a/609141/327890 would need
    # handling of optional sudo password prompt within the exec
    my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
    assert_script_run "grep '^${serial_group}:.*:${sapadmin}\$' /etc/group || (chown $sapadmin /dev/$testapi::serialdev && gpasswd -a $sapadmin $serial_group)";
}

=head2 fix_path

 $self->fix_path( $uri );

Given the path to a CIFS or NFS share in B<$uri>, this method will format the path
so it can be used directly by B<mount(8)>. Returns an array with the protocol name (cifs
or nfs) as the first element, and the formatted path as the second element. Croaks if
an unsupported protocol is passed in B<$uri> or if it cannot be parsed.

=cut

sub fix_path {
    my ($self, $var) = @_;
    my ($proto, $path) = split m|://|, $var;
    my @aux = split '/', $path;

    $proto = 'cifs' if ($proto eq 'smb' or $proto eq 'smbfs');
    die 'Currently only supported protocols are nfs and smb/smbfs/cifs'
      unless ($proto eq 'nfs' or $proto eq 'cifs');

    $aux[0] .= ':' if ($proto eq 'nfs');
    $aux[0] = '//' . $aux[0] if ($proto eq 'cifs');
    $path = join '/', @aux;
    return ($proto, $path);
}

=head2 set_ps_cmd

 $self->set_ps_cmd( $procname );

Sets in the class instance the B<ps> command to be used to check for the presence
of SAP processes in the SUT. Returns the value of the internal variable B<$ps_cmd>.

=cut

sub set_ps_cmd {
    my ($self, $procname) = @_;
    $ps_cmd = 'ps auxw | grep ' . $procname . ' | grep -vw grep' if ($procname);
    return $ps_cmd;
}

=head2 set_sap_info

 $self->set_sap_info( $SID, $instance_number );

SAP software relies on 2 identifiers, the system id (SID) which is a 3-character
identifier, and the instance number. This method receives both via positional
arguments, and sets the internal variables for B<$sid>, B<$instance> and B<$sapadmin>
accordingly. It also sets accessors that depend on B<$sid> and B<$instance>
as well as the product type. Returns the value of B<$sapadmin>.

=cut 

sub set_sap_info {
    my ($self, $sid_env, $instance_env) = @_;
    $sid = uc($sid_env);
    $instance = $instance_env;
    $sapadmin = lc($sid_env) . 'adm';
    $product = get_var('INSTANCE_TYPE', 'HDB');    # Default to HDB as INSTANCE_TYPE is only a required setting in NW tests
    if (ref($self)) {
        # Only set RE if called in OO mode
        $self->SAPINIT_RE(qr|$sid/$product$instance/exe/sapstartsrv|);
        $self->SYSTEMD_RE(qr|systemctl.+start SAP${sid}_$instance|);
        $self->SYSTEMCTL_UNITS_RE(qr/SAP${sid}_$instance.service/);
    }
    return ($sapadmin);
}

=head2 user_change

 $self->user_change();

Switch user in SUT to the SAP admin account, and grant serialdev
permissions to the SAP admin user.

=cut

sub user_change {
    # Allow SAP Admin user to inform status via $testapi::serialdev
    # Note: need to be keep here and during product installation to
    #       ensure compatibility with older generated images
    ensure_serialdev_permissions_for_sap;

    # Change to SAP Admin user
    enter_cmd "su - $sapadmin";

    # Change the working shell to bash as SAP's installer sets the admin
    # user's shell to /bin/csh and csh has problems with strings that start
    # with ~ which can be generated by testapi::hashed_string() leading to
    # unexpected failures of script_output() or assert_script_run()
    enter_cmd "exec bash";

    # We need to change the 'serial_term_prompt' value for 'wait_serial'
    my $serial_term_prompt = "$sapadmin> ";
    enter_cmd(qq/PS1="$serial_term_prompt"/);
    wait_serial(qr/PS1="$serial_term_prompt"/) if testapi::is_serial_terminal;
    $testapi::distri->{serial_term_prompt} = "$serial_term_prompt";
}

=head2 reset_user_change

 $self->reset_user_change();

Exit from the SAP admin account in SUT and change serialdev
permissions accordingly.

=cut

sub reset_user_change {
    # Close the window
    enter_cmd "exit";

    # Reset 'serial_term_prompt' value for 'wait_serial'
    $testapi::distri->{serial_term_prompt} = '# ';

    # Rollback changes to $testapi::serialdev
    ensure_serialdev_permissions;
}

=head2 get_total_mem

 $self->get_total_mem();

Returns the total memory configured in SUT.

=cut

sub get_total_mem {
    return get_required_var('QEMURAM') if (is_qemu);
    my $mem = script_output q@grep ^MemTotal /proc/meminfo | awk '{print $2}'@;
    $mem /= 1024;
    return $mem;
}

=head2 is_saptune_installed

 is_saptune_installed();

Checks if the B<saptune> package is installed in SUT. Returns true or false.

=cut

sub is_saptune_installed {
    my $ret = script_run "rpm -q saptune";
    return (defined $ret and $ret == 0);
}

=head2 prepare_profile

 $self->prepare_profile( $profile );

Configures with B<saptune> (if available in SUT) or B<sapconf> the SUT according to
a profile passed as argument. B<$profile> must be either B<HANA> or B<NETWEAVER>.
Croaks on failure.

=cut

sub prepare_profile {
    my ($self, $profile) = @_;
    return unless ($profile eq 'HANA' or $profile eq 'NETWEAVER');

    # Will prepare system with saptune only if it's available.
    my $has_saptune = $self->is_saptune_installed();

    if ($has_saptune) {
        assert_script_run "saptune daemon start";
        assert_script_run "saptune solution apply $profile";
    }
    elsif (is_sle('15+')) {
        # On SLE15+ the sapconf command was dropped
        assert_script_run "/usr/lib/sapconf/sapconf start";
    }
    else {
        assert_script_run("sapconf stop && sapconf " . lc($profile));
    }

    if (!$has_saptune) {
        # Restart systemd-logind to ensure that all new connections will have the
        # SAP tuning activated. Since saptune v2, the call to 'saptune solution apply'
        # above can make the SUT change focus to the x11 console, which may not be ready
        # for the systemctl command. If the systemctl command times out, change to
        # root-console and try again. Run the first call to systemctl with
        # ignore_failure => 1 to avoid stopping the test. Second call runs as usual
        my $ret = systemctl('restart systemd-logind.service', ignore_failure => 1);
        die "systemctl restart systemd-logind.service failed with retcode: [$ret]" if $ret;
        if (!defined $ret) {
            select_serial_terminal;
            systemctl 'restart systemd-logind.service';
        }
    }

    # X11 workaround only on ppc64le
    if (get_var('OFW')) {
        # 'systemctl restart systemd-logind' is causing the X11 console to move
        # out of tty2 on SLES4SAP-15, which in turn is causing the change back to
        # the previous console in post_run_hook() to fail when running on systems
        # with DESKTOP=gnome, which is a false positive as the test has already
        # finished by that step. The following prevents post_run_hook from attempting
        # to return to the console that was set before this test started. For more
        # info on why X is running in tty2 on SLES4SAP-15, see bsc#1054782
        $prev_console = undef;

        # If running in DESKTOP=gnome, systemd-logind restart may cause the graphical console to
        # reset and appear in SUD, so need to select 'root-console' again
        assert_screen(
            [
                qw(root-console displaymanager displaymanager-password-prompt generic-desktop
                  text-login linux-login started-x-displaymanager-info)
            ], 120);
        select_serial_terminal unless (match_has_tag 'root-console');
    }
    else {
        # If running in DESKTOP=gnome, systemd-logind restart may cause the graphical
        # console to reset and appear in SUD, so need to select 'root-console' again
        # 'root-console' can be re-selected safely even if DESKTOP=textmode
        select_serial_terminal;
    }

    if ($has_saptune) {
        assert_script_run "saptune daemon start";
        my $ret = script_run("saptune solution verify $profile", die_on_timeout => 0);
        if (!defined $ret) {
            # Command timed out. 'saptune daemon start' could have caused the SUT to
            # move out of root-console, so select root-console and try again
            select_serial_terminal;
            $ret = script_run "saptune solution verify $profile";
        }
        record_soft_failure("poo#57464: 'saptune solution verify' returned warnings or errors! Please check!") if ($ret && !is_qemu());

        my $output = script_output "saptune daemon status", proceed_on_failure => 1;
        if (!defined $output) {
            # Command timed out or failed. 'saptune solution verify' could have caused
            # the SUT to move out of root-console, so select root-console and try again
            select_serial_terminal;
            $output = script_output "saptune daemon status";
        }
        record_info("saptune status", $output);
    }
}

=head2 mount_media

 $self->mount_media( $proto, $path, $target );

Mount installation media in SUT from the share identified by B<$proto> and
B<$path> into the target directory B<$target>.

=cut

sub mount_media {
    my ($self, $proto, $path, $target) = @_;
    my $mnt_path = '/mnt';
    my $media_path = "$mnt_path/" . get_required_var('ARCH');

    assert_script_run "mkdir $target";
    assert_script_run "mount -t $proto -o ro $path $mnt_path";
    $media_path = $mnt_path if script_run "[[ -d $media_path ]]";    # Check if specific ARCH subdir exists

    # Create a overlay to "allow" writes to the readonly filesystem
    assert_script_run "mkdir /.workdir /.upperdir";
    assert_script_run "mount -t overlay overlay -o lowerdir=$media_path,upperdir=/.upperdir,workdir=/.workdir $target";
}

=head2 add_hostname_to_hosts

 $self->add_hostname_to_hosts();

Adds the IP address and the hostname of SUT to F</etc/hosts>. Croaks on failure.

=cut

sub add_hostname_to_hosts {
    my $netdevice = get_var('SUT_NETDEVICE', 'eth0');
    assert_script_run "echo \$(ip -4 addr show dev $netdevice | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p') \$(hostname) >> /etc/hosts";
}

=head2 test_pids_max

 $self->test_pids_max();

Checks in SUT that the SAP admin user has no limits in the number of processes
and threads that it can create.

=cut

sub test_pids_max {
    # UserTasksMax should be set to "infinity" in /etc/systemd/logind.conf.d/sap.conf
    my $uid = script_output "id -u $sapadmin";
    # The systemd-run command generates syslog output that may end up in the console, so save the output to a file
    assert_script_run "systemd-run --slice user -qt su - $sapadmin -c 'cat /sys/fs/cgroup/pids/user.slice/user-${uid}.slice/pids.max' | tr -d '\\r' | tee /tmp/pids-max";
    my $rc1 = script_run "grep -qx max /tmp/pids-max";
    # nproc should be set to "unlimited" in /etc/security/limits.d/99-sapsys.conf
    # Check that nproc * 2 + 1 >= threads-max
    assert_script_run "systemd-run --slice user -qt su - $sapadmin -c 'ulimit -u' -s /bin/bash | tail -n 1 | tr -d '\\r' > /tmp/nproc";
    assert_script_run "cat /tmp/nproc ; sysctl -n kernel.threads-max";
    my $rc2 = script_run "[[ \$(( \$(< /tmp/nproc) * 2 + 1)) -ge \$(sysctl -n kernel.threads-max) ]]";
    record_soft_failure "bsc#1031355" if ($rc1 or $rc2);
}

=head2 test_forkbomb

 $self->test_forkbomb();

Runs a script in SUT to create as many processes as possible, both as the SAP
administrator and as root, and verifies that the SAP admin can create
as many as 99% of the amount of processes that root can. Croaks if any of the
commands sent to SUT fail, and record a soft failure if the SAP admin
user cannot create as many processes as root.

=cut

sub test_forkbomb {
    my $script = 'forkbomb.pl';
    assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/$script -o /tmp/$script; chmod +x /tmp/$script";
    # The systemd-run command generates syslog output that may end up in the console, so save the output to a file
    assert_script_run "systemd-run --slice user -qt su - $sapadmin -c /tmp/$script | tr -d '\\r' > /tmp/user-procs", 600;
    my $user_procs = script_output "cat /tmp/user-procs";
    my $root_procs = script_output "/tmp/$script", 600;
    # Check that the SIDadm user can create at least 99% of the processes root could create
    record_soft_failure "bsc#1031355" if ($user_procs < $root_procs * 0.99);
}

=head2 test_version_info

 $self->test_version_info();

Runs a B<sapcontrol> command with function B<GetVersionInfo> in SUT. Croaks on failure.

=cut

sub test_version_info {
    my $output = script_output "sapcontrol -nr $instance -function GetVersionInfo";
    die "sapcontrol: GetVersionInfo API failed\n\n$output" unless ($output =~ /GetVersionInfo[\r\n]+OK/);
}

=head2 test_instance_properties

 $self->test_instance_properties();

Runs a B<sapcontrol> command with function B<GetInstanceProperties> and verifies that
the reported properties match with the SID stored in the class instance. Croaks on failure.

=cut

sub test_instance_properties {
    my $output = script_output "sapcontrol -nr $instance -function GetInstanceProperties | grep ^SAP";
    die "sapcontrol: GetInstanceProperties API failed\n\n$output" unless ($output =~ /SAPSYSTEM.+SAPSYSTEMNAME.+SAPLOCALHOST/s);

    $output =~ /SAPSYSTEMNAME, Attribute, ([A-Z][A-Z0-9]{2})/m;
    die "sapcontrol: SAP administrator [$sapadmin] does not match with System SID [$1]" if ($1 ne $sid);
}

=head2 test_stop

 $self->test_stop();

Tests with B<sapcontrol> and functions B<Stop> and B<StopService> that the instance
and services are succesfully stopped. Croaks on failure.

=cut

sub test_stop {
    my ($self) = @_;

    my $output = script_output "sapcontrol -nr $instance -function Stop";
    die "sapcontrol: Stop API failed\n\n$output" unless ($output =~ /Stop[\r\n]+OK/);

    # Check if instance is correctly stopped
    $self->check_instance_state('gray');

    $output = script_output "sapcontrol -nr $instance -function StopService";
    die "sapcontrol: StopService API failed\n\n$output" unless ($output =~ /StopService[\r\n]+OK/);

    # Check if service is correctly stopped
    $self->check_service_state('stop');
}

=head2 test_start

 $self->test_start();

Tests with B<sapcontrol> and functions B<Start> and B<StartService> that the instance
and services are succesfully started. Croaks on failure.

=cut

sub test_start {
    my ($self) = @_;

    my $output = script_output "sapcontrol -nr $instance -function StartService $sid";
    die "sapcontrol: StartService API failed\n\n$output" unless ($output =~ /StartService.+OK/s);

    # Check if service is correctly started
    $self->check_service_state('start');

    # Process can take some time to initialize all
    sleep 10;
    $self->check_instance_state('gray');

    $output = script_output "sapcontrol -nr $instance -function Start";
    die "sapcontrol: Start API failed\n\n$output" unless ($output =~ /Start[\r\n]+OK/);

    $self->check_instance_state('green');

    # Show list of processes
    script_run $ps_cmd;
}

=head2 check_service_state

 $self->check_service_state( $state );

Checks in the process table of SUT for B<sapstartsrv> up to the number of seconds
specified in the B<WAIT_INSTANCE_STOP_TIME> setting (defaults to 300, with a maximum
permitted value of 600). The B<$state> argument can be either B<start> or B<stop>,
and it controls whether this method waits for the process to appear in the process
table after service was started, or disappear from the process table after service was
stopped. Croaks on failure.

=cut

sub check_service_state {
    my ($self, $state) = @_;
    my $uc_state = uc $state;

    my $time_to_wait = get_var('WAIT_INSTANCE_STOP_TIME', 300);    # Wait by default for 5 minutes
    $time_to_wait = 600 if ($time_to_wait > 600);    # Limit this to 10 minutes max

    while ($time_to_wait > 0) {
        my $output = script_output "pgrep -a sapstartsrv | grep -w $sid", proceed_on_failure => 1;
        my @olines = split(/\n/, $output);

        # Exit if there is no more process
        last if ((@olines == 0) && ($uc_state eq 'STOP'));

        if (($output =~ /sapstartsrv/) && ($uc_state eq 'START')) {
            die "sapcontrol: wrong number of processes running after a StartService\n\n" . @olines unless ((@olines == 1) || ($time_to_wait > 10));

            # Exit if service is started
            last;
        }

        $time_to_wait -= 10;
        sleep 10;
    }

    die "Timed out waiting for SAP service status to turn $state" unless ($time_to_wait > 0);
}

=head2 check_instance_state

 $self->check_instance_state( $state );

Uses B<sapcontrol> functions B<GetSystemInstanceList> and B<GetProcessList> to
check for up to the number of seconds defined in the B<WAIT_INSTANCE_STOP_TIME>
setting (defaults to 300, with a maximum permitted value of 600), whether the
instance is in the state specified by the B<$state> argument. This argument can
be either B<green> or B<gray>, and it controls whether this method waits for the
instance to turn to green status after a start or to turn to gray status after a
stop. Croaks on failure.

=cut

sub check_instance_state {
    my ($self, $state) = @_;
    my $uc_state = uc $state;

    my $time_to_wait = get_var('WAIT_INSTANCE_STOP_TIME', 300);    # Wait by default for 5 minutes
    $time_to_wait = 600 if ($time_to_wait > 600);    # Limit this to 10 minutes max

    while ($time_to_wait > 0) {
        my $output = script_output "sapcontrol -nr $instance -function GetSystemInstanceList";
        die "sapcontrol: GetSystemInstanceList: command failed" unless ($output =~ /GetSystemInstanceList[\r\n]+OK/);

        # Exit if instance is not running anymore
        last if (($output =~ /GRAY/) && ($uc_state eq 'GRAY'));

        if ((($output =~ /GREEN/) && ($uc_state eq 'GREEN')) || ($uc_state eq 'GRAY')) {
            $output = script_output "sapcontrol -nr $instance -function GetProcessList | grep -E -i ^[a-z]", proceed_on_failure => 1;
            die "sapcontrol: GetProcessList: command failed" unless ($output =~ /GetProcessList[\r\n]+OK/);

            my $failing_services = 0;
            for my $line (split(/\n/, $output)) {
                next if ($line =~ /GetProcessList|OK|^name/);
                $failing_services++ if ($line !~ /$uc_state/);
            }
            last unless $failing_services;
        }

        $time_to_wait -= 10;
        sleep 10;
    }

    die "Timed out waiting for SAP instance status to turn $uc_state" unless ($time_to_wait > 0);
}

=head2 check_replication_state

 $self->check_replication_state();

Check status of the HANA System Replication by running the
B<systemReplicationStatus.py> script in SUT. Waits for 5 minutes for
HANA System Replication to be in Active state or croaks on timeout.

Note: can only be run on active node in the cluster.

B<systemReplicationStatus.py> return codes are:
 10: No System Replication
 11: Error
 12: Unknown
 13: Initializing
 14: Syncing
 15: Active

=cut

sub check_replication_state {
    my ($self) = @_;
    my $sapadm = $self->set_sap_info(get_required_var('INSTANCE_SID'), get_required_var('INSTANCE_ID'));
    # Wait by default for 5 minutes
    my $time_to_wait = 300;
    my $cmd = "su - $sapadm -c 'python exe/python_support/systemReplicationStatus.py'";

    # Replication check can only be done on PRIMARY node
    my $output = script_output($cmd, proceed_on_failure => 1);
    return if $output !~ /mode:[\r\n\s]+PRIMARY/;

    # Loop until ACTIVE state or timeout is reached
    while ($time_to_wait > 0) {
        my $is_active = script_run($cmd);

        # Exit if replication is in state "Active"
        last if $is_active eq '15';

        $time_to_wait -= 10;
        sleep 10;
    }
    die 'Timed out waiting for HANA System Replication to turn Active' unless ($time_to_wait > 0);
}

=head2 check_hanasr_attr

 $self->check_hanasr_attr();

Runs B<SAPHanaSR-showAttr> and checks in its output for up to a timeout
specified in the named argument B<timeout> (defaults to 90 seconds) that
the sync_state is B<SOK>. It also checks that no B<SFAIL> sync_status is
present in the output. Finishes by printing the full output of
B<SAPHanaSR-showAttr>. This method will only fail if B<SAPHanaSR-showAttr>
returns a non-zero return value.

=cut

sub check_hanasr_attr {
    my ($self, %args) = @_;
    $args{timeout} //= 90;
    my $looptime = bmwqemu::scale_timeout($args{timeout});
    my $out;

    while ($out = script_output 'SAPHanaSR-showAttr') {
        last if ($out =~ /SOK/ && $out !~ /SFAIL/);
        sleep 5;
        $looptime -= 5;
        last if ($looptime <= 0);
    }
    record_info 'SOK not found', "sync_state is not in SOK after $args{timeout} seconds"
      if ($looptime <= 0 && $out !~ /SOK/);
    record_info 'SFAIL', "One of the HANA nodes still has SFAIL sync_state after $args{timeout} seconds"
      if ($looptime <= 0 && $out =~ /SFAIL/);
    record_info 'SAPHanaSR-showAttr', $out;
}

=head2 check_landscape

 $self->check_landscape();

Runs B<lanscapeHostConfiguration.py> and records the information.

=cut

sub check_landscape {
    my ($self, %args) = @_;
    my $looptime = bmwqemu::scale_timeout($args{timeout} // 90);
    my $sapadm = $self->set_sap_info(get_required_var('INSTANCE_SID'), get_required_var('INSTANCE_ID'));
    # Use proceed_on_failure => 1 on call as landscapeHostConfiguration.py returns non zero value on success
    my $out = script_output("su - $sapadm -c 'python exe/python_support/landscapeHostConfiguration.py'", proceed_on_failure => 1);
    record_info 'landscapeHostConfiguration', $out;
    die 'Overall host status not OK' unless ($out =~ /overall host status: ok/i);
}

=head2 reboot

 $self->reboot();

Restart the SUT and reconnect to the console right after.

=cut

sub reboot {
    my ($self) = @_;

    if (is_ipmi) {
        power_action('reboot', textmode => 1, keepconsole => 1);
        # wait to not assert linux-login while system goes down
        switch_from_ssh_to_sol_console;
        wait_still_screen(30);
        $self->wait_boot(textmode => 1, nologin => get_var('NOAUTOLOGIN', '0'));
    }
    else {
        power_action('reboot', textmode => 1);
        $self->wait_boot(nologin => 1, bootloader_time => 300);
    }
    select_serial_terminal;
}

=head2 do_hana_sr_register

 $self->do_hana_sr_register( node => $node );

Register current HANA node to the node specified by the named argument B<node>. With the named
argument B<proceed_on_failure> set to 1, method will use B<script_run> and return the return
value of the B<script_run> call even if sr_register command fails, otherwise B<assert_script_run>
is used and the method croaks on failure. 

=cut

sub do_hana_sr_register {
    my ($self, %args) = @_;
    my $current_node = get_hostname;
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $sapadm = $self->set_sap_info($sid, $instance_id);

    # Node name is mandatory
    die 'Node name should be set' if !defined $args{node};

    # We may want to check cluster state without stopping the test
    my $cmd = (defined $args{proceed_on_failure} && $args{proceed_on_failure} == 1) ? \&script_run : \&assert_script_run;

    return ($cmd->("su - $sapadm -c 'hdbnsutil -sr_register --name=$current_node --remoteHost=$args{node} --remoteInstance=$instance_id --replicationMode=sync --operationMode=logreplay'"));
}

=head2 do_hana_takeover

 $self->do_hana_takeover( node => $node [, manual_takeover => $manual_takeover] [, cluster => $cluster] [, timeout => $timeout] );

Do a takeover/takeback on a HANA cluster.

Set B<$node> to the node where HANA is/should be the primary server.

Set B<$manual_takeover> to true, so the method performs a manual rather than an automatic
takeover. Defaults to false.

Set B<$cluster> to true so the method runs also a C<crm resource cleanup>. Defaults to false.

Set B<$timeout> to the amount of seconds the internal calls will wait for. Defaults to 300 seconds.

=cut

sub do_hana_takeover {
    # No need to do anything if AUTOMATED_REGISTER is set
    return if check_var('AUTOMATED_REGISTER', 'true');
    my ($self, %args) = @_;
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $sapadm = $self->set_sap_info($sid, $instance_id);
    $args{timeout} //= 300;

    # Node name is mandatory
    die 'Node name should be set' if !defined $args{node};

    # Do the takeover/failback
    assert_script_run "su - $sapadm -c 'hdbnsutil -sr_takeover'" if ($args{manual_takeover});
    my $res = $self->do_hana_sr_register(node => $args{node}, proceed_on_failure => 1);
    if (defined $res && $res != 0) {
        record_info "System not ready", "HANA has not finished starting as master/slave in the HA stack";
        wait_until_resources_started(timeout => ($args{timeout} * 3));
        save_state;
        $self->check_replication_state;
        $self->check_hanasr_attr;
        script_run 'grep -E "expected_votes|two_node" /etc/corosync/corosync.conf';
        $self->do_hana_sr_register(node => $args{node});
    }
    sleep bmwqemu::scale_timeout(10);
    if ($args{cluster}) {
        assert_script_run "crm resource cleanup rsc_SAPHana_${sid}_HDB$instance_id", $args{timeout};
        assert_script_run 'crm_resource --cleanup', $args{timeout};
    }
}

=head2 install_libopenssl_legacy

 $self->install_libopenssl_legacy( $hana_path );

Install B<libopenssl1_0_0> for older (<SPS03) HANA versions on SLE15+

Set B<$hana_path> to the path where the HANA installation media is
located; this path should contain information on the HANA version to
install, so prepare it thinking on this. For example:
F<nfs://sap.sources.host.local/HANA2-SPS5rev52/>. This method will then
determine the HANA version from B<$hana_path> and decide based on the
SLES and HANA versions whether B<libopenssl1_0_0> must be installed.

=cut

sub install_libopenssl_legacy {
    my ($self, $hana_path) = @_;

    if ($hana_path =~ s/.*\/SPS([0-9]+)rev[0-9]\/.*/$1/r) {
        my $hana_version = $1;
        if (is_sle('15+') && ($hana_version <= 2)) {
            # The old libopenssl is in Legacy Module
            add_suseconnect_product('sle-module-legacy');
            zypper_call('in libopenssl1_0_0');
        }
    }
}

=head2 upload_hana_install_log

 $self->upload_hana_install_log();

Package and upload HANA installation logs from SUT.

=cut

sub upload_hana_install_log {
    script_run 'tar -Jcf /tmp/hana_install.log.tar.xz /var/adm/autoinstall/logs /var/tmp/hdb*';
    upload_logs '/tmp/hana_install.log.tar.xz';
}

=head2 upload_nw_install_log

 $self->upload_nw_install_log();

Upload NetWeaver installation logs from SUT.

=cut

sub upload_nw_install_log {
    my ($self) = @_;

    save_and_upload_log('ls -alF /sapinst/unattended', '/tmp/nw_unattended_ls.log');
    save_and_upload_log('ls -alF /sbin/mount*', '/tmp/sbin_mount_ls.log');
    upload_logs('/tmp/check-nw-media', failok => 1);
    upload_logs '/sapinst/unattended/sapinst.log';
    upload_logs('/sapinst/unattended/sapinst_ASCS.log', failok => 1);
    upload_logs('/sapinst/unattended/sapinst_ERS.log', failok => 1);
    upload_logs '/sapinst/unattended/sapinst_dev.log';
    upload_logs '/sapinst/unattended/start_dir.cd';
}

=head2 startup_type

 $self->startup_type();

Record whether the SAP workload was started via sapinit or systemd units.

=cut

sub startup_type {
    my ($self) = @_;
    my $out = script_output 'cat /usr/sap/sapservices';
    my $msg = "Could not determine $product startup method";
    $msg = "$product is started with sapstartsrv using sapinit" if ($out =~ $self->SAPINIT_RE);
    $msg = "$product is started with sapstartsrv using systemd units" if ($out =~ $self->SYSTEMD_RE);
    record_info "$product Startup", "$msg\nsapservices output:\n$out";
    $out = script_output 'systemctl --no-pager list-unit-files | grep -i sap';
    if ($out =~ $self->SYSTEMCTL_UNITS_RE) {
        record_info "$product Systemd", "$product is started using systemd units";
        record_info 'Systemd Units', $out;
    }
}

sub post_run_hook {
    my ($self) = @_;

    return unless ($prev_console);
    select_console($prev_console, await_console => 0);
    ensure_unlocked_desktop if ($prev_console eq 'x11');
}

sub post_fail_hook {
    my ($self) = @_;

    # We need to be sure that *ALL* consoles are closed, are SUPER:post_fail_hook
    # does not support virtio/serial console yet
    reset_consoles;
    select_console('root-console');

    # YaST logs
    script_run "save_y2logs /tmp/y2logs.tar.xz";
    upload_logs "/tmp/y2logs.tar.xz";

    # HANA installation logs, if needed
    $self->upload_hana_install_log if get_var('HANA');

    # NW installation logs, if needed
    $self->upload_nw_install_log if get_var('NW');

    # HA cluster logs, if needed
    ha_export_logs if get_var('HA_CLUSTER');

    # Execute the common part
    $self->SUPER::post_fail_hook;
}

1;
