#!/Perl/bin/perl

# --------------------------------------------------------
# Lizenz:
# --------------------------------------------------------
# Namensnennung-NichtKommerziell-Weitergabe unter gleichen Bedingungen 2.0 
# Deutschland
#
# Sie d�rfen:
# den Inhalt vervielf�ltigen, verbreiten und �ffentlich auff�hren
# Bearbeitungen anfertigen
# 
# Zu den folgenden Bedingungen:
# Namensnennung. Sie m�ssen den Namen des Autors/Rechtsinhabers nennen.
# Keine kommerzielle Nutzung. Dieser Inhalt darf nicht f�r kommerzielle Zwecke 
# verwendet werden.
# Weitergabe unter gleichen Bedingungen. Wenn Sie diesen Inhalt bearbeiten oder 
# in anderer Weise umgestalten, ver�ndern oder als Grundlage f�r einen anderen 
# Inhalt verwenden, dann d�rfen Sie den neu entstandenen Inhalt nur unter 
# Verwendung identischer Lizenzbedingungen weitergeben.
# Im Falle einer Verbreitung m�ssen Sie anderen die Lizenzbedingungen, unter die 
# dieser Inhalt f�llt, mitteilen.
# Jede dieser Bedingungen kann nach schriftlicher Einwilligung des Rechtsinhabers 
# aufgehoben werden.
# 
# Die gesetzlichen Schranken des Urheberrechts bleiben hiervon unber�hrt.
# 
# Unter http://creativecommons.org/licenses/by-nc-sa/2.0/de/legalcode finden
# Sie eine Zusammenfassung des Lizenzvertrags in allgemeinverst�ndlicher Sprache.

# --------------------------------------------------------
# siehe http://creativecommons.org/licenses/by-nc-sa/2.0/de/ f�r die Onlinefassung
# der o.g. Lizenz

use strict;
use warnings;
use Data::Dumper;
use File::DosGlob();
use File::Spec;

package ThumbNailCreate;

use File::Basename qw(fileparse);
use FileHandle;
use GD;
use Image::Size();
use Tk;
use Tk::ROText;
use Tk::TFrame;
use Tk::Dialog;

# --------------------------------------------------------
# Klassenvariablen
# --------------------------------------------------------
$ThumbNailCreator::VERSION 	= 1.0;
$ThumbNailCreator::REVISION 	= 1.0;

# --- Configuration ---
# where are the original images located
my $quellverz = ''; 			# hier liegen die Orginalbilder
my $thumbnailverz = '';			# hier werden die Thumbnails erzeugt
my $thumbnailWidth = 200;      	# width of thumbnails
my $thumbnailQuality = 100;    	# integer from 1 to 100 (1=schlecht, 100=gut)
my $dateiendungen = qr/jpg|jpeg|png/i; # Die Dateitypen, nach denen gesucht wird
my $quellInitialDir = 'C:/zwischen/test';
my $zielInitialDir  = 'C:/zwischen/test/thumbnails';	
# GUI
my $guiWidth = 600;
my $guiHeight = 320;
# --- Code ---
GD::Image->trueColor(1); # improves image quality: thx to Perli from www.perl.de

# sonstige KLassenvariablen
my %gui = (); # Elemente des MainWindow

# --------------------------------------------------------
# Konstruktor
# --------------------------------------------------------
sub new {
  my $self=shift;

  my $ref = {};
  bless($ref, $self);  # nicht &bless schreiben!

  return $ref;
} # /new

