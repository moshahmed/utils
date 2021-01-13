#!/usr/bin/perl -w
# GPL(C) MoshAhmed.at.gmail
use strict;

use Cwd;
my $pwd=getcwd();
my( $cmd ); ( $cmd = $0 ) =~ s,[/\\]+,/,g;

my ($root) = '/';
$root = "$1:/" if $pwd =~ m,^/cygdrive/(\w)\b,;

my (@lineq);
my ($start_time,$end_time)=(0,0);
# my $timestamp_pattern = '^\[(\d+:\d+\.\d+)\]\s*';
my $tmpdir="${root}tmp";
my $sep='';
my ($debug,$verbose)=(0,0);
my ($keep,$mp3info)=(0,1);
my ($rename,$count,$lineno,$txt2lrc,$overwrite)=(0,0,0,0,0);
my (@args) = (@ARGV);
@args = grep {/^-/} @args;

my $USAGE = q{
Usage: lrc-fix.pl lrcfile.lrc > interpolated.lrc
What: Interpolate timestamps in input.lrc 
Also see: txt2srt.pl -mini_lyrics=1 -hms:10:0 input.txt > output.lrc
Options:
  -txt2lrc      Convert file.txt to file.lrc
    -overwrite    Overwrite old lrcfile 
    -rename       Rename lrcfile.lrc to lrcfile.lrc.N and write new one
    -tmpdir:DIR/  Stash infile to DIR/infile, and overwrite infile 
  -end_time:MM:SS.DD Total end_time in centi_seconds (seconds*100).
                e.g. -end_time:1:1 for 61s, -end_time:1:2.3 for 62.3s
  -mp3info:[01] Get end_time from mp3info
  -sep:===      Print separator at time matches in lrc file.
  -keep:[01]    keep mp3 edit time-marks.
  -lineno       add line numbers to lrc
  -h -v -d      Help Verbose Debug
Caveats:
    $ file bad.lrc  .. unicode etc.
    $ dos2unix *.lrc
    $ vim +":e ++enc=UTF16LE | :set fenc=UTF8 | :w" minilyrics-bad.lrc
    $ to-ascii.cmd bad.lrc > good.lrc  
      $ iconv -f utf-8 -t us-ascii//TRANSLIT bad.lrc > good.lrc
      $ tr -cd '[:print:]\\r\\n\\t'        < bad.lrc > good.lrc
TODO: Support srt
};

# Process args
while( $_ = $ARGV[0], defined($_) && m/^-/ ){ shift; last if /^--$/; if(0){
    }elsif( m/^-[h?]$/ ){ die $USAGE;
    }elsif( m/^-rename$/    ){ $rename++;
    }elsif( m/^-txt2lrc$/    ){ $txt2lrc++;
    }elsif( m/^-overwrite$/    ){ $overwrite++;
    }elsif( m/^-lineno$/ ){ $lineno++;
    }elsif( m/^-end_time:(.+)$/ ){ $end_time = time_cs($1);
    }elsif( m/^-keep:(.+)$/ ){ $keep=$1;
    }elsif( m/^-mp3info:(.+)$/ ){ $mp3info=$1;
    }elsif( m/^-tmpdir:(.+)$/ ){ $tmpdir=$1;
    }elsif( m/^-sep:(.+)/ ){ $sep = $1;
    }elsif( m/^-v$/    ){ $verbose++;
    }elsif( m/^-d$/    ){ $debug++;
    }else{ die $USAGE,"Unknown option '$_'\n"; }
}

die $USAGE if -t STDOUT && !@ARGV; # output to tty (!pipe) and no args?


if(@ARGV > 1){
  # glob to subprocess
  for my $lrcfile (@ARGV) {
    die "Cannot read $lrcfile\n" unless -T $lrcfile;
    warn "# lrc-fix @args $lrcfile\n";
    system("perl","c:/mosh/sound/lrc-fix.pl",@args,$lrcfile);
  }
  warn "# Done.\n";
  exit;
}

my($lrcfile) = shift(@ARGV) or die "Need lrcfile to fix\n";
die "Cannot read $lrcfile\n" unless -f $lrcfile;

if ($debug){
  warn("Input file $lrcfile is\n");
  system("file $lrcfile");
}

