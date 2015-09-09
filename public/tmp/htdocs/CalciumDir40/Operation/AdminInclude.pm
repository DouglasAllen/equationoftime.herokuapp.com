# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Admin for Including from Other Calendars
package AdminInclude;
use strict;
use CGI (qw (:standard *table));

use Calendar::GetHTML;
use Calendar::Javascript;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;
    my $cgi = new CGI;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));
    my $calName = $self->calendarName;

    if ($self->isSystemOp) {         # just in case
        GetHTML->errorPage ($i18n,
                            header => $i18n->get ('No Calendar Specified'),
                            message => 'This operation requires a calendar!');
        return;
    }

    if ($cancel) {
        print $self->redir ($self->makeURL({Op => 'AdminPage'}));
        return;
    }

    my ($displayAll) = $self->getParams ('DisplayAll');

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $over = 1;
    my $message = $self->adminChecks;

    my @calendars;
    if ($displayAll) {
        @calendars = MasterDB->getAllCalendars();
    } else {
        if ($self->isMultiCal) {
            @calendars = @{$self->relevantCalendars};
        } else {
            my @groups = $preferences->getGroups;
            my ($matchList, $noGroup) =
                                       MasterDB->getCalendarsInGroup (@groups);
            @calendars = (@$matchList, @$noGroup);
        }
    }

    if (!$message and $save) {
        $self->{audit_formsaved}++;
        $over = 0;

        my %newInfo;
        # If a param starts with INCLUDE-, it's an included calendar
        foreach my $param (keys %{$self->{params}}) {
            next unless ($param =~ /^INCLUDE-FG-(.*)/); # FG always there
            my $name  = $1;

            if ($self->isMultiCal) {
                my $n = $self->getOnChangeName ($name);
                next if $self->{params}->{$n} eq 'ignore';
            }

            # checkbox params for this included cal
            foreach my $field (qw /Included Override Border/) {
                my $param = "INCLUDE-$field-$name";
                my $val = $self->{params}->{$param} || '';
                $newInfo{$name}{$field} = ($val eq 'on');
            }

            # text params for this included cal
            foreach my $field (qw /FG BG Text/) {
                my $param = "INCLUDE-$field-$name";
                ($newInfo{$name}{$field} =
                                 $self->{params}->{$param}) =~ s/\s+$//;
                $newInfo{$name}{$field} =~ s/^\s+//;
            }

            my @cats = $cgi->param ("INCLUDE-Categories-$name");
            $newInfo{$name}{Categories} = \@cats;

        }

        # Set prefs for each specified calendar
        foreach my $cal (@$calendars) {
            my $thePrefs = Preferences->new ($self->dbByName ($cal));
            my $incInfo = $thePrefs->Includes;
            my %orig;
            foreach (keys %newInfo) {
                # if ourselves, or not ignored and unselected, remove it
#                 if (($_ eq $cal) or
#                     ($newInfo{$_} and !$newInfo{$_}{Included})) {
#                     delete $incInfo->{$_};

                if (($_ eq $cal)) {
                    delete $incInfo->{$_};
                }
                elsif ($newInfo{$_} and !$newInfo{$_}{Included}) {
                    my %was = %{$incInfo->{$_} || {Included => 0}}; # copy it
                    $orig{$_} = \%was;
                    delete $incInfo->{$_};

                } else {
                    my %was = %{$incInfo->{$_} || {}}; # copy it
                    $orig{$_} = \%was;
                    $incInfo->{$_} = $newInfo{$_};
                }
            }
            $self->dbByName ($cal)->setPreferences ({Includes => $incInfo});
            $message = $self->getModifyMessage (cals => $calendars,
                                                mods => [keys %newInfo]);
            $self->{audit_info}->{$cal} = \%orig;
        }
        $self->{audit_formsaved}++;
        $preferences = Preferences->new ($calendars->[0]); # re-get
    }

    my $incInfo = $preferences->Includes;

    print GetHTML->startHTML (title  => $i18n->get ('Dynamic Include'),
                              op     => $self);
    print GetHTML->AdminHeader (I18N    => $i18n,
                                cal     => $self->calendarName || '',
                                goob    => $self->goobLabel    || '',
                                group   => $self->groupName    || '',
                                section => 'Dynamic Include');
    print '<br>';
    print "<center><h3>$message</h3></center>" if $message;

    print startform;

    # If group, allow selecting any calendar we have Admin permission for
    if ($self->isMultiCal) {
        my ($calSelector, $message) = $self->calendarSelector;
        print $message if $message;
        print $calSelector if $calSelector;
    }

    print $i18n->get ('Select which calendars you would like to include. ' .
                      'Only calendars which you have permission to view ' .
                      'are listed.') . '<br>';

    print '<center>(';
    if ($displayAll) {
        print $i18n->get ('Listing all calendars; press to') . '&nbsp;';
        print submit (-name  => 'DisplayOnlyGroup',
                      -value => $i18n->get ('list only group calendars'));
    } else {
        print $i18n->get ('Listing only group calendars; press to') . '&nbsp;';
        print submit (-name  => 'DisplayAll',
                      -value => $i18n->get ('list all'));
    }
    print ')</center>';

    # First, delete any cal out of the preference list that don't exist on
    # disk anymore
    foreach my $included (keys %$incInfo) {
        next if ($included =~ /^ADDIN (.*)/);
        delete $incInfo->{$included} unless (grep /$included/, @calendars);
    }

    my ($rowBGcolor, $rowBG2);
    $rowBGcolor = '#cccccc';
    $rowBG2     = '#eeeeee';

    my @sysCats = MasterDB->new->getPreferences->getCategoryNames;

    my @tableRows;
    foreach my $name (sort {lc($a) cmp lc($b)} @calendars) {
        next if ($name eq ($calName || ''));

        my $db = Database->new ($name);

        # See if we've got permission to include this guy
        my $perms = Permissions->new ($db);
        next unless $perms->permitted ($self->getUsername, 'View');

        my $onChange = $self->isMultiCal ? $self->getOnChange ($name) : '';

        my ($override, $includeCB, $overrideCB, $fgField, $bgField,
            $borderCB, $textField, $border, $fgColor, $bgColor, $text, $incP,
            $categories, $cats);
        if (defined $incInfo->{$name}) {
            $incP     = $incInfo->{$name}{'Included'};
            $cats     = $incInfo->{$name}{'Categories'};    # listref
            $override = $incInfo->{$name}{'Override'};
            $border   = $incInfo->{$name}{'Border'};
            $fgColor  = $incInfo->{$name}{'FG'}   || '';
            $bgColor  = $incInfo->{$name}{'BG'}   || '';
            $text     = $incInfo->{$name}{'Text'} || '';
        } else {
            $incP = $cats = $override = $border = $text = '';
            $fgColor = 'black';
            $bgColor = 'white';
        }

        my @theseCats = $db->getPreferences->getCategoryNames;

        my %catNames = map {$_ => 1} (@sysCats, @theseCats);
        my @allCats = sort {lc($a) cmp lc($b)} keys %catNames;
        push @allCats, '<- - - ->';

        $includeCB  = checkbox (-name    => "INCLUDE-Included-$name",
                                -checked => $incP,
                                -onChange => $onChange,
                                -override => $over,
                                -label   => " $name");
        $overrideCB = checkbox (-name    => "INCLUDE-Override-$name",
                                -checked => $override,
                                -onChange => $onChange,
                                -override => $over,
                                -label   => '');
        $borderCB   = checkbox (-name    => "INCLUDE-Border-$name",
                                -checked => $border,
                                -onChange => $onChange,
                                -override => $over,
                                -label   => '');
        $fgField    = textfield (-name      => "INCLUDE-FG-$name",
                                 -default   => $fgColor,
                                 -onChange  => $onChange,
                                 -override  => $over,
                                 -size      => 8,
                                 -maxlength => 20);
        $bgField    = textfield (-name      => "INCLUDE-BG-$name",
                                 -default   => $bgColor,
                                 -onChange  => $onChange,
                                 -override  => $over,
                                 -size      => 8,
                                 -maxlength => 20);
        $textField  = textfield (-name      => "INCLUDE-Text-$name",
                                 -default   => $text,
                                 -onChange  => $onChange,
                                 -override  => $over,
                                 -size      => 8,
                                 -maxlength => 2000);
        $categories = scrolling_list (-name     => "INCLUDE-Categories-$name",
                                      -default  => $cats,
                                      -values   => \@allCats,
                                      -onChange => $onChange,
                                      -override  => $over,
                                      -size     => 3,
                                      -multiple => 1);

        ($rowBGcolor, $rowBG2) = ($rowBG2, $rowBGcolor);

        push @tableRows, Tr ({-bgcolor => $rowBGcolor},
                             $self->groupToggle (name => $name),
                             td ([$includeCB, $db->description || '&nbsp;']),
                             td ({align => 'center'},
                                 [$categories, $overrideCB, $fgField, $bgField,
                                  $borderCB, $textField]));
    }

    if (@tableRows) {

        my ($setAlljs, $setAllRow) = $self->setAllJavascript;
        print $setAlljs;
        push @tableRows, Tr (td ({-align => 'center'}, $setAllRow))
            if $setAllRow;

        my @headers = ($i18n->get ('Include?'), $i18n->get ('Description'));
        unshift @headers, '&nbsp;' if $self->isMultiCal;

        print table ({border       => 0,
                      cellspaceing => 0,
                      cellpadding  => 2},
                     th ({-align => 'left'}, \@headers),
                     th ({-align => 'center'},
                         [$i18n->get ('Use Categories'),
                          $i18n->get ('Override Settings'),
                          $i18n->get ('Foreground Color'),
                          $i18n->get ('Background Color'),
                          $i18n->get ('Border'),
                          $i18n->get ('Identifying Text')]),
                     @tableRows);

        my @helpStrings;
        my $string = $i18n->get ('AdminInclude_HelpString_1');
        if ($string eq 'AdminInclude_HelpString_1') {
            $string =  qq {
                           If one or more categories are selected for a
                           calendar, only events in those categories will
                           be included. If no categories are selected, all
                           events from that calendar will be included.
                           Select the special entry "<- - - ->" to get
                           events with no category.
                          };
        }
        push @helpStrings, $string;

        $string = $i18n->get ('AdminInclude_HelpString_2');
        if ($string eq 'AdminInclude_HelpString_2') {
            $string =  qq {
                           To make all events from a particular calendar
                           appear similar, select the "Override Settings"
                           checkbox and specify the colors and border
                           preference.
                          };
        }
        push @helpStrings, $string;

        $string = $i18n->get ('AdminInclude_HelpString_3');
        if ($string eq 'AdminInclude_HelpString_3') {
            $string =  qq {
                           If "Identifying Text" is specified, it will
                           appear above each event included from the
                           calendar. HTML is allowed here.
                          };
        }
        push @helpStrings, $string;

        print $cgi->ul ($cgi->li ([map {$i18n->get ($_)} @helpStrings]));

        print '<br>';
        print Javascript->ColorPalette ($self);
        print a ({-href   => "Javascript:ColorWindow()"},
                 $i18n->get ('See Available Colors'));
    } else {
        print $cgi->center ($cgi->b ($i18n->get ('There are no other '  .
                                                 'Calendars available ' .
                                                 'to include.')));
    }

    print '<br><hr>';

    print submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset  (-value => 'Reset');

    print $self->hiddenParams;

    print endform;
    print $self->helpNotes;
    print end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->basicAuditString ($short);

    my $cal = $self->currentCal;
    my $old = $self->{audit_info}->{$cal};
    my $new = Preferences->new ($cal)->Includes;

    my $info;
    foreach my $incCal (sort keys %$old) { # each included cal
        my $diffs;
        foreach (sort keys %{$old->{$incCal}}) { # each item for this cal
            next if ($_ eq 'Excluded'); # special; from cookie in Operation.pm
            my $orig = $old->{$incCal}->{$_};
            my $gnu  = $new->{$incCal}->{$_};
            if ($_ eq 'Categories') {
                $orig = join ',', ($orig ? sort @$orig : '');
                $gnu  = join ',', ($gnu  ? sort @$gnu  : '');
            }
            $orig ||= '';
            $gnu  ||= '';
            next if ($orig eq $gnu);
            $diffs .= " ($_: $orig -> $gnu)";
        }
        next unless $diffs;
        if ($short) {
            $diffs = " [$incCal -$diffs]";
        } else {
            $diffs = "\n $incCal -$diffs";
        }
        $info .= $diffs;
    }
    return unless $info;     # don't report if nothing changed
    return $line . $info;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
