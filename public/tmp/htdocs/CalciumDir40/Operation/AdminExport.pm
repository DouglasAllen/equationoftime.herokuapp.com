# Copyright 2000-2006, Fred Steinberg, Brown Bear Software

# Export Event data
package AdminExport;
use strict;
use CGI (':standard');

use Calendar::Date;
use Calendar::GetHTML;
use Calendar::DisplayFilter;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($save, $cancel, $isPopup, $userPage)
           = $self->getParams (qw (Save Cancel IsPopup FromUserPage));

    my $cgi = new CGI;

    my $calName = $self->calendarName;

    if ($cancel) {
        my $op = $calName ? ($isPopup || $userPage ? 'AdminPageUser'
                                                   : 'AdminPage')
                          : 'SysAdminPage';
        print $self->redir ($self->makeURL({Op => $op}));
        return;
    }

    my $prefs = $self->prefs;
    my $i18n  = $self->I18N;

    my @exportedLines;
    my @vEvents;
    my ($format, $separator, $cookie);

    if ($save) {
        my ($fromYear, $fromMonth, $fromDay) =
                                        @{$self->{params}}{qw (FromYearPopup
                                                               FromMonthPopup
                                                               FromDayPopup)};
        my ($toYear, $toMonth, $toDay) =
                                        @{$self->{params}}{qw (ToYearPopup
                                                               ToMonthPopup
                                                               ToDayPopup)};
        $separator = @{$self->{params}}{'Separator'};
        $format    = @{$self->{params}}{'Format'};

        my @categories = $cgi->param ('Categories');

        my $errorMessage;
        if (!Date->valid ($fromYear, $fromMonth, $fromDay)) {
            $errorMessage = $i18n->get ('<br>Invalid <b>From</b> Date');
        }
        if (!Date->valid ($toYear, $toMonth, $toDay)) {
            $errorMessage = $i18n->get ('<br>Invalid <b>To</b> Date');
        }
        if ($errorMessage) {
            GetHTML->errorPage ($i18n,
                               header => $i18n->get ('Error exporting events'),
                               message => $errorMessage);
            return;
        }
        my $fromDate = Date->new ($fromYear, $fromMonth, $fromDay);
        my $toDate   = Date->new ($toYear, $toMonth, $toDay);

        if ($format =~ /^[iv]cal/) {
            my ($regs, $repeats) = $self->db->getEventLists ($prefs, $fromDate,
                                                             $toDate);
            require Calendar::EventvEvent;
            require Calendar::vCalendar::vCalendar;

            my $filter = DisplayFilter->new (operation => $self);

            foreach my $date (_dateSort ([keys %$regs])) {
                my $dateObj = Date->new ($date);
#                foreach my $event (@{$regs->{$date}}) {
#                     my $includedFrom = $event->includedFrom;
#                     next if ($includedFrom and $includedFrom =~ /^ADDIN /);
#                    my $vEvent = $event->vEvent ($dateObj);
#                    push @vEvents, $vEvent;
#                }
                my @events;
                if (@categories) {
                    foreach (@{$regs->{$date}}) {
                        next unless $_->inCategory (\@categories);
                        push @events, $_;
                    }
                } else {
                    @events = @{$regs->{$date}};
                }

                @events = $filter->filterTentative (\@events);
                @events = $filter->filterPrivate (\@events);
                foreach my $event (@events) {
                    _sanitize_private ($event, $i18n); # maybe omit details
                }

                push @vEvents, map {$_->vEvent ($dateObj)} @events;
            }
#            foreach my $event (@$repeats) {
#                my $includedFrom = $event->includedFrom;
#                next if ($includedFrom and $includedFrom =~ /^ADDIN /);
#                my $vEvent = $event->vEvent;
#                push @vEvents, $vEvent;
#            }
            my @events;
            if (@categories) {
                foreach (@$repeats) {
                    next unless $_->inCategory (\@categories);
                    push @events, $_;
                }
            } else {
                @events = @$repeats;
            }

            # Remove tentative ones, stuff we shouldn't see
            @events = $filter->filterTentative (\@events);
            @events = $filter->filterPrivate (\@events);
            foreach my $event (@events) {
                _sanitize_private ($event, $i18n); # maybe omit details
            }

            push @vEvents, map {$_->vEvent} @events;
        } else {
            my $evHash = $self->db->getEventDateHash ($fromDate, $toDate,
                                                      $prefs);
            my $lines = $self->_getExportedLines ($evHash, $format, $separator,
                                                  \@categories, $prefs);
            @exportedLines = @$lines;
        }

        # Write cookie with prefs
        $cookie = $cgi->cookie (-name    => 'CalciumExportPrefs',
                                -value   => "$separator-$format",
                                -expires => '+1y');

        $self->{audit_formsaved}++;
        $self->{audit_fromdate}   = $fromDate;
        $self->{audit_todate}     = $toDate;
        $self->{audit_eventcount} = @exportedLines;
    }

    # Get cookie vals for prefs
    my $prefCookie = $cgi->cookie ('CalciumExportPrefs') || '';
    my ($sepDefault, $formatDefault) = split '-', $prefCookie;

    if (@vEvents) {
        use Time::Local;
        my $now = time;
        my $utc   = timegm (gmtime ($now));
        my $local = timegm (localtime ($now));
#        my $hours = int (($local - $utc) / 3600) - ($prefs->Timezone || 0);
        my $hours = int (($local - $utc) / 3600);
        if ($hours) {
            foreach (@vEvents) {
                $_->convertToUTC ($hours);
            }
        }

        my ($version, $extension) = ('2.0', 'ics');
        if ($format =~ /^vcal/) {
            ($version, $extension) = ('1.0', 'vcs');
        }
        my $vCal = vCalendar->new (events  => \@vEvents,
                                   version => $version);

        my $type     = 'text/calendar';
        my $filename = "CalciumEvents.$extension";
        if ($format =~ /[iv]cal_text/) {
            $type     = 'text/x-Calcium-Events';
            $filename = 'Events.calcium';
        }
        print $cgi->header (-type   => $type,
                            '-Content-disposition' => "filename=$filename",
                            -cookie => $cookie);
        print $vCal->textDump (METHOD => 'PUBLISH');
#        print $vCal->textDump;
        return;
    }
    if (@exportedLines) {
        print $cgi->header (-type   => 'text/x-Calcium-Events',
                           '-Content-disposition' =>
                                      'filename=Events.calcium',
                            -cookie => $cookie);
        if ($format =~ /msoutlook/i) {
            $separator = "\t" if ($separator eq 'TAB');

            my @custom_names;
            if (my $field_order = $prefs->CustomFieldOrder) {
                my @field_order = split ',', $field_order;
                my $fields_lr = $prefs->get_custom_fields (system => 1);
                my %fields_by_id = map {$_->id => $_} @$fields_lr;
                foreach my $field_id (@field_order) {
                    my $field = $fields_by_id{$field_id};
                    next unless $field;
                    push @custom_names, '"' . $field->name . '"';
                }
            }

            print join $separator, ('"Subject"',
                                    '"Start Date"',
                                    '"Start Time"',
                                    '"End Date"',
                                    '"End Time"',
                                    '"All day event"',
                                    '"Description"',
                                    '"Categories"',
                                    @custom_names);
            print "\n";
        }
        print join "\n", @exportedLines;
        return;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Export Event Data'),
                              op     => $self);
    print '<center>';
    print GetHTML->AdminHeader (I18N    => $i18n,
                                cal     => $calName,
                                section => 'Export Event Data');
    print '<br>';

    if ($save and !@exportedLines) {
        print $cgi->p ($cgi->font ({color => 'red'},
                                   $i18n->get ("No events were found in the " .
                                               "specified date range!")));
    }

    print $i18n->get ('Data for Events between the specified dates ' .
                      'will be exported.');
    print '</center>';

    my $script = <<'    END_JAVASCRIPT';
    :    <script language="JavaScript">
    :    <!-- start
    :    // Make sure dates are OK (or cancel pressed)
    :    function submitCheck (theForm, baseYear) {
    :        if (theForm.Cancel.pressed) {
    :            return true;
    :        }
    :        fromMonth = theForm.FromMonthPopup.selectedIndex;
    :        fromDay   = theForm.FromDayPopup.selectedIndex + 1;
    :        fromYear  = theForm.FromYearPopup.selectedIndex + baseYear;
    :        toMonth   = theForm.ToMonthPopup.selectedIndex;
    :        toDay     = theForm.ToDayPopup.selectedIndex + 1;
    :        toYear    = theForm.ToYearPopup.selectedIndex + baseYear;
    :        fromDate = new Date (fromYear, fromMonth, fromDay);
    :        toDate   = new Date (toYear,   toMonth,   toDay);
    :        gotMonth = fromDate.getMonth();
    :        gotDay   = fromDate.getDate();
    :        if (gotMonth != fromMonth || gotDay != fromDay) {
    :            alert ('From Date is invalid.');
    :            return false;
    :        }
    :        gotMonth = toDate.getMonth();
    :        gotDay   = toDate.getDate();
    :        if (gotMonth != toMonth || gotDay != toDay) {
    :            alert ('To Date is invalid.');
    :            return false;
    :        }
    :        if (fromDate.valueOf() > toDate.valueOf()) {
    :            alert ('To Date cannot be before From Date.');
    :            return false;
    :        }
    :        return true;
    :    }
    :    // End -->
    :    </script>
    END_JAVASCRIPT
    $script =~ s/^\s*:\s*//mg;
    print $script;

    my ($yearStart, $yearEnd, $earliestDate);
    $yearStart = Date->new;
    $yearStart->month(1);
    $yearStart->day(1);
    $yearEnd = Date->new ($yearStart)->addYears (1) - 1;
    $earliestDate = Date->new ($yearStart);
    $earliestDate->addYears(-10);

    my $Format_Help = $i18n->get ('AdminExport_FormatHelp');
    if ($Format_Help eq 'AdminExport_FormatHelp') {
        ($Format_Help =<<'        ENDHELP') =~ s/^ +//gm;
        This option specifies how the data will be printed.\n\n
        'iCalendar' format is used by Mozilla, Apple's iCal, and other\n
        calendar systems. 'iCalendar -file' will download as a plain ASCII\n
        file, while 'iCalendar' will download as type text/calendar.\n\n\n
        'vCalendar' is like iCalendar, but is the older version 1.0, mainly
        for Palm Desktop compatibility.\n\n
        'Calcium' or 'MS Outlook' specifies the fields and order.\n\n
        Calcium:\n
          Date Text Link_or_Popup Start_Time End_Time\n
          Border? BG_Color FG_Color Export Owner_Name\n
          Category Included_From_Calendar\n\n
        MS Outlook:\n
          Text Date Start_Time Date End_Time All_Day_Event?\n
          Link_or_Popup\n\n
        'European' prints dates as DD/MM/YYYY (e.g. 31/01/2000),\n
        and times in 24-hour format.\n\n
        'USA' prints dates as MM/DD/YYYY (e.g. 01/31/2000),\n
        and times in 12-hour format, with 'am' or 'pm' in a separate\n
        field.
        ENDHELP
    }
    $Format_Help =~ s/'/\\'/g; #"'

    my $url = $cgi->url (-absolute => 1, -path_info => 1, -query => 1);
