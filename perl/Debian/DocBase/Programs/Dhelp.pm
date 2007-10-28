# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dhelp.pm 89 2007-10-28 10:46:04Z robert $
#

package Debian::DocBase::Programs::Dhelp;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(RegisterDhelp);

use Carp;
use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use File::Basename;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;


my $DHELP_PARSE     = "/usr/sbin/dhelp_parse";
my $USD_DIR         = "/usr/share/doc";
my $DHELP_FNAME     = ".dhelp";

# %DHELP_DOCUMENTS is a hash of hashes containing informations about directories, 
# in which we generate .dhelp files.
# Keys of the hash are the dirs, without the /usr/share/doc/ prefix.
#
# The structure of the hash:
# $dhelp_dir => { 
#   # Set by AddDocumentToHash():
#     $TYPE_OLD      => array of $docs, which used to register .dhelp file in this dir
#     $TYPE_NEW      => array of $docs, which register .dhelp file in this dir
#   # Set by GenerateNewDhelpItem():
#     $FILE_EXISTS   => 1, iff .dhelp file already exists in /usr/share/doc/$dhelp_dir
#     $FILE_CHANGED  => 1, iff contents of .dhelp file has changed
#     $REMOVE_FILE   => 1, iff .dhelp file should be removed
#     $TMP_FILE_NAME => name of the temporary file with new contents of .dhelp file
# }
my %DHELP_DOCUMENTS = ();
my $TYPE_NEW        = "type_new";
my $TYPE_OLD        = "type_old";
my $FILE_EXISTS     = "file_exists";
my $FILE_CHANGED    = "file_changed";
my $REMOVE_FILE     = "remove_file";
my $TMP_FILE_NAME   = "tmp_file_name";

my $tmpdirname      = undef;


# adds one document to %dhelp_document
sub _add_document_helper($$$) { # {{{
  my ($type, $dhelp_dir, $doc) = @_;

    if (not exists $DHELP_DOCUMENTS{$dhelp_dir}) {
      $DHELP_DOCUMENTS{$dhelp_dir} = { $type => [$doc] };
    } elsif (not exists $DHELP_DOCUMENTS{$dhelp_dir }->{$type}) {
      $DHELP_DOCUMENTS{$dhelp_dir}->{$type} = [$doc];
    } else {
      push (@{$DHELP_DOCUMENTS{$dhelp_dir}->{$type}}, $doc);
    }
} # }}}



