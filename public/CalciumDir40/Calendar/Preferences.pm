# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Preferences.pm - do preferential things

package Preferences;

use strict;
use Calendar::Database;
use Calendar::Category;

# We automagically have fns to get/set any preference defined in validPrefs
use vars qw ($AUTOLOAD %validPrefs %dontStore %hasColor %hasFont);

# Includes - Hash of hashes of info about Calendars available to include.
#            Hashed on included calendar name.
#            Keys in each hash include: Included, Override, BG,FG, Border, Text
#            Also keeps track of Add Ins

# Categories   - Hash of name => Category objects
# CustomFields - Hash of   id => CustomField objects
# CustomFieldOrder - CSV of field ids; order to present them in. May
#                    have ids for System-defined fields too (look like e.g.
#                    "s-8", instead of just "8")
# Groups     - comma separated group names (scalar)
# MailAlias  - Hash of name => comma separated email addresses (scalar)
# RemindAll  - comma separated email addresses (scalar)
# RemindCats - Hash of category => [comma separated email addresses (scalar)]
# TimePeriods- Hash of ID => [name,startTime,endTime,displayType]
# MaxIDs     - Hash of PrefName => nextUnusedID for that pref (e.g. TimePeriod)

BEGIN {
    foreach (qw (Includes
                 Description
                 Language
                 Categories Groups MailAlias AutoRefresh
                 CustomFields CustomFieldOrder
                 MilitaryTime StartWeekOn
                 Title  TitleAlignment
                 Header HeaderAlignment
                 Footer FooterAlignment
                 SubFooter SubFooterAlignment
                 Colors Fonts BackgroundImage
                 TimeConflicts TimeSeparation
                 MailSMTP MailFrom MailSignature MailFormat MailAddLink
                 MailiCalAttach
                 SMTPAuth SMTPAuthType SMTPAuthID SMTPAuthPW
                 NotifyNewSubject NotifyModSubject
                 SubscribeSubject RemindSubject
                 BottomBars ShowWeekend NoPastEditing
                 FutureLimit FutureLimitAmount FutureLimitUnits
                 NoLastMinute NoLastMinuteAmount
                 MaxDuration MaxDurationAmount MinDuration MinDurationAmount
                 EventOwnerOnly EventHTML EventSorting EventPrivacy EventTags
                 ShowWeekNums WhichWeekNums
                 DayViewStart DayViewHours DayViewBlockSize DayViewControls
                 PrivacyNoInclude PrivacyOwner HideDetails
                 ListViewPopup
                 MenuItemPlanner MenuItemHome
                 FiscalType FiscalEpoch MenuItemFiscal
                 MultiAddUsers MultiAddCals TentativeSubmit TentativeViewers
                 IsSyncable LastRMSyncID
                 RemindersOn RemindAll RemindCats RemindDays
                 BlockOrList DisplayAmount NavigationBar NavBarSite NavBarLabel
                 PrintPrefs Timezone
                 YearViewColor DefaultTimezone
                 PopupWidth PopupHeight PopupExportOn RepeatEditWhich
                 SelectCalPopupWidth SelectCalPopupHeight
                 EventModPopupWidth EventModPopupHeight
                 EmailSelectPopupWidth EmailSelectPopupHeight
                 RequiredFields EditFormHide EditFormPrompts
                 DefaultPeriod EmailSelector TimeEditWhich TimePeriods
                 DefaultCategory DefaultBorder DefaultTimePeriod
                 DefaultSubsNotify DefaultRemindTimes DefaultRemindTo
                 DefaultText DefaultPopup
                 PlannerHideSelf TimePlanShowTimes MaxIDs
                 CSS_URL CSS_inline BottomBarSite InstName HideMonthTails
                 RSS_Disable RSS_Formats RSS_IconPath
                )) {
        $validPrefs{$_}++;
    }
    foreach (qw/PrintPrefs Timezone/) {
        $dontStore{$_}++;
    }
    foreach (qw (Title Header Footer SubFooter MainPage WeekHeader DayHeader
                 Today Event Link VLink Popup PopupDate BottomBar
                 BottomBarSelected ListViewDate ListViewDay ListViewEvent
                 ListViewPopup MonthTail NavLabel NavLink DayViewControls
                 BannerShadow))
                 {
        $hasColor{$_ . 'BG'}++;
        $hasColor{$_ . 'FG'}++;
    }
    foreach (qw (Body NavLabel NavAbs NavRel
                 MonthYear
                 BlockDayOfWeek BlockDayDate BlockEvent BlockEventTime
                 BlockCategory BlockInclude ListCategory ListInclude
                 ListDate ListDay ListEvent ListEventTime ListDetails
                 PopupDate PopupEvent PopupText BottomBars DayViewControls
                )) {
        $hasFont{$_}++;
    }
}

