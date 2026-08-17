# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper routines for running img-proof framework
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::img_proof;

use strict;
use warnings;
use Exporter qw(import);

use testapi;
use Data::Dumper;
use Carp qw(croak);
use publiccloud::utils qw(is_gce is_ec2 is_hardened);

our @EXPORT_OK = qw(
  run_img_proof
);

=encoding UTF-8

=head1 NAME

publiccloud::img_proof - Routines to run img-proof and parse its output

=head1 SYNOPSIS

    use publiccloud::img_proof qw(run_img_proof);

    my $results = run_img_proof($provider, instance => $instance, tests => $tests);

=head1 DESCRIPTION

Helper module for interacting with the C<img-proof> tool during public cloud image testing.
=cut

# Internal helper function to parse img-proof CLI output
sub parse_img_proof_output {
    my ($output) = @_;
    croak('Output parameter is undefined') unless defined $output;
    my $ret = {};

    for my $line (split(/\r?\n/, $output)) {
        if ($line =~ m/^ID of instance: (\S+)$/) {
            $ret->{instance_id} = $1;
        }
        elsif ($line =~ m/^Terminating instance (\S+)$/) {
            $ret->{instance_id} = $1;
        }
        elsif ($line =~ m/^IP of instance: (\S+)$/) {
            $ret->{ip} = $1;
        }
        elsif ($line =~ m/^Created log file (\S+)$/) {
            $ret->{logfile} = $1;
        }
        elsif ($line =~ m/^Created results file (\S+)$/) {
            $ret->{results} = $1;
        }
        elsif ($line =~ m/tests=(\d+)\|pass=(\d+)\|skip=(\d+)\|fail=(\d+)\|error=(\d+)/) {
            $ret->{tests} = $1;
            $ret->{pass} = $2;
            $ret->{skip} = $3;
            $ret->{fail} = $4;
            $ret->{error} = $5;
        }
        $ret->{output} .= $line . "\n";
    }

    for my $k (qw(ip logfile results tests pass skip fail error)) {
        return unless (exists($ret->{$k}));
    }
    return $ret;
}

=head2 run_img_proof

    run_img_proof(
        $provider,
        instance => $instance,
        [provider => 'ec2',]
        [tests => 'test_security',]
        [distro => 'sles',]
        [timeout => 7200,]
        [results_dir => 'img_proof_results',]
        [user => 'ec2-user',]
        [key_name => 'my_key',]
        [credentials_file => 'aws_creds.json',]
        [running_instance_id => 'i-12345',]
        [exclude => 'test_a, test_b',]
        [beta => 0]
    );

Calls the C<img-proof> CLI tool and retrieves a hash reference containing the test results.

Updates C<$instance->public_ip> with the instance IP extracted from the command output.
Returns a hash reference containing the parsed results
(with C<instance_id> and C<ip> deleted from the returned hash).

=over

=item B<provider> - Public cloud provider instance object (first positional parameter)

=item B<instance> - Mandatory public cloud instance object

=item B<provider> - Cloud provider name string (e.g., 'azure', 'ec2', 'gce')

=item B<tests> - Comma-separated or space-separated list of test cases to run (default: '')

=item B<distro> - Target Linux distribution name passed to C<--distro> (default: 'sles')

=item B<timeout> - Execution timeout in seconds (default: 7200)

=item B<results_dir> - Directory path for img-proof test results passed to C<--results-dir> (default: 'img_proof_results')

=item B<user> - SSH username used for accessing the target instance (C<-u>)

=item B<key_name> - Name or file path of the SSH key passed to C<--ssh-key-name>

=item B<credentials_file> - Path to service account or cloud credentials file passed to C<--service-account-file>

=item B<running_instance_id> - Override instance ID if different from C<$instance->instance_id>

=item B<exclude> - Comma-separated list of test cases to exclude from execution (C<--exclude>)

=item B<beta> - Enable beta features flag in img-proof (default: 0)

=back

=cut

sub run_img_proof {
    my $provider = shift;
    my %args = @_;
    die('Must provide an instance object') if (!$args{instance});

    $args{tests} //= '';
    $args{timeout} //= 60 * 120;
    $args{results_dir} //= 'img_proof_results';
    $args{distro} //= 'sles';
    $args{tests} =~ s/,/ /g;

    my $exclude = $args{exclude} // '';
    my $beta = $args{beta} // 0;

    my $version = script_output('img-proof --version', 300);
    record_info("img-proof version", $version);

    my $cmd = 'img-proof --no-color test ' . $args{provider};
    $cmd .= ' --debug ';
    $cmd .= "--distro " . $args{distro} . " ";
    if (is_gce()) {
        $cmd .= '--region "' . $provider->provider_client->region . '-' . $provider->provider_client->availability_zone . '" ';
    }
    else {
        $cmd .= '--region "' . $provider->provider_client->region . '" ';
    }
    $cmd .= '--results-dir "' . $args{results_dir} . '" ';
    $cmd .= '--no-cleanup ';
    $cmd .= '--collect-vm-info ';
    $cmd .= '--service-account-file "' . $args{credentials_file} . '" ' if ($args{credentials_file});
    #TODO: this if is just dirty hack which needs to be replaced with something more sane ASAP.
    $cmd .= '--access-key-id $AWS_ACCESS_KEY_ID --secret-access-key $AWS_SECRET_ACCESS_KEY ' if (is_ec2());
    $cmd .= '--ssh-key-name $(realpath ' . $args{key_name} . ') ' if ($args{key_name});
    $cmd .= '-u ' . $args{user} . ' ' if ($args{user});
    $cmd .= '--ssh-private-key-file $(realpath ' . $provider->ssh_key . ') ';
    $cmd .= '--running-instance-id "' . ($args{running_instance_id} // $args{instance}->instance_id) . '" ';
    $cmd .= "--beta " if ($beta);
    if ($exclude) {
        # Split exclusion tests by command and add them individually
        for my $excl (split ',', $exclude) {
            $excl =~ s/^\s+|\s+$//g;    # trim spaces
            $cmd .= "--exclude $excl ";
        }
    }

    # Tell img-proof to generate SCAP report on hardened images
    if (is_hardened) {
        my $scap_report = get_var("SCAP_REPORT", "skip");
        $cmd = "SCAP_REPORT=$scap_report " . $cmd;
    }

    $cmd .= $args{tests};
    record_info("img-proof cmd", $cmd);

    my $output = script_output($cmd . ' 2>&1', $args{timeout}, proceed_on_failure => 1);
    record_info("img-proof output", $output);
    my $img_proof = parse_img_proof_output($output);
    record_info("img-proof results", Dumper($img_proof));
    die($output) unless (defined($img_proof));

    $args{instance}->public_ip($img_proof->{ip});
    delete($img_proof->{instance_id});
    delete($img_proof->{ip});

    return $img_proof;
}

1;
