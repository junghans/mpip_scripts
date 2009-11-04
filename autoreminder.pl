#! /usr/bin/perl -w
#
# (C) 2006-2009 Chr. Junghans
# junghans@mpip-mainz.mpg.de
#
#
#version 0.1.5, 13.05.09 -- old version
#version 0.2.0, 26.08.09 -- merge with seminarreminder.pl
#version 0.2.1, 09.09.09 -- fixed a typo
#version 0.2.2, 30.09.09 -- only show websites of talks found in today mail 
#version 0.2.3, 28.10.09 -- fix tab problem

use strict;
use LWP::Simple;

$_=$0;
s#^.*/##;
my $progname=$_;
my $usage="Usage: $progname [OPTIONS] FILE";
my @sites=("http://www.mpip-mainz.mpg.de/~peter/dates",
           "http://www.mpip-mainz.mpg.de/theory.html/seminar/group_seminar");

my @websites=("http://www.mpip-mainz.mpg.de/~poma/multiscale/mm-seminar.php",
              "http://www.mpip-mainz.mpg.de/theory.html/seminar/group_seminar");

#Defaults
my $quiet=undef;
my $sendermail='pdsoftie@mpip-mainz.mpg.de';
my $sendername='"The AutoReminder <'.$sendermail.'>"';
my $authormail='junghans@mpip-mainz.mpg.de';
#my $towho='junghans@mpip-mainz.mpg.de';
my $towho='ak_kremer@mpip-mainz.mpg.de';
my $today_mode="no";
my @times= localtime(time);
my $time=$times[2]*60+$times[1];
my $date=sprintf("%02i.%02i.%02i",$times[3],$times[4]+1,$times[5]-100);
my $nicetime=sprintf("%02i:%02i",$times[2],$times[1]);
my $subject;

sub parse_mm($$);
sub parse_gs($$);
sub find_talk($);

while ((defined ($ARGV[0])) and ($ARGV[0] =~ /^-./))
{
  if (($ARGV[0] !~ /^--/) and (length($ARGV[0])>2)){
    $_=shift(@ARGV);
    #short opt having agruments examples fo
    if ( $_ =~ /^-[fo]/ ) {
      unshift(@ARGV,substr($_,0,2),substr($_,2));
    }
    else{
      unshift(@ARGV,substr($_,0,2),"-".substr($_,2));
    }
  }
  if (($ARGV[0] eq "-h") or ($ARGV[0] eq "--help"))
  {
    print <<END;
This is the autore script
$usage
OPTIONS:
    --today           Mail a summary of the talk today
    --stdout          Show mail on stdout, do NOT send it!
-v, --version         Prints version
-h, --help            Show this help message
-q, --quiet           Do not show messages
    --hg              Show last log message for hg (or cvs)

Examples:  $progname -q
           $progname

Send comments and bugs to: junghans\@mpip-mainz.mpg.de
END
    exit;
  }
  elsif (($ARGV[0] eq "-v") or ($ARGV[0] eq "--version"))
  {
    my $version=`perl -ne 'print "\$1\n" if /^#(version .*?) -- .*/' $0 | perl -ne 'print if eof'`;
    chomp($version);
    print "$progname, $version  by C. Junghans\n";
    exit;
  }
  elsif ($ARGV[0] eq "--hg")
  {
    my $message=`perl -ne 'print "\$1\n" if /^#version .*? -- (.*)\$/' $0 | perl -ne 'print if eof'`;
    chomp($message);
    print "$progname: $message\n";
    exit;
  }
  elsif (($ARGV[0] eq "-q") or ($ARGV[0] eq "--quiet"))
  {
     $quiet='yes';
     shift(@ARGV);
  }
  elsif ($ARGV[0] eq "--today")
  {
    $today_mode="yes";
    shift(@ARGV);
  }
  elsif ($ARGV[0] eq "--stdout")
  {
    $towho="STDOUT";
    shift(@ARGV);
  }
  else
  {
     die "Unknow option '".$ARGV[0]."' !\n";
  }
}

my @seminartimes;
my @speakers;
my @topics;
my @seminarnames;
my @seminarnr;
my $number;
my $dtime;
my @enable;

$enable[0]=parse_mm($sites[0],0);
$enable[1]=parse_gs($sites[1],1);

