# Copyright 2005-2006, Fred Steinberg, Brown Bear Software

package AdminRSS;
use strict;
use CGI;

use Calendar::GetHTML;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $cancel, $disable, $formats, $icon_path) =
            $self->getParams (qw (Save Cancel RSS_Disable RSS_Formats
                                  RSS_IconPath));

    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    my %labels = (RSS_Disable  => $i18n->get ('Disable RSS Feeds')  . ': ',
                  RSS_Formats  => $i18n->get ('RSS Formats')  . ': ',
                  RSS_IconPath => $i18n->get ('RSS Icon URL, or Text')  . ': ',
                 );

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;
    my $message  = $self->adminChecks;

    if (!$message and $save) {
        $override = 0;
        $self->{audit_formsaved}++;

        foreach ($icon_path) {
            s/^\s+//;
            s/\s+$//;
        }

        my %newPrefs = (RSS_Disable  => $disable || 0,
                        RSS_Formats  => $formats,
                        RSS_IconPath => $icon_path);
        if ($self->isMultiCal) {
            my %prefMap = map {$_ => [$_]} keys %labels;
            my @modified = $self->removeIgnoredPrefs (map   => \%prefMap,
                                                      prefs => \%newPrefs);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%labels);
        }
        foreach (@$calendars) {
            $self->saveForAuditing ($_, \%newPrefs);
            $self->dbByName ($_)->setPreferences (\%newPrefs);
        }
    }

    print GetHTML->startHTML (title => $i18n->get ('RSS Settings'),
                              op    => $self);
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'RSS Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'RSS Settings', 1);
    }
    print "<center><h3>$message</h3></center>" if $message;
    print '<br>';

    print $cgi->startform;

    # If group, allow selecting any calendar we have Admin permission for
    my %onChange = ();
    if ($self->isMultiCal) {
        my ($calSelector, $mess) = $self->calendarSelector;
        print $mess if $mess;
        print $calSelector;

        foreach (keys %labels) {
            $onChange{$_} = $self->getOnChange ($_);
        }
    }

    $disable   = $preferences->RSS_Disable;
    $formats   = $preferences->RSS_Formats || 'rss';
    $icon_path = $preferences->RSS_IconPath;

    my $disable_row = $cgi->Tr ($self->groupToggle (name => 'RSS_Disable'),
                            $cgi->td ('<nobr>' .
                                      $cgi->b ($labels{RSS_Disable}) .
                                      '</nobr>'),
                            $cgi->td ($cgi->checkbox (-name    => 'RSS_Disable',
                                                      -checked => $disable,
                                                      -label   => '',
                                           -onChange => $onChange{RSS_Disable},
                                                      -override => $override,
                                                      )),
                            $cgi->td ({-class => 'InlineHelp'},
                                      $i18n->get ('If selected, RSS feeds will '
                                                  .' not be available.')));

    my @rss_formats = qw /rss 2.0 atom rdf/;
    my %format_labels = (atom  => 'Atom',
                         rss   => 'RSS 1.0',
                         rdf   => 'RDF',
                         '2.0' => 'RSS 2.0');
    my $help_line = $i18n->get ('Pick a format for your feed');
    my $formats_row = $cgi->Tr ($self->groupToggle (name => 'RSS_Formats'),
                      $cgi->td ('<nobr>' .
                                $cgi->b ($labels{RSS_Formats}) .
                                '</nobr>'),
                        $cgi->td ($cgi->popup_menu (-name    => 'RSS_Formats',
                                                    -values  => \@rss_formats,
                                                    -labels  => \%format_labels,
                                                    -default  => $formats,
                                            -onChange => $onChange{RSS_Formats},
                                                    -override => $override)),
                              $cgi->td ({-class => 'InlineHelp'},
                                        $help_line));
    $help_line = $i18n->get ('AdminRSS-RSSLink');
    if ($help_line eq 'AdminRSS-RSSLink') {
        $help_line = q {What to display on the calendar for the RSS
                        link. This can be a URL to an image
                        (e.g. <i>http://my.domain.com/images/rss.png</i>),
                        or just text, like "RSS". If left blank, no
                        icon or text link will be dislayed on
                        calendar.};
    }

    my $icon_row = $cgi->Tr ($self->groupToggle (name => 'RSS_IconPath'),
                      $cgi->td ('<nobr>' .
                                $cgi->b ($labels{RSS_IconPath}) .
                                '</nobr>'),
                        $cgi->td ($cgi->textfield (-name    => 'RSS_IconPath',
                                                   -size    => 40,
                                                   -default => $icon_path,
                                           -onChange => $onChange{RSS_IconPath},
                                                   -override => $override)),
                              $cgi->td ({-class => 'InlineHelp'},
                                        $help_line));

    print $cgi->table ($disable_row, $formats_row, $icon_row);

    print '<br>';
    print '<hr>';
    print $cgi->submit (-name  => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-name  => 'Cancel', -value => $i18n->get ('Done'));
    print $self->hiddenParams;
    print $cgi->endform;

    my @help_strings;
    if (!$self->isMultiCal) {
        my $string = $i18n->get ('AdminRSS_HelpString_1');
        if ($string eq 'AdminRSS_HelpString_1') {
            $string = q {The RSS feed for this
                         calendar can also be accessed at this URL:
                         <div style="margin: 10px"><a href="%s">%s</a></div>

                         So, instead of using the RSS Icon URL option
                         above, that link can be placed in the
                         calendar's Header or Footer. For example:
                         <div style="margin: 10px">
                         &lt;a href="%s"&gt;&nbsp;RSS Feed&nbsp;&lt;/a&gt;
                         </div>};
        }

        my $rss_url = $self->makeURL ({Op => 'RSS', FullURL => 1});
        $string = sprintf $string, $rss_url, $rss_url, $rss_url;
        push @help_strings, $string;
    }

    if (@help_strings) {
        print '<br><div class="AdminNotes">';
        print qq {<span class="AdminNotesHeader">} . $i18n->get ('Notes') . ':'
              . '</span>';
        print $cgi->ul ($cgi->li ([@help_strings]));
        print '</div>';
    }

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
