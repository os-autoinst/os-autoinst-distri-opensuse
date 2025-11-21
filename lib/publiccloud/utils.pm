# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Public cloud utilities
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::utils;

use base Exporter;
use Exporter;
use File::Basename;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::JSON 'encode_json';
use Carp qw(croak);
use Socket qw(AF_INET AF_INET6 inet_pton);

use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_public_cloud get_version_id is_transactional is_openstack is_sle_micro check_version);
use transactional qw(reboot_on_changes trup_call process_reboot);
use registration qw(get_addon_fullname add_suseconnect_product %ADDONS_REGCODE);
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
  zypper_add_repo_remote
  zypper_remove_repo_remote
  get_installed_packages_remote
  get_available_packages_remote
  zypper_install_remote
  zypper_install_available_remote
  wait_quit_zypper_pc
  detect_worker_ip
  upload_asset_on_remote
  zypper_remote_call
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
        my $name = get_addon_fullname($addon);
        ssh_add_suseconnect_product($remote, $name, program => $program, version => '${VERSION_ID}', arch => $arch, params => "-r " . $ADDONS_REGCODE{$name}, timeout => $timeout, retries => $retries, delay => $delay);
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
        die 'cloud-regionsrv-client should be installed' if !is_container_host;
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
    my $ret = $instance->ssh_script_run(cmd => $cmd, timeout => 300);
    die 'No enabled repos defined: bsc#1245651' if $ret == 6;    # from zypper man page: ZYPPER_EXIT_NO_REPOS
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

=head2 get_installed_packages_remote

get_installed_packages_remote($instance, $packages_ref)

This function checks which packages from the provided list are installed on the remote instance.
It returns an array reference containing the names of the installed packages.

=cut

sub get_installed_packages_remote {
    my ($instance, $packages_ref) = @_;

    my $pkg_list = join(' ', @$packages_ref);
    my $cmd = "rpm -q --qf '%{NAME}|' $pkg_list 2>/dev/null";

    my $output = $instance->run_ssh_command(
        cmd => $cmd,
        proceed_on_failure => 1
    );

    my %installed;
    for my $entry (split /\|/, $output) {
        next if $entry =~ /is not installed/i;
        $installed{$entry} = 1;
    }

    my @found = grep { $installed{$_} } @$packages_ref;
    return \@found;
}

=head2 get_available_packages_remote

get_available_packages_remote($instance, $packages_ref)

This function checks which packages from the provided list are available for installation on the remote instance.
It returns an array reference containing the names of the available packages.
It uses `zypper -x info` to query the availability of packages.

=cut

sub get_available_packages_remote {
    my ($instance, $packages_ref) = @_;
    die "Expected arrayref" unless ref($packages_ref) eq 'ARRAY';

    my %installed = map { $_ => 1 } @{get_installed_packages_remote($instance, $packages_ref)};
    my @not_installed = grep { !$installed{$_} } @$packages_ref;
    return [] unless @not_installed;

    my $pkg_list = join(' ', @not_installed);
    my $output = $instance->run_ssh_command(
        cmd => "zypper -x info $pkg_list 2>/dev/null",
        proceed_on_failure => 1
    );

    # Grep all "Name           : <pkg>" lines
    my %available = map { $_ => 1 } ($output =~ /^Name\s*:\s*(\S+)/mg);

    # Return only those that are in the original not-installed list
    my @result = grep { $available{$_} } @not_installed;
    return \@result;
}

=head2 zypper_add_repo_remote

zypper_add_repo_remote($instance, $repo_name, $repo_url)

This function adds a repository to the remote instance using zypper.
It uses the `-fG` options to add the repository as a GPG-verified repository.

=cut

sub zypper_add_repo_remote {
    my ($instance, $repo_name, $repo_url) = @_;
    $instance->run_ssh_command(
        cmd => "sudo zypper -n addrepo -fG $repo_url $repo_name",
        timeout => 600
    );
}

=head2 zypper_remove_repo_remote

zypper_remove_repo_remote($instance, $repo_name)

This function removes a repository from the remote instance using zypper.
It uses the `-n` option to run the command non-interactively.

=cut

sub zypper_remove_repo_remote {
    my ($instance, $repo_name) = @_;
    $instance->run_ssh_command(
        cmd => "sudo zypper -n removerepo $repo_name",
        timeout => 600
    );
}

=head2 zypper_install_remote