if ( $mp3info && !$end_time ){
  my $mp3file = $lrcfile =~ s,\.\w+$,.mp3,r;
  if ( -f $mp3file ) {
    $end_time = time_cs(qx{mp3info -p %S $mp3file});
  }
}

if ($txt2lrc) {
  my $txtfile = $lrcfile;
  $txtfile =~ m,([^/]+)\.txt$,i;
  my $newlrc = "$1.lrc";
  print "# $txtfile -> $newlrc\n";
  if (-e $newlrc) {
    warn "Found $newlrc\n";
    die "Will not overwrite $newlrc\n"
      unless $overwrite;
    warn "Overwriting $newlrc\n";
  }
  open STDOUT, '>', "$newlrc" or
    die "Can't redirect STDOUT to $newlrc: $!";
  open STDIN, '<', "$txtfile" or
    die "Can't redirect STDIN from $txtfile: $!";  
}elsif ($rename) {
  # Rename input lrcfile to lrcfile.N and process it.
  die "Need writable tmp dir $tmpdir\n"
    unless -w "$tmpdir/" && -d "$tmpdir";
  my $newname = get_newname($lrcfile);
  print_info($lrcfile,$newname);
  rename($lrcfile,  "$newname") or die "Cannot rename $lrcfile to $newname";
  open STDOUT, '>', "$lrcfile" or die "Cannot redirect STDOUT to $lrcfile: $!";
  open STDIN,  '<', "$newname" or die "Cannot redirect STDIN from $newname: $!";  
} else {
  open STDIN, '<', "$lrcfile" or die "Cannot redirect STDIN from $lrcfile: $!";  
}

# Process input file, line by line.
LINE:
while(<>) { chomp;
  next unless $_; # skip blank lines
  next if m/^#debug/; # Donot re-process #debug output of earlier run.
  next if m/^#/; # Skip comments.

  # For retiming, remove our ts from earlier run, but keep same LN.. Line Number
  s/^\[(\d+:\d+[0-9:.]+)\](\(LN0*(\d+)\))/$2/;

  # Save input lines into lineq until timestamp is found.
  next unless $_;
  my $this_time = time_cs($_);
  if (! $this_time ) {
    unshift(@lineq, $_);
    next LINE;
  }

  # Calculate time_per_char = len(lineq) / (last_time - start_time)
  my $charlen = est_char_time(join("\n", @lineq));
  my $ts_delta = $this_time - $start_time;
  my $time_per_char = $ts_delta / max($charlen,1);

  if ($debug){
    print "# Debug: in centiseconds: time_per_char=$time_per_char,"
          . "ts_delta=$ts_delta=$this_time-$start_time\n"
  }

  my $len_q = 0;
  my $aline;
  while ($aline = pop(@lineq) ) {

    ++$count;
    $count = $1 if $aline =~ s,\(LN0*(\d+)\),, ; # keep old line numbers.
    $aline =~ s/^\[(\d+:\d+[0-9:.]+)\]//;   # get rid of old timestamp

    my $curr_time = $start_time + $time_per_char * $len_q;

    if ($debug) {
      print "# debug:curr_time=$curr_time=$start_time+$time_per_char*$len_q\n";
    }

    if( $keep || $aline !~ m/\.mp3$/) { # keep edit time-marks?
      printf "[%s]", time_lrc($curr_time);
      printf "(LN%04d)", $count if $lineno;
      printf "%s\n", $aline;
    }
    $len_q += est_char_time($aline) + 1;
  }

  # print leftover line with sep
  $aline = $_;
  ++$count;
  $count = $1 if $aline =~ s,\(LN0*(\d+)\),, ; # keep old line numbers.
  $aline =~ s/^\[(\d+:\d+[0-9:.]+)\]//;   # get rid of old timestamp

  if( $keep || $aline !~ m/\.mp3$/) { # keep edit time-marks?
    printf "[%s]", time_lrc($this_time);
    printf "(LN%04d)", $count if $lineno;
    printf "%s\n", $aline;
    print "$sep\n" if $sep;
  }

  $start_time = $this_time;
}

sub get_newname {
  # find a new unique newname for backup.
  my $lrcfile = shift;
  my $counter=0;
  my $newname="$lrcfile.$counter";
  while(-e $newname){
    ++$counter;
    $newname="$tmpdir$lrcfile.$counter";
  }
  return $newname;
} 

