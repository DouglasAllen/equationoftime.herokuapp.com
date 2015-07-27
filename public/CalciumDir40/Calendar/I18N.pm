# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Internationalization support

use strict;

package I18N;

use Calendar::Defines;

# Current languages, mapped to their native names:
my %langMap = (Danish    => 'Dansk',
               English   => 'English',
               French    => 'Français',
               German    => 'Deutsch',
               Hungarian => 'Magyar',
               Italian   => 'Italiano',
               Norwegian => 'Norsk Bokmål',
               Portugese => 'Português',
               Spanish   => 'Español',
               Dutch     => 'Nederlands',
              );

my %loadedStrings = (English => {});

sub new {
    my $class = shift;
    my $language = shift;
    my $self = {};

    $language = 'English' unless ($language && defined $langMap{$language});

    $self->{Language} = $language;

    # May be cached, if we're mod_perl'ing
    if (exists $loadedStrings{$language}) {
        $self->{'map'} = $loadedStrings{$language};
    } else {
#        warn "Loading Language: $language\n";
        my $filename = Defines->baseDirectory . "/Calendar/I18N/$language.pl";
        $filename = "./$filename" unless ($filename =~ /^(\/|[a-zA-Z]:|\\)/);

        no strict;
        $filename =~ /^(.*)$/;    # untaint
        $filename = $1;           #    it  (note the defined $langMap above)
        $retval = do "$filename";

        unless ($retval) {
            warn "Couldn't parse $filename: $@" if $@;
            warn "Couldn't do $filename: $!"    unless defined $retval;
            warn "Couldn't run $filename"       unless $retval;
        }
        $loadedStrings{$language} = \%strings;
        $self->{'map'} = \%strings;
        use strict;
    }

    bless $self, $class;
    return $self;
}

sub getLanguage {
    my $self = shift;
    $self->{Language};
}

sub get {
    my ($self, $key) = @_;
    return "x$key" if !ref ($self);  # so we can tell we screwed up...
    return $self->{'map'}->{$key} || $key;
}

sub getLanguages {
    return %langMap;
}

1;
