# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

package qam;

use strict;
use warnings;

use base "Exporter";
use Exporter;

use testapi;
use utils qw(zypper_call handle_screen);
use JSON;
use List::Util qw(max);
use version_utils 'is_sle';

our @EXPORT
  = qw(capture_state check_automounter is_patch_needed add_test_repositories disable_test_repositories enable_test_repositories
  ssh_add_test_repositories remove_test_repositories advance_installer_window get_patches check_patch_variables);
use constant ZYPPER_PACKAGE_COL => 1;
use constant OLD_ZYPPER_STATUS_COL => 4;
use constant ZYPPER_STATUS_COL => 5;

sub capture_state {
    my ($state, $y2logs) = @_;
    if ($y2logs) {    #save y2logs if needed
        my $compression = is_sle('=12-sp1') ? 'bz2' : 'xz';
        assert_script_run "save_y2logs /tmp/y2logs_$state.tar.$compression";
        upload_logs "/tmp/y2logs_$state.tar.$compression";
        save_screenshot();
    }
    #upload ip status
    script_run("ip a | tee /tmp/ip_a_$state.log");
    upload_logs("/tmp/ip_a_$state.log");
    save_screenshot();
    script_run("ip r | tee /tmp/ip_r_$state.log");
    upload_logs("/tmp/ip_r_$state.log");
    save_screenshot();
    #upload dmesg
    script_run("dmesg > /tmp/dmesg_$state.log");
    upload_logs("/tmp/dmesg_$state.log");
    #upload journal
    script_run("journalctl -b -o short-precise > /tmp/journal_$state.log");
    upload_logs("/tmp/journal_$state.log");
}

sub check_automounter {
    my $ret = 1;
    while ($ret) {
        script_run(qq{[ \$(ls -ld /mounts | cut -d" " -f2) -gt 20 ]; echo automount-\$?- > /dev/$serialdev}, 0);
        $ret = wait_serial(qr/automount-\d-/);
        ($ret) = $ret =~ /automount-(\d)/;
        if ($ret) {
            script_run("rcypbind restart");
            script_run("rcautofs restart");
            sleep 5;
        }
    }
}

sub is_patch_needed {
    my $patch = shift;
    my $install = shift // 0;

    return '' if !($patch);

    my $patch_status = script_output("zypper -n info -t patch $patch");
    if ($patch_status =~ /Status\s*:\s+[nN]ot\s[nN]eeded/) {
        return $install ? $patch_status : 1;
    }
}

# Function that will add all test repos
sub add_test_repositories {
    my $counter = 0;

    my $oldrepo = get_var('PATCH_TEST_REPO');
    my @repos = split(/,/, get_var('MAINT_TEST_REPO', ''));
    my $gpg = get_var('BUILD') =~ m/^MR:/ ? "-G" : "";
    my $system_repos = script_output('zypper lr -u');

    if (is_sle('=12-SP2')) {
        my $arch = get_var('ARCH');
        my $url = "http://dist.suse.de/ibs/SUSE/Updates/SLE-SERVER/12-SP2-LTSS-ERICSSON/$arch/update/";
        # don't add repo when it's already present
        unless ($system_repos =~ /$url/) {
            zypper_call("--no-gpg-checks ar -f $gpg $url '12-SP2-LTSS-ERICSSON-Updates'");
        }
    }
    if (is_sle('=12-SP3')) {
        my $arch = get_var('ARCH');
        my $url = "http://dist.suse.de/ibs/SUSE/Updates/SLE-SERVER/12-SP3-LTSS-TERADATA/$arch/update/";
        # don't add repo when it's already present
        unless ($system_repos =~ /$url/) {
            zypper_call("--no-gpg-checks ar -f $gpg $url '12-SP3-LTSS-TERADATA-Updates'");
        }
    }
    # shim update will fail with old grub2 due to old signature
    if (get_var('UEFI')) {
        zypper_call('up grub2 grub2-x86_64-efi kernel-default');
    }

    # Be carefull. If you have defined both variables, the PATCH_TEST_REPO variable will always
    # have precedence over MAINT_TEST_REPO. So if MAINT_TEST_REPO is required to be installed
    # please be sure that the PATCH_TEST_REPO is empty.
    @repos = split(',', $oldrepo) if ($oldrepo);

    if (get_var("NO_ADD_MAINT_TEST_REPOS")) {
        # If we don't want to add again (and duplicate) repositories that were already added during install,
        # we still need to disable gpg check for all repositories.
        zypper_call('--gpg-auto-import-keys ref', timeout => 1400, exitcode => [0, 106]);
    } else {
        for my $var (@repos) {
            # don't add repo when it's already present
            next if $system_repos =~ /$var/;
            zypper_call("--no-gpg-checks ar -f $gpg -n 'TEST_$counter' $var 'TEST_$counter'");
            $counter++;
        }
    }

    # refresh repositories, inf 106 is accepted because repositories with test
    # can be removed before test start
    zypper_call('ref', timeout => 1400, exitcode => [0, 106]);

    # return the count of repos-1 because counter is increased also on last cycle
    return --$counter;
}

