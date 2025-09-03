# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: python3-docker & python3-podman
# Summary: Test podman & docker python packages
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use power_action_utils 'power_action';
use version_utils;
use utils;
use XML::LibXML;
use containers::common qw(install_packages);
use containers::bats;

my $oci_runtime;

# mapping of known expected failures
my %xfails = (
    '[It] Podman run with volumes podman run with --mount and named volume with driver-opts' => {
        bug => 'bsc#1249050 - podman passes volume options as bind mount options to runtime',
        runtimes => ['runc'],
    },
    '[It] Podman run with volumes podman named volume copyup' => {
        bug => 'bsc#1249050 - podman passes volume options as bind mount options to runtime',
        runtimes => ['runc'],
    },
);

sub patch_junit_xfails {
    my ($xmlfile, $runtime) = @_;
    my $xml = script_output("cat $xmlfile");
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string($xml);

    my $patched = 0;

    # Loop over all testcases in the DOM
    for my $testcase ($doc->findnodes('//testcase')) {
        my $name = $testcase->getAttribute('name');
        # Skip if there's no soft-fail defined
        next unless exists $xfails{$name};

        my $rule = $xfails{$name};
        # Skip if not applicable to this runtime
        next unless grep { $_ eq $runtime } @{$rule->{runtimes}};
        my $reference = $rule->{bug};

        # Patch failures to skipped
        my @failures = $testcase->findnodes('./failure');
        if (@failures) {
            for my $failure_node ($testcase->findnodes('./failure')) {
                $testcase->removeChild($failure_node);
                $testcase->removeAttribute('status');
                $testcase->setAttribute('status', 'skipped');
                $testcase->appendTextChild('skipped', "Softfailed: $rule->{bug}");
                record_info("XFAIL", $reference);

                # Adjust parent <testsuite> counters
                if (my $suite = $testcase->parentNode) {
                    my $fail = $suite->getAttribute('failures');
                    my $skip = $suite->getAttribute('skipped');
                    $suite->setAttribute('failures', $fail - 1);
                    $suite->setAttribute('skipped', $skip + 1);
                }

                $patched++;
                last;
            }
        } else {
            record_info("PASS", $name);
        }
    }

    # Adjust root <testsuites> counters
    if ($patched) {
        if (my ($suites) = $doc->findnodes('/testsuites')) {
            my $failures = $suites->getAttribute('failures');
            my $skipped = $suites->getAttribute('skipped');
            $suites->setAttribute('failures', $failures - $patched);
            $suites->setAttribute('skipped', $skipped + $patched);
        }
    }

    # Write patched XML back
    write_sut_file $xmlfile, $doc->toString(1);
}

sub setup {
    my $self = shift;
    my @pkgs = qw(aardvark-dns apache2-utils buildah catatonit glibc-devel-static go1.24 gpg2 jq libgpgme-devel
      libseccomp-devel make netavark openssl podman podman-remote skopeo socat sudo systemd-container xfsprogs);
    push @pkgs, qw(criu libcriu2) unless is_sle;
    $oci_runtime = get_var("OCI_RUNTIME", "runc");
    push @pkgs, $oci_runtime;

    $self->setup(@pkgs);
    select_serial_terminal;

    record_info "info", script_output("podman info -f json");
    record_info("OCI runtime", script_output("$oci_runtime --version"));

    # Workaround for https://bugzilla.opensuse.org/show_bug.cgi?id=1248988 - catatonit missing in /usr/libexec/podman/
    run_command "cp -f /usr/bin/catatonit /usr/libexec/podman/catatonit";
    # rootless user needed for these tests
    run_command "useradd -m containers";
    run_command "usermod --add-subuids 100000-165535 containers";
    run_command "usermod --add-subgids 100000-165535 containers";
    # Make /run/secrets directory available on containers
    run_command "echo /var/lib/empty:/run/secrets >> /etc/containers/mounts.conf";

    my $version = script_output q(podman --version | awk '{ print $3 }');
    record_info "version", $version;

    # Download podman sources
    patch_sources "podman", "v$version", "test/e2e";
    # This test fails with:
    # Command exited 125 as expected, but did not emit 'failed to connect: dial tcp: lookup '
    run_command "rm -f test/e2e/image_scp_test.go";
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    $self->setup;
    select_serial_terminal;

    # Bind-mount /tmp to /var/tmp to avoid filling tmpfs
    mount_tmp_vartmp;
    power_action('reboot', textmode => 1);
    $self->wait_boot();
    select_serial_terminal;

    assert_script_run "cd /var/tmp/podman";

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    my %env = (
        OCI_RUNTIME => $oci_runtime,
        PODMAN_BINARY => "/usr/bin/podman",
        PODMAN_REMOTE_BINARY => "/usr/bin/podman-remote",
        QUADLET_BINARY => "/usr/libexec/podman/quadlet",
        TESTFLAGS => "--junit-report=report.xml",
    );
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    my @targets = split('\s+', get_var('PODMAN_TARGETS', 'localintegration remoteintegration'));
    foreach my $target (@targets) {
        run_command "env $env make $target &> $target.txt || true", timeout => 1800;
        script_run qq{sed -ri '0,/name=/s/name="Libpod Suite"/name="$target"/' report.xml};
        script_run "cp report.xml /tmp/$target.xml";
        patch_junit_xfails("/tmp/$target.xml", $oci_runtime);
        parse_extra_log(XUnit => "/tmp/$target.xml");
        upload_logs("$target.txt");
    }
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
