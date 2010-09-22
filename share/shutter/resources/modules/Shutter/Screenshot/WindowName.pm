###################################################
#
#  Copyright (C) 2008, 2009, 2010 Mario Kemper <mario.kemper@googlemail.com> and Shutter Team
#
#  This file is part of Shutter.
#
#  Shutter is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  Shutter is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Shutter; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
###################################################

package Shutter::Screenshot::WindowName;

#modules
#--------------------------------------
use utf8;
use strict;
use warnings;

use Shutter::Screenshot::Window;
use Data::Dumper;
our @ISA = qw(Shutter::Screenshot::Window);

#Glib and Gtk2
use Gtk2;
use Glib qw/TRUE FALSE/; 

#--------------------------------------

sub new {
	my $class = shift;

	#call constructor of super class (shutter_common, include_cursor, delay, notify_timeout, include_border)
	my $self = $class->SUPER::new( shift, shift, shift, shift, shift );

	$self->{_hide_time} = shift;   #a short timeout to give the server a chance to redraw the area that was obscured
	
	bless $self, $class;
	return $self;
}

#~ sub DESTROY {
    #~ my $self = shift;
    #~ print "$self dying at\n";
#~ } 
#~ 

sub window_find_by_name {
	my $self = shift;
	my $name_pattern = shift;
	
	my $active_workspace = $self->{_wnck_screen}->get_active_workspace;
	
	#cycle through all windows
	my $output = 7;
	foreach my $win ( $self->{_wnck_screen}->get_windows_stacked ) {
		if ( $active_workspace && $win->is_on_workspace( $active_workspace ) ) {
			if ( $win->get_name =~ m/$name_pattern/i ) {
				$output = $self->window_by_xid($win->get_xid);
				last;
			}
		}
	}	
		
	return $output;
}

sub window_by_xid {
	my $self = shift;
	my $xid  = shift;

	my $gdk_window  = Gtk2::Gdk::Window->foreign_new( $xid );
	my $wnck_window = Gnome2::Wnck::Window->get( $xid );
	
	#~ print $xid, " - ", $gdk_window, " - ", $wnck_window, "\n";
	
	my $output = 0;
	if (defined $gdk_window && defined $wnck_window){
	
		my ( $xp, $yp, $wp, $hp ) = $self->get_window_size( $wnck_window, $gdk_window, $self->{_include_border} );

		#focus selected window (maybe it is hidden)
		$gdk_window->focus(Gtk2->get_current_event_time);
		Gtk2::Gdk->flush;
	
		#A short timeout to give the server a chance to
		#redraw the area
		Glib::Timeout->add ($self->{_hide_time}, sub{
	
			my ($output_new, $l_cropped, $r_cropped, $t_cropped, $b_cropped) = $self->get_pixbuf_from_drawable($self->{_root}, $xp, $yp, $wp, $hp);
	
			#save return value to current $output variable 
			#-> ugly but fastest and safest solution now
			$output = $output_new;	
	
			#respect rounded corners of wm decorations (metacity for example - does not work with compiz currently)	
			if($self->{_x11}{ext_shape} && $self->{_include_border}){
				$output = $self->get_shape($xid, $output, $l_cropped, $r_cropped, $t_cropped, $b_cropped);				
			}
	
			#set name of the captured window
			#e.g. for use in wildcards
			if($output =~ /Gtk2/){
				$self->{_action_name} = $wnck_window->get_name;
			}
	
			#set history object
			$self->{_history} = Shutter::Screenshot::History->new($self->{_sc}, $self->{_root}, $xp, $yp, $wp, $hp, undef, $xid, $xid);

			$self->quit;
			return FALSE;	
		});	
	
		Gtk2->main();
	
	}else{	
		$output = 4;	
	}

	return $output;
}

sub redo_capture {
	my $self = shift;
	my $output = 3;
	if(defined $self->{_history}){
		my ($last_drawable, $lxp, $lyp, $lwp, $lhp, $lregion, $wxid, $gxid) = $self->{_history}->get_last_capture;
		($output) = $self->window_by_xid($wxid);
	}
	return $output;
}	

sub get_history {
	my $self = shift;
	return $self->{_history};
}

sub get_error_text {
	my $self = shift;
	return $self->{_error_text};
}

sub get_action_name {
	my $self = shift;
	return $self->{_action_name};
}

1;