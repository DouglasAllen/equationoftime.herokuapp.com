# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package AdminPage;
use strict;

use CGI (':standard');

use Calendar::GetHTML;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my $i18n = $self->I18N;

    if ($self->isSystemOp) {         # just in case
        GetHTML->errorPage ($i18n,
                            header => $i18n->get ('No Calendar Specified'),
                            message => 'This operation requires a calendar!');
        return;
    }

    my $cgi = new CGI;

    print GetHTML->startHTML (title  => $i18n->get ('Calendar Administration'),
                              onLoad => 'page_load()',
                              op     => $self);
    print GetHTML->onLoad_for_link_menu;

    print '<center>';
    print GetHTML->AdminHeader (I18N    => $i18n,
                                cal     => $self->calendarName || '',
                                goob    => $self->goobLabel    || '',
                                group   => $self->groupName    || '');
    print '</center>';
    print '<br>';

    # List order is how menu appears
    my @tableCrap = qw (display general headers           SPACE
                        editform custom templates         SPACE
                        colors fonts css                  SPACE
                        category periods                  SPACE
                        include addins rss                SPACE
                        security mail subscrip audit      SPACE
                        import export delete
                       );

    if ($self->isMultiCal) {
        @tableCrap = qw (display general headers editform SPACE
                         colors fonts css mail            SPACE);
        # Group Perms don't work for 'all' and 'nogroup'
        if (defined $self->groupName) {
            push @tableCrap, 'groupperm';
        }
        push @tableCrap, qw /include addins rss audit/;
    }

    my %links =  (display  => $self->makeURL ({Op => 'AdminDisplay'}),
                  general  => $self->makeURL ({Op => 'AdminGeneral'}),
                  editform => $self->makeURL ({Op => 'AdminEditForm'}),
                  custom   => $self->makeURL ({Op => 'AdminCustomFields'}),
                  templates => $self->makeURL ({Op => 'AdminTemplates'}),
                  colors   => $self->makeURL ({Op => 'AdminColors'}),
                  fonts    => $self->makeURL ({Op => 'AdminFonts'}),
                  css      => $self->makeURL ({Op => 'AdminCSS'}),
                  category => $self->makeURL ({Op => 'AdminCategories'}),
                  periods  => $self->makeURL ({Op => 'AdminTimePeriods'}),
                  headers  => $self->makeURL ({Op => 'AdminHeader'}),
                  addins   => $self->makeURL ({Op => 'AdminAddIns'}),
                  rss      => $self->makeURL ({Op => 'AdminRSS'}),
                  include  => $self->makeURL ({Op => 'AdminInclude'}),
                  security => $self->makeURL ({Op => 'AdminSecurity'}),
                  audit    => $self->makeURL ({Op => 'AdminAuditing'}),
                  mail     => $self->makeURL ({Op => 'AdminMail'}),
                  subscrip => $self->makeURL ({Op => 'AdminSubscriptions'}),
                  export   => $self->makeURL ({Op => 'AdminExport'}),
                  import   => $self->makeURL ({Op => 'AdminImport'}),
                  'delete' => $self->makeURL ({Op => 'AdminDeleteEvents'}));
    my %linkText = (display  => $i18n->get ('Display Settings'),
                    general  => $i18n->get ('General Settings'),
                    editform => $i18n->get ('Event Edit Form'),
                    custom   => $i18n->get ('Custom Fields'),
                    templates => $i18n->get ('Templates'),
                    colors   => $i18n->get ('Colors'),
                    fonts    => $i18n->get ('Fonts'),
                    css      => $i18n->get ('CSS'),
                    category => $i18n->get ('Categories'),
                    periods  => $i18n->get ('Time Periods'),
                    headers  => $i18n->get ('Title, Header, Footer'),
                    addins   => $i18n->get ('Add-Ins'),
                    rss      => $i18n->get ('RSS Feed'),
                    include  => $i18n->get ('Include other Calendars'),
                    security => $i18n->get ('Security'),
                    audit    => $i18n->get ('Auditing'),
                    mail     => $i18n->get ('Email Settings'),
                    subscrip => $i18n->get ('Email Subscriptions'),
                    export   => $i18n->get ('Export Events'),
                    import   => $i18n->get ('Import Events'),
                    'delete' => $i18n->get ('Delete Events'));
    my %description = (display  => $i18n->get ('Customize how your calendar ' .
                                               'appears'),
                       general  => $i18n->get ("Specify calendar's language," .
                                               " options, and description"),
                       editform => $i18n->get ('Specify defaults and options' .
                                               ' for creating new events'),
                       custom   => $i18n->get ('Define your own custom' .
                                               ' data fields for events'),
                       templates => $i18n->get ('Define custom output ' .
                                               ' templates'),
                       colors   => $i18n->get ('Change colors'),
                       fonts    => $i18n->get ('Change fonts'),
                       css      => $i18n->get ('Specify external or inline ' .
                                               'styles'),
                       category => $i18n->get ('Specify event categories'),
                       periods  => $i18n->get ('Define pre-set time periods'),
                       headers  => $i18n->get ('Specify the title,' .
                                               ' header, footer, and ' .
                                               'background image'),
                       addins   => $i18n->get ('Include events from external ' .
                                               'calendars - e.g. iCalendar '
                                               . qq /from Apple's iCal, or /
                                               . 'Google calendar'),
                       rss      => $i18n->get ('Enable/Disable/Configure RSS '
                                               . 'Feed'),
                       include  => $i18n->get ('Dynamically include events ' .
                                               'from other calendars'),
                       security => $i18n->get ('Specify who can view, edit, ' .
                                               'or administer the calendar'),
                       audit    => $i18n->get ('Specify which operations' .
                                               ' to keep a record of, and how'.
                                               ' to do it'),
                       mail     => $i18n->get ('Settings for mail ' .
                                               'sent from this calendar'),
                       subscrip => $i18n->get ('Manage email subscriptions'),
                       export   => $i18n->get ('Export event data to ASCII'),
                       import   => $i18n->get ('Create new events ' .
                                               'from an ASCII file'),
                       'delete' => $i18n->get ('Remove all events in a ' .
                                               'specified date range'));

    # Specialized for calendar groups
    if ($self->isMultiCal) {
        $links{colors}       = $self->makeURL ({Op => 'AdminColorsAlternate'});
        $links{groupperm}    = $self->makeURL ({Op => 'CalGroupSecurity'}),
        $linkText{groupperm} = $i18n->get ('User Group Permissions'),

        $description{display}  = $i18n->get ('Customize how calendars appear');
        $description{general}  = $i18n->get ("Specify language," .
                                             " options, and description");
        $description{mail}     = $i18n->get ('Customize mail settings');
        $description{addins}   = $i18n->get ('Specify which pre-defined ' .
                                             'events to include ');
        $description{groupperm} = $i18n->get ('Set Security for User Groups');
    }

    my $disabled_string = '&nbsp;&nbsp;<i>['
                          . $i18n->get ('Disabled in this version') . ']</i>';
    if (!Defines->mailEnabled) {
        $description{subscrip} .= $disabled_string;
        delete $links{subscrip};
    }
    if (!Defines->has_feature ('custom fields')) {
        $description{custom}    .= $disabled_string;
        $description{templates} .= $disabled_string;
        delete $links{custom};
        delete $links{templates};
    }
    if (!Defines->multiCals) {
        $description{include} .= $disabled_string;
        delete $links{include};
    }

    print GetHTML->linkMenu (links       => \%links,
                             linkText    => \%linkText,
                             description => \%description,
                             order       => \@tableCrap);
    print '<br><br>';

    my $homeURL = a ({href => $self->makeURL ({CalendarName => undef,
                                               Group        => undef,
                                               PlainURL     => 1})},
                     $i18n->get ('Home'));
    if ($self->isMultiCal) {
        print "<center>$homeURL</center>";
    } else {
        print table ({-width => '60%',
                      -align => 'center'},
                     Tr (td (a ({-href => $self->makeURL ({Op => 'ShowIt'})},
                                $i18n->get ('Return to the Calendar'))),
                         td ($homeURL)));
    }
    print $cgi->end_html;
}


sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

sub auditString {
    return undef;       # we don't care about this
}

1;
