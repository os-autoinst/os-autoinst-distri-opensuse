# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: prepare repos for zdup.test
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call OPENQA_FTP_URL);

sub run {
    my $self = shift;

    # precompile regexes
    my $zypper_packagekit       = qr/^Tell PackageKit to quit\?/m;
    my $zypper_packagekit_again = qr/^Try again\?/m;
    my $zypper_repo_disabled    = qr/^Repository '[^']+' has been successfully disabled./m;

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
            my $flavor  = get_var("FLAVOR");
            my $version = get_var("VERSION");
            my $build   = get_var("BUILD");
            my $arch    = get_var("ARCH");
            $defaultrepo = "$utils::OPENQA_FTP_URL/SLE-$version-$flavor-$arch-Build$build-Media1";
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
            # get all attached ISOs including addons' as zdup dup repos
            my $srx = script_output("ls -al /dev/disk/by-label | grep -E /sr[0-9]+ | wc -l");
            for my $n (0 .. $srx - 1) {
                $defaultrepo .= "dvd:/?devices=\${dev:-/dev/sr$n}+";
            }
        }
    }

    my $nr = 1;
    foreach my $r (split(/,/, get_var('ZDUPREPOS', $defaultrepo))) {
        zypper_call("--no-gpg-checks ar \"$r\" repo$nr");
        $nr++;
    }
    zypper_call '--gpg-auto-import-keys ref';
}

1;
