# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# SearchPerform - do the search, display the results in condensed mode

package SearchPerform;
use strict;
use CGI (':standard');

use Calendar::Date;
use Calendar::Header;
use Calendar::Name;
use Calendar::NavigationBar;
use Calendar::Title;
use Calendar::ListView;
use Calendar::Footer;
use Operation::ShowIt;

use vars ('@ISA');
@ISA = ('ShowIt');              # primarily to get cssDefaults

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    my ($fromDate, $toDate, $searchText, $searchIn, $useRegex, $categories) =
        $self->getParams (qw (FromDate ToDate TextFilter FilterIn UseRegex
                              FilterCategories));

    $self->{audit_searchstring} = $searchText;

    my $textRow;
    if ($searchText) {
        my $inString;
        $inString = $i18n->get ('Event or Popup Text for') . ' -'
            if $searchIn =~ /both/i;
        $inString = $i18n->get ('Event Text Only for') . ' -'
            if $searchIn =~ /event/i;
        $inString = $i18n->get ('Popup Text Only for') . ' -'
            if $searchIn =~ /popup/i;

        my $display = $searchText;
        $display =~ s/</&lt;/g;     # escape HTML
        $display =~ s/>/&gt;/g;

        $textRow = Tr (td ({align => 'center'},
                           font ({color => 'black'},
                                 $i18n->get ('Searching') . " $inString") .
                           font ({color => 'red'}, $display) .
                           font ({color => 'black'},
                                 "-" . ($useRegex ? ' (regex)' : ''))));
    }

    my $categoryRow;
    if ($categories) {
        my @cats = split /$;/, $categories;
        $categoryRow = Tr (td ({align => 'center'},
                               $cgi->font ({color => 'black'},
                                  $i18n->get ('Only Events in Categories: ')) .
                               $cgi->font ({color => 'red'},
                                     join ', ', @cats)));
    }

    my ($amount, $navType, $type) = $self->ParseDisplaySpecs ($self->prefs);

    $fromDate = Date->new ($fromDate);
    $toDate   = Date->new ($toDate);

    my @page;

    push @page, Name->new ($self->prefs);

    delete $self->{params}->{TextFilter}; # for links in nav bar
    delete $self->{params}->{FilterIn};   # for links in nav bar
    delete $self->{params}->{FilterCategories};   # for links in nav bar
    $self->{params}->{NavType}    = 'Absolute';
    push @page, NavigationBar->new ($self, $fromDate, 'top');

    $self->{params}->{TextFilter} = $searchText;
    $self->{params}->{FilterIn}   = $searchIn;
    $self->{params}->{FilterCategories} = $categories;

    push @page, Title->new     ($self, $amount, $type, $fromDate, $toDate);
    push @page, ListView->new  ($self, $fromDate, $toDate, {mode => 'Search'});
    push @page, Footer->new    ($self->prefs);
    push @page, NavigationBar->new ($self, $fromDate, 'bottom');
    push @page, SubFooter->new ($self->prefs);

    # Get each piece's CSS
    $self->{_childrenCSS} = '';
    foreach (@page) {
        next unless defined;
        $self->{_childrenCSS} .= $_->cssDefaults ($self->prefs)
            if $_->can ('cssDefaults');
    }
    my $head = Header->new (op    => $self,
                            title => $i18n->get ('Search Results from') .
                                        ' "' . $self->calendarName . '"');
    print $head->getHTML;
    print $cgi->table ({width   => '100%',
                        bgcolor => '#cccccc',
                        border  => 0},
                       $cgi->Tr ($cgi->td ({align  => 'center'},
                                           $cgi->font ({size  => '+3',
                                                        color => 'black'}, 
                                              $i18n->get ('Search Result')))),
                       $textRow     || '',
                       $categoryRow || '');

    foreach (@page) {
        next unless defined;
        my $html = ($_->getHTML || '');
        print "$html \n";
    }
    print $cgi->end_html
        unless (($ENV{SERVER_PROTOCOL} || '') eq 'INCLUDED');
}

sub auditString {
    my ($self, $short) = @_;
    my $line =  $self->SUPER::auditString ($short);
    $line .= ' ' . $self->{audit_searchstring}
        if $self->{audit_searchstring};
    $line;
}

1;
