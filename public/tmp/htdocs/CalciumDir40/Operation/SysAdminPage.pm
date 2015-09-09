# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package SysAdminPage;
use strict;

use CGI (':standard');

use Calendar::Defines;
use Calendar::GetHTML;
use Operation::Splash;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    # If calendar name, user has admin in calendar, not necessarily sys admin
    if ($self->calendarName) {
        print $self->redir ($self->makeURL ({Op           => 'Splash',
                                             CalendarName => undef}));
        return;
    }

    print GetHTML->startHTML (title  => $i18n->get ('System Administration'),
                              onLoad => 'page_load()',
                              op     => $self);
    print GetHTML->onLoad_for_link_menu;

    print '<center>';
    print GetHTML->PageHeader ((Preferences->new (MasterDB->new)->InstName
                               || 'Calcium') . ' '
                               . $i18n->get ('System Administration'));
    print GetHTML->SectionHeader ($i18n->get ('Operations'));
    print '</center>';

    my @tableCrap = qw (new delete rename
                        SPACE users ugroups userperm security
                        SPACE audit mail reminder
                        SPACE category periods addin
                        SPACE groups css ldap
                        SPACE maintain);
    my %links =  ('new'    => $self->makeURL ({Op => 'CreateCalendar'}),
                  'delete' => $self->makeURL ({Op => 'DeleteCalendar'}),
                  'rename' => $self->makeURL ({Op => 'RenameCalendar'}),
                  users    => $self->makeURL ({Op => 'SysUsers'}),
                  ugroups  => $self->makeURL ({Op => 'SysUserGroups'}),
                  userperm => $self->makeURL ({Op => 'SysUserSecurity'}),
                  security => $self->makeURL ({Op => 'SysSecurity'}),
                  mail     => $self->makeURL ({Op => 'SysMail'}),
                  reminder => $self->makeURL ({Op => 'SysMailReminder'}),
                  category => $self->makeURL ({Op => 'AdminCategories'}),
                  periods  => $self->makeURL ({Op => 'AdminTimePeriods'}),
                  groups   => $self->makeURL ({Op => 'SysGroups'}),
                  addin    => $self->makeURL ({Op => 'AdminAddIns'}),
                  css      => $self->makeURL ({Op => 'AdminCSS'}),
                  ldap     => $self->makeURL ({Op => 'SysLDAP'}),
                  maintain => $self->makeURL ({Op => 'SysMaintenance'}),
                  audit    => $self->makeURL ({Op     => 'AdminAuditing',
                                               SysSet => 1}));
    my %linkText =  ('new'    => $i18n->get ('New Calendar'),
                     'delete' => $i18n->get ('Delete Calendar'),
                     'rename' => $i18n->get ('Rename Calendar'),
                     users    => $i18n->get ('Users'),
                     ugroups  => $i18n->get ('User Groups'),
                     userperm => $i18n->get ('User Permissions'),
                     security => $i18n->get ('System Security'),
                     mail     => $i18n->get ('Email Settings'),
                     reminder => $i18n->get ('Email Reminder Process'),
                     category => $i18n->get ('Event Categories'),
                     periods  => $i18n->get ('Time Periods'),
                     groups   => $i18n->get ('Calendar Groups'),
                     addin    => $i18n->get ('Manage Add-In files'),
                     css      => $i18n->get ('CSS Settings'),
                     ldap     => $i18n->get ('LDAP Settings'),
                     maintain => $i18n->get ('System Maintenance/Repair'),
                     audit    => $i18n->get ('System Auditing'));
    my %description =  ('new'    => $i18n->get ('Create a New Calendar'),
                        'delete' => $i18n->get ('Delete an existing calendar'),
                        'rename' => $i18n->get ('Rename an existing calendar'),
                        users    => $i18n->get ('Add/Delete users, or reset ' .
                                                'passwords'),
                        ugroups  => $i18n->get ('Manage User Groups'),
                        userperm => $i18n->get ('Set permissions for users ' .
                                                'in multiple calendars'),
                        security => $i18n->get ('Set Permissions for System ' .
                                                'Administration'),
                        mail     => $i18n->get ('Set options for Email'),
                        reminder => $i18n->get ('Start or Stop the Reminder ' .
                                                'Process'),
                        category => $i18n->get ('Specify Event Categories'),
                        periods  => $i18n->get ('Define pre-set time periods'),
                        groups   => $i18n->get ('Manage Calendar Groups'),
                        addin    => $i18n->get ('For including events from ' .
                                                'external calendars'),
                        css      => $i18n->get ('Specify external CSS file'),
                        ldap     => $i18n->get ('Configure connection to an ' .
                                                'LDAP server'),
                        maintain => $i18n->get ('Cleanup and/or repair ' .
                                                'calendar data files'),
                        audit    => $i18n->get ('Auditing options for System' .
                                                ' Operations'));
    my $disabled_link = $self->makeURL ({Op => 'SysAdminPage'});
    my $disabled_text = sprintf ' - <b>%s</b>',
                                $i18n->get ('Disabled in this version');
    if (!Defines->multiCals) {
        $links{delete}        = $disabled_link;
        $description{delete} .= $disabled_text;
        $links{new}           = $disabled_link;
        $description{new}    .= $disabled_text;
        $links{groups}        = $disabled_link;
        $description{groups} .= $disabled_text;
    }
    if (!Defines->mailEnabled) {
        $links{reminder}        = $disabled_link;
        $description{reminder} .= $disabled_text;
    }
    if (!Defines->has_feature ('LDAP')) {
        $links{ldap}            = $disabled_link;
        $description{ldap}     .= $disabled_text;
    }

    print GetHTML->linkMenu (links       => \%links,
                             linkText    => \%linkText,
                             description => \%description,
                             order       => \@tableCrap);
    print '<br>';

    if (Defines->multiCals) {
        print GetHTML->SectionHeader ($i18n->get ('Default Settings') .
                                      '<br>' . '<font size=-1>' .
                                      $i18n->get ('These defaults can be ' .
                                                  'used by all <b>newly '  .
                                                  'created</b> calendars') .
                                      '</font>');

        @tableCrap = qw (display general editform colors fonts header
                         security audit);
        %links = ('display'  => $self->makeURL ({Op => 'AdminDisplay'}),
                  'general'  => $self->makeURL ({Op => 'AdminGeneral'}),
                  'editform' => $self->makeURL ({Op => 'AdminEditForm'}),
                  'colors'   => $self->makeURL ({Op => 'AdminColors'}),
                  'fonts'    => $self->makeURL ({Op => 'AdminFonts'}),
                  'header'   => $self->makeURL ({Op => 'AdminHeader'}),
                  'addins'   => $self->makeURL ({Op => 'AdminAddIns'}),
                  'security' => $self->makeURL ({Op => 'AdminSecurity'}),
                  'audit'    => $self->makeURL ({Op => 'AdminAuditing'}));
        %linkText = ('display'  => $i18n->get ('Display Settings'),
                     'general'  => $i18n->get ('General Settings'),
                     'editform' => $i18n->get ('Event Edit Form'),
                     'colors'   => $i18n->get ('Colors'),
                     'fonts'    => $i18n->get ('Fonts'),
                     'header'   => $i18n->get ('Header & Footer'),
                     'addins'   => $i18n->get ('Add-Ins'),
                     'security' => $i18n->get ('Security'),
                     'audit'    => $i18n->get ('Auditing'));
        %description = ('display'  => $i18n->get ('Default calendar ' .
                                                  'appearance'),
                        'general'  => $i18n->get ('Default language and ' .
                                                  'options'),
                        'editform' => $i18n->get('Default edit form settings'),
                        'colors'   => $i18n->get ('Default colors'),
                        'fonts'    => $i18n->get ('Default fonts'),
                        'header'   => $i18n->get ('Default text for headers ' .
                                                  'and footers'),
                        'addins'   => $i18n->get ('Default pre-defined ' .
                                                  'events to include'),
                        'security' => $i18n->get ('Default security ' .
                                                 'settings for new calendars'),
                        'audit'    => $i18n->get ('Default auditing options ' .
                                                  'for new calendars'));
        print GetHTML->linkMenu (links       => \%links,
                                 linkText    => \%linkText,
                                 description => \%description,
                                 order       => \@tableCrap);
    }

    print '<br><center>';

    if ($self->getUsername) {
        print '<p>' . $i18n->get ('You are currently logged in as') .
              ' <b>' . $self->getUsername . '.</b>';
        print '&nbsp;&nbsp;';
        print a ({href => $self->makeURL ({Op => 'UserLogout'})},
                 '<small>' . $i18n->get ('Logout') . '</small>');
        print '</p>';
    } else {
        print '<p>';
        print $i18n->get ('You are <b>not</b> currently logged in.') .'&nbsp;';
        my $loginURL = $self->makeURL ({Op        => 'UserLogin',
                                        DesiredOp => 'SysAdminPage'});
        print a ({href => $loginURL}, $i18n->get ('Login'));
        print '</p>';
    }

    print '<p>', $cgi->a ({href => $self->makeURL}, $i18n->get ('Home'));

    print '</center><br><br>';

    print Splash->calendarList ($self);

    print $cgi->end_html;
}

sub auditString {
    return undef;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
