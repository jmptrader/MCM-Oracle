<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
    <xsl:for-each select="/MonitorList/*[not(self::MXSESSION)]/Process">
        <xsl:value-of select="NickName"/>|<xsl:text/>
        <xsl:value-of select="InstallationCode"/>|<xsl:text/>
        <xsl:value-of select="Description"/>|<xsl:text/>
        <xsl:value-of select="CreationTime"/>|<xsl:text/>
        <xsl:value-of select="Host"/>|<xsl:text/>
        <xsl:value-of select="NPID"/>|<xsl:text/>
        <xsl:value-of select="PID"/>
        <xsl:text>&#10;</xsl:text>
    </xsl:for-each>
    <xsl:for-each select="/MonitorList/MX_MIDDLEWARE_SERVICES/*">
        <xsl:value-of select="NickName"/>|<xsl:text/>
        <xsl:value-of select="InstallationCode"/>|<xsl:text/>
        <xsl:value-of select="Description"/>|<xsl:text/>
        <xsl:value-of select="CreationTime"/>|<xsl:text/>
        <xsl:value-of select="Host"/>|<xsl:text/>
        <xsl:value-of select="NPID"/>|<xsl:text/>
        <xsl:value-of select="LID"/>
        <xsl:text>&#10;</xsl:text>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
