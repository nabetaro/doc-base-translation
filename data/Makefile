# vim:ts=2
# makefile for doc-base
# $Id: Makefile 168 2009-01-04 16:10:53Z robert $
#

ALL_TARGET:=
SUBDIRS:=
include ../common.mk

install-local: 
	$(call msg,$@)
	$(call install,$(DESTDIR)$(sharedir)/doc-base,doc-base.desc,notdir)
	$(call install,$(DESTDIR)$(sharedir)/install-docs-man,install-docs.desc,notdir)
	$(call install,$(DESTDIR)$(sharedir)/data,scrollkeeper.map doc-base.map)
	$(call install,$(DESTDIR)$(etcdir)/documents/README,README.local,notdir)
