# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
use power_action_utils 'power_action';
use repo_tools 'add_qa_head_repo';
use upload_system_log;
use version_utils qw(is_jeos is_opensuse is_released is_sle is_leap is_tumbleweed);
use Utils::Architectures;
use Utils::Systemd qw(systemctl disable_and_stop_service);
use LTP::utils;

sub add_we_repo_if_available {
    # opensuse doesn't have extensions
    return if (is_opensuse || is_jeos);

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

    # sysstat is also a dependency for build from git (pidstat)
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
      e2fsprogs
      evmctl
      exfat-utils
      fuse-exfat
      kernel-default-extra
      lvm2
      net-tools
      net-tools-deprecated
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
        # ignore failures due to missing packages (exit code 104)
        zypper_call("in $dep", exitcode => [0, 104]);
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
        # ignore failures due to missing packages (exit code 104)
        zypper_call("in $dep", exitcode => [0, 104]);
    }
}

sub install_runtime_dependencies_network {
    my @deps;
    @deps = qw(
      dhcp-client
      dhcp-server
      diffutils
      dnsmasq
      ethtool
      iptables
      nfs-kernel-server
      psmisc
      rpcbind
      rsync
      telnet
      tcpdump
      vsftpd
    );
    zypper_call('-t in ' . join(' ', @deps));

    my @maybe_deps = qw(
      telnet-server
      wireguard-tools
      xinetd
    );
    for my $dep (@maybe_deps) {
        # ignore failures due to missing packages (exit code 104)
        zypper_call("in $dep", exitcode => [0, 104]);
    }
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
      libaio-devel
      libopenssl-devel
      make
    );
    zypper_call('-t in ' . join(' ', @deps));

    my @maybe_deps = qw(
      keyutils-devel
      libcap-devel
      libacl-devel
      libtirpc-devel
      libselinux-devel
      gcc-32bit
      kernel-default-devel-32bit
      keyutils-devel-32bit
      libacl-devel-32bit
      libaio-devel-32bit
      libcap-devel-32bit
      libmnl-devel
      libnuma-devel
      libnuma-devel-32bit
      libselinux-devel-32bit
      libtirpc-devel-32bit
    );

    # libopenssl-devel-32bit is blocked by dependency mess on SLE-12 and we
    # don't use it anyway...
    push @maybe_deps, 'libopenssl-devel-32bit' if !is_sle('<15');

    for my $dep (@maybe_deps) {
        # ignore failures due to missing packages (exit code 104)
        zypper_call("in $dep", exitcode => [0, 104]);
    }
}

sub prepare_ltp_git {
    my $url = get_var('LTP_GIT_URL', 'https://github.com/linux-test-project/ltp');
    my $rel = get_var('LTP_RELEASE');
    my $prefix = get_ltproot();
    my $configure = "./configure --prefix=$prefix";
    my $extra_flags = get_var('LTP_EXTRA_CONF_FLAGS', '--with-open-posix-testsuite --with-realtime-testsuite');

    $rel = "-b $rel" if ($rel);

    script_run('rm -rf ltp');
    my $ret = script_run("git clone -q --depth 1 $url $rel ltp", timeout => 360);
    if (!defined($ret) || $ret) {
        assert_script_run("git clone -q $url $rel ltp", timeout => 360);
    }
    assert_script_run 'cd ltp';
    assert_script_run 'make autotools';
    assert_script_run("$configure $extra_flags", timeout => 300);
}

sub install_selected_from_git {
    prepare_ltp_git;
    my @paths = qw(commands/insmod
      kernel/firmware
      kernel/device-drivers
      kernel/syscalls/delete_module
      kernel/syscalls/finit_module
      kernel/syscalls/init_module);

    assert_script_run('pushd testcases');
    foreach (@paths) {
        assert_script_run("pushd $_ && make && make install && popd", timeout => 600);
    }
    assert_script_run("popd");
}

sub install_from_git {
    my $timeout = (is_aarch64 || is_s390x) ? 7200 : 1440;
    my $prefix = get_ltproot();

    prepare_ltp_git;
    assert_script_run 'make -j$(getconf _NPROCESSORS_ONLN)', timeout => $timeout;
    script_run 'export CREATE_ENTRIES=1';
    assert_script_run 'make install', timeout => 360;
    assert_script_run "find $prefix -name '*.run-test' > "
      . get_ltp_openposix_test_list_file();

    # It is a shallow clone so 'git describe' won't work
    record_info("LTP git", script_output('git log -1 --pretty=format:"git-%h" | tee '
              . get_ltp_version_file()));
}

