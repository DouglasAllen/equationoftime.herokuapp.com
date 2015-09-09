# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package EventEditForm;
use strict;

use CGI (':standard');
use Calendar::GetHTML;
use Calendar::Date;
use Calendar::Javascript;

# Forms with text areas, etc., for editing events.
# Pass:
#    operation
#    ref to param hash, with 'newOrEdit', 'date', etc. keys
#    repeatStuffP - whether or not to display the items for repeating events 
sub eventEdit {
    my $class = shift;
    my ($operation, $paramHashRef) = @_;

    my $prefs   = $operation->prefs;
    my $i18n    = $operation->I18N;
    my $calName = $operation->calendarName;
    my $username = $operation->getUsername;

    # Get tab order straight
    my @tab_order = qw (Date
                        ExportPopup
                        EventText
                        TimePeriod
                        StartTime
                        EndTime
                        Category
                        MoreCategories
                        BackgroundColor
                        ForegroundColor
                        Border
                        PopupText
                        CustomFields
                        WhichCalendars
                        SubmitAfterMain
                    );
    my %tab_index;
    my $the_tab_order = 100;
    foreach my $item (@tab_order) {
        $tab_index{$item} = $the_tab_order;
        $the_tab_order += 100;
    }

    my $event      = $paramHashRef->{event}; # not defined for a *new* event
    my $date       = $paramHashRef->{date};
    my $allOrOne   = $paramHashRef->{allOrOne}   || '';
    my $mainHeader = $paramHashRef->{mainHeader} || '';
    my $newOrEdit  = $paramHashRef->{newOrEdit}  || 'new';
    my $displayCal = $paramHashRef->{displayCal} || $calName;
    my $viewCal    = $paramHashRef->{viewCal}; # for getting back to planner
    my $calendarList = $paramHashRef->{calList}; # for multi-add

    my $eventID   = $event ? $event->id()        : undef;
    my $eventText = $event ? $event->text()
                           : $prefs->DefaultText || '';
    my $popupText = $event ? ($event->link() || $event->popup() || '')
                           : $prefs->DefaultPopup || '';
    my $export    = $event ? $event->export : $prefs->EventPrivacy || 'Public';
    my $timePeriod = $event ? $event->timePeriod
                            : ($prefs->DefaultTimePeriod || undef);

    my $mailTo    = $event ? $event->mailTo   : '';
    my $mailCC    = $event ? $event->mailCC   : '';
    my $mailBCC   = $event ? $event->mailBCC  : '';
    my $mailText  = $event ? $event->mailText : '';
    my $defNotify = $prefs->DefaultSubsNotify;
    my $reminderTo;
    my $reminderTimes = $event ? $event->reminderTimes
                               : $prefs->DefaultRemindTimes;
    my @reminderTimes = sort split /\s/, ($reminderTimes || '');

    if ($event) {
        $reminderTo = $event->reminderTo;
    }
    elsif (my $to = $prefs->DefaultRemindTo) {
        $reminderTo = $to;
    }
    else {
        my $user = User->getUser ($username);
        $reminderTo = $user->email if $user;
    }

    my $drawBorder = $event ? $event->drawBorder() : $prefs->DefaultBorder;
    my ($primaryCat, @moreCats) = $event ? $event->getCategoryList
                                         : ($prefs->DefaultCategory || undef);
    my $bgColor    = ($event && $event->bgColor())  || 'Default';
    my $fgColor    = ($event && $event->fgColor())  || 'Default';

    my $prompts = $prefs->EditFormPrompts || '';
    my %prompts = split ' ;; ', $prompts;

    # Since we can be called for a new event or to edit an existing event,
    # we've got to see if we've already got repeat info
    my $repeatInfo = defined ($event) ? $event->repeatInfo() : undef;

    my ($action, $buttonText, $nextOp, $textPrompt, $mailPrompt,
        $copyButtonText);
    if (lc ($newOrEdit) eq 'new') {
        $action     = 'EventNew';
        $nextOp     = 'ShowDay';
        $buttonText = $i18n->get ('Create Event');
        $textPrompt = $prompts{TextNew} ||
                          $i18n->get ('Enter text for a new event:');
        $mailPrompt = $i18n->get ('Specify email addresses to notify ' .
                                  'that this event has been added.');
    } else {    # editing existing
        $action     = 'EventReplace';
        $nextOp     = 'ShowDay';
        $buttonText = $i18n->get ('Replace Event');
        $textPrompt = $prompts{TextEdit} ||
                          $i18n->get ('Modify the text for this event:');
        $mailPrompt = $i18n->get ('Add or change email addresses to notify ' .
                                  'that this event has been modified.');
        $copyButtonText = $i18n->get ('Copy Event')
            unless ($repeatInfo and $allOrOne !~ /all/i);
    }

    my $frequency  = $repeatInfo ? $repeatInfo->frequency() : '';
    my $period     = $repeatInfo ? $repeatInfo->period()    : '';
    my $startDate  = ($repeatInfo and lc ($allOrOne) ne 'only')
                                 ? $repeatInfo->startDate() : Date->new($date);
    my $endDate      = $repeatInfo ? $repeatInfo->endDate()      : '';
    my $monthWeek    = $repeatInfo ? $repeatInfo->monthWeek()    : '';
    my $monthMonth   = $repeatInfo ? $repeatInfo->monthMonth()   : '';
    my $skipWeekends = $repeatInfo ? $repeatInfo->skipWeekends() : '';

    my ($startHour, $startMinute, $endHour, $endMinute);
    my $displayDate;

    if ($event and defined $event->startTime) {
        # Adjust for timezones
        my $zoffset = $prefs->Timezone || 0;
        if ($zoffset) {
            $startDate = $event->getDisplayDate ($startDate, $zoffset);
            $displayDate = $startDate;
        }
        my ($start, $end) = $event->getDisplayTime ($zoffset);

        $startHour   = int ($start / 60);
        $startMinute = $start % 60;
        if (defined $end) {
            $endHour   = int ($end / 60);
            $endMinute = $end % 60;
        }
    } else {
        if (my $start = $paramHashRef->{defaultStartTime}) {
            $startHour = int ($start / 60);
            $startMinute = $start % 60;
        }
        if (my $end = $paramHashRef->{defaultEndTime}) {
            $endHour = int ($end / 60);
            $endMinute = $end % 60;
        }
    }

    my $defaultRepeat = 'None';
    if ($repeatInfo) {
        if ($period) {
            $period = join (' ', sort @$period) if (ref ($period));
            $defaultRepeat = 'Repeat';
        } else {
            $defaultRepeat = 'ByWeek';
        }
        $monthWeek = join ' ', @$monthWeek if (ref ($monthWeek));
    }

    # Start time, end time stuff
    $startHour = -1 if !defined $startHour;
    $endHour   = -1 if !defined $endHour;
    $startMinute = ($startHour >= 0) ? $startMinute || 0 : -1;
    $endMinute   = ($endHour   >= 0) ? $endMinute   || 0 : -1;

    my $milTime = $prefs->MilitaryTime;
    my $none18 = $i18n->get ('None');
    my ($startTimeHourPopup,
        @startTimeRadio) = $class->_hourPopup ('nameBase'     => 'StartHour',
                                               tabindex       =>
                                                       $tab_index{StartTime},
                                               'default'      => $startHour,
                                               'militaryTime' => $milTime,
                                               'None'         => $none18);
    my ($endTimeHourPopup,
        @endTimeRadio)  = $class->_hourPopup ('nameBase'      => 'EndHour',
                                               tabindex       =>
                                                       $tab_index{EndTime},
                                              'default'      => $endHour,
                                              'militaryTime' => $milTime,
                                              'None'         => $none18);

    # First thing, lets add the Javascript we need
    my $html = $class->_setMinutesPopup ();

    # Stuff for hide/show js controls
    $html .= Javascript->setCookie;
    $html .= Javascript->getCookie;
    $html .= GetHTML->HideShow_Javascript;
    my ($hide_18, $show_18) = ($i18n->get ('Hide'), $i18n->get ('Show'));

    # Form for adding new event string
    my $addOrEditURL = $operation->makeURL ({Op => $action});

    $html .= startform ({-action => $addOrEditURL,
                         -name => 'EventEditForm'});

    $html .= GetHTML->SectionHeader ($mainHeader);

    my $hideThese = $prefs->EditFormHide || '';
    my %hideIt = (whenInc     => ($hideThese =~ /whenInc/i)     || 0,
                  border      => ($hideThese =~ /border/i)      || 0,
                  colors      => ($hideThese =~ /colors/i)      || 0,
                  category    => ($hideThese =~ /category/i)    || 0,
                  moreCats    => ($hideThese =~ /moreCats/i)    || 0,
                  summary     => ($hideThese =~ /summary/i)     || 0,
                  details     => ($hideThese =~ /details/i)     || 0,
                  repeat      => ($hideThese =~ /repeat/i)      || 0,
                  subscribers => ($hideThese =~ /subscribers/i) || 0,
                  mail        => ($hideThese =~ /mail/i)        || 0);

    my $dateTable = table ({-cellspacing => 0, -cellpadding => 0},
                           Tr (td (b (($repeatInfo and ($allOrOne =~ /all/i))
                                      ? $i18n->get ('Start Date:')
                                      : $i18n->get ('Date:')))),
                           Tr (td (GetHTML->datePopup ($i18n,
                                                  {name    => 'Date',
                                                   start   => $startDate - 750,
                                                   default => $startDate,
                                                 tab_index => $tab_index{Date},
                                                   op      => $operation}))));

    my $exportTable = '';
    my $do_owner   =  $prefs->PrivacyOwner;
    my $do_include = !$prefs->PrivacyNoInclude;
    my $private_label;
    if ($do_owner and $do_include) {
        $private_label = 'For other users, and when included:';
    }
    elsif ($do_owner) {
        $private_label = 'For other users:';
    }
    elsif ($do_include) {
        $private_label = 'When included in other calendars:';
    }
    else {
        $hideIt{whenInc} = 1;
    }
    unless ($hideIt{whenInc}) {
        $exportTable = table ({-cellspacing => 0, -cellpadding => 0},
                             Tr (td (b ($i18n->get ($private_label)))),
                             Tr (td (popup_menu (-name     => 'ExportPopup',
                                                 -default  => lc ($export),
                                                 -tabindex =>
                                                        $tab_index{ExportPopup},
                                                 -Values   => ['public',
                                                               'private',
                                                               'nopopup',
                                                               'unavailable',
                                                               'outofoffice'],
                                                 -labels   =>
                          {public  => $i18n->get ("Display this event"),
                           private => $i18n->get ("Don't display this event"),
                           nopopup => $i18n->get
                                         ("Display event text, but not Popup"),
                           unavailable =>$i18n->get ("Display 'Unavailable'"),
                           outofoffice =>$i18n->get
                                         ("Display 'Out of Office'"),
                          }))));
    }

    my $textTable = '';
    unless ($hideIt{summary}) {
        my $textarea = textarea (-name    => 'EventText',
                                 -tabindex => $tab_index{EventText},
                                 -rows    => 2,
                                 -columns => 35,
                                 -default => "$eventText",
                                 -wrap    => 'SOFT');

        # unescape any escaped &#123; type sequences, so wide chars which
        # were entered for the event display as the chars for editing. E.g. show
        # the lovely Omega char, instead of "&#937;"
        $textarea = _unescape_numeric_entities ($textarea);

        $textTable = td (table (Tr (td (b ($textPrompt))),
                                Tr (td ($textarea))));
    }

    my $whichTime = $prefs->TimeEditWhich || 'startend';
    my $timePopups;
    if ($whichTime =~ /^(startend|both)$/i) {
        $timePopups = table (Tr (td ({-align => 'RIGHT'},
                                    $i18n->get('Start Time:')),
                                td ({-align => 'RIGHT'}, $startTimeHourPopup),
                                td ({-align => 'LEFT'},
                                    $class->_minutePopup (name     =>
                                                            'StartMinutePopup',
                                                          tabindex =>
                                                          $tab_index{StartTime},
                                                          default  =>
                                                            $startMinute)),
                                td (@startTimeRadio)),
                            Tr (td ({-align => 'RIGHT'},
                                    $i18n->get ('End Time:')),
                                td ({-align => 'RIGHT'}, $endTimeHourPopup),
                                td ({'-align' => 'LEFT'},
                                    $class->_minutePopup (name    =>
                                                              'EndMinutePopup',
                                                          tabindex =>
                                                            $tab_index{EndTime},
                                                          default =>
                                                              $endMinute)),
                                td (@endTimeRadio)));
    }

    my $periodTable;
    if ($whichTime =~ /^(period|both)$/i) {
        my $periods = $prefs->getTimePeriods ('inherit'); # master too
        # Sort on start time; periods are IDs labels are names
        my @timePeriods = sort {$periods->{$a}->[1] <=> $periods->{$b}->[1]}
                             keys %$periods;
        my %labels = map {$_ => $periods->{$_}->[0]} @timePeriods;
        unshift @timePeriods, '-';

        my $onChange;
        if ($whichTime =~ /both/i) {
            $onChange = 'setTimeFromPeriod(this)';
            # Add the Javascript we need
            my $tzoffset = $prefs->Timezone || 0;
            $html .= $class->_setTimesFromPeriodJS ($milTime, $tzoffset,
                                                    map {$periods->{$_}}
                                                        @timePeriods);
        }

        $periodTable = table (Tr (td (b ($i18n->get ('Time Period') . ': ')),
                                  td (popup_menu (-name     => 'TimePeriod',
                                                  -tabindex =>
                                                       $tab_index{TimePeriod},
                                                  -default  => $timePeriod,
                                                  -onChange => $onChange,
                                                  -values   => \@timePeriods,
                                                  -labels   => \%labels))));
    }

    my $timeTable;
    if ($periodTable and $timePopups) {
        $timeTable = "<br><table border=1><tr>" .
                     "<td align='center'>$periodTable<hr width=\"80%\">" .
                     "$timePopups</td></tr></table><br>";
    } else {
        $timeTable = $periodTable || $timePopups || '&nbsp;';
    }

    my $border = '';
    unless ($hideIt{border}) {
        $border = checkbox (-name     => 'BorderCheckbox',
                            -tabindex => $tab_index{Border},
                            -checked  => $drawBorder,
                            -label    => '');
    }

    my $colorNames = '';
    unless ($hideIt{colors}) {
        $html .= Javascript->ColorPalette ($operation);
        $colorNames = a ({-href   => "Javascript:ColorWindow()"},
                         $i18n->get ('Color Names'));
    }

    my ($categoryPopup, $moreCategories) = ('', '');
    unless ($hideIt{category}) {
        my $catObjs = $prefs->getCategories (1);

        my $onClick = 'setStyle(this)';
        my ($bgs, $fgs);
        ($categoryPopup, $bgs, $fgs) = _makeCatPopup (name      => 'Category',
                                                      tab_index =>
                                                        $tab_index{Category},
                                                      cats      => $catObjs,
                                                     selected  => [$primaryCat],
                                                      onClick   => $onClick);
        my $jsBG = join ',', @$bgs;
        my $jsFG = join ',', @$fgs;

        unless ($hideIt{moreCats}) {
            $moreCategories =
                scrolling_list (-name     => 'MoreCategories',
                                -default  => [@moreCats],
                                -Values   => [sort {lc($a) cmp lc($b)}
                                                            keys %$catObjs],
                                -size     => 5,
                                -tabindex => $tab_index{MoreCategories},
                                -multiple => 'true');
        }

        $html .= <<END_SCRIPT;
 <script language="JavaScript">
 <!--
    function setStyle (theList) {
        if (navigator.appName.toLowerCase().indexOf("microsoft") > -1) {
            return;
        }
        var bgColors = new Array ($jsBG);
        var fgColors = new Array ($jsFG);
        theList.style.backgroundColor = bgColors[theList.selectedIndex-1];
        theList.style.color           = fgColors[theList.selectedIndex-1];
    }
-->
 </script>
END_SCRIPT
    }

    my %labels = (category => $prompts{Category} || $i18n->get ('Category'),
                  moreCats => $prompts{MoreCats} ||
                                             $i18n->get ('More Categories'),
                  backg    => $i18n->get ('Background'),
                  foreg    => $i18n->get ('Foreground'),
                  border   => $i18n->get ('Draw Border'));
    foreach (qw/category moreCats border/) {
        $labels{$_} = '' if $hideIt{$_};
    }
    $labels{backg} = $labels{foreg} = '' if $hideIt{colors};
    $labels{moreCats} = '' if $hideIt{category};

    my ($bgField, $fgField) = ('', '');
    unless ($hideIt{colors}) {
        $bgField = textfield (-name      => 'BackgroundColor',
                              -default   => $bgColor,
                              -size      => 10,
                              -tabindex  => $tab_index{BackgroundColor},
                              -maxlength => 20);
        $fgField = textfield (-name      => 'ForegroundColor',
                              -default   => $fgColor,
                              -size      => 10,
                              -tabindex  => $tab_index{ForegroundColor},
                              -maxlength => 20);
    }

    my $miscStuff = table ({-width => '100%',
                            -cellspacing => 0, -cellpadding => 0},
                           Tr (th [@labels{qw/category moreCats backg
                                              foreg border/}]),
                           Tr (td ({-align => 'center',
                                    -valign => 'top'},
                                   $categoryPopup),
                               td ({-align => 'center'},
                                   $moreCategories),
                               td ({-align => 'center', valign => 'top'},
                                   $bgField),
                               td ({-align => 'center', valign => 'top'},
                                   $fgField),
                               td ({-align => 'center', valign => 'top'},
                                   $border),
                               td ($colorNames)));

    my $popupTable = '';
    unless ($hideIt{details}) {
        my $prompt = $prompts{Details} ||
                       $i18n->get ('Enter a URL, or text for a popup window:');
        my $textarea = textarea (-name     => 'PopupText',
                                 -tabindex => $tab_index{PopupText},
                                 -rows     => 4,
                                 -cols     => 60,
                                 -default  => "$popupText",
                                 -wrap     => 'SOFT');

        $textarea = _unescape_numeric_entities ($textarea);

        $popupTable = table
            (Tr (td (b ($prompt))),
             Tr (td ($textarea )),
             Tr (td ($prompts{SubDetails} ||
                     $i18n->get ('Anything starting with '    .
                                 'http:, https:, mailto:, '    .
                                 'ftp:, or a \'www\' '  .
                                 'string (e.g. '               .
                                 '<i>www.domainname.com</i>) ' .
                                 'will be a link. Anything '   .
                                 'else will be popup text.'))));
    }

    # Custom Fields - if any, including system-defined ones
    my $custom_div = '';
    if (my $field_order = $prefs->CustomFieldOrder) {
        my $used_template;
        my $template_open_failed;

        my $fields_lr = $prefs->get_custom_fields (system => 1);

        # Set defaults for fields - if we're editing an event
        my %defaults;
        if ($event) {
            foreach my $field (@$fields_lr) {
                $defaults{$field->id} = $event->customField ($field);
                # if undef, set to '' so we don't get default value
                if (!defined $defaults{$field->id}) {
                    $defaults{$field->id} = '';
                }
            }
        }

        # First, check for user-defined template for this calendar...
        require Calendar::Template;
        my $template = Template->new (name     => 'EditForm',
                                      cal_name => $calName,
                                      convert_newlines => 1);

        if ($template->ok) {
            my %substitutions;
            foreach my $field (@$fields_lr) {
                my $from = '$' . $field->name;
                my $to   = $field->make_html (default => $defaults{$field->id});
                $substitutions{$from} = $to;
            }
            $custom_div = $template->expand (\%substitutions);
            $used_template++;
        }
        elsif ($template->error ne 'not found') {
            $template_open_failed = $template->error;
        }

        # If no template file or it failed, use settings from Prefs
        if (!$used_template) {
            my @rows;
            my @field_order = split ',', $field_order;
            my %fields_by_id = map {$_->id => $_} @$fields_lr;
            my $tab_index = $tab_index{CustomFields};
            foreach my $field_id (@field_order) {
                my $field = $fields_by_id{$field_id};
                next unless $field;
                push @rows, Tr (td ({align => 'right'},
                                    b ($field->label || '&nbsp;')),
                                td ($field->make_html (default  =>
                                                          $defaults{$field->id},
                                                       tabindex =>
                                                          $tab_index++)));
            }
            if ($template_open_failed) {
                my $message = $i18n->get ('Found "EditForm" template file, but '
                                          . "couldn't open it: ")
                              . "'$template_open_failed'";
                push @rows, Tr (td ({align => 'right'},
                                    i ($i18n->get ('Note:'))),
                                td (i ($message)));
            }
            $custom_div = table (@rows) if (@rows);
        }
        $custom_div = qq (<div class="CustomFields">$custom_div</div>);
    }

    # Allow specifying which calendars to add the event to. So, we need a
    # list of all calendars this user has Add permission in.
    my $selectCalRow = '';
    my $whichUsers = $prefs->MultiAddUsers;
    my $showMulti  = (($whichUsers  =~ /anyone/i)
                     or
                      ($whichUsers =~ /caladmin/i and
                       $operation->permission->permitted ($username, 'Admin'))
                     or
                      ($whichUsers =~ /sysadmin/i and
                       Permissions->new (MasterDB->new)->permitted ($username,
                                                                    'Admin')));
    # Don't show if we're already specifying multiple cals,
    # or if we're editing something other then reg. event or entire series
    my $multiCalDisplayed;
    if (!defined $calendarList and $showMulti and
        (!$repeatInfo or $allOrOne =~ /all/i)) {
        my $whichCals = $prefs->MultiAddCals || 'permitted';
        my %allowed = map {$_ => 1}
                       grep {Permissions->new (Database->new ($_))->permitted
                                                            ($username, 'Add')}
                       MasterDB->getAllCalendars;
        my @myCals = ();
        if ($whichCals =~ /ingroup/i) {
            my @groups = $prefs->getGroups;
            my ($groups, $noGroup) = MasterDB->getCalendarsInGroup (@groups);
            @myCals = (@$groups, @$noGroup);
        } elsif ($whichCals =~ /included/i) {
            @myCals = $prefs->getIncludedCalendarNames;
        } elsif ($whichCals =~ /permitted/i) {
            @myCals = keys %allowed;
        }
        my @theCals;
        foreach (@myCals) {
            next unless $allowed{$_};
            next if ($_ eq $calName);
            push @theCals, $_;
        }
        # Perl 5.8.4 bug - does not like @foo = ('baz', sort @foo);
#        @theCals = ($calName, sort {lc($a) cmp lc($b)} @theCals);
#        if (@theCals > 1) {
        my @xxxtheCals = ($calName, sort {lc($a) cmp lc($b)} @theCals);
        if (@xxxtheCals > 1) {
            $multiCalDisplayed = 1;
            my $calPopup = scrolling_list (-name     => 'WhichCalendars',
                                           -default  => $calName,
#                                           -Values   => \@theCals,
                                           -Values   => \@xxxtheCals,
                                           -size     => 5,
                                           -tabindex =>
                                                  $tab_index{WhichCalendars},
                                           -multiple => 'true');
            my ($prompt, $message);
            if (lc ($newOrEdit) eq 'new') {
                $prompt  = $i18n->get ('Add to Which Calendars?');
                $message = '<small><b>Note:</b> the event will not be ' .
                           'added to the current calendar unless it is ' .
                           'selected.</small>';
            } else {
                $prompt  = $i18n->get ('Copy to Which Calendars?');
                $message = '<b>Note:</b> If other calendars are selected, ' .
                           'the event will be copied to those calendars, '  .
                           'even if you select "Replace"';
                $message = '<b>Note:</b> This selection is only used when ' .
                           '<b>copying</b> ' . 'events to other calendars.';
            }

            my $table = table (Tr (td [$prompt, '&nbsp;',
                                       $calPopup, $message]));
            $selectCalRow = Tr (td ({-colspan => 2}, $table));
        }
    }

    $html .= table ({-class => 'EntryWidgets',
                     -width => '100%'},
                    Tr (td ([$dateTable, $exportTable])),
                    Tr ($textTable, td ($timeTable)),
                    Tr (td ({-colspan => 2}, $miscStuff)),
                    Tr (td ({-colspan => 2}, $popupTable)),
                    Tr (td ({-colspan => 2}, $custom_div)),
                    $selectCalRow);

    $html .= '<br>';
    $html .= _submitButtons ($buttonText, $copyButtonText, $paramHashRef,
                             $tab_index{SubmitAfterMain}, $operation);
    $html .= '<br>';

    # Display repeat stuff unless prefs tell us not to or we're editing a
    # single instance of a repeating event
    unless ($hideIt{repeat} or
            $repeatInfo and $allOrOne !~ /all/i) {

        $html .= '<br>';

        my @repeatRadios = radio_group ('-name'      => 'RepeatRadio',
                                        '-values'    => ['None', 'Repeat',
                                                         'ByWeek'],
                                        '-default'   => $defaultRepeat,
                                        '-labels'    =>
                                             {'None'   => ' ' .
                                                   $i18n->get("Don't Repeat"),
                                              'Repeat' => ' ' .
                                                   $i18n->get('Repeat') . ' ',
                                              'ByWeek' => ' ' .
                                           $i18n->get('Repeat on the') . ' '});

        my %nthLabels = (1  => '',
                         2  => ' Other',
                         3  => ' Third',
                         4  => ' Fourth',
                         5  => ' Fifth',
                         6  => ' Sixth',
                         7  => ' Seventh',
                         8  => ' Eighth',
                         9  => ' Ninth',
                         10 => ' Tenth',
                         11 => ' Eleventh',
                         12 => ' Twelfth',
                         13 => ' Thirteenth',
                         14 => ' Fourteenth',
                         15 => ' Fifteenth',
                         16 => ' Sixteenth',
                         17 => ' Seventeenth',
                         18 => ' Eighteenth',
                         19 => ' Nineteenth',
                         20 => ' Twentieth');
        %nthLabels = map {$_ => $i18n->get ("Every$nthLabels{$_}")}
                         keys %nthLabels;

        my $freqPopup = popup_menu ('-name'    => 'Frequency',
                                    '-default' => $frequency,
                                    '-values'  => [1..20],
                                    '-labels'  => \%nthLabels,
                                    '-onChange'=>
                                    'this.form.RepeatRadio[1].checked = true');

        my @values = ('day', 'dayBanner', 'week', 'month', 'year',
                      '1 2 3 4 5', '1 2 3 4 5 6', '1 3 5', '1 3', '2 4',
                      '6 7', '2 5', '5 6', '5 6 7', '4 5 6', '1 2 3 4',
                      '2 3 4 5');
        my %labels = ('day'       => $i18n->get ('Day'),
                      'dayBanner' => $i18n->get ('Day (Bannered)'),
                      'week'      => $i18n->get ('Week'),
                      'month'     => $i18n->get ('Month'),
                      'year'      => $i18n->get ('Year'),
                      '1 2 3 4 5' => $i18n->get ('Monday')    . ' - ' .
                                     $i18n->get ('Friday'),
                      '1 2 3 4 5 6' => $i18n->get ('Monday')    . ' - ' .
                                       $i18n->get ('Saturday'),
                      '1 3 5'     => $i18n->get ('Monday')    . ', ' .
                                     $i18n->get ('Wednesday') . ', ' .
                                     $i18n->get ('Friday'),
                      '1 3'       => $i18n->get ('Monday')   . ', ' .
                                     $i18n->get ('Wednesday'),
                      '2 4'       => $i18n->get ('Tuesday')   . ', ' .
                                     $i18n->get ('Thursday'),
                      '2 5'       => $i18n->get ('Tuesday')   . ', ' .
                                     $i18n->get ('Friday'),
                      '1 2 3 4'   => $i18n->get ('Monday')    . ' - ' .
                                     $i18n->get ('Thursday'),
                      '2 3 4 5'   => $i18n->get ('Tuesday') . ' - ' .
                                     $i18n->get ('Friday'),
                      '5 6'       => $i18n->get ('Friday')   . ', ' .
                                     $i18n->get ('Saturday'),
                      '5 6 7'     => $i18n->get ('Friday')   . ' - ' .
                                     $i18n->get ('Sunday'),
                      '4 5 6'     => $i18n->get ('Thursday')    . ' - ' .
                                     $i18n->get ('Saturday'),
                      '6 7'       => $i18n->get ('Saturday')  . ', ' .
                                     $i18n->get ('Sunday'));

        my $def = $period || $prefs->DefaultPeriod;
        my $periodPopup .= popup_menu ('-name'    => 'Period',
                                       '-default' => $def,
                                       '-values'  => \@values,
                                       '-labels'  => \%labels,
                                       '-onChange'=> 
                                    'this.form.RepeatRadio[1].checked = true');

        @values = ('1', '2', '3', '4', '5', '6', '1 3', '2 4', '1 5');
        %labels = ('1'   => $i18n->get ('First'),
                   '2'   => $i18n->get ('Second'),
                   '3'   => $i18n->get ('Third'),
                   '4'   => $i18n->get ('Fourth'),
                   '5'   => $i18n->get ('Last'),
                   '6'   => $i18n->get ('Fifth, if it exists'),
                   '1 3' => $i18n->get ('First and Third'),
                   '2 4' => $i18n->get ('Second and Fourth'),
                   '1 5' => $i18n->get ('First and Last'));

        my $mwPopup = popup_menu ('-name'    => 'MonthWeek',
                                  '-default' => $monthWeek,
                                  '-values'  => \@values,
                                  '-labels'  => \%labels,
                                  '-onChange'=> 
                                    'this.form.RepeatRadio[2].checked = true');

        my $dayName = b ($i18n->get ($startDate->dayName)) . ' '
                      . $i18n->get ('every');
        my $month18 = lc ($i18n->get ('Month'));
        my $mmPopup = popup_menu ('-name'    => 'MonthMonth',
                                  '-default' => $monthMonth,
                                  '-values'  => [ 1, 2, 3, 4, 5, 6, 12],
                                  '-labels'  => {'1' => $month18,
                                                 '2' => $i18n->get ('other') .
                                                        " $month18",
                                                 '3' => $i18n->get ('third') .
                                                        " $month18",
                                                 '4' => $i18n->get('fourth') .
                                                        " $month18",
                                                 '5' => $i18n->get('fifth') .
                                                        " $month18",
                                                 '6' => $i18n->get('sixth') .
                                                        " $month18",
                                                 '12' => $i18n->get ('year')},
                                  '-onChange'=> 
                                    'this.form.RepeatRadio[2].checked = true');

        $html .= GetHTML->SectionHeader ($i18n->get ('Repeat Information')
                                         . '&nbsp;<i>('
                                         . $i18n->get ('Optional') . '</i>)',
                                         {div_id     => 'RepeatSection',
                                          hide_label => $hide_18,
                                          show_label => $show_18});

        $html .= '<div id="RepeatSection">';

        # Put the three repeat options (none, every, by nth day of month)
        # in a table, so they have a background
        my $repeatTable =
                table ({-cellspacing  => 0, -width => '100%'},
                       Tr (td ($repeatRadios[0])),
                       Tr (td ($repeatRadios[1] . $freqPopup . $periodPopup),
                           td ({-align => 'right'},
                               checkbox (-name    => 'SkipWeekends',
                                         -checked => $skipWeekends,
                                         -label   => ' ' .
                                             $i18n->get ("Skip Weekends")))),
                       Tr (td ({-colspan => 2},
                               $repeatRadios[2] . $mwPopup   . $dayName .
                               $mmPopup)));

        # Now do the Repeat Until Stuff
        my $forever = $i18n->get ('Forever!');
        my @radio = radio_group ('-name'    => 'RepeatUntilRadio',
                                 '-values'  => [' ', " $forever"],
                                 '-default' => (!$endDate or
                                                  $endDate != Date->openFuture)
                                               ? ' ' : " $forever");

        my $untilTable =
                table ({-cellspacing => 0},
                       Tr (td ({-rowspan => 2,
                                -valign  => 'center'},
                               '<b>' . $i18n->get ('Repeat until') .
                               '</b>&nbsp; &nbsp;'),
                           td ($radio[0] .
                               GetHTML->datePopup ($i18n,
                                                   {name    => 'Until',
                                                    start   => $date,
                                                    op      => $operation,
                                                    default => $endDate ||
                                                                     $date + 1,
                                                    onChange =>
                           'this.form.RepeatUntilRadio[0].checked = true;' .
                           'if (this.form.RepeatRadio[0].checked == true) {'.
                           '  this.form.RepeatRadio[1].checked = true}'}))),
                       Tr (td ($radio[1])));

        $html .= table ({-class => 'EntryWidgets',
                         -border => 0, -cellspacing => 0,
                         -width   => '100%'},
                        Tr ([td ($repeatTable),
                             td ('<hr width="25%">'),
                             td ($untilTable)]));

        $html .= '<br>';
        $html .= _submitButtons ($buttonText, $copyButtonText, $paramHashRef,
                                 undef, $operation);
        $html .= '</div>';
    }

    # Display current subscribers, if editing an event which has some
    if ($event and Defines->mailEnabled and
        my $subscribers = $event->getSubscribers ($calName) and
        !$hideIt{subscribers}) {
        $html .= '<br>';
        $html .= GetHTML->SectionHeader ($i18n->get ('Subscriptions')
                                         . '&nbsp;<i>('
                                         . $i18n->get ('Optional') . '</i>)',
                                         {div_id     => 'SubscriptionSection',
                                          hide_label => $hide_18,
                                          show_label => $show_18});

        # Sort them; rejoin with spaces so it wraps in textarea
        my @subs = split /,/, $subscribers;
        $subscribers = join ', ', sort {lc($a) cmp lc ($b)} @subs;

        $html .= '<div id="SubscriptionSection">';

        $html .= table ({-class => 'EntryWidgets',
                         -width => '100%'},
                        Tr (td ({-align => 'right'},
                                '<small>' .
                                $i18n->get ('Email addresses subscribed to ' .
                                            'this event:') .
                                '</small>'),
                            td ({-align => 'left'},
                                textarea (-name    => 'SubscriberAddresses',
                                          -rows    => 2,
                                          -cols    => 60,
                                          -default => $subscribers,
                                          -wrap    => 'SOFT'))));
        $html .= '</div>';
    }

    # JS cleanup is always called from ShowDay
    $html .=  <<END_SCRIPT;
<script language="Javascript">
<!-- start
    var EmailSelectionPopupWindow;
    function cleanUpPopups () {
        if (EmailSelectionPopupWindow)
            EmailSelectionPopupWindow.close();
    }
 -->
</script>
END_SCRIPT


    # Display mail stuff unless prefs tell us not to.
    unless ($hideIt{mail}) {

        $html .= "\n<br>\n";
        $html .= GetHTML->SectionHeader ($i18n->get ('Email Notification')
                                         . '&nbsp;<i>('
                                         . $i18n->get ('Optional') . '</i>)',
                                         {div_id     => 'NotifySection',
                                          hide_label => $hide_18,
                                          show_label => $show_18});

        $html .= '<div id="NotifySection">';

        my $showAddrSelect = lc ($prefs->EmailSelector || '') ne 'none';
        if ($showAddrSelect) {
            my $width  = $prefs->EmailSelectPopupWidth  || 400;
            my $height = $prefs->EmailSelectPopupHeight || 300;
            $html .= Javascript->MakePopupFunction
                       ($operation->makeURL ({Op => 'EmailSelector'}),
                        'EmailSelection', $width, $height);
        }

        my $addressTable =
            table ({-width => '100%', -cellspacing => 0 ,-cellpadding => 0},
                   Tr (td ({-colspan => 3}, '<small>' . $mailPrompt . ' ' .
                           $i18n->get ('(Use commas between addresses.)') .
                           '</small>')),
                   Tr (td ({-align => 'right', -width => '10%'},
                           $i18n->get ('TO:')),
                       td (textfield (-name    => 'MailTo',
                                      -default => $mailTo,
                                      -size    => 40)),
                       $showAddrSelect ?
                           td (a ({-href =>'JavaScript:EmailSelectionPopup()'},
                                  $i18n->get ('Email Address Selector')))
                           : ''),
                   Tr (td ({-align => 'right'}, $i18n->get ('CC:')),
                       td (textfield (-name    => 'MailCC',
                                      -default => $mailCC,
                                      -size    => 40))),
                   Tr (td ({-align => 'right'}, $i18n->get ('BCC:')),
                       td (textfield (-name    => 'MailBCC',
                                      -default => $mailBCC,
                                      -size    => 40)),
                       Defines->mailEnabled ?
                           td (checkbox (-name    => 'NotifySubscribers',
                                         -checked => $defNotify,
                                         -label   =>
                                         $i18n->get ('Automatically notify ' .
                                                     'calendar subscribers')))
                            : ''));
        my $commentTable =
            table ({-width => '100%', -cellspacing => 0 ,-cellpadding => 0},
                   Tr (td ({-colspan => 2}, '<small>' .
                           $i18n->get ('Specify any additional comments '   .
                                       'that you would like included with ' .
                                       'the notification.') . '</small>')),
                   Tr (td ({-width => '10%'}, '&nbsp;'),
                       td (textarea (-name    => 'MailComments',
                                     -rows    => 2,
                                     -cols    => 60,
                                     -default => $mailText,
                                     -wrap    => 'SOFT'))));

        $html .= table ({-class => 'EntryWidgets',
                         -width => '100%'},
                        Tr ([td ($addressTable), td ($commentTable)]));
        $html .= '</div>';      # end NotifySection

        if (Defines->mailEnabled) {
            $html .= '<br>';
            $html .= GetHTML->SectionHeader ($i18n->get ('Email Reminders')
                                             . '&nbsp;<i>('
                                             . $i18n->get ('Optional')
                                             . '</i>)',
                                             {div_id     => 'ReminderSection',
                                              hide_label => $hide_18,
                                              show_label => $show_18});
            $html .= '<div id="ReminderSection">';

            my ($remind_values, $remind_labels)
                              = $class->reminder_values_and_labels ($i18n);

            my $reminderTimeTable =
                table ({-cols => 6, -cellpadding => 0, -cellspacing => 0},
                       Tr (td ({-nowrap => 1},
                               $i18n->get ('Send reminder email:')),
                           td (popup_menu (-name    => 'MailReminder',
                                           -default => $reminderTimes[0],
                                           -values  => $remind_values,
                                           -labels  => $remind_labels)),
                           td ({-nowrap => 1},
                               $i18n->get ('before, and')),
                           td (popup_menu (-name    => 'MailReminder2',
                                           -default => $reminderTimes[1],
                                           -values  => $remind_values,
                                           -labels  => $remind_labels)),
                           td ({-nowrap => 1},
                               $i18n->get ('before the event.')),
                           td ('&nbsp;')),
                       Tr (td ({-align => 'right', -nowrap => 1},
                               $i18n->get ('Email Address:')),
                           td ({-colspan => 5},
                               textfield (-name    => 'ReminderAddress',
                                          -default => $reminderTo,
                                          -size    => 40))));

            $html .= table ({-class => 'EntryWidgets',
                             -width => '100%'},
                            Tr (td ($reminderTimeTable)));
            $html .= '</div>';
        }
        $html .= '<br>';
        $html .= _submitButtons ($buttonText, $copyButtonText, $paramHashRef,
                                 undef, $operation);
    }

    # We need to 'override' params, since we call ourself.

    if (defined $calendarList and ref $calendarList) {
        $html .= hidden (-name     => 'WhichCalendars',
                         -override => 1,
                         -value    => $calendarList); # must be listref
        $nextOp = $paramHashRef->{nextOp};
    }
    if ($multiCalDisplayed) {
        $html .= hidden (-name     => 'MultiCalDisplayed',
                         -override => 1,
                         -value    => 1);
    }

    $html .= hidden (-name     => 'CalendarName',
                     -override => 1,
                     -value    => $calName);
    $html .= hidden (-name     => 'Date',
                     -override => 1,
                     -value    => "$date");
    $html .= hidden (-name     => 'DisplayDate',
                     -override => 1,
                     -value    => "$displayDate") if $displayDate;
    $html .= hidden (-name     => 'OldEventID',
                     -override => 1,
                     -value    => $eventID) if defined $eventID;
    $html .= hidden (-name     => 'AllOrOne',
                     -override => 1,
                     -value    => $allOrOne);
    $html .= hidden (-name     => 'Op',
                     -override => 1,
                     -value    => $action);
    $html .= hidden (-name     => 'NextOp',
                     -override => 1,
                     -value    => $nextOp);
    $html .= hidden (-name     => 'DisplayCal',
                     -override => 1,
                     -value    => $displayCal);
    $html .= hidden (-name     => 'ViewCal',
                     -override => 1,
                     -value    => $viewCal) if $viewCal;
    $html .= hidden (-name     => 'FromPopupWindow',
                     -value    => $paramHashRef->{fromPopupWindow})
        if $paramHashRef->{fromPopupWindow};

    $html .= $operation->hiddenDisplaySpecs;

    $html .= endform();

    # Add js fn to initialize hide/show labels; must be after they exist
    $html .= qq { <script language="JavaScript" type="text/javascript">
    var sections = ["Repeat", "Notify", "Subscription", "Reminder"];
    for (i=0; i<4; i++) {
        var itemID = sections[i] + 'Section';
        var hideThis = getCookie ("CalciumEditForm" + itemID);
        var element = document.getElementById(itemID);
        if (element) {
            if (hideThis == "show") {
                element.style.display = "none";
            } else {
                element.style.display = "";
            }
            hide_or_show (itemID, '$hide_18', '$show_18');
        }
    }
    </script>};

    return qq (<div class="EventEditForm">$html</div>\n);
}

