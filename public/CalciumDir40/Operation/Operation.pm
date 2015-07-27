# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package Operation;
use strict;
require CGI;
use Calendar::Defines;
use Calendar::Preferences;
use Calendar::Permissions;
use Calendar::MasterDB;
use Calendar::I18N;

# Default constructor for Operations
sub new {
    my $class = shift;
    my ($paramHash, $authLevel, $user) = @_;
    my $self = {};
    bless $self, $class;

    $self->{params} = $paramHash;
    $self->{AuthLevel} = $authLevel;
    $self->{user} = $user;
    $self->db;                  # open database; overridden for MasterDB guys
    $self->prefs;               # read the prefs
    $self->I18N;                # initialize language stuff

    # If requested, use overriden params from cookie
    if ($self->{params}->{CookieParams} || $self->{params}->{IsPopup}) {
        my $cgi = CGI->new;
        my $valString = $cgi->cookie ('CalciumDisplayParams');
        if ($valString) {
            my @pairs = split /;/, $valString;
            foreach (@pairs) {
                my ($name, $val) = split /=/;
                next if ($name eq 'IsPopup');
                $self->{params}->{$name} = $val;
            }
        }
    }

    # hacking away here
    if ($user) {
        my $auth = $user->internallyAuthenticated;
        my $theUser = User->getUser ($user->name); # get from DB, ugh.
        if ($theUser) {         # might not exist in db if htaccess used
            $self->{user} = $theUser;
            $self->prefs->Timezone ($self->{user}->timezone);
            $self->{user}->{internalAuthentication} = $auth;
        }
    } else {
        # check for tz cookie, else get from cal defaults
        my $zoneOffset = CGI->new->cookie ('CalciumAnonOffset');
        $zoneOffset = $self->prefs->DefaultTimezone if (!defined $zoneOffset);
        $self->prefs->Timezone ($zoneOffset);
    }

    $self;
}

# See if the user is permitted to perform
sub authenticate {
    my $self = shift;
    return 1 if $self->permission->permitted ($self->getUsername,
                                              $self->{AuthLevel});
}

sub calendarName {
    my $self = shift;
    defined $self->{params} ? $self->{params}->{CalendarName} : undef;
}

sub getUsername {
    my $self = shift;
    $self->{user} ? $self->{user}->name : undef;
}

sub getUser {
    my $self = shift;
    $self->{user};
}

sub opName {
    my $self = shift;
    defined $self->{params} ? $self->{params}->{Op} : undef;
}

# Just a Convenience routine to save typing, make code readable.
sub getParams {
    my $self = shift;
    my @cgiParams = @_;
    my @retList;
    foreach (@cgiParams) {
        push @retList,
                (defined $self->{params} ? $self->{params}->{$_} : undef);
    }
    wantarray ? @retList : $retList[0];
}

sub clearParams {
    my ($self, @params) = @_;
    return unless $self->{params};
    foreach (@params) {
        delete $self->{params}->{$_};
    }
}

# Return hashref
sub rawParams {
    return shift->{params};
}

# Return name->value hashref for params that match regex
sub get_matching_params {
    my ($self, $regex) = @_;
    my %ret_hash = map {$_ => $self->{params}->{$_}}     # get name => value
                     grep {/$regex/}                     # ...only for matching
                       keys %{$self->{params}};          # ...param names
    return \%ret_hash;
}

# Pash list, hashref, or arrayref
sub mungeParams {
    my ($selfOrClass, @params) = @_;
    return '' unless defined $params[0];
    if (ref $params[0] eq 'ARRAY') {
        @params = @{$params[0]};
    } elsif (ref $params[0] eq 'HASH') {
        @params = %{$params[0]};
    }
    return join ($;, @params);
}
# Return list
sub unmungeParams {
    my ($selfOrClass, $munged) = @_;
    # make sure even number, for assigning to hash
    my @params = split (/$;/, ($munged || ''));
    push @params, undef
        if (@params != int (@params / 2) * 2);
    return @params;
#    return split (/$;/, ($munged || ''));
}

# Perform should be overriden to do whatever needs doing, eh wot?
sub perform {
    die "Shazam! Nothing to perform for this operation!\n";
}


