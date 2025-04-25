# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for publiccloud tests
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::basetest;
use base 'opensusebasetest';
use testapi;
use publiccloud::azure;
use publiccloud::ec2;
use publiccloud::eks;
use publiccloud::ecr;
use publiccloud::gce;
use publiccloud::gke;
use publiccloud::gcr;
use publiccloud::acr;
use publiccloud::aks;
use publiccloud::openstack;
use publiccloud::noprovider;
use strict;
use warnings;

sub provider_factory {
    my ($self, %args) = @_;
    my $provider;

    die("Provider already initialized") if ($self->{provider});

    $args{provider} //= get_required_var('PUBLIC_CLOUD_PROVIDER');

    if (get_var('PUBLIC_CLOUD_INSTANCE_IP')) {
        $provider = publiccloud::noprovider->new();
    }
    elsif ($args{provider} eq 'EC2') {
        $args{service} //= 'EC2';

        if ($args{service} eq 'ECR') {
            $provider = publiccloud::ecr->new();
        }
        elsif ($args{service} eq 'EKS') {
            $provider = publiccloud::eks->new();
        }
        elsif ($args{service} eq 'EC2') {
            $provider = publiccloud::ec2->new();
        }
        else {
            die('Unknown service given');
        }

    }
    elsif ($args{provider} eq 'AZURE') {
        $args{service} //= 'AVM';
        if ($args{service} eq 'ACR') {
            $provider = publiccloud::acr->new(
                subscription => get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID'),
                username => get_var('PUBLIC_CLOUD_USER', 'azureuser')
            );
        }
        elsif ($args{service} eq 'AKS') {
            $provider = publiccloud::aks->new();
        }
        elsif ($args{service} eq 'AVM') {
            $provider = publiccloud::azure->new();
        } else {
            die('Unknown service given');
        }
    }
    elsif ($args{provider} eq 'GCE') {
        $args{service} //= 'GCE';
        if ($args{service} eq 'GCR') {
            $provider = publiccloud::gcr->new();
        }
        elsif ($args{service} eq 'GKE') {
            $provider = publiccloud::gke->new();
        }
        elsif ($args{service} eq 'GCE') {
            $provider = publiccloud::gce->new();
        }
        else {
            die('Unknown service given');
        }
    }
    elsif ($args{provider} eq 'OPENSTACK') {
        $provider = publiccloud::openstack->new();
    }
    else {
        die('Unknown PUBLIC_CLOUD_PROVIDER given');
    }

    $provider->init();
    $self->{provider} = $provider;
    return $provider;
}

sub cleanup {
    # to be overridden by tests
    return 1;
}

sub is_selinux_enabled {
    my ($self, $instance) = @_;

    # Get kernel command line
    my $cmdline = $instance->ssh_script_output('cat /proc/cmdline', timeout => 0, quiet => 1);

    # SELinux checks
    my $selinux_disabled = $cmdline && $cmdline =~ /selinux=0/;
    my $security_selinux = $cmdline && $cmdline =~ /security=selinux/;
    my $selinux_dir_exists = $instance->ssh_script_run('stat /sys/kernel/security/selinux', timeout => 0, quiet => 1) == 0;

    # SELinux is enabled if not disabled and either directory exists or security=selinux is set
    return !$selinux_disabled && ($selinux_dir_exists || $security_selinux);
}

sub check_selinux_denials {
    my ($self, $instance) = @_;

    # my $cmd = 'command -v ausearch >/dev/null 2>&1 && sudo ausearch -m avc,user_avc,selinux_err,user_selinux_err -ts today --raw || dmesg | grep -i "selinux.*denied"';
    my $cmd = 'command -v ausearch >/dev/null 2>&1 && sudo ausearch -m avc,user_avc,selinux_err,user_selinux_err -ts today --raw || dmesg';

    my $denials = $instance->ssh_script_output(
        $cmd,
        quiet => 1
    );

    record_info('SELinux denials', $denials);

    return $denials;
}

sub save_selinux_denials {
    my ($self, $instance, $denials, $log_file) = @_;

    if ($denials && $denials !~ /^\s*$/) {    # Check for non-empty output
        $instance->ssh_script_run("echo '$denials' > $log_file", timeout => 0, quiet => 1);
        return 1;
    }
    return 0;
}