# --------------------------------------------------------
# Methoden (privat)
# --------------------------------------------------------
sub _populate {
	my $self = shift;
	my $mw   = shift;
	
	# -- [Elemente der GUI erzeugen] -- #
	
    # -- [ Menu erstellen ] -- #
	my $menuitems = [
	    [Cascade => "~Datei", -menuitems =>
	        [
	            [Button =>	"~Quellverzeichnis aussuchen", 
	            			-command => sub{ $self->_waehleQuellVerz($mw) }],
	            [Button =>	"~Zielverzeichnis aussuchen", 
	            			-command => sub{ $self->_waehleZielVerz($mw) }],
	            [Separator => ""],
	            # Das Programmende event. etwas besser gestalten?
	            # $mw->destroy()...
	            [Button => "~Beenden", -command => sub{ exit(0); }],
	        ],
	    ],
	    [Cascade => "~Help", -menuitems =>
	    	[
	    		[Button => "~�ber ThumbNailCreator", 
	    					-command=>sub{ $self->_ueber($mw) }]
	    	],
	    ],
	];
	     
	
	$gui{'QuellLabel'}  = $mw->Label(-text => 'Quellverzeichnis');
	$gui{'QuellEntry'}  = $mw->Entry(-textvariable => \$quellverz, -width=>60);
	$gui{'QuellButton'} = $mw->Button(	-text => 'w�hlen...', 
									 	-command => sub{ 
									 		$self->_waehleQuellVerz($mw) 
									 	});
	$gui{'ZielLabel'}  = $mw->Label(-text => 'Zielverzeichnis');
	$gui{'ZielEntry'}  = $mw->Entry(-textvariable => \$thumbnailverz, -width=>60);
	$gui{'ZielButton'} = $mw->Button(	-text => 'w�hlen...', 
									 	-command => sub{ 
									 		$self->_waehleZielVerz($mw) 
						 				});


	$gui{'OptionSet'} = $mw->TFrame(
		-label => [ -text => 'Optionen' ],
        -borderwidth => 1,
	);
		
		$gui{'BreiteLabel'} = $gui{'OptionSet'}->Label(
			-text=>'Thumbnailbreite (Pixel)'
		);												
		$gui{'BreiteEntry'} = $gui{'OptionSet'}->Entry(	
			-textvariable=>\$thumbnailWidth, 
			-width=>8
		);
		
		$gui{'QualitaetLabel'} = $gui{'OptionSet'}->Label( -text=>'Qualit�t', );
		$gui{'QualitaetEntry'} = $gui{'OptionSet'}->Entry( 
			-textvariable => \$thumbnailQuality,
			-width => 3,
		);
		
		$gui{'QualitaetSkala'} = $gui{'OptionSet'}->Scale(
			-from 		=> 0,
			-to	 		=> 100,
			-variable	=> \$thumbnailQuality,
			-sliderlength => 6,
			-orient 	=> 'horizontal',
			-length		=> 100,
			-showvalue 	=> 0,
			-bg => 'yellow',
			-activebackground => 'blue',
			-border => 0,
		);
		
	$gui{'Spacer'} = $mw->Frame(-width=>10, -height=>2);
						 				
	$gui{'startKnopf'} = $mw->Button(	-text => 'Erzeuge die Thumbs',
										-command => sub{
											$self->_erzeugeThumbnails(
												$mw, $gui{'statusText'});
										});
	$gui{'statusText'} = $mw->Scrolled('ROText', -width=>80, -height=>10, 
										-wrap=>'word', -scrollbars=>'e' );
				
	
	# -- [Bindings erzeugen] -- #
	# -- (1.1 - QuellLabel) -- #
	$gui{'QuellLabel'}->bind(
		'<Double-Button-1>', 
		[
		 	sub{ $self->_waehleQuellVerz($mw); },
			$gui{'QuellLabel'}, 
		]
	); 
	# -- (1.2 - unfeine Wiederholung bei 3fach-Klick ausmerzen) -- #
	$gui{'QuellLabel'}->bind('<Triple-Button-1>', [sub{return;},]); 
	
	# -- (2.1 - ZielLabel) -- #
	$gui{'ZielLabel'}->bind(
		'<Double-Button-1>', 
		[
			sub{ $self->_waehleZielVerz($mw); },
			$gui{'ZielLabel'},
		]
	); 
	# -- (2.2 - unfeine Wiederholung bei 3fach-Klick ausmerzen) -- #
	$gui{'ZielLabel'}->bind('<Triple-Button-1>', [sub{return;},]);		
	
	
	# -- [Elemente packen] -- #	
	$gui{'Menu'} = $mw->Menu(-menuitems => $menuitems);	
	$mw->configure(-menu => $gui{'Menu'});	
	
	$gui{'QuellLabel'}->grid(-row=>0,-column=>0,);
	$gui{'QuellEntry'}->grid(-row=>0,-column=>1,);
	$gui{'QuellButton'}->grid(-row=>0,-column=>2,);
	
	$gui{'ZielLabel'}->grid(-row=>1,-column=>0,);
	$gui{'ZielEntry'}->grid(-row=>1,-column=>1,);
	$gui{'ZielButton'}->grid(-row=>1,-column=>2,);
		
	$gui{'OptionSet'}->grid(-row=>2, -column=>0, -columnspan=>3, -sticky=>'we');
		$gui{'BreiteLabel'}->pack(-side=>'left', -padx=>10, -pady=>5, );
		$gui{'BreiteEntry'}->pack(-side=>'left',);
		$gui{'QualitaetLabel'}->pack(-side=>'left', -padx=>10,);
		$gui{'QualitaetEntry'}->pack(-side=>'left', );
		$gui{'QualitaetSkala'}->pack(-side=>'left', );
	
	$gui{'Spacer'}->grid(-row=>3, -column=>0, -columnspan=>3, -sticky=>'w');
	
	$gui{'startKnopf'}->grid(-row=>4, -column=>0, -columnspan=>3, -sticky=>'w', );
	
	$gui{'statusText'}->grid(-row=>5, -column=>0, -columnspan=>3, -sticky=>'w', );
	
	# -- [nettes kleines Update] -- #
	$mw->update();
	
} # /populate

