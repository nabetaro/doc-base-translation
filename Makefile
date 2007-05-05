# vim:ts=2
# makefile for doc-base
# $Id: Makefile 68 2007-05-05 09:02:11Z robert $
#
# determine our version number
DEB_VERSION     := $(shell LC_ALL=C dpkg-parsechangelog | grep ^Version: | sed 's/^Version: *//')
DEB_DATE        := $(shell dpkg-parsechangelog | sed -n 's/^Date: *//p')
# pretty-print the date; I wish this was dynamic like the top-level makefile but oh well
DATE_EN         := $(shell LC_ALL=C     date --date="$(DEB_DATE)" '+%d %B, %Y')
generated       := install-docs install-docs.8 install-docs.html doc-base.txt doc-base.html/index.html

# build abstraction
install_file    := install -p -o root -g root -m 644
install_script  := install -p -o root -g root -m 755
install_dir     := install -o root -g root -m 755 -d
install_link    := ln -sf
compress        := gzip -9f

prefix          := /usr
sbindir         := $(prefix)/sbin
mandir          := $(prefix)/share/man/man8
sharedir        := $(prefix)/share/doc-base
perldir         := $(prefix)/share/perl5/Debian/DocBase
docdir          := $(prefix)/share/doc/doc-base
libdir          := /var/lib/doc-base
omfdir          := $(prefix)/share/omf



all: $(generated)


check-stamp: install-docs doc-base.sgml version.ent
	PERL5LIB="perl" perl -cw install-docs
	nsgmls -wall -s -E20 doc-base.sgml	# check SGML syntax
	touch $@


install-docs: install-docs.in
	sed -e '/use lib.*perl/d' \
	    -e 's/#VERSION#/$(DEB_VERSION)/' \
	    < $< > $@
	chmod 755 $@
	touch -r $< $@

install-docs.8: install-docs check-stamp
	pod2man --section=8 --center="Debian Utilities"		\
		--release="doc-base v$(DEB_VERSION)"		\
		--date="$(DATE_EN)"				\
		$< > $@

install-docs.html: install-docs check-stamp
	pod2html --title "install-docs reference" 		\
		< $< > $@
	rm -f pod2htm*.tmp

doc-base.txt: doc-base.sgml version.ent check-stamp
	debiandoc2text $<

doc-base.html/%: doc-base.sgml version.ent check-stamp
	debiandoc2html $<

version.ent: doc-base.sgml debian/changelog
	echo "<!ENTITY version \"$(DEB_VERSION)\">"    > $@
	echo "<!ENTITY date    \"$(DATE_EN)\">"        >> $@

clean:
	rm -f check-stamp build-stamp pod2htm*.tmp version.ent $(generated)
	rm -rf doc-base.html
	rm -f `find . -name "*~"`


install: $(generated)
	$(install_dir)                           $(DESTDIR)$(sbindir)
	$(install_script) install-docs           $(DESTDIR)$(sbindir)


	$(install_dir)                           $(DESTDIR)$(perldir)
	$(install_file) perl/Debian/DocBase/*.pm $(DESTDIR)$(perldir)
	$(install_dir)                           $(DESTDIR)$(perldir)/Programs
	$(install_file) perl/Debian/DocBase/Programs/*.pm \
	                                         $(DESTDIR)$(perldir)/Programs
	# validate installation correctness                                              
	PERL5LIB=$(DESTDIR)$(perldir)/../..      perl -cw $(DESTDIR)$(sbindir)/install-docs


	$(install_dir)                           $(DESTDIR)$(sharedir)
	$(install_file) data/doc-base.desc       $(DESTDIR)$(sharedir)/doc-base
	$(install_file) data/install-docs.desc   $(DESTDIR)$(sharedir)/install-docs-man


	$(install_dir)                           $(DESTDIR)$(sharedir)/data
	$(install_file) data/scrollkeeper.map    $(DESTDIR)$(sharedir)/data/


	$(install_dir)                           $(DESTDIR)$(omfdir)
	$(install_dir)                           $(DESTDIR)$(libdir)/omf
	$(install_dir)                           $(DESTDIR)$(libdir)/info
	rm -f                                    $(DESTDIR)$(omfdir)/doc-base
	$(install_link) $(libdir)/omf            $(DESTDIR)$(omfdir)/doc-base


	$(install_dir)                           $(DESTDIR)$(mandir)
	$(install_file) install-docs.8           $(DESTDIR)$(mandir)
	$(compress)                              $(DESTDIR)$(mandir)/install-docs.8

	$(install_dir)                           $(DESTDIR)$(docdir)
	$(install_file) doc-base.sgml            $(DESTDIR)$(docdir)
	$(compress)                              $(DESTDIR)$(docdir)/doc-base.sgml

	$(install_file) doc-base.txt             $(DESTDIR)$(docdir)
	$(compress)                              $(DESTDIR)$(docdir)/doc-base.txt
	$(install_file) install-docs.html        $(DESTDIR)$(docdir)

	$(install_dir)                           $(DESTDIR)$(docdir)/doc-base.html
	$(install_file) doc-base.html/*          $(DESTDIR)$(docdir)/doc-base.html

.PHONY: install clean all
