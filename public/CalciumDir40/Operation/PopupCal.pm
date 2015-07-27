# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

# Display small calendar, for picking dates, etc.

package PopupCal;
use strict;

use CGI;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n    = $self->I18N;
    my $calName = $self->calendarName || '';
    my $cgi     = CGI->new;

    my $refresh;           # set to, say, 10 to refresh every 10 seconds

    # Get colors
    my $prefs = $self->prefs;
    my %colors = (bg    => $prefs->color ('MainPageBG'),
                  fg    => $prefs->color ('MainPageFG'),
                  link  => $prefs->color ('LinkFG'),
                  vlink => $prefs->color ('VLinkFG'),
                  dayFG   => $prefs->color ('EventFG'),
                  dayBG   => $prefs->color ('EventBG'),
                  todayFG => $prefs->color ('TodayFG'),
                  todayBG => $prefs->color ('TodayBG'),
                  tailBG  => $prefs->color ('MonthTailBG'),
                  tailFG  => $prefs->color ('MonthTailFG'),
                  dowFG   => $prefs->color ('WeekHeaderFG'),
                  dowBG   => $prefs->color ('WeekHeaderBG'),
                  );
    $self->{colors} = \%colors;

    # Fonts - each is [face, size]
    $self->{fonts} = {day   => [$prefs->font ('BlockDayDate')],
                      name  => [$prefs->font ('BlockDayOfWeek')],
                      event => [$prefs->font ('BlockEvent')],
                      time  => [$prefs->font ('BlockEventTime')]};
    $self->{fonts}->{day}->[1]--;
    $self->{fonts}->{name}->[1]--;

    my ($theDate, $theMonth, $theYear) =
            $self->getParams (qw/Date TheMonth TheYear/);

    $self->{_popupName} = $self->getParams ('Name');

    $self->clearParams ('IsPopup'); # we don't actually want cookie info

    $theDate = Date->new ($theDate); # if undef, it's today
    my ($year, $month, $day) = $theDate->ymd;

    # params from form above cal
    if ($theMonth or $theYear) {
        $year  = $theYear;
        $month = $theMonth;
        $theDate = Date->new ($year, $month, $day);
    }

    print GetHTML->startHTML (title   => $calName,
                              Refresh => $refresh,
                              op      => $self);

    print "<center>$calName</center>";
    my $header   = $self->monthHeader ($cgi, $theDate);
    my $calendar = $self->thumbTable ($cgi, $theDate);
    print $header;
    print $calendar;

    print qq (<div align="center">);
    print $cgi->startform;
    print $cgi->button ({-value   => $i18n->get ('Close'),
                         -onClick => 'window.close()'});
    print $cgi->endform;
    print qq (</div>);

    print $cgi->end_html;

    return;
}

