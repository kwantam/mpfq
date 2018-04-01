<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version='1.0'>

  <!-- encoding of generated file(s) -->
<xsl:param name="chunker.output.encoding" select="'UTF-8'"/>

<xsl:param name="paper.type" select="'A4'"/>

  <!-- allow pass-through of TeX ; not used for xhtml now that I've
       simplified the innards of processing, but both are absolutely
       necessary for .fo output
    -->
<xsl:param name="passivetex.extensions" select="1"/>
<xsl:param name="tex.math.in.alt" select="'latex'"/>

</xsl:stylesheet>
