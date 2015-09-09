# Copyright 2000-2006, Fred Steinberg, Brown Bear Software

# Calendar Groups

package SysGroups;
use strict;
use CGI (':standard');

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($addDelete, $newGroupName, $cancel) =
            $self->getParams (qw (AddDelete NewGroupName Cancel));
    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;
    my $message;

    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    my @calendars = sort {lc($a) cmp lc($b)} MasterDB->getAllCalendars;

    if ($addDelete) {
        $self->{audit_formsaved}++;
        my $needToSave;
        if (defined $newGroupName and $newGroupName ne '') {
            $message = $self->_checkName ($newGroupName);
            unless ($message) {
                $prefs->addGroup ($newGroupName) if defined $newGroupName;
                $needToSave++;
            }
        }
        foreach (keys %{$self->{params}}) {
            next unless /^Delete-(.*)/;
            my $group = $1;
            $prefs->deleteGroup ($group);
            $needToSave++;

            # need to go through each calendar, remove this group!
            foreach my $calName (@calendars) {
                my $db = Database->new ($calName);
                my $prefs = $db->getPreferences;
                $prefs->deleteGroup ($group);
                $db->setPreferences ($prefs);
            }
        }
        $self->db->setPreferences ($prefs) if $needToSave;
    }


    # And display (or re-display) the form
    print GetHTML->startHTML (title => $i18n->get ('Calendar Groups'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n, 'Calendar Groups', 1);

    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');

    # get all groups
    my @groups = sort {lc($a) cmp lc($b)} $prefs->getGroups;
    my @rows;
    foreach (@groups) {
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
        push @rows, Tr ({-class => $thisRow},
                        td ({-align       => 'center',
                             -border      => 1,
                             -cellpadding => 3},
                            checkbox (-name    => "Delete-$_",
                                      -checked => undef,
                                      -label   => '')),
                        td ("&nbsp;&nbsp;&nbsp;$_"));
    }

    unless (@rows) {
        push @rows, Tr (td ({-colspan => 2,
                             -align   => 'center'},
                            $i18n->get ('No Groups Exist Yet')));
    }

    print startform;

    print h3 ($message) if $message;

    print '<br><center>';
    print table ({-class       => 'alternatingTable',
                  -border      => 2,
                  -cellpadding => 2,
                  -cellspacing => 2},
                 Tr (th ({-class   => 'AdminTableHeader',
                          -colspan => 2},
                         $i18n->get ('Add/Delete Calendar Groups'))),
                 Tr (th ({-class => 'AdminTableColumnHeader'},
                     [map {$i18n->get ($_)} ('Delete?', 'Group Name')])),
                 @rows,
                 Tr (td ({-bgcolor => "#eeeeee"},
                         ['<span style="font-size: smaller;">' .
                          $i18n->get ('Add New Group:') . '</span>',
                          textfield (-name     => 'NewGroupName',
                                     -size     => 20,
                                     -override => 1,
                                     -default  => '')])));
    print '<br>';
    print submit (-name  => 'AddDelete',
                  -value => $i18n->get ('Add/Delete'));
    print '&nbsp;&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print hidden (-name => 'Op', -value => 'SysGroups');
    print endform;

    print '</center>';
    print "<br><hr width='80%'>";


    my $head   = '<b>' . $i18n->get ('Calendar Groups') . '</b><br><small>' .
              $i18n->get ('Select a group to view or edit the calendars in it')
                 . '</small>';
    my $groupList = scrolling_list (-name   => 'GroupName',
                                    -values => \@groups,
                                    -size   => 10);
    my $gStuff = $head . '<br>' . $groupList . '<br>';
    $gStuff   .= submit (-name  => 'ByGroup',
                         -value => $i18n->get ('View/Edit'));

    $head = '<b>' . $i18n->get ('Calendars') . '</b><br><small>' .
            $i18n->get ("Select a calendar to view or edit the groups it's in")            . '</small>';
    my $calendarList = scrolling_list (-name   => 'CalName',
                                       -values => \@calendars,
                                       -size   => 10);
    my $uStuff = $head . '<br>' . $calendarList . '<br>';
    $uStuff   .= submit (-name  => 'ByCalendar',
                         -value => $i18n->get ('View/Edit'));

    my $url = $self->makeURL ({Op => undef});
    print startform (-action => $url);
    print table ({align => 'center',
                  width => '75%',
                  cellpadding => 10},
                 Tr ({align  => 'center',
                      valign => 'top'},
                     td ($gStuff),
                     td ($uStuff)));
    print hidden (-name     => 'Op',
                  -override => 1,
                  -value    => 'SysGroupAdmin');
    print endform;

    print end_html;
}


sub _checkName {
    my $self = shift;
    my $name = shift;

    my $i18n = $self->I18N;
    my $message;

    # Strip leading, trailing whitespace
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;

    if ($name =~ /\W/) {
        $message = '<span class="ErrorHighlight">' . $i18n->get ('Error') .
                   ': </span>';
        $message .= $i18n->get ('only letters, digits, and the underscore ' .
                                'are allowed in Group names.');
    } elsif ($name eq '') {
        $message = '<span class="ErrorHighlight">' . $i18n->get ('Error') .
                   ': </span>';
        $message .= $i18n->get ('cannot have blank Group name');
    }
    return $message;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $summary =  $self->SUPER::auditString ($short);


    my $message = '-';

    return unless $message;     # don't report if nothing changed

    if ($short) {
        return $summary . " $message";
    } else {
        return $summary . "\n\n$message";
    }
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
