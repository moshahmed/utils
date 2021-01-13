#!/usr/bin/perl -w
# GPL(C) MoshAhmed.at.gmail 
use strict;
use warnings;
use Time::Piece;

my( $cmd ); ( $cmd = $0 ) =~ s,.*[/\\],,;
my $DATE=localtime->strftime('%Y-%m-%d_%H%M');

my $USAGE=q{
USAGE: $cmd [options] infile.txt > outfile.srt
What: Convert file.txt into srt/lrc, interpolate or add timing marks.
How: counts words in file and allocates equal time for each line.
Options:
    -hms=hh:mm:ss      .. Total_time of mp3, computed by mp3info -x file.mp3 if not given
    -mini_lyrics=[012]  .. Output lrc for mini_lyrics 
                          Output h:m:s.cs if 1.
                          Output mm:ss    if 2 for shakespeare.
    -roundtime=[01]    .. round time to seconds in mini_lyrics (default is on)
    -comments=regex    .. passthru matching lines.
    -v      .. verbose .. print #_prefixed_lines in output for debugging.
    -h      .. help.
Pragmas in input:
  ;retiming=0 .. default, preserve timings in input.
  ;retiming=1 .. recompute timings.
};

# Default options and globals.
my $verbose=0;
my $mini_lyrics=2;


my $total_time=0;
my $comments='^[#;@]|^\s*$';
my $retiming=0;
my $roundtime=1;
 
# Process options
while( $_ = $ARGV[0], defined($_) && m/^-/ ){ shift; last if /^--$/; if(0){
    }elsif( m/^-[h?]$/ ){ die $USAGE;
    }elsif( m/^-hms=(.+)$/    ){ $total_time = $1;
      $total_time =~ s/:?$/:/; # add a trailing colon for consistency.
      die "Total time must be hh:mm:ss" unless $total_time =~ m/^(\d+:)+$/ ;
      $total_time = hms_to_ms($total_time);
      print "# total_time=$total_time ms, PWD=$ENV{PWD}, DATE=", get_ymd(), "\n";
    }elsif( m/^-mini_lyrics=(\d+)$/    ){ $mini_lyrics=$1;
    }elsif( m/^-comments=(.*)$/    ){ $comments=$1;
    }elsif( m/^-roundtime=(.*)$/    ){ $roundtime=$1;
    }elsif( m/^-v$/    ){ $verbose++;
    }else{ die $USAGE,"Unknown option '$_'\n"; }
}

# Read input text file.
my $infile = shift or die $USAGE."Need infile.txt to process.\n";
open(INFILE,"<$infile") or die "Cannot read $infile.\n";
undef $/; my $file_slurp = <INFILE>; $/ = "\n";  
my @lines = split( /\n+/o, $file_slurp );   

# Get total time from mp3info infile.mp3
if ($total_time == 0){
  my $mp3file = $infile;
  $mp3file =~ s,.\w+$,.mp3,;
  die "Need $mp3file to get total_time" unless -s $mp3file;
  my $mp3info = `mp3info -x $mp3file 2>&1`;
  if ( $mp3info =~ m,Length:\s+(\d+):(\d+),s ){
      $total_time = $1*60+$2; # in hh:mm
      $total_time *= 1000; # in milliseconds
  }
  warn "total_time=$total_time ms\n" if $verbose;
}

# Count words in text file.
die $USAGE unless $total_time;
my ($total_words) =  word_count($file_slurp);
my $time_per_word = $total_time / $total_words;
print "# total_words=$total_words, time_per_word=$time_per_word ms\n"
  if $verbose;

