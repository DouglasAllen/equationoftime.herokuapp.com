# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# General Administration Options - conflicts, event owner only, description
package AdminGeneral;
use strict;

use CGI (':standard');

use Calendar::GetHTML;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL({Op => $op}));
        return;
    }

    my $cgi  = new CGI;
    my $i18n = $self->I18N;

    my @names = qw (language description conflict pastEdit future
                    noLastMinute maxDuration minDuration hideDetails
                    owner privacy multiAdd tentative remindable syncable
                    timezone refresh);

    my %captions = $self->_getCaptions;

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;
    my $message = $self->adminChecks;

    # Save if we're saving
    if (!$message and $save) {
        $override = 0;
        my (%newPrefs, %oldValues);
        foreach (qw (Language Description IsSyncable AutoRefresh
                     TimeConflicts TimeSeparation NoPastEditing
                     FutureLimit FutureLimitAmount FutureLimitUnits
                     NoLastMinute NoLastMinuteAmount
                     MaxDuration MaxDurationAmount
                     MinDuration MinDurationAmount
                     EventOwnerOnly PrivacyNoInclude PrivacyOwner HideDetails
                     MultiAddUsers MultiAddCals
                     TentativeSubmit TentativeViewers RemindersOn
                     DefaultTimezone)) {
            my $value = $self->{params}->{$_};
            $value = 0 if !defined ($value);

            # PrivacyNoInclude is special; actually opposite. Ug.
            if ($_ eq 'PrivacyNoInclude') {
                $value = !$value;
            }

            $newPrefs{$_} = $value;
            if ($value ne ($preferences->$_() || '')) {
                $oldValues{$_} = $preferences->$_();      # for auditing
            }
        }

        # If Syncability changed, clear LastSyncID
        if ($newPrefs{IsSyncable} ne ($oldValues{IsSyncable} || '')) {
            $newPrefs{LastRMSyncID} = 0;
        }

        # If group, remove prefs that were set to 'Ignore'
        my @modified;
        if ($self->isMultiCal) {
            my %prefMap = (language     => [qw /Language/],
                           description  => [qw /Description/],
                           conflict     => [qw /TimeConflicts TimeSeparation/],
                           pastEdit     => [qw /NoPastEditing/],
                           future       => [qw /FutureLimit FutureLimitAmount
                                                FutureLimitUnits/],
                           noLastMinute => [qw /NoListMinute
                                                NoListMinuteAmount/],
                           maxDuration  => [qw /MaxDuration MaxDurationAmount/],
                           minDuration  => [qw /MinDuration MinDurationAmount/],
                           owner        => [qw /EventOwnerOnly/],
                           hideDetails  => [qw /HideDetails/],
                           privacy      => [qw /PrivacyNoInclude PrivacyOwner/],
                           multiAdd     => [qw /MultiAddUsers MultiAddCals/],
                           tentative    => [qw /TentativeSubmit
                                                TentativeViewers/],
                           remindable   => [qw /RemindersOn/],
                           syncable     => [qw /IsSyncable/],
                           timezone     => [qw /DefaultTimezone/],
                           refresh      => [qw /AutoRefresh/]);

            @modified = $self->removeIgnoredPrefs (map   => \%prefMap,
                                                   prefs => \%newPrefs);

            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%captions);
        }

        foreach (@$calendars) {
            $self->saveForAuditing ($_, \%newPrefs);
            $self->dbByName ($_)->setPreferences (\%newPrefs);
        }
        $self->{audit_formsaved}++;
        $preferences = $self->prefs ('force');

        if ($newPrefs{Language}) {
            $self->{I18N} = undef;
            $i18n = $self->I18N;     # note it is *after* setting new language
            %captions = $self->_getCaptions;
        }
    }

    print GetHTML->startHTML (title  => $i18n->get ('General Settings'),
                              op     => $self);
    print '<center>';
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'General Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'General Settings');
    }
    print "<h3>$message</h3>" if $message;
    print '</center>';
    print '<br/>';

    # Get the prefs we've already got
    my $description    = $preferences->Description     || '';
    my $timeConflicts  = $preferences->TimeConflicts   || 'Allow';
    my $timeSeparation = $preferences->TimeSeparation  || 0;
    my $noPastEditing  = $preferences->NoPastEditing   || 0;
    my $futureLimit    = $preferences->FutureLimit;
    my $futureLimitAmount = ($preferences->FutureLimitAmount || 0) + 0;
    my $futureLimitUnits  = $preferences->FutureLimitUnits || 'months';
    my $noLastMinute       = $preferences->NoLastMinute;
    my $noLastMinuteAmount = ($preferences->NoLastMinuteAmount || 0) + 0;
    my $maxDuration       = $preferences->MaxDuration;
    my $maxDurationAmount = ($preferences->MaxDurationAmount || 0) + 0;
    my $minDuration       = $preferences->MinDuration;
    my $minDurationAmount = ($preferences->MinDurationAmount || 0) + 0;
    my $ownerOnly         = $preferences->EventOwnerOnly   || 0; # true/false
    my $hideDetails       = $preferences->HideDetails      || 0;
    my $multiAddUsers     = $preferences->MultiAddUsers    || 'nobody';
    my $multiAddCals      = $preferences->MultiAddCals     || 'permitted';
    my $tentative         = $preferences->TentativeSubmit  || 0; # true/false
    my $tentViewers       = $preferences->TentativeViewers || 'edit';
    my $isSyncable        = $preferences->IsSyncable       || 0;
    my $remindersOn       = $preferences->RemindersOn      || 0;
    my $timezone          = $preferences->DefaultTimezone  || 0;
    my $refresh           = $preferences->AutoRefresh      || 0;

    # Must use no_include since old versions didn't have it and we
    # want to default for 'include' to be on. Use opposite value for cbox
    my $privacy_no_include = $preferences->PrivacyNoInclude;
    my $privacy_owner      = $preferences->PrivacyOwner;

    my $conflictHelp = $i18n->get ('AdminGeneral_ConflictHelp');
    if ($conflictHelp eq 'AdminGeneral_ConflictHelp') {
        ($conflictHelp =<<'        FNORD') =~ s/^ +//gm;
        You can prevent entry of events that have time conflicts\n
        with existing events, or allow them to be entered.\n
        You may also allow entry of conflicting events, but\n
        display a warning.\n\n

        You can also specify a minimum separation time between\n
        events. For instance, if the separation is specified as\n
        20 minutes, two events would be considered to conflict\n
        if one started 15 minutes after the other ended.\n
        (Note that this setting will be ignored if\n
        Conflicting Events are Allowed.)
        FNORD
    }

    my $lastMinuteHelp = $i18n->get ('AdminGeneral_LastMinuteHelp');
    if ($lastMinuteHelp eq 'AdminGeneral_LastMinuteHelp') {
        ($lastMinuteHelp =<<'        FNORD') =~ s/^ +//gm;
        You can choose to prevent users from changing (or \n
        deleting) events that are scheduled for the near future.\n
        Or, you can choose to have a warning message displayed\n
        before the modification is accepted.\n\n

        Be sure to specify the number of hours in advance;\n
        e.g. if set to "24 hours", users won\'t be able to change\n
        events which occur within 1 day of the time the\n
        modification is submitted.\n\n
        (The number of hours setting is ignored if\n
        Last Minute Changes are Allowed.)
        FNORD
    }

    my $multiAddHelp = $i18n->get ('AdminGeneral_MultiAddHelp');
    if ($multiAddHelp eq 'AdminGeneral_MultiAddHelp') {
        ($multiAddHelp =<<'        ENDMULTIHELP') =~ s/^ +//gm;
        These settings specify whether or not the `Add to Which Calendars`\n
        control should appear on the Event Edit Form.\n\n
        You can specify which users will see it:\n
            \t\tNobody:         it will never appear\n
            \t\tCalendar Admin: only users with Admin permission in the 
                                calendar\n
            \t\tSystem Admins:  only users with System Admin permission\n
            \t\tAny User:       it will always appear\n\n
        You also specify which of the calendars that the\n
        user has Add permission in should appear in the list:\n
            \t\tIncluded:      only calendars included into this calendar\n
            \t\tIn Group:      only calendars in the current calendars group\n
            \t\tAll Permitted: All calendars for which the user has Add
                               permission\n
        ENDMULTIHELP
    }

    my $privacyHelp = $i18n->get ('AdminGeneral_PrivacyHelp');
    if ($privacyHelp eq 'AdminGeneral_PrivacyHelp') {
        ($privacyHelp =<<'        FNORD') =~ s/^ +//gm;
        These settings let you fine tune how event privacy\n
        is handled. If "when included" is selected,\n
        "private" events will not appear when viewing another\n
        calendar that includes events from this one.\n\n

        If "for this calendar" is selected, then when viewing\n
        this calendar, private events will appear only for the\n
        user who created them - no one else will see them.
        FNORD
    }

    print startform;

    # If group, allow selecting any calendar we have Admin permission for
    my $calSelector;
    my %onChange = ();
    if ($self->isMultiCal) {
        my $mess;
        ($calSelector, $mess) = $self->calendarSelector;
        print $mess if $mess;

        foreach (@names) {
            $onChange{$_} = $self->getOnChange ($_);
        }
    }

    my %rows;

    my %langHash = I18N->getLanguages;
    my $today = Date->new;
    my $example = $i18n->get ('Example') . ': "'
                       . $i18n->get ('Today is') . ': '
                       . $today->pretty ($i18n) . '"';
    my @langValues = sort {$langHash{$a} cmp $langHash{$b}} keys %langHash;
    $rows{language} = table (Tr (td (
                        popup_menu (-name    => 'Language',
                                    -default => $preferences->Language,
                                    -onChange => $onChange{language},
                                    -override => $override,
                                    -Values  => \@langValues,
                                    -labels  => {map {$_, $langHash{$_}}
                                                    sort keys %langHash})),
                                td ($example)));

    $rows{description} = table (Tr (td (table (Tr (
                td (table (Tr (td (textfield (-name     => 'Description',
                                              -default  => $description,
                                           -onChange => $onChange{description},
                                              -override => $override,
                                              -size  => 40)),
                               td (font ({size => -2},
                                         $i18n->get (
                                              'This is not displayed on the '.
                                              'calendar; it is used to '     .
                                              'describe the calendar in '    .
                                              'administration and calendar ' .
                                              'selection lists')))))))))));

    $rows{conflict} = table (
       Tr (td (table (Tr (td (popup_menu ('-name'    => 'TimeConflicts',
                                          '-default' => $timeConflicts,
                                          -onChange => $onChange{conflict},
                                          -override => $override,
                                          '-values'  => ['Allow', 'Prevent',
                                                         'Warn'],
                                          '-labels'  => {'Allow' =>
                                                          $i18n->get ('Allow'),
                                                         'Prevent' =>
                                                         $i18n->get
                                                             ("Don't Allow"),
                                                         'Warn' =>
                                                           $i18n->get ('Warn')}
                                                        )),
                          td ({align => 'right'}, '&nbsp;&nbsp;' .
                              $i18n->get ("Minimum Event Separation" . ': ')),
                          td ({align => 'left'},
                              popup_menu (-name    => 'TimeSeparation',
                                          -default => $timeSeparation,
                                          -onChange => $onChange{conflict},
                                          -override => $override,
                                          -Values  => [  0,  5, 10, 15, 20,
                                                        25, 30, 35, 40, 45,
                                                        50, 55, 60, 120,180])),
                          td ({align => 'left'},
                              $i18n->get ('minutes')),
                          td ('&nbsp;&nbsp;' .
                              a ({href =>
                                    "JavaScript:alert (\'$conflictHelp\')"},
                                 '<span class="HelpLink">?</span>')))))));

    $rows{pastEdit} = table (Tr (td (checkbox (-name    => 'NoPastEditing',
                                               -checked => $noPastEditing,
                                              -onChange => $onChange{pastEdit},
                                               -override => $override,
                                               -value   => 1,
                                               -label   => ' ' . $i18n->get (
                     'Prevent editing, deleting, or creating events for ' .
                     'dates before today.')))));

    $rows{future} = table (
       Tr (td (table (Tr (td (popup_menu ('-name'    => 'FutureLimit',
                                          '-default' => $futureLimit,
                                           -onChange => $onChange{future},
                                           -override => $override,
                                          '-values'  => ['Allow', 'Prevent',
                                                         'Warn'],
                                          '-labels'  => {'Allow' =>
                                                       $i18n->get ('No Limit'),
                                                         'Prevent' =>
                                                         $i18n->get
                                                           ('Enforce Limit'),
                                                         'Warn' =>
                                                         $i18n->get
                                                           ('Warn')}
                                                        )),
                          td ('&nbsp;&nbsp;' .
                              $i18n->get ("New events must be within") . ': '),
                          td (textfield (-name      => 'FutureLimitAmount',
                                         -default   => $futureLimitAmount,
                                         -onChange  => $onChange{future},
                                         -override => $override,
                                         -size      => 4,
                                         -maxlength => 3)),
                          td (popup_menu (-name    => 'FutureLimitUnits',
                                          -default => $futureLimitUnits,
                                          -onChange => $onChange{future},
                                          -override => $override,
                                          -Values  => [ 'day', 'week',
                                                        'month', 'year' ],
                                          -labels  => {
                                              day   => $i18n->get ('Day(s)'),
                                              week  => $i18n->get ('Week(s)'),
                                              month => $i18n->get ('Month(s)'),
                                              year  => $i18n->get ('Year(s)') }
                                         )),
                          td ($i18n->get ("of today's date.")))))));

    $rows{noLastMinute} =
           '<div style="margin: 5px;">'
           . popup_menu (-name     => 'NoLastMinute',
                         -default  => $noLastMinute,
                         -onChange => $onChange{noLastMinute},
                         -override => $override,
                         -values   => ['Allow', 'Prevent', 'Warn'],
                         -labels   => {'Allow' => $i18n->get ('Allow'),
                                       'Prevent' =>
                                              $i18n->get ("Don't Allow"),
                                       'Warn' => $i18n->get ('Warn')})
            . '&nbsp;&nbsp;'
            . $i18n->get ("No editing or deleting an event within")
            . ' '
            . textfield (-name      => 'NoLastMinuteAmount',
                         -default   => $noLastMinuteAmount,
                         -onChange  => $onChange{noLastMinute},
                         -override  => $override,
                         -size      => 3,
                         -maxlength => 3)
            . ' hours of its scheduled time.'
            . '&nbsp;&nbsp;'
            . a ({href => "JavaScript:alert (\'$lastMinuteHelp\')"},
                 '<span class="HelpLink">?</span>') . '</div>';

    $rows{maxDuration} =
           '<div style="margin: 5px;">'
           . popup_menu (-name     => 'MaxDuration',
                          -default  => $maxDuration,
                          -onChange => $onChange{maxDuration},
                          -override => $override,
                          -values   => ['Allow', 'Prevent', 'Warn'],
                          -labels   => {'Allow' => $i18n->get ('No Limit'),
                                        'Prevent' =>
                                              $i18n->get ('Enforce Limit'),
                                        'Warn' => $i18n->get ('Warn')})
            . '&nbsp;&nbsp;'
            . $i18n->get ("New events must be no longer than") . ' '
            . textfield (-name      => 'MaxDurationAmount',
                         -default   => $maxDurationAmount,
                         -onChange  => $onChange{maxDuration},
                         -override  => $override,
                         -size      => 4,
                         -maxlength => 3)
            . ' minutes</div>';

    $rows{minDuration} =
           '<div style="margin: 5px;">'
           . popup_menu (-name     => 'MinDuration',
                          -default  => $minDuration,
                          -onChange => $onChange{minDuration},
                          -override => $override,
                          -values   => ['Allow', 'Prevent', 'Warn'],
                          -labels   => {'Allow' => $i18n->get ('No Limit'),
                                        'Prevent' =>
                                              $i18n->get ('Enforce Limit'),
                                        'Warn' => $i18n->get ('Warn')})
            . '&nbsp;&nbsp;'
            . $i18n->get ("New events must be at least") . ' '
            . textfield (-name      => 'MinDurationAmount',
                         -default   => $minDurationAmount,
                         -onChange  => $onChange{minDuration},
                         -override  => $override,
                         -size      => 4,
                         -maxlength => 3)
            . ' minutes long</div>';

    $rows{owner} = table (Tr (td (checkbox (-name    => 'EventOwnerOnly',
                                            -checked => $ownerOnly,
                                            -onChange => $onChange{owner},
                                            -override => $override,
                                            -value   => 1,
                                            -label   => ' ' . $i18n->get (
                                                 'Permit only the creator ' .
                                                 'of an event to Edit '  .
                                                 'or Delete it')))));
    $rows{hideDetails} = table (Tr (td (checkbox (-name    => 'HideDetails',
                                            -checked => $hideDetails,
                                            -onChange => $onChange{hideDetails},
                                            -override => $override,
                                            -value   => 1,
                                            -label   => ' ' . $i18n->get (
                                                 'Allow only users with Edit ' .
'permission to see event popup window/details')))));
    $rows{privacy} = table (Tr (td ($i18n->get ('Apply:')),
                                td (checkbox (-name    => 'PrivacyNoInclude',
                                            -checked => !$privacy_no_include,
                                            -onChange => $onChange{privacy},
                                            -override => $override,
                                            -value   => 1,
                                            -label   => ' ' . $i18n->get (
                                                 'when included into other '  .
                                                 'calendars'))),
                                td ('&nbsp;'),
                                td (checkbox (-name    => 'PrivacyOwner',
                                            -checked => $privacy_owner,
                                            -onChange => $onChange{privacy},
                                            -override => $override,
                                            -value   => 1,
                                            -label   => ' ' . $i18n->get (
                                                 'for this calendar'))),
                                td ('&nbsp;' .
                                    a ({href =>
                                    "JavaScript:alert (\'$privacyHelp\')"},
                                       '<span class="HelpLink">?</span>'))));
    $rows{multiAdd} = table (Tr (
                          td ({align => 'right'},
                              $i18n->get ('Allow which users') . ':'),
                          td ({align => 'left'},
                              popup_menu ('-name'    => 'MultiAddUsers',
                                          '-default' => $multiAddUsers,
                                           -onChange => $onChange{multiAdd},
                                           -override => $override,
                                          '-values'  => ['nobody',
                                                         'caladmin',
                                                         'sysadmin',
                                                         'anyone'],
                                          '-labels'  => {'sysadmin' =>
                                             $i18n->get ('System Admins'),
                                                         'anyone' =>
                                             $i18n->get ("Any User"),
                                                         'caladmin' =>
                                             $i18n->get ("Calendar Admins"),
                                                         'nobody' =>
                                             $i18n->get ("Nobody")}
                                                        )),
                          td ({align => 'right'},
                              $i18n->get ("List which calendars") . ': '),
                          td ({align => 'left'},
                              popup_menu (-name    => 'MultiAddCals',
                                          -default => $multiAddCals,
                                          -onChange => $onChange{multiAdd},
                                          -override => $override,
                                          -Values  => ['included',
                                                       'ingroup',
                                                       'permitted'],
                                          -labels  => {permitted =>
                                                 $i18n->get ('All Permitted'),
                                                       ingroup   =>
                                                 $i18n->get ('In Group'),
                                                       included  =>
                                                 $i18n->get ('Included')})),
                          td ('&nbsp;&nbsp;' .
                              a ({href =>
                                  "JavaScript:alert (\'$multiAddHelp\')"},
                                 '<span class="HelpLink">?</span>'))));

    my $tent = 'Events added by unprivileged users will not appear until ' .
               'approved';
    my %viewLabels = (all        => $i18n->get ('All users'),
                      admin      => $i18n->get ('Users w/Admin permission'),
                      edit       => $i18n->get ('Users w/Edit permission'),
                    ownerAdmin => $i18n->get ('Event owner and users w/Admin'),
                    ownerEdit  => $i18n->get ('Event owner and users w/Edit'));
    $rows{tentative} = table (Tr (td ({-colspan => 2},
                                      checkbox (-name    => 'TentativeSubmit',
                                                -checked => $tentative,
                                             -onChange => $onChange{tentative},
                                                -override => $override,
                                                -value   => 1,
                                                -label   => ' ' .
                                                $i18n->get ($tent)))),
                    Tr (td ('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' .
                            $i18n->get ('Who can view unapproved events?')),
                        td (popup_menu (-name => 'TentativeViewers',
                                        -default  => $tentViewers,
                                        -onChange => $onChange{tentative},
                                        -override => $override,
                                        -Values   => ['edit', 'admin',
                                                      'ownerEdit',
                                                      'ownerAdmin', 'all'],
                                        -labels   => \%viewLabels))));

    $rows{syncable} = table (Tr (td (checkbox (-name    => 'IsSyncable',
                                               -checked => $isSyncable,
                                              -onChange => $onChange{syncable},
                                               -override => $override,
                                               -value   => 1,
                                               -label   => ' ' . $i18n->get (
                                                 'Allow Synchronizing with ' .
                                                 'TripleSync and Palm ' .
                                                 'Handhelds')))));
    my $disabled = '';
    if (!Defines->mailEnabled) {
        $disabled = '<i>' . $i18n->get ('Disabled in this version') . '</i>';
        $remindersOn = 0;
    }
    $rows{remindable} = table (Tr (td (checkbox (-name     => 'RemindersOn',
                                                 -checked  => $remindersOn,
                                            -onChange => $onChange{remindable},
                                                 -override => 1,
                                                 -value    => 1,
                                                 -label    => '')),
                                   td ($i18n->get
                                       ('Enable subscriptions for this '    .
                                        'calendar; anyone can sign up for ' .
                                        'event email reminders')),
                                   td ($disabled)));

    my $serverTime = time;
    my %labels;
    foreach (-23..23) {
        my @vals = localtime ($serverTime + $_ * 3600);
        my ($s, $m, $h, $w) = @vals[0,1,2,6];
        $labels{$_} = "$_ hours - " .
                       sprintf "%02d:%02d:%02d %s", $h, $m, $s,
                              '(' . $i18n->get (Date->dayName ($w, 'abbrev')) .
                              ')';
    }
    ($serverTime = $labels{0}) =~ s/^.*hours - //;
    $rows{timezone} = table (Tr (td ($i18n->get ('For Anonymous Users')),
                                 td (
                                     popup_menu (-name    => 'DefaultTimezone',
                                                 -default => $timezone,
                                              -onChange => $onChange{timezone},
                                                 -override => $override,
                                                 -Values  => [-23..23],
                                                 -labels  => \%labels)),
                                 td ('&nbsp;&nbsp;' .
                                     $i18n->get ('Server time:')),
                                 td ($serverTime)));

    my ($every, $minutes) = ($i18n->get ('every'), $i18n->get ('minutes'));
    %labels  = (0    => $i18n->get ('never'),
                60   => $i18n->get ('every minute'),
                120  => "$every 2 $minutes",
                180  => "$every 3 $minutes",
                300  => "$every 5 $minutes",
                600  => "$every 10 $minutes",
                900  => "$every 15 $minutes",
                1800 => "$every 30 $minutes",
                3600 => "$every " . $i18n->get ('hour'));
    $rows{refresh} = table (Tr (td (
                      $i18n->get ('Automatically reload the calendar ' .
                                  'display?')),
                                td (
                      popup_menu (-name    => 'AutoRefresh',
                                  -default => $refresh,
                                  -onChange => $onChange{refresh},
                                  -override => $override,
                                  -Values   => [0, 60, 120, 180, 300, 600,
                                                900, 1800, 3600],
                                  -labels   => \%labels))));

    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');
    my @rows;

    foreach (qw (language description                  SPACE
                 conflict pastEdit future noLastMinute SPACE
                 maxDuration minDuration               SPACE
                 owner hideDetails privacy tentative multiAdd      SPACE
                 remindable syncable timezone          SPACE
                 refresh)) {
        if (/SPACE/) {
            push @rows, Tr (td ('&nbsp;'));
            next;
        }
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
        push @rows, Tr ({-class => $thisRow},
                        $self->groupToggle (name => $_),
                        td ({align => 'right',
                             width => '22%',
                             class => 'caption'},
                            b ($captions{$_} . ': ')),
                        td ($rows{$_}));
    }

    print $calSelector if $calSelector;

    # Javascript for 'set all', 'ignore all'
    my ($setAlljs, $setAllRow) = $self->setAllJavascript;
    print $setAlljs;
    push @rows, Tr (td ({-align => 'center'}, $setAllRow)) if $setAllRow;

    print table ({class       => 'alternatingTable',
                  width       => '95%',
                  align       => 'center',
                  cellspacing => 0,
                  border      => 0},
                 @rows);

    print '<hr>';

    print submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset  (-value => $i18n->get ('Reset'));

    print $self->hiddenParams;

    print endform;
    print $self->helpNotes;
    print $cgi->end_html;
}

sub _getCaptions {
    my $self = shift;
    my $i18n = $self->I18N;
    return (description  => $i18n->get ('Description'),
            language     => $i18n->get ('Language'),
            conflict     => $i18n->get ('Time Conflicts'),
            pastEdit     => $i18n->get ('Past Event Protection'),
            future       => $i18n->get ('Future Event Limit'),
            noLastMinute => $i18n->get ('"Last Minute" Changes'),
            maxDuration  => $i18n->get ('Maximum Duration'),
            minDuration  => $i18n->get ('Minimum Duration'),
            owner        => $i18n->get ('Event Ownership'),
            hideDetails  => $i18n->get ('Hide Event Details'),
            privacy      => $i18n->get ('Event Privacy'),
            multiAdd     => $i18n->get ('Add to Multiple Calendars'),
            syncable     => $i18n->get ('Synching'),
            remindable   => $i18n->get ('Subscriptions'),
            tentative    => $i18n->get ('Require Approval'),
            timezone     => $i18n->get ('Default Timezone Offset'),
            refresh      => $i18n->get ('Automatic Refresh'));
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
