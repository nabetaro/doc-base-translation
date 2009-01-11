# vim:ts=2
# makefile for doc-base
# $Id: Makefile 178 2009-01-11 14:14:16Z robert $
#

ALL_TARGET := build-local
SUBDIRS		 := 
include ../common.mk

generated := $(bdir)/version.ent							\
						 $(bdir)/doc-base.sgml						\
						 $(bdir)/doc-base.txt 						\
						 $(bdir)/doc-base.html/index.html \
						 $(bdir)/check-stamp							\
						 $(bdir)/section.list

$(ALL_TARGET): $(generated) | $(bdir)


$(bdir)/doc-base.sgml: doc-base.sgml | $(bdir)
	$(call msg,$@)
	cp -f $< $@
	touch -r $< $@

$(bdir)/check-stamp: $(bdir)/doc-base.sgml $(bdir)/version.ent
	$(call msg,$@)
	nsgmls -wall -s -E20 $(bdir)/doc-base.sgml	# check SGML syntax
	touch $@

$(bdir)/doc-base.txt: $(bdir)/doc-base.sgml $(bdir)/version.ent $(bdir)/check-stamp
	$(call msg,$@)
	cd $(bdir) && debiandoc2text $(<F)

$(bdir)/doc-base.html/%: $(bdir)/doc-base.sgml $(bdir)/version.ent $(bdir)/check-stamp
	$(call msg,$@)
	cd $(bdir) && debiandoc2html $(<F)

$(bdir)/version.ent: $(bdir)/doc-base.sgml $(CHANGELOGFILE) $(MAKEFILESLIST) | $(bdir)
	$(call msg,$@)
	echo "<!ENTITY version \"$(VERSION)\">"    > $@.new
	echo "<!ENTITY date    \"$(DATE_EN)\">"    >> $@.new
	mv -f $@.new $@

$(bdir)/section.list: doc-base.sgml | $(bdir)
	$(call msg,$@)
	perl -e  \
	   'exec ("'perl'", "-ne", join("",@ARGV)) if $$#ARGV >-1;                    '\
	   '      last                    if /<!--\s*section\s+list\s+end\s*-->/;     '\
	   '      $$insect=1              if /<!--\s*section\s+list\s+begin\s*-->/;   '\
	   '      next                    unless $$insect;                            '\
	   '      s/item>/tag>/g          if $$inlst;                                 '\
	   '      $$inlst = 1             if s/<list>/<taglist>/;                     '\
	   '      $$inlst = 0             if s/<\/list>/<\/taglist>/;                 '\
	   '      $$top .= ($$sect . "/") if /<taglist>/ and $$sect;                  '\
	   '      $$top =~ s/[^\/]+\/$$// if /<\/taglist>/;                           '\
	   '      $$sect = $$1            if (/<tag>(?:(?:<\w+[>\/])*?)\s*([^<>\/]+)\s*(.*?)<\/tag>/);  '\
	   '      print "$$top$$sect\n"   if /<tag>/ && !/<!--\s*skip\s*-->/;         '\
	 < $< > $@.tmp
	 touch -r $< $@.tmp
	 mv $@.tmp $@

install-local: $(generated) 
	$(call msg,$@)
	$(call install,$(docdir),$(bdir)/version.ent)
	$(call install,$(docdir)/doc-base.html,$(bdir)/doc-base.html/*)
	$(call install,$(docdir),$(bdir)/doc-base.sgml $(bdir)/doc-base.txt,compress)
	$(call install,$(sharedir)/data,$(bdir)/section.list)
