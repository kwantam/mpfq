<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version='1.0'>

<xsl:include href="custom.xsl"/>

<!--
        The two templates below are copied from:

        /usr/share/sgml/docbook/xsl-stylesheets-1.68.1-1.1/fo/math.xsl

        unfortunately, that file only has the template for
        inlineequation, not equation.
-->

<xsl:template match="math">
  <xsl:processing-instruction name="xmltex">
    <xsl:text>\(</xsl:text>
    <xsl:value-of select="."/>
    <xsl:text>\)</xsl:text>
  </xsl:processing-instruction>
</xsl:template>

<!--
<xsl:template match="inlineequation">
  <xsl:choose>
    <xsl:when test="$passivetex.extensions != 0 and $tex.math.in.alt != ''">
      <xsl:apply-templates select="alt[@role='tex'] | inlinemediaobject/textobject[@role='tex']">
        <xsl:with-param name="output.delims">
          <xsl:call-template name="tex.math.output.delims"/>
        </xsl:with-param>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
-->

<xsl:template match="equation">
  <xsl:choose>
    <xsl:when test="$passivetex.extensions != 0 and $tex.math.in.alt != ''">
      <xsl:apply-templates select="alt[@role='tex'] | mediaobject/textobject[@role='tex']">
        <xsl:with-param name="output.delims">
          <xsl:call-template name="tex.math.output.delims"/>
        </xsl:with-param>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
