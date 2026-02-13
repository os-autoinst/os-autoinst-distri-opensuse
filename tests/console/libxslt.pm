# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libxslt libxslt-tools
# Summary: Basic smoke test for libxslt, verifying xsltproc functionality.
# Maintainer: qe-core <qe-core@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

my $xmlfile = <<'EOT';
<doc>Success</doc>
EOT

my $xslfile = <<'EOT';
<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <output><xsl:value-of select="doc"/></output>
  </xsl:template>
</xsl:stylesheet>
EOT

my $securityfile = <<'EOT';
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <xsl:copy-of select="document('http://127.0.0.1/test.xml')"/>
  </xsl:template>
</xsl:stylesheet>
EOT

sub run {
    select_serial_terminal;

    # Install libxslt and its utilities
    zypper_call 'in libxslt-tools';
    assert_script_run 'wget --quiet ' . data_url('qe-core/libxslt/uaf.xml');
    assert_script_run 'wget --quiet ' . data_url('qe-core/libxslt/uaf.xsl');

    # Verify version and basic execution
    validate_script_output 'xsltproc --version', sub { m/Using libxml/ };

    # Create a simple XML file and a simple XSL stylesheet
    script_output("cat > test.xml <<'END'\n$xmlfile\nEND\n( exit \$?)");
    script_output("cat > test.xsl <<'END'\n$xslfile\nEND\n( exit \$?)");
    script_output("cat > security.xsl <<'END'\n$securityfile\nEND\n( exit \$?)");

    # Perform a transformation and validate the output
    validate_script_output 'xsltproc test.xsl test.xml', sub { m/Success/ };

    # Expect failure or warning when network access is disallowed
    validate_script_output 'xsltproc --nonet security.xsl test.xml 2>&1', sub { m/failed to load/i };

    for my $i (1 .. 5) {
        record_info("RUN $i", "Running xsltproc on uaf pair (iteration $i)");
        # Run and fail the test if xsltproc exits non-zero
        assert_script_run("xsltproc uaf.xsl uaf.xml", timeout => 300);
    }

    # Cleanup
    script_run 'rm test.xml test.xsl security.xsl uaf.xsl uaf.xml';
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs('test.xml');
    upload_logs('test.xsl');
    upload_logs('security.xsl');
}

1;