sub add_ltp_repo {
    my $repo = get_var('LTP_REPOSITORY');

    if (!$repo) {
        if (is_sle) {
            add_qa_head_repo;
            return;
        }

        # ltp for leap15.2 is available only x86_64
        if (is_leap('15.4+')) {
            $repo = get_var('VERSION');
        } elsif ((is_leap('=15.2') && is_x86_64) || is_leap('15.3+')) {
            $repo = sprintf("openSUSE_Leap_%s", get_var('VERSION'));
        } elsif (is_tumbleweed) {
            $repo = "openSUSE_Factory";
            $repo = "openSUSE_Factory_ARM" if (is_aarch64() || is_arm());
            $repo = "openSUSE_Factory_PowerPC" if is_ppc64le();
            $repo = "openSUSE_Factory_zSystems" if is_s390x();
        } else {
            die sprintf("Unexpected combination of version (%s) and architecture (%s) used", get_var('VERSION'), get_var('ARCH'));
        }
        $repo = "https://download.opensuse.org/repositories/benchmark:/ltp:/devel/$repo/";
    }

    zypper_ar($repo, name => 'ltp_repo');
}

sub get_default_pkg {
    my @packages;

    if (is_sle && is_released) {
        push @packages, 'ltp-stable';
        push @packages, 'ltp-stable-32bit' if is_x86_64;
    } else {
        push @packages, 'ltp';
        push @packages, 'ltp-32bit' if is_x86_64 && !is_jeos;
    }

    return join(' ', @packages);
}

sub install_from_repo {
    my @pkgs = split(/\s* \s*/, get_var('LTP_PKG', get_default_pkg));

    zypper_call("in --recommends " . join(' ', @pkgs));

    for my $pkg (@pkgs) {
        my $want_32bit = $pkg =~ m/32bit/;
        record_info("LTP pkg: $pkg", script_output("rpm -qi $pkg | tee "
                  . get_ltp_version_file($want_32bit)));
        assert_script_run "find " . get_ltproot($want_32bit) .
          q(/testcases/bin/openposix/conformance/interfaces/ -name '*.run-test' > )
          . get_ltp_openposix_test_list_file($want_32bit);
    }
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
    assert_script_run('touch /var/lib/dhcp/db/dhcpd.leases');
    script_run('touch /var/lib/dhcp6/db/dhcpd6.leases');

    # echo/echoes, getaddrinfo_01
    assert_script_run('f=/etc/nsswitch.conf; [ ! -f $f ] && f=/usr$f; sed -i \'s/^\(hosts:\s+files\s\+dns$\)/\1 myhostname/\' $f');

    my @services = qw(auditd dnsmasq rpcbind vsftpd);
    # nfsd module is not included in kernel-default-base package
    push @services, 'nfs-server' unless get_var('KERNEL_BASE');

    foreach my $service (@services) {
        if (!is_jeos && is_sle('12+') || is_opensuse) {
            systemctl("reenable $service");
            assert_script_run("systemctl start $service || { systemctl status --no-pager $service; journalctl -xe --no-pager; false; }");
        }
        else {
            script_run("rc$service start");
        }
    }

    if (is_sle('<12')) {
        script_run('chkconfig -d SuSEfirewall2_init');
        script_run('chkconfig -d SuSEfirewall2_setup');
        script_run('/etc/init.d/SuSEfirewall2_setup stop');
    }
    else {
        disable_and_stop_service(opensusebasetest::firewall, ignore_failure => 1);
    }
}