#exit if there is notthing to mail
exit if ($#seminartimes < 0);

if ("$today_mode" eq "yes" ) {
  $subject="\"Todays talks\""
}
else {
  $number=find_talk(15);
  defined($number) || exit;
  $subject="\"$seminarnames[$number] in $dtime minutes\"";
}

if ("$towho" ne "STDOUT") {
   open(MAIL,"| mail -r $sendername -s $subject $towho");
   select(MAIL);
}
else{
  print "Subject: $subject from $sendername\n";
}
print "Dear all,\n\n";

if ("$today_mode" eq "yes" ) {
  print "Todays talks are:\n\n";
  my @index;
  foreach (0..$#seminarnames){ $index[$_]=$_; }
  @index=sort { $seminartimes[$a] cmp $seminartimes[$b] } @index;
  for (@index) {
    print "$seminartimes[$_]\t$speakers[$_]\n     \t$topics[$_] ($seminarnames[$_])\n";
  }
  print "\nFor further infomations visit:\n";
  foreach (0..$#websites) { print "$websites[$_]\n" if defined($enable[$_]); }
}
else{
  print <<EOF
Todays speaker in the $seminarnames[$number] is $speakers[$number].
She/he will talk about "$topics[$number]".

For further infomations visit:
$websites[$seminarnr[$number]]
EOF
}

my $version=`$0 --version`;
chomp($version);
print <<EOF;

Greetings,

The AutoReminder

---------------------------------------------
This is $version.
Send bugs and comments to $authormail.
EOF

if ("$towho" ne "STDOUT") {
  select(STDOUT);
  print "$progname: $date $nicetime Date found and email to $towho send\n";
  close(MAIL) or die "$progname: Error at running mail\n";
}

###########################################################
sub parse_mm($$){
  my $site=$_[0];
  my $seminarplan = get($site);
  my @lines=split(/\n/,$seminarplan);
  my $enable=undef;
  foreach (@lines) {
    next if /^#/;
    my @parts=split(/\|/);
    #remove space from beginnig and end
    foreach (0..$#parts){$parts[$_]=~s/^\s*(.*?)\s*$/$1/;}
    #next line if date do NOT match
    next unless ($parts[0] eq $date);
    #next line for seminar with none speaker
    next if ($parts[2] =~ /none/i);
    push(@seminartimes,$parts[1]);
    #delete non-unicode characters
    $parts[2] =~ s/\P{IsASCII}//g;
    push(@speakers,$parts[2]);
    $parts[3] =~ s/\P{IsASCII}//g;
    push(@topics,$parts[3]);
    push(@seminarnames,"Modeling Meeting");
    push(@seminarnr,$_[1]);
    $enable="yes";
  }
  return $enable;
}

sub find_talk($){
   my $dt=$_[0];
   foreach (0..$#seminartimes){
     my @parts=split(/:/,$seminartimes[$_]);
     my $stime=$parts[0]*60+$parts[1];
     $dtime=$stime-$time;
     if (($dtime<=$dt) and ($dtime>1)) {
       return $_;
     }
   }
   return undef;
}

sub parse_gs($$){
  my $site=$_[0];
  my $seminarplan = get($site);
  my @lines=split(/\n/,$seminarplan);
  my $enable=undef;
  foreach (my $i=0;$i<=$#lines;$i++) {
    my $line=$lines[$i];
    next unless ($line =~ /$date/);
    #add the next three line to string
    $line .= "$lines[$i+1]"."$lines[$i+2]"."$lines[$i+3]";
    $i+=3;
    #strip html tags
    $line =~ s/<.*?>//g;
    #remove space for end and beginnig
    $line =~ s/^\s*(.*?)\s*$/$1/;
    if ( $line =~ /^$date\s+(.*?)\s+\((.*?)\)$/ ){
      push(@speakers,$1);
      push(@topics,$2);
    }
    else {
      push(@speakers,"Unknown");
      push(@topics,"Unknown(Change the pattern in parse_gs in $progname");
    }
    push(@seminarnames,"Group Seminar");
    push(@seminartimes,"15:30");
    push(@seminarnr,$_[1]);
    $enable="yes";
  }
  return $enable;
}
