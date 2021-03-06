#!/usr/bin/perl
# What: Group files by date/location (with exiftool)
# test: perl -e 'system(qq/exiftool -c "%.4f" -GPSPosition x.jpg/)'
#       $latlong = q/GPS Position : 18.2213 N, 72.2781 E/;
# from https://unix.stackexchange.com/questions/49701/bash-grouping-files-by-name/49756
# 2019-12-21

use strict;
use warnings;
use File::Find;

my %groups;

my $grouper;  
my ($verbose, $showcount, $mv, $header,$sortcount) = (0,0,1,0,0);
my ($bydir,$byloc);
my ($fcount,$gcount);

my $USAGE  = <<"END_USAGE";
USAGE: cmd [OPTIONS] [-by...] [DIR or list.txt] | vi - and :%!bash
WHAT: group files by pattern .. prints grouper.sh bash script to mv files to dir-groups
OPTIONS:
  -by:regex  .. Group by, default: -by=grouper-regex
                eg. -by:(2019\\d\\d) by month, -by:(20\\d\\d) by year
  -bydir     .. group each dir separately.
  -byloc     .. group by location using exiftool to get latlong
                Eg. -byloc5 for 5 decimal latlong from img
                Eg. cmd -mv -byloc2 -by:loc.+ .
  -c         .. showcount
  -mv        .. show mv files group/, eg. cmd -mv .. | vi - and :%!bash

  -s:[-+]100 .. sortcount asc/desc, show counts lt/gt 100, default sort by group name.
    -lt:N -gt:N    eg. -lt:44 -gt:77 .. only move groups less/more than 44/77.

  -h,-v      .. help, verbose
Notes:
  DIR        .. calls find DIR or generate list.txt with
                > find . -printf "%y%d\\t%12s\\t%TY-%Tm-%Td-%TH%TM\\t%p %l\\n" > list.txt
  Idempotent .. Wont move already grouped dirs/files.
Example:
  > mv7.sh -c .  .. Counts
  > mv7.sh -gt:5 .. Show mv of dirs having more than 5.
END_USAGE

while( $_ = $ARGV[0], defined($_) && m/^-/ ){ shift; last if /^--$/; if(0){
  }elsif( m/^-[h?]$/ ){ die $USAGE;
  }elsif( m/^-v$/    ){ $verbose++;
  }elsif( m/^-by:(.*)$/    ){ $grouper=$1;
  }elsif( m/^-bydir$/    ){ $bydir=1;
  }elsif( m/^-byloc$/    ){ unshift(@ARGV,'-byloc5');
  }elsif( m/^-byloc(\d+)$/    ){
    $byloc="exiftool -c %.".$1."f -GPSPosition ";
    $grouper = '(loc_.+)';
    warn "# byloc=$byloc\n";
  }elsif( m/^-mv$/    ){ $mv=1;
  }elsif( m/^-c$/    ){ $showcount=1;
  
  }elsif( m/^-lt:(\d+)$/    ){ $sortcount=-$1;
  }elsif( m/^-gt:(\d+)$/    ){ $sortcount=+$1;
  }elsif( m/^-s:([+-]\d+)$/    ){ $sortcount=$1;

  }else{ die $USAGE,"Unknown option '$_'\n"; }
}

# Default is show counts, if nothing.
$showcount=1
  unless $showcount or $mv;

# Add default whole parenthesis if missing for matching groups.
$grouper = q,\b((\d{4})\W?(\d{2})\W?(\d{2}))\b,
  unless $grouper;

$grouper = "($grouper)"
  unless $grouper =~ m,[(].*[)],;

print "# grouper=m{$grouper}\n" if $verbose;

die $USAGE."Need dir or list.txt to process.\n"
  unless @ARGV;

foreach my $arg1 ( @ARGV ){
  warn "# Processing $arg1\n";
  ($fcount,$gcount)=(0,0);
  if (-d $arg1){
    File::Find::find( \&find_file_filter, $arg1 );
  }elsif( -f $arg1 ){ 
    process_list($arg1);
  } else{
    die "Need dir or list.txt to process files, not a file or dir: $arg1\n";
  }
  warn "# Grouped $gcount from $fcount in $arg1\n";
}

my @sorted; 
sort_groups();
print_groups();

sub sort_groups {
  # while( my( $group, $files_arr_ref ) = each %groups ) {
  if ($sortcount > 0 ){ # sort asc by count
    @sorted = sort { scalar( @{$groups{$a}} ) - scalar( @{$groups{$b}} ) } keys %groups;
  }elsif ($sortcount < 0){ # sort desc by count
    @sorted = sort { scalar( @{$groups{$b}} ) - scalar( @{$groups{$a}} ) } keys %groups;
  }else{ # sort by group name
    @sorted = sort keys %groups;
  }
}

sub print_groups {
  my $moves=0;
  for my $group (@sorted) {
      my $files_arr_ref = $groups{$group};
      my $sc = scalar(@{$files_arr_ref});
      next if $sortcount > 0 && $sc <  $sortcount; # show larger asc
      next if $sortcount < 0 && $sc > -$sortcount; # show smaller desc
      $moves += $sc;
      if ( $showcount ) {
        print("# CNT GROUP of files to move\n") unless $header++;
        printf("# %3d %s/\n",  $sc, $group );
        next;
      }
      if ( $mv ) {
        print "mkdir -p $group  # count=$sc\n";
        for my $file (sort @{$files_arr_ref}) {
            print "  mv -vi $file $group/\n";
        }
      }
  }
  printf("# groups=%d, moves=%d\n",scalar(@sorted),$moves);
}

sub group_add {
  my ($dir,$file)=@_;
  my ($tomatch)= $file;
  if( $byloc && -f "$dir/$file" ){
    my $latlong = `$byloc $dir/$file`;
    # if ($latlong =~ m/:\s+(\d+)\.(\d+)\s([NS]),\s+(\d+)\.(\d+)\s([EW])/ ){
    #   $latlong = "loc_$1_$2$3-$4_$5$6";
    # }
    if ($latlong =~ m/:\s+(.+)/ ){
      $latlong = "loc_$1";
      $latlong =~ s/[\s,]+//g;
    }
    $tomatch = $latlong;
  }

  # Idempotent, if already grouped into dir?
  return if $dir =~ m/$grouper/io;

  return unless $tomatch =~ m/$grouper/o;
  $fcount++;
  $gcount++;
  my $match = $1;
  my $group = $match;
     $group = $dir.'/'.$group if $bydir;
  push @{ $groups{ $group } }, $file;
}

sub find_file_filter {
    my ($dir,$file)=($File::Find::dir, $File::Find::name);
    group_add($dir,$file);
}

sub list_filter {
    my ($dir,$file)=@_;
    group_add($dir,$file);
}

sub process_list {
    my $list=shift;
    open(LIST,"<$list") or die "Error: Cannot read list=$list\n";
    while (<LIST>) {
      next unless m/^[fd]/;
      my($fd,$size,$date,$path) = split();
      die "bad list.txt\n" unless $date =~ m/^\d{4}-\d{2}-\d{2}/;
      my($dirname,$file) = ($path,$path);
      $file =~ s,^.*/,,; $dirname =~ s,/[^/]*$,,;
      list_filter($dirname,$file);
    }
}
