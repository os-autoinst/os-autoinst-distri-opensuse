# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Public cloud utilities
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

package publiccloud::utils;

use base Exporter;
use Exporter;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::JSON 'encode_json';

use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_public_cloud);
use registration;

our @EXPORT = qw(
  deregister_addon
  define_secret_variable
  get_credentials
  is_byos
  is_ondemand
  is_ec2
  is_azure
  is_gce
  is_container_host
  registercloudguest
  register_addon
  register_openstack
  register_addons_in_pc
  gcloud_install
);

# Get the current UTC timestamp as YYYY/mm/dd HH:MM:SS
sub utc_timestamp {
    my @weekday = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = gmtime(time);
    $year = $year + 1900;
    return sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year, $mon, $day, $hour, $min, $sec);
}

sub register_addon {
    my ($remote, $addon) = @_;
    my $arch = get_var('PUBLIC_CLOUD_ARCH') // "x86_64";
    $arch = "aarch64" if ($arch eq "arm64");
    my $timestamp = utc_timestamp();
    record_info($addon, "Going to register '$addon' addon\nUTC: $timestamp");
    my $cmd_time = time();
    # ssh_add_suseconnect_product($remote, $name, $version, $arch, $params, $timeout, $retries, $delay)
    my ($timeout, $retries, $delay) = (300, 3, 120);
    if ($addon =~ /ltss/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), '${VERSION_ID}', $arch, "-r " . get_required_var('SCC_REGCODE_LTSS'), $timeout, $retries, $delay);
    } elsif (is_sle('<15') && $addon =~ /tcm|wsm|contm|asmm|pcm/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), '`echo ${VERSION} | cut -d- -f1`', $arch, '', $timeout, $retries, $delay);
    } elsif (is_sle('<15') && $addon =~ /sdk|we/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), '${VERSION_ID}', $arch, '', $timeout, $retries, $delay);
    } else {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), undef, $arch, '', $timeout, $retries, $delay);
    }
    record_info('SUSEConnect time', 'The command SUSEConnect -r ' . get_addon_fullname($addon) . ' took ' . (time() - $cmd_time) . ' seconds.');
}

sub deregister_addon {
    my ($remote, $addon) = @_;
    my $arch = get_var('PUBLIC_CLOUD_ARCH', 'x86_64');
    $arch = "aarch64" if ($arch eq "arm64");
    my $timestamp = utc_timestamp();
    record_info($addon, "Going to deregister '$addon' addon\nUTC: $timestamp");
    my $cmd_time = time();
    my ($timeout, $retries, $delay) = (300, 3, 120);
    if ($addon =~ /ltss/) {
        # ssh_remove_suseconnect_product($remote, $name, $version, $arch, $params, $timeout, $retries, $delay)
        ssh_remove_suseconnect_product($remote, get_addon_fullname($addon), '${VERSION_ID}', $arch, "-r " . get_required_var('SCC_REGCODE_LTSS'), $timeout, $retries, $delay);
    } elsif (is_sle('<15') && $addon =~ /tcm|wsm|contm|asmm|pcm/) {
        ssh_remove_suseconnect_product($remote, get_addon_fullname($addon), '`echo ${VERSION} | cut -d- -f1`', $arch, '', $timeout, $retries, $delay);
    } elsif (is_sle('<15') && $addon =~ /sdk|we/) {
        ssh_remove_suseconnect_product($remote, get_addon_fullname($addon), '${VERSION_ID}', $arch, '', $timeout, $retries, $delay);
    } else {
        ssh_remove_suseconnect_product($remote, get_addon_fullname($addon), undef, $arch, '', $timeout, $retries, $delay);
    }
    record_info('SUSEConnect time', 'The command SUSEConnect -d ' . get_addon_fullname($addon) . ' took ' . (time() - $cmd_time) . ' seconds.');
}

sub registercloudguest {
    my ($instance) = @_;
    my $regcode = get_required_var('SCC_REGCODE');
    my $path = is_sle('>15') && is_sle('<15-SP3') ? '/usr/sbin/' : '';
    my $suseconnect = $path . get_var("PUBLIC_CLOUD_SCC_ENDPOINT", "registercloudguest");
    my $cmd_time = time();
    # Check what version of registercloudguest binary we use
    $instance->ssh_script_run(cmd => "rpm -qa cloud-regionsrv-client");
    $instance->ssh_script_retry(cmd => "sudo $suseconnect -r $regcode", timeout => 420, retry => 3, delay => 120);
    record_info('registeration time', 'The registration took ' . (time() - $cmd_time) . ' seconds.');
}

