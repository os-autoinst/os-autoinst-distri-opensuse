# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::sapcontrol;

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use hacluster qw(script_output_retry_check);

our @EXPORT = qw(
  sapcontrol
  sapcontrol_process_check
  sap_show_status_info
  get_remote_instance_number
  get_instance_type
);

=head1 SYNOPSIS

Package containing functions which interact or are related to C<sapcontrol> execution.

=cut

=head2 sapcontrol

 sapcontrol(instance_id=>'00',
    webmethod=>'GetProcessList',
    sidadm=>'pooadm',
    [additional_args=>'someargument',
    remote_execution=>$remote_execution,
    return_output=>'true']);

Executes sapcontrol webmethod for instance specified in arguments and returns exit code received from command.
Allows remote execution of webmethods between instances, however not all webmethods are possible to execute in that manner.
Function expects to be executed from an authorized user (sidadm or root).

Sapcontrol return codes:

    RC 0 = webmethod call was successful
    RC 1 = webmethod call failed
    RC 2 = last webmethod call in progress (processes are starting/stopping)
    RC 3 = all processes GREEN
    RC 4 = all processes GREY (stopped)

=over

=item * B<instance_id> 2 digit instance number

=item * B<webmethod> webmethod name to be executed (Ex: Stop, GetProcessList, ...)

=item * B<additional_args> additional arguments to be appended at the end of command

=item * B<return_output> returns output instead of RC

=item * B<remote_hostname> hostname of the target instance for remote execution. Local execution does not need this.

=item * B<sidadm_password> Password for sidadm user. Only required for remote execution.

=item * B<sidadm> sidadm user. Only required for remote execution.

=back
=cut

sub sapcontrol {
    my (%args) = @_;
    my $current_user = script_output_retry_check(cmd => 'whoami', sleep => 2, regex_string => "^root\$");

    croak "Mandatory argument 'webmethod' not specified" unless $args{webmethod};
    croak "Mandatory argument 'instance_id' not specified" unless $args{instance_id};

    my $cmd = join(' ', 'sapcontrol', '-nr', $args{instance_id});
    # variables below allow sapcontrol to run under root
    my $sapcontrol_path_root = '/usr/sap/hostctrl/exe';
    my $root_env = "LD_LIBRARY_PATH=$sapcontrol_path_root:\$LD_LIBRARY_PATH";
    $cmd = $current_user eq 'root' ? "$root_env $sapcontrol_path_root/$cmd" : $cmd;

    if ($args{remote_hostname}) {
        croak "Mandatory argument 'sidadm' not specified" unless $args{sidadm};
        croak "Mandatory argument 'sidadm_password' not specified" unless $args{sidadm_password};
        $cmd = join(' ', $cmd, '-host', $args{remote_hostname}, '-user', $args{sidadm}, $args{sidadm_password});
    }

    $cmd = join(' ', $cmd, '-function', $args{webmethod});
    $cmd .= " $args{additional_args}" if $args{additional_args};
    my $result = $args{return_output} ? script_output($cmd, proceed_on_failure => 1) : script_run($cmd);

    return ($result);
}


=head2 sap_show_status_info

 sap_show_status_info(cluster=>1, netweaver=>1);

Prints output for standard set of commands to show info about system in various stages of the test for troubleshooting.
It is possible to activate or deactivate various output sections by named args:

=over

=item * B<cluster> - Shows cluster related outputs

=item * B<netweaver> - Shows netweaver related outputs

=back
=cut

sub sap_show_status_info {
    my (%args) = @_;
    my $cluster = $args{cluster};
    my $netweaver = $args{netweaver};
    my $instance_id = defined($netweaver) ? $args{instance_id} : get_required_var('INSTANCE_ID');
    my @output;

    # Netweaver info
    if (defined($netweaver)) {
        push(@output, "\n//// NETWEAVER ///");
        push(@output, "\n### SAPCONTROL PROCESS LIST ###");
        push(@output, sapcontrol(instance_id => $instance_id, webmethod => 'GetProcessList', return_output => 1));
        push(@output, "\n### SAPCONTROL SYSTEM INSTANCE LIST ###");
        push(@output, sapcontrol(instance_id => $instance_id, webmethod => 'GetSystemInstanceList', return_output => 1));
    }

    # Cluster info
    if (defined($cluster)) {
        push(@output, "\n//// CLUSTER ///");
        push(@output, "\n### CLUSTER STATUS ###");
        push(@output, script_output('PAGER=/usr/bin/cat crm status'));
    }
    record_info('Status', join("\n", @output));
}

