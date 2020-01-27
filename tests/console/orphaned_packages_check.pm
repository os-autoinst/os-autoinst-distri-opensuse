# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for any orphaned packages. There should be none in fully
#   supported systems
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: poo#19606

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_upgrade';

# Performing a DVD/Offline system upgrade cannot update
# all potential packages already present on the SUT
# A subsequent 'zypper dup' is necessary to ensure
# all packages available in the repo are up-to-date
# poo#61829
sub is_offline_upgrade_or_livecd {
    return (!get_var('ONLINE_MIGRATION') && is_upgrade) || get_var('LIVECD');
}

# Compare detected orphans with whitelisted if any
sub compare_orphans_lists {
    my %args = @_;

    record_info('Detected Orphans', "@{ $args{zypper_orphans} }");
    record_info('Orphans whitelisted',
        $args{whitelist} // 'No orphans whitelisted within the test suite',
        result => $args{whitelist} ? 'ok' : 'fail');

    # Packages do not have a whistespace in their labels
    # A trailing or leading whitespace introduced along the path has to be removed
    # Usually it can happen on ssh like consoles (e.g. tunnel-console)
    my @not_handled_orphans = ();
    if ($args{whitelist}) {
        # Remove duplicate packages from the whitelist
        my %wl = map { $_ => 1 } (split(',', $args{whitelist}));
        @not_handled_orphans = grep {
            my $p = $_;
            $p =~ s/\s+//g;
            !$wl{$p};
        } @{$args{zypper_orphans}};
    } else { @not_handled_orphans = @{$args{zypper_orphans}}; }

    record_info('Missing', (@not_handled_orphans) ? ("@not_handled_orphans", result => 'fail') : 'None');

    return ((scalar @not_handled_orphans) == 0);
}

sub run {
    select_console 'root-console';

    record_info('Upgraded?',
        'Has the SUT been upgraded or installed from LIVECD? Both can possibly cause orphans',
        result => (is_offline_upgrade_or_livecd) ? 'ok' : 'fail');

    # Orphans are also expected on JeOS without SDK module (jeos-firstboot, jeos-license and live-langset-data)
    # Save the orphaned packages list to one log file and upload the log, so QA can use this log to report bug
    my @orphans = split('\n',
        script_output q[zypper -qs 11 pa --orphaned | 
                            grep -v "\(release-DVD\|release-dvd\|openSUSE-release\|skelcd\)" |
                            tee -a /tmp/orphaned.log | awk 'NR>2 {print $3}'], proceed_on_failure => 1);

    if (((scalar @orphans) > 0) && !is_offline_upgrade_or_livecd) {
        compare_orphans_lists(zypper_orphans => \@orphans,
            whitelist => get_var('ZYPPER_WHITELISTED_ORPHANS')) or
          die "There have been unexpected orphans detected!";
    }
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    (script_run q{test -s /tmp/orphaned.log}) ? $self->export_logs() : upload_logs '/tmp/orphaned.log';

}

1;
