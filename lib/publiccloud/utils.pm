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
use version_utils qw(is_sle is_sle_micro is_public_cloud get_version_id is_transactional);
use transactional qw(check_reboot_changes trup_call process_reboot);
use registration;
use maintenance_smelt qw(is_embargo_update);

# Indicating if the openQA port has been already allowed via SELinux policies
my $openqa_port_allowed = 0;

our @EXPORT = qw(
  deregister_addon
  define_secret_variable
  get_credentials
  validate_repo
  is_byos
  is_ondemand
  is_ec2
  is_azure
  is_gce
  is_container_host
  is_hardened
  registercloudguest
  register_addon
  register_openstack
  register_addons_in_pc
  gcloud_install
  prepare_ssh_tunnel
  kill_packagekit
  allow_openqa_port_selinux
  fully_update_system
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
        if ($addon =~ /nvidia/i) {
            (my $version = get_version_id(dst_machine => $remote)) =~ s/^(\d+).*/$1/m;
            ssh_add_suseconnect_product($remote, get_addon_fullname($addon), $version, $arch, '', $timeout, $retries, $delay);
        } else {
            ssh_add_suseconnect_product($remote, get_addon_fullname($addon), undef, $arch, '', $timeout, $retries, $delay);
        }
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
    $instance->ssh_script_retry(cmd => "sudo zypper -n --gpg-auto-import-keys ref", timeout => 300, retry => 3, delay => 120);
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

# Validation for update repos
sub validate_repo {
    my ($maintrepo) = @_;
    if ($maintrepo =~ /\/(PTF|Maintenance):\/(\d+)/g) {
        my ($incident, $type) = ($2, $1);
        die "We did not detect incident number for URL \"$maintrepo\". We detected \"$incident\"" unless $incident =~ /\d+/;
        if (is_embargo_update($incident, $type)) {
            record_info("EMBARGOED", "The repository \"$maintrepo\" belongs to embargoed incident number \"$incident\"");
            script_run("echo 'The repository \"$maintrepo\" belongs to embargoed incident number \"$incident\"'");
            return 0;
        }
        return 1;
    }
    die "Unexpected URL \"$maintrepo\"";
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

sub is_hardened() {
    return is_public_cloud && get_var('FLAVOR') =~ 'Hardened';
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

    # WARNING:  Python 3.6.x is no longer officially supported by the Google Cloud CLI
    # and may not function correctly. Please use Python version 3.8 and up.
    my @pkgs = qw(curl tar gzip);
    my $py_version = get_var('PYTHON_VERSION', '3.11');
    my $py_pkg_version = $py_version =~ s/\.//gr;
    push @pkgs, 'python' . $py_pkg_version;
    add_suseconnect_product(get_addon_fullname('python3')) if is_sle('15-SP6+');

    zypper_call("in @pkgs", $timeout);

    assert_script_run("export CLOUDSDK_PYTHON=/usr/bin/python$py_version");
    assert_script_run("export CLOUDSDK_CORE_DISABLE_PROMPTS=1");
    assert_script_run("curl $url | bash", $timeout);
    assert_script_run("echo . /root/$dir/completion.bash.inc >> ~/.bashrc");
    assert_script_run("echo . /root/$dir/path.bash.inc >> ~/.bashrc");
    assert_script_run("source ~/.bashrc");

    record_info('GCE', script_output('gcloud version'));
}

sub prepare_ssh_tunnel {
    my $instance = shift;

    # configure ssh client
    my $ssh_config_url = data_url('publiccloud/ssh_config');
    assert_script_run("curl $ssh_config_url -o ~/.ssh/config");

    # Create the ssh alias
    assert_script_run(sprintf(q(echo -e 'Host sut\n  Hostname %s' >> ~/.ssh/config), $instance->public_ip));

    # Copy SSH settings also for normal user
    assert_script_run("install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    assert_script_run("install -o $testapi::username -g users -m 0600 ~/.ssh/* /home/$testapi::username/.ssh/");

    # Skip setting root password for img_proof, because it expects the root password to NOT be set
    $instance->ssh_assert_script_run(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd root));

    # Permit root passwordless login over SSH
    $instance->ssh_assert_script_run('sudo cat /etc/ssh/sshd_config');
    $instance->ssh_assert_script_run('sudo sed -i "s/PermitRootLogin no/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config');
    $instance->ssh_assert_script_run('sudo sed -iE "/^AllowTcpForwarding/c\AllowTcpForwarding yes" /etc/ssh/sshd_config') if (is_hardened());
    $instance->ssh_assert_script_run('sudo systemctl reload sshd');

    # Copy SSH settings for remote root
    $instance->ssh_assert_script_run('sudo install -o root -g root -m 0700 -dD /root/.ssh');
    $instance->ssh_assert_script_run(sprintf("sudo install -o root -g root -m 0644 /home/%s/.ssh/authorized_keys /root/.ssh/", $instance->{username}));

    # Create remote user and set him a password
    my $path = (is_sle('>15') && is_sle('<15-SP3')) ? '/usr/sbin/' : '';
    $instance->ssh_assert_script_run("test -d /home/$testapi::username || sudo ${path}useradd -m $testapi::username");
    $instance->ssh_assert_script_run(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd $testapi::username));

    # Copy SSH settings for remote user
    $instance->ssh_assert_script_run("sudo install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    $instance->ssh_assert_script_run("sudo install -o $testapi::username -g users -m 0644 ~/.ssh/authorized_keys /home/$testapi::username/.ssh/");

    # Create log file for ssh tunnel
    my $ssh_sut = '/var/tmp/ssh_sut.log';
    assert_script_run "touch $ssh_sut; chmod 777 $ssh_sut";
}

sub kill_packagekit {
    my ($instance) = @_;
    # sle-micro do not have pkcon installed
    return if (is_sle_micro);
    my $ret = $instance->ssh_script_run(cmd => "sudo pkcon quit", timeout => 120);
    if ($ret) {
        # Older versions of systemd don't support "disable --now"
        $instance->ssh_script_run(cmd => "sudo systemctl stop packagekitd");
        $instance->ssh_script_run(cmd => "sudo systemctl disable packagekitd");
        $instance->ssh_script_run(cmd => "sudo systemctl mask packagekitd");
    }
}


sub allow_openqa_port_selinux {
    # not needed to perform multiple times, also semanage would fail.
    return if ($openqa_port_allowed);

    # Additional packages required for semanage
    my $pkgs = 'policycoreutils-python-utils';
    if (is_transactional) {
        trup_call("pkg install $pkgs");
        check_reboot_changes;
    } else {
        zypper_call("in $pkgs");
    }
    # allow ssh tunnel port (to openQA)
    my $upload_port = get_required_var('QEMUPORT') + 1;
    assert_script_run("semanage port -a -t ssh_port_t -p tcp $upload_port");
    process_reboot(trigger => 1) if (is_transactional);
    $openqa_port_allowed = 1;
}


=head2 fully_update_system

 ssh_fully_patch_system($host);

Connect to the remote host C<$host> using ssh and update the system by
running C<zypper update> twice. The first run will update the package manager,
the second run will update the system.
Transactional systems like SLE micro shall use C<transactional_update patch> and reboot. 

=cut

sub fully_update_system {
    my ($instance) = @_;
    my $ret;
    my $cmd_time = time();
    if (is_transactional)
    {
        my $cmd = "sudo transactional-update -n up";
        my $cmd_name = "transactional update";
        # first run, possible update of packager
        my $ret = $instance->ssh_script_run(cmd => $cmd, timeout => 1500);
        $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
        record_info($cmd_name, 'The command ' . $cmd_name . ' took ' . (time() - $cmd_time) . ' seconds.');
        die "$cmd_name failed with $ret" if ($ret != 0 && $ret != 102 && $ret != 103);
        # second run, full system update
        $cmd_time = time();
        $ret = $instance->ssh_script_run(cmd => $cmd, timeout => 6000);
        $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
        record_info($cmd_name, 'The second command ' . $cmd_name . ' took ' . (time() - $cmd_time) . ' seconds.');
        die "$cmd_name failed with $ret" if ($ret != 0 && $ret != 102);
    } else {
        ssh_fully_patch_system($instance->username . '@' . $instance->public_ip);
        $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    }
}

1;
