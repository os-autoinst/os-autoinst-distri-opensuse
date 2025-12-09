# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for publiccloud tests
#
# Maintainer: QE-C team <qa-c@suse.de>

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
use publiccloud::utils qw(is_publiccloud_sles4sap);
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
    my $start_text = 'Public Cloud finalize: ';
    diag($start_text . 'start:');

    # Call cleanup() defined in test modules
    eval { $self->cleanup(); }
      or record_info('FAILED cleanup', $start_text . "Failed the cleanup (ref.:) $self->cleanup() failed --\n $@", result => 'fail');

    my $flags = $self->test_flags();
    my $upload;

    diag($start_text . '$flags->{publiccloud_multi_module}=' . $flags->{publiccloud_multi_module}) if ($flags->{publiccloud_multi_module});
    diag($start_text . '$flags->{fatal}=' . $flags->{fatal}) if ($flags->{fatal});
    diag($start_text . '$self->{result}=' . $self->{result}) if ($self->{result});

    if ($self->{run_args}) {
        diag($start_text . 'checks starting in run_args structure (ref.:$self->{run_args}):');
        # check Provider
        if ($self->{run_args}->{my_provider}) {
            my $dumpable_provider = Storable::dclone($self->{run_args}->{my_provider});
            $dumpable_provider->{provider_client}->{credentials_file_content} = '******';
            diag($start_text . '$self->{run_args}->{my_provider}= ' . Dumper($dumpable_provider));
        } else {
            my $local_text = $start_text . 'Provider is undefined or incomplete (ref.: $self->{run_args}->{my_provider})';
            record_info('UNDEF. provider', $local_text, result => 'fail');
            diag($local_text);
        }
        # check Instance
        if ($self->{run_args}->{my_instance}) {
            my $dumpable_instance = Storable::dclone($self->{run_args}->{my_instance});
            $dumpable_instance->{provider}->{provider_client}->{credentials_file_content} = '******';
            diag($start_text . '$self->{run_args}->{my_instance}=' . Dumper($dumpable_instance));
            $upload = 1;
        } else {
            my $local_text = $start_text . 'Instance is undefined or incomplete (ref.: $self->{run_args}->{my_instance})';
            record_info('UNDEF. instance', $local_text, result => 'fail');
            diag($local_text);
        }
    } else {
        $start_text .= 'running arguments undefined (ref.: $self->{run_args}).';
        record_info('FAILED finalize', $start_text, result => 'fail');
        diag($start_text . 'Probably early errors/faults.');
    }
    # currently we have two cases when teardown of instance will be skipped:
    # 1. Job should have 'PUBLIC_CLOUD_NO_TEARDOWN' variable
    if (get_var('PUBLIC_CLOUD_NO_TEARDOWN')) {
        my $ret;
        diag($start_text . 'The test has PUBLIC_CLOUD_NO_TEARDOWN variable.');
        upload_asset(script_output('ls ~/.ssh/id* | grep -v pub | head -n1'));
        if ($upload) {
            $ret = $self->_upload_logs();
            record_info('FAILED upload_logs', $start_text . "Failed _upload_logs no teardown (ref.: \$self->_upload_logs) --\n $@")
              unless (defined($ret));
        }
        return $ret;
    }
    diag($start_text . '1st check passed.');

    # 2. Test module needs to have 'publiccloud_multi_module' flag and should not have 'fatal' flag and 'fail' result
    #   * In case the test does not have 'publiccloud_multi_module' flag we don't expect anything else running after it.
    #   * In case the test does have 'publiccloud_multi_module' flag:
    if ($flags->{publiccloud_multi_module}) {
        # * We continue with teardown if the test is failed and fatal.
        # * We don't continue with cleaup if the test is not failed or not fatal
        #   This is because we expect other test modules requirening the machine running after.
        diag($start_text . 'Test has `publiccloud_multi_module` flag.');
        diag($start_text . 'We will end here unless this is `fatal` test finishing with `fail` result.');
        return unless ($flags->{fatal} && $self->{result} && $self->{result} eq 'fail');
    } else {
        diag($start_text . 'Test does not have `publiccloud_multi_module` flag.');
    }
    diag($start_text . '2nd check passed.');
    if ($upload) {
        my $ret = $self->_upload_logs();
        record_info('FAILED upload_logs', $start_text . "Failed _upload_logs (ref.: \$self->_upload_logs) --\n $@")
          unless (defined($ret));
    }
    # We need $self->{run_args} and $self->{run_args}->{my_provider}
    if ($self->{run_args}->{my_provider}) {
        diag($start_text . 'Ready for provider teardown.');
        # Call the provider teardown
        eval { $self->{run_args}->{my_provider}->upload_boot_diagnostics() }
          or record_info('FAILED upload_boot_diagnostics', $start_text . "Failed provider upload_boot_diagnostics (ref.: \$self->{run_args}->{my_provider}->upload_boot_diagnostics) --\n $@");
        eval { $self->{run_args}->{my_provider}->teardown() }
          or record_info('FAILED teardown', $start_text . "Failed provider teardown (ref.: \$self->{run_args}->{my_provider}::teardown) --\n $@");
        diag($start_text . 'The provider teardown finished.');
    } else {
        diag($start_text . 'Not ready for provider teardown.');
        return;
    }
    # finalize completed
    return 1;
}

sub _upload_logs {
    my ($self) = @_;
    my $ssh_sut_log = '/var/tmp/ssh_sut.log';
    my $start_text = 'Public Cloud _upload_logs: ';

    diag($start_text . 'start:') if ($self->{run_args});
    script_run("sudo chmod a+r " . $ssh_sut_log);
    upload_logs($ssh_sut_log, failok => 1, log_name => $ssh_sut_log . ".txt");

    if ($self->{run_args} && $self->{run_args}->{my_instance}) {
        diag($start_text . 'Valid instance $self->{run_args}->{my_instance};');
        my @instance_logs = ('/var/log/cloudregister', '/etc/hosts', '/var/log/zypper.log', '/etc/zypp/credentials.d/SCCcredentials');
        for my $instance_log (@instance_logs) {
            $self->{run_args}->{my_instance}->ssh_script_run("sudo chmod a+r " . $instance_log, quiet => 1, ignore_timeout_failure => 1);
            $self->{run_args}->{my_instance}->upload_log($instance_log, failok => 1, log_name => $instance_log . ".txt");
        }
        # collect supportconfig logs, only when test failed:
        $self->{run_args}->{my_instance}->upload_supportconfig_log() if ($self->{result} && $self->{result} eq 'fail');
    } else {
        diag($start_text . 'instance unavailable or run_args undefined (ref.: $self->{run_args}->{my_instance}). Possible that the test died before the instance was created.');
        return;
    }
    # log uploaded ok
    return 1;
}

sub post_fail_hook {
    my ($self) = @_;

    if (is_publiccloud_sles4sap()) {
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
    if (is_publiccloud_sles4sap()) {
        # SAP/HA Public Cloud test case uses its own cleanup procedure (for example: loadtest qesap_cleanup.pm)
        return;
    }
    $self->finalize() unless $self->{finalize_called};
}

1;