sub makeURL {
    my $self = shift;
    my $params = shift;
    my $cgi  = CGI->new;
    my $name = $self->calendarName;
    my ($url, $plainURL);
    if ($params->{FullURL}) {
        $url = $cgi->url ();
        delete $params->{FullURL};
        $plainURL++;
    } elsif (($ENV{SERVER_PROTOCOL} || '') eq 'INCLUDED') {
        $url = $cgi->url;
        $url =~ s/^included:/http:/;
    } else {
        $url = $cgi->url (-relative => 1);
#        $url = $cgi->url;
    }
    if ($params->{PlainURL}) {
        delete $params->{PlainURL};
        $plainURL++;
    }
    $url .= '?';
    if ($name && !exists $params->{CalendarName}) {
        $url .= "CalendarName=$name&";
    }
    while (my ($name, $value) = each %$params) {
        next if (!defined $value); # so can use undef to omit defaults
        $url .= "$name=" . _escape($value) . '&';
    }
    # Add common display arguments
    unless (defined $plainURL) {
        foreach ($self->displayParamNames) {
            next if exists $params->{$_};         # not if supplied as an arg
            my $value = $self->{params}->{$_};
            next unless $value;    # not if we don't have it
            $value = _escape ($value) if /TextFilter|FilterCategories/;
            $url .= "$_=$value&";  # otherwise, add it
        }
    }
    chop $url;              # remove last ? or &
    $url ||= $cgi->url;     # in case using index.cgi; empty URLs won't work
    $url;
}
sub _escape {    # from CGI.pm 2.xx
    my $arg = shift;
    return $arg unless $arg;
    $arg=~s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    return $arg;
}

# This one makes a full URL, including hostname and port, and ignores all
# params excpet those passed in and the Calendar Name.
sub makeFullURL {
    my $self = shift;
    my $params = shift;
    my $cgi  = CGI->new;
    my $name = $self->calendarName;
    my $url = $cgi->url ();
    $url .= '?';
    if ($name && !exists $params->{CalendarName}) {
        $url .= "CalendarName=$name&";
    }
}

# Create and Parse Display Specs param. Parse returns a list.
# Pass in a preferences object if you want to use fallbacks
sub ParseDisplaySpecs {
    my $self = shift;
    my $prefs = shift;
    my ($amount, $navType, $type) = ($self->{params}->{Amount}  || '',
                                     $self->{params}->{NavType} || '',
                                     $self->{params}->{Type}    || '');

    if ($amount !~ /(Year|Month|Week|Day|Quarter|Period)/i) {
        $amount = $prefs ? $prefs->DisplayAmount : 'Month';
        $self->{params}->{Amount} = $amount;
    }

    if ($navType !~ /(Absolute|Relative|Both|Neither)/i) {
        $navType = $prefs ? $prefs->NavigationBar : 'Absolute';
        $self->{params}->{NavType} = $navType;
    }

    if ($type !~ /(Block|List|Condensed|Planner|TimePlan)/i) {
        $type = $prefs ? $prefs->BlockOrList : 'Block';
        $self->{params}->{Type} = $type;
    }

    ($amount, $navType, $type);
}

# Return filter categories, regex, and which text to look at
sub ParseFilterSpecs {
    my $self = shift;
    my ($filterText, $filterIn, $filterIgnoreCase, $filterUseRegex,
        $filterCategories) = $self->getParams (qw (TextFilter FilterIn
                                                   IgnoreCase UseRegex
                                                   FilterCategories));
    if ($filterText) {
        $filterText = quotemeta ($filterText) unless $filterUseRegex;
        $filterText = "(?i)$filterText" if $filterIgnoreCase;
        $filterIn = 'both'  if ($filterIn =~ /both/i);
        $filterIn = 'text'  if ($filterIn =~ /event/i);
        $filterIn = 'popup' if ($filterIn =~ /popup/i);
    }
    if ($filterCategories) {
        $filterCategories = [split /$;/, $filterCategories];
    }
    return ($filterCategories, $filterText, $filterIn);
}

# Return text for hidden CGI form elements for passing Display Specs around
sub hiddenDisplaySpecs {
    my $self = shift;
    my $cgi = CGI->new;
    my $html = '';
    foreach my $param ($self->displayParamNames) {
        my $val = $self->{params}->{$param};
        next unless defined $val;
        $html .= $cgi->hidden (-name     => $param,
                               -override => 1,
                               -default  => $val);
    }
    $html;
}

