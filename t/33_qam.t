use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any none uniq);
use testapi;
use qam;

sub undef_vars {
    set_var($_, undef) for qw(
      BALAMB_TEST_REPOS
      WINHILL_TEST_REPOS
    );
}

subtest '[get_test_repos]' => sub {
    set_var('BALAMB_TEST_REPOS', 'Squall,Seifer');
    set_var('WINHILL_TEST_REPOS', 'Quistis,Rinoa');
    my $qam_mock = Test::MockModule->new('qam', no_auto => 1);
    $qam_mock->noop('set_var');

    my @repos = get_test_repos();
    undef_vars();

    ok((any { /Squall/ } @repos), 'Got "Squall" from BALAMB_TEST_REPOS');
    ok((any { /Seifer/ } @repos), 'Got "Seifer" from BALAMB_TEST_REPOS');
    ok((any { /Quistis/ } @repos), 'Got "Quistis" from WINHILL_TEST_REPOS');
    ok((any { /Rinoa/ } @repos), 'Got "Rinoa" from WINHILL_TEST_REPOS');
};

subtest '[get_test_repos] Test repo deduplicaton' => sub {
    set_var('BALAMB_TEST_REPOS', 'Squall,Seifer');
    set_var('WINHILL_TEST_REPOS', 'Quistis,Rinoa,Seifer');
    my $qam_mock = Test::MockModule->new('qam', no_auto => 1);
    $qam_mock->noop('set_var');

    my @repos = get_test_repos();
    undef_vars();
    is scalar @repos, scalar(uniq @repos), 'returned list is unique';
};

done_testing;
