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
#version 0.2.4, 04.11.09 -- added homepage, --test option and updated help
#version 0.2.5, 06.11.09 -- added --date option 
#version 0.2.6, 11.11.09 -- fixed help + parse_gs(NO SEMINAR)
#version 0.2.7, 25.11.09 -- do not send email something if not parsed
#version 0.2.8, 02.12.09 -- strip non ASCI ASCII stuff in parse_gs
#version 0.2.9, 16.12.09 -- fixes some pattern problem

use strict;
use LWP::Simple;

$_=$0;
s#^.*/##;
my $progname=$_;
my $usage="Usage: $progname [OPTIONS]";
my @sites=("http://www.mpip-mainz.mpg.de/~peter/dates",
           "http://www.mpip-mainz.mpg.de/theory.html/seminar/group_seminar");

my @websites=("http://www.mpip-mainz.mpg.de/~poma/multiscale/mm-seminar.php",
              "http://www.mpip-mainz.mpg.de/theory.html/seminar/group_seminar");

#Defaults
my $quiet=undef;
my $sendermail='pdsoftie@mpip-mainz.mpg.de';
my $sendername='"The AutoReminder <'.$sendermail.'>"';
my $towho='ak_kremer@mpip-mainz.mpg.de';
my $usermail="$ENV{USER}\@mpip-mainz.mpg.de";
my $homepage='http://pckr99.mpip-mainz.mpg.de:1234/mpip_scripts';
my $today_mode="no";
my @times= localtime(time);
my $time=$times[2]*60+$times[1];
my $date=sprintf("%02i.%02i.%02i",$times[3],$times[4]+1,$times[5]-100);
my $nicetime=sprintf("%02i:%02i",$times[2],$times[1]);
my $subject;
my $delta=15;

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
This is the autoreminder script.
$usage

By default it sends an email to $towho, if it finds a talk
which is at maximum $delta min away.

Use --today option to get an overview about all talks of the day.

Websites checked by autoreminder:
@websites

OPTIONS:
    --today           Mail a summary of the talk today
    --stdout          Show mail on stdout, do NOT send it!
    --date XX.XX.XX   Change to date of the day
                      Default: today ($date)
    --test            See the email ONLY to you 
                      ($usermail)
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
    print "$progname, $version\n";
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
  elsif ($ARGV[0] eq "--date")
  {
    shift(@ARGV);
    $date=shift(@ARGV);
    die "Argument of date should have the form 'XX.XX.XX'" unless $date =~ /^\d\d\.\d\d\.\d\d$/;
  }
  elsif ($ARGV[0] eq "--test")
  {
    $towho="$usermail";
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
  $number=find_talk($delta);
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
$version, written to inform $towho
Visit my homepage $homepage.
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
    next if /^\s*$/;
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
    $line .= " $lines[$i+1] "."$lines[$i+2] "."$lines[$i+3]";
    $i+=3;
    #strip html tags
    $line =~ s/<.*?>//g;
    #delete non-unicode characters
    $line =~ s/\P{IsASCII}//g;
    next if ( $line =~ /NO\W*SEMINAR/g);
    #remove space for end and beginnig
    $line =~ s/^\s*(.*?)\s*$/$1/;
    if ( $line =~ /^$date\s*(.*?)\s*\((.*?)\)$/ ){
      push(@speakers,$1);
      push(@topics,$2);
      push(@seminarnames,"Group Seminar");
      push(@seminartimes,"15:30");
      push(@seminarnr,$_[1]);
      $enable="yes";
    }
    #else {
    #  push(@speakers,"Unknown");
    #  push(@topics,"Unknown(Change the pattern in parse_gs in $progname");
    #}
  }
  return $enable;
}
