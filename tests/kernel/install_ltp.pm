# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module installs the LTP (Linux Test Project) and then reboots.
# Maintainer: Richard palethorpe <rpalethorpe@suse.com>
# Usage details are at the end of this file.
use 5.018;
use warnings;
use base 'opensusebasetest';
use File::Basename 'basename';
use LWP::Simple 'head';

use testapi;
use registration;
use utils;
use bootloader_setup qw(add_custom_grub_entries add_grub_cmdline_settings);
use main_common 'get_ltp_tag';
use power_action_utils 'power_action';
use repo_tools 'add_qa_head_repo';
use serial_terminal 'add_serial_console';
use upload_system_log;
use version_utils qw(is_jeos is_opensuse is_released is_sle);
use Utils::Architectures qw(is_aarch64 is_ppc64le is_s390x);
use Utils::Backends 'use_ssh_serial_console';

sub add_we_repo_if_available {
    # opensuse doesn't have extensions
    return if (is_opensuse);

    my ($ar_url, $we_repo);
    $we_repo = get_var('REPO_SLE_PRODUCT_WE');
    $we_repo = get_var('REPO_SLE_WE') if (!$we_repo);
    if ($we_repo) {
        $ar_url = "$utils::OPENQA_FTP_URL/$we_repo";
    }

    # productQA test with enabled WE as iso_2
    if (!head($ar_url) && get_var('BUILD_WE') && get_var('ISO_2')) {
        $ar_url = 'dvd:///?devices=/dev/sr2';
    }
    if ($ar_url) {
        zypper_ar($ar_url, name => 'WE');
    }
}

sub install_runtime_dependencies {
    if (is_jeos) {
        zypper_call('in --force-resolution gettext-runtime');
    }

    my @deps = qw(
      sysstat
      iputils
    );
    zypper_call('-t in ' . join(' ', @deps));

    # kernel-default-extra are only for SLE (in WE)
    # net-tools-deprecated are not available for SLE15
    # ntfsprogs are for SLE in WE, openSUSE has it in default repository
    my @maybe_deps = qw(
      acl
      apparmor-parser
      apparmor-utils
      audit
      bc
      binutils
      dosfstools
      evmctl
      fuse-exfat
      kernel-default-extra
      net-tools
      net-tools-deprecated
      nfs-kernel-server
      ntfsprogs
      numactl
      psmisc
      quota
      sssd-tools
      sudo
      tpm-tools
      wget
      xfsprogs
    );
    for my $dep (@maybe_deps) {
        script_run('zypper -n -t in ' . $dep . ' | tee');
    }
}

sub install_debugging_tools {
    my @maybe_deps = qw(
      attr
      gdb
      ltrace
      strace
    );
    for my $dep (@maybe_deps) {
        script_run('zypper -n -t in ' . $dep . ' | tee');
    }
}

sub install_runtime_dependencies_network {
    my @deps;
    # utils
    @deps = qw(
      ethtool
      iptables
      psmisc
      tcpdump
    );
    zypper_call('-t in ' . join(' ', @deps));

    # clients
    @deps = qw(
      dhcp-client
      telnet
    );
    zypper_call('-t in ' . join(' ', @deps));

    # services
    @deps = qw(
      dhcp-server
      dnsmasq
      nfs-kernel-server
      rpcbind
      rsync
      vsftpd
    );
    zypper_call('-t in ' . join(' ', @deps));
}

sub install_build_dependencies {
    my @deps = qw(
      autoconf
      automake
      bison
      expect
      flex
      gcc
      git-core
      kernel-default-devel
      keyutils-devel
      libacl-devel
      libaio-devel
      libcap-devel
      libopenssl-devel
      libselinux-devel
      libtirpc-devel
      make
    );
    zypper_call('-t in ' . join(' ', @deps));

    my @maybe_deps = qw(
      gcc-32bit
      kernel-default-devel-32bit
      keyutils-devel-32bit
      libacl-devel-32bit
      libaio-devel-32bit
      libcap-devel-32bit
      libnuma-devel
      libnuma-devel-32bit
      libopenssl-devel-32bit
      libselinux-devel-32bit
      libtirpc-devel-32bit
    );
    for my $dep (@maybe_deps) {
        script_run('zypper -n -t in ' . $dep . ' | tee');
    }
}

sub upload_runtest_files {
    my ($dir, $tag) = @_;
    my $aiurl = autoinst_url();

    my $up_script = qq%
rfiles=\$(ls --file-type $dir)
for f in \$rfiles; do
    echo "Uploading ltp-\$f-$tag"
    curl --form upload=\@$dir/\$f --form target=assets_public $aiurl/upload_asset/ltp-\$f-$tag
    echo "ltp-\$f-$tag" >> /tmp/ltp-runtest-files-$tag
done
curl --form upload=\@/tmp/ltp-runtest-files-$tag --form target=assets_public $aiurl/upload_asset/ltp-runtest-files-$tag
curl --form upload=\@/root/openposix-test-list-$tag --form target=assets_public $aiurl/upload_asset/openposix-test-list-$tag
%;

    script_output($up_script, 300);
}

