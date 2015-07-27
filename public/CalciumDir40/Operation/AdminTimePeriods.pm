# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

# Admin for Time Periods
package AdminTimePeriods;
use strict;
use CGI;

use Calendar::TableEditor;
use Calendar::Event;            # for getTimeString

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $cancel, $displayWhich) = $self->getParams (qw (Save Cancel
                                                               TimeEditWhich));
    my ($calName) = $self->calendarName;

    if ($cancel) {
        my $op = $calName ? 'AdminPage' : 'SysAdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $cgi   = CGI->new;
    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;
    my $masterPrefs;
    if ($calName) {
        $masterPrefs = MasterDB->new->getPreferences;
    } else {
        $masterPrefs = $prefs;
    }

    my $tzoffset = $prefs->Timezone || 0;
    my $message = '';

    my @columns = qw (TimePeriod StartTime EndTime Display);
    my $numAddRows = 3;
    my $wrapColor = 'maroon';

    if ($save) {
        $self->{audit_formsaved}++;
        my $tps = $prefs->getTimePeriods;
        my %nameToID;
        foreach my $id (keys %$tps) {
            $nameToID{$tps->{$id}->[0]} = $id;
        }

        my $ted = TableEditor::ParamParser->new (columns    => \@columns,
                                                 key        => 'TimePeriod',
                                                 numAddRows => $numAddRows,
                                                 params   => $self->rawParams);
        my @deletedKeys = $ted->getDeleted;
        my $rowHashes   = $ted->getRows;
        my $newRows     = $ted->getNewRows;

        foreach (@deletedKeys) {
            $prefs->deleteTimePeriod ($nameToID{$_});
        }

        while (my ($key, $vals) = each %$rowHashes) {
            my $start = $vals->{StartTime};
            my $end   = $vals->{EndTime};
            undef $start unless length $start;
            undef $end   unless length $end;
            $start = _normalizeTime ($start, $tzoffset) if (defined $start);
            $end   = _normalizeTime ($end, $tzoffset)   if (defined $end);
            if (!defined $start) {
                $message .= "$key: " . $i18n->get ('bad start time');
            } else {
                $end = '' unless defined $end;
                $prefs->setTimePeriod ($nameToID{$key},
                                       [$key, $start, $end, $vals->{Display}]);
            }
        }
        foreach my $rowHash (@$newRows) {
            my $key = $rowHash->{TimePeriod};
            next unless defined ($key);
            if ($prefs->getTimePeriodByName ($key)) {
                $message = "$key: " . $i18n->get ('already exists');
                next;
            }
            my $start = $rowHash->{StartTime};
            my $end   = $rowHash->{EndTime};
            $start = _normalizeTime ($start, $tzoffset) if (length $start);
            $end   = _normalizeTime ($end, $tzoffset)   if (length $end);
            if (!defined $start) {
                $message .= "$key: " . $i18n->get ('bad start time');
            } else {
                $end = '' unless defined $end;
                my $id = $prefs->newTimePeriod (name    => $key,
                                                start   => $start,
                                                end     => $end,
                                                display =>$rowHash->{Display});
            }
        }

        if ($ted->renamed) {
            my $oldName = $ted->renamedOldName;
            my $newName = $ted->renamedNewName;
            if (my $fail = $prefs->renameTimePeriod ($nameToID{$oldName},
                                                     $newName)) {
                if ($fail eq 'exists') {
                    $message .= $i18n->get ('Time Period already exists') .
                                ": '$newName'";
                } elsif ($fail eq 'notfound') {
                    $message .= $i18n->get ('Time Period not found') .
                                ": '$oldName'";
                } else {
                    $message .= $i18n->get ('Could not rename period.');
                }
            }
        }

        $prefs->TimeEditWhich ($displayWhich);
        $self->db->setPreferences ($prefs);
    }

    print GetHTML->startHTML (title  => $i18n->get ('Time Periods') . ': ' .
                                        ($calName ||
                                             $i18n->get ('System Defaults')),
                              op     => $self);
    if ($calName) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $calName,
                                    section => 'Time Periods');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Time Periods', 1);
    }

    print "<h3><center>$message</center></h3>" if $message;

    print '<br>';

    my %columnLabels = (TimePeriod => $i18n->get ('Period Name'),
                        StartTime  => $i18n->get ('Start Time'),
                        EndTime    => $i18n->get ('End Time'),
                        Display    => $i18n->get ('Display'));
    my %controlTypes  = (Display => 'popupMenu');
    my %controlParams = (Display =>
                           {values => [qw/times period both neither/],
                            labels => {times   => $i18n->get ('Times'),
                                       period  => $i18n->get ('Period Name'),
                                       both    => $i18n->get ('Both'),
                                       neither => $i18n->get ('Neither')}});

    my $mil = $prefs->MilitaryTime;
    my $sysTitle = $i18n->get ('System Defined Periods');
    my $wrapCount;              # if any times wrap past midnight

    # If we're in a calendar, first do System Periods table
    if ($calName) {
        my $ted = TableEditor->new (columns       => \@columns,
                                    key           => 'TimePeriod',
                                    columnLabels  => \%columnLabels,
                                    tableTitle   => $sysTitle,
                                    viewOnly      => 1,
                                   );

        my $sysPeriods = $masterPrefs->getTimePeriods;
        # sort by start time
        my @ids = sort {$sysPeriods->{$a}->[1] <=> $sysPeriods->{$b}->[1]}
                    keys %$sysPeriods;
        foreach my $id (@ids) {
            my $data = $sysPeriods->{$id};
            my $start = $data->[1] + (60 * $tzoffset);
            my $end   = length $data->[2] ? $data->[2] + (60 * $tzoffset)
                                          : undef;

            # Offset might move to next/previous day
            $start -= (24*60) if ($start >= 24*60);
            $end   -= (24*60) if (defined $end and $end >= 24*60);
            $start += (24*60) if ($start < 0);
            $end   += (24*60) if (defined $end and $end < 0);

            my $row = $ted->addRow (TimePeriod => $data->[0],
                                    StartTime  => Event->getTimeString ($start,
                                                                        $mil),
                                    EndTime    => defined $end ?
                                                   Event->getTimeString ($end,
                                                                         $mil)
                                                   : undef,
                                    Display    => $data->[3]);
            if (defined $end and $start > $end) {
                $row->setStyles (StartTime => "background-color: $wrapColor",
                                 EndTime   => "background-color: $wrapColor");
                $wrapCount++;
            }
        }
        print $ted->render;
        unless (@{$ted->rows}) {
            print '<center>-none defined-</center>';
        }
        print '<br><br>';
    }

    print $cgi->startform;

    # Now do table for this calendar (or just for system)
    my $tableTitle = $sysTitle;
    if ($calName) {
        $tableTitle = qq (Periods for This Calendar Only) . '<br><small>' .
                      qq (Note: you can override System Periods by adding
                          a local one with the same name.) . '</small>';
    }

    my $ted = TableEditor->new (columns       => \@columns,
                                key           => 'TimePeriod',
                                columnLabels  => \%columnLabels,
                                types         => \%controlTypes,
                                controlparams => \%controlParams,
#                                deleteLabel  => 'Delete Period?',
                                tableTitle    => $tableTitle,
                                numAddRows    => $numAddRows,
                               );
    my $periods = $self->prefs->getTimePeriods;

    # sort by start time
    my @ids = sort {$periods->{$a}->[1] <=> $periods->{$b}->[1]}
                  keys %$periods;
    my @names;
    foreach my $id (@ids) {
        my $data = $periods->{$id};
        push @names, $data->[0];
        my $start = $data->[1] + (60 * $tzoffset);
        my $end   = length $data->[2] ? $data->[2] + (60 * $tzoffset) : undef;

        # Offset might move to next/previous day
        $start -= (24*60) if ($start >= 24*60);
        $end   -= (24*60) if (defined $end and $end >= 24*60);
        $start += (24*60) if ($start < 0);
        $end   += (24*60) if (defined $end and $end < 0);

        my $row = $ted->addRow (TimePeriod => $data->[0],
                                StartTime  => Event->getTimeString ($start,
                                                                    $mil),
                                EndTime    => defined $end
                                                ? Event->getTimeString ($end,
                                                                        $mil)
                                                : undef,
                                Display    => $data->[3]);
#        if ($data->[1] > $data->[2]) {
        if (defined $end and $start > $end) {
            $row->setStyles (StartTime => "background-color: $wrapColor",
                             EndTime   => "background-color: $wrapColor");
            $wrapCount++;
        }
    }
    print $ted->render;

    my $help = $i18n->get ('AdminTimePeriods_HelpString_1');
    if ($help eq 'AdminTimePeriods_HelpString_1') {
        $help = qq {Time entry is flexible. You can use "7", "7:00", or
                    "7:00am" for 7 in the morning; "315pm", "3:15pm", "15",
                    "15:15" will all be recognized as quarter past three in
                    the afternoon.};
    }
    print qq (<blockquote><small><p>$help</p></small></blockquote>);

    if ($wrapCount) {
        print qq {<blockquote><small><p><b>Note:</b> Periods displayed with
                  <font color="$wrapColor">colored times</font> wrap past midnight</p></small>
                  </blockquote>}
    }

    print $ted->renderRenameRow (title => $i18n->get ("Rename a Time Period"),
                                 names => \@names);

    my $timeEditWhich;
    if ($calName) {
        print '<br>';
        $timeEditWhich = $prefs->TimeEditWhich || 'startend';
        my %labels = (startend => $i18n->get ('Start time, end time'),
                      period   => $i18n->get ('Defined time periods'),
                      both     => $i18n->get ('Both times and periods'),
                      none     => $i18n->get ('None - no time entry'));
        print '<div align="center">';
        print $i18n->get ('Display which "Time" Controls on Event Entry form');
        print ': ';
        print $cgi->popup_menu (-name     => 'TimeEditWhich',
                                -default  => $timeEditWhich,
                                -values   => [qw/startend period both none/],
                                -labels   => \%labels);
        print '</div>';
    }

    print '<hr>';
    print $cgi->submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print $cgi->reset  (-value => 'Reset');

    print $cgi->hidden (-name => 'Op',           -value => __PACKAGE__);
    print $cgi->hidden (-name => 'CalendarName', -value => $calName)
        if $calName;

    print $cgi->endform;

    if ($tzoffset) {
        my $hours = $tzoffset == 1 ? 'hour' : 'hours';
        print '<p><b>' . $i18n->get ('Note') . ': </b>';
        print $i18n->get ('Times reflect user offset') . ": $tzoffset " .
              $i18n->get ($hours);
        print '</p>';
    }

    if ($calName and $timeEditWhich !~ /period|both/i) {
        print '<p>';
        print '<span class="WarningHighlight">' . $i18n->get ('Note') . ': ' .
              '</span>';
        print $i18n->get ('Unless you change the display setting, ' .
                          'Time Periods will not appear on the ' .
                          'Event Entry Form');
        print '</p>';
    }

    print $cgi->end_html;
}

