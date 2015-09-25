#!/usr/bin/env perl
# ./snapshot.pl < OAR.*.stdout | column -t -s $'\t'

use strict;
use warnings;

my $basemem = undef;

my $name = undef;
my $np   = undef;
my $type = undef;
my $mem = undef;
my $max = undef;
my $clock = undef;
my $states = undef;

sub state_reset() {
  $name = undef;
  $np = undef;
  $type = undef;
  $mem = undef;
  $max = undef;
  $clock = undef;
  $states = undef;
}

sub dump_test {
  if ($name && $mem) {
    $states = "-" if !$states;
    $clock = "-" if !$clock;
    $max = $max / 1024 if $max;
    $max = sprintf("%5.2f", $max) if $max;
    $max = "-" if !$max;
    my $dmem;
    $dmem = ($mem / 1024) if !$basemem and $mem;
    $dmem = ($mem - $basemem) / 1024 if $basemem and $mem;
    $dmem = sprintf("%5.2f", $dmem) if $dmem;
    $dmem = "-" if !$mem;
    printf "$name\t$np\t$type\t$states\t$clock\t$max\t$dmem\n";
    state_reset();
  }
}

state_reset();
print "name\tnp\ttype\tstates\tclock\tmax\tmem\n";
foreach (<>) {

  if (m|^-/\+ buffers/cache:[ \t]+([0-9]+)|) {
    if (!$basemem && !$name) {
      $basemem = int($1);
    } elsif ($name) {
      $mem = int($1);
    }
  }

  elsif (m/^\*\*\* XP ([^ ]*) NP=([0-9*]) ([^ ]*)\n/) {
    dump_test();
    $name = $1;
    $np   = $2;
    $type = $3;
  }

  elsif (!$name) {

  }

  elsif (m/^\[0\.000000\] \[mc_global\/INFO\] Expanded states = ([0-9]*)/) {
    $states = $1;
  }

  elsif (m/clock:([0-9\.]*) user:([0-9\.]*) sys:([0-9\.]*) swapped:[0-9\.]* exitval:[0-9]* max:([0-9\.]*)k/) {
    $max = $4;
    $clock = $1;
  }

}

dump_test();