# Return a ref to a hash with all prefs set to built-in defaults
sub defaults {
    my $class = shift;

    my %colors = (BottomBarFG         => 'black',
                  BottomBarSelectedFG => 'black',
                  DayHeaderFG         => 'black',
                  DayViewControlsFG   => 'black',
                  EventFG             => 'black',
                  FooterFG            => 'black',
                  HeaderFG            => 'black',
                  LinkFG              => 'black',
                  ListViewDateFG      => 'black',
                  ListViewDayFG       => 'black',
                  ListViewEventFG     => 'black',
                  ListViewPopupFG     => 'black',
                  MainPageFG          => 'black',
                  MonthTailFG         => 'black',
                  NavLabelFG          => 'black',
                  NavLinkFG           => 'black',
                  PopupDateFG         => 'black',
                  PopupFG             => 'black',
                  TitleFG             => 'black',
                  TodayFG             => 'black',
                  VLinkFG             => 'black',

                  BannerShadowBG      => 'black',
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
                 );

    my %fonts = (BottomBarsSIZE     => 2,
                 BlockEventTimeSIZE => 1,
                 MonthYearSIZE      => 5,
                 PopupDateSIZE      => 3,
                 PopupEventSIZE     => 6,
                 PopupTextSIZE      => 4,
                 BlockIncludeSIZE   => 2,
                 BlockCategorySIZE  => 2,
                 ListIncludeSIZE    => 2,
                 ListIncludeSIZE    => 2,
                ); # size is 1..7, 3 is 'Normal'

    my %categories = ();
#     my %categories = (Meeting  => Category->new (name => 'Meeting',
#                                                  bg   => 'darkred',
#                                                  fg   => 'black'),
#                       Vacation => Category->new (name => 'Vacation',
#                                                  bg   => 'cornsilk',
#                                                  fg   => 'black'));
    my %mailAliases = ();


    my %hash = (IsSyncable      => 1,
                RemindersOn     => 1,
                PopupExportOn   => 1,
                Description     => '',
                Language        => 'English',
                MilitaryTime    => 0,
                StartWeekOn     => 7,
                Title           => 'no Title specified yet',
                TitleAlignment  => 'Center',
                Header          => 'no Header specified yet',
                HeaderAlignment => 'Center',
                Footer          => 'no Footer specified yet',
                FooterAlignment => 'Center',
                Colors          => \%colors,
                Fonts           => \%fonts,
                Categories      => \%categories,
                CustomFields    => {},
                MailAlias       => \%mailAliases,
                BackgroundImage => undef,
                EventHTML       => 'any',
                EventSorting    => 'time,text',
                TimeConflicts   => 'Allow',
                TimeSeparation  => 0,
                MailFrom        => "Calcium@" . ($ENV{SERVER_NAME} ||
                                                   'localhost.localdomain'),
                BottomBars      => 'displaynavbarcalsys',
                ShowWeekend     => 1,
                ListViewPopup   => 1,
                MenuItemPlanner => 'Always',
                MenuItemHome    => 'Always',
                MenuItemFiscal  => 'Never',
                MultiAddUsers   => 'nobody',
                MultiAddCals    => 'permitted',
                BlockOrList     => 'Block',
                DisplayAmount   => 'Month',
                NavigationBar   => 'Absolute',
                NavBarSite      => 'top');
    \%hash;
}

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;           # get rid of package names, etc.
    return unless $name =~ /[^A-Z]/;  # ignore all cap methods; e.g. DESTROY

    # Make sure it's a valid preference, nes pas?
    die "Bad Preference Name! '$name'\n" unless $validPrefs{$name};

    $self->{$name} = shift if (@_);
    $self->{$name};
}

