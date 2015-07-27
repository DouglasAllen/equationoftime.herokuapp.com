# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

use strict;

package FooterSection;

sub new {
    my ($class, $prefs, $prefName) = @_;
    my $self = {name => $prefName};
    bless $self, $class;

    my $content = $prefs->$prefName();

    unless ($content) {
        $self->{html} = '';
        return $self;
    }

    $content =~ s/\n/<br>/g unless ($content =~ /<[^>]*>/);

    $self->{html} = $content;
    $self;
}

sub getHTML {
    my $self = shift;
    return '' unless $self->{html};
    return qq (<div class="$self->{name}">$self->{html}</div>);
}



package Footer;
use vars ('@ISA');
@ISA = ('FooterSection');

sub new {
    my $class = shift;
    return $class->SUPER::new (@_, 'Footer');
}


package SubFooter;
use vars ('@ISA');
@ISA = ('FooterSection');

sub new {
    my $class = shift;
    return $class->SUPER::new (@_, 'SubFooter');
}

1;