sub register_addons_in_pc {
    my ($instance) = @_;
    my @addons = split(/,/, get_var('SCC_ADDONS', ''));
    my $remote = $instance->username . '@' . $instance->public_ip;
    for my $addon (@addons) {
        next if ($addon =~ /^\s+$/);
        register_addon($remote, $addon);
    }
    record_info('repos (lr)', $instance->run_ssh_command(cmd => "sudo zypper lr"));
    record_info('repos (ls)', $instance->run_ssh_command(cmd => "sudo zypper ls"));
}

sub register_openstack {
    my $instance = shift;

    my $regcode = get_required_var 'SCC_REGCODE';
    my $fake_scc = get_var 'SCC_URL', '';

    my $cmd = "sudo SUSEConnect -r $regcode";
    $cmd .= " --url $fake_scc" if $fake_scc;
    $instance->ssh_assert_script_run(cmd => $cmd, timeout => 700, retry => 5);
}

# Check if we are a BYOS test run
sub is_byos() {
    return is_public_cloud && get_var('FLAVOR') =~ 'BYOS';
}

# Check if we are a OnDemand test run
sub is_ondemand() {
    # By convention OnDemand images are not marked explicitly.
    # Check all the other flavors, and if they don't match, it must be on_demand.
    return is_public_cloud && (!is_byos());    # When introducing new flavors, add checks here accordingly.
}

# Check if we are on an AWS test run
sub is_ec2() {
    return is_public_cloud && check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
}

# Check if we are on an Azure test run
sub is_azure() {
    return is_public_cloud && check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
}

# Check if we are on an GCP test run
sub is_gce() {
    return is_public_cloud && check_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
}

sub is_container_host() {
    return is_public_cloud && get_var('FLAVOR') =~ 'CHOST';
}

sub define_secret_variable {
    my ($var_name, $var_value) = @_;
    script_run("set -a");
    script_run("read -sp \"enter value: \" $var_name", 0);
    type_password($var_value . "\n");
    script_run("set +a");
}

# Get credentials from the Public Cloud micro service, which requires user
# and password. The resulting json will be stored in a file.
sub get_credentials {
    my ($url_sufix, $output_json) = @_;
    my $base_url = get_required_var('PUBLIC_CLOUD_CREDENTIALS_URL');
    my $namespace = get_required_var('PUBLIC_CLOUD_NAMESPACE');
    my $user = get_required_var('_SECRET_PUBLIC_CLOUD_CREDENTIALS_USER');
    my $pwd = get_required_var('_SECRET_PUBLIC_CLOUD_CREDENTIALS_PWD');
    my $url = $base_url . '/' . $namespace . '/' . $url_sufix;

    my $url_auth = Mojo::URL->new($url)->userinfo("$user:$pwd");
    my $ua = Mojo::UserAgent->new;
    $ua->insecure(1);
    my $tx = $ua->get($url_auth);
    die("Fetching CSP credentials failed: " . $tx->result->message) unless eval { $tx->result->is_success };
    my $data_structure = $tx->res->json;
    if ($output_json) {
        # Note: tmp files are job-specific files in the pool directory on the worker and get cleaned up after job execution
        save_tmp_file('creds.json', encode_json($data_structure));
        assert_script_run('curl ' . autoinst_url . '/files/creds.json -o ' . $output_json);
    }
    return $data_structure;
}

=head2 gcloud_install
    gcloud_install($url, $dir, $timeout)

This function is used to install the gcloud CLI 
for the GKE Google Cloud.

From $url we get the full package and install it
in $dir local folder as a subdir of /root.
Defaults are available for a simple call without parameters:
    gcloud_install()

=cut

sub gcloud_install {
    my %args = @_;
    my $url = $args{url} || 'sdk.cloud.google.com';
    my $dir = $args{dir} || 'google-cloud-sdk';
    my $timeout = $args{timeout} || 700;

    zypper_call("in curl tar gzip", $timeout);

    assert_script_run("export CLOUDSDK_CORE_DISABLE_PROMPTS=1");
    assert_script_run("curl $url | bash", $timeout);
    assert_script_run("echo . /root/$dir/completion.bash.inc >> ~/.bashrc");
    assert_script_run("echo . /root/$dir/path.bash.inc >> ~/.bashrc");
    assert_script_run("source ~/.bashrc");

    record_info('GCE', script_output('gcloud version'));
}

1;