# adds document to %DHELP_DOCUMENTS
sub AddDocumentToHash($) { # {{{
  my $doc = shift;
  my $docid = $doc->document_id();

  my $old_dhelp_file =  $doc->get_status('Dhelp-file');
  my $old_dir        = undef;
  if (defined $old_dhelp_file) {
    $old_dir    =  $old_dhelp_file;
    $old_dir    =~ s/^\Q$USD_DIR\E\/+//o;
    $old_dir    =~ s/\/+\Q$DHELP_FNAME\E$//o;
  }
  my $new_dir = undef;

  my $format_data = $doc->format('html');
  if (defined $format_data) {
    my $file = $$format_data{'index'};
    $file =~ s/\/+/\//;
    # ensure the documentation is in an area dhelp can deal with
    if ( $file !~ /^$USD_DIR\/([^\/]+)\/(.+)$/o ) {
      Warn ("RegisterDhelp: skipping $file
              because dhelp only knows about /usr/share/doc");
    } else {

      $new_dir=$1;

      _add_document_helper($TYPE_NEW, $new_dir, $doc);
      Debug("Will add dhelp entry for doc `$docid' in dir `$new_dir'");
    }
  }

  if (defined $old_dhelp_file and -e $old_dhelp_file
      and (not defined $new_dir
           or $old_dir ne $new_dir)) {
    _add_document_helper($TYPE_OLD, $old_dir, $doc);
    Debug("Will remove old dhelp entry for doc `$docid' from dir `$old_dir'");
  }

} # }}}


# read an existing dhelp file
# returns items with <x-doc-base-id> in the %$dhelp_data hash (document_id => item_data)
# returns items from items without <x-doc-base-id> tag in the @$other_dhelp_data
# returns undef in case of error
sub ReadDhelpFile($$$) { # {{{
  my ($dhelp_file, $dhelp_data, $other_dhelp_data) = @_;

  Debug("Reading dhelp file: $dhelp_file");

  open(FH, "<", "$dhelp_file") or return Warn ("can't open file '$dhelp_file': $!\n");
  $_ = join('', <FH>);    # slurp in the file

# <x-doc-base-id> may be anywhere in <item>
#  while ( m{(<item>\s*  # item defines a block, required
#        (?:  # alternate everything group
#          (?:<x-doc-base-id>([^<\s]+)\s*)  # x-doc-base-id, optional
#        |
#          (?:<.*?)   # not interested in other tags, non greedy
#        )*  # end alternating
#        \s*</item> # spaces ok, item ends
#        )}gscx )
#
#  simpler version depending on <x-doc-base-id> being the first element in <item>
  while ( m{(<item>\s*   # item defines a block, required
          (?:<x-doc-base-id>([^<\s]+)\s*)?   # x-doc-base-id, optional
          .*?         # non greedy
        \s*</item>
        )}gscx )
    {
    # $1 is everything beetwen <item> and </item>
    # $2 is value of the <x-doc-base-id> tag
      if (defined $2) {
        $dhelp_data->{$2} = $1;
      } else {
        push(@$other_dhelp_data,  $1);
      }
    }
  close FH;
} # }}}

# writes contents $@dhelp_data into a $file;
# $@dhelp_data should be an array of dhelp <item>s
sub WriteDhelpFile($$) { # {{{
  my $file = shift;
  my $dhelp_data = shift;

  return 0 if  ($#{$dhelp_data} < 0); # no data to write, the file already deleted

  open (FH, ">", "$file") or croak  ("Cannot open file $file for writing: $!");
  print FH join("\n\n", @$dhelp_data) . "\n";
  close FH or croak "Cannot close dhelp file `$file'";

  return 1;
} # }}}

{
my $lasttmpfidx   = 0;
# returns a name for .dhelp temporary file
sub GetTmpFileName($) { # {{{
  my $dirname = shift;

  if (not defined $tmpdirname) {
     $tmpdirname = tempdir('docbase.XXXXXX', TMPDIR => 1, CLEANUP => 1)
      or croak "Can't creat temporary directory: $!";
  }

  $dirname =~ s/\//_/og;
  $lasttmpfidx++;
  return $tmpdirname . '/' . $dirname . '_' . $lasttmpfidx;
} # }}}
}

# helper function for GenerateDhelpItemFromDoc
# returns dhelp item elements in form <key>value or <key>multi_line_value</key>
sub _add_key($$;$) { # {{{
  my $key       = shift;
  my $value     = shift;
  my $multiline = shift;

  return "" unless defined $value;
  $value =~ s/^\s+//m;
  $value =~ s/\s+$//m;
  return "" unless length($value);

  $value =~ s/\n/ /mg unless defined $multiline;
  return "<$key>\n$value\n</$key>\n" if defined $multiline;
  return "<$key>$value\n";
} # }}}

# generate dhelp <item> for a one document $doc
sub GenerateDhelpItemFromDoc($$) { # {{{
  my $doc = shift;
  my $dir = shift;
  my @new_dhelp_data = ();
  my $docid = $doc->document_id();


  my $format_data = $doc->format('html');
  defined ($format_data) or croak "Internal error: no html format found";
  my $filename = $$format_data{'index'};
  defined($filename) or croak "Internal error: no index";
  $filename =~ s/\/+/\//;
  $filename =~ s/^$USD_DIR\/([^\/])+\/(.+)$/$2/o;

  my $dhelp_section;
  ( $dhelp_section = $doc->section()) =~ tr/A-Z/a-z/;
  $dhelp_section =~ s|^app(lication)?s/||;
  $dhelp_section =~ s/^(howto|faq)$/\U$&\E/;
  # now push our data onto the array (undefs are ok)
  (my $documents =  $$format_data{'files'}) =~ s/\B\Q$USD_DIR\E\/\Q$dir\E\///g;


  my $data = "<item>\n";
  $data .= _add_key("x-doc-base-id",  $doc->document_id());
  $data .= _add_key("directory",      HTMLEncode($dhelp_section));
  $data .= _add_key("linkname",       $doc->title());
  $data .= _add_key("filename",       $filename);
  $data .= _add_key("documents",      $documents);
  $data .= _add_key("description",    HTMLEncodeDescription($doc->abstract()), 1);
  $data .= "</item>";
  return $data;
} # }}}


# generates new dhelp file
# takes into account all documents from $DHELP_DOCUMENTS{$dir}->{ $(TYPE_OLD|TYPE_NEW) }
# sets  $DHELP_DOCUMENTS{$dir}->{ $(FILE_EXISTS | FILE_CHANGED | REMOVE_FILE | TMP_FILE_NAME) } statuses
sub GenerateNewDhelpFile($) { # {{{
  my $dir              = shift;

  my $file             = "$USD_DIR/$dir/$DHELP_FNAME";
  my @other_dhelp_data = (); # array of dhelp_items without document_id assigned
  my %dhelp_data       = (); # hash of (document_id => dhelp_item_for_this_document_id)
  my $file_exists      = (-f $file);
  my $file_changed     = 0;
  my $doc_id           = undef;
  my $item_data        = undef;

  # read existing dhelp file
  if ($file_exists) {
    ReadDhelpFile($file, \%dhelp_data, \@other_dhelp_data);
    $DHELP_DOCUMENTS{$dir}->{$FILE_EXISTS} = 1;
  }

  # remove old dhelp file contents
  if (exists $DHELP_DOCUMENTS{$dir}->{$TYPE_OLD}) {
    for my $doc ( @{$DHELP_DOCUMENTS{$dir}->{$TYPE_OLD}}) {
      $doc_id       = $doc->document_id();
      $file_changed = 1 if exists $dhelp_data{$doc_id};
      delete $dhelp_data{$doc_id};
    }
  }

  # generate new dhelp file contents
  if (exists $DHELP_DOCUMENTS{$dir}->{$TYPE_NEW}) {
    for my $doc ( @{$DHELP_DOCUMENTS{$dir}->{$TYPE_NEW}}) {
      $doc_id     = $doc->document_id();
      $item_data  = GenerateDhelpItemFromDoc($doc, $dir);
      if (not exists $dhelp_data{$doc_id} or $dhelp_data{$doc_id} ne $item_data) {
        $file_changed         = 1;
        $dhelp_data{$doc_id}  = $item_data;
      }
    }
  }

  # old contents is same as new contents, skip registration
  if (not $file_changed) {
    Debug("Dhelp file `$file' contents not changed, skipping");
    return 1;
  }

  $DHELP_DOCUMENTS{$dir}->{$FILE_CHANGED} = 1;

  # add new items to @other_dhelp_data
  foreach my $key (sort keys %dhelp_data) {
    push @other_dhelp_data, $dhelp_data{$key};
  }

  if ($#other_dhelp_data < 0) {
    Debug("Dhelp file `$file' will be removed");
    # file contents is empty, should be removed
    $DHELP_DOCUMENTS{$dir}->{$REMOVE_FILE} = 1 if $file_exists;
    return 1;
  }

  # write new contents of dhelp file into a temporary file
  my $tmpfile = GetTmpFileName($dir);
  WriteDhelpFile($tmpfile, \@other_dhelp_data);
    Debug("Dhelp file `$file' will be updated");
  $DHELP_DOCUMENTS{$dir}->{$TMP_FILE_NAME} = $tmpfile;
} # }}}


# executes `/usr/sbin/dhelp_parse $arg $@dirs' 
# $arg should be `-d' or `-a'
sub ExecuteDhelpParse($$) { # {{{
  my $arg   = shift;
  my $dirs  = shift;

  return 0 if $#{$dirs} < 0;

  my @args =  grep { $_ = $USD_DIR . "/" .$_ } @$dirs;
  Execute($DHELP_PARSE, $arg, @args);
  undef @args;
} # }}}



# rename $srcfile to $dstfile
sub rename_or_copy($$) { # {{{
 my ($srcfile, $dstfile) = @_;

 return 1 if rename $srcfile, $dstfile;
 if (not copy($srcfile, "$dstfile.tmp")) {
   my $err = $!;
   unlink "$dstfile.tmp";
   croak "Can't copy `$srcfile' to `$dstfile.tmp': $err";
 }
 if (not rename "$dstfile.tmp", $dstfile) {
   my $err = $!;
   unlink "$dstfile.tmp";
   croak "Can't rename `$dstfile.tmp' to `$dstfile': $err";
  }
 return 1;
} # }}}



# for each $doc from @$documents sets its Dhelp-file to $new_file
# if called with three arguments, sets the Dhelp-file iff the third 
#  argument is equal the existing value of Dhelp-file
sub SetDocStatusDhelpFile($$;$) { # {{{
  my ($documents, $new_file, $old_file) = @_;
  my $old_status = undef;

  return 1 unless defined $documents;
  foreach my $doc (@$documents) {
    $doc->set_status('Dhelp-file', $new_file)
      if (not defined $old_file)
          or (defined ($old_status = $doc->get_status('Dhelp-file'))              
              and $old_status eq $old_file)
  }

  return 1;
} # }}}

# Registering documents to dhelp
# Main function of the module
sub RegisterDhelp(@) {  # {{{
  my @documents = @_;

  $#documents < 0 and return;

  Debug("RegisterDhelp started");
  
  %DHELP_DOCUMENTS = ();


  foreach my $doc (@documents) {
    AddDocumentToHash($doc);
#    register_one_dhelp_document($doc);
  }

  foreach my $dir (sort keys %DHELP_DOCUMENTS) {
    GenerateNewDhelpFile($dir);
  }

  IgnoreSignals();

  my @dirs = ();
  # unregister old documents
  foreach my $dir (sort keys %DHELP_DOCUMENTS) {
    next unless exists $DHELP_DOCUMENTS{$dir}->{$FILE_CHANGED};
    next unless exists $DHELP_DOCUMENTS{$dir}->{$FILE_EXISTS};
    push (@dirs, $dir);
  }
  ExecuteDhelpParse("-d", \@dirs);

  # move temporary dirs
  @dirs = ();
  foreach my $dir (sort keys %DHELP_DOCUMENTS) {
    my $file = "$USD_DIR/$dir/$DHELP_FNAME";

    if (exists $DHELP_DOCUMENTS{$dir}->{$FILE_CHANGED}) {

      if (exists $DHELP_DOCUMENTS{$dir}->{$REMOVE_FILE}) {
        unlink $file or croak "Can't unlink $file: $!";
      } elsif (exists $DHELP_DOCUMENTS{$dir}->{$TMP_FILE_NAME}) {
        my $tmp_file = $DHELP_DOCUMENTS{$dir}->{$TMP_FILE_NAME};

        rename_or_copy ($tmp_file, $file) or
          croak "Can't rename `$tmp_file' to `$file': $!";

        push (@dirs, $dir);
      }
    }

    # set documents as registered
    SetDocStatusDhelpFile($DHELP_DOCUMENTS{$dir}->{$TYPE_OLD}, undef, $file);
    SetDocStatusDhelpFile($DHELP_DOCUMENTS{$dir}->{$TYPE_NEW}, $file);
  }

  # register dirs
  ExecuteDhelpParse("-a", \@dirs);

  
  RestoreSignals();

  undef $tmpdirname;
  undef %DHELP_DOCUMENTS;

  Debug("RegisterDhelp finished");

} # }}}

1;
