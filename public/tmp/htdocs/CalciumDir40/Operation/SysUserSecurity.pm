# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# Set permissions for users or user groups in multiple calendars
package SysUserSecurity;
use strict;
use CGI;

use Calendar::AdminPager;
use Calendar::GetHTML;
use Calendar::MasterDB;
use Calendar::UserGroup;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($doIt, $getPerms, $cancel) = $self->getParams (qw (Save GetPerms
                                                           Cancel));

    if ($cancel) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }
    if ($self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'Splash'}));
        return;
    }

    my $message;
    my $cgi = new CGI;

    my @selectedUsers = $cgi->param ('SelectedUsers');
    my @allCalendars  = sort {lc ($a) cmp lc ($b)} MasterDB->getAllCalendars;

    my $pager = AdminPager->new (op       => $self,
                                 contents => \@allCalendars,
                                 itemName => $i18n->get ('calendars'));
    my @displayCals = $pager->getDisplayList;

    my %calendarPerms;
    my %radioDefaults;
    my $masterPerm = Permissions->new (MasterDB->new);
    my $userHasSysAdmin;

    if ($getPerms and @selectedUsers != 1) {
        $message = $i18n->get ('Must select exactly one user to see ' .
                               'permissions.');
        $self->{audit_error} = 'single user not selected';
    }

    if ($doIt) {
        $self->{audit_formsaved}++;
        my ($param, $value, %newPerms);
        if (!@selectedUsers) {
            $message = $i18n->get ('Select one or more users.');
            $self->{audit_error} = 'no users selected';
        }
        if (!$self->{audit_error}) {
            foreach my $calName (@displayCals) {
                my $level = $cgi->param ("CalRadio-$calName");
                $level ||= 'Ignore';
                next if ($level eq 'Ignore');

                my $perms = Permissions->new ($calName);

                foreach my $uname (@selectedUsers) {
                    if ($uname =~ /Group: (.*)/) {
                        my $group_name = $1;
                        if (my $group = UserGroup->getByName ($group_name)) {
                            $perms->setGroup ($group, $level);
                        }
                    }
                    elsif ($uname ne 'Anonymous User') {
                        $perms->set ($uname, $level);
                    }
                    else {
                        $perms->setAnonymous ($level);
                    }
                }
            }
        }
    }

    # if a single user or group selected, always get perms
    if (@selectedUsers == 1) {
        my $user = $selectedUsers[0];
        my $group;
        if ($user =~ /Group: (.*)/) {
            my $group_name = $1;
            $group = UserGroup->getByName ($group_name);
            $userHasSysAdmin = $masterPerm->groupPermitted ($group, 'Admin');
        }
        else {
            undef $user if ($user eq 'Anonymous User');
            $userHasSysAdmin = $masterPerm->permitted ($user, 'Admin');
        }
        foreach my $calName (@displayCals) {
            $calendarPerms{$calName} = Permissions->new ($calName);
            if ($userHasSysAdmin) {
                $radioDefaults{$calName} = 'Admin';
            }
            else {
                $radioDefaults{$calName} = $group
                                   ? $calendarPerms{$calName}->getGroup ($group)
                                   : $calendarPerms{$calName}->get ($user);
            }
        }
    }

    if ($self->{audit_formsaved}) {
        $self->{audit_usernames} = \@selectedUsers;
    }

    print GetHTML->startHTML (title => $i18n->get ('User Security'),
                              op    => $self);

    print <<END_SCRIPT;
    <script language="JavaScript">
    <!--
        function CheckAll (level) {
           theform=document.SecurityForm;
           for (i=0; i<theform.elements.length; i++) {
              if (theform.elements[i].type=='radio' &&
                  theform.elements[i].value==level) {
                 theform.elements[i].checked=1;
              }
           }
        }
    //-->
    </script>
