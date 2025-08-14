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
use Carp qw(croak);

use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_public_cloud get_version_id is_transactional is_openstack is_sle_micro check_version);
use transactional qw(reboot_on_changes trup_call process_reboot);
use registration qw(get_addon_fullname add_suseconnect_product);
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
  is_cloudinit_supported
  registercloudguest
  register_addon
  register_openstack
  register_addons_in_pc
  gcloud_install
  get_ssh_private_key_path
  permit_root_login
  prepare_ssh_tunnel
  kill_packagekit
  allow_openqa_port_selinux
  ssh_update_transactional_system
  create_script_file
  install_in_venv
  venv_activate
  get_python_exec
);

# Check if we are a BYOS test run
sub is_byos() {
    return is_public_cloud && get_var('FLAVOR') =~ /byos/i;
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

sub is_cloudinit_supported {
    return ((is_azure || is_ec2) && !is_sle_micro);
}

# Get the current UTC timestamp as YYYY/mm/dd HH:MM:SS
sub utc_timestamp {
    my @weekday = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = gmtime(time);
    $year = $year + 1900;
    return sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year, $mon, $day, $hour, $min, $sec);
}


=head2 ssh_add_suseconnect_product

    ssh_add_suseconnect_product($remote, $name, [program => $program, [version => $version, [arch => $arch, [params => $params, [timeout => $timeout, [retries => $retries, [delay => $delay]]]]]]]);

Register addon in the SUT
=cut

sub ssh_add_suseconnect_product {
    my ($remote, $name, %args) = @_;
    if ($args{program} eq 'registercloudguest') {
        script_retry(sprintf("ssh %s sudo %s %s", $remote, $args{program}, $args{params}), delay => $args{delay}, retry => $args{retries}, timeout => $args{timeout});
    } else {
        script_retry(sprintf("ssh %s sudo %s -p %s/%s/%s %s", $remote, $args{program}, $name, $args{version}, $args{arch}, $args{params}), delay => $args{delay}, retry => $args{retries}, timeout => $args{timeout});
    }
}

sub register_addon {
    my ($remote, $addon) = @_;

    my $arch = get_var('PUBLIC_CLOUD_ARCH') // "x86_64";
    $arch = "aarch64" if ($arch eq "arm64");
    my $timestamp = utc_timestamp();
    record_info($addon, "Going to register '$addon' addon\nUTC: $timestamp");
    my $cmd_time = time();
    my ($timeout, $retries, $delay) = (300, 3, 120);
    my $program = get_var("PUBLIC_CLOUD_SCC_ENDPOINT", "registercloudguest");

    assert_script_run "sftp $remote:/etc/os-release /tmp/os-release";
    assert_script_run 'source /tmp/os-release';

    if ($addon =~ /ltss/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), program => $program, version => '${VERSION_ID}', arch => $arch, params => "-r " . get_required_var('SCC_REGCODE_LTSS'), timeout => $timeout, retries => $retries, delay => $delay);
    } elsif (is_ondemand) {
        record_info($addon, 'This is on demand image, we will not register this addon.');
        return;
    } elsif (is_sle('<15') && $addon =~ /tcm|wsm|contm|asmm|pcm/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), program => 'SUSEConnect', version => '`echo ${VERSION} | cut -d- -f1`', arch => $arch, params => '', timeout => $timeout, retries => $retries, delay => $delay);
    } elsif (is_sle('<15') && $addon =~ /sdk|we/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), program => 'SUSEConnect', version => '${VERSION_ID}', arch => $arch, params => '', timeout => $timeout, retries => $retries, delay => $delay);
    } else {
        if ($addon =~ /nvidia/i) {
            (my $version = get_version_id(dst_machine => $remote)) =~ s/^(\d+).*/$1/m;
            ssh_add_suseconnect_product($remote, get_addon_fullname($addon), program => 'SUSEConnect', version => $version, arch => $arch, params => '', timeout => $timeout, retries => $retries, delay => $delay);
        } else {
            ssh_add_suseconnect_product($remote, get_addon_fullname($addon), program => 'SUSEConnect', version => '${VERSION_ID}', arch => $arch, params => '', timeout => $timeout, retries => $retries, delay => $delay);
        }
    }
    record_info('SUSEConnect time', 'The command SUSEConnect -r ' . get_addon_fullname($addon) . ' took ' . (time() - $cmd_time) . ' seconds.');
}

=head2 ssh_remove_suseconnect_product

    ssh_remove_suseconnect_product($name, [$version, [$arch, [$params]]]);

