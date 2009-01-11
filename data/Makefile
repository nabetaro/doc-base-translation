# vim:ts=2
# makefile for doc-base
# $Id: Makefile 178 2009-01-11 14:14:16Z robert $
#

ALL_TARGET:=
SUBDIRS:=
include ../common.mk

install-local: 
	$(call msg,$@)
	$(call install,$(sharedir)/doc-base,doc-base.desc,notdir)
	$(call install,$(sharedir)/install-docs-man,install-docs.desc,notdir)
	$(call install,$(sharedir)/data,scrollkeeper.map doc-base.map)
	$(call install,$(etcdir)/documents/README,README.local,notdir)
