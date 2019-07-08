# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2019 SUSE LLC
#
# Maintainers:
# Richard Palethorpe <rpalethorpe@suse.com>
# Petr Vorel <pvorel@suse.cz>

package LTP::Install;

use base Exporter;
use strict;
use warnings;
use File::Basename 'basename';
use LWP::Simple 'head';

use testapi;
use bmwqemu;
use registration;
use utils;
use bootloader_setup qw(add_custom_grub_entries add_grub_cmdline_settings);
use main_common 'get_ltp_tag';
use power_action_utils 'power_action';
use serial_terminal 'add_serial_console';
use upload_system_log;
use version_utils qw(is_sle is_opensuse is_jeos);
use Utils::Backends 'use_ssh_serial_console';

our @EXPORT = qw(install_ltp);

sub add_repos {
    my $qa_head_repo = get_required_var('QA_HEAD_REPO');
    zypper_ar($qa_head_repo, 'qa_repo');
}

sub add_we_repo_if_available {
    # opensuse doesn't have extensions
    return if check_var('DISTRI', 'opensuse');

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
        zypper_call("ar $ar_url WE",              dumb_term => 1);
        zypper_call('--gpg-auto-import-keys ref', dumb_term => 1);
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
      keyutils-devel
      libacl-devel
      libaio-devel
      libcap-devel
      libopenssl-devel
      libselinux-devel
      libtirpc-devel
      make
    );
    zypper_call('-t in ' . join(' ', @deps), dumb_term => 1);

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

sub install_from_git {
    my ($tag) = @_;
    my $url = get_var('LTP_GIT_URL') || 'https://github.com/linux-test-project/ltp';
    my $rel = get_var('LTP_RELEASE') || '';
    my $timeout     = check_var('ARCH', 's390x') || check_var('ARCH', 'aarch64') ? 7200 : 1440;
    my $configure   = './configure --with-open-posix-testsuite --with-realtime-testsuite';
    my $extra_flags = get_var('LTP_EXTRA_CONF_FLAGS') || '';
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
    assert_script_run "find /opt/ltp/ -name '*.run-test' > ~/openposix-test-list-$tag";
}

sub install_from_repo {
    my ($tag) = @_;
    zypper_call('in qa_test_ltp', dumb_term => 1);
    script_run 'rpm -q qa_test_ltp | tee /opt/ltp_version';
    assert_script_run q(find ${LTPROOT:-/opt/ltp}/testcases/bin/openposix/conformance/interfaces/ -name '*.run-test' > ~/openposix-test-list-) . $tag;
}

sub install_runtime_dependencies {
    if (is_jeos) {
        zypper_call('in --force-resolution gettext-runtime', dumb_term => 1);
    }

    my @deps = qw(
      sysstat
      iputils
    );
    zypper_call('-t in ' . join(' ', @deps), dumb_term => 1);

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

sub install_runtime_dependencies_network {
    my @deps;
    # utils
    @deps = qw(
      ethtool
      iptables
      psmisc
      tcpdump
    );
    zypper_call('-t in ' . join(' ', @deps), dumb_term => 1);

    # clients
    @deps = qw(
      dhcp-client
      telnet
    );
    zypper_call('-t in ' . join(' ', @deps), dumb_term => 1);

    # services
    @deps = qw(
      dhcp-server
      dnsmasq
      nfs-kernel-server
      rpcbind
      rsync
      vsftpd
    );
    zypper_call('-t in ' . join(' ', @deps), dumb_term => 1);
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

sub install_ltp {
    my $inst_ltp = get_var 'INSTALL_LTP';
    my $tag      = get_ltp_tag();
    my $grub_param;

    if ($inst_ltp !~ /(repo|git)/i) {
        die 'INSTALL_LTP must contain "git" or "repo"';
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

    $grub_param .= ' console=hvc0'     if (get_var('ARCH') eq 'ppc64le');
    $grub_param .= ' console=ttysclp0' if (get_var('ARCH') eq 's390x');
    if (defined $grub_param) {
        add_grub_cmdline_settings($grub_param);
    }

    add_custom_grub_entries if (is_sle('12+') || is_opensuse) && !is_jeos;

    install_runtime_dependencies;
    install_runtime_dependencies_network;
    install_debugging_tools;

    if ($inst_ltp =~ /git/i) {
        install_build_dependencies;
        # bsc#1024050 - Watch for Zombies
        script_run('(pidstat -p ALL 1 > /tmp/pidstat.txt &)');
        install_from_git($tag);
    }
    else {
        add_repos;
        install_from_repo($tag);
    }

    setup_network;

    upload_runtest_files('${LTPROOT:-/opt/ltp}/runtest', $tag);

    power_action('reboot', textmode => 1) if get_var('LTP_INSTALL_REBOOT');
}

1;