END_SCRIPT

    print GetHTML->SysAdminHeader ($i18n, 'Set User Security', 1);

    print $cgi->startform (-name => 'SecurityForm');

    my @users    = sort {lc $a cmp lc $b } User->getUserNames;
    my @u_groups = sort {lc $a cmp lc $b } map {$_->name} UserGroup->getAll;

    my @user_list = ((map {"Group: $_"} @u_groups),
                     'Anonymous User',
                     @users);

    my $userList = $cgi->scrolling_list (-name     => 'SelectedUsers',
                                         -Values   => \@user_list,
                                         -size     => 10,
                                         -multiple => 'true');

    my @permValues = (qw (Ignore None View Add Edit Admin));
    my %permLabels = (Ignore => $i18n->get ("Don't Change"),
                      None   => $i18n->get ('No Access'),
                      View   => $i18n->get ('View Only'),
                      Add    => $i18n->get ('Add Events'),
                      Edit   => $i18n->get ('Edit Events'),
                      Admin  => $i18n->get ('Administer'));

    my @calRows;
    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');
    foreach my $calName (sort {lc($a) cmp lc($b)} @displayCals) {
        my @radios = $cgi->radio_group (-name     => "CalRadio-$calName",
                                        -values   => \@permValues,
                                        -labels   => \%permLabels,
                                        -override => 1,
                                        -default  => $radioDefaults{$calName}
                                                     || 'Ignore');
        my $row = $cgi->Tr ({-class => $thisRow},
                            $cgi->td ({-class => 'CalendarName'}, $calName),
                            $cgi->td (\@radios));
        push @calRows, $row;
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
    }
    push @calRows, $cgi->Tr ($cgi->td ('&nbsp;'),
                             $cgi->td ({-align => 'center',
                                        -class => 'SetAllLink'},
                               [map {
                              $cgi->a ({-href => "javascript:CheckAll('$_')"},
                                       $i18n->get ('Select All'))
                                    }
                                 qw (Ignore None View Add Edit Admin)]));

    my $header = $cgi->Tr ({class => 'SectionHeader'},
                           $cgi->th ($i18n->get ('Calendar')),
                           $cgi->th ({colspan => 6},
                                     $i18n->get ('Permission Level ' .
                                                 'for selected users')));
    unshift @calRows, $header;

    if ($message) {
        print '<p><center>' .
              $cgi->font ({-color => 'red',
                           -size  => "+1"}, $i18n->get ('Error')) . ': ' .
              $cgi->font ({-size  => "+1"}, $message) . '</center></p>';
    }

    print '<blockquote>';

    my $instructions = qq {
        This page lets you set permissions for users and user groups
        in multiple calendars. Select one or more users and/or user
        groups, specify permissions in each calendar, and press the
        "Set Permission" button at the bottom. All the selected users
        and user groups will get the same permissions. You can also
        view permissions in all calendars for a single user or user
        group, using the "Get Current Permissions" button.};
    $instructions =~ s/\n//g;
    print $i18n->get ($instructions);
    print '</blockquote>';


    print '<center><b>', $i18n->get ('Users') . "</b><br>$userList</center>";

    print '<p><center>';
    print $cgi->submit (-name  => 'GetPerms',
                        -value => $i18n->get ('Get Current Permissions'));
    print '<br><small>';
    print $i18n->get ('Only if a single user or group is selected.');
    print '</small></center></p>';

    if ($userHasSysAdmin) {
        print '<center><p><big>';
        print $i18n->get ('Note: Selected user has System Admin permission.');
        print '</big></p></center>';
    }

    print $cgi->table ({class        => 'alternatingTable',
                        -align       => 'center',
                        -border      => 0,
                        -cellspacing => 0,
                        -cellpadding => 5},
                       @calRows);

    print $pager->controls;

    print '<hr>';
    print $cgi->submit (-name  => 'Save',
                        -value => $i18n->get ('Set Permissions'));
    print '&nbsp;';
    print $cgi->submit (-name    => 'Cancel',
                        -value   => $i18n->get ('Done'));
    print '&nbsp;&nbsp;&nbsp;';
    print $cgi->reset;
    print $cgi->hidden (-name => 'Op', -value => 'SysUserSecurity');

    print '<p>', $i18n->get ('Notes'), ':';
    print $cgi->ul (
           $cgi->li (
             $i18n->get ('All users have permissions at least as great as ' .
                         'the Anonymous User')),
           $cgi->li (
             $i18n->get ('Users with System Admin permission always have ' .
                         'Admin permission in every calendar.')));


    print $cgi->endform;
    print $cgi->end_html;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    $css .= $self->cssString ('.alternatingTable', {'font-size' => 'smaller'});
    $css .= $self->cssString ('.CalendarName',  {'font-size' => 'larger'});
    $css .= $self->cssString ('.SetAllLink', {color       => 'black',
                                              'font-size' => 'smaller'});
    return $css;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    my $info;

    $info .= ' ' . join ",", @{$self->{audit_usernames}};
    $info .= " error - $self->{audit_error}" if $self->{audit_error};

    return "$line $info";
}

1;
