SHELL := /bin/bash

#Common prefixes

prefix = /usr
datarootdir = $(prefix)/share
docdir = $(datarootdir)/doc/cppreference-doc-en
bookdir = $(datarootdir)/devhelp/books/cppreference-doc-en

#Version

VERSION=20111225

#STANDARD RULES

all: doc_devhelp doc_qch

clean:
	rm -rf "output/"
	rm -f "cppreference-doc-en.devhelp2"
	rm -f "cppreference-doc-en.qch"
	rm -f "qch-help-project.xml"
	rm -f "qch-files.xml"

check:

dist:
	mkdir -p "cppreference-doc-$(VERSION)"
	cp -r "reference" "cppreference-doc-$(VERSION)"
	find . -maxdepth 1 -type f -not -iname "*.tar.gz" -exec cp '{}' "cppreference-doc-$(VERSION)" \;
	tar czf "cppreference-doc-$(VERSION).tar.gz" "cppreference-doc-$(VERSION)" 
	rm -rf "cppreference-doc-$(VERSION)"

install:
	#do not install the ttf files
	pushd "output"; find . -type f -not -iname "*.ttf" \
		-exec install -DT -m 644 '{}' "$(DESTDIR)$(docdir)/{}" \; ; popd

	install -DT -m 644 cppreference-doc-en.devhelp2 "$(DESTDIR)$(bookdir)/cppreference-doc-en.devhelp2"

uninstall:
	rm -rf "$(DESTDIR)$(docdir)"
	rm -rf "$(DESTDIR)$(bookdir)"

#WORKER RULES

doc_devhelp: cppreference-doc-en.devhelp2 

doc_qch: cppreference-doc-en.qch

#build the .devhelp2 index
cppreference-doc-en.devhelp2: init_html
	xsltproc index2devhelp.xsl index-functions.xml > "cppreference-doc-en.devhelp2"

	#correct links in the .devhelp2 index
	pushd "output"; find . -iname "*.html" -exec ../build_devhelp.sh '{}' \; ; popd

#build the .qch (QT help) file
cppreference-doc-en.qch: qch-help-project.xml
	#qhelpgenerator only works if the project file is in the same directory as the documentation 
	cp qch-help-project.xml output/qch.xml
	pushd "output"; qhelpgenerator qch.xml -o "../cppreference-doc-en.qch"; popd
	rm -f output/qch.xml

qch-help-project.xml: cppreference-doc-en.devhelp2
	#build the file list
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><files>" > "qch-files.xml"
	pushd "output"; find . -type f -not -iname "*.ttf" \
		-exec echo "<file>"'{}'"</file>" >> "../qch-files.xml" \; ; popd                
	echo "</files>" >> "qch-files.xml"
	
	#create the project (copies the file list)
	xsltproc devhelp2qch.xsl cppreference-doc-en.devhelp2 > "qch-help-project.xml"

#copy the source documentation tree, since changes will be made inplace
init_html:
	rm -rf "output"
	cp -r "reference" "output"
	
	#remove useless UI elements
	find "output" -name "*.html" -exec ./fix_html.sh '{}' \;
	
	#append css modifications
	cat fix_html-css.css >> "output/en.cppreference.com/mwiki/index0cd5.css"
	
#redownloads the source documentation directly from en.cppreference.com
source:
	rm -rf "reference"
	mkdir "reference"
	
	pushd "reference" ; \
	httrack http://en.cppreference.com/w/ -%k -%s -n -%q0 \
	  -* +en.cppreference.com/* +upload.cppreference.com/* -*index.php\?* -*/Special:* -*/Talk:* -*/Help:* -*/File:* -*/Cppreference:* -*/WhatLinksHere:* -*action=* -*printable=* \
	  +*MediaWiki:Common.css* +*MediaWiki:Print.css* +*MediaWiki:Vector.css* +*title=-&action=raw* ;\
	popd
	
	#httrack apparently continues as a background process in non-interactive shells. 
	#Wait for it to complete
	while [[ ! -e "reference/hts-in_progress.lock" ]] ; do sleep 1; done
	while [[ -e "reference/hts-in_progress.lock" ]] ; do sleep 3; done
	
	#delete useless files
	rm -rf "reference/hts-cache"
	rm -f "reference/backblue.gif"
	rm -f "reference/fade.gif"
	rm -f "reference/hts-log.txt"
	rm -f "reference/index.html"
	
