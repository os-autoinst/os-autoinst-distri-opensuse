# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use testapi;
use LWP::UserAgent;

# poo#11518 - deregister system after job finishes
if (get_var("SCC_DEREGISTER")) {
    diag "de-registration from SCC";

    my @credentials = split /\r\n/, get_var("SCC_DEREGISTER");

    my $ua = LWP::UserAgent->new;
    $ua->credentials('scc.suse.com:443', 'SCC Connect API', $credentials[0], $credentials[1]);
    my $response = $ua->delete('https://scc.suse.com/connect/systems');

    if (!$response->is_success) {
        die $response->status_line;
    }
}
else {
    diag "de-registration not needed";
}

1;
