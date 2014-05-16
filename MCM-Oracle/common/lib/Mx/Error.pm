package Mx::Error;

our $MX_ANSWERFILE_FAILURE   = 11;
our $MISSING_REPORT          = 12;
our $NFS_STALE_FILEHANDLE    = 13;
our $NOT_RUNNING_EXCLUSIVELY = 14;
our $MX_SERVICE_FAILURE      = 15;
our $MX_MACRO_FAILURE        = 16;
our $CORE_DUMPED             = 17;
our $MX_LOGFILE_FAILURE      = 18;
our $COMMAND_TIMEOUT         = 19;
our $DYNTABLE_OVERFLOW       = 20;
our $REFDATA_LOCKED          = 21;
our $SYBASE_CONNECT_TIMEOUT  = 22;
our $BATCH_DELAY_EXCEEDED    = 23;

my %DESCRIPTIONS = (
  $MX_ANSWERFILE_FAILURE   => 'MX answerfile failure',
  $MISSING_REPORT          => 'missing report',
  $NFS_STALE_FILEHANDLE    => 'NFS stale filehandle',
  $NOT_RUNNING_EXCLUSIVELY => 'not running exclusively',
  $MX_SERVICE_FAILURE      => 'MX service failure',
  $MX_MACRO_FAILURE        => 'MX macro failure',
  $CORE_DUMPED             => 'coredump',
  $MX_LOGFILE_FAILURE      => 'MX logfile failure',
  $COMMAND_TIMEOUT         => 'command timeout',
  $DYNTABLE_OVERFLOW       => 'dynamic table overflow',
  $REFDATA_LOCKED          => 'ref data locked',
  $SYBASE_CONNECT_TIMEOUT  => 'Sybase connect timeout',
  $BATCH_DELAY_EXCEEDED    => 'batch delay exceeded'
);

#---------------#
sub description {
#---------------#
    my ( $class, $errorcode ) = @_;

    
    return $DESCRIPTIONS{ $errorcode } || $errorcode;
}

1;
