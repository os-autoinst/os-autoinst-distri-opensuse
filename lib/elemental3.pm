# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Elemental3 helper functions
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

package elemental3;

use strict;
use warnings;
use Mojo::Base qw(Exporter);
use Mojo::UserAgent;
use Mojo::DOM;
use testapi;
use Carp qw(croak);
use utils qw(script_retry script_output_retry validate_script_output_retry);

our @EXPORT = qw(
  elemental3_cmd
  get_container_uri
  get_sysext
  get_values
  kubectl_cmd
  wait_k8s_state
  wait_kubectl_cmd
  wait_nodes_ready
  wait_on_cmd
  wait_script_output
);

=head2 elemental3_cmd

 elemental3_cmd( config_dir => <value>, cmd => <value>, uri => <value>,
                 timeout => <value> );

Execute elemental3 command from container.

=cut

sub elemental3_cmd {
    my (%args) = @_;
    my $ca_vol = '';
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $runtime = get_required_var('CONTAINER_RUNTIMES');

    croak('Missing required argument!') unless (%args);

    # Check if we need to mount the local CA in the container
    # This could be needed when we have to test updates on released versions,
    # as internal SUSE CAs are not installed in that case!
    unless (get_var('TOTEST_PATH', '') =~ /Main:/) {
        # NOTE: ':z' is needed because of SELinux!
        $ca_vol = '--volume /var/lib/ca-certificates:/var/lib/ca-certificates:ro,z --volume /etc/ssl:/etc/ssl:ro,z';
    }

    # NOTE: ':z' is needed because of SELinux!
    assert_script_run(
        "$runtime run --rm ${ca_vol} --volume $args{config_dir}:/config:z $args{uri} $args{cmd}",
        timeout => $timeout
    );
}

=head2 get_container_uri

 get_container_uri( url => <value>, arch => <value>, regex => <value> );

Get URI from registry file.

=cut

sub get_container_uri {
    my (%args) = @_;

    croak('Missing required argument!') unless (%args);

    # Force containers directory
    $args{url} .= "/containers";

    my ($fn, $version, $build) = get_values(
        url => $args{url},
        arch => $args{arch},
        regex => $args{regex}
    );
    my $regex = "pull\\s+\(.*:${version}-${build}\)";

    # Open webpage
    my $res = Mojo::UserAgent->new->get("$args{url}/${fn}")->result;
    if ($res->is_success) {
        # Return the found URI
        return ($1) if ($res->body =~ m/${regex}/);
    }
    else {
        croak("Cannot get '$args{url}/${fn}': " . $res->message);
    }

    # If we reach this point, no match was found
    croak("Could not find any URI matching the regex in '$args{url}'");
}

=head2 get_sysext

 get_sysext( tmpdir => <value>, timeout => <value> );

Get systemd system extensions from SYSEXT_IMAGES_TO_TEST list and
prepare them to be used by elemental tool.

=cut

sub get_sysext {
    my (%args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);

    croak('Missing required argument!') unless (%args);

    my $overlay_dir = "$args{tmpdir}/overlays";
    my $sysext_dir = "$overlay_dir/etc/extensions";

    record_info('SYSEXT', 'Download and configure systemd system extensions');

    # Create directories
    assert_script_run("mkdir -p $sysext_dir");

    # Get the system extensions
    foreach my $img (split(/,/, get_var('SYSEXT_IMAGES_TO_TEST', ''))) {
        assert_script_run(
            "elemental3ctl --debug unpack-image --image ${img} --target ${sysext_dir}",
            timeout => $timeout
        );
    }

    # Return systemd-sysexts file name
    return ($overlay_dir);
}

=head2 get_values

 get_values( url => <value>, arch => <value>, regex => <value> );

Get values from filelist webpage based on provided regex.

=cut