# Pass in either:
#   - a hash ref, which will be the object
#   - a Database object, to get the prefs from
#   - a string to use to create a Database object to get prefs from
#   - nothing, to get the built-in defaults
# and get the all the prefs from it.
sub new {
    my $class = shift;
    my $theArg = shift;

    my ($self, $db);
    if (!defined $theArg) {
        $self = Preferences->defaults;
    } elsif (ref ($theArg) eq 'HASH') {
        $self = $theArg;
    } else {
        if (ref ($theArg) and $theArg->isa ('Database')) {
            $db = $theArg;
        } else {
            $db = Database->new ($theArg);
        }
        $self = $db->getPreferences;
    }

    bless $self, $class;
    $self;
}

# Clear things we don't store; needed typically for mod_perl so cached
# session prefs (via cached db) don't stick around between sessions
sub clearCache {
    my $self = shift;
    foreach my $name (keys %dontStore) {
        delete $self->{$name};
    }
}

# Return a color from the prefs hash, or scream if we don't know what the
# hell they're talking about
# '$printExclusion' normally undef; only used to get colors if 'some' PrintMode
sub color {
    my $self = shift;
    my ($key, $printExclusion) = (@_);     # to get colors even if it's 'some'

    # See if we know about this color
    die "What? Never heard of color: '$key'\n" unless $hasColor{$key};

    if ($self->PrintPrefs) {
        my $which = $self->PrintPrefs->colors || 'none';
        if ($which eq 'none' or (!$printExclusion and $which eq 'some')) {
            #    if (!$printExclusion and $self->inBWPrintMode) {
            return ($key =~ /BG$/) ? 'white' : 'black';
        }
    }

    my $colors = $self->Colors;
    return $colors->{$key} if $colors;
    return;
}
sub inBWPrintMode {
    my ($self) = @_;
    # 'none' or 'some' is normally BW
    return ($self->PrintPrefs and
                ($self->PrintPrefs->isColorMode ('none') or
                 $self->PrintPrefs->isColorMode ('some')));
}
sub inPrintMode {
    my ($self, $mode) = @_;
    return ($self->PrintPrefs and
                $self->PrintPrefs->isColorMode ($mode || 'none'));
}



# Return a list of (face, size) from the fonts hash, or scream if we don't
# know what the hell they're talking about
sub font {
    my $self = shift;
    my ($key) = (@_);

    # See if we know about this font item
    die "What? Never heard of font: '$key'\n" unless $hasFont{$key};

    my $fonts = $self->Fonts;
    return unless $fonts;
    return ($fonts->{$key . 'FACE'}, $fonts->{$key. 'SIZE'});
}

# Return hashref of Category objects, keyed on name
# Specify whether or not to check Master Prefs too
sub getCategories {
    my ($self, $checkMaster) = @_;
    my $href = {};
    if ($checkMaster) {
        $href = MasterDB->new->getPreferences->Categories;
    }
    $href = {%$href, %{$self->Categories}};    # cal. cats overwrites system
    $href;
}

# Return list of Category names
sub getCategoryNames {
    my $self = shift;
    keys %{$self->Categories};
}

# Get or set Category object; return undef if getting and it doesn't exist
sub category {
    my ($self, $name, $catObj) = @_;
    return unless defined $name;
    $self->Categories->{$name} = $catObj if $catObj;
    $self->Categories->{$name};
}

sub deleteCategory {
    my ($self, $name) = @_;
    return unless defined $name;
    delete $self->Categories->{$name};
}

# Return list of defined aliases.
sub getMailAliasNames {
    my $self = shift;
    keys %{$self->MailAlias};
}

# Return list of addresses for given alias
sub getMailAlias {
    my $self = shift;
    my $alias = shift;
    return () unless defined $alias;
    my $addresses = $self->MailAlias->{lc($alias)} || '';
    return split ',', $addresses;
}