# Process file line by line.
my $line_printed = 0;
my $cum_time = 0;
my $cum_words = 0;
foreach my $line (@lines) {

  if ( $line =~ m/;\s*retiming=(\d+)/i ){
    $retiming=$1;
    print $line,"\n";
    next;
  }
  if ($comments && $line =~ m/$comments/io) {
    print $line,"\n";
    next;
  }

  if ($retiming) {
    $line =~ s,^\[[^]]*\]\s*,,mg;
  } 

  my ($line_words) = word_count($line);
  $cum_words += $line_words;
  my $line_time = $line_words * $time_per_word;

  if (!$retiming && $line =~ m/^\[((\d+):)*(\d+\.\d+)\]/ ){ 
    # User has given correct time offset?
    my $user_cum_time =  ($2 * 60 + $3)*1000;
    printf("%d vs %d on $. $line\n", $cum_time/1000, $user_cum_time/1000) 
        if $verbose;
    $cum_time = $user_cum_time;
    print $line,"\n";

    # Recompute $time_per_word
    my $words_left = $total_words - $cum_words;
    my $time_left = $total_time - $cum_time;
    $time_per_word = $time_left / $words_left;
    printf("# words_left=$words_left, time_left=$time_left, time_per_word=%2.2f ms\n", $time_per_word/1000)
      if $verbose;
    next;
  }
  show_info($line,$line_time,$line_words);

  $line =~ s,^\[[^]]*\]\s*,,mg;
  next if $line =~ /^$/;
  print_line($line,$cum_time,$line_time);
  $cum_time += $line_time;
}
print_line("# By $cmd $infile on $DATE", $cum_time, 1000);

# ==================================================

sub word_count {
  my $line = shift;
  my @lines = split(/\n/, $line);
  my $wc = 0;
  my $nl_count = 0;
  LINE: for my $line (@lines) {
    $nl_count += ($line =~ tr/\n//); # TODO
    for ($line) {
      s,^\s+,,;      # Trim whitespaces
      s,\s+$,,;
      s,^\[[^]]*\]\s*,,;  # Trim /[timestamps]/
    }
    next LINE if $line =~ m/$comments/io;
    my @words = split(/\W+/,$line);
    $wc += scalar(@words);
  }
  return $wc;
}

sub print_line {
  my $line = shift;
  my $tt = shift;
  my $line_time = shift;
  $line_printed++;
  if ($mini_lyrics) {
    # printf "[id: $cmd]\n[ar:Artist]\n[ti:Title]\n[al:Album]\n\n"
    #  if $line_printed==1;
    printf("[%s] %s\n", time_str($tt), $line);
  } else {
    printf "%d\n%s --> %s\n%s\n\n", $line_printed,
      time_str($tt), time_str($tt+$line_time), $line;
  }
}

sub time_str { # convert float to h:m:s
  my $t = shift;
  $t /= 1000;
  my $hh = int ($t / 3600);
  my $mm = int (($t - $hh * 3600) / 60);
  my $ss = int ($t - $hh * 3600 - $mm * 60);
  my $tstr;
  if ($mini_lyrics==2) {
    $tstr = sprintf ("%d:%d", $t/60, $t % 60);
  } elsif ($mini_lyrics==1) {
    my $centi_seconds = int (($t - int ($t)) * 100 + 0.5);
    $centi_seconds = 0 if $roundtime>0;
    if ($hh>0) { # Dont print hours in lrc unless needed.
      $tstr = sprintf ("%02d:%02d:%02d.%02d", $hh, $mm, $ss, $centi_seconds);
    }else{
      $tstr = sprintf ("%02d:%02d.%02d", $mm, $ss, $centi_seconds);
    }
  }else{
    my $milli_seconds = int (($t - int ($t)) * 1000 + 0.5);
    $tstr = sprintf ("%02d:%02d:%02d,%03d", $hh, $mm, $ss, $milli_seconds);
  }
  print "# time_str($t) -> $tstr\n" if $verbose > 1;
  return $tstr;
}

sub hms_to_ms { # Convert total_time into milli-seconds.
  my $total_time = shift;
  my $factor = 1000;
  my $est_time;
  while( $total_time =~ s/([\d.]+):$// ) { # total_time in h:m:s => est_time in milli-seconds
    $est_time += $1 * $factor;
    $factor *= 60;
  }  
  return $est_time;
} 

sub get_ymd {
  my(undef, $min, $hour, $mday, $month, $year, undef, undef) = localtime(time());
  my $date_is = sprintf("%04d%02d%02d", $year+1900, $month+1, $mday); # $hour, $min
  return $date_is;
}

sub show_info {
  return unless $verbose;
  my($line,$line_time,$line_words)=@_;
  printf("#%s line:time=%d s, words=$line_words, ", time_str($cum_time), int($line_time/100)/10);
  printf("time=%d/%d=%4.4f, ", int($cum_time/1e3), int($total_time/1e3), $cum_time/$total_time);
  printf("words=$cum_words/$total_words=%4.4f", $cum_words/$total_words);
  printf(" line=[[$line]]");
  printf("\n");
} 