sub displayParamNames {
    return qw (Amount NavType Type
               TextFilter FilterIn IgnoreCase UseRegex FilterCategories
               DayViewStart DayViewHours DayViewIncrement YearViewColor
               Date UseLang IsPopup);
}

sub displayParamCookie {
    my $self = shift;
    my @displayParams;
    my @vals = $self->getParams ($self->displayParamNames);
    foreach ($self->displayParamNames) {
        my $val = shift @vals;
        next unless defined $val;
        next if ($_ eq 'IsPopup');
        push @displayParams, "$_=$val";
    }
    my $paramCookie = CGI->new->cookie (-name  => 'CalciumDisplayParams',
                                        -value => join ';', @displayParams);
}

# Return prefs object. Get from the db (and cookies) if we haven't already
# got 'em. Will create a new Database object if necessary.
sub prefs {
    my $self = shift;
    my $force = shift;
    if ($force || !defined $self->{Preferences}) {
        $self->{Preferences} = Preferences->new ($self->db);

        $self->{Preferences}->clearCache;     # needed for mod_perl

        # check for special I18N setting
        if (my $theLang = $self->getParams ('UseLang')) {
            $self->{Preferences}->Language ($theLang);
        }

        # check for excluded includes
        if (my $name = $self->calendarName) {

            my $hash = $self->{Preferences}->{Includes};

            # check params for special IncludeOnly, instead of using cookie
            my $incOnly = $self->getParams ('IncludeOnly');
            if ($incOnly) {
                my @calNames = split /-/, $incOnly;
                my %included = map {$_ => 1} @calNames;
                foreach (keys %$hash) {
                    $hash->{$_}->{Excluded} = !exists $included{$_};
                }
            } else {
                # get additional prefs from cookies (will change if more)
                my $cgi = CGI->new;
                my $excluded = $cgi->cookie ("EventFilter-$name") || '';
                my %cookie;
                foreach (split ',', $excluded) {
                    $cookie{$_}++;
                }
                foreach (keys %$hash) {
                    $hash->{$_}->{Excluded} = $cookie{$_};
                }
            }
        }
    }
    return $self->{Preferences};
}

# Return Permissions object. Creates new db if necessary
sub permission {
    my $self = shift;
    my $db = shift;
    $self->{Permission} = Permissions->new ($self->db)
        unless defined $self->{Permission};
    return $self->{Permission};
}

# Cache user permission for this operation
sub userPermitted {
    my ($self, $level) = @_;
    $self->{_userPermissions} ||= {};
    if (!exists $self->{_userPermissions}->{$level}) {
        $self->{_userPermissions}->{$level} =
            $self->permission->permitted ($self->getUser, $level);
    }
    return $self->{_userPermissions}->{$level};
}

# Get Database object. Create a new one if we don't have it yet.
# If we don't have a calendar name, we must be working with the MasterDB
sub db {
    my $self = shift;
    $self->{Database} = ($self->calendarName ? Database->new
                                                          ($self->calendarName)
                                             : MasterDB->new)
        unless $self->{Database};
    return $self->{Database};
}

# Get or Set. Setting also updates the preferences.
sub I18N {
    my $self = shift;
    my $newLanguage = shift;
    if ($newLanguage) {
        $self->{I18N} = I18N->new ($newLanguage);
        $self->db->setPreferences ({Language => $newLanguage});
    } else {
        $self->{I18N} = I18N->new ($self->prefs->Language)
            unless $self->{I18N};
    }
    return $self->{I18N};
}


# Auditing
#  See if we want to be audited, then create an audit obj and do it.
# This works on security classes (View, Add, Edit, Admin). Particular
# operations can override the auditType method for special case auditing (e.g.
# user login)
sub audit {
    my $self = shift;
    my $type = $self->auditType;
    my @auditTypes;
    my $db = $self->db;
    if ($type =~ /User/i) {     # use setting from Master if "user" opts.
        $db = MasterDB->new;
    }
    @auditTypes = $db->getAuditing ($type);
    return unless @auditTypes;
    my @auditObjs = map {AuditFactory->create ($_)} @auditTypes;
    foreach (@auditObjs) {
        $_->perform ($self, $db);
    }
}

