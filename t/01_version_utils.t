use strict;
use warnings;
use Test::More;
use FindBin;

# This is required to be able to read
# packages in distri's lib/ folder.
# Alternatively it can be supplied as -I option
# while running prove.
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib");

use testapi qw(check_var get_var set_var);
use version_utils 'is_caasp';

subtest 'is_caasp' => sub {

    set_var('DISTRI', 'caasp');

    ok is_caasp;

    set_var('DISTRI', undef);

    ok !is_caasp;
};

done_testing;
