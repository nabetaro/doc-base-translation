# vim:ts=2
# makefile for doc-base
# $Id: Makefile 168 2009-01-04 16:10:53Z robert $
#

ALL_TARGET=
SUBDIRS=
include ../../../../common.mk

SOURCE_FILES	:=	$(sort $(wildcard *.pm))
INSTALL_DIR		:= 	$(subst $(realpath $(TOPDIR)/perl),,$(realpath $(CURDIR)))

install-local:
	$(call msg,$@)
	$(call install,$(DESTDIR)/$(perllibdir)/$(INSTALL_DIR),$(SOURCE_FILES))