#    $url =~ s{\?}{/CalciumEvents?};
    print $cgi->startform (-action   => $url,
                           -onSubmit =>
                                  "return submitCheck(this, $earliestDate)");

    my $fromPopup = GetHTML->datePopup ($i18n,
                                        {name     => 'From',
                                         default  => $yearStart,
                                         start    => $earliestDate,
                                         numYears => 20});
    my $toPopup   = GetHTML->datePopup ($i18n,
                                        {name     => 'To',
#                                         default  => Date->new - 1,
                                         default  => $yearEnd,
                                         start    => $earliestDate,
                                         numYears => 20});
    my ($usa, $euro) = ($i18n->get ('USA'), $i18n->get ('European'));
    print $cgi->table ($cgi->Tr ($cgi->td ($cgi->b ($i18n->get ('From:'))),
                                 $cgi->td ({-colspan => 2}, $fromPopup)),
                       $cgi->Tr ($cgi->td ($cgi->b ($i18n->get ('To:'))),
                                 $cgi->td ({-colspan => 2}, $toPopup)),
                       $cgi->Tr ($cgi->td ($cgi->b
                                           ($i18n->get ('Field Separator:'))),
                                 $cgi->td ($cgi->popup_menu (
                                             -name    => 'Separator',
                                             -default => $sepDefault,
                                             -Values  => [',', ' ', 'TAB',';'],
                                             -labels  => {','  =>
                                                      $i18n->get ('Comma'),
                                                          ' '  =>
                                                      $i18n->get ('Space'),
                                                          'TAB'  =>
                                                      $i18n->get ('Tab'),
                                                          ';'  =>
                                                      $i18n->get ('Semicolon'),
                                                         })),
                                 $cgi->td ($cgi->font ({-size => -1}, '(' .
                                  $i18n->get ('Separators in ' .
                                              'the actual data will be ' .
                                              'preceded by a backslash. ') .
                                  $i18n->get ('Ignored for vCalendar')
                                                 . ')'))),
                       $cgi->Tr ($cgi->td ($cgi->b
                                           ($i18n->get ('Format:'))),
                                 $cgi->td ($cgi->popup_menu (
                                             -name    => 'Format',
                                             -default => $formatDefault,
                                             -Values  => ['usa', 'euro',
                                                          'vcal', 'vcal_text',
                                                          'ical', 'ical_text',
                                                          'msoutlook-usa',
                                                          'msoutlook-euro'],
                                             -labels  =>
                                  {'usa'            => "Calcium - $usa",
                                   'euro'           => "Calcium - $euro",
                                   'vcal'           => "vCalendar",
                                   'vcal_text'      => 'vCalendar  - file',
                                   'ical'           => "iCalendar",
                                   'ical_text'      => 'iCalendar  - file',
                                   'msoutlook-usa'  => "MS Outlook - $usa",
                                   'msoutlook-euro' => "MS Outlook - $euro",
                                  })),
                                 $cgi->td ($cgi->a ({href =>
                                       "JavaScript:alert (\'$Format_Help\')"},
                                      $i18n->get ('What does this mean?')))));

    my $headStyle = 'font-weight:bold';
    print '<hr align="left" width="25%">';
    print qq (<span style="$headStyle">);
    print $i18n->get ('Only export events which are in any of these ' .
                      'categories:');
    print '</span><br><br>';
    print GetHTML->categorySelector (op   => $self,
                                     name => 'Categories');

    print '<br><br><hr>';

    print $cgi->submit (-name  => 'Save',
                        -value => $i18n->get ('Download Events'));
    print '&nbsp;';
    print $cgi->submit (-name    => 'Cancel',
                        -value   => $i18n->get ('Done'),
                        -onClick => 'this.pressed = true');
    print '&nbsp;';
    print $cgi->reset  (-value => $i18n->get ('Reset Dates'));

    print $cgi->hidden (-name => 'Op',          -value => 'AdminExport');
    print $cgi->hidden (-name => 'CalendarName', -value => $calName);
    print hidden (-name => 'FromUserPage', -value => $userPage) if $userPage;
    print $self->hiddenDisplaySpecs;

    print $cgi->endform;

    print '<br>';
    print $cgi->span ({-style => $headStyle}, $i18n->get ('Notes') . ':');
    print '<ul>';
    print '<li>';
        my $string = $i18n->get ('AdminExport_Instructions');
    if ($string eq 'AdminExport_Instructions') {
        print $i18n->get ('Each occurrence of a Repeating Event will be ' .
                          'exported as a separate line of data.');
        print ' ' . $i18n->get ('(Except for vCalendar format.)');
    } else {
        print $string;
    }
    print '</li>';

    my $subscribeURL = $self->makeURL ({Op => 'OptioniCal'});
    print '<li>';
    print $i18n->get ('If you have a desktop application that supports ' .
                      'iCalendar, you can "');
    print $cgi->a ({href => $subscribeURL}, $i18n->get ('Subscribe'));
    print $i18n->get ('" to this calendar');
    print '</li>';

    print '</ul>';

    print $cgi->end_html;
}


