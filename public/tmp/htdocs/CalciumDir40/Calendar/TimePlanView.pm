# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# Display one or more days worth of events, with vertical time blocks

package TimePlanView;
use strict;

use CGI;
use Calendar::Date;
use Calendar::DisplayFilter;
use Calendar::TimeBlock;

sub new {
    my $class = shift;
    my ($op, $startDate, $endDate) = @_;
    my $self = {};
    bless $self, $class;

    my $db    = $op->db;
    my $i18n  = $op->I18N;
    my $prefs = $op->prefs;
    my $calName = $op->calendarName;
    my $cgi   = CGI->new;

    my $addPerm     = $op->permission->permitted ($op->getUsername, 'Add');
    my $showWeekend = $prefs->ShowWeekend || ($startDate == $endDate);

    # Column for each day
    my (@dates, %dayNames, %events);
    for (my $date = Date->new ($startDate); $date <= $endDate; $date++){

        next if (!$showWeekend and $date->isWeekend);

        push @dates, $date;

        my $text = $date->day;

        if ($addPerm and !$prefs->PrintPrefs) {
            my $url = $op->makeURL ({Op   => 'ShowDay',
                                     Date => $date});
            $text = "<a href='$url'>$text</a>";
        }

        my $dayName = $i18n->get ($date->dayName ('abbrev'));
        my $url = $op->makeURL ({Op     => $op->opName,
                                 Date   => $date,
                                 Amount => 'Day'});
        $dayName = "<a href='$url'>$dayName</a>";

        my $weekNum = '';
        if ($prefs->ShowWeekNums and
            ($date->dayOfWeek == $prefs->StartWeekOn)) {
            $weekNum = $date->weekNumber ($prefs->WhichWeekNums,
                                          $prefs->StartWeekOn);
            $weekNum = "<small><small>[$weekNum]</small></small>";
            my $url = $op->makeURL ({Op     => $op->opName,
                                     Date   => $date,
                                     Amount => 'Week'});
            $weekNum = "<a href='$url'>$weekNum</a>";
        }

        $dayNames{$date} = "<nobr>$dayName $text $weekNum</nobr>";

        # Get events for this day
        $events{"$date"} = $self->_eventsForToday ($date, $op, $prefs);
    }

    my $tblock = TimeBlock->new (op      => $op,
                                 dates   => \@dates,
                                 headers => \%dayNames,
                                 events  => \%events
                                );

    $self->{html}  = Javascript->PopupWindow ($op);
    $self->{html} .= Javascript->EditEvent ($op);
    $self->{html} .= $tblock->render;
    $self->{html} .= '<br>' . $tblock->hourControls (ShowIncrement => 1);
    $self;
}

sub _eventsForToday {
    my ($self, $date, $op) = @_;
    my @events = $op->db->getApplicableEvents ($date, $op->prefs, 'yesterday');

    # Filter out tentative/private events, setting privacy display flag too
    $self->{_display_filter} ||= DisplayFilter->new (operation => $op);
    @events = $self->{_display_filter}->filterTentative (\@events);
    @events = $self->{_display_filter}->filterPrivate (\@events);
    @events = $self->{_display_filter}->filter_from_params (\@events);

    # Make copy of any repeating events, since we need to keep
    # track of instance date for each one (for possible timezone
    # shifts.)
    @events = map {$_->isRepeating? $_->copy : $_} @events; # shallow copy

    return \@events;
}

sub cssDefaults {
    my ($self, $prefs) = @_;

    my $blankColBG  = $prefs->color ('MainPageBG');
    my ($face, $size) = $prefs->font ('BlockDayDate');

    # These are actually named in TimeBlock.pm
    my $css;
    $css .= Operation->cssString ('.DayHeader',
                 {'background-color' => $prefs->color ('DayHeaderBG'),
                  'font-family'      => $face,
                  'font-size'        => $size});
    $css .= Operation->cssString ('.DayHeader A',,
                 {color              => $prefs->color ('DayHeaderFG')});

    $css .= Operation->cssString ('.TodayHeader',
                 {'background-color' => $prefs->color ('TodayBG'),
                  'font-family'      => $face,
                  'font-size'        => $size});
    $css .= Operation->cssString ('.TodayHeader A',,
                 {color              => $prefs->color ('TodayFG')});

    my (@dayHeader, @todayHeader, @blankColumn);


    $css .= Operation->cssString ('.BlankColumn',
                                  {bg => $prefs->color ('MainPageBG')});

    $css .= Operation->cssString ('.UntimedEventRow',
                  {bg    => $prefs->color ('MonthTailBG'),
                   color => $prefs->color ('MonthTailFG')});

    $css .= Operation->cssString ('.HourColumn, .MinuteColumn',
                  {bg    => $prefs->color ('WeekHeaderBG'),
                   color => $prefs->color ('WeekHeaderFG')});

    $css .= Operation->cssString ('.MinuteColumn', {'font-size' => 'smaller',
                                                    'font-style'=> 'oblique'});

    ($face, $size) = $prefs->font ('DayViewControls');
    $css .= Operation->cssString ('.DayViewControls',
                              {bg    => $prefs->color ('DayViewControlsBG'),
                               color => $prefs->color ('DayViewControlsFG'),
                               'font-family' => $face,
                               'font-size'   => $size});
    $css .= Operation->cssString ('.DayViewControls A:link',
                  {color              => $prefs->color ('DayViewControlsFG')});
    $css .= Operation->cssString ('.DayViewControls A:visited',
                  {color              => $prefs->color ('DayViewControlsFG')});
    $css.= Operation->cssString ('.DayViewControls select',
                             {bg => $prefs->color ('DayViewControlsBG')});
    $css.= Operation->cssString ('.EventCells',
                             {bg => $prefs->color ('EventBG')});

    my %font_to_css_map = (BlockEvent     => '.CalEvent',
                           BlockInclude   => '.IncludeTag',
                           BlockCategory  => '.EventTag.Category',
                           BlockEventTime => '.TimeLabel');
    while (my ($font_name, $css_specifier) = each %font_to_css_map) {
        ($face, $size) = $prefs->font ($font_name);
        $css .= Operation->cssString ('.TimePlanView ' . $css_specifier,
                                      {'font-size'  => $size,
                                       'font-family'=> $face});
    }

    return $css;
}

sub getHTML {
  my $self = shift;
  return qq (<div class="TimePlanView">$self->{html}</div>);
}

1;
