# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dwww.pm 63 2007-04-28 22:41:18Z robert $
#

package Debian::DocBase::Programs::Dwww;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(RegisterDwww);

use Debian::DocBase::Common;
use Debian::DocBase::Utils;

our $dwww_update = "/usr/bin/update-menus";

# Registering to dwww:
sub RegisterDwww { # {{{
  my @documents = @_;
  $#documents < 0 and return;
 
  &Execute($dwww_update);
} # }}}