Deregister addon in SUT
=cut

sub ssh_remove_suseconnect_product {
    my ($remote, $name, $version, $arch, $params) = @_;
    assert_script_run "sftp $remote:/etc/os-release /tmp/os-release";
    assert_script_run 'source /tmp/os-release';
    script_retry(sprintf("ssh $remote sudo SUSEConnect -d -p $name/$version/$arch $params", $remote, $name, $version, $arch, $params), retry => 5, delay => 60, timeout => 180);
}

sub deregister_addon {
    my ($remote, $addon) = @_;

    my $arch = get_var('PUBLIC_CLOUD_ARCH', 'x86_64');
    $arch = "aarch64" if ($arch eq "arm64");
    my $timestamp = utc_timestamp();
    record_info($addon, "Going to deregister '$addon' addon\nUTC: $timestamp");
    my $cmd_time = time();
    my ($timeout, $retries, $delay) = (300, 3, 120);

    assert_script_run "sftp $remote:/etc/os-release /tmp/os-release";
    assert_script_run 'source /tmp/os-release';

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
    my $suseconnect = get_var("PUBLIC_CLOUD_SCC_ENDPOINT", "registercloudguest");

    # Check what version of registercloudguest binary we use, chost images have none pre-installed
    my $version = $instance->ssh_script_output(cmd => 'rpm -q --queryformat "%{VERSION}\n" cloud-regionsrv-client', proceed_on_failure => 1);
    if ($version =~ /cloud-regionsrv-client is not installed/) {
        die 'cloud-regionsrv-client should not be installed' if !is_container_host;
    }

    my $cmd_time = time();
    $instance->ssh_script_retry(cmd => "sudo $suseconnect -r $regcode", timeout => 420, retry => 3, delay => 120);
    record_info('registration time', 'The registration took ' . (time() - $cmd_time) . ' seconds.');

    # If the SSH master socket is active, exit it, so the next SSH command will (re)login
    if (script_run('ssh -O check ' . $instance->username . '@' . $instance->public_ip) == 0) {
        assert_script_run('ssh -O exit ' . $instance->username . '@' . $instance->public_ip);
    }
}

