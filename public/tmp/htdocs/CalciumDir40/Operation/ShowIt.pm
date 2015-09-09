# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# This ends up displaying a Calendar; Month, Week, or Year view. Block or List.

package ShowIt;
use strict;
use CGI;
use Calendar::BottomBars;
use Calendar::Date;
use Calendar::Footer;
use Calendar::Header;
use Calendar::Name;
use Calendar::NavigationBar;
use Calendar::QuickFilterBar;
use Calendar::Title;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    unless ($self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'Splash'}));
        return;
    }

    my ($date) = $self->getParams ('Date');

    $date = Date->new ($date);
    if (!$date->valid) {
        GetHTML->errorPage ($self->I18N,
                            message => $self->I18N->get ('Invalid Date') .
                            ": $date");
        return;
    }

    my $preferences = $self->prefs;

    my ($amount, $navType, $type) = $self->ParseDisplaySpecs ($preferences);

    # save stuff in case we're auditing
    $self->{audit_date} = $date;
    $self->{audit_mode} = "$amount $type";

    if ($type =~ /planner/i) {
        if ($preferences->getIncludedCalendarNames) {
            $amount = 'week' unless $amount =~ /week|day/i;
            $self->{params}->{Amount} = $amount;
        } else {                # no planner view if no included calendars
            $type = $preferences->BlockOrList || 'Block';
            $self->{params}->{Type} = $type; # need for bottombars
        }
    } elsif ($type =~ /timeplan/i) {
        if ($amount !~ /month|week|day/i) {
            $self->{params}->{Amount} = 'Week';    # hack
            $amount = 'week';
        }
    }

    my ($fiscalType, $fiscalEpoch);
    if ($amount =~ /fperiod|fyear|fquarter/i) {
        $fiscalType = $preferences->FiscalType || '';
        if ($fiscalType eq 'floating') {
            $fiscalType = 'Date::Fiscal::Floating';
        } else {
            $fiscalType = 'Date::Fiscal::Fixed';
        }
        eval "require Calendar::$fiscalType";
        die "Couldn't find Calendar::$fiscalType" if $@;
        $fiscalEpoch = $preferences->FiscalEpoch || '2002/01/01';
    }

    my ($startDate, $endDate) = $self->getParams (qw /StartDate EndDate/);

    if ($startDate and $endDate) {
        $startDate = Date->new ($startDate);
        $endDate   = Date->new ($endDate);
    }
    elsif ($amount =~ /month/i) {
        # If not in relative mode, always put first of month at top.
        # (Also do this if 'Today' was selected.)
        my $today = Date->new();
        $startDate = Date->new($date);
        if ($navType =~ /absolute|neither/i) { # or "$date" eq "$today") {
            $startDate = $startDate->firstOfMonth;
        }
        $endDate = Date->new ($startDate);
        ($endDate->addMonths(1))->addDays(-1);
        # If today is displayed, set it for bottombar links
        if ($today->inRange ($startDate, $endDate)) {
            $date = $today;
        }
    }
    elsif ($amount =~ /fperiod/i) {
        my $fdate = $fiscalType->new ($date);
        $fdate->epoch ($fiscalEpoch);
        $startDate = $fdate->startOfPeriod;
        $endDate   = $fdate->endOfPeriod;

        $startDate->epoch ($fiscalEpoch);
        $endDate->epoch ($fiscalEpoch);
    }
    elsif ($amount =~ /week/i) {
        my $startWeekOn = $preferences->StartWeekOn || 7;   # 7,1-6
        $startDate = $date->firstOfWeek ($startWeekOn);
        $endDate   = Date->new ($startDate) + 6;
    }
    elsif ($amount =~ /day/i) {
        $startDate = Date->new ($date);
        $endDate   = Date->new ($date);
    }
    elsif ($amount =~ /fyear|fquarter/i) {
        $startDate = $fiscalType->new ($date);
        $startDate->epoch ($fiscalEpoch);
        if ($amount =~ /fyear/i) {
            $startDate = $startDate->startOfYear;
            $endDate   = $startDate->endOfYear;
        } else {
            $startDate = $startDate->startOfQuarter;
            $endDate   = $startDate->endOfQuarter;
        }
    }
    elsif ($amount =~ /quarter/i) {
        $startDate = $date->startOfQuarter;
        $endDate   = $date->endOfQuarter;
    }
    elsif ($amount =~ /year/i) {
        $startDate = Date->new ($date->year, 1, 1);
        $endDate   = Date->new ($date->year, 12, 31);
    } else {
        die ("Oops! Bad 'Amount' param to showIt.pl\n");
    }

    my $printObj;
    if ($self->getParams ('PrintView')) {
        my ($colors, $title, $header, $footer, $dateHeader, $background) =
            $self->getParams (qw /PrintColors PrintTitle PrintHeader
                                  PrintFooter PrintDateHeader
                                  PrintBackground/);
        require Calendar::PrintOptions;
        my %printParams = (colors     => ($colors || 'none'),
                           title      => $title,
                           header     => $header,
                           footer     => $footer,
                           dateHeader => $dateHeader,
                           background => $background);
        $printObj = PrintOptions->new (%printParams);
        $preferences->PrintPrefs ($printObj);
    }

    # Don't bother parsing both Block and List View.pm files
    my $theView;
    if ($type =~ /block/i) {
        require Calendar::BlockView;
        $theView = BlockView->new ($self, $startDate->new ($startDate),
                                          $endDate->new ($endDate));
    } elsif ($type =~ /planner/i) {
        if ($amount =~ /day/i) {
            require Calendar::DayPlanner;
            $theView = DayPlanner->new ($self, Date->new ($startDate),
                                               Date->new ($endDate));
        } else {
            require Calendar::MultiView;
            $theView = MultiView->new ($self, Date->new ($startDate),
                                              Date->new ($endDate));
        }
    } elsif ($type =~ /timeplan/i) {
            require Calendar::TimePlanView;
            $theView = TimePlanView->new ($self, Date->new ($startDate),
                                                 Date->new ($endDate));
    } else {
        require Calendar::ListView;
        $theView = ListView->new ($self, $startDate, $endDate);
    }

    my $winTitle = $preferences->Description;

    if ($preferences->PrintPrefs) {
        $winTitle = $self->I18N->get ('Printable View') .
                    ': ' . $self->calendarName;
    }

    # If we did before, re-set cookie for display params
    # (only needed if separate popup window needs it.)
    my $cgi = new CGI;
    my $cookie = $cgi->cookie ('CalciumDisplayParams') ?
                                          $self->displayParamCookie : undef;

    my ($navTop, $navBottom, $title, $footer, $subFooter,
        $barsTop, $barsBottom);
    # Build the page
    if (!$printObj) {
        $navTop    = NavigationBar->new  ($self, $startDate, 'top');
        $navBottom = NavigationBar->new  ($self, $startDate, 'bottom');
        $title     = Title->new ($self, $amount, $type, $startDate, $endDate);
        $footer    = Footer->new ($preferences);
        $subFooter = SubFooter->new ($preferences);
        my $barSite = $preferences->BottomBarSite || 'bottom';
        $barsTop    = ($barSite =~ /top|both/i) ?
                          BottomBars->new ($self, $date, 'Top') : undef;
        $barsBottom = ($barSite =~ /bottom|both/i) ?
                          BottomBars->new ($self, $date, 'Bottom') : undef;
    } else {
        $title = Title->new ($self, $amount, $type, $startDate, $endDate)
            if ($printObj->dateHeader);
        if ($printObj->footer) {
            $footer    = Footer->new ($preferences);
            $subFooter = SubFooter->new ($preferences);
        }
    }

    $self->{_theView} = $theView;

    my @items = (QuickFilterBar->new ($self),
                 Name->new ($preferences, $printObj),
                 $navTop,
                 $barsTop,
                 $title,
                 $theView,
                 $footer,
                 $navBottom,
                 $barsBottom,
                 $subFooter);

    # Get each piece's CSS
    $self->{_childrenCSS} = '';
    foreach (@items) {
        next unless defined;
        $self->{_childrenCSS} .= $_->cssDefaults ($preferences)
            if $_->can ('cssDefaults');
    }

    # Add RSS alt link header, unless we don't want it
    # E.g. <link rel="alternate" type="application/rss+xml" title="My Cal"
    #        href="http://domain.com/MyCal?Op=RSS">
    my (@rss_links, $rss_default_link);
    if (!$preferences->RSS_Disable) {
        my $default_format = $preferences->RSS_Formats || 'rss';
        my %rss_types = (atom  => 'application/atom+xml',
                         rss   => 'application/rss+xml',
                         rdf   => 'application/rdf+xml');
        foreach my $format (qw /atom rss rdf 2.0/) {
            my $the_url = $self->makeURL ({Op      => 'RSS',
                                           Format  => $format,
                                           FullURL => 1});
            my $the_link =
              sprintf ('<link rel="alternate" type="%s" '
                       . 'title="%s" href="%s" />',
                       $rss_types{$format} || 'application/rss+xml',
                       (($winTitle || $self->calendarName) . "($format)"),
                       $the_url);
            push @rss_links, $the_link;
            if ($format eq $default_format or !$rss_default_link) {
                $rss_default_link = $the_url;
            }
        }
    }

    # Do Header *after* getting each ones CSS
    my @page = (Header->new (op     => $self,
                             title  => $winTitle,
                             head_elements => \@rss_links,
                             cookie        => $cookie),
                @items);

    # And print it all out
    foreach (@page) {
        next unless defined;
        my $html = ($_->getHTML || '');
        # Expand $ vars in Title/Header/Footers
        if ($_->isa ('Name') or $_->isa ('FooterSection')) {
            $html = $self->expand_vars ($html);
        }
        print "$html \n";
    }

    # Add RSS link at bottom
    if (!$preferences->RSS_Disable
        and my $path = $preferences->RSS_IconPath) {
        my $display_this = $path;
        # If it starts with 'http' or a slash, we call it an image URL
        if ($path =~ m{^(http)?/}) {
            $display_this = qq {<img border="0" src="$path">};
        }
        my $a_link = qq {<a href="$rss_default_link">$display_this</a>};
        print qq {<span id="RSSLink" style="float: right;">$a_link</span>};
    }

    print $cgi->end_html
        unless (($ENV{SERVER_PROTOCOL} || '') eq 'INCLUDED');
}