sub thumbTable {
    my ($self, $cgi, $date) = @_;

    my $weekStart = $self->prefs->StartWeekOn || 7;

    # Day of week initials
    my @tds = map {$cgi->font ({-color => $self->{colors}->{dowFG},
                                -face  => $self->{fonts}->{name}->[0],
                                -size  => $self->{fonts}->{name}->[1]},
                               $_)}
                   qw (S M T W T F S);
    if ($weekStart != 7) {
        foreach (1..$weekStart) {
            push @tds, (shift @tds);
        }
    }
    my @trs = $cgi->Tr ({-align => 'center'},
                        $cgi->td ({-bgcolor => $self->{colors}->{dowBG}},
                                  [@tds]));

    # For first week of month, find what day of the week the 1st is, spit
    # out some blank cells
    my $theDate       = $date->firstOfMonth;
    my $weekStartDate = $theDate->firstOfWeek ($weekStart);
    my $delta         = $weekStartDate->deltaDays ($theDate);
    @tds = ();
    my $tailBG = {-bgcolor => $self->{colors}->{tailBG}};
    my $tailFG = {  -color => $self->{colors}->{tailFG},
                    -size  => -1};
    for (my $i=0; $i<$delta; $i++) {
        if ($i == 0) {
            my $lastMonth = Date->new ($date)->addMonths (-1);
            my $lastURL = $self->makeURL ({Date => $lastMonth,
                                           Op   => $self->opName});
            push @tds, $cgi->td ($tailBG,
                                 $cgi->a ({-href   => $lastURL,
                                           -target => '_top'},
                                         $cgi->font ($tailFG, '&lt;')));
        } else {
            push @tds, $cgi->td ($tailBG, $cgi->font ($tailFG, '&nbsp;'));
        }
    }

    my $today = Date->new;

    my $jsSetDate = "Javascript:setDatePopup ('$self->{_popupName}', ";

    for (my $i=$delta; $i<7; $i++) {
        my $fgcolor = $self->{colors}->{dayFG};
        my $bgcolor = $self->{colors}->{dayBG};
        if ($theDate == $today) {
            $fgcolor = $self->{colors}->{todayFG};
            $bgcolor = $self->{colors}->{todayBG};
        }
        push @tds, $cgi->td ({-bgcolor => $bgcolor},
                             $cgi->a ({-href => $jsSetDate .
                                                join (',', $theDate->ymd) .
                                                ');window.close()'},
                                      $cgi->font ({-color => $fgcolor,
                                                   -face  =>
                                                   $self->{fonts}->{day}->[0],
                                                   -size  =>
                                                   $self->{fonts}->{day}->[1]},
                                                  $theDate->day)));
#                                                   '&nbsp;' . $theDate->day .
#                                                   '&nbsp;')));
        $theDate++;
    }
    push @trs, $cgi->Tr ({-align => 'center'}, @tds);

    # And remaining weeks
    my $daysInMonth = $theDate->daysInMonth;
    @tds = ();
    my $day = $theDate->day;
    while ($day++ <= $daysInMonth) {
        if ($theDate->dayOfWeek == $weekStart) {
            push @trs, $cgi->Tr ({-align => 'center'}, @tds) if @tds;
            @tds = ();
        }

        my $fgcolor = $self->{colors}->{dayFG};
        my $bgcolor = $self->{colors}->{dayBG};
        if ($theDate == $today) {
            $fgcolor = $self->{colors}->{todayFG};
            $bgcolor = $self->{colors}->{todayBG};
        }

        push @tds, $cgi->td ({-bgcolor => $bgcolor},
                             $cgi->a ({-href   => $jsSetDate .
                                                  join (',', $theDate->ymd) .
                                                  ');window.close()'},
                                      $cgi->font ({-color => $fgcolor,
                                                   -face  =>
                                                   $self->{fonts}->{day}->[0],
                                                   -size  =>
                                                   $self->{fonts}->{day}->[1]},
                                                  $theDate->day)));
        $theDate++;
    }

    # And maybe last week
    for (my $i=@tds; $i<7; $i++) {
        if ($i == 6) {
            my $nextMonth = Date->new ($date)->addMonths (1);
            my $nextURL = $self->makeURL ({Date => $nextMonth,
                                           Op   => $self->opName});
            push @tds, $cgi->td ($tailBG,
                                 $cgi->a ({-href   => $nextURL,
                                           -target => '_top'},
                                          $cgi->font ($tailFG, '&gt;')));
        } else {
            push @tds, $cgi->td ($tailBG, $cgi->font ($tailFG, '&nbsp;'));
        }
    }
    push @trs, $cgi->Tr ({-align => 'center'}, @tds) if @tds;

    my $html=<<END_SCRIPT;
<script language="Javascript">
<!--
    function setDatePopup (name, year, month, day) {
        var numForms = window.opener.document.forms.length;
        for (var i=0; i<numForms; i++) {
            var form = window.opener.document.forms[i];
            if (form.elements[name + 'YearPopup']) {

                var miss = true;
                opts = form.elements[name + 'YearPopup'].options;
                for (var j=0; j<opts.length; j++) {
                    if (opts[j].value == year) {
                        form.elements[name + 'YearPopup'].selectedIndex = j;
                        miss = false;
                        break;
                    }
                }
                if (miss) {
                  var ny = new Option (year, year, true, true);
                  form.elements[name + 'YearPopup'].options[opts.length] = ny;
                }

                opts = form.elements[name + 'MonthPopup'].options;
                for (var j=0; j<opts.length; j++) {
                    if (opts[j].value == month) {
                        form.elements[name + 'MonthPopup'].selectedIndex = j;
                        break;
                    }
                }

                opts = form.elements[name + 'DayPopup'].options;
                for (var j=0; j<opts.length; j++) {
                    if (opts[j].value == day) {
                        form.elements[name + 'DayPopup'].selectedIndex = j;
                        break;
                    }
                }

                break;
            }
        }
    }
 -->
</script>
END_SCRIPT

    $html .= $cgi->table ({-border      => 0,
                           -align       => 'center',
                           -cellpadding => 2,
                           -cellspacing => 1,
                           -bgcolor     => '#336699'},
                          @trs);

    return $html;
}

sub monthHeader {
    my ($self, $cgi, $date) = @_;

    my $onChangeJS = "document.forms[0].submit()";

    my $html = $cgi->start_form;
    my %monthNames = (1  => 'January',
                      2  => 'February',
                      3  => 'March',
                      4  => 'April',
                      5  => 'May',
                      6  => 'June',
                      7  => 'July',
                      8  => 'August',
                      9  => 'September',
                      10 => 'October',
                      11 => 'November',
                      12 => 'December');
    $html .= '<center>';
    $html .= $cgi->popup_menu (-name   => 'TheMonth',
                               -values => [1..12],
                               -default => $date->month,
                               -onchange => $onChangeJS,
                               -labels => \%monthNames);
    my $thisYear = $date->year;
    $html .= $cgi->popup_menu (-name    => 'TheYear',
                               -values  => [map {$thisYear + $_} -2..2],
                               -onchange => $onChangeJS,
                               -default => $thisYear);
    $html .= $cgi->hidden (-name  => 'Op', -value => $self->opName);
    $html .= $cgi->hidden (-name  => 'CalendarName',
                           -value => $self->calendarName);
    $html .= $cgi->hidden (-name  => 'Name', -value => $self->{_popupName});
    $html .= $cgi->end_form;

    $html .= '</center>';
    return $html;
}

# Just call Operation::makeURL, but always add the Name param
sub makeURL {
    my ($self, $params) = @_;
    $params->{Name} = $self->{_popupName};
    $self->SUPER::makeURL ($params);
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css;
    $css = $self->SUPER::cssDefaults;
    $css .= $self->cssString ('A:link', {'text-decoration' => 'none'});
    return $css;
}

# just use default auditing
#sub auditString {
#}

1;