sub get_values {
    my (%args) = @_;

    croak('Missing required argument!') unless (%args);

    # Set file prefix to search
    my $prefix_regex = "\\.$args{arch}-.*\\.tar\\.registry\\.txt\$";

    # If needed add '/' at the end of the URL as without it connection will fail
    $args{url} .= '/' unless $args{url} =~ m{/\z};

    # Open webpage
    my $res = Mojo::UserAgent->new->get($args{url})->result;
    if ($res->is_success) {
        # Extract information from the webpage
        my $dom = Mojo::DOM->new($res->body);

        # Get the first more recent occurence found
        foreach (${dom}->find('a[href]')->reverse->each) {
            my @matches = ($_->{href} =~ /$args{regex}${prefix_regex}/);
            return ($_->text, @matches) if (@matches);
        }
    }
    else {
        croak("Cannot get '$args{url}': " . $res->message);
    }

    # If we reach this point, no match was found
    croak("Could not find any file matching the regex in '$args{url}'");
}

=head2 kubectl_cmd

 kubectl_cmd( cmd => <value> [, timeout => <value> ] );

Checks for up to B<$timeout> seconds whether kubectl command is executed.
Returns command status if command is successful or die on timeout.

=cut

sub kubectl_cmd {
    my (%args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $retry = 10;
    my $delay = $timeout / $retry;

    croak('Missing required argument <cmd>!') unless $args{cmd};

    return script_retry(
        "kubectl $args{cmd}",
        delay => $delay,
        retry => $retry,
        fail_message => "kubectl command '$args{cmd}' failed!"
    );
}

=head2 wait_k8s_state

 wait_k8s_state( regex => <value> [, timeout => <value> ] );

Checks for up to B<$timeout> seconds whether K8s cluster is running.
Returns 0 if cluster is running or croaks on timeout.

=cut

sub wait_k8s_state {
    my (%args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $retry = 10;
    my $delay = $timeout / $retry;

    croak('A regex should be defined!') unless (defined $args{regex} && $args{regex} ne '');

    my $chk_cmd = 'kubectl get pod -A 2>&1';
    return script_retry(
        "$chk_cmd | grep -Eivq '$args{regex}'",
        delay => $delay,
        expect => 1,
        retry => $retry,
        fail_message => "K8s cluster did not reach the required state within $timeout seconds!"
    );
}

=head2 wait_kubectl_cmd

 wait_kubectl_cmd( [ timeout => <value> ] );

Wait for kubectl command to be available.

=cut

sub wait_kubectl_cmd {
    my (%args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $retry = 10;
    my $delay = $timeout / $retry;

    return script_retry(
        'which kubectl',
        delay => $delay,
        retry => $retry,
        fail_message => "kubectl command did not appear within $timeout seconds!"
    );
}

=head2 wait_nodes_ready

 wait_nodes_ready( [ timeout => <value> ] );

Wait for up to B<$timeout> seconds until K8s nodes are ready.
Returns 0 if nodes are ready or die on timeout.

=cut

sub wait_nodes_ready {
    my (%args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $retry = 10;
    my $delay = $timeout / $retry;

    # Use a negative lookahead to ensure 'NotReady' is not in the output.
    # The /s modifier allows '.' to match newline characters.
    return validate_script_output_retry(
        'kubectl get nodes 2>&1',
        qr/^(?!.*\bNotReady\b)/s,
        delay => $delay,
        retry => $retry,
        fail_message => "K8s nodes not ready within $timeout seconds!"
    );
}

=head2 wait_on_cmd

 wait_on_cmd( cmd => <value> [, timeout => <value> ] );

Checks for up to B<$timeout> seconds whether command is executed.
Returns command status if command is successful or die on timeout.

=cut

sub wait_on_cmd {
    my (%args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $retry = 10;
    my $delay = $timeout / $retry;

    croak('Missing required argument <cmd>!') unless $args{cmd};

    return script_retry(
        $args{cmd},
        delay => $delay,
        retry => $retry,
        fail_message => "Command '$args{cmd}' did not appear within $timeout seconds!"
    );
}

=head2 wait_script_output

 wait_script_output( cmd => <value> [, timeout => <value> ] );

Checks for up to B<$timeout> seconds whether command is executed.
Returns command output if successful or die on timeout.

=cut

sub wait_script_output {
    my (%args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $retry = 10;
    my $delay = $timeout / $retry;

    croak('Missing required argument <cmd>!') unless $args{cmd};

    return script_output_retry(
        cmd => $args{cmd},
        delay => $delay,
        retry => $retry,
        fail_message => "Command '$args{cmd}' timed out after $timeout seconds!"
    );
}

1;