sub install_from_git {
    my ($tag) = @_;
    my $url         = get_var('LTP_GIT_URL', 'https://github.com/linux-test-project/ltp');
    my $rel         = get_var('LTP_RELEASE');
    my $timeout     = (is_aarch64 || is_s390x) ? 7200 : 1440;
    my $configure   = './configure --with-open-posix-testsuite --with-realtime-testsuite';
    my $extra_flags = get_var('LTP_EXTRA_CONF_FLAGS', '');
    if ($rel) {
        $rel = ' -b ' . $rel;
    }
    assert_script_run("git clone -q --depth 1 $url" . $rel, timeout => 360);
    assert_script_run 'cd ltp';
    # It is a shallow clone so 'git describe' won't work
    script_run 'git log -1 --pretty=format:"git-%h" | tee /opt/ltp_version';

    assert_script_run 'make autotools';
    assert_script_run("$configure $extra_flags", timeout => 300);
    assert_script_run 'make -j$(getconf _NPROCESSORS_ONLN)', timeout => $timeout;
    script_run 'export CREATE_ENTRIES=1';
    assert_script_run 'make install', timeout => 360;
    assert_script_run "find /opt/ltp -name '*.run-test' > ~/openposix-test-list-$tag";
}

sub want_stable {
    return get_var('LTP_STABLE', is_sle && is_released);
}

sub add_ltp_repo {
    my $repo = get_var('LTP_REPOSITORY');

    if (!$repo) {
        if (is_sle) {
            add_qa_head_repo;
            return;
        }

        my $arch = '';
        $arch = "_ARM"      if is_aarch64();
        $arch = "_PowerPC"  if is_ppc64le();
        $arch = "_zSystems" if is_s390x();

        $repo = "https://download.opensuse.org/repositories/benchmark:/ltp:/devel/openSUSE_Tumbleweed$arch/";
        if (want_stable) {
            $repo = "https://download.opensuse.org/repositories/benchmark/openSUSE_Factory$arch/";
        }
    }

    zypper_ar($repo, name => 'ltp_repo');
}

sub install_from_repo {
    my ($tag) = @_;
    my $pkg = get_var('LTP_PKG', (want_stable && is_sle) ? 'qa_test_ltp' : 'ltp');

    zypper_call("in $pkg");
    script_run "rpm -q $pkg | tee /opt/ltp_version";
    assert_script_run q(find /opt/ltp/testcases/bin/openposix/conformance/interfaces/ -name '*.run-test' > ~/openposix-test-list-) . $tag;
}

sub setup_network {
    my $content;

    # pts in /etc/securetty
    $content = '# ltp specific setup\npts/1\npts/2\npts/3\npts/4\npts/5\npts/6\npts/7\npts/8\npts/9\n';
    assert_script_run("printf \"$content\" >> /etc/securetty");

    # ftp
    assert_script_run('sed -i \'s/^\s*\(root\)\s*$/# \1/\' /etc/ftpusers');

    # getaddrinfo_01: missing hostname in /etc/hosts
    assert_script_run('h=`hostname`; grep -q $h /etc/hosts || printf "# ltp\n127.0.0.1\t$h\n::1\t$h\n" >> /etc/hosts');

    # boo#1017616: missing link to ping6 in iputils >= s20150815
    assert_script_run('which ping6 >/dev/null 2>&1 || ln -s `which ping` /usr/local/bin/ping6');

    # dhcpd
    assert_script_run('touch /var/lib/dhcp/db/dhcpd.leases /var/lib/dhcp6/db/dhcpd6.leases');

    # echo/echoes, getaddrinfo_01
    assert_script_run('sed -i \'s/^\(hosts:\s+files\s\+dns$\)/\1 myhostname/\' /etc/nsswitch.conf');

    foreach my $service (qw(auditd dnsmasq nfsserver rpcbind vsftpd)) {
        if (is_sle('12+') || is_opensuse || is_jeos) {
            systemctl("reenable $service");
            assert_script_run("systemctl start $service || { systemctl status --no-pager $service; journalctl -xe --no-pager; false; }");
        }
        else {
            script_run("rc$service start");
        }
    }
}

