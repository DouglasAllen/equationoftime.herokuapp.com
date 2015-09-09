# Copyright 2000-2006, Fred Steinberg, Brown Bear Software

package Category;
use strict;
use vars qw ($AUTOLOAD %validField);

# Valid Fields
BEGIN {foreach (qw (name bg fg border showName)) {$validField{$_}++;}}

sub new {
  my $class = shift;
  my %args = (name => '',
              @_);
  return undef unless defined $args{name};
  my $self = {};
  bless $self, $class;

  while (my ($key, $value) = each %args) {
      warn "Bad Param to Category! '$key'\n", next unless $validField{$key};
      $self->{$key} = $value if defined $value;
  }

  $self;
}

# Need special check here for backwards compatibility
sub showName {
    my ($self, $new_value) = @_;
    if ($new_value) {
        $self->{showName} = $new_value;
    }
    if ($self->{showName} eq 'on') {    # old versions were just on or off
        return $self->name;
    }
    return $self->{showName};
}

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;           # get rid of package names, etc.
    return unless $name =~ /[^A-Z]/;  # ignore all cap methods; e.g. DESTROY 

    $self->{$name} = shift if (@_);
    $self->{$name};
}

# see if all fields of two objects are eq
sub sameAs {
    my ($self, $other) = @_;
    return undef unless $other;
    foreach (keys %validField) {
        return undef unless (($self->{$_} || '') eq ($other->{$_} || ''));
    }
    return 1;
}

sub serialize {
    my $self = shift;
    join $;, %$self;
}

sub unserialize {
    my $classname = shift;
    my (%values) = @_;
    $classname->new (%values);
}

1;