zypper_install_remote($instance, $packages)

This function installs the specified packages on the remote instance using zypper.
It handles both transactional updates and regular zypper installations based on the system type.

=cut

sub zypper_install_remote {
    my ($instance, $packages) = @_;

    my @pkg_list = ref($packages) eq 'ARRAY' ? @$packages : ($packages);
    my $pkg_str = join(' ', @pkg_list);

    if (is_transactional) {
        $instance->run_ssh_command(
            cmd => "sudo transactional-update -n pkg install --no-recommends $pkg_str",
            timeout => 900
        );
        $instance->softreboot();
    } else {
        $instance->run_ssh_command(
            cmd => "sudo zypper -n in --no-recommends $pkg_str",
            timeout => 600
        );
    }
}

=head2 zypper_install_available_remote

zypper_install_available_remote($instance, $packages_ref)

This function checks which packages from the provided list are available for installation on the remote instance.
If any packages are available, it installs them using zypper_install_remote.

=cut

sub zypper_install_available_remote {
    my ($instance, $packages_ref) = @_;
    my $available_ref = get_available_packages_remote($instance, $packages_ref);
    return unless @$available_ref;
    zypper_install_remote($instance, $available_ref);
}

=head2 wait_quit_zypper_pc

    wait_quit_zypper_pc($instance
        [, timeout => 20 ]   # per-attempt SSH timeout (s)
        [, delay   => 10 ]   # delay between attempts (s)
        [, retry   => 60 ]   # number of attempts
    );

Wait until no background zypper-related processes are running on the remote
instance. Uses C<retry_ssh_command> for polling. Returns on success; dies
after retries are exhausted.

=cut

sub wait_quit_zypper_pc {
    my ($instance, %args) = @_;

    my $timeout = $args{timeout} // 20;    # per-attempt SSH timeout
    my $delay = $args{delay} // 10;    # seconds between polls
    my $retry = $args{retry} // 120;    # total attempts (~10 min ceiling)

    # Succeeds (RC 0) only when NO matching processes exist.
    # Using '!' avoids explicit 'exit' and works cleanly with retry_ssh_command.
    my $cmd = q{pgrep -f "zypper|purge-kernels|rpm" && false || true};

    $instance->retry_ssh_command(
        cmd => $cmd,
        timeout => $timeout,
        delay => $delay,
        retry => $retry,
    );
}

=head2 detect_worker_ip

    detect_worker_ip($proceed_on_failure)

    Detects the current openQA worker's public IPs (ipv4/6) and returns them as
    an array of suitable CIDR strings(/32 or /128 for ipv4/6, respectively).
    The function uses http://checkip.amazonaws.com and falls back to https://ifconfig.me
    if the first attempt fails.
    Optionally accepts proceed_on_failure => 1 to return undef instead of dying.

    Return:
    - worker ip, if retrieved
    - undef otherwise (if proceed_on_failure is set)

=cut

sub detect_worker_ip {
    my (%args) = @_;
    my $ip;
    for my $url ('http://checkip.amazonaws.com', 'https://ifconfig.me') {
        $ip = script_output("curl -q -fsS --max-time 10 $url",
            timeout => 15, proceed_on_failure => 1);
        $ip =~ s/^\s+|\s+$//g;
        next unless $ip && (inet_pton(AF_INET, $ip) || inet_pton(AF_INET6, $ip));
        return $ip;
    }
    return undef if $args{proceed_on_failure};
    die "Worker IP could not be determined - return was $ip";
}

sub upload_asset_on_remote {
    my (%args) = @_;

    my $instance = $args{instance};
    my $source_data_url_path = $args{source_data_url_path};
    my $destination_path = $args{destination_path};
    my $elevated = $args{elevated} // 0;

    die 'Missing instance' unless $instance;
    die 'Missing source_data_url_path' unless $source_data_url_path;
    die 'Missing destination_path' unless $destination_path;

    my $filename = basename($source_data_url_path);

    my $curl_cmd = "curl " . data_url($source_data_url_path) . " -o ./$filename";
    assert_script_run($curl_cmd);

    $instance->scp("./$filename", "remote:/tmp/$filename");

    my $prefix = $elevated ? 'sudo ' : '';
    my $mv_cmd = $prefix . "mv /tmp/$filename $destination_path";
    $instance->ssh_assert_script_run($mv_cmd);
}


