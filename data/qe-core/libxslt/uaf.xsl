<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:lxl="http://xmlsoft.org/XSLT/namespace">
<xsl:output method="html" version="1.0" encoding="UTF-8" />
<xsl:key match="preceding::data" name="awesome-key" use="'awesome-value'" />
<xsl:variable name="global1" >
  <data>1</data>
  <data>2</data>
  <get-keys />
</xsl:variable>
<xsl:variable name="global2">
  <data>3</data>
  <data>4</data>
  <xsl:apply-templates select="lxl:node-set($global1)" />
</xsl:variable>
<xsl:template match="get-keys">
  <xsl:for-each select="key('awesome-key', 'awesome-value')">
    <p><xsl:value-of select="." /></p>
  </xsl:for-each>
</xsl:template>
<xsl:template match="root">
  <html>
    <body>
      <script>
        if (testRunner) {
          testRunner.dumpAsText();
        }
      </script>
      <xsl:for-each select="lxl:node-set($global2)/p">
        <xsl:copy-of select="." />
      </xsl:for-each>
    </body>
  </html>
</xsl:template>
</xsl:stylesheet>
