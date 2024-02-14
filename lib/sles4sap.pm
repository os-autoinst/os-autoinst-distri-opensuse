# SUSE's openQA tests
#
# Copyright 2017-2024 SUSE LLC
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
use serial_terminal qw(select_serial_terminal);
use utils;
use hacluster qw(get_hostname ha_export_logs pre_run_hook save_state wait_until_resources_started script_output_retry_check);
use isotovideo;
use ipmi_backend_utils;
use x11utils qw(ensure_unlocked_desktop);
use power_action_utils qw(power_action);
use Utils::Backends;
use registration qw(add_suseconnect_product);
use version_utils qw(is_sle);
use utils qw(zypper_call);
use Digest::MD5 qw(md5_hex);
use Utils::Systemd qw(systemctl);
use Utils::Logging qw(save_and_upload_log);
use Carp qw(croak);

our @EXPORT = qw(
  $instance_password
  $systemd_cgls_cmd
  SAPINIT_RE
  SYSTEMD_RE
  SYSTEMCTL_UNITS_RE
  ASE_RESPONSE_FILE
  ensure_serialdev_permissions_for_sap
  fix_path
  set_ps_cmd
  set_sap_info
  user_change
  reset_user_change
  get_total_mem
  prepare_profile
  copy_media
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
  prepare_sapinst_profile
  netweaver_installation_data
  prepare_swpm
  sapcontrol_process_check
  get_sidadm
  sap_show_status_info
  sapcontrol
  get_instance_profile_path
  get_remote_instance_number
  load_ase_env
  upload_ase_logs
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

=head2 ASE_RESPONSE_FILE

    $self->ASE_RESPONSE_FILE($filename);

Let the class methods know the name of the ASE response file currently in use. It is set to
undef by default. Test modules testing for SAP ASE should set this property before anything else.

=cut

has ASE_RESPONSE_FILE => undef;

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
    croak('missing mandatory arg') unless $sid_env and $instance_env;
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
    my @valid_profiles = qw(HANA NETWEAVER SAP-ASE);
    return unless (grep /^$profile$/, @valid_profiles);

    # Will prepare system with saptune only if it's available.
    my $has_saptune = $self->is_saptune_installed();

    if ($has_saptune) {
        assert_script_run 'saptune service takeover';
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
        # reset and appear in SUT, so need to select 'root-console' again
        assert_screen(
            [
                qw(root-console displaymanager displaymanager-password-prompt generic-desktop
                  text-login linux-login started-x-displaymanager-info)
            ], 120);
        select_serial_terminal unless (match_has_tag 'root-console');
    }
    else {
        # If running in DESKTOP=gnome, systemd-logind restart may cause the graphical
        # console to reset and appear in SUT, so need to select 'root-console' again
        # 'root-console' can be re-selected safely even if DESKTOP=textmode
        select_serial_terminal;
    }

    if ($has_saptune) {
        assert_script_run 'saptune service takeover';
        my $ret = script_run("saptune solution verify $profile", die_on_timeout => 0);
        if (!defined $ret) {
            # Command timed out. 'saptune service takeover' could have caused the SUT to
            # move out of root-console, so select root-console and try again
            select_serial_terminal;
            $ret = script_run "saptune solution verify $profile";
        }
        record_soft_failure("poo#57464: 'saptune solution verify' returned warnings or errors! Please check!") if ($ret && !is_qemu());

        my $output = script_output 'saptune service status', proceed_on_failure => 1;
        if (!defined $output) {
            # Command timed out or failed. 'saptune solution verify' could have caused
            # the SUT to move out of root-console, so select root-console and try again
            select_serial_terminal;
            $output = script_output 'saptune service status';
        }
        record_info("saptune status", $output);
    }
}

=head2 _do_mount

 _do_mount( $proto, $path, $target);

Performs a call to the mount command (used by both C<mount_media> and C<copy_media>) with
appropiate options depending on the protocol. Function internal to the class.

=cut