# unescape any escaped &#123; type sequences.
# Used by textareas, so wide chars which were entered for the event
# display as the chars for editing. E.g. show the lovely Omega char,
# instead of "&#937;"
sub _unescape_numeric_entities {
    my $text = shift;
    $text =~ s/&amp;#(\d+)/&#$1/g;
    return $text;
}

sub _submitButtons {
    my ($submitText, $copyText, $params, $tabindex, $op) = @_;

    my $html .= submit (-name     => 'Submit',
                        -tabindex => $tabindex,
                        -value    => $submitText);
    $tabindex++ if $tabindex;

    if ($copyText) {
        $html .= ' &nbsp; ';
        $html .= submit (-name     => 'CopyEvent',
                         -tabindex => $tabindex,
                         -value    => $copyText);
        $tabindex++ if $tabindex;
    }

#    $html .= ' &nbsp; &nbsp; ' . reset () . ' &nbsp; ';

    # If editing, maybe allow deleting. See EventReplace
    if ($params->{showDelete}) {
        my $delete_onclick;
        if (my $event = $params->{event}) {
            $delete_onclick = EventEditForm->delete_confirm (op    => $op,
                                                             event => $event);
        }
        $html .= ' &nbsp; ';
        $html .= submit (-name     => 'DeleteEvent',
                         -tabindex => $tabindex++,
                         -value    => $params->{showDelete},
                         -onclick  => $delete_onclick);
        $tabindex++ if $tabindex;
    }

    unless ($params->{noCancel}) {
        $html .= ' &nbsp; ';
        $html .= submit (-name     => 'Cancel',
                         -tabindex => $tabindex++,
                         -onClick  => $params->{cancelOnClick});
    }

    $html;
}