sub run {
    my $self     = shift;
    my $inst_ltp = get_var 'INSTALL_LTP';
    my $tag      = get_ltp_tag();
    my $grub_param;

    if ($inst_ltp !~ /(repo|git)/i) {
        die 'INSTALL_LTP must contain "git" or "repo"';
    }

    if (!get_var('LTP_BAREMETAL') && !is_jeos) {
        $self->wait_boot;
    }

    # poo#18980
    if (get_var('OFW') && !check_var('VIRTIO_CONSOLE', 0)) {
        select_console('root-console');
        add_serial_console('hvc1');
    }

    if (check_var('BACKEND', 'ipmi')) {
        use_ssh_serial_console;
    }
    else {
        $self->select_serial_terminal;
    }

    if (script_output('cat /sys/module/printk/parameters/time') eq 'N') {
        script_run('echo 1 > /sys/module/printk/parameters/time');
        $grub_param = 'printk.time=1';
    }

    # check kGraft if KGRAFT=1
    if (check_var("KGRAFT", '1')) {
        assert_script_run("uname -v | grep -E '(/kGraft-|/lp-)'");
    }

    upload_logs('/boot/config-$(uname -r)', failok => 1);

    add_we_repo_if_available;

    if ($inst_ltp =~ /git/i) {
        install_build_dependencies;
        # bsc#1024050 - Watch for Zombies
        script_run('(pidstat -p ALL 1 > /tmp/pidstat.txt &)');
        install_from_git($tag);
    }
    else {
        add_ltp_repo;
        install_from_repo($tag);
    }

    $grub_param .= ' console=hvc0'     if (get_var('ARCH') eq 'ppc64le');
    $grub_param .= ' console=ttysclp0' if (get_var('ARCH') eq 's390x');
    if (defined $grub_param) {
        add_grub_cmdline_settings($grub_param);
    }

    add_custom_grub_entries if (is_sle('12+') || is_opensuse) && !is_jeos;

    install_runtime_dependencies;
    install_runtime_dependencies_network;
    install_debugging_tools;

    setup_network;

    upload_runtest_files('/opt/ltp/runtest', $tag);

    power_action('reboot', textmode => 1) if get_var('LTP_INSTALL_REBOOT');
}

sub post_fail_hook {
    my $self = shift;

    upload_system_logs();

    # bsc#1024050
    script_run('pkill pidstat');
    upload_logs('/tmp/pidstat.txt', failok => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Configuration

=head2 Required Repositories for runtime and compilation

For OpenSUSE the standard OSS repositories will suffice. On SLE the SDK addon
is essential when installing from Git. The Workstation Extension is nice to have,
but most tests will run without it. At the time of writing their is no appropriate
HDD image available with WE already configured so we must add its media inside this
test.

=head2 Example

Example SLE test suite configuration for installation from repository:

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_sdk_installed.qcow2
INSTALL_LTP=from_repo
ISO=SLE-%VERSION%-Server-DVD-%ARCH%-Build%BUILD%-Media1.iso
ISO_1=SLE-%VERSION%-SDK-DVD-%ARCH%-Build%BUILD_SDK%-Media1.iso
ISO_2=SLE-%VERSION%-WE-DVD-%ARCH%-Build%BUILD_WE%-Media1.iso
PUBLISH_HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_ltp_installed.qcow2
QEMUCPUS=4
QEMURAM=4096
RUN_AFTER_TEST=sles12_minimal_base+sdk_create_hdd

For openSUSE the configuration should be simpler as you can install git and the
other dev tools from the main repository. You just need a text mode installation
image to boot from (a graphical one will probably work as well). Depending how
OpenQA is configured the ISO variable may not be necessary either.

=head2 INSTALL_LTP

Either should contain 'git' or 'repo'. Git is recommended for now. If you decide
to install from the repo then also specify QA_HEAD_REPO.

=head2 LTP_REPOSITORY

When installing from repository default repository URL is generated (for SLES
uses QA head repository in IBS, using QA_HEAD_REPO variable; for openSUSE
Tumbleweed benchmark repository in OBS), with respect whether stable or nightly
build LTP is required (see LTP_STABLE). Variable allows to use custom repository.
When defined, it requires LTP_PKG to be set properly.

Examples (these are set by default):

QA_HEAD_REPO=http://dist.suse.de/ibs/QA:/Head/SLE-12-SP5
QA head repository for SLE12 SP5.

https://download.opensuse.org/repositories/benchmark:/ltp:/devel/openSUSE_Tumbleweed_PowerPC
Nightly build for openSUSE Tumbleweed ppc64le.

https://download.opensuse.org/repositories/benchmark/openSUSE_Factory
Stable release for openSUSE Tumbleweed x86_64.

=head2 LTP_STABLE

When defined and installing from repository stable release. Default is stable
for SLES QAM, otherwise nightly builds.

=head2 LTP_PKG

Name of the package from repository. Sometimes packages are named differently
than 'ltp'. Allow to define it, when custom repository is used (via LTP_REPOSITORY).

Examples:
LTP_PKG=ltp-32bit
32bit based builds (which are for compilation set with
LTP_EXTRA_CONF_FLAGS="CFLAGS=-m32 LDFLAGS=-m32").

LTP_PKG=qa_test_ltp
Stable LTP package in QA head repository.

=head2 LTP_RELEASE

When installing from Git this can be set to a release tag, commit hash, branch
name or whatever else Git will accept. Usually this is set to a release, such as
20160920, which will cause that release to be used. If not set, then the default
clone action will be performed, which probably means the latest master branch
will be used.

=head2 LTP_GIT_URL

Overrides the official LTP GitHub repository URL.

=head2 GRUB_PARAM

Append custom group entries with appended group param via
add_custom_grub_entries().

=cut
