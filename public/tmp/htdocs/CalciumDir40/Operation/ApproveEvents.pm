# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Display/Approve/Delete tentative events

package ApproveEvents;
use strict;

use CGI;
use Calendar::Date;
use Calendar::Footer;
use Calendar::Header;
use Calendar::ListView;
use Calendar::Name;
use Calendar::Title;
use Operation::ShowIt;

use vars ('@ISA');
@ISA = ('ShowIt');              # primarily to get cssDefaults

sub perform {
    my $self = shift;

    if ($self->getParams ('ApproveIt')) {

        $self->{form_saved}++;
        $self->{audit_ids} = {};

        # Get event ids
        while (my ($name, $val) = each %{$self->{params}}) {
            next if ($val =~ /pending/i);
            next unless ($name =~ /Approve-(\d+)-(.*)/);
            my ($id, $calName) = ($1, $2);
            my $action = $val; # 'approve', 'delete', 'pending'
            my $db;
            if (defined $calName and $calName ne '') {
                $db = Database->new ($calName);
            } else {
                $db = $self->db;
            }
            my ($event, $date) = $db->getEventById ($id);
            next unless $event;
            if ($action =~ /approve/i) {
                $event->isTentative (0);
                $db->replaceEvent ($event, $date);
            } elsif ($action =~ /delete/i) {
                $db->deleteEvent ($date, $id, 'all');
            }
            $self->{audit_ids}->{$id} = [$action, $date, $event->text];
        }

        # If no tentative events left, go back to cal
        my $eventHash = $self->db->getTentativeEvents;
        $self->db->addIncludedTentativeEvents ($self->getUsername, $eventHash);
        if (!keys %$eventHash) {
            print $self->redir ($self->makeURL ({Op => 'ShowIt'}));
            return;
        }
    }

    my $prefs = $self->prefs;
    my @page = (Name->new      ($prefs),
                Title->new     ($self, 'ignored', 'Approval'),
                ListView->new  ($self, Date->new, Date->new,
                                {mode => 'Approval'}),
                Footer->new    ($prefs),
                SubFooter->new ($prefs));

    # Get each piece's CSS
    $self->{_childrenCSS} = '';
    foreach (@page) {
        next unless defined;
        $self->{_childrenCSS} .= $_->cssDefaults ($prefs)
            if $_->can ('cssDefaults');
    }

    # Do Header *after* getting each ones CSS
    unshift @page, Header->new (op     => $self,
                                title  => $prefs->Description);

    foreach (@page) {
        next unless defined;
        my $html = ($_->getHTML || '');
        print "$html \n";
    }
    my $cgi = CGI->new ('');
    print $cgi->end_html
        unless (($ENV{SERVER_PROTOCOL} || '') eq 'INCLUDED');

    return;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{form_saved};
    my $line = $self->SUPER::auditString ($short);

    if ($short) {
        $line .= ' ';
        while (my ($id, $info) = each %{$self->{audit_ids}}) {
            $line .= "$id: $info->[0],";
        }
        chop $line;
        return $line;
    }

    my $message = "These tentative events on the '" . $self->calendarName .
                  "' Calendar were processed:\n\n";

    my $text = '';
    while (my ($id, $info) = each %{$self->{audit_ids}}) {
        $text .= ' ' . sprintf ("%7s", $info->[0]) . "d - $info->[1] - " .
                "$info->[2]\n";
    }
    $text ||= '    -no events processed-';
    $message .= $text;

    return "$line\n\n$message\n";
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css = $self->SUPER::cssDefaults;
    $css .= Operation->cssString ('.EventTag',
                                  {bg    => 'gray',
                                   color => 'darkred'});
    $css;
}

1;