sub finalize {
    my ($self) = @_;
    die("Cleanup called twice!") if ($self->{finalize_called});
    $self->{finalize_called} = 1;

    # Call cleanup() defined in test modules
    eval { $self->cleanup(); } or record_info('FAILED', "\$self->cleanup() failed -- $@", result => 'fail');

    my $flags = $self->test_flags();

    diag('Public Cloud finalize: $flags->{publiccloud_multi_module}=' . $flags->{publiccloud_multi_module}) if ($flags->{publiccloud_multi_module});
    diag('Public Cloud finalize: $flags->{fatal}=' . $flags->{fatal}) if ($flags->{fatal});
    diag('Public Cloud finalize: $self->{result}=' . $self->{result}) if ($self->{result});
    diag('Public Cloud finalize: $self->{run_args}=' . $self->{run_args}) if ($self->{run_args});
    diag('Public Cloud finalize: $self->{run_args}->{my_provider}=' . $self->{run_args}->{my_provider}) if ($self->{run_args} && $self->{run_args}->{my_provider});
    diag('Public Cloud finalize: $self->{run_args}->{my_instance}=' . $self->{run_args}->{my_instance}) if ($self->{run_args} && $self->{run_args}->{my_instance});

    if ($self->{run_args} && $self->{run_args}->{my_instance} && $self->{result} && $self->{result} eq 'fail') {
        $self->{run_args}->{my_instance}->upload_supportconfig_log();
    }

    # currently we have two cases when cleanup of image will be skipped:
    # 1. Job should have 'PUBLIC_CLOUD_NO_TEARDOWN' variable
    if (get_var('PUBLIC_CLOUD_NO_TEARDOWN')) {
        diag('Public Cloud finalize: The test has PUBLIC_CLOUD_NO_TEARDOWN variable.');
        eval { $self->_upload_logs() } or record_info('FAILED', "\$self->_upload_logs() failed -- $@", result => 'fail');
        upload_asset(script_output('ls ~/.ssh/id* | grep -v pub | head -n1'));
        return;
    }
    diag('Public Cloud finalize: 1st check passed.');

    # 2. Test module needs to have 'publiccloud_multi_module' flag and should not have 'fatal' flag and 'fail' result
    #   * In case the test does not have 'publiccloud_multi_module' flag we don't expect anything else running after it.
    #   * In case the test does have 'publiccloud_multi_module' flag:
    if ($flags->{publiccloud_multi_module}) {
        # * We continue with cleanup if the test is failed and fatal.
        # * We don't continue with cleaup if the test is not failed or not fatal
        #   This is because we expect other test modules requirening the machine running after.
        diag('Public Cloud finalize: Test has `publiccloud_multi_module` flag.');
        diag('Public Cloud finalize: We will end here unless this is `fatal` test finishing with `fail` result.');
        return unless ($flags->{fatal} && $self->{result} && $self->{result} eq 'fail');
    } else {
        diag('Public Cloud finalize: Test does not have `publiccloud_multi_module` flag.');
    }
    diag('Public Cloud finalize: 2nd check passed.');

    eval { $self->_upload_logs(); } or record_info('FAILED', "\$self->_upload_logs() failed -- $@", result => 'fail');

    # We need $self->{run_args} and $self->{run_args}->{my_provider}
    if ($self->{run_args} && $self->{run_args}->{my_provider}) {
        diag('Public Cloud finalize: Ready for provider teardown.');
        # Call the provider teardown
        eval { $self->{run_args}->{my_provider}->teardown() } or record_info('FAILED', "\$self->run_args->my_provider::cleanup() failed -- $@", result => 'fail');
        diag('Public Cloud finalize: The provider teardown finished.');
    } else {
        diag('Public Cloud finalize: Not ready for provider teardown.');
    }
}

sub _upload_logs {
    my ($self) = @_;
    my $ssh_sut_log = '/var/tmp/ssh_sut.log';

    diag('Public Cloud _upload_logs: $self->{run_args}=' . $self->{run_args}) if ($self->{run_args});
    diag('Public Cloud _upload_logs: $self->{run_args}->{my_instance}=' . $self->{run_args}->{my_instance}) if ($self->{run_args}->{my_instance});
    unless ($self->{run_args} && $self->{run_args}->{my_instance}) {
        die('Public Cloud _upload_logs: Either $self->{run_args} or $self->{run_args}->{my_instance} is not available. Maybe the test died before the instance has been created?');
    }

    script_run("sudo chmod a+r " . $ssh_sut_log);
    upload_logs($ssh_sut_log, failok => 1, log_name => $ssh_sut_log . ".txt");

    my @instance_logs = ('/var/log/cloudregister', '/etc/hosts', '/var/log/zypper.log', '/etc/zypp/credentials.d/SCCcredentials');

    $self->{run_args}->{my_instance}->ssh_script_run("echo hello > /tmp/test_change.txt", quiet => 1);
    push @instance_logs, "/tmp/test_change.txt";

    my $selinux_log_file = "/tmp/selinux_denials.txt";
    if ($self->is_selinux_enabled($self->{run_args}->{my_instance})) {
        record_info('SELinux is enabled, checking for denials');
        my $denials = $self->check_selinux_denials($self->{run_args}->{my_instance});
        if ($self->save_selinux_denials($self->{run_args}->{my_instance}, $denials, $selinux_log_file)) {
            push @instance_logs, $selinux_log_file;    # Add to the array for unified handling
        }
    } else {
        record_info('SELinux is disabled, skipping denials check');
    }

    for my $instance_log (@instance_logs) {
        $self->{run_args}->{my_instance}->ssh_script_run("sudo chmod a+r " . $instance_log, timeout => 0, quiet => 1);
        $self->{run_args}->{my_instance}->upload_log($instance_log, failok => 1, log_name => $instance_log . ".txt");
    }
    return 1;
}

sub post_fail_hook {
    my ($self) = @_;

    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        # This is called explicitly to avoid cyclical imports
        sles4sap_publiccloud::sles4sap_cleanup(
            $self,
            cleanup_called => $self->{cleanup_called} // undef,
            network_peering_present => 1,
            ansible_present => 0
        );
        return;
    }

    $self->finalize() unless $self->{finalize_called};
}

sub post_run_hook {
    my ($self) = @_;
    $self->finalize() unless $self->{finalize_called};
}

1;
