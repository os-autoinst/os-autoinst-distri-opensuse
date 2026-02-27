# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: container-suseconnect test for multiple container runtimes
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(get_os_release is_sle);
use registration qw(detect_suseconnect_path);
use utils;
use qam;

my $runtime;
my $runtime_name;
my $container_name;

sub container_image_tag {
    my ($self, $args) = @_;
    my ($running_version, $sp, $host_os) = get_os_release;

    if (is_sle('<=15-SP5')) {
        return "registry.suse.com/suse/ltss/sle${running_version}.${sp}/sle15:${running_version}.${sp}";
    } elsif (is_sle('>=15-SP6')) {
        return "registry.suse.com/bci/bci-base:${running_version}.${sp}";
    } else {
        die("Unsupported SLE version for container-suseconnect test");
    }
}

sub run {
    my ($self, $args) = @_;

    $runtime_name = $args->{runtime};

    select_serial_terminal;

    assert_script_run("curl " . data_url('containers/container-suseconnect/add-incidents-repos.sh') . " -o ./add-incidents-repos.sh");
    assert_script_run("chmod +x ./add-incidents-repos.sh");

    $runtime = $self->containers_factory($runtime_name);
    my $base_image = $self->container_image_tag();
    assert_script_run("$runtime_name pull $base_image");

    my $scc_credentials_path = "/etc/zypp/credentials.d/SCCcredentials";

    my @repos = get_test_repos();
    my $incident_repos_urls = join(',', @repos);

    if ($incident_repos_urls) {
        assert_script_run("echo '$incident_repos_urls' > ./incident_repos_urls.txt");
    }

    $container_name = "suseconnect-test-$runtime_name";

    my @run_cmd = ("$runtime_name run -d");
    push @run_cmd, ("--name $container_name",
        "-e ADDITIONAL_MODULES=sle-module-desktop-applications,sle-module-development-tools",
        "-v $scc_credentials_path:/etc/zypp/credentials.d/SCCcredentials");
    if (get_var('SCC_URL')) {
        my $suseconnect_path = detect_suseconnect_path();
        push @run_cmd, ("-v $suseconnect_path:/etc/SUSEConnect");
    }
    push @run_cmd, ("$base_image sleep infinity");

    assert_script_run(join(' ', @run_cmd));

    if ($incident_repos_urls) {
        assert_script_run("$runtime_name cp ./add-incidents-repos.sh $container_name:/usr/local/bin/add-incidents-repos.sh");
        assert_script_run("$runtime_name exec $container_name chmod +x /usr/local/bin/add-incidents-repos.sh");

        assert_script_run("$runtime_name cp ./incident_repos_urls.txt $container_name:/tmp/incident_repos_urls.txt");
        assert_script_run(
            "$runtime_name exec $container_name /usr/local/bin/add-incidents-repos.sh /tmp/incident_repos_urls.txt"
        );
        assert_script_run(
            "$runtime_name exec $container_name zypper -nv --gpg-auto-import-keys up"
        );
    }

    assert_script_run(
        "$runtime_name exec $container_name " .
          "zypper -n --gpg-auto-import-keys in gvim"
    );

    validate_script_output(
        "$runtime_name exec $container_name container-suseconnect lp",
        sub { m/All available products:/ }
    );
    validate_script_output(
        "$runtime_name exec $container_name container-suseconnect lm",
        sub { m/All available modules:/ }
    );
    validate_script_output(
        "$runtime_name exec $container_name rpm -qa",
        sub { m/gvim/ }
    );

}

sub cleanup {
    my ($self) = @_;
    script_run("$runtime_name rm -f $container_name") if $container_name;
    script_run("rm -f ./add-incidents-repos.sh");
    script_run("rm -f ./incident_repos_urls.txt");
    $runtime->cleanup_system_host();
}

sub post_run_hook { shift->cleanup() }
sub post_fail_hook { shift->cleanup() }

1;
