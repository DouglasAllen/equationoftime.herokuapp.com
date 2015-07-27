# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Calendar Display Options/Settings
package AdminDisplay;
use strict;

use CGI (':standard');

use Calendar::GetHTML;
use Calendar::Date;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $done) = $self->getParams (qw (Save Cancel Group));

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    if ($done) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op    => $op}));
        return;
    }

    my @names = qw (day time display navbar weekend weeknum popup selcalpop
                    eventmodpop listviewpop mailselpop dayview daytimes menus
                    menuItems menuSite plannerself fiscal eventHTML
                    eventSorting eventTags hidetails);

    my %captions = (day         => $i18n->get ('First day of Week'),
                    time        => $i18n->get ('Time Format'),
                    display     => $i18n->get ('Default Display'),
                    navbar      => $i18n->get ('Navigation Bars'),
                    weekend     => $i18n->get ('Weekend Days'),
                    weeknum     => $i18n->get ('Week Numbers'),
                    hidetails   => $i18n->get ('Block View "Tails"'),
                    listviewpop => $i18n->get ('List View Columns'),
                    popup       => $i18n->get ('Event Popup Window'),
                    selcalpop   => $i18n->get ('"Select Calendar" Popup'),
                    eventmodpop => $i18n->get ('Event Add/Edit Popup'),
                    mailselpop  => $i18n->get ('Email Selector Popup'),
                    dayview     => $i18n->get ('Time Plan Hours'),
                    daytimes    => $i18n->get ('Time Plan - Event Times'),
                    menus       => $i18n->get ('Menu Bars to Display'),
                    menuItems   => $i18n->get ('Menu Bar Items to Display'),
                    menuSite    => $i18n->get ('Menu Bar Location'),
                    plannerself => $i18n->get ('Planner View'),
                    fiscal      => $i18n->get ('Fiscal Year'),
                    eventHTML      => $i18n->get ('HTML in Events'),
                    eventSorting   => $i18n->get ('Event Sorting'),
                    eventTags      => $i18n->get ('Event Tag Display'));
