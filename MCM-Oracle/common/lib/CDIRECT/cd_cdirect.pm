package CDIRECT::cd_cdirect;

use strict;

use File::Basename;

#-------#
sub new {
#-------#
    my ($class, %args) = @_;

    my $self = {};

    $self->{config}            = $args{config};
    $self->{logger}            = $args{logger};
    $self->{sybase}            = $args{sybase};
    $self->{db_audit}          = $args{db_audit};
    $self->{runtype}           = $args{runtype},
    $self->{pillar}            = $args{pillar},
    $self->{short_entity}      = $args{short_entity};
    $self->{glob_entity}       = $args{glob_entity};
    $self->{content}           = $args{content};
    $self->{target}            = $args{target};
    $self->{segment}           = $args{segment};
    $self->{mx_dates}          = $args{mx_dates};
    $self->{audit}             = 'Y';
    $self->{send}              = 'Y';

    $self->{localdir}          = '';
    $self->{localfile}         = '';
    $self->{localnode}         = '';

    $self->{remotedir}         = 'NO.REMOTEDIR';
    $self->{remotefile}        = '';
    $self->{remotenode}        = 'NO.REMOTENODE';
    $self->{remotejob}         = 'NO.REMOTEJOB';
    $self->{remotedcb}         = 'NO.REMOTEDCB';
    $self->{remotetrigger}     = 'NO.REMOTETRIGGER';

    $self->{transferinfo}      = '';

    $self->{template_keyfile}  = '';
    $self->{template_path}     = '/ontw/etc/ftkeys/templates' ;
    $self->{wmx_path}          = '/ontw/etc/ftkeys/wmx' ;
    $self->{wmx_keyfile}       = '';
    $self->{recordlength}      = 'Not needed';



    bless $self, $class;

    return $self;
}

#--------------------#
sub get_transferinfo {
#--------------------#

    my ( $self ) = @_;

    my $target       = $self->{target} ;

    $self->{transferinfo} = "ConnectDirect towards $target" ; 


    return $self->{transferinfo} ;

}


#-----------------#
sub Send_YN       {
#-----------------#

      my ( $self, %args )  = @_;

      my $logger           = $self->{logger} ;
      my $send             = $self->get_send() ;

      if ( $send ne 'Y' || $self->{remotenode} eq 'NO.SERVER' ){

         $logger->warn("C:D send is disabled, not sending ...") ;
         print "C:D send is disabled, not sending ...\n" ;
         
         exit 0 ;

      }

}


#-----------------#
sub get_localnode {
#-----------------#

  my ( $self ) = @_;

  my $config   = $self->{config} ;

  my $hostname     = Mx::Util->hostname;

  my $cdnode = 'S'.substr $hostname,1 ;
  $cdnode =~ tr/[a-z]/[A-Z]/ ;

  $self->{localnode} = $cdnode.'.SERVER';

  return $self->{localnode} ;

}