# Produce a popup to select an hour. If using 12 hour time, an am/pm radio
# will also be created. Names will be $nameBase . 'Popup', $nameBase . 'Radio'
# Returns a list of 1 or 2 strings. (Second is the radio, obviously.)
# Pass hash pairs with 'nameBase', 'default' keys.
# (Default should be int, -1 -> 23)
# Defaults to None.
sub _hourPopup {
    my $className = shift;
    my %args = (nameBase     => 'hour',
                default      => -1,
                militaryTime => 1,
                None         => 'None',
                tabindex     => undef,
                @_);

    $args{default} = -1 if ($args{default} < -1 or $args{default} > 23);

    my ($values, $labels, $popup, @radio);

    if ($args{'militaryTime'}) { # true or false
        $values = [-1, 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11,
                      12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23];

        $labels = {'-1' => $args{'None'},
                    '0' => '0',   '1' => '1',   '2' => '2',   '3' => '3',
                    '4' => '4',   '5' => '5',   '6' => '6',   '7' => '7',
                    '8' => '8',   '9' => '9',  '10' => '10', '11' => '11',
                   '12' => '12', '13' => '13', '14' => '14', '15' => '15',
                   '16' => '16', '17' => '17', '18' => '18', '19' => '19',
                   '20' => '20', '21' => '21', '22' => '22', '23' => '23'};
    } else {
        $values = [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
        $labels = {'-1' => $args{'None'},
                    '0' => '12',  '1' => '1',  '2' => '2',   '3' => '3',
                    '4' => '4',   '5' => '5',  '6' => '6',   '7' => '7',
                    '8' => '8',   '9' => '9', '10' => '10', '11' => '11'};

        my $tabindex;
        if ($args{tabindex}) {
            $tabindex = $args{tabindex} + 2; # leave one for minutes
        }

        @radio = radio_group ('-name'    => $args{nameBase} . 'Radio',
                              '-values'  => ['AM', 'PM'],
                              '-default' => $args{default} > 11 ? 'PM' : 'AM',
                              -tabindex  => $tabindex,
                              '-onClick' => "amPmRadios (this)");
        $args{default} -= 12 if $args{default} > 11;
    }

    $popup = popup_menu ('-name'     => $args{nameBase} . 'Popup',
                         '-default'  => $args{default},
                         '-values'   => $values,
                         '-labels'   => $labels,
                         -tabindex   => $args{tabindex},
                         '-onChange' => "setMinutesPopup (this)");

    ($popup, @radio);
}

# Produce a popup to select a minute.
# Pash hash pairs with 'name', 'default' keys.
# Defaults to none.
sub _minutePopup {
    my $className = shift;
    my %args = (name         => 'minutePopup',
                default      => -1,
                tabindex     => undef,
                @_);

    $args{default} = -1 if ($args{default} < -1 or $args{default} > 59);

    my @values = (-1);
    my %labels = (-1 => ' ', -2 => '---');

    for (my $i=0; $i<60; $i+=5) {
        push @values, $i;
        $labels{$i} = ":$i";
    }
    push @values, -2;
    for (my $i=1; $i<60; $i++) {
        push @values, $i;
        $labels{$i} = ":$i";
    }
    for (my $i=0; $i<10; $i++) {
        $labels{$i} = ":0$i";
    }

    my $tabindex = $args{tabindex} ? $args{tabindex} + 1 : undef;

    popup_menu ('-name'    => $args{name},
                -tabindex  => $args{tabindex},
                '-default' => $args{default},
                '-values'  => \@values,
                '-labels'  => \%labels);
}

sub _setMinutesPopup {
    my $class = shift;
    my $code = <<END_SCRIPT;
 <script language="JavaScript">
 <!-- start
     // Set the Minutes Popup to :00 if the hours were edited to non-blank
     // and the minutes are blank, or to blank if the hours were set to blank
     function setMinutesPopup (hourPopup) {
         form = hourPopup.form
         if (hourPopup.name == 'StartHourPopup') {
             minutePopup = form.StartMinutePopup;
         } else {
             minutePopup = form.EndMinutePopup;
         }
         // If we select None for hour, set minutes to None
         if (hourPopup.selectedIndex < 1) {
             minutePopup.selectedIndex = 0
         }
         // If we select a valid hour and minutes set to none, set them to 0
         if ((hourPopup.selectedIndex > 0) &&
             (minutePopup.selectedIndex < 1)) {
             minutePopup.selectedIndex = 1
         }
     }

     // Set the End Time radio to PM if the start time is PM
     function amPmRadios (radio) {
         if (radio.name == 'StartHourRadio') {
             if (radio.value == 'PM') {
                 radio.form.EndHourRadio[1].checked = true;
             }
         }
     }
 // End -->
 </script>
END_SCRIPT

    $code;
}

sub _setTimesFromPeriodJS {
    my ($class, $milTime, $offset, @periods) = @_;

    my @startHours = 0;
    my @startMins  = 0;
    my @startAM    = 0;
    my @endHours   = 0;
    my @endMins    = 0;
    my @endAM      = 0;

    foreach (@periods) {
        next unless ref $_;

        my $startHour = int ($_->[1] / 60) + $offset;
        my $startMin  = $_->[1] % 60;

        my ($endHour, $endMin);
        if ($_->[2] ne '') {
            $endHour = int ($_->[2] / 60) + $offset;
            $endMin  = $_->[2] % 60;
        } else {
            $endHour = $endMin = -1;
        }


        if ($milTime) {
            push @startHours, $startHour + 1;
            push @endHours,   $endHour + 1;
        } else {
            my $ampm = '"AM"';
            if ($startHour >= 12) {
                $startHour -= 12;
                $ampm = '"PM"';
            }
            $startHour = 0 if ($startHour == 12);
            push @startHours, $startHour + 1;
            push @startAM, $ampm;


            $ampm = '"AM"';
            if ($endHour >= 12) {
                $endHour -= 12;
                $ampm = '"PM"';
            }
            $endHour = 0 if ($endHour == 12);
            push @endHours, $endHour + 1;
            push @endAM, $ampm;
        }

        if ($startMin == 0) {
            push @startMins, 1;
        } else {
            push @startMins, $startMin + 13;
        }
        if ($endMin == -1) {
            push @endMins, 0;
        } elsif ($endMin == 0) {
            push @endMins, 1;
        } else {
            push @endMins, $endMin + 13;
        }
    }
    my $startHours = join (',', @startHours);
    my $startMins  = join (',', @startMins);
    my $startAM    = join (',', @startAM);

    my $endHours   = join (',', @endHours);
    my $endMins    = join (',', @endMins);
    my $endAM      = join (',', @endAM);

    my @ampmCode = ('','');
    if (!$milTime) {
        @ampmCode =
                (qq /startAM    = [$startAM];
                     endAM      = [$endAM];/,
                 qq /if (startAM[index] == 'AM') {
                         form.StartHourRadio[0].checked = true;
                     } else {
                         form.StartHourRadio[1].checked = true;
                     }

                     if (endAM[index] == 'AM') {
                         form.EndHourRadio[0].checked = true;
                     } else {
                         form.EndHourRadio[1].checked = true;
                     }/);
    }

    my $code = <<END_SCRIPT;
 <script language="JavaScript">
 <!-- start
     startHours = [$startHours];
     startMins  = [$startMins];

     endHours   = [$endHours];
     endMins    = [$endMins];
     $ampmCode[0]

     // Set start/end times on period change
     function setTimeFromPeriod (periodPopup) {
         form = periodPopup.form
         index = periodPopup.selectedIndex;

         form.StartHourPopup.selectedIndex = startHours[index];
         form.StartMinutePopup.selectedIndex = startMins[index];

         form.EndHourPopup.selectedIndex = endHours[index];
         form.EndMinutePopup.selectedIndex = endMins[index];

         $ampmCode[1]
     }
 // End -->
 </script>
END_SCRIPT

    $code;
}

sub _makeCatPopup {
    my %args = @_;
    my $name       = $args{name};
    my $catObjs    = $args{cats};
    my $selecteds  = $args{selected};
    my $onClick    = $args{onClick};
    my $isMultiple = $args{isMultiple};
    my $tabindex   = $args{tab_index} ? qq /tabindex="$args{tab_index}"/ : '';

    $selecteds ||= [];
    my $style = '';
    if (!$isMultiple and $selecteds->[0] and
        (my $c = $catObjs->{$selecteds->[0]})) {
        my ($fg, $bg) = ($c->fg, $c->bg);
        $style = "style=\"color: $fg; background-color: $bg\"";
    }
    my $mult  = $isMultiple ? 'Multiple'              : '';
    my $click = $onClick    ? qq (onClick="$onClick") : '';
    my $size  = $isMultiple ? "size=$isMultiple"      : '';
    my $catPopup = "<select $style name=$name $mult $size $tabindex $click>";

    my %sel;
    foreach (@$selecteds) {
        next unless defined;
        $sel{$_} = 1;
    }

    $catPopup .= '<option value="-">-</option>';

    my (@jsBG, @jsFG);
    foreach $name (sort {lc ($a) cmp lc ($b)} keys %$catObjs) {
        $style = '';
        my ($fg, $bg) = ('black', 'lightgray');
        if ($catObjs->{$name}) {
            $fg = $catObjs->{$name}->fg || 'black';
            $bg = $catObjs->{$name}->bg || 'lightgray';
            $style = "style=\"color: $fg; background-color: $bg\"";
        }
        push @jsBG, "'$bg'";
        push @jsFG, "'$fg'";
        my $def = $sel{$name} ? 'selected' : '';
        my $esc = CGI::escapeHTML ($name);
        $catPopup .= "<option $def $style value=\"$esc\">$esc</option>\n";
    }
    $catPopup .= '</select>';
    return ($catPopup, \@jsBG, \@jsFG);
}

# Return [values] and {value => label}
sub reminder_values_and_labels {
    my ($class, $i18n) = @_;
    my @reminderValues = (0, 5, 10, 15, 20, 30, 45, 60, 120, 180, 360,
                          720, 1080,
                          1440,      1440*2,  1440*3,  1440*4, 1440*5,
                          1440*6,    1440*7,  1440*8,  1440*9, 1440*10,
                          1440*11,   1440*12, 1440*13, 1440*14);
    my ($minute, $minutes) = ($i18n->get ('minute'), $i18n->get ('minutes'));
    my ($hour,   $hours)   = ($i18n->get ('hour'),   $i18n->get ('hours'));
    my ($day,    $days)    = ($i18n->get ('day'),    $i18n->get ('days'));
    my ($week,   $weeks)   = ($i18n->get ('week'),   $i18n->get ('weeks'));
    my ($month,  $months)  = ($i18n->get ('month'),  $i18n->get ('months'));

    my %reminderLabels = (0       => '----',
                          5       => "5  $minutes",
                          10      => "10 $minutes",
                          15      => "15 $minutes",
                          20      => "20 $minutes",
                          30      => "30 $minutes",
                          45      => "45 $minutes",
                          60      => "1 $hour",
                          120     => "2 $hours",
                          180     => "3 $hours",
                          360     => "6 $hours",
                          720     => "12 $hours",
                          1080    => "18 $hours",
                          1440    => "1 $day",
                          2880    => "2 $days",
                          1440*3  => "3 $days",
                          2880*2  => "4 $days",
                          1440*5  => "5 $days",
                          1440*6  => "6 $days",
                          1440*7  => "1 $week",
                          1440*8  => "8 $days",
                          1440*9  => "9 $days",
                          1440*10 => "10 $days",
                          1440*11 => "11 $days",
                          1440*12 => "12 $days",
                          1440*13 => "13 $days",
                          1440*14 => "2 $weeks");

    foreach (15..30) {
        push @reminderValues, 1440 * $_;
        $reminderLabels{1440*$_} = "$_ $days";
    }
    foreach (2..12) {
        push @reminderValues, 1440 * 30 * $_;
        $reminderLabels{1440 * 30 * $_} = "$_ $months";
    }
    return (\@reminderValues, \%reminderLabels);
}

sub delete_confirm {
    my ($class, %args) = @_;
    my $op    = $args{op};
    my $event = $args{event};
    my $delete_onclick;
    if (my $user = $op->getUser) {
        if (my $confirm = $user->confirm_delete) {
            if ($confirm eq 'all'
                or ($event->isRepeating and $confirm eq 'repeat')) {
                my $mess = $op->I18N->get ('Are you sure you want to '
                                           . "delete '%s'?");
                $mess = sprintf $mess, $event->text;
                $delete_onclick = qq (return confirm ("$mess"));
            }
        }
    }
    return $delete_onclick;
}

1;
