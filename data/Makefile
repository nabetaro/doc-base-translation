# vim:ts=2
# makefile for doc-base
# $Id: Makefile 167 2009-01-04 12:24:45Z robert $
#

ALL_TARGET=
SUBDIRS=
include ../common.mk

install-local: 
	$(install_dir)                            $(DESTDIR)$(sharedir)
	$(install_file) doc-base.desc        			$(DESTDIR)$(sharedir)/doc-base
	$(install_file) install-docs.desc    			$(DESTDIR)$(sharedir)/install-docs-man
	$(install_dir)                            $(DESTDIR)$(sharedir)/data
	$(install_file) scrollkeeper.map     			$(DESTDIR)$(sharedir)/data/
	$(install_file) doc-base.map         			$(DESTDIR)$(sharedir)/data/
	$(install_dir)                            $(DESTDIR)$(etcdir)/documents
	$(install_file) README.local         			$(DESTDIR)$(etcdir)/documents/README
