# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package caasp;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use mmapi;
use version_utils 'is_caasp';
use power_action_utils 'power_action';

our @EXPORT = qw(
  microos_reboot microos_login send_alt
  handle_simple_pw script_run0 script_assert0
  get_delayed update_scheduled
  pause_until unpause);

# Shorcuts for gui / textmode (optional) oci installer
# Version 3.0 (default)
my %keys = (
    kb_layout    => ['e', 'y'],
    kb_test      => ['g'],
    password     => ['w', 'a'],
    role         => ['s'],
    partitioning => ['p'],
    booting      => ['b'],
    network      => ['n'],
    kdump        => ['k'],
    install      => ['i'],
    ntpserver    => ['t'],
    next         => ['n'],
    no           => ['n'],
    ok           => ['o'],
);

# Send alt shortcut by name
sub send_alt {
    my $key = shift;
    my $txt = check_var('VIDEOMODE', 'text');

    if (is_caasp '4.0+') {
        $keys{kb_layout} = ['k', 'k'];
        $keys{kb_test}   = ['y', 'e'];
        $keys{password}  = ['a', 'a'];
    }
    send_key "alt-$keys{$key}[$txt]";
}

# Weak password warning should be displayed only once - bsc#1025835
sub handle_simple_pw {
    return if get_var 'SIMPLE_PW_CONFIRMED';

    assert_screen 'inst-userpasswdtoosimple';
    send_key 'alt-y';
    set_var 'SIMPLE_PW_CONFIRMED', 1;
}

# Assert login prompt and login as root
sub microos_login {
    assert_screen 'linux-login-casp', 150;

    # Workers installed using autoyast have no password - bsc#1030876
    return if get_var('AUTOYAST');

    if (is_caasp 'VMX') {
        # FreeRDP is not sending 'Ctrl' as part of 'Ctrl-Alt-Fx', 'Alt-Fx' is fine though.
        my $key = check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'alt-f2' : 'ctrl-alt-f2';
        # First attempts to select tty2 are ignored - bsc#1035968
        send_key_until_needlematch 'tty2-selected', $key, 10, 30;
    }

    select_console 'root-console';

    # Don't match linux-login-casp twice
    assert_script_run 'clear';
}

# Process reboot with an option to trigger it
sub microos_reboot {
    my $trigger = shift // 0;
    power_action('reboot', observe => !$trigger, keepconsole => 1);

    # No grub bootloader on xen-pv
    # grub2 needle is unreliable (stalls during timeout) - poo#28648
    assert_screen [qw(grub2 linux-login-casp)], 150;
    send_key('ret') if match_has_tag('grub2');

    microos_login;
}

# Get current job id
sub get_current_job {
    my $name = get_required_var('NAME');
    return int(substr($name, 0, 8));
}

sub get_controller_job {
    return get_current_job if check_var('STACK_ROLE', 'controller');

    my $parents = get_parents();
    for my $job_id (@$parents) {
        if (get_job_info($job_id)->{settings}->{STACK_ROLE} eq 'controller') {
            return $job_id;
        }
    }
}

# Get list of jobs in cluster
sub get_cluster_jobs {
    return @{get_job_info(get_controller_job)->{children}->{Parallel}};
}

sub get_admin_job {
    return get_current_job if check_var('STACK_ROLE', 'admin');

    my @cluster_jobs = get_cluster_jobs;
    for my $job_id (@cluster_jobs) {
        if (get_job_info($job_id)->{settings}->{STACK_ROLE} eq 'admin') {
            return $job_id;
        }
    }
}

# Return job id of delayed node when role filter is set
# Return number of delayed jobs without filter
# get_delayed [master|worker]
sub get_delayed {
    my $role = shift;

    my $count = 0;
    my @jobs  = get_cluster_jobs;
    for my $job_id (@jobs) {
        if (my $drole = get_job_info($job_id)->{settings}->{DELAYED}) {
            if ($role) {
                return $job_id if $role eq $drole;
            } else {
                $count++;
            }
        }
    }
    return $count;
}


# Return update repository without parameters
# Optional filter for update type [qam|fake|test|migration]
sub update_scheduled {
    my $type = shift;

    # Don't update MicroOS tests
    return 0 unless get_var('STACK_ROLE');
    # Don't update staging
    return 0 if get_var('FLAVOR') =~ /Staging-?-DVD/;

    # Find update repository on controller node
    my $repo = get_job_info(get_controller_job)->{settings}->{INCIDENT_REPO};

    # Filter for update types
    return $repo unless $type;
    return $repo =~ /Maintenance/ if $type eq 'qam';
    return $repo =~ /FakeUpdate/i if $type eq 'fake';
    return $repo =~ /TestUpdate/i if $type eq 'test';
    return $repo =~ /Migration/i  if $type eq 'migration';
    die "Unrecognized type: '$type'";
}

# Wrapper returning PIPESTATUS[0]
sub script_run0 {
    my ($cmd, $wait) = @_;
    return script_run($cmd . '; ( exit ${PIPESTATUS[0]} )', $wait);
}

# Wrapper checking PIPESTATUS[0]
sub script_assert0 {
    my ($cmd, $wait) = @_;
    assert_script_run($cmd . '; ( exit ${PIPESTATUS[0]} )', $wait);
}

# All events ordered by execution
my %events = (
    support_server_ready => 'Wait for dhcp, dns, ntp, ..',
    VELUM_STARTED        => 'Wait until velum starts to login there from controller',
    VELUM_CONFIGURED     => 'Velum has to be configured before autoyast installations start',
    NODES_ACCEPTED       => 'Wait until salt-keys are accepted to start booting delayed nodes',
    AUTOYAST_PW_SET      => 'Wait on autoyast nodes until passord is set from admin with salt',
    CNTRL_FINISHED       => 'Wait on CaaSP nodes until controller finishes testing',
);

# CaaSP specific unpausing
sub unpause {
    my $event = shift;

    # Handle cluster failure on controller node
    if (uc($event) eq 'ALL') {
        foreach my $e (keys %events) {
            # We need passwords mostly on failure
            next if $e eq 'AUTOYAST_PW_SET';
            lockapi::mutex_create $e;
        }
    }
    else {
        lockapi::mutex_create $event;
    }
}

# CaaSP specific pausing
sub pause_until {
    my $event = shift;

    # Make sure mutex is documented here
    die "Event '$event' is unknown" unless exists $events{$event};

    # Mutexes created by child jobs (not controller)
    my $owner;
    $owner = get_admin_job if $event eq 'VELUM_STARTED';
    $owner = get_admin_job if $event eq 'AUTOYAST_PW_SET';

    lockapi::mutex_wait($event, $owner, $events{$event});
}

1;
