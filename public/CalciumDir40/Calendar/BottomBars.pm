# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# This guy is for the selection bars at the bottom of the screen

package BottomBars;
use strict;
use CGI (':standard');
use Calendar::Defines;
use Calendar::Javascript;

# Pass op, date, identifying name
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my ($operation, $date, $name) = @_;

    $name ||= '';
    $self->{_name} = $name;

    my ($amount, $navType, $type) = $operation->ParseDisplaySpecs;
    my ($displayTable, $navTable, $calTable, $optsTable, $baseHref, $href);

    my $prefs    = $operation->prefs;
    my $username = $operation->getUsername;

    # See which menus, if any, we want
    my $whichMenus = $prefs->BottomBars || '';
    return unless ($whichMenus or $username);

    my $i18n = $operation->I18N;

    # normalize, for popup matching
    $amount = ucfirst ($amount);
    $type   = ucfirst ($type);
    $type = 'TimePlan' if ($type eq 'Timeplan');

    # OK, make the Display, Navigation, and Calendar menus

    my (%theHash, @order);

    # Display menu
    if ($whichMenus =~ /display/i) {
        my @amountValues = qw /Day Week Month Quarter Year/;

        my $showFiscal = $prefs->MenuItemFiscal || 'always';
        if ($showFiscal !~ /never/i) {
            push @amountValues, qw /FPeriod FQuarter FYear/;
        }

        # if currently in planner view, only allow Day and Week
        if ($type =~ /planner/i) {
            @amountValues = qw /Week Day/;
        } elsif ($type =~ /timeplan/i) { # time plan only up to month
            @amountValues = qw /Day Week Month/;
        }

        my @typeValues = qw /Block List Condensed TimePlan/;
        # if any included cals, maybe add planner view
        if ($prefs->getIncludedCalendarNames) {
            my $showPlanner = $prefs->MenuItemPlanner || 'always';
            if ($showPlanner !~ /never/i
                and $showPlanner =~ /always/i
                or ($showPlanner =~ /add/i and
                    $operation->permission->permitted ($username, 'Add'))
                or ($showPlanner =~ /admin/i and
                    $operation->permission->permitted ($username, 'Admin'))) {
                push @typeValues, 'Planner';
            }
        }

        # Be careful w/quoting; older versions of CGI.pm don't autoescape
        # in forms, so "BBDisplay" won't work.

        # On change, get values and do a GET, not a POST, so can reload
        # from popups w/out annoying "are you aure?" messages from browser
        my $getURL = $operation->makeURL ({Op     => 'ShowIt',
                                           Amount => undef,
                                           Type   => undef});
        my $formName = "BBDisplay$name";
        my $jsName   = "bottomSubmit$name";
        my $onChangeJS = qq {$jsName ()};
        $self->{html} .=<<ENDJS;
<script language="Javascript"><!--
function $jsName () {
    var amt = document.forms['$formName'].elements[0];
    var typ = document.forms['$formName'].elements[1];
    var xtra = '';
    xtra = xtra + '&' + amt.name + "=" + amt.options[amt.selectedIndex].value;
    xtra = xtra + '&' + typ.name + "=" + typ.options[typ.selectedIndex].value;
    window.location = '$getURL' + xtra;
}
//--></script>
ENDJS

        my %amountLabels = (Year     => $i18n->get ('Year'),
                            Quarter  => $i18n->get ('Quarter'),
                            Month    => $i18n->get ('Month'),
                            Week     => $i18n->get ('Week'),
                            Day      => $i18n->get ('Day'),
                            FYear    => $i18n->get ('Fiscal Year'),
                            FQuarter => $i18n->get ('Fiscal Quarter'),
                            FPeriod  => $i18n->get ('Fiscal Period'));

        my $amt = popup_menu (-name     => 'Amount',
                              -override => 1,
                              -default  => $amount,
                              -onchange => $onChangeJS,
                              -values   => \@amountValues,
                              -labels   => \%amountLabels);
        my %typeLabels = (Block     => $i18n->get ('Block'),
                          List      => $i18n->get ('List'),
                          Condensed => $i18n->get ('Condensed'),
                          TimePlan  => $i18n->get ('Time Plan'),
                          Planner   => $i18n->get ('Planner'));
        my $typ = popup_menu (-name     => 'Type',
                              -override => 1,
                              -default  => $type,
                              -onchange => $onChangeJS,
                              -values   => \@typeValues,
                              -labels   => \%typeLabels);
        my $goButton = '<noscript>' . submit (-name => 'Go') . '</noscript>';
        $displayTable  = startform (-style => 'margin-bottom: 0',
                                    -name  => $formName);
        $displayTable .= table (Tr (td ($amt), td ($typ), td ($goButton)));
        $displayTable .= hidden (-name  => 'CalendarName',
                                 -value => $operation->calendarName);
        delete $operation->{params}->{CookieParams};
        delete $operation->{params}->{IsPopup};
        $displayTable .= $operation->hiddenDisplaySpecs;
        $displayTable .= endform;
    }

    # Navigation Bar menu (but don't display if no nav bar displayed)
    if ($whichMenus =~ /navbar/i and $prefs->NavBarSite !~ /neither/i) {
        $baseHref = $operation->makeURL ({Op      => 'ShowIt',
                                          CookieParams => undef,
                                          IsPopup      => undef,
                                          Date    => $date,
                                          Amount  => $amount,
                                          NavType => undef,
                                          Type    => $type});
        %theHash = ('Absolute' => $baseHref . "&NavType=Absolute",
                    'Relative' => $baseHref . "&NavType=Relative",
                    'Both'     => $baseHref . "&NavType=Both",
                    'Neither'  => $baseHref . "&NavType=Neither");
        @order = (qw (Absolute Relative Both Neither));
        $navTable = $self->_bottomBarTable (\@order, \%theHash, $i18n, $prefs,
                                            ($navType));
    }

    # Calendar menu
    if ($whichMenus =~ /cal/i) {
#         $self->{'html'}  = Javascript->SearchCalendar ($operation);
#         $self->{'html'} .= Javascript->TextFilter     ($operation);
#         $self->{'html'} .= Javascript->EventFilter    ($operation);

        $self->{html} .= Javascript->MakePopupFunction
                            ($operation->makeURL ({Op => 'AdminPageUser'}),
                             'UserOptions', 500, 450);
        $self->{html} .= Javascript->MakePopupFunction
                            ($operation->makeURL ({Op => 'PrintView'}),
                             'Print', 500, 450);

        my $showDay = $operation->makeURL ({Op => 'ShowDay',
                                            Date => $date});

        %theHash = (#'Search'       => 'JavaScript:SearchCalendar()',
                    #'Text Filter'  => 'JavaScript:TextFilter()',
                    #'Event Filter' => 'JavaScript:EventFilter()',
                    'Print' => $operation->makeURL ({Op => 'PrintView'}),

                    'Approve Events' =>
                                $operation->makeURL ({Op => 'ApproveEvents'}),
                    'Settings'   => $operation->makeURL ({Op => 'AdminPage'}),
                    'Options'    => $operation->makeURL ({Op =>
                                                          'AdminPageUser'}),
                    'Add'        => $showDay,
                    'Add/Edit'   => $showDay);

#        my %JSLink = (Options => 'JavaScript:UserOptionsPopup()');
        my %JSLink = (Options => 'JavaScript:UserOptionsPopup()',
                      Print   => 'JavaScript:PrintPopup()',
                     );
        $theHash{JSLinks} = \%JSLink;

#        @order = ('Search', 'Text Filter', 'Event Filter');
        @order = ('Options');
        push @order, 'Settings'
            if ($operation->permission->permitted ($username, 'Admin'));
        if ($operation->permission->permitted ($username, 'Edit')) {
            unshift @order, 'Add/Edit';
            if ($prefs->TentativeSubmit) {
                push @order, 'Approve Events';
            }
        } elsif ($operation->permission->permitted ($username, 'Add')) {
            unshift @order, 'Add';
        }
        unshift @order, 'Print' if (@order < 3);
        $calTable = $self->_bottomBarTable (\@order, \%theHash, $i18n, $prefs);
    }

    # System Options menu
    if ($whichMenus =~ /sys/i) {
        $self->{'html'} .= Javascript->SelectCalendar ($operation);
        %theHash = ();
        @order = ();
        my $showHome = $prefs->MenuItemHome || 'always';
        if ($showHome !~ /never/i and
            ($showHome =~ /always/i
             or ($showHome =~ /add/i and
                 $operation->permission->permitted ($username, 'Add'))
             or ($showHome =~ /admin/i and
                 $operation->permission->permitted ($username, 'Admin')))) {
            %theHash = ('Home' => $operation->makeURL ({PlainURL => 1,
                                                      CalendarName => undef}));
            @order = ('Home');
        }
        my $admin = 'Administer';
        if (Defines->multiCals) {
            $admin = 'Admin';
            $theHash{'Select Calendar'} = $operation->makeURL
                                                    ({Op => 'SelectCalendar'});
            my $width  = $prefs->SelectCalPopupWidth   || 25;
            my $height = $prefs->SelectCalPopupHeight  || 40;
            $theHash{JSLinks} = {'Select Calendar'=>
                                  "JavaScript:SelectCalendar($width,$height)"};
            push @order, 'Select Calendar';
        }
        if (Permissions->new(MasterDB->new)->permitted ($username, 'Admin')) {
            push @order, $admin;
            $theHash{$admin} = $operation->makeURL ({Op => 'SysAdminPage',
                                                     CalendarName => undef});
        }
        if ($username) {
            if ($operation->getUser->internallyAuthenticated) {
                push @order, 'Logout';
                $theHash{'Logout'} = $operation->makeURL({Op => 'UserLogout'});
            }
        } else {
            push @order, 'Login';
            my $params = $operation->mungeParams (CalendarName =>
                                                  $operation->calendarName);
            $theHash{'Login'} = $operation->makeURL ({Op        => 'UserLogin',
                                                      DesiredParams => $params,
                                                      DesiredOp =>
                                                          $operation->opName});
        }
        $optsTable = $self->_bottomBarTable (\@order, \%theHash, $i18n,$prefs);
    }

    my $userlink;
    if ($username) {
        if ($operation->getUser->internallyAuthenticated) {
            my $url = $operation->makeURL ({Op     => 'UserOptions',
                                            NextOp => 'ShowIt'});
            $userlink = a ({href => $url}, "$username");
        } else {
            $userlink = $username;
        }
    }

    my @menus;
    foreach ($displayTable, $navTable, $calTable, $optsTable) {
        push @menus, $_ if $_;
    }

    my @labels;
    push @labels, 'Display'        if $displayTable;
    push @labels, 'Navigation Bar' if $navTable;
    push @labels, 'This Calendar'  if $calTable;
    push @labels, 'System Options' if $optsTable;

    my @corners;
    foreach my $label (@labels) {
        push @corners, td ({-class => 'BottomBarLabel',
                            -align => 'right'},
                           $i18n->get ($label) . ':');
        push @corners, td ({-align => 'left'}, shift @menus);
    }

    my $offset = $prefs->Timezone || '0';
    my $offString = '';
    if ($offset) {
        my $hours = $offset == 1 ? 'hour' : 'hours';
        $offString = small ($i18n->get ('Time offset') .
                            ": $offset " . $i18n->get ($hours));
    }
    if ($username) {
        my $usertd = td ({-colspan => 2},
                         [small (i ($i18n->get ("Current User:"))) . ' ' .
                          small ($userlink) .
                          "&nbsp;&nbsp;$offString"
                         ]);
        push @corners, $usertd;
    } elsif (defined $prefs->Timezone) {
        push @corners, td ({-colspan => 2}, $offString);
    }

    my @rows;
    if ($corners[0] or $corners[1] or $corners[2] or $corners[3]) {
        push @rows, Tr ($corners[0] || '', $corners[1] || '',
                        $corners[2] || '', $corners[3] || '');
    }
    if ($corners[4] or $corners[5] or $corners[6] or $corners[7]) {
        push @rows, Tr ($corners[4] || '', $corners[5] || '',
                        $corners[6] || '', $corners[7] || '');
    }
    if ($corners[8]) {
        push @rows, Tr ($corners[8]);
    }
    $self->{html} .= table ({-align => 'center'}, @rows);