#------------------#
sub get_remotenode {
#------------------#

    my ( $self ) = @_;

    my $target       = $self->{ target };
    my $pillar       = $self->{ pillar };

    my %remote_nodes ;

    if ( $target eq 'IBS'        ) { %remote_nodes = ( O => "NO.SERVER",     A => "ACP.SSKC",        P => "MVS.SSPC"         ) ; } ;
    if ( $target eq 'DATAKOEPEL' ) { %remote_nodes = ( O => "NO.SERVER",     A => "PRMBOP1",         P => "PRMBOP1"          ) ; } ;
    if ( $target eq 'EMS'        ) { %remote_nodes = ( O => "NO.SERVER",     A => "ACP.SSKC",        P => "MVS.SSPC"         ) ; } ;
    if ( $target eq 'IL'         ) { %remote_nodes = ( O => "NO.SERVER",     A => "POWMARA1.SERVER", P => "POWMARP1.SERVER"  ) ; } ;
    if ( $target eq 'IC' || $target eq 'ICIL'         ) { %remote_nodes = ( O => "NO.SERVER",     A => "ACP.SSKC",        P => "MVS.SSPC"         ) ; } ;
    if ( $target eq 'ALM'        ) { %remote_nodes = ( O => "NO.SERVER",     A => "S1A00250",        P => "S0A00319"         ) ; } ;
    if ( $target eq 'ABSOLUT1'   ) { %remote_nodes = ( O => "ABST1.SERVER",  A => "ABSA1.SERVER",    P => "ABSP1.SERVER"     ) ; } ;
    if ( $target eq 'ABSOLUT2'   ) { %remote_nodes = ( O => "ABST2.SERVER",  A => "ABSA2.SERVER",    P => "ABSP2.SERVER"     ) ; } ;
    if ( $target eq 'FAME'       ) { %remote_nodes = ( O => "NO.SERVER",     A => "S1008500.SERVER", P => "S0006900.SERVER"  ) ; } ;
    if ( $target eq 'ERIS'       ) { %remote_nodes = ( O => "S2003680",      A => "NO.SERVER",       P => "SA005675"         ) ; } ;
    if ( $target eq 'EGATE1'     ) { %remote_nodes = ( O => "EAIO2.SERVER",  A => "EAIA1.SERVER",    P => "EAIP1.SERVER"     ) ; } ;
    if ( $target eq 'EGATE'      ) { %remote_nodes = ( O => "EAIO2.SERVER",  A => "EAIA1.SERVER",    P => "EAIP1.SERVER"     ) ; } ;
    if ( $target eq 'EGATE2'     ) { %remote_nodes = ( O => "EAIO2.SERVER",  A => "EAIA2.SERVER",    P => "EAIP2.SERVER"     ) ; } ;
    if ( $target eq 'EGATE3'     ) { %remote_nodes = ( O => "EAIO2.SERVER",  A => "EAIA3.SERVER",    P => "EAIP3.SERVER"     ) ; } ;
    if ( $target eq 'TOPCALL'    ) { %remote_nodes = ( O => "NO.SERVER",     A => "WFLA1",           P => "WFLP1"            ) ; } ;
    if ( $target eq 'ILRISK'     ) { %remote_nodes = ( O => "NO.SERVER",     A => "POWA1.SERVER",    P => "POWP1.SERVER"     ) ; } ;
    if ( $target eq 'SENTRY'     ) { %remote_nodes = ( O => "NO.SERVER",     A => "CAMA1.SERVER",    P => "CAMP1.SERVER"     ) ; } ;
    if ( $target eq 'FDE'        ) { %remote_nodes = ( O => "NO.SERVER",     A => "PARA1.SERVER",    P => "PARP1.SERVER"     ) ; } ;
    if ( $target eq 'MVS'        ) { %remote_nodes = ( O => "NO.SERVER",     A => "ACP.SSKC",        P => "MVS.SSPC"         ) ; } ;
    if ( $target eq 'RDJ'        ) { %remote_nodes = ( O => "ONT.SSTC",      A => "ACP.SSKC",        P => "MVS.SSPC"         ) ; } ;
    if ( $target eq 'OV'         ) { %remote_nodes = ( O => "NO.SERVER",     A => "ACP.SSKC",        P => "MVS.SSPC"         ) ; } ;
    if ( $target eq 'WHT'        ) { %remote_nodes = ( O => "NO.SERVER",     A => "ACP.SSKC",        P => "MVS.SSPC"         ) ; } ;
    if ( $target eq 'ALGO'       ) { %remote_nodes = ( O => "NO.SERVER",     A => "ALGOA1.SERVER",   P => "ALGOP1.SERVER"    ) ; } ;
    if ( $target eq 'ESB'        ) { %remote_nodes = ( O => "ESBT1.SERVER",  A => "ESBA2.SERVER",    P => "ESBP2.SERVER"     ) ; } ;
    if ( $target eq 'ESB1'       ) { %remote_nodes = ( O => "ESBT1.SERVER",  A => "ESBA1.SERVER",    P => "ESBP1.SERVER"     ) ; } ;
    if ( $target eq 'ESB2'       ) { %remote_nodes = ( O => "ESBT2.SERVER",  A => "ESBA2.SERVER",    P => "ESBP2.SERVER"     ) ; } ;
    if ( $target eq 'ESB3'       ) { %remote_nodes = ( O => "ESBT3.SERVER",  A => "ESBA3.SERVER",    P => "ESBP3.SERVER"     ) ; } ;

    $self->{remotenode} = $remote_nodes { $self->{pillar} } ;

    return $self->{remotenode} ;

}