sub disable_test_repositories {
    my $count = scalar(shift);

    record_info 'Disable update repos';
    for my $i (0 .. $count) {
        zypper_call("mr -d -G 'TEST_$i'");
    }
}

sub enable_test_repositories {
    my $count = scalar(shift);

    record_info 'Enable update repos';
    for my $i (0 .. $count) {
        zypper_call("mr -e -G 'TEST_$i'");
    }
}

# Function that will add all test repos to SSH guest
sub ssh_add_test_repositories {
    my $host = shift;
    my $counter = 0;

    my $oldrepo = get_var('PATCH_TEST_REPO');
    my @repos = split(/,/, get_var('MAINT_TEST_REPO', ''));
    # Be carefull. If you have defined both variables, the PATCH_TEST_REPO variable will always
    # have precedence over MAINT_TEST_REPO. So if MAINT_TEST_REPO is required to be installed
    # please be sure that the PATCH_TEST_REPO is empty.
    @repos = split(',', $oldrepo) if ($oldrepo);

    for my $var (@repos) {
        assert_script_run("ssh root\@$host 'zypper -n --no-gpg-checks ar -f -n TEST_$counter $var TEST_$counter'");
        $counter++;
    }
    # refresh repositories, inf 106 is accepted because repositories with test
    # can be removed before test start
    my $ret = script_run("ssh root\@$host 'zypper -n --gpg-auto-import-keys ref'", 240);
    die "Zypper failed with $ret" if ($ret != 0 && $ret != 106);
}

# Function that will remove all test repos
sub remove_test_repositories {

    type_string 'repos=($(zypper lr -e - | grep "name=TEST|baseurl=ftp" | cut -d= -f2)); if [ ${#repos[@]} -ne 0 ]; then zypper rr ${repos[@]}; fi';
    send_key 'ret';
}

sub advance_installer_window {
    my ($screenName) = @_;
    my $build = get_var('BUILD');

    send_key $cmd{next};
    my %handlers;

    $handlers{$screenName} = sub { 1 };
    $handlers{'unable-to-create-repo'} = sub {
        die 'Unable to create repository';
    };
    $handlers{'cannot-access-installation-media'} = sub {
        send_key "alt-y";
        return 0;
    };

    if ($build =~ m/^MR:/) {
        $handlers{'import-untrusted-gpg-key'} = sub {
            send_key "alt-t";
            return 0;
        };
    }

    unless (handle_screen([keys %handlers], \%handlers, assert => 0, timeout => 60)) {
        send_key_until_needlematch $screenName, $cmd{next}, 6, 60;
        record_soft_failure 'Retry most probably due to network problems poo#52319 or failed next click';
    }
}

# Get list of patches
sub get_patches {
    my ($incident_id, $repo) = @_;

    # Replace comma by space, repositories must be divided by space
    $repo =~ tr/,/ /;

    # Search for patches by incident, exclude not needed
    my $patches = script_output("zypper patches -r $repo");
    my @patch_list;
    my $status_col = ZYPPER_STATUS_COL;

    if (is_sle('<12-SP2')) {
        $status_col = OLD_ZYPPER_STATUS_COL;
    }

    for my $line (split /\n/, $patches) {
        my @tokens = split /\s*\|\s*/, $line;
        next if $#tokens < max(ZYPPER_PACKAGE_COL, $status_col);
        my $packname = $tokens[ZYPPER_PACKAGE_COL];
        push @patch_list, $packname if $packname =~ m/$incident_id/ &&
          'needed' eq lc $tokens[$status_col];
    }

    return join(' ', @patch_list);
}

# Check variables for patch definition
sub check_patch_variables {
    my ($patch, $incident_id) = @_;

    if ($patch && $incident_id) {
        die('It is not possible to have defined INCIDENT_PATCH and INCIDENT_ID at the same time');
    }
    elsif (!$patch && !$incident_id) {
        die("Missing INCIDENT_PATCH or INCIDENT_ID");
    }
}

1;
