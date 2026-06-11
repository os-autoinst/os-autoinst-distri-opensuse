# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Elemental3 helper functions
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

package elemental3;

use Mojo::Base qw(Exporter);
use Mojo::UserAgent;
use Mojo::DOM;
use testapi;

our @EXPORT = qw(
  elemental3_cmd
  get_container_uri
  get_sysext
  get_values
);

=head2 elemental3_cmd

 elemental3_cmd( config_dir => <value>, cmd => <value>, uri => <value>,
                 timeout => <value> );

Execute elemental3 command from container.

=cut

sub elemental3_cmd {
    my (%args) = @_;
    my $runtime = get_required_var('CONTAINER_RUNTIMES');

    croak('Missing arguments!') if (!%args);

    # NOTE: ':z' is needed because of SELinux!
    assert_script_run(
        "$runtime run --rm --volume $args{config_dir}:/config:z $args{uri} $args{cmd}",
        timeout => $args{timeout}
    );
}

=head2 get_container_uri

 get_container_uri( url => <value>, arch => <value>, regex => <value> );

Get URI from registry file.

=cut

sub get_container_uri {
    my (%args) = @_;

    croak('Missing arguments!') if (!%args);

    # Force containers directory
    $args{url} .= "/containers";

    my ($fn, $version, $build) = get_values(
        url => $args{url},
        arch => $args{arch},
        regex => $args{regex}
    );
    my $regex = "pull\\s+\(.*:${version}-${build}\)";

    return ($1) if (script_output("curl -s $args{url}/${fn}") =~ m/${regex}/);
}

=head2 get_sysext

 get_sysext( tmpdir => <value>, timeout => <value> );

Get systemd system extensions from SYSEXT_IMAGES_TO_TEST list and
prepare them to be used by elemental tool.

=cut

sub get_sysext {
    my (%args) = @_;

    croak('Missing arguments!') if (!%args);

    my $overlay_dir = "$args{tmpdir}/overlays";
    my $sysext_dir = "$overlay_dir/etc/extensions";

    record_info('SYSEXT', 'Download and configure systemd system extensions');

    # Create directories
    assert_script_run("mkdir -p $sysext_dir");

    # Get the system extensions
    foreach my $img (split(/,/, get_var('SYSEXT_IMAGES_TO_TEST'))) {
        assert_script_run(
            "elemental3ctl --debug unpack-image --image ${img} --target ${sysext_dir}",
            timeout => $args{timeout}
        );
    }

    # Return systemd-sysexts file name
    return ($overlay_dir);
}

=head2 get_values

 get_values( url => <value>, arch => <value>, regex => <value> );

Get values from filelist webpage  based on provided regex.

=cut

sub get_values {
    my (%args) = @_;

    croak('Missing arguments!') if (!%args);

    # Set file prefix to search
    my $prefix_regex = "\\.$args{arch}-.*\\.tar\\.registry\\.txt\$";

    # If needed add '/' at the end of the URL as without it connection will fail
    $args{url} .= '/' unless (substr($args{url}, -1) eq '/');

    # Open webpage
    my $ua = Mojo::UserAgent->new;
    my $res = $ua->get($args{url})->result;

    if ($res->is_success) {
        # Extract informations from the webpage
        my $dom = Mojo::DOM->new($res->body);

        # Get the first more recent occurence found
        foreach (${dom}->find('a[href]')->reverse->each) {
            my @matches = ($_->{href} =~ /$args{regex}${prefix_regex}/);
            return ($_->text, @matches) if (@matches);
        }
    }
    else {
        die("Cannot parse the result: $res->message");
    }
}

1;
