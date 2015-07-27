# Copyright 2004-2006, Fred Steinberg, Brown Bear Software

package AdminCSS;
use strict;
use CGI;

use Calendar::GetHTML;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $cancel, $fileURL, $inlineCode) =
            $self->getParams (qw (Save Cancel FileURL InlineCode));

    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    my %nameMap = (CSS_URL    => $i18n->get ('CSS File')    . ': ',
                   CSS_inline => $i18n->get ('Inline CSS')  . ': ',);

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;
    my $message  = $self->adminChecks;

    if (!$message and $save) {
        $override = 0;
        $self->{audit_formsaved}++;

        foreach ($fileURL, $inlineCode) {
            $_ =~ s/^\s+//;
            $_ =~ s/\s+$//;
        }

        my %newPrefs = (CSS_URL    => $fileURL,
                        CSS_inline => $inlineCode);
        if ($self->isMultiCal) {
            my %prefMap = map {$_ => [$_]} keys %nameMap;
            my @modified = $self->removeIgnoredPrefs (map   => \%prefMap,
                                                      prefs => \%newPrefs);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%nameMap);
        }
        foreach (@$calendars) {
            $self->saveForAuditing ($_, \%newPrefs);
            $self->dbByName ($_)->setPreferences (\%newPrefs);
        }
    }

    print GetHTML->startHTML (title => $i18n->get ('CSS Settings'),
                              op    => $self);
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'CSS Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'CSS Settings', 1);
    }
    print "<center><h3>$message</h3></center>" if $message;
    print '<br>';

    my $urlInstructions = $i18n->get ('AdminCSS-URLHelp');
    if ($urlInstructions eq 'AdminCSS-URLHelp') {
        $urlInstructions = qq {
            Specify the URL for the CSS file. It can be an absolute URL, or
            one relative to the server\'s document root. E.g.
            <b>http://my.domain.com/css/calcium.css</b> or just
            <b>/css/calcium.css</b>
                              }
    }
    my $inlineInstructions = $i18n->get ('AdminCSS-InlineHelp');
    if ($inlineInstructions eq 'AdminCSS-InlineHelp') {
        $inlineInstructions = qq {
            Specify CSS to send back inline. Any valid CSS is ok, e.g.
            <pre>.SectionHeader {color: gold; background-color: darkblue;}
.InlineHelp {font-style: italic;}
            </pre>
                                 }
    }

    print $cgi->startform;

    # If group, allow selecting any calendar we have Admin permission for
    my %onChange = ();
    if ($self->isMultiCal) {
        my ($calSelector, $mess) = $self->calendarSelector;
        print $mess if $mess;
        print $calSelector;

        foreach (keys %nameMap) {
            $onChange{$_} = $self->getOnChange ($_);
        }
    }

    my $url    = $preferences->CSS_URL;
    my $inline = $preferences->CSS_inline;

    my $fileRow = $cgi->Tr ($self->groupToggle (name => 'CSS_URL'),
                            $cgi->td ('<nobr>' .
                                      $cgi->b ($nameMap{CSS_URL}) .
                                      '</nobr>'),
                            $cgi->td ($cgi->textfield (-name     => 'FileURL',
                                                       -default  => $url,
                                                       -size     => 40,
                                           -onChange => $onChange{CSS_URL},
                                                       -override => $override,
                                                      )),
                            $cgi->td ({-class => 'InlineHelp'},
                                      $urlInstructions));

    my $urlRow = $cgi->Tr ($cgi->td ('&nbsp;'));
    if ($url) {
        $urlRow = $cgi->Tr ($cgi->td ({-colspan => 3, -align => 'center'},
                    $i18n->get ('Click this link to test the current setting')
                    . ': ' . $cgi->a ({-href => $url}, $url)));
    }

    my $inlineRow = $cgi->Tr ($self->groupToggle (name => 'CSS_inline'),
                      $cgi->td ('<nobr>' .
                                $cgi->b ($nameMap{CSS_inline}) .
                                '</nobr>'),
                        $cgi->td ($cgi->textarea (-name     => 'InlineCode',
                                                  -default  => $inline,
                                                  -rows     => 10,
                                                  -columns  => 40,
                                                  -wrap     => 'OFF',
                                            -onChange => $onChange{CSS_inline},
                                                  -override => $override,
                                                 )),
                              $cgi->td ({-class => 'InlineHelp'},
                                        $inlineInstructions));
    print $cgi->table ($fileRow, $urlRow, $inlineRow);

    print '<br>';
    print '<hr>';
    print $cgi->submit (-name  => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-name  => 'Cancel', -value => $i18n->get ('Done'));
    print $self->hiddenParams;
    print $cgi->endform;
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
