use strict;
use warnings;
package CPAN::Mini::App;
our $VERSION = '1.100470_001';
# ABSTRACT: the guts of the minicpan command


use CPAN::Mini;
use File::HomeDir;
use File::Spec;
use Getopt::Long qw(GetOptions);
use Pod::Usage 1.00;

sub _display_version {
  my $class = shift;
  no strict 'refs';
  print "minicpan",
    ($class ne 'CPAN::Mini' ? ' (from CPAN::Mini)' : q{}),
    ", powered by $class ", $class->VERSION, "\n\n";
  exit;
}


sub run {
  my %config = CPAN::Mini->read_config;
  $config{class} ||= 'CPAN::Mini';
  my $version;

  GetOptions(
    "c|class=s"   => \$config{class},
    "h|help"      => sub { pod2usage(1); },
    "v|version"   => sub { $version = 1 },
    "l|local=s"   => \$config{local},
    "r|remote=s"  => \$config{remote},
    "d|dirmode=s" => \$config{dirmode},
    "qq"          => sub { $config{quiet} = 2; $config{errors} = 0; },
    'offline'     => \$config{offline},
    "q+" => \$config{quiet},
    "f+" => \$config{force},
    "p+" => \$config{perl},
    "x+" => \$config{exact_mirror},
  ) or pod2usage(2);

  eval "require $config{class}";
  die $@ if $@;

  _display_version($config{class}) if $version;
  pod2usage(2) unless $config{local} and $config{remote};

  $|++;
  $config{dirmode} &&= oct($config{dirmode});

  $config{class}->update_mirror(
    remote  => $config{remote},
    local   => $config{local},
    trace   => (not $config{quiet}),
    force   => $config{force},
    offline => $config{offline},
    also_mirror    => $config{also_mirror},
    exact_mirror   => $config{exact_mirror},
    module_filters => $config{module_filters},
    path_filters   => $config{path_filters},
    skip_cleanup   => $config{skip_cleanup},
    skip_perl      => (not $config{perl}),
    (defined $config{dirmode} ? (dirmode => $config{dirmode}) : ()),
    (defined $config{errors}  ? (errors  => $config{errors})  : ()),
  );
}


1;

__END__
=pod

=head1 NAME

CPAN::Mini::App - the guts of the minicpan command

=head1 VERSION

version 1.100470_001

=head1 SYNOPSIS

  #!/usr/bin/perl
  use CPAN::Mini::App;
  CPAN::Mini::App->run;

=head1 METHODS

=head2 run

This method is called by F<minicpan> to do all the work.  Don't rely on what it
does just yet.

=head1 SEE ALSO 

Randal Schwartz's original article, which can be found here:

  http://www.stonehenge.com/merlyn/LinuxMag/col42.html

=head1 AUTHORS

  Ricardo SIGNES <rjbs@cpan.org>
  Randal Schwartz <merlyn@stonehenge.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

