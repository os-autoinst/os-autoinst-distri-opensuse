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
use Data::Dumper;
use Storable qw(dclone);
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

sub finalize {
    my ($self) = @_;
    die("finalize called twice!") if ($self->{finalize_called});
    $self->{finalize_called} = 1;

    # Call cleanup() defined in test modules
    eval { $self->cleanup(); } or record_info('FAILED', "\$self->cleanup() failed -- $@", result => 'fail');

    my $flags = $self->test_flags();

    diag('Public Cloud finalize: $flags->{publiccloud_multi_module}=' . $flags->{publiccloud_multi_module}) if ($flags->{publiccloud_multi_module});
    diag('Public Cloud finalize: $flags->{fatal}=' . $flags->{fatal}) if ($flags->{fatal});
    diag('Public Cloud finalize: $self->{result}=' . $self->{result}) if ($self->{result});
    diag('Public Cloud finalize: $self->{run_args}=' . $self->{run_args}) if ($self->{run_args});

    if ($self->{run_args}) {
        if ($self->{run_args}->{my_instance}) {
            my $dumpable_instance = Storable::dclone($self->{run_args}->{my_instance});
            $dumpable_instance->{provider}->{provider_client}->{credentials_file_content} = '******';
            diag('Public Cloud finalize: $self->{run_args}->{my_instance}=' . Dumper($dumpable_instance));
        }
        if ($self->{run_args}->{my_provider}) {
            my $dumpable_provider = Storable::dclone($self->{run_args}->{my_provider});
            $dumpable_provider->{provider_client}->{credentials_file_content} = '******';
            diag('Public Cloud finalize: $self->{run_args}->{my_provider}=' . Dumper($dumpable_provider));
        }
    }

    # currently we have two cases when teardown of instance will be skipped:
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
        # * We continue with teardown if the test is failed and fatal.
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
        eval { $self->{run_args}->{my_provider}->upload_boot_diagnostics() } or record_info('FAILED', "\$self->{run_args}->{my_provider}->upload_boot_diagnostics() failed -- $@");
        eval { $self->{run_args}->{my_provider}->teardown() } or record_info('FAILED', "\$self->{run_args}->{my_provider}::teardown() failed -- $@", result => 'fail');
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
    for my $instance_log (@instance_logs) {
        next if ($self->{run_args}->{my_instance}->ssh_script_run("test -f " . $instance_log, quiet => 1));
        $self->{run_args}->{my_instance}->ssh_script_run("sudo chmod a+r " . $instance_log, timeout => 0, quiet => 1);
        $self->{run_args}->{my_instance}->upload_log($instance_log, failok => 1, log_name => $instance_log . ".txt");
    }

    $self->{run_args}->{my_instance}->upload_supportconfig_log();

    return 1;
}

sub post_fail_hook {
    my ($self) = @_;

    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        # This is called explicitly to avoid cyclical imports
        sles4sap_publiccloud::sles4sap_cleanup(
            $self,
            cleanup_called => $self->{cleanup_called} // undef,
            ansible_present => 0
        );
        return;
    }

    $self->finalize() unless $self->{finalize_called};
}

sub post_run_hook {
    my ($self) = @_;
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        # SAP/HA Public Cloud test case uses its own cleanup procedure (for example: loadtest qesap_cleanup.pm)
        return;
    }
    $self->finalize() unless $self->{finalize_called};
}

1;
