# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dhelp.pm 133 2008-04-20 14:32:30Z robert $
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
# $arg should be `-d' or `-a' or `-r'
sub _ExecuteDhelpParse($$) { # {{{
  my $arg   = shift;
  my $dirs  = shift;

  return 0 if $#{$dirs} < 0 and $arg ne '-r';

  Execute($DHELP_PARSE, $arg, @$dirs) if ($opt_update_menus);
  
} # }}}



sub _GetDocFileList($$) { # {{{
  my $documents = shift;  # in parameter
  my $docfiles  = shift;  # out parameter
  
  foreach my $doc (@$documents) {
    my $docid   = $doc->GetDocumentID();
    my $docfile = $VAR_CTRL_DIR . "/" . $docid;
    next unless -f $docfile;
    push(@$docfiles, $docfile);
  }
}   # }}}

# Main functions of the module

# Unregistering documents from dhelp
# Must be called BEFORE the new contents is written 
# to /var/lib/doc-base/documents/
 sub UnregisterDhelp(@) {  # {{{
  my @documents     = @_;
  my @docfiles      = ();

  Debug("UnregisterDhelp started");

  _GetDocFileList(\@documents, \@docfiles);

  _ExecuteDhelpParse("-d", \@docfiles);

  Debug("UnregisterDhelp finished");

  undef @docfiles;

} # }}}

# Registering documents to dhelp
# Must be called before AFTER new contents is written 
# to /var/lib/doc-base/documents/
sub RegisterDhelp($@) {  # {{{
  my $register_all  = shift;
  my @documents     = @_;
  my @docfiles      = ();

  Debug("RegisterDhelp started");
  
  if ($register_all) {
    _ExecuteDhelpParse("-r", ());
  }
  else
  {
    _GetDocFileList(\@documents, \@docfiles);
  
    _ExecuteDhelpParse("-a", \@docfiles) if @docfiles;
  }    

  Debug("RegisterDhelp finished");

  undef @docfiles;

} # }}} 

1;
