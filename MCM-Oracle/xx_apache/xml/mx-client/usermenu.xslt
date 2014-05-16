<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- top level xml tag -->
<xsl:template match="usermenu">
<html>
<head>
<title>
  <xsl:value-of select="title" /> - <xsl:value-of select="environment" />
</title>
  <link rel="stylesheet" type="text/css" href="/css/style.css" />
</head>
<body>
  <h1>Environments</h1>
  <table border="0" cellspacing="1" cellpadding="3" width="100%" bgcolor="#000066">
  <thead>
    <tr align="center">
    <th style="color: #FFFFFF;" width="100px">Env</th>
    <th style="color: #FFFFFF;" width="100px">Category</th>
    <th style="color: #FFFFFF;" width="110px">Title</th>
    <th style="color: #FFFFFF;">Link / Action / Parameter</th>
    <th style="color: #FFFFFF;">Files</th>
    <th style="color: #FFFFFF;">ID</th>
    </tr>
  </thead>
  <tbody>
    <xsl:apply-templates select="channel" />
  </tbody>
  </table>
  <h1>Usermenu</h1>
  <p>Titel: <xsl:value-of select="title" /></p>
  <p>Filename: <xsl:value-of select="name" /></p>
  <p>Environment: <xsl:value-of select="environment" /></p>
  <p>Session user: <xsl:value-of select="username" /></p>
  <p>Reporting user: <xsl:value-of select="queryuser" /></p>
  <p>Local storage: <xsl:value-of select="launchpath" /></p>
  <h1>Application</h1>
  <xsl:apply-templates select="files" />
</body>
</html>
</xsl:template>

<xsl:template match="channel">
<tr align="center">
<td colspan="1">
<h2>
<a>
<xsl:attribute name="href">
<xsl:value-of select="link" /><xsl:value-of select="../name" />
</xsl:attribute>
<xsl:value-of select="@environment" />
</a>
</h2>
</td>
<td colspan="4">
<xsl:value-of select="description" />
</td>
<td>
<xsl:if test="status='Disabled'">
<xsl:value-of select="status" />
</xsl:if>
</td>
</tr>
<xsl:apply-templates select="item" />
</xsl:template>

<xsl:template match="item">
<tr valign="top">
<td></td>
<td>
  <xsl:value-of select="@category" />
</td>
<td>
  <xsl:value-of select="title" />
</td>
<td>
  <xsl:if test="@category='URL'">
  <a>
    <xsl:attribute name="href">
      <xsl:value-of select="link" />
    </xsl:attribute>
    <xsl:attribute name="target">
      <xsl:value-of select="@id" />
    </xsl:attribute>
    <xsl:value-of select="link" />
  </a>
  </xsl:if>
  <xsl:if test="not(@category='URL')">
    <xsl:value-of select="link" />
    <xsl:value-of select="action" />
  </xsl:if>
  <xsl:value-of select="parameter" />
  <xsl:if test="@category='Launch'">
    <br /><xsl:text>Download from </xsl:text>
    <xsl:value-of select="./files/@remoteprefix" />
  </xsl:if>
</td>
<td>
  <xsl:if test="@category='Launch' or @category='Console'">
    <xsl:apply-templates select="files" />
  </xsl:if>
</td>
<td>
  <xsl:value-of select="@id" />
</td>
</tr>
</xsl:template>

<xsl:template match="files">
  <xsl:apply-templates select="file" />
</xsl:template>

<xsl:template match="file">
  <a>
    <xsl:attribute name="href">
      <xsl:value-of select="../@remoteprefix" />
      <xsl:value-of select="." />
      <xsl:value-of select="@fwsuffix" />
    </xsl:attribute>
    <xsl:attribute name="target">
      <xsl:value-of select="../@id" />
    </xsl:attribute>
    <xsl:value-of select="." />
    <xsl:value-of select="@suffix" />
  </a>
  <br />
</xsl:template>

</xsl:stylesheet>
