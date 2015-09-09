# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Colors Options - title, time format, etc.
package AdminColors;
use strict;
use CGI (':standard');

use Calendar::Date;
use Calendar::GetHTML;
use Calendar::Javascript;

use vars ('@ISA');
@ISA = ('Operation');

# This Operation can be performed on a Calendar OR the Master DB

# This is pretty obnoxious. First, we get called with just the Calendar
# Name. When we change a color, we add on Params to specify what item we're
# changing (Item), and the FG and BG colors we're changing it to. We also
# need to pass along *all* the other color prefs, since we may have already
# changed them too, and we don't write anything out to the DB until 'save'
# is pressed.

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($item, $bg, $fg, $preset, $loadPreset, $save, $cancel) =
               $self->getParams (qw (Item BG FG Presets LoadPreset
                                     Save Cancel));

    my ($calName) = $self->calendarName;        # will be undef for MasterDB

    my @fieldNameList = qw (Title Header Footer MainPage WeekHeader DayHeader
                            Today Event Link Popup PopupDate);

    my $preferences = $self->prefs;
    my %copy = %{$preferences->Colors};        # save orig colors for auditing

    undef $preset if ($preset and $preset eq '-');

    my %presets = (Corporate => {BannerShadowBG      => 'black',
                                 BannerShadowFG      => 'white',
                                 BottomBarBG         => 'gray',
                                 BottomBarSelectedBG => '#C8D7E5',
                                 DayHeaderBG         => '#5F829E',
                                 DayViewControlsBG   => '#D4D4D4',
                                 EventBG             => '#CCCCCC',
                                 FooterBG            => '#D4D4D4',
                                 HeaderBG            => '#D4D4D4',
                                 LinkBG              => '#CCCCCC',
                                 ListViewDateBG      => '#4D7DA9',
                                 ListViewDayBG       => '#C8D7E5',
                                 ListViewEventBG     => '#CCCCCC',
                                 ListViewPopupBG     => '#999999',
                                 MainPageBG          => '#BCBCBC',
                                 MonthTailBG         => '#999999',
                                 NavLabelBG          => '#999999',
                                 NavLinkBG           => '#999999',
                                 PopupBG             => '#BCBCBC',
                                 PopupDateBG         => '#4D7DA9',
                                 TitleBG             => '#C8D7E5',
                                 TodayBG             => '#FC5555',
                                 VLinkBG             => '#CCCCCC',
                                 WeekHeaderBG        => '#004584',
                                 WeekHeaderFG        => 'white',
                                },
                   Spring    => {BannerShadowBG      => 'black',
                                 BannerShadowFG      => 'white',
                                 BottomBarBG         => '#CCCCCC',
                                 BottomBarSelectedBG => '#CAA8A7',
                                 DayHeaderBG         => '#AAB594',
                                 DayViewControlsBG   => '#CCCCCC',
                                 EventBG             => 'white',
                                 FooterBG            => '#F9ECB7',
                                 HeaderBG            => '#F9ECB7',
                                 LinkBG              => 'white',
                                 ListViewDateBG      => '#79926F',
                                 ListViewDayBG       => '#AAB594',
                                 ListViewEventBG     => 'white',
                                 ListViewPopupBG     => '#CCCCCC',
                                 MainPageBG          => '#F2E7E3',
                                 MonthTailBG         => '#CCCCCC',
                                 NavLabelBG          => '#CCCCCC',
                                 NavLinkBG           => '#cccccc',
                                 PopupBG             => '#F2E7E3',
                                 PopupDateBG         => '#F9ECB7',
                                 TitleBG             => '#DBF1FF',
                                 TodayBG             => '#CAA8A7',
                                 VLinkBG             => 'white',
                                 WeekHeaderBG        => '#79926F',
                                },
                   Summer    => {BannerShadowBG      => 'black',
                                 BannerShadowFG      => 'white',
                                 BottomBarBG         => '#CCCCCC',
                                 BottomBarSelectedBG => '#CB111F',
                                 DayHeaderBG         => '#8F364A',
                                 DayHeaderFG         => 'white',
                                 DayViewControlsBG   => '#CCCCCC',
                                 EventBG             => 'white',
                                 FooterBG            => '#1A7280',
                                 HeaderBG            => '#1A7280',
                                 LinkBG              => 'white',
                                 ListViewDateBG      => '#3B3362',
                                 ListViewDateFG      => 'white',
                                 ListViewDayBG       => '#8F364A',
                                 ListViewEventBG     => 'white',
                                 ListViewPopupBG     => '#CCCCCC',
                                 MainPageBG          => 'gray',
                                 MonthTailBG         => '#CCCCCC',
                                 NavLabelBG          => 'gray',
                                 NavLinkBG           => '#CCCCCC',
                                 PopupBG             => 'white',
                                 PopupDateBG         => '#3B3362',
                                 PopupDateFG         => 'white',
                                 TitleBG             => '#1A7280',
                                 TodayBG             => '#CB111F',
                                 VLinkBG             => 'white',
                                 WeekHeaderBG        => '#3B3362',
                                 WeekHeaderFG        => 'white',
                                },
                   Autumn    => {BannerShadowBG      => 'black',
                                 BannerShadowFG      => '#A8A377',
                                 BottomBarBG         => '#CCCCCC',
                                 BottomBarSelectedBG => '#CB111F',
                                 DayHeaderBG         => '#D96226',
                                 DayViewControlsBG   => '#CCCCCC',
                                 EventBG             => '#A8A377',
                                 FooterBG            => '#AA5633',
                                 HeaderBG            => '#E8B273',
                                 LinkBG              => '#A8A377',
                                 ListViewDateBG      => '#E8B273',
                                 ListViewDayBG       => '#D96226',
                                 ListViewEventBG     => '#A8A377',
                                 ListViewPopupBG     => 'gray',
                                 MainPageBG          => '#929F8A',
                                 MonthTailBG         => 'gray',
                                 NavLabelBG          => 'gray',
                                 NavLinkBG           => '#CCCCCC',
                                 PopupBG             => '#A8A377',
                                 PopupDateBG         => '#929F8A',
                                 TitleBG             => '#6AACD0',
                                 TodayBG             => '#FAB338',
                                 VLinkBG             => '#A8A377',
                                 WeekHeaderBG        => '#E8B273',
                                },
                   Winter    => {BannerShadowBG      => 'blank',
                                 BannerShadowFG      => '#CCCCCC',
                                 BottomBarBG         => '#CCCCCC',
                                 BottomBarSelectedBG => '#173250',
                                 BottomBarSelectedFG => 'white',
                                 DayHeaderBG         => '#2F4E6B',
                                 DayHeaderFG         => 'white',
                                 DayViewControlsBG   => '#CCCCCC',
                                 EventBG             => '#E0E9FF',
                                 FooterBG            => '#CDDAFA',
                                 HeaderBG            => '#CDDAFA',
                                 LinkBG              => '#E0E9FF',
                                 ListViewDateBG      => '#173250',
                                 ListViewDateFG      => 'white',
                                 ListViewDayBG       => '#2F4E6B',
                                 ListViewDayFG       => 'white',
                                 ListViewEventBG     => '#E0E9FF',
                                 ListViewPopupBG     => '#CCCCCC',
                                 MainPageBG          => '#9BAED6',
                                 MonthTailBG         => 'gray',
                                 NavLabelBG          => 'gray',
                                 NavLinkBG           => '#CCCCCC',
                                 PopupBG             => '#E0E9FF',
                                 PopupDateBG         => '#9BAED6',
                                 TitleBG             => '#CDDAFA',
                                 TodayBG             => 'white',
                                 TodayFG             => '#2F4E6B',
                                 VLinkBG             => '#CCCCCC',
                                 WeekHeaderBG        => '#173250',
                                 WeekHeaderFG        => 'white',
                                },
                   Earth     => {BannerShadowBG      => 'black',
                                 BannerShadowFG      => '#8A6946',
                                 BottomBarBG         => 'gray',
                                 BottomBarSelectedBG => '#4B3C39',
                                 BottomBarSelectedFG => '#A3A1B6',
                                 DayHeaderBG         => '#533324',
                                 DayHeaderFG         => '#A3A1B6',
                                 DayViewControlsBG   => '#CCCCCC',
                                 EventBG             => '8A6946',
                                 FooterBG            => 'gray',
                                 HeaderBG            => '#AAAAAA',
                                 LinkBG              => '#8A6946',
                                 ListViewDateBG      => '#4B3C39',
                                 ListViewDateFG      => '#A3A1B6',
                                 ListViewDayBG       => '#533324',
                                 ListViewDayFG       => '#A3A1B6',
                                 ListViewEventBG     => '#8A6946',
                                 ListViewPopupBG     => '#A3A1B6',
                                 MainPageBG          => '#4B3C39',
                                 MonthTailBG         => '#4B3C39',
                                 NavLabelBG          => 'gray',
                                 NavLinkBG           => '#CCCCCC',
                                 PopupBG             => '#533324',
                                 PopupFG             => '#A3A1B6',
                                 PopupDateBG         => '#4B3C39',
                                 PopupDateFG         => '#A3A1B6',
                                 TitleBG             => '#AAAAAA',
                                 TodayBG             => '#2A4B6C',
                                 VLinkBG             => '#CCCCCC',
                                 WeekHeaderBG        => '#4B3C39',
                                 WeekHeaderFG        => '#A3A1B6',
                                },
                   Sky       => {BannerShadowBG      => 'black',
                                 BannerShadowFG      => 'white',
                                 BottomBarBG         => 'gray',
                                 BottomBarSelectedBG => '#FA9D4F',
                                 DayHeaderBG         => '#54B9ED',
                                 DayViewControlsBG   => '#CCCCCC',
                                 EventBG             => 'white',
                                 FooterBG            => '#35619E',
                                 HeaderBG            => '#35619E',
                                 LinkBG              => 'white',
                                 ListViewDateBG      => '#ADCCFA',
                                 ListViewDayBG       => '#54B9ED',
                                 ListViewEventBG     => 'white',
                                 ListViewPopupBG     => '#BCBCBC',
                                 MainPageBG          => '#575A6D',
                                 MainPageFG          => '#D59B87',
                                 MonthTailBG         => '#575A6D',
                                 NavLabelBG          => '#35619E',
                                 NavLinkBG           => '#ADCCFA',
                                 PopupBG             => '#ADCCFA',
                                 PopupDateBG         => '#54B9ED',
                                 TitleBG             => '#35619E',
                                 TodayBG             => '#FA9D4F',
                                 VLinkBG             => 'white',
                                 WeekHeaderBG        => '#ADCCFA',
                                },
                   Mustard =>   {BannerShadowBG      => 'black',
                                 BannerShadowFG      => '#DDCE2B',
                                 BottomBarBG         => '#E18E5A',
                                 BottomBarSelectedBG => '#CE2068',
                                 DayHeaderBG         => '#A3B53B',
                                 DayViewControlsBG   => '#ADCCFA',
                                 EventBG             => '#DDCE2B',
                                 FooterBG            => '#FA9D4F',
                                 HeaderBG            => '#FA9D4F',
                                 LinkBG              => '#DDCE2B',
                                 ListViewDateBG      => '#189E97',
                                 ListViewDayBG       => '#A3B53B',
                                 ListViewEventBG     => '#DDCE2B',
                                 ListViewPopupBG     => '#ADCCFA',
                                 MainPageBG          => '#E18E5A',
                                 MonthTailBG         => '#E18E5A',
                                 NavLabelBG          => '#35619E',
                                 NavLinkBG           => '#ADCCFA',
                                 PopupBG             => '#DDCE2B',
                                 PopupDateBG         => '#A3B53B',
                                 TitleBG             => '#CE2068',
                                 TodayBG             => '#E18E5A',
                                 VLinkBG             => '#DDCE2B',
                                 WeekHeaderBG        => '#189E97',
                                },
                  );

    # If we're saving ourself, or cancelling, save or cancel, redirect & exit.
    if ($save || $cancel) {
        if ($save) {
            my %isAFieldName;
            $self->{audit_formsaved}++;
            my %blah = %copy;
            $self->{audit_origColors} = \%blah;
            foreach (@fieldNameList) {
                my $bg = $_ . 'BG';
                my $fg = $_ . 'FG';
                ($copy{$bg} = $self->{params}->{$bg}) =~ s/\s+$//;
                ($copy{$fg} = $self->{params}->{$fg}) =~ s/\s+$//;
                $isAFieldName{$bg} = $isAFieldName{$fg} = 1;
            }

            # If using presets, set other unset colors based on them
            if ($preset) {
                my $theColors = $presets{$preset};
                if ($theColors) {
                    while (my ($pref, $color) = each %$theColors) {
                        next if $isAFieldName{$pref};
                        $copy{$pref} = $color;
                    }
                }
                foreach (qw /VLink ListViewEvent/) {
                    $copy{$_ . 'BG'} ||= $self->{params}->{EventBG};
                    $copy{$_ . 'FG'} ||= $self->{params}->{EventFG};
                }
                foreach (qw /BottomBar NavLabel DayViewControls
                             ListViewDate ListViewPopup/) {
                    $copy{$_ . 'BG'} ||= $self->{params}->{FooterBG};
                    $copy{$_ . 'FG'} ||= $self->{params}->{FooterFG};
                }
                foreach (qw /MonthTail/) {
                    $copy{$_ . 'BG'} ||= $self->{params}->{MainPageBG};
                    $copy{$_ . 'FG'} ||= $self->{params}->{MainPageFG};
                }
                foreach (qw /BottomBarSelected NavLink ListViewDay/) {
                    $copy{$_ . 'BG'} ||= $self->{params}->{EventBG};
                    $copy{$_ . 'FG'} ||= $self->{params}->{EventFG};
                }
                foreach (qw /BannerShadow/) {
                    $copy{$_ . 'BG'} ||= $self->{params}->{EventFG};
                    $copy{$_ . 'FG'} ||= $self->{params}->{EventBG};
                }
            }

            $self->db->setPreferences ({Colors => \%copy});
        }
        my $op = $calName ? 'AdminPage' : 'SysAdminPage';
        print $self->redir ($self->makeURL({Op => $op}));
        return;
    }

    my $colors;

    if ($preset and $loadPreset) {
        foreach (@fieldNameList) {
            $colors->{$_ . 'BG'} ||= 'white';
            $colors->{$_ . 'FG'} ||= 'black';
        }
        my $theColors = $presets{$preset};
        if ($theColors) {
            while (my ($pref, $color) = each %$theColors) {
                $colors->{$pref} = $color;
            }
        }
    }
    # Only need the prefs if we're not calling ourselves, with all the colors
    elsif (!$item) {
        $colors = $preferences->Colors;
        foreach (@fieldNameList) {
            $colors->{$_ . 'BG'} ||= 'black';     # assign defaults, if
            $colors->{$_ . 'FG'} ||= 'white';     #          necessary...
        }
    } else {
        # We passed ourselves all the colors
        foreach (@fieldNameList) {
            $colors->{$_ . 'BG'} = $self->{params}->{$_ . 'BG'};
            $colors->{$_ . 'FG'} = $self->{params}->{$_ . 'FG'};
        }
        # One of them is the item to change colors for; overwrite it
        $colors->{$item . 'FG'} = $fg;
        $colors->{$item . 'BG'} = $bg;
    }

    my $cgi = new CGI;

    print GetHTML->startHTML (title  => $i18n->get ('Colors') .
                                          ($calName && ": $calName" || ''),
                              op     => $self);
    print '<center>';
    if ($calName) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $calName,
                                    section => 'Color Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Color Settings');
    }
    print '</center>';

    print '<br>';

    my $helpString = $i18n->get ('AdminColors_HelpString');
    if ($helpString eq 'AdminColors_HelpString') {
        my $leadIn = "The calendar's current colors";
           $leadIn = "Default colors for newly created calendars"
                                                              unless $calName;
        ($helpString =<<"        FNORD") =~ s/^ +//gm;
            $leadIn are shown below. To change a color, enter the desired
            foreground and background colors, then click on the link for the
            item whose colors you want to change. When you are happy with the
            way things look, don't forget to click on the 'Save' button!
        FNORD
    #'
    }
    print $helpString;
    print '<br><br>';
    print '<center>';

    print startform;

    print hidden (-name => 'FromPreset', -default => 1)
        if ($preset);

    # Stick hidden fields with all the colors in
    foreach (@fieldNameList) {
        print hidden (-name     => $_ . 'FG',
                      -default  => $colors->{$_ . 'FG'},
                      -override => 1);
        print hidden (-name     => $_ . 'BG',
                      -default  => $colors->{$_ . 'BG'},
                      -override => 1);
    }
    print hidden (-name => 'Item', -value => '');

    my $today = Date->new;

    print <<'    END_JAVASCRIPT';
        <script language="JavaScript">
        <!-- hide code
            function GetColors (theItem) {
                document.forms[0].Item.value = theItem;
                document.forms[0].submit();
            }
        // end code hiding -->
        </script>
    END_JAVASCRIPT

    print table ({-width => '100%'},
                 th ([$i18n->get ('Calendar'), ' ',
                      $i18n->get ('Popup Windows')]),
                 Tr ({-valign => 'top'},

      td (table ({-width   => '100%',
                  -bgcolor => $colors->{'MainPageBG'},
                  -cellspacing => 10,
                  -border  => 1},
           Tr (td (table ({-width   => '100%', -bgcolor => '#cccccc'},
              Tr (td ({-align   => 'center',
                       -bgcolor => $colors->{'TitleBG'}},
                      a ({-href => "Javascript:GetColors('Title')"},
                         font ({-color => $colors->{'TitleFG'}},
                               $i18n->get ('Title'))))),
              Tr (td ({-align   => 'center',
                       -bgcolor => $colors->{'HeaderBG'}},
                      a ({-href => "JavaScript:GetColors('Header')"},
                         font ({-color => $colors->{'HeaderFG'}},
                               $i18n->get ('Header'))))),
              Tr (td ({align    => 'center',
                       -bgcolor => $colors->{'MainPageBG'}},
                      a ({-href => "JavaScript:GetColors('MainPage')"},
                         font ({-color => $colors->{'MainPageFG'}},
                               $i18n->get ('Background'))))),
              Tr (td (table ({-width   => '100%',
                              -columns => 7,
                              -border  => 2},
                             Tr (td ({-colspan => 7,
                                      -align   => 'center',
                                      -bgcolor => $colors->{'WeekHeaderBG'}},
                                     a ({-href =>
                                         "JavaScript:GetColors('WeekHeader')"},
                                        font ({-color =>
                                                  $colors->{'WeekHeaderFG'}},
                                     $i18n->get ('Days of the Week Names'))))),
                             Tr (td ({-width   => '14%',
                                      -align   => 'center',
                                      -bgcolor => $colors->{'DayHeaderBG'}},
                                     a ({-href =>
                                          "JavaScript:GetColors('DayHeader')"},
                                        font ({-color =>
                                                 $colors->{'DayHeaderFG'}},
                                              ($today-1)->day))),
                                 td ({-width   => '14%',
                                      -align   => 'center',
                                      -bgcolor => $colors->{'TodayBG'}},
                                     a ({-href =>
                                            "JavaScript:GetColors('Today')"},
                                        font ({-color =>
                                                  $colors->{'TodayFG'}},
                                              $i18n->get ('Today')))),
                                 td ({-width   => '14%',
                                      -align   => 'center',
                                      -bgcolor => $colors->{'DayHeaderBG'}},
                                     a ({-href =>
                                          "JavaScript:GetColors('DayHeader')"},
                                        font ({-color =>
                                                  $colors->{'DayHeaderFG'}},
                                              ($today+1)->day))),
                                 td ({-width => '14%',
                                      -align => 'center',
                                      -bgcolor => $colors->{'DayHeaderBG'}},
                                     [qw (&nbsp; &nbsp; &nbsp; &nbsp;)])),
                             Tr (td ({-width => '14%',
                                      -align => 'center',
                                      -bgcolor => $colors->{'EventBG'}},
                                     [a ({-href =>
                                          "JavaScript:GetColors('Event')"},
                                        font ({-color => $colors->{'EventFG'}},
                                              $i18n->get ('Events'))),
                                      font ({-color => $colors->{'EventFG'}},
                                            $i18n->get ('in')),
                                      font ({-color => $colors->{'EventFG'}},
                                            $i18n->get ('the')),
                                      font ({-color => $colors->{'EventFG'}},
                                            $i18n->get ('Month')),
                                      qw (<br><br>&nbsp; &nbsp; &nbsp;)])),
                             Tr (td ({-width   => '14%',
                                      -align   => 'center',
                                      -bgcolor => $colors->{'LinkBG'}},
                                     [a ({-href =>
                                          "JavaScript:GetColors('Link')"},
                                         font ({-color => $colors->{'LinkFG'}},
                                               $i18n->get ('Links'))),
                                      a ({-href =>
                                            "JavaScript:GetColors('Link')"},
                                         font ({-color => $colors->{'LinkFG'}},
                                               $i18n->get ('in'))),
                                      a ({-href =>
                                            "JavaScript:GetColors('Link')"},
                                         font ({-color => $colors->{'LinkFG'}},
                                               $i18n->get ('the'))),
                                      a ({-href =>
                                            "JavaScript:GetColors('Link')"},
                                         font ({-color => $colors->{'LinkFG'}},
                                               $i18n->get ('Month')))]),
                                 td ({-width   => '14%',
                                      -align   => 'center',
                                      -bgcolor => $colors->{'EventBG'}},
                                     [qw (<br><br>&nbsp; &nbsp; &nbsp;)]))))),
              Tr (td ({-align   => 'center',
                       -bgcolor => $colors->{'FooterBG'}},
                      a ({-href => "JavaScript:GetColors('Footer')"},
                         font ({-color => $colors->{'FooterFG'}},
                               $i18n->get ('Footer')))))))))),
          td ({-width => '5%'}, ' '),

          td (table ({-border => 1,
                      -width  => '100%',
                      -bgcolor => $colors->{'PopupBG'}},
                 Tr (td (table ({-width       => '100%',
                                 -cellspacing => 0,
                                 -border      => 0},
                            Tr (td ({-align => 'center',
                                     -bgcolor => $colors->{PopupDateBG}},
                                    a ({-href =>
                                          "JavaScript:GetColors('PopupDate')"},
                                       font ({-color =>
                                                 $colors->{'PopupDateFG'}},
                                             Date->new())))),
                            Tr (td ({-align => 'center'},
                                    a ({-href =>
                                            "JavaScript:GetColors('Popup')"},
                                       font ({-color => $colors->{'PopupFG'}},
                                 $i18n->get ('Popup text'))))))))))));

    print '<p></p>';

    print table ({-width => '80%'},
                 Tr (td ($i18n->get ('Foreground') . ': ' .
                         textfield ('-name'      => 'FG',
                                    '-default'   => 'white',
                                    '-size'      => 10,
                                    '-maxlength' => 20)),
                     td ($i18n->get ('Background') . ': ' .
                         textfield ('-name'      => 'BG',
                                    '-default'   => 'blue',
                                    '-size'      => 10,
                                    '-maxlength' => 20))));

    print '</center>';
    print '<br>';

