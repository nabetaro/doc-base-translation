# vim:ts=2
# makefile for doc-base
# $Id: Makefile 167 2009-01-04 12:24:45Z robert $
#

ALL_TARGET=
SUBDIRS=Programs
include ../../../common.mk

SOURCE_FILES	:=	$(sort $(wildcard *.pm))
INSTALL_DIR		:= 	$(subst $(realpath $(TOPDIR)/perl),,$(realpath $(CURDIR)))

install-local:
	$(install_dir) $(DESTDIR)/$(perllibdir)/$(INSTALL_DIR)
	$(install_file) $(SOURCE_FILES)  $(DESTDIR)/$(perllibdir)/$(INSTALL_DIR)