# pass alias name and one or list of addresses
# We convert all Aliases names to lowercase. Just easier that way.
sub setMailAlias {
    my $self = shift;
    my ($alias, @addrs) = @_;
    return () unless (defined $alias and $addrs[0]);
    $self->MailAlias->{lc($alias)} = join ',', @addrs;
}

sub deleteMailAlias {
    my $self = shift;
    my $alias = shift;
    return () unless defined $alias;
    delete $self->MailAlias->{lc($alias)};
}


# Get groups. Returns scalar or list.
sub getGroups {
    my $self = shift;
    my @groups = split ',', ($self->Groups || '');
    return wantarray ? @groups : $groups[0];
}

# Set Groups; pass single scalar or list of groups to set, (undef, empty
# string, empty list, or list of undef to clear).
# Returns list or scalar.
sub setGroups {
    my ($self, @groups) = @_;
    if (defined $groups[0] and $groups[0] ne '') {
        $self->Groups (join ',', @groups);
    } else {
        $self->Groups (undef);
    }
    return $self->getGroups;
}

sub addGroup {
    my ($self, $group) = @_;
    return unless defined $group;
    my @groups = $self->getGroups;
    @groups = () unless @groups;
    return if grep {$_ eq $group} @groups;
    $self->setGroups (@groups, $group);
}

sub deleteGroup {
    my ($self, $deleteMe) = @_;
    return unless defined $deleteMe;
    my @groups = $self->getGroups;
    return unless @groups;
    my @newGroups;
    foreach (@groups) {
        push (@newGroups, $_) unless /^$deleteMe$/;
    }
    $self->setGroups (@newGroups) if (@groups != @newGroups); # checks lengths
}

# -Returns a ref to a hash of included calendar info, keyed on cal name.
# -Pass an arg (e.g. 'all') to get all included calendars, not just those
#  which are set to display
sub getIncludedCalendarInfo {
    my $self = shift;
    my $all = shift;
    my (@included, %returnHash);

    @included = $self->getIncludedCalendarNames ($all);
    push @included, map {"ADDIN $_"} $self->getIncludedAddInNames ($all);

    foreach (@included) {
        $returnHash{$_} = $self->Includes->{$_};
    }
    return \%returnHash;
}

# Return a list of included calendar names.
# Pass an arg (e.g. 'all') to get all included calendars, not just those
# which are set to display
sub getIncludedCalendarNames {
    my $self = shift;
    my $all = shift;
    my ($allIncludes, @activeIncludes);

    $allIncludes = $self->Includes;
    return if (ref ($allIncludes) ne 'HASH');

    my ($name, $hash);
    while (($name, $hash) = (each %$allIncludes)) {
        next if ($name =~ /^ADDIN /);
        if ($hash->{'Included'} and ($all or !$hash->{'Excluded'})) {
            push @activeIncludes, $name;
        }
    }
    return @activeIncludes;
}

# Return a list of the AddIns we've included.
# Pass an arg (e.g. 'all') to get all included AddIns, not just those
# which are set to display
sub getIncludedAddInNames {
    my $self = shift;
    my $all = shift;

    my $allIncludes = $self->Includes;
    return if (ref ($allIncludes) ne 'HASH');

    my ($name, $hash, @activeIncludes);
    while (($name, $hash) = (each %$allIncludes)) {
        next if ($name !~ /^ADDIN /);
        if ($hash->{'Included'} and ($all or !$hash->{'Excluded'})) {
            $name =~ s/^ADDIN //;
            push @activeIncludes, $name;
        }
    }
    return @activeIncludes;
}