sub print_info {
  my($lrcfile,$newname)=(@_);
  my $len_info = length($lrcfile) + length($newname);
  if ($len_info > 50 || "$lrcfile$newname" =~ m,[^\w./-], ) {
    # Multi line info, if filename is long or contains funny chars.
    print "\n"
       ."# rename \"$lrcfile\"\n"
       ."#     to \"$newname\"\n"
       ."# lrc-fix.pl in=\"$newname\"\n"
       ."#           out=\"$lrcfile\"\n";
  }else{
    print "# Rewriting $lrcfile, rename input infile to $newname\n";
  }
}  

sub est_char_time {
  # Carefully tuned to give idempotent timing on multiple runs.
  my $chars = shift;
  # Ignore unutterable text
  for ($chars) {

   # Custom unutterable from Gutenberg Shakespeare.
   # s,\b[A-Z]{2,30}\b, ,; # from "As you like it": "ORLANDO[tab]What mar .."
   s,.*\t, PAUSE ,mg;   # e.g. "Second Soldier[tab]Go we to him."
   s,\s*\[.+\], PAUSE ,g; # Skip stage directions, e.g. [Exit JAQUES] 
   s,\s*[[+].+, ,g; # Skip multi-line stage directions, e.g. [Exit JAQUES\n(\s*+.*\n)]
   s,\S+\.(mp3|lrc)\b, ,g; # Skip [timestamp] filename.mp3

   # Usual unutterables.
   s,LN\d+, ,g;   # remove line numbers.
   s,\d+:[\d:.]+, ,g; # remove timestamps
   s,\W+, ,g;
   s,\s+, ,g;  s,^\s+,,g;  s,\s+$,,g;

   s,^;.*, ,g; # ; Single line stage directions.
  }
  my $charlen = length($chars);
  print "#debug chars=$chars, charlen=$charlen\n" if $debug;
  return $charlen;
}

sub time_cs { # Convert timestamps to centiseconds
  # e.g. 1:2.3 to (60*1+2)*100+3 = 6230 centi-seconds = 62.3 seconds.
  # e.g. 1:3 to  63.
  # e.g. 1:37:021 is 1*60*60+37*60+21 (tamburlaine*mp3)
  # e.g. 5   to 5 seconds
  my $ts = shift || die;
  my($hour,$min,$sec,$cs);

  if (($hour,$min,$sec,$cs) = ($ts =~ m,[^0-9.:](\d+):(\d+):(\d\d)(\d*)[^0-9.:], )) {
    # vlc 2.1.0 -cmd=get_time on tamburlaine*mp3 is returning 1:40:028
    # Looks like a bug in vlc get_time, [1:44:0211] Tamburlaine-Part-1-44-23.mp3
    # Looks like the dot is missing: 1:44:02.11
    $ts = ($hour*60*60+($min*60 + $sec))*100 + $cs;
    return $ts;
  }
  if (($min,$sec,$cs) = ($ts =~ m,(\d+):(\d+)\.(\d+), )) {
    $ts = ($min * 60 + $sec)*100 + $cs;
    return $ts;
  }
  if (($min,$sec) = ($ts =~ m,(\d+):(\d+), )) {
    $ts = ($min * 60 + $sec)*100;
    return $ts;
  }
  if (($sec) = ($ts =~ m,^(\d+)$, )) {
    $ts = $sec*100;
    return $ts;
  }
  return '';
}

sub time_lrc { # Convert timestamps, e.g 6230 to 1:2.3
  my $ts = shift;
  my $cs = $ts % 100; $ts = int($ts/100);
  my $sec = $ts % 60; $ts = int($ts/60);
  my $min = $ts;
  return sprintf( "%02d:%02d.%02d", $min,$sec,$cs );
}

sub seconds_to_hms { # Convert Seconds to H:M:S, Unused.
    my $t = shift;  # t=total time in seconds
    my $seconds = $t % 60; $t=($t-$seconds)/60; # t now has minutes
    my $minutes = $t % 60; $t=($t-$minutes)/60; # t now has hours
    my $hours   = $t % 24; $t=($t-$hours)  /24; # t now has days

    my $str = '';
    $str .= "$t days, " if $t>0;
    $str .= sprintf "%2d:%02d:%02d", $hours, $minutes, $seconds;
} 

sub max {
  my($a, $b) = (shift,shift);
  return $a>$b ? $a : $b;
}


