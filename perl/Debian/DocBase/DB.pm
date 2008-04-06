# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: DB.pm 125 2008-04-06 19:20:02Z robert $
#

package Debian::DocBase::DB;

use strict;
use warnings;

use MLDBM qw(GDBM_File Storable); 
use Fcntl;
use Carp;
use Debian::DocBase::Common;
use Debian::DocBase::Utils;

my $filesdb  = undef;
my $statusdb = undef;

sub new { # {{{
    my $class   = shift;
    my $dbfile  = shift;
    my $enckey  = shift;
    my $self    = {
        DB      => {},
        FILE    => $dbfile,
        ENCKEY  => $enckey

    };
    bless($self, $class);
    $self->init();
    return $self;
} # }}}

sub init() {
  my $self = shift;

  tie %{$self->{'DB'}}, 'MLDBM', $self->{'FILE'}, O_CREAT|O_RDWR, 0644
    or carp "Can't access $self->{'FILE'}: $!\n";
}

sub PutData($$$) {
    my ($self, $key, $data)  = @_;
    $self->{'DB'}->{$self->EncodeKey($key)}   = $data;
}

sub GetData($$) {
  my ($self, $key) = @_;
  return $self->{'DB'}->{$self->EncodeKey($key)}
}
    
sub GetDB() {
  my $self = shift;
  return $self->{'DB'};
} 

sub RemoveData($$)
{
  my ($self, $key) = @_;
  delete $self->{'DB'}->{$self->EncodeKey($key)};
}

sub Exists($) {
  my ($self, $key) = @_;
  my $data = $self->{'DB'}->{$self->EncodeKey($key)};
  return $data and %{$data};
}

### PRIVATE FUNCTIONS
sub EncodeKey($$) {
  my ($self, $key) = @_;
  return $key unless $self->{'ENCKEY'};
  $key =~ s/\/+/\//g;
  $key =~ s/^$CONTROL_DIR/@/o;
  $key =~ s/^$LOCAL_CONTROL_DIR/#/o;
  return $key;
}

sub DecodeKey($$) {
  my ($self, $key) = @_;
  return $key unless $self->{'ENCKEY'};

  $key =~ s/^@/$CONTROL_DIR/o;
  $key =~ s/^#/$LOCAL_CONTROL_DIR/o;
  return $key;
}    

### STATIC FUNCTIONS
sub GetFilesDB() {
  $filesdb     = Debian::DocBase::DB->new($DB_FILES, 1) unless $filesdb;
  return $filesdb;
}

sub GetStatusDB() {
  $statusdb     = Debian::DocBase::DB->new($DB_STATUS, 0) unless $statusdb;
  return $statusdb;
}

1