sub _getExportedLines {
    my ($self, $evHash, $format, $separator, $categories, $prefs) = @_;
    my @lines;
    my $escapeIt = 1;

    if ($separator eq 'TAB') {
        $separator = "\t";
        undef $escapeIt;
    }

    my $filter = DisplayFilter->new (operation => $self);

    my @custom_field_order;
    if (my $custom_field_order = $prefs->CustomFieldOrder) {
        @custom_field_order = split ',', $custom_field_order;
    }

    my $i18n = $self->I18N;

    foreach my $date (map  {$_->[0]}
                      sort {$AdminExport::a->[1] <=> $AdminExport::b->[1]}
                      map  {[$_, Date->new ($_)->_toInt]} keys %$evHash) {
        my $event_list = $evHash->{$date};

        # Remove tentative ones, stuff we shouldn't see
        my @events = $filter->filterTentative ($event_list);
        @events    = $filter->filterPrivate (\@events);

        my @sorted_list = Event->sort (\@events, $prefs->EventSorting);
        foreach (@sorted_list) {
#        foreach (@{$evHash->{$date}}) {
            my $includedFrom = $_->includedFrom;
            next if ($includedFrom and $includedFrom =~ /^ADDIN /);

            _sanitize_private ($_, $i18n); # maybe omit details

            if ($categories and $categories->[0]) {
                next unless $_->inCategory ($categories);
            }

            my ($y, $m, $d) = split '/', $date;
            $m = "0$m" if $m < 10;
            $d = "0$d" if $d < 10;

            my ($starth, $startm, $endh, $endm);
            if (defined $_->startTime) {
                $starth = int ($_->startTime / 60);
                $startm = $_->startTime % 60;
                $startm = "0$startm" if $startm < 10;
            }
            if (defined $_->endTime) {
                $endh = int ($_->endTime / 60);
                $endm = $_->endTime % 60;
                $endm = "0$endm" if $endm < 10;
            }

            my ($theDate, $startTime, $endTime,
                $start_meridian, $end_meridian);

            my $isUSA = ($format =~ /usa/i);
            if ($isUSA) {
                $theDate = "$m/$d/$y";
                if (defined ($starth)) {
                    $start_meridian = $starth < 12 ? 'am' : 'pm';
                    $starth  = 12 if ($starth == 0);
                    $starth -= 12 if ($starth > 12);
                    $startTime = "$starth:$startm";
                }
                if (defined ($endh)) {
                    $end_meridian = $endh < 12 ? 'am' : 'pm';
                    $endh  = 12 if ($endh == 0);
                    $endh -= 12 if ($endh > 12);
                    $endTime = "$endh:$endm";
                }
            } else {
                if ($separator eq ';') {
                    $theDate = "$d.$m.$y";
                } else {
                    $theDate = "$d/$m/$y";
                }
                $startTime = "$starth:$startm" if defined ($starth);
                $endTime   = "$endh:$endm"     if defined ($endh);
            }

            local $^W = 0;      # don't warn about undefs
            my @fields;
            if ($format =~ /msoutlook/i) {
                my ($start, $end);
                $start = "$startTime:00 \U$start_meridian" if ($startTime);
                $end   = "$endTime:00 \U$end_meridian"     if ($endTime);

                my @cats     = $_->getCategoryList;
                my $category = join ';', @cats;

                my @custom_values;
                if (@custom_field_order
                    and !$_->hide_details and !$_->display_privacy_string) {
                    foreach my $field_id (@custom_field_order) {
                        my $value = $_->customField ($field_id);
                        if (ref $value) {
                            $value = join ',', @$value;
                        }
                        push @custom_values, $value;
                    }
                }

                @fields = ($_->escapedText ($escapeIt),
                           $theDate,
                           $start,
                           $theDate,
                           $end,
                           $start ? 'False' : 'True',
                           $_->link || $_->escapedPopup ($escapeIt),
                           $category,
                           @custom_values
                          );
                map {$_ = "\"$_\"" if defined} @fields;
            } else {
                my (@start, @end);
                push @start, $startTime; # yes, even if undef
                push @start, $start_meridian if $isUSA;
                push @end, $endTime;
                push @end, $end_meridian     if $isUSA;

                my @cats = $_->getCategoryList;
                my $catString = join '^', @cats;

                @fields = ($theDate,
                           $_->escapedText ($escapeIt),
                           $_->link || $_->escapedPopup ($escapeIt),
                           @start, # list because might have am or pm
                           @end,
                           $_->drawBorder ? '1' : '',
                           $_->bgColor,
                           $_->fgColor,
                           $_->export,
                           $_->owner,
                           $catString,
                           $_->includedFrom);
                foreach (@fields) { # escape things that need escaping
#                    s/($separator|['"])/\\$1/go;    # ' ])
                    if ($separator ne "\t") {
                        s/($separator)/\\$1/g;
                        s/(['"])/\\$1/g;         # ' ])
                    } else {
                        s/\t/\\t/g;
                    }
#                        s/<br>/\\\\n/g; # need \\n in the output file
                   s/\n/\\n/g; # just put '\' and 'n' in output file
                    s/<br>/\\n/g; # just put '\' and 'n' in output file
                }
            }
            push @lines, (join $separator, @fields);
        }
    }
    \@lines;
}

# Possibly sanitive private data
sub _sanitize_private {
    my ($event, $i18n) = @_;
    if ($event->display_privacy_string) {
        $event->text ($event->displayString ($i18n));
    }
    if ($event->hide_details) {
        $event->popup (undef);
    }
}


# Return sorted list of dates in hash
sub _dateSort {
    my $dates = shift;
    return map  {$_->[0]}
           sort {$AdminExport::a->[1] <=> $AdminExport::b->[1]}
           map  {[$_, Date->new ($_)->_toInt]}
               @$dates;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    return "$line $self->{audit_fromdate}-$self->{audit_todate} " .
           "$self->{audit_eventcount} events";
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