sub _waehleQuellVerz {
	my $self = shift;
	my $mw = shift;
	$quellverz = $mw->chooseDirectory(
		-initialdir => $quellInitialDir,
		-parent => $mw,
		-title => 'Bitte w�hlen Sie das Verzeichnis in welchem sich die ' . 
					'Orginalbilder befinden.',
		-mustexist => 1,
	);
} # /waehleQuellVerz

sub _waehleZielVerz {
	my $self = shift;
	my $mw = shift;
	$thumbnailverz = $mw->chooseDirectory(
		-initialdir => $zielInitialDir,
		-parent => $mw,
		-title => 'Bitte w�hlen Sie das Verzeichnis in dem Sie die Thumbnails ' .
					'erstellen m�chten.',
		-mustexist => 1,
	);	
} # /_waehleZielVerz

sub _erzeugeThumbnails {
	my $self 	= shift;
	my $mw 		= shift;
	my $status 	= shift;
	
	# Status-Text von vorherigen Mitteilungen bereinigen	
	$status->delete('0.0','end');
	
	# Zeitinfo um zu zeigen dass was passiert ist wenn der Benutzer die selbe
	# Aktion wiederholt nacheinander t�tigt
	$self->_write($status, 'Beginn @ ' . localtime());
	
	if( -d $quellverz and -d $thumbnailverz ) {

		# loop over all files in directory
		my @bilder = File::DosGlob::glob(
			File::Spec->catfile($quellverz, '*.*')
		);		
			
		foreach my $filename ( @bilder ) {
		
			# extract filetype and convert it to lowercase
			my $ending = (fileparse($filename, $dateiendungen))[-1];
		    $ending = lc($ending);
		    next unless $ending =~ $dateiendungen;

		    # get thumbnail height and width and heigth of original image
			my ($thumbnailHeight, $width, $height) =
		         $self->_GetImageSize($filename, $thumbnailWidth)
		    or next;

		    # build target filename
		    my $targetFilename = $filename;
		    my $qv = File::Spec->catfile($quellverz);		# Einmal File::Spec
		    my $tv = File::Spec->catfile($thumbnailverz);	# immer File::Spec!
		    $targetFilename =~ s/\Q$qv\E/$tv/g;
		
		    # do some debugging output
		    $self->_write($status, "$filename: ${width}x$height\t");
		    $self->_write($status, 
		    	"=> $targetFilename: ${thumbnailWidth}x$thumbnailHeight\n");
		    	
		    # try to read image
		    my $image = undef; 
		    if ($ending eq 'jpg' or $ending eq 'jpeg') {
		        $image = GD::Image->newFromJpeg($filename);
		    }elsif ($ending eq 'png') {
		        $image = GD::Image->newFromPng($filename);
		    }
		    
		    # check if reading was successful
		    $image or $self->_write($status,
		    	"Error: couldn't read $filename as $ending: $!\n"), next;
		    	
		    # create thumbnail
		    my $thumbnail = GD::Image->new($thumbnailWidth, $thumbnailHeight);
		    $thumbnail->copyResized( $image, 0,0, 0,0,
		                             $thumbnailWidth, $thumbnailHeight,
		                             $width, $height,
		                            );
		
		    # open outfile
		    my $fh = new FileHandle "> $targetFilename";
		    if (defined $fh) {
				binmode($fh);
				
			    # write image to file
			    if ($ending eq 'jpg' or $ending eq 'jpeg') {
			        print $fh $thumbnail->jpeg($thumbnailQuality);
			    }elsif ($ending eq 'png') {
			        print $fh $thumbnail->png();
			    }

			    # close file and do error checking (e.g. disk full?)			    
		        $fh->close() or $self->_write($status,
		        	"Error: couldn't write to file '$targetFilename': $!\n");
		        
		    }else {
		    	# Fehler: Die Datei konnte nicht ge�ffnet werden
		        $self->_write($status, 
		        	"Error: couldn't create '$targetFilename': $!\n"), next;
		    }
    
		} # for

	}else{
		$self->_write($status, 'Bitte geben Sie ein g�ltiges Quellverzeichnis an!')
			unless -d $quellverz;
		$self->_write($status, 'Bitte geben Sie ein g�ltiges Zielverzeichnis an!')
			unless -d $thumbnailverz;		
	}
	
	# Eine kleine Best�tigung ausgeben, damit der Beutzer aus der Spannungsphase 
	# entlassen wird
	$self->_write($status, 'Ende @ ' . localtime());
	
} # /_erzeugeThumbnails