sub register_addons_in_pc {
    my ($instance) = @_;
    my @addons = split(/,/, get_var('SCC_ADDONS', ''));
    my $remote = $instance->username . '@' . $instance->public_ip;
    # Workaround for bsc#1245220
    my $env = is_sle("=15-SP3") ? "ZYPP_CURL2=1" : "";
    my $cmd = "sudo $env zypper -n --gpg-auto-import-keys ref";
    $instance->ssh_script_retry(cmd => $cmd, timeout => 300, retry => 3, delay => 120);
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
    if (is_sle_micro('>=6.0')) {
        record_info("Product Increments", "Can't validate repository");
        return 1;
    }
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

=head2 get_credentials
    get_credentials(url_suffix => 'some_csp.json'[, namespace => 'some_name', output_json => './local_credentials.json'])

Get credentials from the Public Cloud micro service, which requires user
and password. The resulting json will be optionally stored in a file.
This function also get input from these variables:
 - PUBLIC_CLOUD_CREDENTIALS_URL
 - _SECRET_PUBLIC_CLOUD_CREDENTIALS_USER
 - _SECRET_PUBLIC_CLOUD_CREDENTIALS_PWD
 
=over

=item B<url_suffix> - last part of the micro service url

=item B<output_json> - (optional) save the credential to json file with provided filename.

=item B<namespace> - (optional) credential namespace on the micro service. If not provided read from PUBLIC_CLOUD_NAMESPACE

=back
=cut

sub get_credentials {
    my (%args) = @_;
    croak 'Missing mandatory url_suffix argument' unless $args{url_suffix};
    $args{namespace} //= get_required_var('PUBLIC_CLOUD_NAMESPACE');

    my $base_url = get_required_var('PUBLIC_CLOUD_CREDENTIALS_URL');
    my $user = get_required_var('_SECRET_PUBLIC_CLOUD_CREDENTIALS_USER');
    my $pwd = get_required_var('_SECRET_PUBLIC_CLOUD_CREDENTIALS_PWD');
    my $url = $base_url . '/' . $args{namespace} . '/' . $args{url_suffix};

    my $url_auth = Mojo::URL->new($url)->userinfo("$user:$pwd");
    my $ua = Mojo::UserAgent->new;
    $ua->insecure(1);
    my $tx = $ua->get($url_auth);
    my $res = $tx->result;
    die("Fetching CSP credentials failed: " . $res->message) unless ($res->is_success);
    my $data_structure = $res->json;
    if ($args{output_json}) {
        # Note: tmp files are job-specific files in the pool directory on the worker and get cleaned up after job execution
        save_tmp_file('creds.json', encode_json($data_structure));
        assert_script_run('curl ' . autoinst_url . '/files/creds.json -o ' . $args{output_json});
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

sub get_ssh_private_key_path {
    # Paramiko needs to be updated for ed25519 https://stackoverflow.com/a/60791079
    return (is_azure() || is_openstack() || get_var('PUBLIC_CLOUD_LTP')) ? "~/.ssh/id_rsa" : '~/.ssh/id_ed25519';
}

sub permit_root_login {
    my ($instance) = @_;

    # Skip setting root password for img_proof, because it expects the root password to NOT be set
    $instance->ssh_assert_script_run(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd root)) unless (get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS'));

    # Copy SSH settings for remote root
    $instance->ssh_assert_script_run('sudo install -o root -g root -m 0700 -dD /root/.ssh');
    $instance->ssh_assert_script_run(sprintf("sudo install -o root -g root -m 0644 /home/%s/.ssh/authorized_keys /root/.ssh/", $instance->{username}));
}

sub prepare_ssh_tunnel {
    my ($instance) = @_;

    # Create the ssh alias
    assert_script_run(sprintf(q(echo -e 'Host sut\n  Hostname %s' >> ~/.ssh/config), $instance->public_ip));

    # Create remote user and set him a password
    my $path = (is_sle('>15') && is_sle('<15-SP3')) ? '/usr/sbin/' : '';
    $instance->ssh_assert_script_run("test -d /home/$testapi::username || sudo ${path}useradd -m $testapi::username");
    $instance->ssh_assert_script_run(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd $testapi::username));

    # Copy SSH settings for remote user
    $instance->ssh_assert_script_run("sudo install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    $instance->ssh_assert_script_run("sudo install -o $testapi::username -g users -m 0644 ~/.ssh/authorized_keys /home/$testapi::username/.ssh/");

    # Copy SSH settings also for local user
    assert_script_run("install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    assert_script_run("install -o $testapi::username -g users -m 0600 ~/.ssh/* /home/$testapi::username/.ssh/");

    # Permit root passwordless login and TCP forwarding over SSH
    if (is_sle('>=16')) {
        $instance->ssh_assert_script_run(q(echo "PermitRootLogin without-password" | sudo tee /etc/ssh/sshd_config.d/10-root-login.conf));
        $instance->ssh_assert_script_run(q(echo "AllowTcpForwarding yes" | sudo tee /etc/ssh/sshd_config.d/10-tcp-forwarding.conf)) if (is_hardened());
    } else {
        $instance->ssh_assert_script_run('sudo sed -i "s/PermitRootLogin no/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config');
        $instance->ssh_assert_script_run('sudo sed -i "/^AllowTcpForwarding/c\AllowTcpForwarding yes" /etc/ssh/sshd_config') if (is_hardened());
    }
    $instance->ssh_assert_script_run('sudo systemctl reload sshd');
    record_info('sshd -G', $instance->ssh_script_output('sudo sshd -G', proceed_on_failure => 1));

    permit_root_login($instance);

    # Create log file for ssh tunnel
    my $ssh_sut = '/var/tmp/ssh_sut.log';
    assert_script_run "touch $ssh_sut; chmod 777 $ssh_sut";
}

sub kill_packagekit {
    my ($instance) = @_;
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
        reboot_on_changes;
    } else {
        zypper_call("in $pkgs");
    }
    # allow ssh tunnel port (to openQA)
    my $upload_port = get_required_var('QEMUPORT') + 1;
    assert_script_run("semanage port -a -t ssh_port_t -p tcp $upload_port");
    process_reboot(trigger => 1) if (is_transactional);
    $openqa_port_allowed = 1;
}


=head2 ssh_update_transactional_system

ssh_update_transactional_system($host);

Connect to the remote host C<$instance> using ssh and update the system by
running C<zypper update> twice, in transactional mode. The first run will update the package manager,
the second run will update the system.
Transactional systems like SLE micro used C<transactional_update up> and reboot. 

=cut

sub ssh_update_transactional_system {
    my ($instance) = @_;
    my $cmd_time = time();
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
}

=head2 get_python_exec

get_python_exec()

Returns the Python executable name for public cloud purposes. As of now, it returns "python3.11" by default.

=cut

sub get_python_exec {
    my $version = '3.11';
    return "python$version";
}

=head2 create_script_file

create_script_file($filename, $fullpath, $content)

Creates a script file with the given content, downloads it from the autoinst URL, and makes it executable.
This is useful for creating scripts that can be run on the public cloud instance.

=cut

sub create_script_file {
    my ($filename, $fullpath, $content) = @_;
    save_tmp_file($filename, $content);
    assert_script_run(sprintf('curl -o "%s" "%s/files/%s"', $fullpath, autoinst_url, $filename));
    assert_script_run(sprintf('chmod +x %s', $fullpath));
}

=head2 install_in_venv

install_in_venv($binary, %args)

Installs a Python package in a virtual environment. The package can be specified either by a requirements.txt file or by a list of pip packages.
The function creates a virtual environment, installs the specified package(s), and creates a wrapper script to run the binary within the virtual environment.

=cut

sub install_in_venv {
    my ($binary, %args) = @_;

    die("Missing binary name") unless $binary;
    die("Need to define path to requirements.txt or list of packages")
      unless $args{pip_packages} || $args{requirements};

    my $venv = venv_create($binary);
    venv_activate($venv);

    my $what_to_install = venv_prepare_install_source($binary, \%args);
    venv_install_packages($what_to_install);

    venv_record_installed_packages($venv);
    venv_deactivate();

    my $script = venv_generate_runner_script($binary, $venv);
    my $fullpath = "$venv/bin/$binary-run-in-venv";

    create_script_file($binary, $fullpath, $script);
    assert_script_run(sprintf('ln -s %s /usr/bin/%s', $fullpath, $binary));

    return $venv;
}

=head2 venv_create

venv_create($binary)

Creates a Python virtual environment in the home directory of the root user.
The virtual environment is named after the binary, prefixed with ".venv_".

=cut

sub venv_create {
    my ($binary) = @_;
    my $python_exec = get_python_exec();
    my $venv = "/root/.venv_$binary";

    assert_script_run("$python_exec -m venv $venv");
    return $venv;
}

=head2 venv_activate

venv_activate($venv)

Activates the Python virtual environment specified by C<$venv>.

=cut

sub venv_activate {
    my ($venv) = @_;
    assert_script_run("source '$venv/bin/activate'");
}

=head2 venv_prepare_install_source

venv_prepare_install_source($binary, $args_ref)

Prepares the source for installation in the virtual environment.
If the C<requirements> argument is defined, it fetches a requirements.txt file from the
autoinst URL and returns the path to that file.
If not, it returns the list of pip packages to install.

=cut

sub venv_prepare_install_source {
    my ($binary, $args_ref) = @_;
    if (defined $args_ref->{requirements}) {
        my $url = sprintf('%s/data/publiccloud/venv/%s.txt', autoinst_url(), $binary);
        my $dst = "/tmp/$binary.txt";
        assert_script_run("curl -f -v $url > $dst");
        return "-r $dst";
    }
    return $args_ref->{pip_packages};
}

=head2 venv_install_packages

venv_install_packages($install_target)

Installs the specified package(s) in the virtual environment using pip.
This function takes a string that can be either a path to a requirements.txt file or a list of pip packages.

=cut

sub venv_install_packages {
    my ($install_target) = @_;
    my $timeout = 15 * 60;
    assert_script_run("pip install --force-reinstall $install_target", timeout => $timeout);
}

=head2 venv_record_installed_packages

venv_record_installed_packages($venv)
Records the installed packages in the virtual environment by running `pip freeze`.

=cut

sub venv_record_installed_packages {
    my ($venv) = @_;
    record_info($venv, script_output('pip freeze'));
}

=head2 venv_deactivate

venv_deactivate()

Deactivates the currently active Python virtual environment.

=cut

sub venv_deactivate {
    assert_script_run('deactivate');
}

=head2 venv_generate_runner_script

venv_generate_runner_script($binary, $venv)

Generates a shell script that activates the virtual environment and runs the specified binary.
This script checks if the binary exists in the virtual environment and exits with an error if it does not.

=cut

sub venv_generate_runner_script {
    my ($binary, $venv) = @_;
    return <<"EOT";
#!/bin/sh
. "$venv/bin/activate"
if [ ! -e "$venv/bin/$binary" ]; then
   echo "Missing $binary in virtualenv $venv"
   deactivate
   exit 2
fi
$binary "\$@"
exit_code=\$?
deactivate
exit \$exit_code
EOT
}

1;
