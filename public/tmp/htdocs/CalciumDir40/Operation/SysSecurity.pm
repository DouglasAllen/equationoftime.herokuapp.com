# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Specify who can do System Administration type things

package SysSecurity;
use strict;

use CGI (':standard');
use Calendar::AdminPager;
use Calendar::GetHTML;
use Calendar::UserGroup;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($save, $cancel, $anyOrSelected) =
             $self->getParams (qw (Save Cancel AnyOrSelected));

    # if we've been cancel'ed, go back
    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    my $username   = $self->getUsername;
    my @userGroups = UserGroup->getAll;

    my @allUsers = sort {lc($a) cmp lc($b)} User->getUserNames;
    my $pager = AdminPager->new (op       => $self,
                                 contents => \@allUsers,
                                 itemName => $i18n->get ('users'));
    my @userNames = $pager->getDisplayList;

    my $message;

    # if we're getting saved, save it.
    if ($save) {
        $self->{audit_formsaved}++;
        $self->{audit_orig} = $self->permission->getUserHash;

        if ($anyOrSelected eq 'anyone') {
            $self->permission->setAnonymous ('Admin');
        } else {
            $self->permission->setAnonymous ('None');
            $self->permission->setAuthenticatedUser ('None');
            foreach (@userNames) {
                my $level = (param ("User-$_") ? 'Admin' : 'None');
                $self->permission->set ($_, $level);
            }
            foreach (@userGroups) {
                my $name = $_->name;
                my $level = (param ("Group-$name") ? 'Admin' : 'None');
                $self->permission->setGroup ($_, $level);
            }
        }

        # Make sure they don't remove their own admin privs
        unless ($self->permission->permitted ($username, 'Admin')) {
            $self->permission->set ($username, 'Admin');
            $message = $i18n->get ('Sorry, you cannot remove Administration ' .
                                   'permissions for yourself.');
        }
    }

    print GetHTML->startHTML (title => $i18n->get ('System Security'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n,
                                   'Security for System Administration', 1);

    my $instructions = $i18n->get ('SysSecurity_HelpString');
    if ($instructions eq 'SysSecurity_HelpString') {
        ($instructions =<<"        FNORD") =~ s/^ +//gm;
            System Administration functions include Creating and
            Deleting Calendars, adding and removing Users, and setting
            Global Defaults which apply to new calendars. Any
            user with System Administration rights will have full
            permissions in any calendar.
        FNORD
    }
    print table ({width => '90%', align => 'center'}, Tr (td ($instructions)));

    print '<center>';

    if ($username) {
        print $i18n->get ('You are currently logged in as') .
              ' <b>' . $username . '.</b><br><br>';
    } else {
        print '<p>';
        print $i18n->get ('You are <b>not</b> currently logged in.') .
              '&nbsp;';
        my $loginURL = $self->makeURL ({Op        => 'UserLogin',
                                        DesiredOp => 'SysSecurity'});
        print a ({href => $loginURL}, $i18n->get ('Login'));
        print '</p>';
    }

    print "<p>$message</p>" if $message;

    my $anonAdmin = $self->permission->permitted (undef, 'Admin');

    my (%empowered, %groupCan);
    unless ($anonAdmin) {
        foreach (@allUsers) {
            $empowered{$_}++ if $self->permission->userPermitted ($_, 'Admin');
        }
        foreach (@userGroups) {
            $groupCan{$_->name}++
                if ($self->permission->groupPermitted ($_->id, 'Admin'));
        }
    }

    my ($theUsers, $theString, $theGroups, $groupString);
    if ($anonAdmin) {
        $theString = 'Current settings allow <font color=red>Anyone</font> ' .
                     'to perform System Administration';
    } else {
        if (keys %empowered == 1) {
            $theString = 'Current settings allow only this user to perform' .
                         ' System Administration';
        } else {
            $theString = 'Current settings allow only these users to perform' .
                         ' System Administration';
        }
        $theUsers = join ', ', sort {lc($a) cmp lc($b)} keys %empowered;
        if (keys %groupCan) {
            $groupString .= sprintf 'As well as users in %s',
                                    (keys %groupCan == 1) ? 'this group'
                                                        : 'these groups';
            $theGroups = join ', ', sort {lc($a) cmp lc($b)} keys %groupCan;
        }
    }
    print $i18n->get ($theString);
    print ":<br><b>$theUsers</b>" if $theUsers;
    if (keys %groupCan) {
        print "<br>", $i18n->get ($groupString);
        print ":<br><b>$theGroups</b>" if $theGroups;
    }

    print '</center>';

    print startform;

    my $anyoneString = $i18n->get ("<b>Anyone</b> can perform System "     .
                                   "Administration, even if they haven't " .
                                   "logged in.");
    my $selectedUsersString = $i18n->get ("<b>Only the users selected "   .
                                          "below</b> can perform System " .
                                          "Administration.");
    my @radios = radio_group (-name      => 'AnyOrSelected',
                              -values    => ['anyone', 'selectedUsers'],
                              -default   => $anonAdmin ? 'anyone'
                                                       : 'selectedUsers',
                              -labels    => {anyone        => '',
                                             selectedUsers => ''});

    my $whoTable = table (Tr (td ($radios[0], $anyoneString)),
                          Tr (td ($radios[1], $selectedUsersString)));

    print <<'    END_JAVASCRIPT';
        <script language="JavaScript">
        <!-- start
            function setWhoRadio (theCheckbox) {
                form = theCheckbox.form;
                form.AnyOrSelected[1].checked = true;
            }
        // End -->
        </script>
    END_JAVASCRIPT

    # User Groups
    my @rows = ();
    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');
    my $groupRow = '';
    if (@userGroups) {
        my $members = UserGroup->getMemberMap;
        foreach (map  {$_->[0]}
                 sort {lc($a->[1]) cmp lc($b->[1])}
                 map  {[$_, $_->name]}
                      @userGroups) {                     # sort by name
            my @userNames = sort {lc $a cmp lc $b}
                             map {$_->name} @{$members->{$_->id} || []};
            for (my $i=5; $i<@userNames; $i+=5) {
                $userNames[$i] = '\n' . $userNames[$i]; # newlines for popup
            }
            my $userList = join (', ', @userNames)
                               || ' - no users in this group -';
            my $alert = '"' . $_->name . '" Group Members:\n' . $userList;
            push @rows, Tr ({-class => $thisRow},
                            td (a ({-href => "Javascript:alert ('$alert')"},
                                   $_->name)),
                            td ({-align => 'center'},
                                checkbox (-name    => "Group-" . $_->name,
                                          -label   => '',
                                          -checked => $groupCan{$_->name},
                                          -override => 1,
                                          -onClick  => 'setWhoRadio (this)')));
            ($thisRow, $thatRow) = ($thatRow, $thisRow);
        }
        my $groupTable =
            table ({-class       => 'alternatingTable',
                    -cellspacing => 0,
                    -cellpadding => 2,
                    -border      => 0},
                   th ({-align => 'center'},
                       ['<u>' . $i18n->get ('User Group') . '</u>&nbsp;',
                        '<u>' . $i18n->get ('Administer') . '?</u>']),
                   @rows);
        $groupRow = Tr (td ({align => 'center'}, $groupTable));
    }

    @rows = ();
    foreach (@userNames) {
        push @rows, Tr ({-class => $thisRow},
                        td ($_),
                        td ({-align => 'center'},
                             checkbox (-name    => "User-$_",
                                       -label   => '',
                                       -checked => $empowered{$_},
                                       -override => 1,
                                       -onClick  => 'setWhoRadio (this)')));
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
    }

    my $boxTable =
        table ({-class => 'alternatingTable',
                -cellspacing => 0,
                -cellpadding => 2,
                -border      => 0},
               th ({-align => 'center'},
                   ['<u>' . $i18n->get ('Username') . '</u>&nbsp;',
                    '<u>' . $i18n->get ('Administer') . '?</u>']),
               @rows);

    print table ({-width   => '90%',
                  -align   => 'center',
                  -bgcolor => '#bbbbbb'},
                 Tr (td (GetHTML->SectionHeader (
                                         $i18n->get ('Change Permissions')))),
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
    print hidden (-name  => 'Op', -value => 'SysSecurity');
    print endform;
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
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
