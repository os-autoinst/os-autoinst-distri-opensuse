# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Offline migration using the DVD medium as repository with
#   `zypper dup`
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # precompile regexes
    my $zypper_dup_continue      = qr/^Continue\? \[y/m;
    my $zypper_dup_conflict      = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_dup_notifications = qr/^View the notifications now\? \[y/m;
    my $zypper_dup_error         = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_dup_finish        = qr/^There are some running programs that might use files|^ZYPPER-DONE/m;
    my $zypper_packagekit        = qr/^Tell PackageKit to quit\?/m;
    my $zypper_packagekit_again  = qr/^Try again\?/m;
    my $zypper_repo_disabled     = qr/^Repository '[^']+' has been successfully disabled./m;
    my $zypper_installing        = qr/Installing: \S+/;
    my $zypper_dup_fileconflict  = qr/^File conflicts .*^Continue\? \[y/ms;
    my $zypper_retrieving        = qr/Retrieving \S+/;
    my $zypper_check_conflicts   = qr/Checking for file conflicts: \S+/;

    # This is just for reference to know how the network was configured prior to the update
    script_run "ip addr show";
    save_screenshot;

    # before disable we need to have cdrkit installed to get proper iso appid
    script_run "zypper -n in cdrkit-cdrtools-compat";
    # Disable all repos, so we do not need to remove one by one
    # beware PackageKit!
    script_run("zypper modifyrepo --all --disable | tee /dev/$serialdev", 0);
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
        if (check_var('TEST', "migration_zdup_online_sle12_ga")) {
            my $flavor  = get_var("FLAVOR");
            my $version = get_var("VERSION");
            my $build   = get_var("BUILD");
            my $arch    = get_var("ARCH");
            $defaultrepo = "ftp://openqa.suse.de/SLE-$version-$flavor-$arch-Build$build-Media1";
        }
        else {
            # SUSEMIRROR not set, zdup from attached ISO
            my $build  = get_var("BUILD");
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
            # if that fails, e.g. if volume descriptor too long, just try /dev/sr0
            $defaultrepo = "dvd:/?devices=\${dev:-/dev/sr0}";
        }
    }

    my $nr = 1;
    foreach my $r (split(/\+/, get_var("ZDUPREPOS", $defaultrepo))) {
        assert_script_run("zypper -n addrepo \"$r\" repo$nr");
        $nr++;
    }
    assert_script_run("zypper -n refresh", 240);

    script_run("(zypper dup -l;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);

    $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error], 240);
    while ($out) {
        if ($out =~ $zypper_dup_conflict) {
            if (get_var("WORKAROUND_DEPS")) {
                record_soft_failure 'workaround dependencies';
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
    my $post_checks = [
        $zypper_dup_finish,       $zypper_installing,      $zypper_dup_notifications, $zypper_dup_error,
        $zypper_dup_fileconflict, $zypper_check_conflicts, $zypper_retrieving
    ];
    $out = wait_serial($post_checks, 480);
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
            $out = wait_serial($post_checks, 240);
            next;
        }
        elsif ($out =~ $zypper_dup_fileconflict) {
            #             record_soft_failure;
            #             send_key 'y';
            #             send_key 'ret';
            $self->result('fail');
            save_screenshot;
            return;
        }
        else {
            # probably to avoid hitting black screen on video
            send_key 'shift';
        }
        save_screenshot;
        $out = wait_serial([$zypper_dup_finish, $zypper_installing, $zypper_dup_notifications, $zypper_dup_error], 240);
    }

    assert_screen "zypper-dup-finish";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
