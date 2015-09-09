# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Specify who can do what to this calendar.

package AdminSecurity;
use strict;

use CGI (':standard');
use Calendar::AdminPager;
use Calendar::GetHTML;
use Calendar::UserGroup;

use vars ('@ISA');
@ISA = ('Operation');

my %permValues = (None       => 0,
                  View       => 1,
                  Add        => 2,
                  Edit       => 3,
                  Admin      => 4,
                  Administer => 4);

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    my $calName = $self->calendarName;

    if ($cancel) {
        my $op = $calName ? 'AdminPage' : 'SysAdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $username   = $self->getUsername;
    my $masterPerm = Permissions->new (MasterDB->new);
    my @userGroups = UserGroup->getAll;

    my @allUserNames = sort {lc($a) cmp lc($b)} User->getUserNames;
    my $pager = AdminPager->new (op       => $self,
                                 contents => \@allUserNames,
                                 itemName => $i18n->get ('users'));
    my @userNames = $pager->getDisplayList;

    my $message;

    # if we're getting saved, save it.
    if ($save) {
        $self->{audit_formsaved}++;
        $self->{audit_orig} = $self->permission->getUserHash;

        if ($calName) {
            $self->permission->setAuthenticatedUser ('None');
            $self->permission->setAnonymous (param ("AnonRadio"));
            foreach (@userNames) {
                my $level = param ("UserRadio-$_");
                $level ||= 'None';
                $self->permission->set ($_, $level);
            }

            foreach (@userGroups) {
                my $name = $_->name;
                my $level = param ("GroupRadio-$name") || 'None';
                $self->permission->setGroup ($_, $level);
            }

            # Anyone who has Sys Admin, gets Admin everywhere
            foreach (@userNames) {
                $self->permission->set ($_, 'Admin')
                    if ($masterPerm->permitted ($_, 'Admin'));
            }
            # Make sure they don't remove their own admin privs
            unless ($self->permission->permitted ($username, 'Admin')) {
                $self->permission->set ($username, 'Admin');
                $message = $i18n->get ('Sorry, you cannot remove ' .
                                       'Administration permissions ' .
                                       'for yourself.');
            }

        # hack for storing new cal default perms
        } else {
            $self->permission->set ('SysDefault-AuthenticatedUser', 'None');
            $self->permission->set ('SysDefault-AnonymousUser',
                                    param ('AnonRadio'));
            foreach (@userNames) {
                my $level = param ("UserRadio-$_");
                $level ||= 'None';
                $self->permission->set ("SysDefault-$_", $level);
            }
        }
    }

    print GetHTML->startHTML (title  => $i18n->get ('Security') . ': ' .
                                          ($calName ||
                                           $i18n->get ('System Defaults')),
                              op     => $self);

    if ($calName) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $calName,
                                    section => 'Security');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Security');
    }

    my $helpString = $i18n->get ('AdminSecurity_HelpString');
    if ($helpString eq 'AdminSecurity_HelpString') {
        ($helpString =<<"        END_INSTRUCTIONS") =~ s/^ +//gm;
            There are four levels of increasing security: <b>View Only</b>,
            <b>Add Events</b>, <b>Edit Events</b>, and <b>Administer</b>.
            Higher levels include permission for all lower ones, so anyone
            with Edit permission can also View and Add events, while those
            with Administer permission can do anything. <i>Note that any
            user with <span class="highlight">System Administration
            Permission</span> will always have Administer permission in any
            calendar.</i>
        END_INSTRUCTIONS
    }
    print table ({width => '90%', align => 'center'}, Tr (td ($helpString)));

    print '<br><center>';

    if (Permissions->new (MasterDB->new)->permitted (undef, 'Admin')) {
        my $url = $self->makeURL ({Op           => 'SysSecurity',
                                   CalendarName => undef});
        print '<p>';
        print '<b><span class="highlight">';
        print $i18n->get ('Warning');
        print ':</span></b> ';
        print $i18n->get ('Anonymous users have System Administration ' .
                          'Permission.');
        print '<br>';

        my $x = $i18n->get ('Go to the <a href="%s">System Administration ' .
                            'Security Settings</a> to change this.');
        printf ($x, $url);
        print '</p>';
    }

    if ($username) {
        print $i18n->get ('You are currently logged in as') .
              ' <b>' . $username . '.</b><br><br>';
    } else {
        print '<p>';
        print $i18n->get ('You are <b>not</b> currently logged in.') .
              '&nbsp;';
        my $loginURL = $self->makeURL ({Op        => 'UserLogin',
                                        DesiredOp => 'AdminSecurity'});
        print a ({href => $loginURL}, $i18n->get ('Login'));
        print '</p>';
    }

    print "<p>$message</p>" if $message;
    print '</center>';

    my $anonAdmin;
    # hack for storing new cal default perms
    $anonAdmin = defined $calName ? $self->permission->getAnonymous
                                  : $self->permission->get
                                                 ('SysDefault-AnonymousUser');
    print startform;

    my @permValues = (qw (None View Add Edit Admin));
    my %permLabels = (None  => $i18n->get ('No Access'),
                      View  => $i18n->get ('View Only'),
                      Add   => $i18n->get ('Add Events'),
                      Edit  => $i18n->get ('Edit Events'),
                      Admin => $i18n->get ('Administer'));

    my $anyoneString = $i18n->get ("Default Security level. This applies to " .
                                   "users who haven't logged in.");

    my @radios = radio_group (-name     => "AnonRadio",
                              -values   => \@permValues,
                              -labels   => \%permLabels,
                              -override => 1,
                              -default  => "\u$anonAdmin");
    my $whoTable = table (Tr (td ({-colspan => 10}, $anyoneString)),
                          Tr (td (table ({-align => 'center'},
                                         Tr (td ([$radios[0], '&nbsp;&nbsp;',
                                                  $radios[1], '&nbsp;&nbsp;',
                                                  $radios[2], '&nbsp;&nbsp;',
                                                  $radios[3], '&nbsp;&nbsp;',
                                                  $radios[4]]))))));

    my %groupNameFor = map {$_->id => $_->name} @userGroups;
    my @cal_groups = $self->prefs->getGroups;

    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');
    my @rows;
    foreach (@userNames) {
        next unless defined;
        my $perm;
        my ($groupMax, $fromGroup);
        my $sysAdminP = $masterPerm->permitted ($_, 'Admin');
        # hack for storing new cal default perms
        if ($calName) {
            if ($sysAdminP) {
                $perm = 'Admin';
            } else {
                $perm = $self->permission->get ($_);
            }

            my $userObj = User->getUser ($_);

            # If user gets greater permission from a user group, indicate that
            if (@userGroups and $userObj) {
                # First, check user group settings for this calendar...
                my ($groupPerm, $groupID) = _maxGroupPermission ($userObj,
                                                             $self->permission,
                                                                 $masterPerm);
                if ($permValues{"\u$groupPerm"} > $permValues{"\u$perm"}) {
                    $groupMax = $groupPerm;
                    $fromGroup = $groupNameFor{$groupID};
                }

                $groupMax ||= 'None';

                # ...then, check user group settings for calendar groups
                foreach my $cal_group (@cal_groups) {
                    # Get hashref of {user group IDs => perm in cal group}
                    my $cg_perms = MasterDB->get_cal_group_perms ($cal_group);
                    foreach my $ugroup_id ($userObj->groupIDs) {
                        my $ugroup = $cg_perms->{$ugroup_id} || 'None';
                        if ($permValues{"\u$ugroup"}
                                > $permValues{"\u$groupMax"}) {
                            $groupMax = $ugroup;
                            $fromGroup = $groupNameFor{$ugroup_id};
                            $fromGroup .= "/$cal_group";
                        }
                    }
                }
            }
        } else {
            $perm = $self->permission->get ("SysDefault-$_") || 'View';
        }
        my @radios = radio_group (-name     => "UserRadio-$_",
                                  -values   => \@permValues,
                                  -labels   => \%permLabels,
                                  -override => 1,
                                  -default  => "\u$perm");
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
        my %x;
        $x{-class} = 'highlight' if $sysAdminP;

        my $groupTD = '';
        if (@userGroups) {
            my $groupString = $fromGroup ?
                           "<small><i><b>$groupMax</b> - $fromGroup</i></small>"
                           : '&nbsp;';
            $groupTD = td ($groupString);
        }
        push @rows, Tr ({-class => $thisRow},
                        td (\%x, $_),
                        $groupTD,
                        td ({-align => 'center',
                             -class    => 'PermLabels'},
                            table (Tr (td ([@radios])))));
    }

    my @col_headers = ('Username');
    if (@userGroups) {
        push @col_headers, 'Max Group Perm.';
    }
    push @col_headers, 'Permission Level';
    @col_headers = map {'<u>' . $i18n->get ($_) . '</u>'} @col_headers;

    my $boxTable =
        table ({-class   => 'alternatingTable',
                -width   => '90%',
                -border => 0,
                -cellspacing => 0,
                -cellpadding => 0},
               th ({-class => 'headerRow',
                    -align => 'center'}, \@col_headers),
               @rows);

    my $groupRow = '';
    if (@userGroups) {
        @rows = ();
        foreach (map  {$_->[0]}
                 sort {lc($a->[1]) cmp lc($b->[1])}
                 map {[$_, $_->name]} @userGroups) { # sort by name
            my $perm = $self->permission->getGroup ($_);
            $perm = 'Admin' if $masterPerm->groupPermitted ($_, 'Admin');
            my $name = $_->name;
            my @radios = radio_group (-name     => "GroupRadio-$name",
                                      -values   => \@permValues,
                                      -labels   => \%permLabels,
                                      -override => 1,
                                      -default  => "\u$perm");
            my $label = $name;
            if ($masterPerm->groupPermitted ($_, 'Admin')) {
                $label = qq (<span class="highlight">$name</span>);
            }
            ($thisRow, $thatRow) = ($thatRow, $thisRow);
            push @rows, Tr ({-class => $thisRow},
                            td ($label),
                            td ({-align => 'center'},
                                table (Tr (td ({-class    => 'PermLabels'},
                                               [@radios])))));
        }
        push @rows, Tr (td ({-colspan => 2}, '<hr width="70%">'));
        my $groupTable =
                table ({-class       => 'alternatingTable',
                        -border      => 0,
                        -cellspacing => 0,
                        -cellpadding => 0},
                       th ({-class => 'headerRow'},
                           ['<u>' . $i18n->get ('User Group Name')  . '</u>',
                            '<u>' . $i18n->get ('Permission Level') . '</u>']),
                       @rows);

        $groupRow = Tr (td ({align => 'center'}, $groupTable));
    }

    print table ({-width   => '90%',
                  -align   => 'center',
                  -bgcolor => '#cccccc'},
                 Tr (td (GetHTML->SectionHeader
                         ($i18n->get ('Current Permissions / ' .
                                      'Set New Permissions')))),
                 Tr (td ({align => 'center'}, table (Tr (td ($whoTable))))),
                 $groupRow,
                 Tr (td ({align => 'center'}, $boxTable)));

    print $pager->controls;

    print '<br>';
    print '<hr>';
    print submit (-name  => 'Save',
                  -value => $i18n->get ('Set Permissions')); print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset;
    print hidden (-name  => 'Op',           -value => 'AdminSecurity');
    print hidden (-name  => 'CalendarName', -value => $calName) if $calName;
    print endform;

    print '<br><div class="AdminNotes">';
    print span ({-class => 'AdminNotesHeader'}, $i18n->get ('Notes') . ':');
    print '<ul><li>';
    print $i18n->get ('A user will have the highest access assigned to ' .
                      'them, including all the User Groups they are a ' .
                      'member of, as well as User Group permissions assigned ' .
                      'to Calendar Groups.');
    print '</li></ul></div>';

    print end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    my $perms = $self->permission->getUserHash;

    my $info;
    foreach (sort keys %{$self->{audit_orig}}) {
        next if ($self->{audit_orig}->{$_} eq $perms->{$_});
        $info .= " [$_: $self->{audit_orig}->{$_} -> $perms->{$_}]";
    }

    return unless $info;     # don't report if nothing changed
    return $line . $info;
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css;
    $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    $css .= $self->cssString ('.highlight', {'color' => 'red'});
    $css .= $self->cssString ('.PermLabels', {'font-size' => 'smaller'});
    return $css;
}

# Pass perm obj and user;
# return max permission level and group name they get that level from
sub _maxGroupPermission {
    my ($user, $perm, $masterPerm) = @_;
    my $maxGroupPermission = 'None';
    my $groupID;
    foreach my $id ($user->groupIDs) {
        my $have = $perm->getGroup ($id) || 'None';
        if ($masterPerm->groupPermitted ($_, 'Admin')) {
            $have = 'Admin';
        }
        if ($permValues{"\u$have"} > $permValues{"\u$maxGroupPermission"}) {
            $maxGroupPermission = $have;
            $groupID = $id;
            last if "\u$maxGroupPermission" eq 'Admin';
        }
    }
    return ($maxGroupPermission, $groupID);
}

1;
