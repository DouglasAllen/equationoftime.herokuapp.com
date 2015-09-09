# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Options/Settings for Event Edit Form
package AdminEditForm;
use strict;

use CGI;

use Calendar::GetHTML;
use Calendar::Date;
use Calendar::EventEditForm;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $done) = $self->getParams (qw (Save Cancel Group));

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    if ($done) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op    => $op}));
        return;
    }

    my @names = qw (hideThese prompts timeEdit emailSelect
                    requireds
                    defText defPopup
                    defRepEdit defCategory defTimePeriod defBorder defPrivacy
                    defPeriod defSubsNotify defRemindTimes defRemindTo);

    my %captions = (hideThese     => $i18n->get ('Hide these'),
                    prompts       => $i18n->get ('Text prompts'),
                    timeEdit      => $i18n->get ('Time Controls'),
                    emailSelect   => $i18n->get ('Email Address Popup'),
                    requireds     => $i18n->get ('Mandatory Fields'),
                    defRepEdit    => $i18n->get ('Repeating Events'),
                    defText       => $i18n->get ('Event Text'),
                    defPopup      => $i18n->get ('Event Details'),
                    defCategory   => $i18n->get ('Category'),
                    defTimePeriod => $i18n->get ('Time Period'),
                    defBorder     => $i18n->get ('Draw Border'),
                    defPrivacy    => $i18n->get ('Event Privacy'),
                    defPeriod     => $i18n->get ('Repeat Period'),
                    defSubsNotify => $i18n->get ('Notify Subscribers'),
                    defRemindTimes => $i18n->get ('Reminder Times'),
                    defRemindTo   => $i18n->get ('Reminder "To"'));

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;

    my %defPrompts = (TextNew  => $i18n->get ('Enter text for a new event:'),
                      TextEdit => $i18n->get ('Modify the text for this ' .
                                              'event:'),
                      Details  => $i18n->get ('Enter a URL, or text for a ' .
                                              'popup window:'),
                      SubDetails => $i18n->get ('Anything starting with '    .
                                                'http:, https:, mailto:, '    .
                                                'ftp:, file:, or a \'www\' '  .
                                                'string (e.g. '               .
                                                '<i>www.domainname.com</i>) ' .
                                                'will be a link. Anything '   .
                                                'else will be popup text.'),
                      Category => $i18n->get ('Category'),
                      MoreCats => $i18n->get ('More Categories'));

    my $message = $self->adminChecks;
    if (!$message and $save) {
        $override = 0;
        my @thePrefs = qw (RepeatEditWhich TimeEditWhich EmailSelector
                           EventPrivacy DefaultCategory DefaultBorder
                           DefaultTimePeriod DefaultPeriod DefaultSubsNotify
                           DefaultRemindTo DefaultText DefaultPopup);
        my %newPrefs;
        foreach (@thePrefs) {
            my $value = $self->{params}->{$_};
            $value =~ s/^\s+//;     # strip leading/trailing whitespace
            $value =~ s/\s+$//;
            $newPrefs{$_} = $value if (defined $value);
        }

        # Default Reminder Times are a bit special
        my @remind_times = ($self->{params}->{DefaultRemindTimes1},
                            $self->{params}->{DefaultRemindTimes2});
        $newPrefs{DefaultRemindTimes} = join ' ', grep {$_ > 0} @remind_times;

        # Edit Form stuff is a little special
        my $hideThem;
        my @hides;
        foreach (qw (Summary Details Category MoreCats WhenInc Colors Border
                     Repeat Mail)) {
            push @hides, lc ($_)
                if $self->{params}->{'Hide' . $_}
        }
        $newPrefs{EditFormHide} = join ',', @hides;

        # Required Fields is a little special too
        my @reqs;
        foreach (qw (Category Details Time)) {
            push @reqs, lc ($_)
                if $self->{params}->{"Required-$_"};
        }
        $newPrefs{RequiredFields} = join ',', @reqs;

        # And so are the prompts
        my @prompts;
        foreach (qw (TextNew TextEdit Details SubDetails Category MoreCats)) {
            my $val = $self->{params}->{"Prompt-$_"};
            $val = undef if ($val =~ /^\s*$/);
            next if (!$val or $val eq $defPrompts{$_});
            $val =~ s/ ;; / ; /g; # hack to make storing easier.
            push @prompts, ($_, $val);
        }
        $newPrefs{EditFormPrompts} = join ' ;; ', @prompts;

        # If multi-cal, remove prefs set to Ignore
        if ($self->isMultiCal) {
            my %prefMap = (hideThese     => [qw /EditFormHide/],
                           prompts       => [qw /EditFormPrompts/],
                           timeEdit      => [qw /TimeEditWhich/],
                           emailSelect   => [qw /EmailSelector/],
                           requireds     => [qw /RequiredFields/],
                           defRepEdit    => [qw /RepeatEditWhich/],
                           defText       => [qw /DefaultText/],
                           defPopup      => [qw /DefaultPopup/],
                           defCategory   => [qw /DefaultCategory/],
                           defTimePeriod => [qw /DefaultTimePeriod/],
                           defBorder     => [qw /DefaultBorder/],
                           defPrivacy    => [qw /EventPrivacy/],
                           defPeriod     => [qw /DefaultPeriod/],
                           defSubsNotify => [qw /DefaultSubsNotify/],
                           defRemindTimes => [qw /DefaultRemindTimes/],
                           defRemindTo   => [qw /DefaultRemindTo/],
                          );

            my @modified = $self->removeIgnoredPrefs (map   => \%prefMap,
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
    }

    # Get the prefs we've already got
    my $hideThem       = $preferences->EditFormHide  || '';
    my $prompts        = $preferences->EditFormPrompts  || '';
    my $popupExport    = $preferences->PopupExportOn   || 0; #true/false
    my $repeatEdit     = $preferences->RepeatEditWhich || 'All';
    my $emailSelect    = $preferences->EmailSelector   || 'all';
    my $requiredFields = $preferences->RequiredFields  || '';
    my $timeEditWhich  = $preferences->TimeEditWhich   || 'startend';
    my $defText        = $preferences->DefaultText     || '';
    my $defPopup       = $preferences->DefaultPopup     || '';
    my $defCategory    = $preferences->DefaultCategory;
    my $defTimePeriod  = $preferences->DefaultTimePeriod;
    my $defBorder      = $preferences->DefaultBorder   || 0;
    my $defPrivacy     = $preferences->EventPrivacy    || 'public';
    my $defPeriod      = $preferences->DefaultPeriod   || 'day';
    my $defSubsNotify  = $preferences->DefaultSubsNotify || 0;
    my $defRemindTimes = $preferences->DefaultRemindTimes || '';
    my $defRemindTo    = $preferences->DefaultRemindTo || '';

    my @def_remind_times = sort split /\s/, $defRemindTimes;

    my %prompts = split ' ;; ', $prompts;
    foreach (keys %defPrompts) {
        $prompts{$_} ||= $defPrompts{$_};
    }

    my %hideThese = (Repeat   => ($hideThem =~ /repeat/i)   || 0,
                     Mail     => ($hideThem =~ /mail/i)     || 0,
                     Summary  => ($hideThem =~ /summary/i)  || 0,
                     Details  => ($hideThem =~ /details/i)  || 0,
                     Category => ($hideThem =~ /category/i) || 0,
                     MoreCats => ($hideThem =~ /moreCats/i) || 0,
                     WhenInc  => ($hideThem =~ /whenInc/i)  || 0,
                     Colors   => ($hideThem =~ /colors/i)   || 0,
                     Border   => ($hideThem =~ /border/i)   || 0);

    my %isRequired;
    foreach (split ',', $requiredFields) {
        $isRequired{lc ($_)}++;
    }

    # Check for bad scenes
    my @warnings;
    if ($isRequired{category} and $hideThese{Category}) {
        push @warnings, $i18n->get ('"Category" is required, but its ' .
                                    'control is hidden.');
    }
        if ($isRequired{details} and $hideThese{Details}) {
        push @warnings, $i18n->get ('"Popup/Link" is required, but its ' .
                                    'control is hidden.');
    }
        if ($isRequired{time} and (lc $timeEditWhich) eq 'none') {
        push @warnings, $i18n->get ('"Time" is required, but its ' .
                                    'control is hidden.');
        $message .= $i18n->get ('"Time" field is required, but the controls ' .
                                'for entering it are not displayed!');
    }
    if (@warnings) {
        $message &&= '<br>';
        $message .= '<span class="ErrorHighlight">' . $i18n->get ('Warning') .
                    ':</span> ';
        $message .= join '<br>', @warnings;
    }

    print GetHTML->startHTML (title  => $i18n->get('Event Edit Form Settings'),
                              op     => $self);
    print '<center>';
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Event Edit Form Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Event Edit Form Settings');
    }
    print "<h3>$message</h3>" if $message;
    print '</center>';

    print $cgi->startform;

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

    my %hideLabs = (Repeat   => 'Repeat Controls',
                    Mail     => 'Email Controls',
                    Details  => 'Popup/Link',
                    Summary  => 'Event Text',
                    Category => 'Category',
                    MoreCats => 'More Categories',
                    WhenInc  => 'When Included',
                    Colors   => 'Colors',
                    Border   => 'Border');
    my @checks;
    foreach (qw /Summary Details Category MoreCats WhenInc Colors Border
                 Repeat Mail/) {
        push @checks, $cgi->checkbox (-name     => 'Hide' . $_,
                                      -checked  => $hideThese{$_},
                                      -onChange => $onChange{hideThese},
                                      -override => $override,
                                      -label    => $i18n->get ($hideLabs{$_}));
    }
    @checks = map {"<nobr>$_</nobr>"} @checks;
    my $summary_check = shift @checks;

    # If any custom fields are defined, give option to hide Event Summary
    my $fields_lr = $self->prefs->get_custom_fields (system => undef);
    my $first_row;
    if (@$fields_lr) {
        my $note = '&nbsp;&nbsp;<i>'
                   . $i18n->get ('If checked, make sure one of your custom '
                                 . 'fields will be displayed')
                   . '</i>';
        $first_row = $cgi->Tr ($cgi->td ({colspan => 4},
                                         $summary_check . $note));
    }

    $rows{hideThese} = $cgi->table ($first_row,
                                    $cgi->Tr ($cgi->td ([@checks[0..3]])),
                                    $cgi->Tr ($cgi->td ([@checks[4..7]])));


    my %pFields;
    foreach (qw /TextNew TextEdit Details SubDetails Category MoreCats/) {
        $pFields{$_} = $cgi->textfield (-name     => "Prompt-$_",
                                        -default  => $prompts{$_},
                                        -onChange => $onChange{prompts},
                                        -override => 1,
                                        -size     => 40);
    }
    $rows{prompts} = $cgi->table ({-cellpadding => 2},
                      $cgi->Tr ($cgi->td ('Text <i>(new event)</i>: '),
                                $cgi->td ($pFields{TextNew})),
                      $cgi->Tr ($cgi->td ('Text <i>(edit event)</i>: '),
                                $cgi->td ($pFields{TextEdit})),
                      $cgi->Tr ($cgi->td ('Details: '),
                                $cgi->td ($pFields{Details})),
                      $cgi->Tr ($cgi->td ('Details <i>(below)</i>: '),
                                $cgi->td ($pFields{SubDetails})),
                      $cgi->Tr ($cgi->td ('Category: '),
                                $cgi->td ($pFields{Category})),
                      $cgi->Tr ($cgi->td ('More Categories: '),
                                $cgi->td ($pFields{MoreCats})),
                      $cgi->Tr ($cgi->td ({-colspan => 2, -align => 'center'},
                                      '<span class="InlineHelp">' .
                                       $i18n->get ('leave a prompt blank ' .
                                                   'to restore the default') .
                                      '</span>')));

    my %labels = (startend => $i18n->get ('Start time, end time'),
                  period   => $i18n->get ('Defined time periods'),
                  both     => $i18n->get ('Both times and periods'),
                  none     => $i18n->get ('None - no time entry'));
    $rows{timeEdit} = $cgi->table ({-cellpadding => 4}, $cgi->Tr ($cgi->td (
                      $cgi->popup_menu (-name     => 'TimeEditWhich',
                                        -default  => $timeEditWhich,
                                        -onChange => $onChange{timeEdit},
                                        -override => $override,
                                        -values   => [qw/startend period
                                                         both none/],
                                        -labels   => \%labels)),
                      $cgi->td (
                          $i18n->get ('Display which "Time" Controls'))));

    %labels = (none    => $i18n->get ("Don't display"),
               aliases => $i18n->get ('Email aliases only'),
               users   => $i18n->get ('User names only'),
               all     => $i18n->get ('Aliases and User names'));
    $rows{emailSelect} = $cgi->table ({-cellpadding => 4},
                                      $cgi->Tr ($cgi->td (
                          $cgi->popup_menu (-name     => 'EmailSelector',
                                            -default  => $emailSelect,
                                            -onChange =>
                                               $onChange{emailSelect},
                                            -override => $override,
                                            -values   => [qw /none all aliases
                                                            users/],
                                            -labels   => \%labels)),
                                       $cgi->td (
                                        $i18n->get ('Email Address Selector ' .
                                                    'on Event Edit Form'))));

    $rows{requireds} = '&nbsp;&nbsp;&nbsp;&nbsp;' .
                       $cgi->checkbox (-name => 'Required-Category',
                                       -checked => $isRequired{category},
                                       -onChange => $onChange{requireds},
                                       -override => $override,
                                       -label    => $i18n->get ('Category')) .
                       '&nbsp;&nbsp;&nbsp;&nbsp;' .
                       $cgi->checkbox (-name => 'Required-Details',
                                       -checked => $isRequired{details},
                                       -onChange => $onChange{requireds},
                                       -override => $override,
                                       -label   => $i18n->get ('Popup/Link')) .
                       '&nbsp;&nbsp;&nbsp;&nbsp;' .
                       $cgi->checkbox (-name => 'Required-Time',
                                       -checked => $isRequired{time},
                                       -onChange => $onChange{requireds},
                                       -override => $override,
                                       -label   => $i18n->get ('Time'));
    $rows{requireds} = qq {<div style="margin: 5px">$rows{requireds}</div>};


    %labels = (All  => '"' . $i18n->get ('All') . '"',
               Only => '"' . $i18n->get ('Only This Instance') . '"',
               Past   => '"' . $i18n->get ('This date, and all before') . '"',
               Future => '"' . $i18n->get ('This date, and all after') . '"',
              );
    $rows{defRepEdit} = $cgi->table ({-cellpadding => 4},
                               $cgi->Tr ($cgi->td (
                         $cgi->popup_menu (-name => 'RepeatEditWhich',
                                           -default  => $repeatEdit,
                                           -onChange => $onChange{defRepEdit},
                                           -override => $override,
                                           -values   => [qw/All Only Past
                                                            Future/],
                                           -labels   => \%labels)),
                         $cgi->td ($i18n->get ('Default for editing or ' .
                                               'deleting repeating events'))));
    $rows{defSubsNotify} =
        $cgi->table ({-cellpadding => 4},
           $cgi->Tr ($cgi->td (
              $cgi->radio_group (-name     => 'DefaultSubsNotify',
                                 -default  => $defSubsNotify,
                                 -onChange => $onChange{defSubsNotify},
                                 -override => $override,
                                 -values   => [qw /0 1/],
                               -labels   => {0 => $i18n->get ("Don't Notify"),
                                             1 => $i18n->get ('Notify')}))));

    my ($values, $labels) = EventEditForm->reminder_values_and_labels ($i18n);
    $rows{defRemindTimes} =
        $cgi->table ({-cellpadding => 4},
           $cgi->Tr ($cgi->td (
              $cgi->popup_menu (-name     => 'DefaultRemindTimes1',
                                -default  => $def_remind_times[0],
                                -onChange => $onChange{defRemindTimes},
                                -override => $override,
                                -values   => $values,
                                -labels   => $labels)
                              . $i18n->get ('before, and')),
                     $cgi->td (
              $cgi->popup_menu (-name     => 'DefaultRemindTimes2',
                                -default  => $def_remind_times[1],
                                -onChange => $onChange{defRemindTimes},
                                -override => $override,
                                -values   => $values,
                                -labels   => $labels)
                               . $i18n->get ('before the event'))));

    $rows{defRemindTo} = 
        $cgi->table ({-cellpadding => 4},
           $cgi->Tr ($cgi->td (
                          $cgi->textfield (-name     => 'DefaultRemindTo',
                                          -default  => $defRemindTo,
                                          -onChange => $onChange{defRemindTo},
                                          -override => $override,
                                          -size     => 25)
                         . ' <small>'
                         . $i18n->get ('if blank, will use email address of '
                                       . 'the user adding the event')
                         . '</small>')));

    my @categories = sort {lc ($a) cmp lc ($b)}
                          keys %{$preferences->getCategories ('inherit')};
    unshift @categories, ' - ';
    $rows{defCategory} =
        $cgi->table ({-cellpadding => 4},
                     $cgi->Tr ($cgi->td (
                         $cgi->popup_menu (-name     => 'DefaultCategory',
                                           -default  => $defCategory,
                                           -onChange => $onChange{defCategory},
                                           -override => $override,
                                           -values   => \@categories))));

    $rows{defText} =
        $cgi->table ({-cellpadding => 4},
                     $cgi->Tr ($cgi->td (
                         $cgi->textarea (-name     => 'DefaultText',
                                         -default  => $defText,
                                         -onChange => $onChange{defText},
                                         -override => $override,
                                         -rows     => 2,
                                         -columns  => 35,
                                         -wrap     => 'SOFT'))));

    $rows{defPopup} =
        $cgi->table ({-cellpadding => 4},
                     $cgi->Tr ($cgi->td (
                         $cgi->textarea (-name     => 'DefaultPopup',
                                         -default  => $defPopup,
                                         -onChange => $onChange{defPopup},
                                         -override => $override,
                                         -rows     => 4,
                                         -columns  => 60,
                                         -wrap     => 'SOFT'))));

    my $periods = $preferences->getTimePeriods ('inherit'); # master too
    # Sort on start time; periods are IDs, labels are names
    my @timePeriods = sort {$periods->{$a}->[1] <=> $periods->{$b}->[1]}
                         keys %$periods;
    %labels = map {$_ => $periods->{$_}->[0]} @timePeriods;
    unshift @timePeriods, '-';
    $rows{defTimePeriod} =
        $cgi->table ({-cellpadding => 4},
                     $cgi->Tr ($cgi->td (
                         $cgi->popup_menu (-name     => 'DefaultTimePeriod',
                                           -default  => $defTimePeriod,
                                           -onChange =>
                                                      $onChange{defTimePeriod},
                                           -override => $override,
                                           -values   => \@timePeriods,
                                           -labels   => \%labels))));

    $rows{defBorder} =
        $cgi->table ({-cellpadding => 4},
                     $cgi->Tr ($cgi->td (
                         $cgi->radio_group (-name     => 'DefaultBorder',
                                            -default  => $defBorder,
                                            -onChange => $onChange{defBorder},
                                            -override => $override,
                                            -values   => [qw /0 1/],
                                            -labels   =>
                                               {0 => $i18n->get ('Off'),
                                                1 => $i18n->get ('On')}))));

    %labels = (public      => $i18n->get ("Display this event"),
               private     => $i18n->get ("Don't display this event"),
               nopopup     => $i18n->get ("Display event text, but not Popup"),
               unavailable => $i18n->get ("Display 'Unavailable'"),
               outofoffice => $i18n->get ("Display 'Out of Office'"));

    $rows{defPrivacy} = $cgi->table ({-cellpadding => 4},
                             $cgi->Tr ($cgi->td (
                         $cgi->popup_menu (-name     => 'EventPrivacy',
                                           -default  => $defPrivacy,
                                           -onChange => $onChange{defPrivacy},
                                           -override => $override,
                                           -values   => [qw /public private
                                                             nopopup
                                                             unavailable
                                                             outofoffice/],
                                           -labels  => \%labels)),
                          $cgi->td ($i18n->get ('Default for "When included' .
                                                ' in other calendars"'))));

    %labels = (day       => $i18n->get ('Day'),
               dayBanner => $i18n->get ('Day (Bannered)'),
               week      => $i18n->get ('Week'),
               month     => $i18n->get ('Month'),
               year      => $i18n->get ('Year'));
    $rows{defPeriod} = $cgi->table ({-cellpadding => 4},
                             $cgi->Tr ($cgi->td (
                        $cgi->popup_menu (-name     => 'DefaultPeriod',
                                          -default  => $defPeriod,
                                          -onChange => $onChange{defPeriod},
                                          -override => $override,
                                          -values   => [qw /day dayBanner
                                                            week month year/],
                                          -labels   => \%labels)),
                         $cgi->td ($i18n->get ('Default for repeating ' .
                                               'events; ') .
                                     $i18n->get
                       ('"Bannered" means the event will display spread out ' .
                        'across the days it repeats on.'))));

    my $bgcolor = '#dddddd';
    my $bg2     = '#eeeeee';

    my @rows;

    my %sectionLabels = (display  => $i18n->get ('How the Form Looks'),
                         required => $i18n->get ('Required Fields for Events'),
                         default  => $i18n->get ('Default Values for New ' .
                                                 'Events'));

    # could use @names, but display order might be differmint
    foreach (qw (LABEL-display hideThese timeEdit emailSelect prompts SPACE
                 LABEL-required requireds SPACE
                 LABEL-default defText defPopup
                               defCategory defTimePeriod defBorder defPrivacy
                               defPeriod defRepEdit defSubsNotify
                               defRemindTimes defRemindTo)) {
        if (/SPACE/) {
            push @rows, $cgi->Tr ($cgi->td ('&nbsp;'));
            next;
        }

        if (/LABEL-(.*)/) {
            push @rows, $cgi->Tr ($cgi->td ({-colspan => 2},
                                            "<b>$sectionLabels{$1}</b>"));
            next;
        }

        ($bgcolor, $bg2) = ($bg2, $bgcolor);
        push @rows, $cgi->Tr ({bgcolor => '#cdcdcd'},
                      $self->groupToggle (name  => $_),
                      $cgi->td ({align   => 'right',
                                 bgcolor => '#cdcdcd',
                                 width   => '22%'},
                        $cgi->b ('<nobr>' . $captions{$_} . ': ' . '</nobr>')),
                        $cgi->td ({bgcolor => $bgcolor}, $rows{$_}));
    }

    print $calSelector if $calSelector;

    my ($setAlljs, $setAllRow) = $self->setAllJavascript;
    print $setAlljs;
    push @rows, $cgi->Tr ($cgi->td ({-align => 'center'}, $setAllRow))
        if $setAllRow;

    print '<br>';
    print $cgi->table ({width       => '90%',
                        align       => 'center',
                        cellspacing => 0,
                        border      => 0},
                       @rows);

    print '<hr>';

    print $cgi->submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print $cgi->reset  (-value => 'Reset');

    print $self->hiddenParams;
    print $cgi->endform;
    print $self->helpNotes;
    print $cgi->end_html;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