#----------------------#
sub CalculateFileProps {
#----------------------#

      my ( $self, %args )  = @_;

      my $logger           = $self->{logger} ;

      my $localdir         = $self->get_localdir() ;
      my $localfile        = $self->get_localfile() ;

      my $tot_filesize     = 0 ;
      my $filesize         = 0 ;
      my $filesize_mb      = 0 ;

      my $totlinecount     = 0 ;

      my  @files = glob( $localdir . '/' . $localfile ) ;

      foreach my $file ( @files ) {

         $filesize = -s $file ;
         print "Files : $file : $filesize bytes \n" ;
         $tot_filesize += $filesize ;

         my $linecount = 0 ;
         open(INPUTFILE, "< $file") || $logger->logdie("Cannot open file $file");
             $linecount++  while <INPUTFILE>;
         close (INPUTFILE) || $logger->logdie("Cannot close file $file");
         $totlinecount += $linecount;

      }

      $filesize_mb  = sprintf "%.2f", $tot_filesize / (1024 * 1024);

      print "Total filesize $localdir/$localfile  : $tot_filesize bytes\n" ;
      print "Total filesize $localdir/$localfile  : $filesize_mb MB \n" ;

      $logger->info("Total filesize $localdir/$localfile  : $tot_filesize bytes");
      $logger->info("Total filesize $localdir/$localfile  : $filesize_mb MB");

      return  $tot_filesize, $totlinecount ;

}

#---------------------#
sub EnableAudit       {
#---------------------#

      my ( $self, %args )  = @_;
      
      my $enable_audit = $self->get_audit() ;

      return $enable_audit ;

}



#-----------------#
sub CreateKeyFile {
#-----------------#

      my ( $self, %args )  = @_;

      my $logger           = $self->{logger} ;

      my $transferinfo     = $self->get_transferinfo() ;
      my $localdir         = $self->get_localdir() ;
      my $localfile        = $self->get_localfile() ;
      my $localnode        = $self->get_localnode() ;

      my $remotedir        = $self->get_remotedir() ;
      my $remotefile       = $self->get_remotefile() ;
      my $remotenode       = $self->get_remotenode();
      my $remotetrigger    = $self->get_remotetrigger();
      my $remotejob        = $self->get_remotejob();
      my $recordlength     = $self->get_recordlength();

      my $templatekeyfile  = $self->get_templatekeyfile();
      my $wmxkeyfile       = $self->get_wmxkeyfile() ;
      my $templatekeydir   = $self->{template_path} ;
      my $wmxkeydir        = $self->{wmx_path} ;


      print "transferinfo     = $transferinfo \n" ;
      print "localdir         = $localdir \n" ;
      print "localfile        = $localfile \n" ;
      print "localnode        = $localnode \n" ;

      print "remotedir        = $remotedir \n" ;
      print "remotefile       = $remotefile \n" ;
      print "remotenode       = $remotenode \n";
      print "remotetrigger    = $remotetrigger \n";
      print "remotejob        = $remotejob \n";
      print "recordlength     = $recordlength \n";

      print "templatekeydir   = $templatekeydir \n";
      print "templatekeyfile  = $templatekeyfile \n";
      print "wmxkeydir        = $wmxkeydir \n";
      print "wmxkeyfile       = $wmxkeyfile \n" ;

      print "------------------------------------------------------------------------\n" ;

      $logger->info("CDIRECT INFO : creating keyfile : $wmxkeydir/$wmxkeyfile ...");

      open (INPUTFILE, "< $templatekeydir/$templatekeyfile") || $logger->logdie ("Cannot open $templatekeydir/$templatekeyfile ! ");
      open (OUTPUTFILE, "> $wmxkeydir/$wmxkeyfile") || $logger->logdie (" Cannot open $wmxkeydir/$wmxkeyfile !");

      while (<INPUTFILE>) {
        $_ =~ s/__TRANSFERINFO__/$transferinfo/g;
        $_ =~ s/__CDNODE__/$localnode/g;
        $_ =~ s/__LOCALDIR__/$localdir/g;
        $_ =~ s/__LOCALFILE__/$localfile/g;
        $_ =~ s/__REMOTEFILE__/$remotefile/g;
        $_ =~ s/__REMOTEDIR__/$remotedir/g;
        $_ =~ s/__REMOTENODE__/$remotenode/g;
        $_ =~ s/__RLENGTH__/$recordlength/g;
        $_ =~ s/__TRIGGER__/$remotetrigger/g;
        $_ =~ s/__REMOTEJOB__/$remotejob/g;
        print OUTPUTFILE $_ ;
      }

      close (INPUTFILE) || die("can't close  $!");
      close (OUTPUTFILE) || die("can't close $!");
      
}

1;
