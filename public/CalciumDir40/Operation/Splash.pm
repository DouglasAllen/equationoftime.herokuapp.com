# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package Splash;
use strict;

use CGI (':standard');

use Calendar::Defines;
use Calendar::GetHTML;
use Calendar::MasterDB;
use Calendar::Permissions;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $cgi  = new CGI;
    my $i18n = $self->I18N;

    my $instance_name = Preferences->new (MasterDB->new)->InstName || 'Calcium';

    print GetHTML->startHTML (title  => $instance_name,
                              onLoad => 'page_load()',
                              op     => $self);
    print GetHTML->onLoad_for_link_menu;

    my $username = $self->getUsername;
    my $welcome = $i18n->get ('Options') .
                  ($username ? ' ' . $i18n->get ('for user') . ": $username"
                             : '');

    print '<div class="Splash">';

    print GetHTML->PageHeader ($instance_name);

    $self->{_adminPermissionCount} = 0;

    my $calendarList = Splash->calendarList ($self);

    my %links =  (sysAdmin => $self->makeURL ({Op => 'SysAdminPage'}),
                  password => $self->makeURL ({Op     => 'UserOptions',
                                               NextOp => 'Splash'}),
                  multiAdmin => $self->makeURL ({Op   => 'AdminPage',
                                                 GOOB => 'all'}),
                  login    => $self->makeURL ({Op => 'UserLogin'}),
                  logout   => $self->makeURL ({Op => 'UserLogout'}));
    my %linkText =  (sysAdmin => $i18n->get ('System Administration'),
                     password => $i18n->get ('User Options'),
                     multiAdmin => $i18n->get ('Calendar Settings'),
                     login    => $i18n->get ('Login'),
                     logout   => $i18n->get ('Logout'));
    my %description = (sysAdmin  => $i18n->get ('Manage users, create new ' .
                                                'calendars, set system '    .
                                                'defaults'),
                        password => $i18n->get ('Change your password, ' .
                                                'email address, or timezone ' .
                                                'offset'),
                       multiAdmin => $i18n->get ('Change settings for ' .
                                                 'multiple calendars at once'),
                        login    => $i18n->get ('Identify yourself'),
                        logout   => $i18n->get ('Bye!'));
    my @tableCrap;
    push @tableCrap, 'sysAdmin'
        if (Permissions->new (MasterDB->new)->permitted ($username, 'Admin'));
    push @tableCrap, 'multiAdmin'
        if ($self->{_adminPermissionCount} > 1);
    push @tableCrap, ('password', 'logout')
        if ($username && $self->getUser->internallyAuthenticated);
    push @tableCrap, ('login')
        if (!$username);

    if (@tableCrap == 1 and $tableCrap[0] eq 'login') {
        print '<center>';
        print a ({-href => $links{login}}, h3 ($linkText{login}));
        print '</center>';
    } else {
        print GetHTML->SectionHeader ($welcome);
        print GetHTML->linkMenu (links       => \%links,
                                 linkText    => \%linkText,
                                 description => \%description,
                                 order       => \@tableCrap);
    }
    print '<br/>';

    print $calendarList;

    print '<br/><br/><br/><br/><hr/><small>';
    print 'Calcium ' . Defines->version . ' ' . Defines->license;
    print '<br/>';
    print '<a href="http://www.brownbearsw.com">Brown Bear Software</a>';
    print '</small>';

    print '</div>';

    print $cgi->end_html;
}


sub calendarList {
    my $className = shift;
    my $op = shift;
    my @cals = MasterDB->getAllCalendars;
    my $html;

    my $username = $op->getUsername;
    my $i18n = $op->I18N;

    $html = GetHTML->SectionHeader ($i18n->get('Links to Existing Calendars'));

    my (@items, @rows);
    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');

    my $invalidGroupNameSortsFirst = ' invalid group name!';

    # Get info for each calendar
    my (%adminPerms, %descriptions, %calsInGroup);
    foreach my $calName (@cals) {
        my $db = Database->new ($calName);
        my $perm = Permissions->new ($db);
        next unless $perm->permitted ($username, 'View');
        $adminPerms{$calName}   = $perm->permitted ($username, 'Admin');
        $descriptions{$calName} = $db->description || '';

        $op->{_adminPermissionCount}++ if ($adminPerms{$calName});

        my @groups = $db->getPreferences->getGroups;
        push @groups, $invalidGroupNameSortsFirst if (!@groups);
        foreach my $group (@groups) {
            $calsInGroup{$group} ||= [];
            push @{$calsInGroup{$group}}, $calName;
        }
    }

    # List calendars sorted first by group, then by name within groups
    my $notFirst;
    foreach my $gname (sort {lc($a) cmp lc($b)} keys %calsInGroup) {
        if ($notFirst) {
            push @rows, Tr (td ({-colspan => 3}, '&nbsp;'));
        }
        $notFirst++;

        my $canAdmin = 0;
        my @cals = @{$calsInGroup{$gname}};
        my @calRows;
        foreach (sort {lc($a) cmp lc($b)} @cals) {
            my $link = $op->makeURL ({Op           => 'ShowIt',
                                      CalendarName => $_});
            my $adminLink = '&nbsp;';
            if ($adminPerms{$_}) {
                $adminLink = a ({href => $op->makeURL ({Op => 'AdminPage',
                                                        CalendarName => $_})},
                                $i18n->get ('Settings'));
                $canAdmin++;
            }
            ($thisRow, $thatRow) = ($thatRow, $thisRow);
            push @calRows, Tr ({-class => $thisRow},
                               td ([a ({-href => $link}, $_),
                                    $descriptions{$_} || '&nbsp;']),
                               td ({-class => 'AdminLink'}, $adminLink));
        }

        my $groupTitle;
        if ($gname eq $invalidGroupNameSortsFirst) {
            $groupTitle = $i18n->get ('Calendars not in any Group');
            if ($canAdmin > 1) {
                $groupTitle .= ' &nbsp; (' .
                        a ({-href => $op->makeURL ({Op   => 'AdminPage',
                                                    GOOB => 'nogroup'})},
                           $i18n->get ('settings')) . ')';
            }
        } else {
            $groupTitle = $i18n->get ('Group') . ': ';
            if ($canAdmin > 1) {
                $groupTitle .= a ({-href => $op->makeURL ({Op   => 'AdminPage',
                                                           Group => $gname})},
                                  $gname);
            } else {
                $groupTitle .= $gname;
            }
        }

        if (Defines->multiCals) {
            push @rows, Tr ({-class => 'headerRow'},
                            td ({-colspan => 3,
                                 -align   => 'center'},
                                $groupTitle));
        }
        push @rows, @calRows;
    }

    if (@rows) {
        $html .=  table ({class        => 'alternatingTable',
                          width        => '95%',
                          align        => 'center',
                          border       => 0,
                          cellpadding  => 2},
                         Tr (th ({-align => 'center'},
                                 [$i18n->get ('Name'),
                                  $i18n->get ('Description'),
                                  $i18n->get ('Administer')])),
                         @rows);
    } else {
        $html .= '<center>';
        $html .= $i18n->get ("No calendars exist, or you don't have " .
                             "permission to view any of them");
        $html .= '</center>';
    }
    $html;
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css;
    $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    $css .= $self->cssString ('.AdminLink', {'text-align' => 'center'});
    return $css;
}

1;