# Reminder addresses
sub getRemindAllAddresses {
    my $self = shift;
    my @all = split ',', ($self->RemindAll || '');
    return @all;
}
sub setRemindAllAddresses {
    my ($self, @addrs) = @_;
    my $all = join ',', @addrs;
    $self->RemindAll ($all);
}
# return hash; {cat name => [address list]}
sub getRemindByCategory {
    my $self = shift;
    my $catHash = $self->RemindCats || {};
    my %hash;
    while (my ($cat, $addrs) = each %$catHash) {
        $hash{$cat} = [split ',', ($addrs || '')];
    }
    return \%hash;
}
sub setRemindByCategory {
    my ($self, $catHash) = @_;
    my $hcopy;
    while (my ($cat, $addrs) = each %$catHash) {
        next if (!defined $addrs or !(@$addrs));
        $hcopy->{$cat} = join ',', @$addrs;
    }
    $self->RemindCats ($hcopy);
}
# returns ref to list of addresses
sub getRemindForCategory {
    my ($self, $cat) = @_;
    my $catHash = $self->getRemindByCategory;
    return $catHash->{$cat};
}
# pass cat name, ref to list of addresses
sub setRemindForCategory {
    my ($self, $cat, $addrs) = @_;
    my $catHash = $self->getRemindByCategory;
    $catHash->{$cat} = $addrs;
    $self->setRemindByCategory ($catHash);
}

# Return next available ID for specified preference, incrementing.
# We don't write; whoever needs this should be saving the prefs
sub _nextID {
    my ($self, $pref) = @_;
    my $validRE = 'TimePeriod|UserGroup|CustomField';
    die "Bad pref to _nextID: $pref\n" unless ($pref =~ /$validRE/o);
    my $ids = $self->MaxIDs || {};
    my $id = ++$ids->{$pref};  # pre-increment; start with 1
    $self->MaxIDs ($ids);
    return $id;
}

# Time Periods
sub newTimePeriod {
    my $self = shift;
    my %vals = (id      => undef,
                name    => undef,
                start   => 0,
                end     => 0,
                display => 'both',
                @_);
    my @period = ($vals{name}, $vals{start}, $vals{end}, $vals{display});
    my $id = $vals{id} || $self->_nextID ('TimePeriod');
    $self->setTimePeriod ($id, \@period);
    return $id;
}

# Return entire hash; {period id => [name, start, end, displayType]}
sub getTimePeriods {
    my ($self, $checkMaster) = @_;
    my $theHash = $self->TimePeriods || {};
    my (%hash, %names);
    while (my ($id, $data) = each %$theHash) {
        my @values = split "\036", ($data || '');
        $values[1] ||= 0;       # set to midnight if not defined
        $hash{$id} = \@values;
        $names{$values[0]} = $id;
    }
    if ($checkMaster) {
        my $master = MasterDB->new->getPreferences->getTimePeriods;
        while (my ($id, $data) = each %$master) {
            next if $names{$data->[0]}; # skip if name exists already
            $hash{"S-$id"} = $data;
        }
    }
    return \%hash;
}
# Replace entire hash
sub setTimePeriods {
    my ($self, $hash) = @_;
    my $hcopy;
    while (my ($id, $dataArray) = each %$hash) {
        next if (!defined $id);
        $hcopy->{$id} = join "\036", @$dataArray;
    }
    $self->TimePeriods ($hcopy);
}
# Replace single period in hash
sub setTimePeriod {
    my ($self, $id, $data) = @_;
    my $hash = $self->getTimePeriods;
    $hash->{$id} = $data;          # don't need to copy the array, since...
    $self->setTimePeriods ($hash); # ...setTimePeriods does a 'join'
}
# Return (name, startTime, endTime, displayType) list
# If id starts with "S-", it's a Master period
sub getTimePeriod {
    my ($self, $id) = @_;
    return unless defined ($id);
    my $periods;
    if ($id =~ /^S-(.*)/) {
        $id = $1;
        $periods = MasterDB->new->getPreferences->getTimePeriods;
    } else {
        $periods = $self->getTimePeriods;
    }
    my $data = $periods->{$id} || [];
    return @$data;
}
sub deleteTimePeriod {
    my ($self, $id) = @_;
    return unless defined ($id);
    my $hash = $self->getTimePeriods;
    delete $hash->{$id};
    $self->setTimePeriods ($hash);
}
# Return undef if ok; 'exists' or 'notfound' on error
sub renameTimePeriod {
    my ($self, $id, $newName) = @_;
    my @data = $self->getTimePeriod ($id);
    return 'notfound' unless @data;
    return 'exists'  if $self->getTimePeriodByName ($newName);
    $data[0] = $newName;
    $self->setTimePeriod ($id, \@data);
    return;
}
sub getTimePeriodByName {
    my ($self, $name) = @_;
    my $tps = $self->getTimePeriods;
    foreach (keys %$tps) {
        return $tps->{$_}
            if ($tps->{$_}->[0] eq $name);
    }
    return undef;
}

