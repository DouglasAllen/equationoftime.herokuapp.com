# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package Name;
use strict;

# Title, Header

sub new {
    my $class = shift;
    my ($prefs, $printObj) = @_;
    my $self = {};
    bless $self, $class;

    my $title  = $prefs->Title;
    my $header = $prefs->Header;

    # replace newlines w/<br> unless it's got HTML in it
    foreach ($title, $header) {
        next unless $_;
        next if /<[^>]*>/;
        s/\n/<br>/g;
    }

    # If print view, maybe don't show some stuff
    undef $title  if ($printObj and !$printObj->title);
    undef $header if ($printObj and !$printObj->header);

    return $self unless ($title or $header);

    $self->{html} = '<table width="100%" border="0" cellspacing="0">';

    if ($title) {
        $self->{html} .= qq (<tr><td class="Title">$title</td></tr>);
    }

    # Now add any descriptive header strings there may be
    if ($header) {
        $self->{html} .= qq (<tr><td class="Header">$header</td></tr>);
    }

    $self->{html} .= "</table>\n";
    $self;
}

sub getHTML {
    my $self = shift;
    return $self->{html};
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css = Operation->cssString ('.Title',
                              {bg            => $prefs->color ('TitleBG'),
                               color         => $prefs->color ('TitleFG'),
                               'font-size'   => 6,
                               'font-weight' => 'bold',
                               'text-align'  => $prefs->TitleAlignment});
    $css;
}

1;
