
use strict;
use warnings;

BEGIN { require 5.006; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'create a minimal mirror of CPAN',
  'AUTHOR' => 'Ricardo SIGNES <rjbs@cpan.org>, Randal Schwartz <merlyn@stonehenge.com>',
  'BUILD_REQUIRES' => {
    'Test::More' => '0.96'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'CPAN-Mini',
  'EXE_FILES' => [
    'bin/minicpan'
  ],
  'LICENSE' => 'perl',
  'NAME' => 'CPAN::Mini',
  'PREREQ_PM' => {
    'Carp' => '0',
    'Compress::Zlib' => '1.20',
    'File::Basename' => '0',
    'File::Copy' => '0',
    'File::Find' => '0',
    'File::HomeDir' => '0.57',
    'File::Path' => '2.04',
    'File::Spec' => '0',
    'File::Temp' => '0',
    'Getopt::Long' => '0',
    'LWP::UserAgent' => '5',
    'Pod::Usage' => '1.00',
    'URI' => '1'
  },
  'VERSION' => '1.110',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



