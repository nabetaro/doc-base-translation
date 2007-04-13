# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dhelp.pm 57 2007-04-13 19:18:32Z robert $
#

package Debian::DocBase::Programs::Dhelp;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(register_dhelp  add_file remove_files);

use Debian::DocBase::Common;
use Debian::DocBase::Utils;

our $dhelp_parse = "/usr/sbin/dhelp_parse";

# Registering to dhelp
sub register_dhelp { # {{{

  my $format_data = $doc->format('html');
  return unless defined $format_data;
  my $file = &basename($$format_data{'index'});
  my $dir = &dirname($$format_data{'index'});
  $dir =~ m|^/| or 
      die "Index file has to be specified with absolute path: $$format_data{'index'}";

 # ensure the documentation is in an area dhelp can deal with
 if ( $dir !~ m|^/usr/share/doc| ) {
  print "register_dhelp: skipping $dir/$file
         because dhelp only knows about /usr/share/doc\n"
      if $verbose;
    }

  my $dhelp_data;
  my $dhelp_file = "$dir/.dhelp";
  # dhelp file already exists?
  if (-f $dhelp_file) {
    # is this file from us?
    #if (not exists $list{$dhelp_file}) {
      # no, skip action -- actually we could probably tolerate this condition
      #warn "warning: skipping foreign dhelp file $dhelp_file";
      #next;
    #}

    # yes, read in the file
    $dhelp_data = read_dhelp_file($dhelp_file);

    # take a look at the contents
    my $i;
    for ( $i = 0; $i <= $#$dhelp_data; $i++ ) {
      if ($$dhelp_data[$i]{'filename'} =~ /^\s*\Q$file\E\s*$/o) {
        # remove this entry; we'll add it back below
        print "register_dhelp: found entry for $file in $dhelp_file, replacing\n"
        if $verbose;
        splice(@$dhelp_data, $i, 1);
      }
    }
  } else {
    # no file yet, let's make an empty ref to fill in below
    $dhelp_data = [];
  }


  # last minute data munging,
  # FIXME when we finally get a real document hierarchy
  my $dhelp_section;
  ( $dhelp_section = $doc->section()) =~ tr/A-Z/a-z/;
  $dhelp_section =~ s|^apps/||;
  $dhelp_section =~ s/^(howto|faq)$/\U$&\E/;
  # now push our data onto the array (undefs are ok)
  push(@$dhelp_data, {
    'filename'    => $file,
    'directory'   => $dhelp_section,
    'linkname'    => $doc->title(),
    'description' => $doc->abstract()
    }
  );

  # remove the dhelp_file and any other installed dhelp files 
  # (since the location could change and we can have only one file for document-id)
  # note: remove_files zeroes %list
  $list{$dhelp_file} = 1;  remove_files();
  
  print "Updating $dhelp_file\n" if $verbose;
  add_file($dhelp_file);
  write_dhelp_file($dhelp_file, $dhelp_data);

  if (-x $dhelp_parse) {
    print "Executing $dhelp_parse -a $dir\n" if $verbose;
    if (system("$dhelp_parse -a $dir") != 0) {
      warn "warning: error occured during execution of $dhelp_parse -a $dir";
    }
  } else {
    print "Skipping $dhelp_parse, program not found\n" if $verbose;
  }
  # set status
  $status{'Registered-to-dhelp'} = 1;
  $status_changed = 1;

} # }}}


# read a dhelp file, probably more flexibly than dhelp itself
# input:
#  file name
# output:
#  returns ref to array of hashes containing our data
sub read_dhelp_file { # {{{
  my ($dhelpfile) = @_;
  my ($dhdata);     # array ref, to be returned holding all the dhelp data 
  my (@rets);     # temporary array

  open(FH, "<$dhelpfile") or die "open file '$dhelpfile': $!\n";
  $_ = join('', <FH>);    # slurp in the file

  while ( m{
      <item>\s*     # item defines a block, required
    (?:     # alternate everything group
       (?:<directory>   # directory is starting, required
   ([^<]+)    #   $1
       )      # ... ending
     |
       (?:<dirtitle>    # dirtitle is starting, optional
         ([^<]+)    #   $2 until next tag start
       )      # ... ending
     |
       (?:<linkname>    # linkname is starting, optional
         ([^<]+)    #   $3
       )      # ... ending
     |
       (?:<filename>    # filename is starting, optional
         ([^<]+)    #   $4
       )      # ... ending
     |
       (?:<description>   # filename is starting, optional
         (.*?)      #  $5, non greedy
       </description>)    # ... ending
     )*     # end alternating
       \s*</item>   # spaces ok, item ends
      }gscx )
    {
      @rets =  ($1, $2, $3, $4, $5);
      @rets = map { $_="" unless defined $_; chomp; s/^\s+//; s/\s+$//; $_; }  @rets;
      # push a hashref of our dhelp data item onto the $dhdata array
      push(@$dhdata, {
          'directory'   => $rets[0],
          'dirtitle'    => $rets[1],
          'linkname'    => $rets[2],
          'filename'    => $rets[3],
          'description' => $rets[4],
          'converted'   => 1,      # the entry is already HTML-encoded,
                                   # we shouldn'try recode it on writing
         });
    }

  close FH;
  return $dhdata;
} # }}}


sub write_dhelp_file { # {{{
  my ($file, $data) = @_;

  open(FH, ">$file") or die "cannot create dhelp file '$file': $!\n";
  foreach my $rec (@$data) {
    my $do_html_convert = not (defined $$rec{'converted'} or $$rec{'converted'});
    print FH "<item>\n";
    foreach my $field ((
      'directory', 'dtitle', 'linkname', 'filename'
           )) {
      next unless defined $$rec{$field};
      next unless length($$rec{$field});
      if ($field ne 'linkname') {        
        print FH "<$field>$$rec{$field}\n";
      } else {   
        print FH "<$field>" . &html_encode($$rec{$field}, $do_html_convert) ."\n";
     }
    }
    print FH "<description>\n" . &html_encode_description($$rec{description}, $do_html_convert) . "\n</description>\n"
      if length($$rec{'description'});
    print FH "</item>\n\n";
  }
  close FH;
} # }}}

sub add_file { # {{{
  my ($file) = @_;

  return if $list{$file};

  my $data_file = "$DATA_DIR/$docid.list";
  open(L,">>$data_file")
    or die "$data_file: cannot open for appending";
  print L $file,"\n";
  close(L) or die "$data_file: cannot close file";

  $list{$file} = 1;
} # }}}

sub remove_files { # {{{
  for my $file (keys %list) {
    next unless -f $file;

    # dhelp file?
    if ($file =~ /\.dhelp$/o) { # yes

      my $dir = dirname($file);

      if (-x $dhelp_parse) {
        # call dhelp to notice removal of document
        print "Executing $dhelp_parse -d $dir\n" if $verbose;
        if (system("$dhelp_parse -d $dir") != 0) {
          warn "warning: error occured during execution of $dhelp_parse -d $dir";
        }
      }

      print "Removing dhelp file $file\n" if $verbose;
      unlink($file) or die "$file: cannot remove file: $!";

      next;
    }

    # not a dhelp file

    print "Removing file $file\n" if $verbose;
    unlink($file) or die "$file: cannot remove file: $!";
  }
  %list = ();
  $list_changed = 1;
} # }}}

1;
