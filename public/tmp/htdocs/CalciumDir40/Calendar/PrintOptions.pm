# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

package PrintOptions;
use strict;
use vars qw ($AUTOLOAD %validField);

my %validField = (colors => 1, title => 1, header => 1,
                  dateHeader => 1, footer => 1, background => 1);

# colors : [none, some, all];

sub new {
    my ($class, %params) = @_;
    $params{colors} ||= 'none';
    my $self = \%params;
    bless $self, $class;
    $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;                 # get rid of package names, etc.
    return unless $name =~ /[^A-Z]/;  # ignore all cap methods; e.g. DESTROY 

    die __PACKAGE__ . ": bad field name! '$name'\n" unless $validField{$name};

    $self->{$name} = shift if (@_);
    $self->{$name};
}

sub isColorMode {
    my ($self, $mode) = @_;
    return unless defined $mode;
    return ($self->{colors} eq $mode);
}

1;