# Replace some values
sub setValues {
    my $self = shift;
    my ($argHash) = (@_);
    my ($key, $value);
    while (($key, $value) = (each %$argHash)) {
        next unless defined $value;
        $self->{$key} = $value;
    }
    $self;
}

# Custom Field stuff
# Return ref to list of CustomField objects defined for this cal.
# Specify whether or not to get system-level Custom Fields too;
#     calendar-specific ones override system-level BY NAME
#     system-level ones have IDs like "S-33", i.e. preceded by "S-"
sub get_custom_fields {
    my $self = shift;
    my %args = (system => 1,     # undef to not get system-defined fields
                @_);
    my $fields_by_id = $self->{CustomFields};

    # If don't want system ones, just return ours
    if (!$args{system}) {
        return [values %$fields_by_id];
    }

    my %fields_by_name = map {$_->name, $_} values %$fields_by_id;

    # else, get system ones and merge in
    my $sys_by_id = MasterDB->new->getPreferences->CustomFields;
    while (my ($id, $field) = each %$sys_by_id) {
        next if $fields_by_name{$field->name}; # skip if already have this name
        $field->id ("S-$id");                  # system fields need speical IDs
        $fields_by_name{$field->name} = $field;
        $fields_by_id->{"S-$id"}      = $field;
    }
    return [values %$fields_by_id];
}

# Modify a custom field
sub set_custom_field {
    my ($self, $custom_field) = @_;
    return unless $custom_field and $custom_field->name;
    $self->CustomFields->{$custom_field->id} = $custom_field;
    return $custom_field;
}

# Add a new field - generates new ID for it (but caller must save to DB!)
sub new_custom_field {
    my ($self, $custom_field) = @_;
    if (!$custom_field or !defined $custom_field->name) {
        die "bad field to Preferences::new_custom_field";
    }
    if (defined $custom_field->id) {
        die "existing ID not allowed for newly created custom field!"
    }
    $custom_field->id ($self->_nextID ('CustomField'));
    $self->set_custom_field ($custom_field);
}

sub delete_custom_field {
    my ($self, $field_or_id) = @_;
    my $id = ref $field_or_id ? $field_or_id->id : $field_or_id;
    delete $self->CustomFields->{$id};
}



# Return a plain old string, suitable for tucking away in a plain or DB file
sub serialize {
    my $self = shift;

    my ($line, @lines);

    if ($self->{Colors}) {
        $line = "Colors$;" . join $;, %{$self->{Colors}};
        push @lines, $line;
    }

    if ($self->{Fonts}) {
        $line = "Fonts$;" . join $;, %{$self->{Fonts}};
        push @lines, $line;
    }

    if ($self->{MailAlias} and keys %{$self->{MailAlias}}) {
        $line = "MailAlias$;" . join $;, %{$self->{MailAlias}};
        push @lines, $line;
    }

    if ($self->{RemindCats} and keys %{$self->{RemindCats}}) {
        $line = "RemindCats$;" . join $;, %{$self->{RemindCats}};
        push @lines, $line;
    }

    if ($self->{TimePeriods} and keys %{$self->{TimePeriods}}) {
        $line = "TimePeriods$;" . join $;, %{$self->{TimePeriods}};
        push @lines, $line;
    }

    if ($self->{MaxIDs} and keys %{$self->{MaxIDs}}) {
        $line = "MaxIDs$;" . join $;, %{$self->{MaxIDs}};
        push @lines, $line;
    }

    if ($self->{Includes}) {
        $line = "Includes";
        while (my ($name, $incHash) = each %{$self->{Includes}}) {
            $line .= $;;
            my $borderETC = ($incHash->{Border} || '0') .
                            ($incHash->{Text}   || '');
            my $cats;
            $cats = join "\036", @{$incHash->{Categories}}
                if $incHash->{Categories};
            my $overrideETC = ($incHash->{Override}   || '0') . ($cats || '');
            $line .= join $;, ($name,
                               $incHash->{Included} || '',
                               $overrideETC,
                               $incHash->{BG}       || '',
                               $incHash->{FG}       || '',
                               $borderETC);
        }
        push @lines, $line;
    }

    if ($self->{Categories}) {
        while (my ($name, $cat) = each %{$self->{Categories}}) {
            $line = "Category-$name$;" . $cat->serialize;
            push @lines, $line;
        }
    }

    if ($self->{CustomFields}) {
        foreach my $field (values %{$self->{CustomFields}}) {
            my $id = $field->id;
            $line = "CustomField-$id$;" . $field->serialize;
            push @lines, $line;
        }
    }

    foreach my $key (keys %{$self}) {
        next if ($dontStore{$key}); # never save these
        next if ($key =~ /^(Colors|Fonts|MailAlias|Includes|Categories|RemindCats|TimePeriods|MaxIDs|CustomFields)$/);
        $line = "$key$;" . ($self->{$key} || '');
        push @lines, $line;
    }
    my $string = join "\035", @lines;    # $; is \034
    $string =~ s/\n/\\n/g;
    $string;
}