sub auditType {           # might be overridden; e.g. UserLogin, UserLogout
    my $self = shift;
    return OperationFactory->getOpType (ref ($self));
}


# Subclasses should define this method for custom Audit Strings
# Return the string to be logged or mailed or whatever; undef means do nada
# Interface is defined to expect an arg if want short string
sub auditString {
     my $self = shift;
     my $short = shift;         # ignored in this default version

     my ($sec, $min, $hour, $mday, $mon, $year, @etc) = localtime (time);
     my $date = sprintf '%d/%.2d/%.2d %.2d:%.2d:%.2d',
                        $year+1900, $mon+1, $mday, $hour, $min, $sec;
     my $calNames = $self->calendarName;
     if (defined $self->{audit_calendars}) {
         $calNames = join ',', @{$self->{audit_calendars}};
     }
     return "$date " .
            "$ENV{REMOTE_ADDR} " . 
            ($self->getUsername || '-') . ' ' .
            ($calNames          || '-') . ' ' .
            ref ($self);
}

# Do HTTP Redirect; uncomment 3 lines for problematic IIS/IE combination
sub redir {
    my ($self, $url) = @_;
    my $cgi = CGI->new;

    # in case empty URL is aliased to this script; fixes double-post
    # problem w/Safari
    $url = "/$url" if ($url =~ /^\?/);

    return $cgi->redirect ($url)
# Uncomment following lines if redirect problems w/IE and IIS
#         unless ($ENV{HTTP_USER_AGENT} =~ /MSIE/i);
#     return $cgi->redirect (-uri => $url,
#                            -nph => 1);
}

sub cssDefaults {
    my ($self) = @_;
    $self = $self->new unless (ref $self);
    my $prefs = $self->prefs;
    my $css;

    my ($body_font, $body_size) = $prefs->font ('Body');
    my %body_css = (bg => 'white');
    $body_css{'font-family'} = $body_font if ($body_font);
    $body_css{'font-size'}   = $body_size if ($body_size);

    $css .= $self->cssString ('body', \%body_css);

    $css .= $self->cssString ('.PageHeader', {bg          => '#cccccc',
                                              'font-size' => 'xx-large',
                                              'font-weight' => 'bold',
                                              'text-align' => 'center'});
    $css .= $self->cssString ('.SectionHeader', {bg           => 'thistle',
                                                 padding   => '2px',
                                                 'font-size'   => 'medium',
                                                 'font-weight' => 'bold',
                                                 'text-align'  => 'center'});
    $css .= $self->cssString ('.ErrorHighlight',   {color => 'red'});
    $css .= $self->cssString ('.WarningHighlight', {color => 'darkred',
                                                    'font-weight' => 'bold'});
    $css .= $self->cssString ('.EventTag', {'font-size' => 'smaller'});

    # EventEditForm only for ShowDay, EventEditDelete, ShowMultiAddEvent, etc.
    $css .= $self->cssString ('.EntryWidgets', {bg => '#cccccc'});
    $css .= $self->cssString ('.InlineHelp', {'font-size'   => 'smaller',
                                              'margin-left' => '10px'});
}
sub cssFile {
    my $self = shift;
    $self = $self->new unless (ref $self);
    return $self->prefs->CSS_URL || MasterDB->new->getPreferences ('CSS_URL');
}
sub cssString {
    my ($selfOrClass, $name, $styles) = @_;
    my @sizes = ('.6em','.6em','.75em', '1em', '1.2em', '1.5em', '2em', '3em');
    my @foo;
    while (my ($attrib, $value) = each %$styles) {
        next if (!defined $value or $value eq '');
        # convenience thingies
        if ($attrib eq 'bg') {
            $attrib = 'background-color';
        }
        elsif ($attrib eq 'fg') {
            $attrib = 'color';
        }
        elsif ($attrib eq 'font-size' and $value =~ /^[1-7]$/) { # ugg
            # turns out that 1 --> x-small, 6-->xx-large, 7? oh well
            $value = $sizes[$value];
        }
        push @foo, "$attrib: $value";
    }
    return '' unless @foo;
    return "$name { " . join ('; ', @foo) . "}\n";
}

1;
