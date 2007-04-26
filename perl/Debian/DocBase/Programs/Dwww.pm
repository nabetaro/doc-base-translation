# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dwww.pm 61 2007-04-26 20:40:12Z robert $
#

package Debian::DocBase::Programs::Dwww;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(RegisterDwww);

use Debian::DocBase::Common;

our $dwww_update = "/usr/bin/update-menus";

# Registering to dwww:
sub RegisterDwww { # {{{
  my @documents = @_;
  $#documents < 0 and return;
 
  &update_dwww_menus();
} # }}}

sub update_dwww_menus { # {{{
  if (-x $dwww_update) {
    print "Executing $dwww_update\n" if $verbose;
    if (system($dwww_update) != 0) {
      warn "warning: error occured during execution of $dwww_update";
    }
  }
} # }}}