# Return a new prefs object from a serialized string
sub unserialize {
    my $classname = shift;
    my $string = shift;

    my ($line, @lines);

    return $classname->new unless $string;

    $string =~ s/\\n/\n/g;
    @lines = split "\035", $string;

    my %prefs = %{$classname->defaults};

    while ($line = shift @lines) {
        my ($key, @values) = split $;, $line;
        if ($key eq 'Colors') {
            push @values, '' if (int(@values/2)*2 != @values);
            my %colors = (@values);
            $prefs{Colors} = \%colors;
        } elsif ($key eq 'Fonts') {
            push @values, '' if (int(@values/2)*2 != @values);
            my %fonts = (@values);
            $prefs{Fonts} = \%fonts;
        } elsif ($key eq 'MailAlias') {
            push @values, '' if (int(@values/2)*2 != @values);
            my %aliases = (@values);
            $prefs{MailAlias} = \%aliases;
        } elsif ($key eq 'RemindCats') {
            push @values, '' if (int(@values/2)*2 != @values);
            my %stuff = (@values);
            $prefs{RemindCats} = \%stuff;
        } elsif ($key eq 'TimePeriods') {
            push @values, '' if (int(@values/2)*2 != @values);
            my %stuff = (@values);
            $prefs{TimePeriods} = \%stuff;
        } elsif ($key eq 'MaxIDs') {
            push @values, '' if (int(@values/2)*2 != @values);
            my %stuff = (@values);
            $prefs{MaxIDs} = \%stuff;
        } elsif ($key eq 'Includes') {
            my %includes;
            while (@values) {
                my ($calName, $include, $overrideETC, $bg, $fg, $borderETC) =
                    splice (@values, 0, 6);
                my ($border, $text) = unpack "aa*", ($borderETC || '');
                my ($override, $cats) = unpack "aa*", ($overrideETC || '');
                my @cats = split "\036", $cats;
                $includes{$calName} = {Included => $include,
                                       Categories => \@cats,
                                       Override => $override,
                                       BG       => $bg,
                                       FG       => $fg,
                                       Border   => $border,
                                       Text     => $text};
                $prefs{Includes} = \%includes;
            }
        } elsif ($key =~ /^Category-(.*)/) {
            push @values, '' if (@values % 2);
            $prefs{Categories}->{$1} = Category->unserialize (@values);
        } elsif ($key =~ /^CustomField-(.*)/) {
            require Calendar::CustomField; # don't parse unless we use it
            push @values, '' if (@values % 2);
            my $field = CustomField->unserialize (@values);
            $prefs{CustomFields}->{$field->id} = $field;
        } else {
            $prefs{$key} = $values[0];
        }
    }

    $classname->new (\%prefs);
}

1;