sub _do_mount {
    my ($proto, $path, $mnt_path) = @_;

    # Set some NFS options in case we are using NFS
    my $nfs_client_id = md5_hex(get_required_var('JOBTOKEN'));
    my $options = 'ro';
    if ($proto eq 'nfs') {
        my $nfs_timeo = get_var('NFS_TIMEO');
        $options = $nfs_timeo ? "timeo=$nfs_timeo,rsize=16384,wsize=16384,ro" : 'rsize=16384,wsize=16384,ro';
        # Attempt to force a unique NFSv4 client id
        assert_script_run "modprobe nfs nfs4_unique_id=$nfs_client_id";
        # Check nfs4_unique_id parameter file exists
        assert_script_run 'until ls /sys/module/nfs/parameters/nfs4_unique_id; do sleep 1; done';
    }
    assert_script_run "mount -t $proto -o $options $path $mnt_path", 90;
    # Check NFS client ID
    assert_script_run 'cat /sys/module/nfs/parameters/nfs4_unique_id' if ($proto eq 'nfs');
}

=head2 copy_media

 $self->copy_media( $proto, $path, $timeout, $target);

Copies installation media in SUT from the share identified by B<$proto> and
B<$path> into the target directory B<$target>. B<$timeout> specifies how long
to wait for the copy to complete.

After installation files are copied, this method will also verify the existence
of a F<checksum.md5sum> file in the target directory and use it to check for the
integrity of the copied files. This test can be skipped by setting to a
true value the B<DISABLE_CHECKSUM> setting in the test.

The method will croak if any of the commands sent to SUT fail.

=cut

