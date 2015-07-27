# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package QuickFilterBar;
use strict;

use CGI (qw (table Tr td a font));

sub new {
    my $class = shift;
    my ($operation) = @_;
    my $self = {};
    bless $self, $class;

    # Get event text filter
    my ($filterText, $filterIn, $ignoreCase, $useRegex, $filterCategories) =
            $operation->getParams (qw (TextFilter FilterIn
                                       IgnoreCase UseRegex FilterCategories));

    # Don't display unless we're being filtered
    return $self unless (defined $filterText or $filterCategories);

    my $calName = $operation->calendarName;
    my $i18n    = $operation->I18N;

    my $eventFilter = '';

    my %paramHash = %{$operation->{params}};
    delete $paramHash{CookieParams};
    @paramHash{qw (TextFilter FilterIn IgnoreCase UseRegex
                   FilterCategories)} = ();
    my $removelink = $operation->makeURL (\%paramHash);

    my ($textRow, $categoryRow);

    if (defined $filterText) {
        my $inString;
        $inString = $i18n->get('Event or Popup Text for')
            if $filterIn =~ /both/i;
        $inString = $i18n->get ('Event Text Only for')
            if $filterIn =~ /event/i;
        $inString = $i18n->get ('Popup Text Only for')
            if $filterIn =~ /popup/i;

        my $display = $filterText;
        $display =~ s/</&lt;/g;     # escape HTML
        $display =~ s/>/&gt;/g;

        $textRow = Tr (td ({align => 'center'},
                           font ({color => 'black',
                                  size  => '+1'},
                                 $i18n->get ('Filtering in') . " $inString -").
                           font ({color => 'red',
                                  size  => '+1'},
                                 $display) .
                           font ({color => 'black',
                                  size  => '+1'},
                                 "-" . ($useRegex ? ' (regex)' : ''))));
    }

    if ($filterCategories) {
        my @cats = split /$;/, $filterCategories;
        $categoryRow = Tr (td ({align => 'center'},
                               font ({color => 'black',
                                      size => '+1'},
                                  $i18n->get ('Only Events in Categories: ')) .
                               font ({color => 'red',
                                      size => '+1'},
                                     join ', ', @cats)));
    }

    my $removeFilter = a ({href => $removelink},
                          font ({color => 'black'}, '[' .
                                $i18n->get ('Remove Filter') . ']'));

    $self->{'html'} .= table ({width   => '100%',
                               bgcolor => '#cccccc',
                               border  => 0,
                               cellspacing => 0},
                              $textRow || '',
                              $categoryRow || '',
                              Tr (td ({align => 'center'},
                                      $removeFilter)));
    $self;
}

sub getHTML {
  my $self = shift;
  $self->{'html'} || '';
}

1;
