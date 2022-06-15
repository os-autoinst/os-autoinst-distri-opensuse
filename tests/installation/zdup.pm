# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Offline migration using the DVD medium as repository with
#   `zypper dup`
# Maintainer: QE LSG <qa-team@suse.de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils qw(OPENQA_FTP_URL zypper_call);

sub run {
    my $self = shift;

    # precompile regexes
    my $zypper_dup_continue = qr/^Continue\? \[y/m;
    my $zypper_dup_conflict = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_dup_notifications = qr/^View the notifications now\? \[y/m;
    my $zypper_dup_error = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_dup_finish = qr/^There are some running programs that might use files|ZYPPER-DONE/m;
    my $zypper_packagekit = qr/^Tell PackageKit to quit\?/m;
    my $zypper_packagekit_again = qr/^Try again\?/m;
    # Check return message about disable all repos or all repos has been disabled
    my $zypper_repo_disabled = qr/^Repository '[^']+' has been successfully disabled.|Nothing to change for repository '[^']+'./m;
    my $zypper_dup_fileconflict = qr/^File conflicts .*^Continue\? \[y/ms;
    my $zypper_retrieving = qr/Retrieving: \S+/;
    my $zypper_check_conflicts = qr/Checking for file conflicts: \S+/;

    # This is just for reference to know how the network was configured prior to the update
    script_run "ip addr show";
    save_screenshot;

    # Disable all repos, so we do not need to remove one by one
    # beware PackageKit!
    script_run("zypper -n mr --all --disable | tee /dev/$serialdev", 0);
    my $out = wait_serial([$zypper_packagekit, $zypper_repo_disabled], 120);
    while ($out) {
        if ($out =~ $zypper_packagekit || $out =~ $zypper_packagekit_again) {
            send_key 'y';
            send_key 'ret';
        }
        elsif ($out =~ $zypper_repo_disabled) {
            last;
        }
        $out = wait_serial([$zypper_repo_disabled, $zypper_packagekit_again, $zypper_packagekit], 120);
    }
    unless ($out) {
        save_screenshot;
        $self->result('fail');
        return;
    }

    my $defaultrepo;
    if (get_var('SUSEMIRROR')) {
        $defaultrepo = "http://" . get_var("SUSEMIRROR");
    }
    else {
        #SUSEMIRROR not set, zdup from ftp source for online migration
        if (get_var('TEST') =~ /migration_zdup_online_sle12_ga/) {
            my $flavor = get_var("FLAVOR");
            my $version = get_var("VERSION");
            my $build = get_var("BUILD");
            my $arch = get_var("ARCH");
            $defaultrepo = "$utils::OPENQA_FTP_URL/SLE-$version-$flavor-$arch-Build$build-Media1";
        }
        else {
            # SUSEMIRROR not set, zdup from attached ISO
            my $build = get_var("BUILD");
            my $flavor = get_var("FLAVOR");
            script_run "ls -al /dev/disk/by-label";
            my $isoinfo = "isoinfo -d -i /dev/\$dev | grep \"Application id\" | awk -F \" \" '{print \$3}'";

            script_run "dev=;
                       for i in sr0 sr1 sr2 sr3 sr4 sr5; do
                       label=`$isoinfo`
                       case \$label in
                           *$flavor-*$build*) echo \"\$i match\"; dev=\"/dev/\$i\"; break;;
                           *) continue;;
                       esac
                       done
                       [ -z \$dev ] || echo \"found dev \$dev with label \$label\"";
            # get all attached ISOs including addons' as zdup dup repos
            my $srx = script_output("ls -al /dev/disk/by-label | grep -E /sr[0-9]+ | wc -l");
            for my $n (0 .. $srx - 1) {
                $defaultrepo .= "dvd:/?devices=\${dev:-/dev/sr$n},";
            }
        }
    }

    my $nr = 1;
    foreach my $r (split(/,/, get_var('ZDUPREPOS', $defaultrepo))) {
        $r =~ s/^\s+|\s+$//g;
        zypper_call("--no-gpg-checks ar \"$r\" repo$nr");
        $nr++;
    }
    zypper_call '--gpg-auto-import-keys ref';

    script_run("(zypper dup -l;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);

    $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error], 240);
    while ($out) {
        if ($out =~ $zypper_dup_conflict) {
            if (check_var("WORKAROUND_DEPS", '1')) {
                record_info 'workaround dependencies';
                send_key '1';
                send_key 'ret';
            }
            else {
                $self->result('fail');
                save_screenshot;
                return;
            }
        }
        elsif ($out =~ $zypper_dup_continue) {
            # confirm zypper dup continue
            send_key 'y';
            send_key 'ret';
            last;
        }
        elsif ($out =~ $zypper_dup_error) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        save_screenshot;
        $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error], 120);
    }
    unless ($out) {
        $self->result('fail');
        save_screenshot;
        return;
    }

    # wait for zypper dup finish, accept failures in meantime
    my $post_checks = [$zypper_dup_finish, $zypper_dup_notifications, $zypper_dup_error, $zypper_dup_fileconflict, $zypper_check_conflicts, $zypper_retrieving];
    $out = wait_serial($post_checks, 3600);
    while ($out) {
        if ($out =~ $zypper_dup_notifications) {
            send_key 'n';    # do not show notifications
            send_key 'ret';
        }
        elsif ($out =~ $zypper_dup_error) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        elsif ($out =~ $zypper_dup_finish) {
            last;
        }
        elsif ($out =~ $zypper_retrieving or $out =~ $zypper_check_conflicts) {
            # probably to avoid hitting black screen on video
            send_key 'shift';
            # continue but do a check again
            $out = wait_serial($post_checks, 3600);
            next;
        }
        elsif ($out =~ $zypper_dup_fileconflict) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        else {
            # probably to avoid hitting black screen on video
            send_key 'shift';
        }
        save_screenshot;
        $out = wait_serial([$zypper_dup_finish, $zypper_dup_notifications, $zypper_dup_error], 3600);
    }

    assert_screen "zypper-dup-finish";
}

sub post_fail_hook {
    my $self = shift;
    $utils::IN_ZYPPER_CALL = 1;
    $self->export_logs();
}

1;
