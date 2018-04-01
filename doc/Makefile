
.PHONY: html all dvi pdf valid

# do not generate dvi and pdf by default, it takes ages...
all: valid html

pdf: doc.pdf
dvi: doc.dvi

XML:=$(filter-out doc.xml doc2.xml,$(wildcard *.xml))

valid:
	@xmllint --noout --xinclude --valid --postvalid doc.xml

doc2.xml: $(XML) ./parsemath.pl
	./parsemath.pl < doc.xml > $@
	xmllint --noout --xinclude --valid --postvalid doc2.xml

html: doc2.xml
	-@[ -d html ] || mkdir html
	xmllint --noout --xinclude --valid --postvalid doc2.xml
	xsltproc --nonet -o html/doc.html xsl/xhtml-nochunks.xsl doc2.xml
	xsltproc --nonet -o html/ xsl/xhtml.xsl doc2.xml

doc.fo: doc2.xml
	xmllint --noout --xinclude --valid --postvalid doc2.xml
	xsltproc --nonet -o doc.fo xsl/fo.xsl doc2.xml

doc.dvi: doc.fo
	xmltex doc.fo ; :
	xmltex doc.fo ; :
	rm -f doc.log doc.aux doc.out

doc.pdf: doc.fo
	pdfxmltex doc.fo ; :
	pdfxmltex doc.fo ; :
	rm -f doc.log doc.aux doc.out

clean:
	-rm -f doc.log doc.aux doc.out
	-rm -f doc.pdf doc.dvi doc.fo
	-rm -f doc2.xml
	-rm -f html/*.html
	-rm -f *~
