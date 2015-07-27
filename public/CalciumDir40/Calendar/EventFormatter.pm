# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Event - formatting routines for dumping Calcium events (mostly for mail)

package Event;
use strict;

sub formatForMail {
    my ($self, $date, $calName, $prefs, $i18n) = @_;

    my %vals = (calName   => $calName,
                text      => $self->text,
                category  => $self->getCategoryScalar,
                scheduled => $date->pretty ($i18n),
                popup     => $self->popup || $self->link);

    # And custom fields
    if (Defines->has_feature ('custom fields')) {
        require Calendar::Template;
        my $templ = Template->new (name     => 'Mail',
                                   cal_name => $calName,
                                   convert_newlines => 1);

        $vals{custom} = $self->custom_fields_display (template => $templ,
                                                      prefs    => $prefs,
                                                      escape   => undef,
                                                      format   => 'html');
        $vals{custom_text} = $self->custom_fields_display (template => $templ,
                                                           prefs    => $prefs,
                                                           escape   => undef,
                                                           format   => 'text');
    }

    if ($self->startTime) {
        $vals{scheduled} .= ', ' . $self->getTimeString ('both', $prefs);
    }

    my %labels = (calName   => $i18n->get ('Calendar Name:'),
                  text      => $i18n->get ('Event text:'),
                  category  => $i18n->get ('Category:'),
                  scheduled => $i18n->get ('Scheduled for:'),
                  popup     => $i18n->get ('Details:'),
                 );

    my @usedLabels = grep {$vals{$_}} keys %labels; # labels which are used
    # find longest label
    my $max = [sort {$a <=> $b}
                map {length}
                map {$labels{$_}} @usedLabels]->[-1];

    # Wrap long text to indent properly
    if (eval "require Text::Wrap") {
        my $indent = ' ' x ($max + 1);
        $Text::Wrap::columns = 72;
        $Text::Wrap::huge    = 'overflow';
        $Text::Wrap::columns = 72;         # avoid 'used only once' warnings
        $Text::Wrap::huge    = 'overflow';
        foreach (qw /text popup/) {
            next unless defined ($vals{$_});
            $vals{$_} = Text::Wrap::wrap ($indent, $indent, ($vals{$_}));
            $vals{$_} =~ s/^\s*//;
        }
    }

    my $text = '';
    foreach (qw /calName scheduled text category popup/) {
        next unless $vals{$_};
        $vals{$_} =~ s/\r//g;
        $text .= sprintf ("%-*s %s\n", $max, $labels{$_}, $vals{$_});
    }
    if (defined $vals{custom_text}) {
        $text .= "\n$vals{custom_text}\n";
    }

    $vals{text}  = $self->escapedText  (undef, 1);
    $vals{popup} = $self->escapedPopup (undef, 1) if ($vals{popup});


    my $html = '<table>';
    foreach (qw /calName scheduled text category popup/) {
        next unless $vals{$_};
        $html .= qq (<tr><td valign="top"><b>$labels{$_}</b></td>) .
                 qq (<td>$vals{$_}</td></tr>);
    }
    $html .= '</table><br/>';
    if (defined $vals{custom}) {
        $html .= "\n$vals{custom}\n";
    }

    return ($text, $html);
}

sub expandString {
    my ($self, $string, $date, $i18n) = @_;
    return unless defined $string;
    $string =~ s/ \$text     / $self->text                     /xeg;
    $string =~ s/ \$date     / $date->pretty ($i18n)           /xeg;
    $string =~ s/ \$category / $self->getCategoryScalar || '-' /xeg;
    $string =~ s/ \$user     / $self->owner             || '-' /xeg;
    $string;
}

1;