sub _normalizeTime {
    my ($raw, $tzoffset) = @_;
    return undef unless defined $raw;
    $raw =~ s/[^\dapm:]//ig;
    my $isPM = $raw =~ /pm/i;
    my $isAM = $raw =~ /am/i;
    my ($hour, $min) = split ':', $raw;
    $hour ||= 0; $min ||=0;
    $hour =~ s/[^\d]//g;
    $min  =~ s/[^\d]//g;
    $hour ||= 0; $min ||=0;
    if (length ($hour) == 4) {          # e.g. 1800
        $min  = substr ($hour, 2, 2);
        $hour = substr ($hour, 0, 2);
    } elsif (length ($hour) == 3) {     # e.g. 830
        $min  = substr ($hour, 1, 2);
        $hour = substr ($hour, 0, 1);
    }
    $hour  =  0 if ($isAM and $hour == 12);
    $hour += 12 if ($isPM and $hour < 12);
    $hour = 23 if $hour > 23;
    $min  = 59 if $min > 59;
    $tzoffset ||= 0;
    return ($hour - $tzoffset) * 60 + $min;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    $css .= $self->cssString ('.StartTimeInput',  {'text-align' => 'right'});
    $css .= $self->cssString ('.EndTimeInput',    {'text-align' => 'right'});
    return $css;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    return $line;
}

1;