sub run {
    my $self = shift;
    my $inst_ltp = get_var 'INSTALL_LTP';
    my $cmd_file = get_var('LTP_COMMAND_FILE');
    my $grub_param = 'ignore_loglevel';

    if ($inst_ltp !~ /(repo|git)/i) {
        die 'INSTALL_LTP must contain "git" or "repo"';
    }

    if (!get_var('KGRAFT') && !get_var('LTP_BAREMETAL') && !is_jeos) {
        $self->wait_boot;
    }

    $self->select_serial_terminal;

    if (script_output('cat /sys/module/printk/parameters/time') eq 'N') {
        script_run('echo 1 > /sys/module/printk/parameters/time');
        $grub_param .= ' printk.time=1';
    }

    # check kGraft if KGRAFT=1
    if (check_var("KGRAFT", '1') && !check_var('REMOVE_KGRAFT', '1')) {
        assert_script_run("uname -v | grep -E '(/kGraft-|/lp-)'");
    }

    upload_logs('/boot/config-$(uname -r)', failok => 1);
    set_zypper_lock_timeout(300);
    add_we_repo_if_available;

    if ($inst_ltp =~ /git/i) {
        install_build_dependencies;
        install_runtime_dependencies;    # install pidstat (sysstat)

        # bsc#1024050 - Watch for Zombies
        script_run('(pidstat -p ALL 1 > /tmp/pidstat.txt &)');
        install_from_git();

        install_runtime_dependencies_network;
        install_debugging_tools;
    }
    else {
        add_ltp_repo;
        install_from_repo();
        if (get_var("LTP_GIT_URL")) {
            install_build_dependencies;
            install_selected_from_git;
        }
    }

    log_versions 1;

    zypper_call('in efivar') if is_sle('12+') || is_opensuse;

    $grub_param .= ' console=hvc0' if (get_var('ARCH') eq 'ppc64le');
    $grub_param .= ' console=ttysclp0' if (get_var('ARCH') eq 's390x');
    if (!is_sle('<12') && defined $grub_param) {
        add_grub_cmdline_settings($grub_param, update_grub => 1);
    }

    add_custom_grub_entries if (is_sle('12+') || is_opensuse) && !is_jeos;
    setup_network;

    # we don't run LVM tests in 32bit, thus not generating the runtest file
    # for 32 bit packages
    if (!is_sle('<12')) {
        prepare_ltp_env();
        assert_script_run('generate_lvm_runfile.sh');
    }

    (is_jeos && is_sle('>15')) && zypper_call 'in system-user-bin system-user-daemon';

    # boot_ltp will schedule the tests and shutdown_ltp if there is a command
    # file
    if (get_var('LTP_INSTALL_REBOOT')) {
        power_action('reboot', textmode => 1) unless is_jeos;
        loadtest_kernel 'boot_ltp';
    } elsif ($cmd_file) {
        assert_secureboot_status(1) if get_var('SECUREBOOT');
        init_ltp_tests($cmd_file);
        schedule_tests($cmd_file);
    }
}

sub post_fail_hook {
    my $self = shift;

    upload_system_logs();

    # bsc#1024050
    if (get_var('INSTALL_LTP') =~ /git/i) {
        script_run('pkill pidstat');
        upload_logs('/tmp/pidstat.txt', failok => 1);
    }
}

sub test_flags {
    my %ret = (fatal => 1);

    $ret{milestone} = 1 if get_var('LTP_COMMAND_FILE');
    return \%ret;
}

1;

=head1 Configuration

=head2 Required Repositories for runtime and compilation

For OpenSUSE the standard OSS repositories will suffice. On SLE the SDK addon
is essential when installing from Git. The Workstation Extension is nice to have,
but most tests will run without it. At the time of writing their is no appropriate
HDD image available with WE already configured so we must add its media inside this
test.

=head2 Runtime dependencies

Runtime dependencies are needed to be listed both in this module (for git
installation) and for all LTP rpm packages (for installation from repo), where
listed as 'Recommends:'. See list of available LTP packages in LTP_PKG section.

=head2 INSTALL_LTP

Either should contain 'git' or 'repo'. Git is recommended for now. If you decide
to install from the repo then also specify QA_HEAD_REPO.

=head2 LTP_BAREMETAL

Loads installer modules to install OS before running install_ltp.

This was originally used to install LTP on baremetal, but now used also on other
platforms which do not support QCOW2 image snapshot (PowerVM, s390x backend).

=head2 LTP_REPOSITORY

When installing from repository the default repository URL is generated (for SLES
uses QA head repository in IBS, using QA_HEAD_REPO variable; for openSUSE
Tumbleweed benchmark repository in OBS). Variable allows to use custom repository.
When defined, it requires LTP_PKG to be set properly.

Examples (these are set by default):

QA_HEAD_REPO=http://dist.suse.de/ibs/QA:/Head/SLE-12-SP5
QA head repository for SLE12 SP5.

https://download.opensuse.org/repositories/benchmark:/ltp:/devel/openSUSE_Tumbleweed_PowerPC
Nightly build for openSUSE Tumbleweed ppc64le.

=head2 LTP_PKG

Name of the package from repository. Sometimes packages are named differently
than 'ltp'. Allow to define it, when custom repository is used (via LTP_REPOSITORY).

Examples:
LTP_PKG=ltp-32bit
32bit based builds (which are for compilation set with
LTP_EXTRA_CONF_FLAGS="CFLAGS=-m32 LDFLAGS=-m32").

LTP_PKG=qa_test_ltp
Stable LTP package in QA head repository.
This is the default for QA for SLE released products.

LTP_PKG=ltp ltp-32bit
Install both 64bit and 32bit LTP packages from nightly build.
This is the default on x86_64 for QA for SLE product development and Tumbleweed.