if (1) {
    print '<center>';
    print $i18n->get ('Or, start with one of these preset palettes:') . ' ';
    print popup_menu (-name     => 'Presets',
                      -values   => ['-', 'Corporate',
                                    'Spring', 'Summer', 'Autumn', 'Winter',
                                    'Earth', 'Sky', 'Mustard']);
    print submit (-name  => 'LoadPreset',
                  -value => $i18n->get ('Load Palette'));
    print '</center>';
}

    print Javascript->ColorPalette ($self);

    print table ({-cellspacing => 10},
                 Tr (td (a ({-href => "Javascript:ColorWindow()"},
                            $i18n->get ('See Available Colors'))),
                     td (a ({-href =>
                             $self->makeURL ({Op => 'AdminColorsAlternate'})},
                            $i18n->get ('More Color Options')))));

    print '<hr><br>';
    print submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name => 'Cancel', -value => $i18n->get ('Cancel'));
    print '&nbsp;';

    print hidden (-name => 'Op',           -value => 'AdminColors');
    print hidden (-name => 'CalendarName', -value => $calName)
        if defined ($calName);
    print reset  (-value => 'Reset');

    print endform;
    print end_html;
}

sub auditString {
    my ($self, $short) = @_;
    _auditString ($self, $short); # so AdminColorsAlternate can use it too
}

sub _auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};

    my $summary =  $self->SUPER::auditString ($short);

    my $oldColors = $self->prefs->Colors;
    $oldColors = $self->{audit_origColors};
    my $newColors = ($self->prefs ('force'))->Colors;

    my (%old, %new);
    foreach my $item (sort {lc($a) cmp lc($b)} keys %$oldColors) {
        next unless $oldColors->{$item};
        next if ($oldColors->{$item} eq $newColors->{$item});
        $old{$item} = $oldColors->{$item};
        $new{$item} = $newColors->{$item};
    }

    my $message = '';
    foreach (sort keys %old) {
        if ($short) {
            $message .= "[$_ $old{$_}->$new{$_}] ";
        } else {
            $message .= "Changed $_ from '$old{$_}' to '$new{$_}'\n";
        }
    }

    if ($short) {
        return ($summary . " $message");
    } else {
        return ($summary . "\n\n$message");
    }
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
