# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Common.pm 83 2007-10-23 07:01:35Z robert $


package Debian::DocBase::Common;

use Exporter();
use strict;
use warnings;

use vars    qw(@ISA @EXPORT);
@ISA    = qw(Exporter);
@EXPORT = qw($DATA_DIR $CONTROL_DIR @SUPPORTED_FORMATS @NEED_INDEX_FORMATS
             %FIELDS_DEF
                $FLDDEF_TYPE
                  $FLDTYPE_MAIN $FLDTYPE_FORMAT
                $FLDDEF_REQUIRED
                $FLDDEF_MULTILINE
             $opt_verbose $opt_debug $exitval $opt_rootdir $opt_update_menus
            );

our $DATA_DIR     = "/var/lib/doc-base/info";
our $CONTROL_DIR  = "/usr/share/doc-base";

# ---configuration-part---

# All formats handled by the doc-base
our @SUPPORTED_FORMATS =  (
                            'html',
                            'text',
                            'pdf',
                            'postscript',
                            'info',
                            'dvi',
                            'debiandoc-sgml'
                      );

# Formats which need the Index: field
our @NEED_INDEX_FORMATS = (
                            'html',
                            'info'
                         );

# doc-base control file fields definitions
our $FLDDEF_TYPE      = 'type';
  our $FLDTYPE_MAIN   = 1;
  our $FLDTYPE_FORMAT = 2;
our $FLDDEF_REQUIRED  = 'required';
our $FLDDEF_MULTILINE = 'multiline';

# Fields in doc-base file:
our %FIELDS_DEF  = (
 # Main fields:
  'document' => {
                  $FLDDEF_TYPE      => $FLDTYPE_MAIN,
                  $FLDDEF_REQUIRED  => 1,
                  $FLDDEF_MULTILINE => 0
                },
  'version'  => {
                  $FLDDEF_TYPE      => $FLDTYPE_MAIN,
                  $FLDDEF_REQUIRED  => 0,
                  $FLDDEF_MULTILINE => 0
                },
  'section'  => {
                  $FLDDEF_TYPE      => $FLDTYPE_MAIN,
                  $FLDDEF_REQUIRED  => 0,
                  $FLDDEF_MULTILINE => 0
                },
  'title'    => {
                  $FLDDEF_TYPE      => $FLDTYPE_MAIN,
                  $FLDDEF_REQUIRED  => 1,
                  $FLDDEF_MULTILINE => 1
                },
  'author'   => {
                  $FLDDEF_TYPE      => $FLDTYPE_MAIN,
                  $FLDDEF_REQUIRED  => 0,
                  $FLDDEF_MULTILINE => 1
                },
  'abstract' => {
                  $FLDDEF_TYPE      => $FLDTYPE_MAIN,
                  $FLDDEF_REQUIRED  => 0,
                  $FLDDEF_MULTILINE => 1
                },
 # Format fields:  
  'format'   => {
                  $FLDDEF_TYPE      => $FLDTYPE_FORMAT,
                  $FLDDEF_REQUIRED  => 1,
                  $FLDDEF_MULTILINE => 0
                },
  'index'    => {
                  $FLDDEF_TYPE      => $FLDTYPE_FORMAT,
                  $FLDDEF_REQUIRED  => 0,
                  $FLDDEF_MULTILINE => 0
                },
  'files'    => {
                  $FLDDEF_TYPE      => $FLDTYPE_FORMAT,
                  $FLDDEF_REQUIRED  => 0, # 
                  $FLDDEF_MULTILINE => 1
                }
);




# ---end-of-configuration-part---

# ---global-variables---


our $opt_verbose      = 0;
our $opt_debug        = 0;
our $opt_update_menus = 1;
our $opt_rootdir      = "";
our $exitval          = 0;


1;