=head3 Available LTP packages

https://confluence.suse.com/display/qasle/LTP+repositories

* QA:Head/qa_test_ltp (IBS, stable - latest release, used for released products testing)
https://build.suse.de/package/show/QA:Head/qa_test_ltp
Configured via
https://github.com/SUSE/qa-testsuites

* QA:Head/ltp (IBS, nightly build)
https://build.suse.de/package/show/QA:Head/ltp

* benchmark:ltp:devel/ltp (OBS, nightly build)
https://build.opensuse.org/package/show/benchmark:ltp:devel/ltp

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

=head2 SLES CONFIGURATION

=head3 install_ltp+sle+Online

BOOT_HDD_IMAGE=1
DESKTOP=textmode
GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb;slub_debug=FZPU
HDD_1=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed.qcow2
INSTALL_LTP=from_repo
LTP_PKG=ltp ltp-32bit
PUBLISH_HDD_1=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp.qcow2
PUBLISH_PFLASH_VARS=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp-uefi-vars.qcow2
QEMUCPUS=4
QEMURAM=4096
START_AFTER_TEST=create_hdd_minimal_base+sdk
UEFI_PFLASH_VARS=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed-uefi-vars.qcow2

=head3 install_ltp+sle+Online-KOTD

BOOT_HDD_IMAGE=1
DESKTOP=textmode
GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb;slub_debug=FZPU
HDD_1=%KOTD_HDD%
INSTALL_KOTD=1
INSTALL_LTP=from_repo
LTP_PKG=ltp ltp-32bit
PUBLISH_HDD_1=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp.qcow2
PUBLISH_PFLASH_VARS=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp-uefi-vars.qcow2
QEMUCPUS=4
QEMURAM=4096
UEFI_PFLASH_VARS=%DISTRI%-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed-uefi-vars.qcow2

=head3 install_ltp_spvm

BOOT_HDD_IMAGE=1
DESKTOP=textmode
GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb
INSTALL_LTP=from_repo
NOVIDEO=1
START_DIRECTLY_AFTER_TEST=default_kernel_spvm

=head3 install_ltp_baremetal

DESKTOP=textmode
GA_REPO=http://dist.suse.de/ibs/SUSE:/SLE-%VERSION%:/GA/standard/SUSE:SLE-%VERSION%:GA.repo
GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb;slub_debug=FZPU
GRUB_TIMEOUT=300
INSTALL_LTP=from_repo
LTP_PKG=ltp ltp-32bit
START_DIRECTLY_AFTER_TEST=prepare_baremetal
VNC_TYPING_LIMIT=50

=head3 install_ltp+sle+Server-DVD-Incidents-Kernel-KOTD

Incidents Kernel (released products) use qa_test_ltp package.

BOOT_HDD_IMAGE=1
DESKTOP=textmode
GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb
HDDSIZEGB=60
HDD_1=SLES-%VERSION%-%ARCH%-minimal_installed_for_LTP.qcow2
INSTALL_LTP=from_repo
PUBLISH_HDD_1=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp.qcow2
PUBLISH_PFLASH_VARS=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp-uefi-vars.qcow2
QEMUCPUS=4
QEMURAM=4096
UEFI_PFLASH_VARS=SLES-%VERSION%-%ARCH%-minimal_installed_for_LTP-uefi-vars.qcow2

=head2 JeOS

JeOS does not use install_ltp, it installs LTP for each runtest file.

=head3 jeos-ltp-syscalls

INSTALL_LTP=from_repo
LTP_COMMAND_EXCLUDE=quotactl(01|04|06)|msgstress(03|04)
LTP_COMMAND_FILE=syscalls
SCC_ADDONS=base
YAML_SCHEDULE=schedule/jeos/sle/jeos-ltp.yaml

=head2 openSUSE CONFIGURATION

=head3 install_ltp+opensuse+DVD

BOOT_HDD_IMAGE=1
DESKTOP=textmode
GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb
HDD_1=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%DESKTOP%@%MACHINE%.qcow2
INSTALL_LTP=from_repo
LTP_ENV=LVM_DIR=/var/tmp/
PUBLISH_HDD_1=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp.qcow2
PUBLISH_PFLASH_VARS=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%FLAVOR%@%MACHINE%-with-ltp-uefi-vars.qcow2
QEMUCPUS=4
QEMURAM=4096
START_AFTER_TEST=create_hdd_textmode
UEFI_PFLASH_VARS=%DISTRI%-%VERSION%-%ARCH%-%BUILD%-%DESKTOP%@%MACHINE%-uefi-vars.qcow2

=cut
