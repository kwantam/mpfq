<?xml version='1.0'?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version='1.0'>

<xsl:include href="custom.xsl"/>

<!-- disable the tex hackery, we do all this on our own beforehand -->
<xsl:template match="*" mode="collect.tex.math"/>

<!-- use this to bypass the imagedata layer, which is terribly incapable
for now -->
<xsl:template match="math">
  <xsl:element name="span" namespace="http://www.w3.org/1999/xhtml">
    <xsl:attribute name="class">inlinemediaobject</xsl:attribute>
    <xsl:element name="img" namespace="http://www.w3.org/1999/xhtml">
      <xsl:if test="@image">
        <xsl:attribute name="src">
          <xsl:value-of select="@image"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:variable name="tex">
          <xsl:value-of select="."/>
      </xsl:variable>
      <xsl:attribute name="alt">
        <xsl:choose>
          <xsl:when test="$tex != ''">
            <xsl:text>\(</xsl:text>
            <xsl:value-of select="$tex"/>
            <xsl:text>\)</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>math image</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:if test="@style">
        <xsl:attribute name="style">
          <xsl:value-of select="@style"/>
        </xsl:attribute>
      </xsl:if>
    </xsl:element>
  </xsl:element>
</xsl:template>

</xsl:stylesheet>
