# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dhelp.pm 96 2007-12-01 15:05:52Z robert $
#

package Debian::DocBase::Programs::Dhelp;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(RegisterDhelp UnregisterDhelp);

use Carp;
use Debian::DocBase::Common;
use Debian::DocBase::Utils;

my $DHELP_PARSE     = "/usr/sbin/dhelp_parse";

# executes `/usr/sbin/dhelp_parse $arg $@dirs' 
# $arg should be `-d' or `-a'
sub ExecuteDhelpParse($$) { # {{{
  my $arg   = shift;
  my $dirs  = shift;

  return 0 if $#{$dirs} < 0;

  IgnoreSignals();
  Execute($DHELP_PARSE, $arg, @$dirs);
  RestoreSignals();
  
} # }}}



sub GetDocFileList($$) {
  my $documents = shift;  # in parameter
  my $docfiles  = shift;  # out parameter
  
  foreach my $doc (@$documents) {
    my $docid   = $doc->document_id();
    my $docfile = $VAR_CTRL_DIR . "/" . $docid;
    next unless -f $docfile;
    push(@$docfiles, $docfile);
  }
}  

# Main functions of the module

# Unregistering documents from dhelp
# Must be called BEFORE the new contents is written 
# to /var/lib/doc-base/documents/
sub UnregisterDhelp(@) {  # {{{
  my @documents = @_;
  my @docfiles  = ();

  $#documents < 0 and return;

  Debug("UnregisterDhelp started");

  GetDocFileList(\@documents, \@docfiles);
  
  ExecuteDhelpParse("-d", \@docfiles);

  Debug("UnregisterDhelp finished");

  undef @docfiles;

} # }}}

# Registering documents to dhelp
# Must be called before AFTER new contents is written 
# to /var/lib/doc-base/documents/
sub RegisterDhelp(@) {  # {{{
  my @documents = @_;
  my @docfiles  = ();

  $#documents < 0 and return;

  Debug("RegisterDhelp started");
  
  GetDocFileList(\@documents, \@docfiles);
  
  ExecuteDhelpParse("-a", \@docfiles);

  Debug("RegisterDhelp finished");

  undef @docfiles;

} # }}}

1;