=head2 sapcontrol_process_check

 sapcontrol_process_check(expected_state=>expected_state,
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

=over

=item * B<expected_state> State that is expected (failed, started, stopped)

=item * B<instance_id> Instance number - two digit number

=item * B<loop_sleep> sleep time between checks - only used if 'wait_for_state' is true

=item * B<timeout> timeout for waiting for target state, after which function croaks

=item * B<wait_for_state> If set to true, function will wait for expected state until success or timeout

=back
=cut

sub sapcontrol_process_check {
    my (%args) = @_;
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

    my $rc = sapcontrol(instance_id => $instance_id, webmethod => 'GetProcessList');
    my $start_time = time;

    while ($rc ne $state_to_rc{$expected_state}) {
        last unless $wait_for_state;
        record_info('Status wait', "Sapcontrol waiting until expected process state: $expected_state");
        $rc = sapcontrol(instance_id => $instance_id, webmethod => 'GetProcessList');
        croak "Timeout while waiting for expected state: $expected_state" if (time - $start_time > $timeout);
        sleep $loop_sleep;
    }

    if ($state_to_rc{$expected_state} ne $rc) {
        sap_show_status_info(netweaver => 1, instance_id => $instance_id);
        croak "Processes are not '$expected_state'";
    }

    return $expected_state;
}

=head2 get_remote_instance_number

 get_instance_number(instance_type=>$instance_type [instance_id=>'00']);

Finds instance number from remote instance using sapcontrol "GetSystemInstanceList" webmethod.
Local system instance number is required to execute sapcontrol though and can be supplied using openQA
setting B<INSTANCE_ID> or argument B<$args{local_instance_id}>.

=over

=item * B<instance_type> Instance type (ASCS, ERS) - this can be expanded to other instances

=item * B<local_instance_id> SAP instance id - defaults to OpenQA setting INSTANCE_ID

=back
=cut

sub get_remote_instance_number {
    my (%args) = @_;
    $args{local_instance_id} //= get_required_var('INSTANCE_ID');

    croak "Missing mandatory argument 'instance_type'." unless $args{instance_type};
    croak "Function is not yet implemented for instance type: $args{instance_type}" unless
      grep /$args{instance_type}/, ('ASCS', 'ERS');

    # This needs to be expanded for PAS and AAS
    my %instance_type_features = (
        ASCS => 'MESSAGESERVER',
        ERS => 'ENQREP'
    );
    my $attempts = 10;
    my @instance_data;
    while ($attempts--) {
        @instance_data = grep /$instance_type_features{$args{instance_type}}/,
          split('\n', sapcontrol(webmethod => 'GetSystemInstanceList', instance_id => $args{local_instance_id}, return_output => 1));
        last if (@instance_data);
        sleep 3;
    }
    die "Timeout: Could not find instance with $args{instance_type} after 30 seconds" unless @instance_data;
    my $instance_id = (split(', ', $instance_data[0]))[1];
    return sprintf("%02d", $instance_id);
}

=head2 get_instance_type

 get_instance_type(local_instance_id=>'00');

=over

=item * B<local_instance_id> SAP instance id - defaults to OpenQA setting INSTANCE_ID

=back
=cut

sub get_instance_type {
    my (%args) = @_;
    croak 'Missing mandatory argument "$args{local_instance_id}"' unless $args{local_instance_id};
    my $sapcontrol_result = sapcontrol(instance_id => $args{local_instance_id},
        webmethod => 'GetInstanceProperties',
        return_output => 'true',    # we need command output instead of RC
        additional_args => '| grep INSTANCE_NAME'    # Filter only important line. There is a lot of garbage output.
    );

    my @cmd_result = split(', ', $sapcontrol_result);
    $cmd_result[2] =~ s/[0-9].//,

      return ($cmd_result[2]);
}
