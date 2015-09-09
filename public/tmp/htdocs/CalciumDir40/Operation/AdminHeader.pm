# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Title, Header, and Footer Settings
package AdminHeader;
use strict;

use CGI (':standard');

use Calendar::GetHTML;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL({Op => $op}));
        return;
    }

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    my @names = qw (Title Header Footer SubFooter BackgroundImage);
    my %captions = (Title           => $i18n->get ('Title'),
                    Header          => $i18n->get ('Header'),
                    Footer          => $i18n->get ('Footer'),
                    SubFooter       => $i18n->get ('Sub-Footer'),
                    BackgroundImage => $i18n->get ('Background Image'));

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;
    my $message = $self->adminChecks;
    if (!$message and $save) {
        $override = 0;

        # which 'ignore' items go with which
        my %ignore = (TitleAlignment     => 'Title',
                      HeaderAlignment    => 'Header',
                      FooterAlignment    => 'Footer',
                      SubFooterAlignment => 'SubFooter');

        # Get new prefs
        my %newPrefs;
        foreach (qw (Title Header Footer SubFooter
                     TitleAlignment HeaderAlignment FooterAlignment
                     SubFooterAlignment BackgroundImage)) {

            my $value = $self->{params}->{$_};
            next if !defined $value;
            $value =~ s/^\s+//;
            $value =~ s/\s+$//;
            $newPrefs{$_} = $value;
        }
        # Make sure bg image starts at root, or full URL
        if ($newPrefs{BackgroundImage} and
            ($newPrefs{BackgroundImage} !~ m{^[/|http|ftp]})) {
            $newPrefs{BackgroundImage} = '/' . $newPrefs{BackgroundImage};
        }

        my @modified;
        if ($self->isMultiCal) {
            my %prefMap = (Title           => [qw /Title TitleAlignment/],
                           Header          => [qw /Header HeaderAlignment/],
                           Footer          => [qw /Footer FooterAlignment/],
                           SubFooter       => [qw /SubFooter
                                                   SubFooterAlignment/],
                           BackgroundImage => [qw /BackgroundImage/]);

            @modified = $self->removeIgnoredPrefs (map   => \%prefMap,
                                                   prefs => \%newPrefs);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%captions);
        }

        # Set prefs for each specified calendar
        foreach (@$calendars) {
            $self->saveForAuditing ($_, \%newPrefs);
            $self->dbByName ($_)->setPreferences (\%newPrefs);
        }
        $self->{audit_formsaved}++;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Title, Header, Footer'),
                              class  => 'AdminHeaderPage',
                              op     => $self);
    print '<center>';

    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Title, Header, Footer');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Header & Footer');
    }
    print '<br>';

    print "<h3>$message</h3>" if $message;
    print '</center>';

    # Get the prefs we've already got
    my $title     = $preferences->Title;
    my $header    = $preferences->Header;
    my $footer    = $preferences->Footer;
    my $subFooter = $preferences->SubFooter;
    my $titleAlign     = $preferences->TitleAlignment     || 'center';
    my $headerAlign    = $preferences->HeaderAlignment    || 'center';
    my $footerAlign    = $preferences->FooterAlignment    || 'center';
    my $subFooterAlign = $preferences->SubFooterAlignment || 'center';
    my $bgImage     = $preferences->BackgroundImage || '';
    $bgImage =~ s-^([^/])-/$1-; # leading /

    if (!defined $calendars->[0]) {
        $title = '';
    }

    print startform;

    # If group, allow selecting any calendar we have Admin permission for
    my $calSelector;
    my %onChange = ();
    if ($self->isMultiCal) {
        ($calSelector, $message) = $self->calendarSelector;
        print $message if $message;

        foreach (@names) {
            $onChange{$_} = $self->getOnChange ($_);
        }
    }

    my $titleRow;
    my $alignString = $i18n->get ('Align') . ': ';
    my $alignValues = ['Left', 'Center', 'Right'];
    my $alignLabels = {Left   => $i18n->get ('Left'),
                       Center => $i18n->get ('Center'),
                       Right  => $i18n->get ('Right')};


    my $numRows = 7;

    if (!$self->isSystemOp) {
        $titleRow = Tr ($self->groupToggle (name  => 'Title',
                                            bg    => '#f0f0f0'),
                        td ({-align => 'right'},
                            b ($i18n->get ('Title') . ': ')),
                        td (textarea (-name => 'Title',
                                      -rows    => $numRows,
                                      -columns => 40,
                                      -default => $title,
                                      -override => $override,
                                      -onChange => $onChange{Title},
                                      -wrap    => 'OFF')),
                        td ({align => 'right'}, $alignString),
                        td ({align => 'left'},
                            popup_menu ('-name'    => 'TitleAlignment',
                                        '-default' => $titleAlign,
                                        '-values'  => $alignValues,
                                        -override  => $override,
                                        -onChange  => $onChange{Title},
                                        '-labels'  => $alignLabels)));
    }

    my ($setAlljs, $setAllRow) = $self->setAllJavascript;
    $setAllRow = Tr (td ({-align   => 'center',
                          -bgcolor => '#f0f0f0'}, $setAllRow)) if $setAllRow;

    print $calSelector if $calSelector;
    print $setAlljs;
    print table ($titleRow || '',
                 Tr ($self->groupToggle (name => 'Header',
                                         bg   => '#f0f0f0'),
                     td ({-align => 'right'},
                         b ($i18n->get ('Header') . ': ')),
                     td (textarea (-name => 'Header',
                                   -rows    => $numRows,
                                   -columns => 40,
                                   -default => $header || '',
                                   -override => $override,
                                   -onChange => $onChange{Header},
                                   -wrap    => 'OFF')),
                     td ({align => 'right'}, $alignString || ''),
                     td ({align => 'left'},
                         popup_menu ('-name'    => 'HeaderAlignment',
                                     '-default' => $headerAlign,
                                     '-values'  => $alignValues,
                                     -override  => $override,
                                     -onChange  => $onChange{Header},
                                     '-labels'  => $alignLabels))),
                 Tr ($self->groupToggle (name => 'Footer',
                                         bg   => '#f0f0f0'),
                     td ({-align => 'right'},
                         b ($i18n->get ('Footer') . ': ')),
                     td (textarea (-name => 'Footer',
                                   -rows    => $numRows,
                                   -columns => 40,
                                   -default => $footer || '',
                                   -override => $override,
                                   -onChange => $onChange{Footer},
                                   -wrap    => 'OFF')),
                     td ({align => 'right'}, $alignString),
                     td ({align => 'left'},
                         popup_menu ('-name'    => 'FooterAlignment',
                                     '-default' => $footerAlign,
                                     '-values'  => $alignValues,
                                     -override  => $override,
                                     -onChange  => $onChange{Footer},
                                     '-labels'  => $alignLabels))),
                 Tr ($self->groupToggle (name => 'SubFooter',
                                         bg   => '#f0f0f0'),
                     td ({-align => 'right'},
                         b ($i18n->get ('Sub-Footer') . ': ')),
                     td (textarea (-name => 'SubFooter',
                                   -rows    => $numRows,
                                   -columns => 40,
                                   -default => $subFooter || '',
                                   -override => $override,
                                   -onChange => $onChange{SubFooter},
                                   -wrap    => 'OFF')),
                     td ({align => 'right'}, $alignString),
                     td ({align => 'left'},
                         popup_menu (-name     => 'SubFooterAlignment',
                                     -default  => $subFooterAlign,
                                     -values   => $alignValues,
                                     -override => $override,
                                     -onChange => $onChange{SubFooter},
                                     -labels   => $alignLabels))),
                 Tr ($self->groupToggle (name => 'BackgroundImage',
                                         bg   => '#f0f0f0'),
                     td ({-align => 'right'},
                         b ($i18n->get ('Background Image') . ': ')),
                     td (textfield (-name   => 'BackgroundImage',
                                   -size    => 42,
                                   -override => $override,
                                   -onChange  => $onChange{BackgroundImage},
                                   -default => $bgImage || '')),
                    td ({-colspan => 2},
                        '<small>' .
                        $i18n->get ('Enter the path to an image, starting '  .
                                    'from the web-server\'s document root. ' .
                                    'For example: ' .
                                    '<b>/images/back1.gif</b></small>'))),
                $setAllRow);

    print '<hr>';

    print submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset  (-value => 'Reset');

    print $self->hiddenParams;

    print endform;

    print '<br><b>' . $i18n->get ('Notes') . ':</b>';
    my $notes = $i18n->get ('AdminHeader_Notes');
    if ($notes eq 'AdminHeader_Notes') {
        $notes = '<ul>';
        $notes .= qq (<li>You can use HTML in these settings; e.g.
                     &nbsp;&lt;b&gt;My Calendar&lt;/b&gt;&nbsp; would display
                     in bold - <b>My Calendar</b></li>);
        $notes .= qq (<li>The Sub-Footer appears at the very bottom of the
                      calendar, below any menus.</li>);
        $notes .= q  (<li>The Title, Header, and Footers can include special
                      strings:<blockquote>
                      <table border="1" cellpadding="4">
                      <th>String</th><th>Produces</th>
                      <tr><td>$calname</td><td>calendar name</td></tr>
                      <tr><td>$user</td>   <td>logged in user name, if any</td></tr>
                      <tr><td>$date</td><td>the displayed date</td></tr>
                      <tr><td>$year</td>   <td>year part of date</td></tr>
                      <tr><td>$month</td>  <td>month part of date</td></tr>
                      <tr><td>$day</td>    <td>day part of date</td></tr>
                      <tr><td>$categoryChooser</td>
                          <td>controls to hide/show events by category.</td>
                      </tr></table>
                      <br/>The category chooser displays checkboxes,
                      one for each category; the checkboxes control
                      whether events in that category are displayed or
                      not. A number can be appended to
                      "$categoryChooser" to have it display a table of
                      checkboxes, instead of a single row. The number
                      is how many columns to use in the table;
                      e.g. "$categoryChooser_4" would display the
                      categories in 4 columns.</blockquote>);
        $notes .= '</ul>'; } print $notes;

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