=head2 zypper_remote_call

    zypper_remote_call($command [, exitcode => $exitcode] [, timeout => $timeout];

Function wrapping zypper or transactional-update command for remote execution via ssh; not for tunneling.
Implements lib/utils::zypper_call, dedicated to publiccloud instances, but the input command is totally up to the user, 
simply expecting zypper or transactional-update commands present, being some zypper commands allowed in transactionals.
Unlike 'zypper_call', here the zypper_log_packages preparation is skipped.

Usage example:
    $instance->zypper_remote_call("LANG=C sudo zypper -n up", exitcode => [0,102,103], timeout => 300);

=cut

sub zypper_remote_call {
    my $instance = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $command = $args{cmd};
    # check command line:
    my $type = $command =~ (/((^|\b)zypper\b)(?![-\/])/) ? 1 :
      ($command =~ /((^|\b)transactional-update\b)(?![-\/])/) ? 2 : 0;
    die("ERROR: unexpected command: " . $command) unless ($type);
    #
    $args{rc_only} = 1;
    $args{timeout} //= 700;
    my $exit = $args{exitcode} || [0];
    my $retry = $args{retry} // 1;
    my $delay = $args{delay} // 5;
    my $proceed = $args{proceed_on_failure} // 0;
    my $log = "/var/log/zypper.log";
    my $ret;
    #
    delete $args{exitcode};
    delete $args{retry};
    delete $args{delay};
    # retry loop
    for (1 .. $retry) {
        # pause on next
        sleep($delay) if (defined($ret));
        $ret = $instance->run_ssh_command(%args);
        die "FAILED: timeout after " . $args{timeout} . " sec." unless defined($ret);
        last if ($ret == 0);
        # check exit codes
        if ($ret == 4 && $type == 1) {
            if ($instance->ssh_script_run(qq[sudo grep "Error code.*502" $log]) == 0) {
                die 'According to bsc#1070851 zypper should automatically retry internally. Bugfix missing for current product?';
            }
            elsif ($instance->ssh_script_run(qq[sudo grep "Solverrun finished with an ERROR" $log] == 0)) {
                my $search_conflicts = q[sudo awk 'BEGIN {print "Processing conflicts - ",NR; group=0}
                    /Solverrun finished with an ERROR/,/statistics/{ 
                    print group"|", $0; if ($0 ~ /statistics/ ){ print "EOL"; group++ }; }' ] . $log;
                my $conflicts = $instance->ssh_script_output($search_conflicts);
                record_info("Conflict", $conflicts, result => 'fail');
                diag "Package conflicts found, not retrying anymore" if $conflicts;
                last;
            }
            next;
        }
        last;
    }
    # failed result management
    unless (grep { $_ == $ret } @$exit) {
        $instance->upload_log($log);
        my $msg = qq['$command' failed with code $ret];
        if ($ret == 104) {
            $msg .= " (ZYPPER_EXIT_INF_CAP_NOT_FOUND)\n\nRelated zypper logs:\n";
            $instance->ssh_script_run(qq[sudo tac $log | grep -F -m1 -B100000 "Hi, me zypper" | tac | grep -E '(SolverRequester.cc|THROW|CAUGHT)' > /tmp/z104.txt]);
            $msg .= $instance->ssh_script_output('cat /tmp/z104.txt');
        }
        elsif ($ret == 107) {
            $msg .= " (ZYPPER_EXIT_INF_RPM_SCRIPT_FAILED)\n\nRelated zypper logs:\n";
            $instance->ssh_script_run(qq[sudo tac $log | grep -F -m1 -B100000 "Hi, me zypper" | tac | grep -E 'RpmPostTransCollector.cc(executeScripts):.* scriptlet failed, exit status' > /tmp/z107.txt]);
            $msg .= $instance->ssh_script_output('cat /tmp/z107.txt') . "\n\n";
        }
        else {
            $instance->ssh_script_run(qq[sudo tac $log | grep -F -m1 -B100000 "Hi, me zypper" | tac | grep 'Exception.cc' > /tmp/zlog.txt]);
            $msg .= "\n\nRelated zypper logs:\n";
            $msg .= $instance->ssh_script_output('cat /tmp/zlog.txt');
        }
        die $msg unless ($proceed);
        record_info("zypper error", $msg, result => 'fail');
    }
    $instance->softreboot() if ($type == 2 && $ret == 0);
    record_info("zypper remote call", "Command: $command \nResult: $ret");
    return $ret;
}

1;
