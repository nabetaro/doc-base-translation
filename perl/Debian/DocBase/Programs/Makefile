# vim:ts=2
# makefile for doc-base
# $Id: Makefile 178 2009-01-11 14:14:16Z robert $
#

ALL_TARGET=
SUBDIRS=
include ../../../../common.mk

SOURCE_FILES	:=	$(sort $(wildcard *.pm))
INSTALL_DIR		:= 	$(subst $(realpath $(TOPDIR)/perl),,$(realpath $(CURDIR)))

install-local:
	$(call msg,$@)
	$(call install,$(perllibdir)/$(INSTALL_DIR),$(SOURCE_FILES))

