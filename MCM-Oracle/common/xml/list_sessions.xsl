<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
    <xsl:for-each select="/MonitorList/MXSESSION/Process">
        <xsl:value-of select="NPID"/>:<xsl:text/>
        <xsl:value-of select="Host"/>:<xsl:text/>
        <xsl:value-of select="User"/>:<xsl:text/>
        <xsl:value-of select="Group"/>
        <xsl:text>&#10;</xsl:text>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
