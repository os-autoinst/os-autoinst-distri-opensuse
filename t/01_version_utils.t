use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;

use testapi qw(check_var get_var set_var);

subtest 'check_version' => sub {
    # compare versions if possible
    ok version_utils::check_version($_, '15.5'),  "check $_, 15.5" for qw(>15.0 <15.10);
    ok !version_utils::check_version($_, '15.5'), "check $_, 15.5" for qw(=15.50 >=15.10);

    # compare strings if not
    ok version_utils::check_version($_, 'klm'), "check $_, klm" for qw(abc+ 1+ =KLM);

    # die if regex does not match
    for (qw(1.3+ 11-sp1+)) {
        dies_ok { version_utils::check_version($_, '12-sp3', qr/^\d{2}/) } "check $_, 12-sp3, ^\\d{2}";
    }

    # die if compare symbols are wrong
    for (qw(=1.3+ >1.3+ <>1.3 > 12 abc)) {
        dies_ok { version_utils::check_version($_, '12-sp3') } "check $_, 12-sp3";
    }

    ok version_utils::check_version($_, '10.5.0-Maria'), "check $_, 15.5"   for qw(>10.4.4 10.4+ >=10.4-Maria >10.3.0-MySQL);
    ok !version_utils::check_version($_, '10.5.1'),      "check $_, 10.5.1" for qw(=10.4.9 <10.5.0);
};

subtest 'is_caasp' => sub {
    use version_utils 'is_caasp';

    set_var('DISTRI', 'caasp');

    ok is_caasp;

    set_var('DISTRI', undef);

    ok !is_caasp;
};

subtest 'is_leap' => sub {
    use version_utils 'is_leap';

    set_var('DISTRI', 'opensuse');
    ok !is_leap, "check !is_leap";

    set_var('VERSION', '42.3');
    ok is_leap, "check is_leap";
    ok is_leap($_),  "check $_" for qw(=42.3 <=15.0 >42.1 >=42.3);
    ok !is_leap($_), "check $_" for qw(=15.0 >42.3 <42.3 <13.0);
    dies_ok { is_leap $_ } "check $_" for (qw(13+ <=15 =42 42+ 42.1:S:A+ =42.3:S:A));

    set_var('VERSION', '42.3:S:A');
    ok is_leap($_), "check $_" for qw(=42.3 <=15.0);
};

subtest 'is_sle' => sub {
    use version_utils 'is_sle';

    set_var('DISTRI', 'opensuse');
    ok !is_sle, "check !is_sle";

    set_var('DISTRI', 'sle');
    ok is_sle, "check is_sle";

    set_var('VERSION', '12');
    ok is_sle, "check is_sle";
    ok is_sle($_),  "check $_" for qw(=12 >=12 <=12 12+ <12-sp1 <=15-sp2 <15 11+ >11 >=11 11-sp1+);
    ok !is_sle($_), "check $_" for qw(>12 <12 >12-sp1 15-sp1+ >=15 <=11 <11-sp2);
    dies_ok { is_sle $_ } "check $_" for (qw(12 15- =12+ >1 1-sp1+ <15+ 15-sp1));

    set_var('VERSION', '12-SP2');
    ok is_sle($_), "check $_" for qw(=12-sp2 =12-sP2 <=15 >11-sp3 <12-sp3 >12-sp1 <12-SP3 >12-SP1);
};

done_testing;