#                    eventTagOrder  => $i18n->get ('Event Tag Order'));

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;

    my $message = $self->adminChecks;
    if (!$message and $save) {
        $override = 0;
        my @thePrefs = qw (StartWeekOn MilitaryTime BlockOrList DisplayAmount
                           YearViewColor NavigationBar NavBarSite NavBarLabel
                           ShowWeekend DayViewHours DayViewStart
                           DayViewBlockSize DayViewControls
                           ListViewPopup MenuItemPlanner
                           MenuItemHome MenuItemFiscal FiscalType
                           PopupWidth PopupHeight
                           SelectCalPopupWidth SelectCalPopupHeight
                           EventModPopupWidth EventModPopupHeight
                           EmailSelectPopupWidth EmailSelectPopupHeight
                           ShowWeekNums WhichWeekNums
                           PlannerHideSelf TimePlanShowTimes
                           BottomBarSite HideMonthTails
                           EventHTML); # EventTags EventSorting PopupExportOn
        my %newPrefs;
        foreach (@thePrefs) {
            my $value = $self->{params}->{$_};
            $newPrefs{$_} = $value if (defined $value);
        }

        # BottomBar menus are a bit special
        my $menus;
        foreach (qw (DisplayMenu NavBarMenu CalMenu SysMenu)) {
            $menus .= $self->{params}->{$_} || '';
        }
        $newPrefs{BottomBars} = $menus;

        # And so is Event Sorting
        my @sortBy = map {$self->{params}->{"EventSorting-$_"}} 1..3;
        my $sortPref = join ',', @sortBy;
        $newPrefs{EventSorting} = $sortPref;

        # And so are Event Tags
        my @tags;
        foreach (qw (owner export)) {
            push @tags, $self->{params}->{"EventTag-$_"} || '';
        }
        $newPrefs{EventTags} = join '-', @tags;

        # And so is the Popup Export
        $newPrefs{PopupExportOn} = $self->{params}->{PopupExportOn} || 0;

        # And so is the Fiscal Epoch
        $newPrefs{FiscalEpoch} = $self->{params}->{FiscalEpochYear} . '/' .
                                 $self->{params}->{FiscalEpochMonth} . '/' .
                                 $self->{params}->{FiscalEpochDay};

        # If multi-cal, remove prefs set to Ignore
        if ($self->isMultiCal) {
            my %prefMap = (day         => [qw /StartWeekOn/],
                           time        => [qw /MilitaryTime/],
                           display     => [qw /BlockOrList DisplayAmount
                                               YearViewColor/],
                           navbar      => [qw /NavigationBar NavBarSite
                                               NavBarLabel/],
                           weekend     => [qw /ShowWeekend/],
                           weeknum     => [qw /ShowWeekNums WhichWeekNums/],
                           hidetails   => [qw /HideMonthTails/],
                           popup       => [qw /PopupWidth PopupHeight
                                               PopupExportOn/],
                           selcalpop   => [qw /SelectCalPopupWidth
                                               SelectCalPopupHeight/],
                           eventmodpop => [qw /EventModPopupWidth
                                               EventModPopupHeight/],
                           mailselpop  => [qw /EmailSelectPopupWidth
                                               EmailSelectPopupHeight/],
                           listviewpop => [qw /ListViewPopup/],
                           dayview     => [qw /DayViewHours DayViewStart
                                               DayViewBlockSize
                                               DayViewControls/],
                           daytimes    => [qw /TimePlanShowTimes/],
                           menus       => [qw /BottomBars/],
                           menuItems   => [qw /MenuItemHome MenuItemPlanner
                                               MenuItemFiscal/],
                           menuSite    => [qw /BottomBarSite/],
                           plannerself => [qw /PlannerHideSelf/],
                           fiscal      => [qw /FiscalType FiscalEpoch/],
                           eventHTML   => [qw /EventHTML/],
                           eventTags   => [qw /EventTags/],
                           eventSorting => [qw /EventSorting/],
                          );

            my @modified = $self->removeIgnoredPrefs (map   => \%prefMap,
                                                      prefs => \%newPrefs);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%captions);
        }

        foreach (@$calendars) {
            $self->saveForAuditing ($_, \%newPrefs);
            $self->dbByName ($_)->setPreferences (\%newPrefs);
        }
        $self->{audit_formsaved}++;

        $preferences = $self->prefs ('force');
    }

    print GetHTML->startHTML (title => $i18n->get ('Display Settings'),
                              op    => $self);
    print '<center>';
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Display Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Display Settings');
    }
    print "<h3>$message</h3>" if $message;
    print '</center>';

    # Get the prefs we've already got
    my $startWeekOn    = $preferences->StartWeekOn   || 7;
    my $militaryTime   = $preferences->MilitaryTime  || 0;     # true or false
    my $blockOrList    = $preferences->BlockOrList   || 'Block';
    my $displayAmount  = $preferences->DisplayAmount || 'Month';
    my $yearColor      = $preferences->YearViewColor || 'Count';
    my $showWeekend    = $preferences->ShowWeekend   || 0;     # true/false
    my $navigationBar  = $preferences->NavigationBar || 'Both';
    my $navBarSite     = $preferences->NavBarSite    || 'top';
    my $navBarLabel    = $preferences->NavBarLabel   || '';
    my $bottomBars     = $preferences->BottomBars    || '';
    my $bottomBarSite  = $preferences->BottomBarSite || 'bottom';
    my $showWeekNums   = $preferences->ShowWeekNums  || 0;
    my $whichWeekNums  = $preferences->WhichWeekNums || 4;
    my $hide_tails     = $preferences->HideMonthTails;
    my $dayViewHours   = $preferences->DayViewHours  || 8;
    my $dayViewStart   = $preferences->DayViewStart  || 9;
    my $dayViewBlockSize = $preferences->DayViewBlockSize  || 1; # 1 hour
    my $dayViewControls = $preferences->DayViewControls || 'show';
    my $tpShowTimes    = $preferences->TimePlanShowTimes || 'always';
    my $listViewPopup  = $preferences->ListViewPopup || 75;
    my $plannerItem    = $preferences->MenuItemPlanner || 'Always';
    my $homeItem       = $preferences->MenuItemHome    || 'Always';
    my $fiscalItem     = $preferences->MenuItemFiscal  || 'Always';
    my $fiscalType     = $preferences->FiscalType      || 'fixed';
    my $fiscalEpoch    = $preferences->FiscalEpoch     || '2000/01/01';
    my $popupWidth     = $preferences->PopupWidth      || 250;
    my $popupHeight    = $preferences->PopupHeight     || 350;
    my $popupExport    = $preferences->PopupExportOn   || 0; #true/false
    my $selCalPopWidth = $preferences->SelectCalPopupWidth  || 25;
    my $selCalPopHeight= $preferences->SelectCalPopupHeight || 40;
    my $evtModPopWidth = $preferences->EventModPopupWidth   || 50;
    my $evtModPopHeight= $preferences->EventModPopupHeight  || 50;
    my $mailSelPopWidth = $preferences->EmailSelectPopupWidth   || 400;
    my $mailSelPopHeight= $preferences->EmailSelectPopupHeight  || 300;
    my $plannerSelf    = $preferences->PlannerHideSelf || 0;
    my $eventHTML      = $preferences->EventHTML       || 'any';
    my $eventTags      = $preferences->EventTags       || '';
    my $eventSorting   = $preferences->EventSorting    || 'time,text';

    my @sortBy = split /,/, $eventSorting;
    my %eventTags = (owner  => $eventTags =~ /owner/ || undef,
                     export => $eventTags =~ /export/ || undef);

    $fiscalEpoch = Date->new ($fiscalEpoch);
    my %fiscalEpoch = (year  => $fiscalEpoch->year,
                       month => $fiscalEpoch->month,
                       day   => $fiscalEpoch->day);

    print startform;

    # If group, allow selecting any calendar we have Admin permission for
    my $calSelector;
    my %onChange = ();
    if ($self->isMultiCal) {
        my $mess;
        ($calSelector, $mess) = $self->calendarSelector;
        print $mess if $mess;

        foreach (@names) {
            $onChange{$_} = $self->getOnChange ($_);
        }
    }

    my %rows;
    $rows{day} = table (Tr (td (_weekdayPopup ('i18n'     => $i18n,
                                               'name'     => 'StartWeekOn',
                                               'onChange' => $onChange{day},
                                               'override' => $override,
                                               'default'  => $startWeekOn))));

    $rows{time} = table (Tr (td (popup_menu ('-name'    => 'MilitaryTime',
                                             '-default' => $militaryTime,
                                             -onChange  => $onChange{time},
                                               override => $override,
                                             '-values'  => [0, 1],
                                             '-labels'  => {'0' => '12 ' .
                                                            $i18n->get ('Hour')
                                                            . ' (AM/PM)',
                                                            '1' => '24 ' .
                                                            $i18n->get
                                                                 ('Hour')}))));

    $rows{display} = table ({width => '95%'},
                 Tr (td ({-align => 'right'},
                         $i18n->get ('Style:')),
                     td (popup_menu ('-name'    =>'BlockOrList',
                                     '-default' => $blockOrList,
                                     -onChange  => $onChange{display},
                                       override => $override,
                                     '-values'  => ['Block',     'List',
                                                    'Condensed', 'TimePlan',
                                                    'Planner'],
                          '-labels' => {Block     => $i18n->get ('Block'),
                                        List      => $i18n->get ('List'),
                                        Condensed => $i18n->get ('Condensed'),
                                        TimePlan  => $i18n->get ('Time Plan'),
                                        Planner   => $i18n->get ('Planner')})),
                     td ({-align => 'right'},
                         $i18n->get ('Amount:')),
                     td (popup_menu ('-name'    => 'DisplayAmount',
                                     '-default' => $displayAmount,
                                     -onChange  => $onChange{display},
                                       override => $override,
                                     '-values'  => ['Day', 'Week',
                                                    'Month', 'Quarter', 'Year',
                                                    'FPeriod', 'FQuarter',
                                                    'FYear'],
                      '-labels'  => {Day      => $i18n->get ('Day'),
                                     Week     => $i18n->get ('Week'),
                                     Month    => $i18n->get ('Month'),
                                     Quarter    => $i18n->get ('Quarter'),
                                     Year     => $i18n->get ('Year'),
                                     FPeriod  => $i18n->get ('Fiscal Period'),
                                     FQuarter => $i18n->get ('Fiscal Quarter'),
                                     FYear    => $i18n->get ('Fiscal Year')})),
                     td ({-align => 'right'}, $i18n->get ('Year View:')),
                     td (popup_menu (-name    => 'YearViewColor',
                                     -default => $yearColor,
                                     -onChange => $onChange{display},
                                      override => $override,
                                     -values  => ['Count', 'Categories',
                                                  'None'],
                -labels  => {Count      => $i18n->get ('Color by Event Count'),
                             Categories => $i18n->get ('Color by Categories'),
                             None       => $i18n->get ('No day coloring')})),
                    ));

    $rows{navbar} = table (Tr (td ({-align => 'right'}, $i18n->get ('Type:')),
                               td (popup_menu ('-name'    => 'NavigationBar',
                                               '-default' => $navigationBar,
                                               -onChange  => $onChange{navbar},
                                                 override => $override,
                                               '-values'  => ['Absolute',
                                                              'Relative',
                                                              'Both'],
                             '-labels' => {Absolute => $i18n->get ('Absolute'),
                                           Relative => $i18n->get ('Relative'),
                                           Both     => $i18n->get ('Both')})),
                               td ({-align => 'right'},
                                   $i18n->get('Location:')),
                               td (popup_menu ('-name'    => 'NavBarSite',
                                               '-default' => $navBarSite,
                                               -onChange  => $onChange{navbar},
                                                 override => $override,
                                               '-values'  => ['top',
                                                              'bottom',
                                                              'both',
                                                              'neither'],
                             '-labels' => {top     => $i18n->get ('Top'),
                                           bottom  => $i18n->get ('Bottom'),
                                           both    => $i18n->get ('Both'),
                                           neither => $i18n->get
                                                        ("Don't Display")})),
                               td ({-align => 'right'}, $i18n->get ('Label:')),
                               td (textfield (-name     => 'NavBarLabel',
                                              -default  => $navBarLabel,
                                              -onChange => $onChange{navbar},
                                              -override => $override,
                                              -columns  => 30))));

    my $displayMenu = ($bottomBars =~ /display/i);
    my $navBarMenu  = ($bottomBars =~ /navbar/i);
    my $calMenu     = ($bottomBars =~ /cal/i);
    my $sysMenu     = ($bottomBars =~ /sys/i);
    $rows{menus} = table ({-cellpadding => 4},
                          Tr (td (checkbox (-name => 'DisplayMenu',
                                            -checked => $displayMenu,
                                            -onChange => $onChange{menus},
                                             override => $override,
                                            -value   => 'display',
                                            -label   => ' ' . $i18n->get
                                                           ('Display'))),
                              td (checkbox (-name => 'NavBarMenu',
                                            -checked => $navBarMenu,
                                            -onChange => $onChange{menus},
                                            override => $override,
                                            -value   => 'navbar',
                                            -label   => ' ' . $i18n->get
                                                         ('Navigation Bar'))),
                              td (checkbox (-name => 'CalMenu',
                                            -checked => $calMenu,
                                            -onChange => $onChange{menus},
                                            override => $override,
                                            -value   => 'cal',
                                            -label   => ' ' . $i18n->get
                                                         ('This Calendar'))),
                              td (checkbox (-name => 'SysMenu',
                                            -checked => $sysMenu,
                                            -onChange => $onChange{menus},
                                            override => $override,
                                            -value   => 'sys',
                                            -label   => ' ' . $i18n->get
                                                        ('System Options')))));

    my %itemLabels = (Always => $i18n->get ('Always'),
                      Add    => $i18n->get ('Users w/Add'),
                      Admin  => $i18n->get ('Users w/Admin'),
                      Never  => $i18n->get ('Never'));
    $rows{menuItems} = table (Tr (
                         td ({-align => 'right'},
                             $i18n->get ('<i>Home</i> link:')),
                         td (popup_menu (-name    => 'MenuItemHome',
                                         -default => $homeItem,
                                         -onChange => $onChange{menuItems},
                                         override => $override,
                                         -values  => ['Always', 'Admin',
                                                      'Never'],
                                         -labels  => \%itemLabels)),
                         td ({-align => 'right'},
                             $i18n->get ('<i>Planner</i> link:')),
                         td (popup_menu (-name    => 'MenuItemPlanner',
                                         -default => $plannerItem,
                                         -onChange => $onChange{menuItems},
                                         override => $override,
                                         -values  => ['Always', 'Add',
                                                      'Admin', 'Never'],
                                         -labels  => \%itemLabels)),
                         td ({-align => 'right'},
                             $i18n->get ('<i>Fiscal</i> links:')),
                         td (popup_menu (-name    => 'MenuItemFiscal',
                                         -default => $fiscalItem,
                                         -onChange => $onChange{menuItems},
                                         override => $override,
                                         -values  => ['Always', 'Never'],
                                         -labels  => \%itemLabels))));

    $rows{menuSite} = '&nbsp;' .
                      popup_menu (-name     => 'BottomBarSite',
                                  -default  => $bottomBarSite,
                                  -onChange => $onChange{menuSite},
                                  -override => $override,
                                  -values   => ['top', 'bottom', 'both',
                                                'neither'],
                                  -labels => {top     => $i18n->get ('Top'),
                                              bottom  => $i18n->get ('Bottom'),
                                              both    => $i18n->get ('Both'),
                                              neither => $i18n->get
                                                          ("Don't Display")}) .
                     '<span class="InlineHelp">' .
                     $i18n->get ('Display menus above or below the calendar?')
                     . '</span>';

    $rows{weekend} = table (Tr (td (popup_menu ('-name'    => 'ShowWeekend',
                                                '-default' => $showWeekend,
                                              -onChange => $onChange{weekend},
                                                override => $override,
                                                '-values'  => [0, 1],
                                                '-labels'  => {'0' => 
                                                       $i18n->get ('Hide'),
                                                               '1' =>
                                                  $i18n->get ('Display')})),
                                td (font ({-size => -1},
                                          $i18n->get ('You can have Block ' .
                      'and List views display only Monday - Friday')))));

    $rows{weeknum} = table (Tr (td (popup_menu ('-name'    => 'ShowWeekNums',
                                                '-default' => $showWeekNums,
                                              -onChange => $onChange{weeknum},
                                                override => $override,
                                                '-values'  => [0, 1],
                                                '-labels'  => {'0' =>
                                                       $i18n->get ('Hide'),
                                                               '1' =>
                                                  $i18n->get ('Display')})),
                                td ($i18n->get('The first week of the year:')),
                                td (popup_menu ('-name'    => 'WhichWeekNums',
                                                '-default' => $whichWeekNums,
                                              -onChange => $onChange{weeknum},
                                                override => $override,
                                                '-values'  => [1, 4, 7],
                                                '-labels'  => {'1' => 
                                    $i18n->get ('has January 1st in it'),
                                                               '4' =>
                                    $i18n->get ('has at least 4 days in it'),
                                                               '7' =>
                                    $i18n->get ('has 7 days in it')}))));

    $rows{hidetails} = table (Tr (td (popup_menu (-name     => 'HideMonthTails',
                                                  -default  => $hide_tails,
                                                  -onChange =>
                                                  $onChange{hidetails},
                                                  -override => $override,
                                                  -values   => [0, 1],
                                                  -labels   => {'1' => 
                                                       $i18n->get ('Hide'),
                                                                '0' =>
                                                  $i18n->get ('Display')})),
                                td (font ({-size => -1},
                                          $i18n->get ('For events '
                      . 'from the start or end of bordering months in the '
                      . 'Block Month view')))));

    my $values = [-1, 10, 30, 60, 75, 90];
    my %labels;
    $labels{-1} = $i18n->get ("Don't show");
    $labels{10} = $i18n->get ("Very narrow");
    $labels{30} = $i18n->get ("Narrow");
    $labels{60} = $i18n->get ("Medium");
    $labels{75} = $i18n->get ("Wide");
    $labels{90} = $i18n->get ("Very Wide");

    $rows{listviewpop} = table (Tr (
                          td (popup_menu (-name     => 'ListViewPopup',
                                          -default  => $listViewPopup,
                                          -onChange => $onChange{listviewpop},
                                          override  => $override,
                                          -values   => $values,
                                          -labels   => \%labels)),
                                    td (font ({-size => -1},
              $i18n->get ('In List and Condensed views, width of the' .
                          '"Popup Text" column')))));


    my @sizes = (100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600,
                 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70);

    %labels = map {$_ => $_ < 100 ? "$_ % of screen" : "$_ pixels"} @sizes;

    $rows{popup} = table (Tr (td ($i18n->get ('Width') . ':'),
                              td (popup_menu (-name    => 'PopupWidth',
                                              -default => $popupWidth,
                                              -onChange => $onChange{popup},
                                              override => $override,
                                              -labels  => \%labels,
                                              -values  => \@sizes)),
                              td ('&nbsp;'),
                              td ($i18n->get ('Height') . ':'),
                              td (popup_menu (-name    => 'PopupHeight',
                                              -default => $popupHeight,
                                              -onChange => $onChange{popup},
                                              override => $override,
                                              -labels  => \%labels,
                                              -values  => \@sizes)),
                              td ('&nbsp;'),
                              td (checkbox (-name => 'PopupExportOn',
                                            -checked => $popupExport,
                                            -onChange => $onChange{popup},
                                            override => $override,
                                            -value   => 1,
                                            -label   => ' ' . $i18n->get
                                            ('Display iCalendar Export link')))
                              ));

    $rows{selcalpop} =
        table (Tr (td ($i18n->get ('Width') . ':'),
                   td (popup_menu (-name    => 'SelectCalPopupWidth',
                                   -default => $selCalPopWidth,
                                   -onChange => $onChange{selcalpop},
                                   override => $override,
                                   -labels  => \%labels,
                                   -values  => \@sizes)),
                   td ('&nbsp;'),
                   td ($i18n->get ('Height') . ':'),
                   td (popup_menu (-name    => 'SelectCalPopupHeight',
                                   -default => $selCalPopHeight,
                                   -onChange => $onChange{selcalpop},
                                   override => $override,
                                   -labels  => \%labels,
                                   -values  => \@sizes))));

    $rows{eventmodpop} =
        table (Tr (td ($i18n->get ('Width') . ':'),
                   td (popup_menu (-name    => 'EventModPopupWidth',
                                   -default => $evtModPopWidth,
                                   -onChange => $onChange{eventmodpop},
                                   override => $override,
                                   -labels  => \%labels,
                                   -values  => \@sizes)),
                   td ('&nbsp;'),
                   td ($i18n->get ('Height') . ':'),
                   td (popup_menu (-name    => 'EventModPopupHeight',
                                   -default => $evtModPopHeight,
                                   -onChange => $onChange{eventmodpop},
                                   override => $override,
                                   -labels  => \%labels,
                                   -values  => \@sizes))));

    $rows{mailselpop} =
        table (Tr (td ($i18n->get ('Width') . ':'),
                   td (popup_menu (-name    => 'EmailSelectPopupWidth',
                                   -default => $mailSelPopWidth,
                                   -onChange => $onChange{mailselpop},
                                   override => $override,
                                   -labels  => \%labels,
                                   -values  => \@sizes)),
                   td ('&nbsp;'),
                   td ($i18n->get ('Height') . ':'),
                   td (popup_menu (-name    => 'EmailSelectPopupHeight',
                                   -default => $mailSelPopHeight,
                                   -onChange => $onChange{mailselpop},
                                   override => $override,
                                   -labels  => \%labels,
                                   -values  => \@sizes))));

    my %startHourLabels = map {$_ => _timeLabel ($_, $militaryTime)} (0..23);
    sub _timeLabel {
        my ($hour, $milTime) = @_;
        my $amPm = '';
        if (!$milTime) {
            $amPm = $hour < 12 ? 'am ' : 'pm ';
            $hour = 12 if $hour == 0;
            $hour -= 12 if ($hour > 12);
        }
        return "$hour:00" . $amPm;
    }
    require Calendar::TimeBlock;
    my @blockSizes      = TimeBlock->getBlockSizeList;
    my %blockSizeLabels = TimeBlock->getBlockSizeLabels ($i18n, \@blockSizes);
    $rows{dayview} = table (Tr (td ({-align => 'right'},
                                   $i18n->get ('Number of hours to display:')),
                                td (popup_menu (-name    => 'DayViewHours',
                                                -default => $dayViewHours,
                                               -onChange => $onChange{dayview},
                                               -override => $override,
                                                -values  => [1..24])),
                                td ({-align => 'right'},
                                    $i18n->get ('Start Hour:')),
                                td (popup_menu (
                                        -name     => 'DayViewStart',
                                        -default  => $dayViewStart,
                                        -onChange => $onChange{dayview},
                                        -override => $override,
                                        -values   => [0..23],
                                        -labels   => \%startHourLabels)),
                                td ({-align => 'right'},
                                    $i18n->get ('Block Size:')),
                                td (popup_menu (
                                        -name     => 'DayViewBlockSize',
                                        -default  => $dayViewBlockSize,
                                        -onChange => $onChange{dayview},
                                        -override => $override,
                                        -values   => \@blockSizes,
                                        -labels   => \%blockSizeLabels)),
                                td ({-align => 'right'},
                                    $i18n->get ('Controls Menu:')),
                                td (popup_menu (
                                         -name     => 'DayViewControls',
                                         -default  => $dayViewControls,
                                         -onChange => $onChange{dayview},
                                         -override => $override,
                                         -values   => ['show', 'hide'],
                                         -labels   => {show =>
                                                        $i18n->get ('Display'),
                                                      hide =>
                                                        $i18n->get ('Hide')}))
                               ));

    $rows{daytimes} = table (Tr (
                          td (popup_menu (-name     => 'TimePlanShowTimes',
                                          -default  => $tpShowTimes,
                                          -onChange => $onChange{daytimes},
                                          -override => $override,
                                          -values   => [qw/always never
                                                           unaligned/],
                                          -labels   => {'always' =>
                                        $i18n->get ('Always display'),
                                                        'never' =>
                                        $i18n->get ('Never display'),
                                                        'unaligned' =>
                                        $i18n->get ('Display if unaligned')})),
                                 td (font ({-size => -1},
                                     $i18n->get ('In the Time Plan view, ' .
                                                 'show event times above ' .
                                                 'event text?')))));

    # Epoch and Fixed/Floating and Epoch
    my $Fiscal_Help = $i18n->get ('AdminDisplay_FiscalHelp');
    if ($Fiscal_Help eq 'AdminDisplay_FiscalHelp') {
        ($Fiscal_Help =<<'        ENDFISCALHELP') =~ s/^ +//gm;
        Fixed fiscal years always start and end on the same month\n
        and day, e.g. 'Aug. 1 to July. 31'. So, the year part of\n
        the 'Start of Year' setting is ignored.\n\n
        Floating fiscal years are always 364 days long, i.e. 52 weeks.\n
        This means the start of the year changes every year, so the\n
        year in 'Start of Year' is important.\n\n
        If you are not using fiscal years, you can ignore this; you can\n
        also turn off the choice for Fiscal views by selecting 'Never'\n
        for 'Fiscal Links' in the 'Menu Bar Items to Display' choice above.
        ENDFISCALHELP
    }
    $Fiscal_Help =~ s/'/\\'/g; #'
    $rows{fiscal} = table ({-width => '90%',
                            -cellpadding => 4},
                           Tr (td ({-align => 'right'},
                                   $i18n->get ('Type:')),
                               td (popup_menu (-name    => 'FiscalType',
                                               -default => $fiscalType,
                                               -onChange => $onChange{fiscal},
                                               override => $override,
                                               -values  => ['fixed',
                                                            'floating'],
                                               -labels  =>
                                       {fixed    => $i18n->get ('Fixed'),
                                        floating => $i18n->get ('Floating')})),
                               td ({-align => 'right'},
                                   $i18n->get ('Start of year:')),
                               td ('<nobr>' .
                                   popup_menu (-name    => 'FiscalEpochYear',
                                               -default => $fiscalEpoch{year},
                                               -onChange => $onChange{fiscal},
                                               override => $override,
                                               -values  => [1990..2010]) .
                                   popup_menu (-name    => 'FiscalEpochMonth',
                                               -default => $fiscalEpoch{month},
                                               -onChange => $onChange{fiscal},
                                               override => $override,
                                               -values  => [1..12],
                                               -labels  => {
                                           map {($_, $i18n->get
                                                       (Date->monthName ($_)))}
                                               (1..12)}),
                                   popup_menu (-name    => 'FiscalEpochDay',
                                               -default => $fiscalEpoch{day},
                                               -onChange => $onChange{fiscal},
                                               override => $override,
                                               -values  => [1..31])
                                   . '</nobr>'),
                               td (a ({href =>
                                       "JavaScript:alert (\'$Fiscal_Help\')"},
                                      '<span class="HelpLink">?</span>'))));

    %labels = (0 => $i18n->get ('Display the including calendar'),
               1 => $i18n->get ('Do NOT display including calendar'));
    $rows{plannerself} = table ({-cellpadding => 4},
                             Tr (td (popup_menu (-name    => 'PlannerHideSelf',
                                                 -default => $plannerSelf,
                                                 -onChange =>
                                                     $onChange{plannerself},
                                                 -override => $override,
                                                 -values  => [0, 1],
                                                 -labels  => \%labels)),
                                 td ($i18n->get ('Whether or not to display ' .
                                                 'the main including ' .
                                                 'calendar in the Planner ' .
                                                 'views.'))));

    my $HTML_Help = $i18n->get ('AdminGeneral_HTMLHelp');
    if ($HTML_Help eq 'AdminGeneral_HTMLHelp') {
        ($HTML_Help =<<'        ENDHTMLHELP') =~ s/^ +//gm;
        You can choose to prevent HTML tags in Event and Popup Text\n
        from being interpreted by browsers. This can be useful to\n
        prevent events with malicious formatting or embedded scripts\n
        from doing any harm.
        ENDHTMLHELP
    }
    %labels = (any  => $i18n->get ('process HTML tags normally'),
               none => $i18n->get ('ignore HTML tags'));
    $rows{eventHTML} = table (Tr (td (
                               popup_menu (-name    => 'EventHTML',
                                           -default => $eventHTML,
                                           -onChange => $onChange{eventHTML},
                                           -override => $override,
                                           -Values  => ['any', 'none'],#'safe'
                                           -labels  => \%labels)),
                               td ('&nbsp;' .
                                   a ({href =>
                                       "JavaScript:alert (\'$HTML_Help\')"},
                                      '<span class="HelpLink">?</span>'))));

    $rows{eventTags} = table (
                          Tr (td (checkbox (-name     => 'EventTag-owner',
                                            -checked  => $eventTags{owner},
                                            -onChange => $onChange{eventTags},
                                            -override => $override,
                                            -value    => 'owner',
                                            -label    => $i18n->get (
                                                            'Event owner'))),
                              td (checkbox (-name     => 'EventTag-export',
                                            -checked  => $eventTags{export},
                                            -onChange => $onChange{eventTags},
                                            -override => $override,
                                            -value    => 'export',
                                            -label    => $i18n->get
                                                      ('"When Included"')))),
                          Tr (td ({-colSpan => 2},
                                  span ({-class => 'InlineHelp'},
                                        $i18n->get ('Select extra fields to ' .
                                                    'display with events')))));

    %labels = (time     => $i18n->get ('Start Time'),
               text     => $i18n->get ('Event Text'),
               incFrom  => $i18n->get ('Included From'),
               category => $i18n->get ('Category'));
    my @sortVals = qw /time text incFrom category/;
    $rows{eventSorting} = table ( {-cellpadding => 0, -cellspacing => 0},
                           Tr (th [$i18n->get ("Sort first by:"),
                                   $i18n->get ("then by:"),
                                   $i18n->get ("then by:")]),
                           Tr (
                            td (popup_menu (-name    => 'EventSorting-1',
                                            -default => $sortBy[0],
                                          -onChange => $onChange{eventSorting},
                                            -override => $override,
                                            -Values  => \@sortVals,
                                            -labels  => \%labels)),
                            td (popup_menu (-name    => 'EventSorting-2',
                                            -default => $sortBy[1],
                                          -onChange => $onChange{eventSorting},
                                            -override => $override,
                                            -Values  => ['-', @sortVals],
                                            -labels  => \%labels)),
                            td (popup_menu (-name    => 'EventSorting-3',
                                            -default => $sortBy[2],
                                          -onChange => $onChange{eventSorting},
                                            -override => $override,
                                            -Values  => ['-', @sortVals],
                                            -labels  => \%labels))));

    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');

    my @rows;

    # could use @names, but display order might be differmint
    foreach (qw (day time display navbar                 SPACE
                 weekend weeknum hidetails               SPACE
                 eventHTML eventSorting eventTags        SPACE
                 popup selcalpop eventmodpop mailselpop listviewpop SPACE
                 dayview daytimes                        SPACE
                 menus menuItems menuSite                SPACE
                 plannerself fiscal)) {
        if (/SPACE/) {
            push @rows, Tr (td ('&nbsp;'));
            next;
        }

        ($thisRow, $thatRow) = ($thatRow, $thisRow);
        push @rows, Tr ({-class => $thisRow},
                        $self->groupToggle (name => $_),
                        td ({align   => 'right',
                             width   => '22%',
                             class => 'caption'},
                            b ('<nobr>' . $captions{$_} . ': ' . '</nobr>')),
                        td ($rows{$_}));
    }

    print $calSelector if $calSelector;

    my ($setAlljs, $setAllRow) = $self->setAllJavascript;
    print $setAlljs;
    push @rows, Tr (td ({-align => 'center'}, $setAllRow)) if $setAllRow;

    print '<br/>';
    print table ({class       => 'alternatingTable',
                  width       => '95%',
                  align       => 'center',
                  cellspacing => 0,
                  border      => 0},
                 @rows);

    print '<hr/>';

    print submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset  (-value => 'Reset');

    print $self->hiddenParams;
    print endform;
    print $self->helpNotes;
    print $cgi->end_html;
}

# Produce a popup to select a day of the week.
# Pash hash pairs with 'name', 'default' keys. (Default must be int, 1-7)
# Defaults to Sunday.
sub _weekdayPopup {
    my %args = (name    => 'WeekdayPopup',
                default => 7,
                @_);

    $args{default} = 7 if (!$args{default} or
                           $args{default} < 1 or $args{default} > 7);

    popup_menu ('-name'     => $args{name},
                '-default'  => $args{default},
                '-onChange' => $args{onChange},
                '-override' => $args{override},
                '-values'   => [7, 1],
                '-labels'   => {'7' => $args{i18n}->get ('Sunday'),
                                '1' => $args{i18n}->get ('Monday')});
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
