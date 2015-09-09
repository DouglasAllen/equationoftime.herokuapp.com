# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# Display one or more days worth of events, simple view for SSI / IFRAME

package IncludeView;
use strict;

use CGI;
use Calendar::Date;
use Calendar::DisplayFilter;

sub new {
    my $class = shift;
    my ($op, $startDate, $endDate) = @_;
    my $self = {};
    bless $self, $class;

    my $db      = $op->db;
    my $i18n    = $op->I18N;
    my $prefs   = $op->prefs;
    my $calName = $op->calendarName;
    my $cgi     = CGI->new;

    my $showWeekend = $prefs->ShowWeekend || ($startDate == $endDate);

    my $events = $db->getEventDateHash ($startDate-1, $endDate+1, $prefs);
    my $display_filter = DisplayFilter->new (operation => $op);

    my @date_html;

    # Simple <div> block for each day; each event is in it's own <div>
    for (my $date = Date->new ($startDate); $date <= $endDate; $date++) {

        next if (!$showWeekend and $date->isWeekend);

        my @events = @{$events->{"$date"} || []};

        # Filter out tentative/private events, setting privacy display flag too
        @events = $display_filter->filterTentative (\@events);
        @events = $display_filter->filterPrivate (\@events);
        @events = $display_filter->filter_from_params (\@events);

        @events = Event->sort (\@events, $prefs->EventSorting);

        my @colors = ($prefs->color ('EventBG'), $prefs->color ('EventFG'));

        my $day_name = $date->dayName;
        my $date_html = qq /<div class="$day_name">/;

        foreach (@events) {
            my ($bg, $fg, $textID)
                          = _get_event_display_stuff (event      => $_,
                                                      prefs      => $prefs,
                                                      calName    => $calName,
                                                      def_colors => \@colors);
            my $ev_html = qq /<div class="Event"
                                   style="background-color: $bg;">/;
            $ev_html .= $_->getHTML ({op        => $op,
                                      calName   => $calName,
                                      date      => $date,
                                      prefs     => $prefs,
                                      textID    => $textID,
                                      textFG    => $fg,
                                      i18n      => $i18n});
            $ev_html .= "</div>\n";
            $date_html .= $ev_html;
        }
        $date_html .= "</div>\n";
        my $date_header = '<span class="DateString">' . $date->pretty ($i18n)
                         . '</span>';
        my $one_day = '<div class="SimpleDay">' . $date_header . $date_html
                      . '</div>';
        push @date_html, $one_day;
#        push @date_html, '<span class="DateString">' . $date->pretty ($i18n)
#                         . '</span>';
#        push @date_html, $date_html;
    }

    $self->{html}  = Javascript->PopupWindow ($op);
    $self->{html} .= Javascript->EditEvent ($op);
    $self->{html} .= join "\n", @date_html;
    $self;
}

sub cssDefaults {
    my ($self, $prefs) = @_;

    my $css;
    $css .= Operation->cssString (  '.Monday, .Tuesday, .Wednesday, .Thursday,'
                                  . '.Friday, .Saturday, .Sunday',
                 {'xwidth'  => '100px',
                  'min-height' => '30px',
                  'border-width' => '2px',
                  'border-style' => 'solid',
                  'text-align'   => 'left'});
    $css .= Operation->cssString ('.DateString', {'font-size' => 'x-small',
                                                  'text-align' => 'center'});
    $css .= Operation->cssString ('.SimpleDay', {'text-align' => 'center',
                                                 'margin-top' => '20px'});
    $css .= Operation->cssString ('.SimpleView', {'width' => '70%',
                                                  'margin' => 'auto'});

    return $css;
}

sub getHTML {
  my $self = shift;
  return qq (<div class="SimpleView">$self->{html}</div>);
}

sub _get_event_display_stuff {
    my %args = @_;
    my $event      = $args{event};
    my $prefs      = $args{prefs};
    my $calName    = $args{calName};
    my ($default_bg, $default_fg) = @{$args{def_colors}};

    my ($fgColor, $bgColor, $border, $textID);

    if ($event->includedFrom || '' ne $calName) {
        ($fgColor, $bgColor, $border, $textID) =
          $event->getIncludedOverrides ($prefs->Includes);
    }

    my $thisOnesBG = $event->bgColor;
    my $thisOnesFG = $event->fgColor;

    if ((!$fgColor || !$bgColor) && $event->primaryCategory) {
        ($fgColor, $bgColor, $border) =
                $event->getCategoryOverrides ($prefs,
                                              MasterDB->new->getPreferences);
        $fgColor = $thisOnesFG if $thisOnesFG;
        $bgColor = $thisOnesBG if $thisOnesBG;
    }
    $bgColor ||= $thisOnesBG || $default_bg;
    $fgColor ||= $thisOnesFG || $default_fg;

    if ($prefs->inPrintMode ('none')) { # use colors for 'some'
        $fgColor = 'black';
        $bgColor = 'white';
    }
    return ($bgColor, $fgColor, $textID);
}

1;