sub expand_vars {
    my ($self, $string) = @_;
    return unless defined $string;
    my $date = $self->{audit_date};
    $string =~ s/ \$date    / $date->pretty ($self->I18N) /xeg;
    $string =~ s/ \$calname / $self->calendarName         /xeg;
    $string =~ s/ \$user    / $self->getUsername || ''    /xeg;
    $string =~ s/ \$year    / $date->year                 /xeg;
    $string =~ s/ \$month   / $date->month                /xeg;
    $string =~ s/ \$day     / $date->day                  /xeg;
    if ($string =~ /\$categoryChooser(_(\d+))?/) {
        my $suffix = $2;
        require Calendar::CategoryChooser;
        my $chooser = CategoryChooser->new (prefs       => $self->prefs,
                                            num_columns => $suffix);
        my $html = $chooser->getHTML;
        $string =~ s/ \$categoryChooser(_\d+)? / $html /xg;
    }
    return $string;
}

sub cssDefaults {
    my $self = shift;
    my $prefs = $self->prefs;

    my $css = $self->SUPER::cssDefaults;

    my $bgImage = $prefs->BackgroundImage;
    $bgImage = "url($bgImage)" if $bgImage;

    $css .= Operation->cssString ('BODY',
                      {'background-color' => $prefs->color ('MainPageBG'),
                       color              => $prefs->color ('MainPageFG'),
                       'background-image' => $bgImage});
    $css .= Operation->cssString ('.Footer',
                              {bg           => $prefs->color ('FooterBG'),
                               color        => $prefs->color ('FooterFG'),
                               'text-align' => $prefs->FooterAlignment});
    $css .= Operation->cssString ('.SubFooter',
                              {bg           => $prefs->color ('SubFooterBG'),
                               color        => $prefs->color ('SubFooterFG'),
                               'text-align' => $prefs->SubFooterAlignment});
    $css .= Operation->cssString ('.Header',
                              {bg           => $prefs->color ('HeaderBG'),
                               color        => $prefs->color ('HeaderFG'),
                               'text-align' => $prefs->HeaderAlignment});
    my ($face, $size) = $prefs->font ('BlockDayOfWeek');
    $css .= Operation->cssString ('.WeekHeader, .Year .MonthHeader',
                              {bg    => $prefs->color ('WeekHeaderBG',
                                                       'someColors')});
    $css .= Operation->cssString ('.WeekHeader span, .Year .MonthHeader span',
                              {bg    => $prefs->color ('WeekHeaderBG',
                                                       'someColors'),
                               color => $prefs->color ('WeekHeaderFG',
                                                       'someColors'),
                               'font-family' => $face,
                               'font-size'   => $size});

    $css .= Operation->cssString ('.DayHeader',
                                  {bg => $prefs->color ('DayHeaderBG',
                                                        'someColors')});
    $css .= Operation->cssString ('.DayHeader span, .DayHeader span A, ' .
                                  '.DayHeader span A:visited, ' .
                                  '.DayHeader A:visited',
                                  {fg => $prefs->color ('DayHeaderFG',
                                                        'someColors')});
    ($face, $size) = $prefs->font ('BlockDayDate');
    $css .= Operation->cssString ('.DayHeader span',
                                  {'font-family' => $face,
                                   'font-size'   => $size});
    $css .= Operation->cssString ('.TodayHeader',
                              {bg => $prefs->color ('TodayBG', 'someColors')});
    $css .= Operation->cssString ('.TodayHeader span, .TodayHeader span A, ' .
                                  '.TodayHeader span A:visited, ' .
                                  '.TodayHeader A:visited',
                              {fg => $prefs->color ('TodayFG', 'someColors')});
    $css .= Operation->cssString ('.TodayHeader span',
                                  {'font-family' => $face,
                                   'font-size'   => $size});
    $css .= Operation->cssString ('.MonthAbbrev',
                                  {bg => $prefs->color ('WeekHeaderBG',
                                                        'someColors')});
    ($face, $size) = $prefs->font ('BlockInclude');
    $css .= Operation->cssString ('.BlockView .IncludeTag',
                                  {'font-family' => $face,
                                   'font-size'   => $size});
    ($face, $size) = $prefs->font ('BlockCategory');
    $css .= Operation->cssString ('.BlockView .EventTag.Category',
                                  {'font-family' => $face,
                                   'font-size'   => $size});
    ($face, $size) = $prefs->font ('BlockEventTime');
    $css .= Operation->cssString ('.BlockView .TimeLabel',
                                  {'font-family' => $face,
                                   'font-size'   => $size});

    ($face, $size) = $prefs->font ('BlockDayOfWeek');
    $css .= Operation->cssString ('.MonthAbbrev span',
                           {fg => $prefs->color ('WeekHeaderFG', 'someColors'),
                            'font-family' => $face,
                            'font-size'   => $size});

    my $vlink   = $prefs->color ('VLinkFG');
    my $link    = $prefs->color ('LinkFG');
    $css .= "A:visited {color: $vlink}\n" if (defined $vlink);
    $css .= "A:link    {color: $link}\n"  if (defined $link);

    # Event Faces
    ($face, $size) = $prefs->font ('BlockEvent');
    $css .= $self->cssString ('.BlockView .CalEvent', {'font-size'  => $size,
                                                       'font-family'=> $face});
    ($face, $size) = $prefs->font ('ListEvent');
    $css .= $self->cssString ('.ListView .CalEvent', {'font-size'   => $size,
                                                      'font-family' => $face});

    # Event Tags
    $css .= $self->cssString ('.EventTag', {'font-size' => 'smaller'});
    $css .= $self->cssString ('.EventTag.Tentative', {'font-style' => 'italic',
                                                      color => 'darkred'});

    # Cursor for editing events...assuming we can edit
    $css .= $self->cssString ('.CalEvent', {cursor => 'crosshair'})
        if ($self->userPermitted ('Edit'));

    # Cursor for double-click adding events...assuming we can add (BlockView)
    $css .= $self->cssString ('.DayHeader, .TodayHeader',
                              {cursor => 'crosshair'})
        if ($self->userPermitted ('Add'));

    $css .= $self->{_childrenCSS} if $self->{_childrenCSS};

    if ($prefs->PrintPrefs) {
        $css .= qq {
                     A:link    {text-decoration: none}
                     A:visited {text-decoration: none}
                     A:active  {text-decoration: none}
                   };
    }
    return $css;
}

sub auditString {
    my ($self, $short) = @_;
    my $line =  $self->SUPER::auditString ($short);
    if ($self->{audit_date}) {
        $line .= ' ' . $self->{audit_date} . ' ' . $self->{audit_mode};
    }
    return $line;
}

1;