sub copy_media {
    my ($self, $proto, $path, $nettout, $target) = @_;
    my $mnt_path = '/mnt';
    my $media_path = "$mnt_path/" . get_required_var('ARCH');

    # First create $target and copy media there
    assert_script_run "mkdir $target";
    _do_mount($proto, $path, $mnt_path);
    $media_path = $mnt_path if script_run "[[ -d $media_path ]]";    # Check if specific ARCH subdir exists
    my $rsync = 'rsync -azr --info=progress2';
    record_info 'rsync stats (dry-run)', script_output("$rsync --dry-run --stats $media_path/ $target/", proceed_on_failure => 1);
    assert_script_run "$rsync $media_path/ $target/", $nettout;

    # Unmount the share, as we don't need it anymore
    assert_script_run "umount $mnt_path";

    # Skip checksum check if DISABLE_CHECKSUM is set, or if no
    # checksum.md5sum file was copied to the $target directory
    # NOTE: checksum is generated with this command: "find . -type f -exec md5sum {} \; > checksum.md5sum"
    my $chksum_file = 'checksum.md5sum';
    my $no_checksum_file = script_run "[[ -f $target/$chksum_file ]]";
    return 1 if (get_var('DISABLE_CHECKSUM') || $no_checksum_file);

    # Switch to $target to verify copied contents are OK
    assert_script_run "pushd $target";
    # We can't check the checksum file itself as well as the clustered NFS share part
    assert_script_run "sed -i -e '/$chksum_file\$/d' -e '/\\/nfs_share/d' $chksum_file";
    assert_script_run "md5sum -c --quiet $chksum_file", $nettout;
    # Back to previous directory
    assert_script_run 'popd';
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
    _do_mount($proto, $path, $mnt_path);
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

    if ($hana_path =~ s/.*\/SPS([0-9]+)rev[0-9]+\/.*/$1/r) {
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

=head2 prepare_swpm

 $self->prepare_swpm(sapcar_bin_path=>$sapcar_bin_path,
    sar_archives_dir=>$sar_archives_dir,
    swpm_sar_filename=>$swpm_sar_filename,
    target_path=>$target_path);

Unpacks and prepares swpm package from specified source dir into target directory using SAPCAR tool.
After extraction it checks for 'sapinst' executable being present in target path. Croaks if executable is missing.

B<sapcar_bin_path> Filename with full path to SAPCAR binary

B<sar_archives_dir> Directory which contains all required SAR archives (SWPM, SAP kernel, Patches, etc...)

B<swpm_sar_filename> SWPM SAR archive filename

B<target_path> Target path for archives to be unpacked into

=cut

sub prepare_swpm {
    my ($self, %args) = @_;
    # Mandatory args
    foreach ('sapcar_bin_path', 'sar_archives_dir', 'swpm_sar_filename', 'target_path') {
        croak("Mandatory argument '$_' missing") unless $args{$_};
    }

    my $sapcar_bin_path = $args{sapcar_bin_path};
    my $sar_archives_dir = $args{sar_archives_dir};
    my $swpm_sar_filename = $args{swpm_sar_filename};
    my $target_path = $args{target_path};
    my $sapinst_executable = "$target_path/sapinst";

    assert_script_run("mkdir -p $target_path");
    assert_script_run("cp $sar_archives_dir/* $target_path/");
    assert_script_run("cd $target_path; $sapcar_bin_path -xvf ./$swpm_sar_filename");
    my $swpm_dir_content = script_output("ls -alitr $target_path");
    record_info("SWPM dir", "$swpm_dir_content");

    assert_script_run("test -x $sapinst_executable");
    return $sapinst_executable;
}

=head2 prepare_sapinst_profile

 $self->prepare_sapinst_profile(
    profile_target_file=>$profile_target_file,
    profile_template_file=>$profile_template_file,
    sar_location_directory=>$sar_location_directory);

Copies sapinst profile template from NFS to target dir and fills in required variables.

B<profile_target_file> Full filename and path for sapinst install profile to be created

B<profile_template_file> Template file location from which will the profile be sceated

B<sar_location_directory> Location of SAR files -  this is filled into template

=cut

sub prepare_sapinst_profile {
    my ($self, %args) = @_;
    my $profile_target_file = $args{profile_target_file};
    my $profile_template_file = $args{profile_template_file};
    my $sar_location = $args{'sar_location_directory'};
    my $nw_install_data = $self->netweaver_installation_data();
    my $instance_data = $nw_install_data->{instances}{$args{instance_type}};

    my %replace_params = (
        '%INSTANCE_ID%' => $instance_data->{instance_id},
        '%INSTANCE_SID%' => $nw_install_data->{instance_sid},
        '%VIRTUAL_HOSTNAME%' => $instance_data->{virtual_hostname},
        '%DOWNLOAD_BASKET%' => $sar_location,
        '%SAPSYS_GID%' => $nw_install_data->{sapsys_gid},
        '%SIDADM_UID%' => $nw_install_data->{sidadm_uid},
        '%SIDADM_PASSWD%' => $testapi::password,    # Use default pw.
        '%SAP_MASTER_PASSWORD%' => $nw_install_data->{sap_master_password}
    );

    assert_script_run("cp $profile_template_file $profile_target_file");
    file_content_replace($profile_target_file, %replace_params);
}

=head2 prepare_sap_instances_data

 $self->prepare_sap_instances_data();

Prepares data for installation of all SAP components using openqa parameter "SAP_INSTANCES".
parameter example: SAP_INSTANCES = "ASCS,ERS,PAS,AAS".

B<HDB> = Hana database export - netweaver component, not database

B<ASCS> = Central services

B<ERS> = Enqueue replication

B<PAS> = Primary application server

B<AAS> = Additional application server

=cut

sub netweaver_installation_data {
    my ($self) = @_;
    croak("Parameter 'SAP_INSTANCES' contains empty value") unless get_var('SAP_INSTANCES');

    my @defined_instances = split(',', get_required_var('SAP_INSTANCES'));
    my @unsupported_values = map { !$self->is_instance_type_supported($_) ? $_ : () } @defined_instances;
    my $sap_sid = uc get_required_var('INSTANCE_SID');
    my %instances_data;
    my $instance_id = 0;
    my $sidadm_uid = get_var('SIDADM_UID', '1001');
    my $sapsys_gid = get_var('SAPSYS_GID', '1002');
    set_var('SIDADM_UID', $sidadm_uid);
    set_var('SAPSYS_GID', $sapsys_gid);

    croak('Unsupported instances defined: ' . join(' ', @unsupported_values) . "\nCheck 'SAP_INSTANCES' parameter")
      if @unsupported_values;

    # general variables
    my %installation_data = (
        instance_sid => $sap_sid,
        sidadm => $self->get_sidadm(),
        sidadm_uid => $sidadm_uid,
        sapsys_gid => $sapsys_gid,
        sap_master_password => get_required_var('_SECRET_SAP_MASTER_PASSWORD'),
        sap_directory => "/usr/sap/$sap_sid"
    );

    return \%installation_data if check_var('SUPPORT_SERVER', '1');    # Supportserver does not need anything below

    # Instance specific data
    foreach (@defined_instances) {
        my %instance_data;
        $instance_data{instance_id} = sprintf("%02d", $instance_id);
        $instance_data{product_id} = get_required_var($_ . '_PRODUCT_ID');
        $instance_data{instance_dir_name} = $_ eq 'HDB' ? undef :
          $self->get_nw_instance_name(instance_type => $_, instance_id => $instance_data{instance_id});
        $instances_data{$_} = \%instance_data;
        $instance_id++;
    }
    $installation_data{instances} = \%instances_data;

    return \%installation_data;
}

=head2 get_nw_instance_name

 $self->get_nw_instance_name(instance_type=>$instance_type, instance_id=>$instance_id);

Returns standard sap instance directory name constructed from instance id and instance type.

B<instance_type> Instance type (ASCS, ERS, PAS, AAS)

B<instance_id> Instance ID - two digit number

=cut

sub get_nw_instance_name {
    my ($self, %args) = @_;
    foreach ('instance_type', 'instance_id') {
        croak "missing mandatory argument '$_'" unless $args{$_};
    }

    my $instance_type = $self->is_instance_type_supported($args{instance_type});
    my $instance_id = $args{instance_id};
    my %instance_type_dir_names = (
        ASCS => $instance_type . $instance_id,
        ERS => $instance_type . $instance_id,
        PAS => 'D' . $instance_id,    # D means 'Dialog'
        AAS => 'D' . $instance_id
    );

    return $instance_type_dir_names{$instance_type};
}

=head2 is_instance_type_supported

 $self->is_instance_type_supported($instance_type);

Checks if instance type is supported.
Returns $instance_type with sucess, croaks with missing argument or unsupported value detected.

B<instance_type> Instance type (ASCS, ERS, PAS, AAS)

=cut

sub is_instance_type_supported {
    my ($self, $instance_type) = @_;
    my @supported_values = qw(ASCS HDB ERS PAS AAS);
    croak("Argument '\$instance_type' undefined or unsupported")
      unless $instance_type and grep(/^$instance_type$/, @supported_values) > 0;
    return $instance_type;
}

=head2 share_hosts_entry

  $self->share_hosts_entry(virtual_hostname=>$virtual_hostname,
                           virtual_ip=>$virtual_ip,
                           shared_directory_root=>shared_directory_root);

Creates file with virtual IP and hostname entry for C</etc/hosts> file on mounted shared
device (Default: C</sapmnt>). This is to help creating C</etc/hosts> file which would include
entries for all nodes.

File name: <INSTANCE_TYPE>

File content: <virtual IP> <virtual_hostname>

B<virtual_hostname> Virtual hostname (alias) which is tied to instance and will be moved with HA IP addr resource

B<virtual_ip> Virtual IP addr tied to an instance and HA resource

B<shared_directory_root> Shared directory available for all instances. Separate directory 'hosts' will be created

=cut

sub share_hosts_entry {
    my ($self, %args) = @_;
    my $virtual_hostname = $args{virtual_hostname} // get_var('INSTANCE_ALIAS', '$(hostname)');
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $virtual_ip = $args{virtual_ip} // (split('/', get_required_var('INSTANCE_IP_CIDR')))[0];
    my $shared_directory_root = $args{shared_directory_root} // '/sapmnt';    # sapmnt is usually shared between all hosts
    set_var('HOSTS_SHARED_DIRECTORY', "$shared_directory_root/hosts");

    croak "Directory '$shared_directory_root' does not appear to be a mount point" if
      script_run("mount | grep $shared_directory_root");

    assert_script_run("mkdir -p $shared_directory_root/hosts");
    assert_script_run("echo '$virtual_ip $virtual_hostname' >> $shared_directory_root/hosts/$instance_type");
}

=head2 add_hosts_file_entries

 $self->add_hosts_file_entries();

Reads files in 'HOSTS_SHARED_DIRECTORY' and adds entries into /etc/hosts file.

=cut

sub add_hosts_file_entries {
    my $source_directory = get_var('HOSTS_SHARED_DIRECTORY', '/sapmnt/hosts');    # sapmnt is usually shared between all hosts
    assert_script_run("cat $source_directory/* >> /etc/hosts");
    assert_script_run('cat /etc/hosts');
}

=head2 get_sidadm

 $self->get_sidadm([must_exist=>$must_exist]);

Returns sidadm username created from SAP sid - parameter INSTANCE_SID.
check_if_exists - if set to true, test will fail if user does not exist. tests inconsistency between OpenQA parameter and real username

B<must_exist> Checks if sidadm exists, croaks on failure. Default 'false'

=cut

sub get_sidadm {
    my ($self, %args) = @_;
    my $must_exist = $args{'must_exist'} // 0;
    my $sidadm = lc get_required_var('INSTANCE_SID') . 'adm';
    my $user_exists = script_run("id $sidadm") ? 0 : 1;    # convert RC from script run to true/false

    croak("User '$sidadm' does not exist") if $must_exist and !$user_exists;

    return $sidadm;
}

=head2 sap_show_status_info

 $self->sap_show_status_info(cluster=>1, netweaver=>1);

Prints output for standard set of commands to show info about system in various stages of the test for troubleshooting.
It is possible to activate or deactivate various output sections by named args:

B<cluster> - Shows cluster related outputs

B<netweaver> - Shows netweaver related outputs

=cut

sub sap_show_status_info {
    my ($self, %args) = @_;
    my $cluster = $args{cluster};
    my $netweaver = $args{netweaver};
    my $instance_id = defined($netweaver) ? $args{instance_id} : get_required_var('INSTANCE_ID');
    my @output;

    # Netweaver info
    if (defined($netweaver)) {
        push(@output, "\n//// NETWEAVER ///");
        push(@output, "\n### SAPCONTROL PROCESS LIST ###");
        push(@output, $self->sapcontrol(instance_id => $instance_id, webmethod => 'GetProcessList', return_output => 1));
        push(@output, "\n### SAPCONTROL SYSTEM INSTANCE LIST ###");
        push(@output, $self->sapcontrol(instance_id => $instance_id, webmethod => 'GetSystemInstanceList', return_output => 1));
    }

    # Cluster info
    if (defined($cluster)) {
        push(@output, "\n//// CLUSTER ///");
        push(@output, "\n### CLUSTER STATUS ###");
        push(@output, script_output('PAGER=/usr/bin/cat crm status'));
    }
    record_info('Status', join("\n", @output));
}

=head2 sapcontrol

 $self->sapcontrol(instance_id=>$instance_id,
    webmethod=>$webmethod,
    [additional_args=>$additional_args,
    remote_execution=>$remote_execution]);

Executes sapcontrol webmethod for instance specified in arguments and returns exit code received from command.
Allows remote execution of webmethods between instances, however not all webmethods are possible to execute in that manner.

Sapcontrol return codes:

    RC 0 = webmethod call was successfull
    RC 1 = webmethod call failed
    RC 2 = last webmethod call in progress (processes are starting/stopping)
    RC 3 = all processes GREEN
    RC 4 = all processes GREY (stopped)

B<instance_id> 2 digit instance number

B<webmethod> webmethod name to be executed (Ex: Stop, GetProcessList, ...)

B<additional_args> additional arguments to be appended at the end of command

B<return_output> returns output instead of RC

B<remote_hostname> hostname of the target instance for remote execution. Local execution does not need this.

B<sidadm_password> Password for sidadm user. Only required for remote execution.

=cut

sub sapcontrol {
    my ($self, %args) = @_;
    my $webmethod = $args{webmethod};
    my $instance_id = $args{instance_id};
    my $remote_hostname = $args{remote_hostname};
    my $return_output = $args{return_output};
    my $additional_args = $args{additional_args} // '';
    my $sidadm = $self->get_sidadm();
    my $current_user = script_output_retry_check(cmd => 'whoami', sleep => 2, regex_string => "^root\$|^$sidadm\$");
    my $sidadm_password = $args{sidadm_password};

    croak "Mandatory argument 'webmethod' not specified" unless $webmethod;
    croak "Mandatory argument 'instance_id' not specified" unless $instance_id;
    croak "Function may be executed under root or sidadm.\nCurrent user: $current_user"
      unless grep(/$current_user/, ('root', $sidadm));

    my $cmd = join(' ', 'sapcontrol', '-nr', $instance_id);
    # variables below allow sapcontrol to run under root
    my $sapcontrol_path_root = '/usr/sap/hostctrl/exe';
    my $root_env = "LD_LIBRARY_PATH=$sapcontrol_path_root:\$LD_LIBRARY_PATH";
    $cmd = $current_user eq 'root' ? "$root_env $sapcontrol_path_root/$cmd" : $cmd;

    if ($remote_hostname) {
        croak "Mandatory argument 'sidadm_password' not specified" unless $sidadm_password;
        $cmd = join(' ', $cmd, '-host', $remote_hostname, '-user', $sidadm, $sidadm_password);
    }
    $cmd = join(' ', $cmd,, '-function', $webmethod);
    $cmd = join(' ', $cmd, $additional_args) if $additional_args;

    my $result = $return_output ? script_output($cmd, proceed_on_failure => 1) : script_run($cmd);

    return ($result);
}

=head2 sapcontrol_process_check

 $self->sapcontrol_process_check(expected_state=>expected_state,
    [instance_id=>$instance_id,
    loop_sleep=>$loop_sleep,
    timeout=>$timeout,
    wait_for_state=>$wait_for_state]);

Runs "sapcontrol -nr <INST_NO> -function GetProcessList" via SIDadm and compares RC against expected state.
Croaks if state is not correct.

Expected return codes are:

    RC 0 = webmethod call was successfull
    RC 1 = webmethod call failed (This includes NIECONN_REFUSED status)
    RC 2 = last webmethod call in progress (processes are starting/stopping)
    RC 3 = all processes GREEN
    RC 4 = all processes GREY (stopped)

Method arguments:

B<expected_state> State that is expected (failed, started, stopped)

B<instance_id> Instance number - two digit number

B<loop_sleep> sleep time between checks - only used if 'wait_for_state' is true

B<timeout> timeout for waiting for target state, after which function croaks

B<wait_for_state> If set to true, function will wait for expected state until success or timeout

=cut

sub sapcontrol_process_check {
    my ($self, %args) = @_;
    my $instance_id = $args{instance_id} // get_required_var('INSTANCE_ID');
    my $expected_state = $args{expected_state};
    my $loop_sleep = $args{loop_sleep} // 5;
    my $timeout = $args{timeout} // bmwqemu::scale_timeout(120);
    my $wait_for_state = $args{wait_for_state} // 0;
    my %state_to_rc = (
        failed => '1',    # After stopping service (ServiceStop method) sapcontrol returns RC1
        started => '3',
        stopped => '4'
    );

    croak "Argument 'expected state' undefined" unless defined($expected_state);

    my @allowed_state_values = keys(%state_to_rc);
    $expected_state = lc $expected_state;
    croak "Value '$expected_state' for argument 'expected state' not supported. Allowed values: '@allowed_state_values'"
      unless (grep(/^$expected_state$/, @allowed_state_values));

    my $rc = $self->sapcontrol(instance_id => $instance_id, webmethod => 'GetProcessList');
    my $start_time = time;

    while ($rc ne $state_to_rc{$expected_state}) {
        last unless $wait_for_state;
        $rc = $self->sapcontrol(instance_id => $instance_id, webmethod => 'GetProcessList');
        croak "Timeout while waiting for expected state: $expected_state" if (time - $start_time > $timeout);
        sleep $loop_sleep;
    }

    if ($state_to_rc{$expected_state} ne $rc) {
        $self->sap_show_status_info(netweaver => 1, instance_id => $instance_id);
        croak "Processes are not '$expected_state'";
    }

    return $expected_state;
}

=head2 get_remote_instance_number

 $self->get_instance_number(instance_type=>$instance_type);

Finds instance number from remote instance using sapcontrol "GetSystemInstanceList" webmethod.
Local system instance number is required to execute sapcontrol though.

B<instance_type> Instance type (ASCS, ERS) - this can be expanded to other instances

=cut

sub get_remote_instance_number () {
    my ($self, %args) = @_;
    my $instance_type = $args{instance_type};
    my $local_instance_id = get_required_var('INSTANCE_ID');

    croak "Missing mandatory argument '$instance_type'." unless $instance_type;
    croak "Function is not yet implemented for instance type: $instance_type" unless grep /$instance_type/, ('ASCS', 'ERS');

    # This needs to be expanded for PAS and AAS
    my %instance_type_features = (
        ASCS => 'MESSAGESERVER',
        ERS => 'ENQREP'
    );

    my @instance_data = grep /$instance_type_features{$instance_type}/,
      split('\n', $self->sapcontrol(webmethod => 'GetSystemInstanceList', instance_id => $local_instance_id, return_output => 1));
    my $instance_id = (split(', ', $instance_data[0]))[1];
    $instance_id = sprintf("%02d", $instance_id);

    return ($instance_id);
}

=head2 get_instance_profile_path

 $self->get_instance_profile_path(instance_type=>$instance_type, instance_id=$instance_id);

Returns full instance profile path for specified instance type

B<instance_type> Instance type (ASCS, ERS, PAS, AAS)

B<instance_id> Instance number - two digit number

=cut

sub get_instance_profile_path () {
    my ($self, %args) = @_;
    my $sap_sid = get_required_var('INSTANCE_SID');
    my $instance_type = $args{instance_type};
    my $instance_id = $args{instance_id};
    croak "Missing mandator argument 'instance_id'" unless $instance_id;
    croak "Function is not yet implemented for instance type: $instance_type" unless grep /$instance_type/, ('ASCS', 'ERS');

    my $instance_name = $self->get_nw_instance_name(instance_type => $instance_type, instance_id => $instance_id);
    my $profile_diectory = "/sapmnt/$sap_sid/profile";

    my @profile_match = split('\s', script_output("ls $profile_diectory | grep -E '^$sap_sid\_$instance_name\_[^._]*\$'"));

    my $profile_path = "$profile_diectory/$profile_match[0]";
    croak "Profile '$profile_path' does not exist" if script_run("test -e $profile_path");

    return ($profile_path);
}

=head2 load_ase_env

  $self->load_ase_env

Loads environment variables from ASE installation into the current shell session.

=cut

sub load_ase_env {
    my ($self) = @_;
    return unless $self->ASE_RESPONSE_FILE;

    # SAP ASE installation leaves a SYBASE.sh file with environment variables definitions in
    # the directory where it was installed. The command below will extract the value of the
    # install directory from the response file and prepend it to SYBASE.sh to load those
    # variables
    # Command will look like this:
    # source $(awk -F= '/^USER_INSTALL_DIR/ {print $2}' $HOME/ASE_RESPONSE_FILE.txt)/SYBASE.sh
    assert_script_run q|source $(awk -F= '/^USER_INSTALL_DIR/ {print $2}' $HOME/| . $self->ASE_RESPONSE_FILE . ')/SYBASE.sh';
    assert_script_run 'export LANG=' . get_var('INSTLANG', 'en_US.UTF-8');
}

=head2 upload_ase_logs

  $self->upload_ase_logs

Save and upload to openQA the SAP ASE installation logs. These are typically located in
C</opt/sap/log> and C</opt/sap/$SYBASE_ASE/install> but depend on the response file used
during installation.

=cut

sub upload_ase_logs {
    my ($self) = @_;
    return unless $self->ASE_RESPONSE_FILE;
    $self->load_ase_env;
    save_and_upload_log('tar -zcf ase_logs.tar.gz $SYBASE/log $SYBASE/$SYBASE_ASE/install/*.log', 'ase_logs.tar.gz');
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

    # ASE installation logs, if needed
    $self->upload_ase_logs;

    # HA cluster logs, if needed
    ha_export_logs if get_var('HA_CLUSTER');

    # Execute the common part
    $self->SUPER::post_fail_hook;
}

1;