#     $self->{'html'} .= table ({-align => 'center'},
#                               Tr ($corners[0] || '', $corners[1] || '',
#                                   $corners[2] || '', $corners[3] || ''),
#                               Tr ($corners[4] || '', $corners[5] || '',
#                                   $corners[6] || '', $corners[7] || ''),
#                               Tr ($corners[8] || ''));

# Uncomment following (and comment above) for 1 menu per line.
#     $self->{'html'} .= table (#{-width => (@labels > 1) ? '100%' : ''},
#                           {-align => 'center'},
#                               Tr ($corners[0] || '', $corners[1] || ''),
#                               Tr ($corners[2] || '', $corners[3] || ''),
#                               Tr ($corners[4] || '', $corners[5] || ''),
#                               Tr ($corners[6] || '', $corners[7] || ''),
#                               Tr ($corners[8] || ''));

    $self;
}

sub getHTML {
    my $self = shift;
    my $html = '<div class="BottomBars">';
    $html .= qq (<div class="$self->{_name}">) if $self->{_name};
    $html .= "\n$self->{html}\n";
    $html .= '</div>' if $self->{_name};
    $html .= "</div>\n";
    return $html;
}

# Pass a hash with (link text => link) pairs, and a list of which items are
# currently selected (and thus aren't links and a diff. color)
sub _bottomBarTable {
    my $self = shift;
    my ($order, $linkHash, $i18n, $prefs, @selected) = @_;

    my $html;

    my $tds;

    my $JSLink = $linkHash->{JSLinks} || {};

    foreach my $linkText (@$order) {
        my $selected = grep /$linkText/i, @selected;
        my $space    = $linkText eq '&nbsp;';
        my $text18  = $i18n->get ($linkText);
        my $stuff;
        if ($selected) {
            $stuff = $text18;
        } else {
            if ($space) {
                $stuff = "<small>$text18</small>";
            } else {
                if ($JSLink->{$linkText}) {
                    $text18 =~ s/'/\\'/g;
                    $text18 =~ s/"/\\"/g;
                }
                if (!$JSLink->{$linkText}) {
                    $stuff = a ({-href => $linkHash->{$linkText}}, $text18);
                } else {
                    $stuff = "\n" . qq (<script language="javascript">
                                 document.write (
                                '<a href="$JSLink->{$linkText}">$text18</a>')
                                 </script>);
                    $stuff .= "\n";
                    $stuff .= qq (<noscript>
                                  <a href="$linkHash->{$linkText}">$text18</a>
                                  </noscript>);
                    $stuff .= "\n";
                }
            }
        }

        $tds .= td ({-class   => ($selected ? 'BottomItemSelected'
                                            : 'BottomItem'),
                     -align   => 'center'},
                    $stuff);
    }

    $html = table ({width       => '100%',
                    border      => 0,
                    cellpadding => 6,
                    cellspacing => 0},
                   Tr ($tds));
    $html;
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css;
    my ($face, $size) = $prefs->font ('BottomBars');

    $css.= Operation->cssString ('.BottomBars',
                {color              => $prefs->color ('BottomBarFG'),
                 'font-family' => $face,
                 'font-size'   => $size});

    $css .= Operation->cssString ('.BottomItem',
                {'background-color' => $prefs->color ('BottomBarBG'),
                 color              => $prefs->color ('BottomBarFG')});
    $css .= Operation->cssString ('.BottomItemSelected',
                {'background-color' => $prefs->color ('BottomBarSelectedBG'),
                 color              => $prefs->color ('BottomBarSelectedFG')});

    $css.= Operation->cssString ('.BottomBars select',
                     {'background-color' => $prefs->color ('BottomBarBG')});

    $css.= Operation->cssString ('.BottomItem A:link',
                             {color => $prefs->color ('BottomBarFG')});
    $css.= Operation->cssString ('.BottomItem A:visited',
                             {color => $prefs->color ('BottomBarFG')});
    $css .= Operation->cssString ('.BottomBarLabel',
                              {color => $prefs->color ('MainPageFG'),
                               'font-weight' => 'bold'});

    return $css;
}

1;