sub _write ($$) {
	# schreibt einen Text in das �bergebene Text-Widget
	my $self 	= shift;
	my $widget 	= shift;
	my $text 	= shift;	
	
	# f�ge ein Newline-Zeichen an falls keinen angegeben wurde damit man immmer
	# in einer neuen Zeile landet...
	$text .= "\n" unless $text =~ m/\n$/;
	
	$widget->insert('end', $text);	
} # /_write

sub _GetImageSize {
	my $self = shift;
    my ($filename, $thumbnailWidth) = @_;
    my (@size) = &Image::Size::attr_imgsize($filename);
    unless ( $size[1] and $size[3]) {
        warn "Error: couldn't get imagesize of $filename\n";
        return ();
    } # unless
    my $thumbnailHeight = int $thumbnailWidth * $size[3] / $size[1];
    return ($thumbnailHeight, @size[1,3]);
} # _GetImageSize

sub _ueber {
	# Gibt ein paar Informationen �ber ThumbNailCreator, Version, Autor, Quellen
	# und Helfer. Event. noch URLs zu den Webseiten hinzuf�gen.
	my $self 	= shift;
	my $mw 		= shift;

	# Bitte die Unordnung entschuldigen, es ist 04:20 Uhr.	
	my $text = qq~use ThumbNailCreator;~;
	$text .= "\n# " . '-' x 48 . "\n";
	$text .= qq~\$ThumbNailCreator::Version = $ThumbNailCreator::VERSION;~;
	$text .= qq~\$ThumbNailCreator::Autor = "Alexander Becker";~;
	$text .= "\n# " . '-' x 48 . "\n";
	$text .= qq+"my \$dank = qq~Vielen Dank f�r die zahlreichen Snipplets welche ich im Internet finden konnte. Nur so wurde dieses Programm �berhaupt m�glich. Besonderen Dank an die Mitglieder der http:://www.perl-community.de, insbesondere \"strat\" f�r den Thumbnail-Code und \"esskar\" f�r das MainWindow-Zentrieren-Schnipsel~;+;
	$text .= "\n# " . '-' x 48 . "\n";
	$text .= qq+"my \$helfer = qq~Mithelfer sind nat�rlich herzlich gebeten das Programm zu verbessern und zu erweitern.~;+;
	$text .= "\n# " . '-' x 48 . "\n";
	$text .= qq~my \$lizenz = "Creative Commons: Namensnennung-NichtKommerziell-Weitergabe unter gleichen Bedingungen 2.0 Deutschland";~;
		
	$gui{UeberDialog} = $mw->Dialog(
		-title			=> '�ber ThumbNailCreator',
		-bitmap 		=> 'question',
		-default_button => 'exit(0);',
		-font			=> 'Verdana', 
		-buttons		=> [qw(exit(0);)],
	);
	
	$gui{UeberText} = $gui{UeberDialog}->ROText(
		-width	=> 50, 
		-height	=> 20,
		-wrap 	=> 'word',
	)->pack();
	$gui{UeberText}->insert("0.0", $text);
	
	$gui{UeberDialog}->Show();
	
	
} # /ueber

# --------------------------------------------------------
# Methoden (�ffentlich)
# --------------------------------------------------------
sub run {
	# Startet die grafische Oberfl�che
	my $self = shift;
	
	# -- [MainWindow erzeugen] -- #
	my $mw = Tk::MainWindow->new(
		-width 	=> $guiHeight,
		-height	=> $guiWidth,
		-title	=> "ThumbNailCreator (Version $ThumbNailCreator::VERSION)",
	);
	
	# -- [Wieso sollte ich sonst H�he und Breite angeben?] -- #
	$mw->gridPropagate(0);
	$mw->packPropagate(0);
	
	# -- [Bildschirmgr��e holen] -- #
	my $screenHeight  = $mw->screenheight;
	my $screenWidth   = $mw->screenwidth;

	# -- [GUI zentrieren] -- #
	$mw->geometry($guiWidth."x".$guiHeight);
	$mw->geometry("+" .
                   int($screenWidth/2 - $guiWidth/2) .
                   "+" .
                   int($screenHeight/2 - $guiHeight/2)
    );
           
    $self->_populate($mw);
	
	MainLoop;
} # /run

1; # /package ThumbNailCreate

# package main;

my $tnc = ThumbNailCreate->new();
$tnc->run();