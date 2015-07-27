# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# PrintView - form to specify parameters for printing view

package PrintView;
use strict;
use CGI (':standard');
use Calendar::GetHTML;
use Calendar::Javascript;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($doIt, $cancel, $color, $title, $headFoot,
        $dateHeader, $background, $isPopup, $setOpener) =
        $self->getParams (qw (DoIt Cancel Color Title HeaderFooter DateHeader
                              Background IsPopup SetOpener));

    my $cgi = new CGI;
    my $calName = $self->calendarName;

    # if cancelled, go back
    if ($cancel) {
        my $doneURL = $self->makeURL ({Op => 'AdminPageUser'});

        if (!$setOpener) {
            print $self->redir ($doneURL);
            return;
        }

        my $url = $self->makeURL ({Op          => 'ShowIt',
                                   CookieParams => 1,
                                   IsPopup      => undef});

        # Set opener back to regular view
        print GetHTML->startHTML (title   => $i18n->get ('Print View'),
                                  op      => $self,
                                  Refresh => "0; URL=$doneURL");
        print Javascript->SetLocation;
        print qq {
                  <script language="JavaScript"><!--
                  SetLocation (self.opener, '$url')
                  // --></script>
                 };
        print '<center>';
        print $cgi->h1 ($i18n->get('Displaying calendar...'));
        print $cgi->p ($i18n->get ('Click') . ' ' .
                       $cgi->a ({href => $url}, $i18n->get ('here'))
                       . ' '.
                       $i18n->get ('to continue, or just wait ' .
                                   'a second...'));
        print '</center>';
        print $cgi->end_html;
        return;
    }

    my $setOpenerHTML;
    my $cookie;

    if ($doIt)  {
        $self->{audit_formsaved}++;
        my $head = ($headFoot =~ /h/);
        my $foot = ($headFoot =~ /f/);
        my $url = $self->makeURL ({Op              => 'ShowIt',
                                   PrintView       => 1,
                                   PrintColors     => $color,
                                   PrintTitle      => $title,
                                   PrintHeader     => $head,
                                   PrintFooter     => $foot,
                                   PrintDateHeader => $dateHeader,
                                   PrintBackground => $background,
                                   CookieParams    => 1,
                                   IsPopup         => undef
                                  });

        # Write cookie with prefs
        my %vals;
        $vals{Color}        = $color;
        $vals{Title}        = $title;
        $vals{HeaderFooter} = $headFoot;
        $vals{DateHeader}   = $dateHeader;
        $vals{Background}   = $background;
        my @vals;
        while (my ($name, $val) = each %vals) {
            $val ||= 0;
            push @vals, "$name-$val";
        }
        $cookie = $cgi->cookie (-name    => 'CalciumPrintPrefs',
                                -value   => join ('-', @vals),
                                -expires => '+1y');

        if ($isPopup) {
            $setOpenerHTML = Javascript->SetLocation;
            $setOpenerHTML .= qq {
                                  <script language="JavaScript"><!--
                                  SetLocation (self.opener, '$url')
                                  // --></script>
                                 };
            $setOpener++;
        } else {
            print $self->redir ($url);
            return;
        }
    }

    # Get cookie vals for prefs
    my $prefCookie = $cgi->cookie ('CalciumPrintPrefs') || '';
    my %defaults = split '-', $prefCookie;

    print GetHTML->startHTML (title  => $i18n->get ('Print View Settings'),
                              class  => 'PrintViewOptions',
                              op     => $self,
                              cookie => $cookie);

    print $setOpenerHTML if $setOpenerHTML;

    print '<div class="PopupMenuWindow">'
        if ($isPopup);

    print GetHTML->PageHeader ($i18n->get ('Print Options: ') .
                               '<font color="blue">' . "$calName</font>");
    print $cgi->startform;

    my @rows;
    push @rows, $cgi->Tr ($cgi->td ('Colors:'),
                          $cgi->td ($cgi->popup_menu
                                    (-name => 'Color',
                                     -labels => {none => 'Black and white',
                                                 some => 'Some color',
                                                 all  => 'Full color'},
                                     -values => [qw /none some all/],
                                     -default => $defaults{Color})));
    push @rows, $cgi->Tr ($cgi->td ('Title:'),
                          $cgi->td ($cgi->popup_menu (-name => 'Title',
                                                      -labels => {0 => 'Hide',
                                                                  1 => 'Show'},
                                                      -values => [1, 0],
                                                      -default =>
                                                           $defaults{Title})));
    push @rows, $cgi->Tr ($cgi->td ('Header/Footer:'),
                          $cgi->td ($cgi->popup_menu (-name => 'HeaderFooter',
                      -labels => {n  => $i18n->get ('No Header or Footer'),
                                  h  => $i18n->get ('Show Header only'),
                                  f  => $i18n->get ('Show Footer only'),
                                  hf => $i18n->get ('Show Header and Footer')},
                      -values => [qw/hf n h f/],
                     -default => $defaults{HeaderFooter})));

    push @rows, $cgi->Tr ($cgi->td ('Date Header:'),
                          $cgi->td ($cgi->popup_menu (-name => 'DateHeader',
                                                      -labels => {0 => 'Hide',
                                                                  1 => 'Show'},
                                                      -values => [1, 0],
                                          -default => $defaults{DateHeader})));
    if (defined $self->prefs->BackgroundImage) {
        push @rows, $cgi->Tr ($cgi->td ('Background Image:'),
                              $cgi->td ($cgi->popup_menu
                                        (-name => 'Background',
                                         -labels => {0 => 'Hide',
                                                     1 => 'Show'},
                                         -values => [1, 0],
                                         -default => $defaults{Background})));
    }

    print $cgi->table (@rows);

    print '<hr width="50%">';

    print $cgi->submit (-name  => 'DoIt',
                        -value => $i18n->get ('Display Printable View'));
    print '&nbsp;&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));

    print $cgi->hidden (-name => 'Op',           -value => 'PrintView');
    print $cgi->hidden (-name => 'CalendarName', -value => $calName)
        if $calName;
    print $cgi->hidden (-name => 'SetOpener',    -value => $setOpener)
        if $setOpener;
    print $self->hiddenDisplaySpecs;

    print $cgi->endform;

    print '<br>';
    print '<b>' . $i18n->get ('Notes') . ':</b>';
    print '<ul>';
    if (!$isPopup) {
        print '<li>', ($i18n->get ("To print, press the 'Display' button " .
                                   "above, then use your browser's print " .
                                   "function to print the page. You can "  .
                                   "then use the 'Back' button on your "   .
                                   "browser to return here."));
    }
    print '</li>';
    print '<li>', ($i18n->get ("If you have color images in your header, " .
                               "footer, background, or in an event, they'll " .
                               "still appear in color even if you specify "   .
                               "'Black and White'."));
    print '</li>';

    print '</div>' if ($isPopup);  # for <div class="PopupMenuWindow">

    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line =  $self->SUPER::auditString ($short);
}

1;
