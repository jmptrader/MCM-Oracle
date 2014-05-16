if exists (select * from sysobjects
           where  name = "sp__stat"
           and    type = "P")
   drop proc sp__stat

go
if exists (select * from sysobjects
           where  name = "sp__stat2"
           and    type = "P")
   drop proc sp__stat2

go
/* numbers here are in seconds for io, busy, idle */
create proc sp__stat2 (
                  @users       int output,
                  @runnable    int output,
                  @busy        int output,
                  @io          int output,
                  @idle        int output,
                  @pin         int output,
                  @pout        int output,
                  @tread       int output,
                  @twrite      int output,
                  @terr        int output,
                  @now         datetime output
)
AS
BEGIN

                  declare @ms_per_tick float
                  select @ms_per_tick = convert(int,@@timeticks/1000)

                  select @users=count(*) from master..sysprocesses where suser_name(suid)!='sa'

                  select @runnable=count(*) from master..sysprocesses where cmd!="AWAITING COMMAND" and suser_name(suid)!='sa'

                  select
                            @busy                 = ( @@cpu_busy * @ms_per_tick) / 1000,
                            @io                   = ( @@io_busy * @ms_per_tick) / 1000,
                            @idle                 = ( @@idle * @ms_per_tick) / 1000,
                            @pin                  = @@pack_received,
                            @pout                 = @@pack_sent,
                            @tread                = @@total_read,
                            @twrite               = @@total_write,
                            @terr                 = @@total_errors,
                            @now                  = getdate()

END
go

create proc sp__stat
AS
BEGIN
declare @users int, @runnable int, @busy int, @io int,
                        @idle int, @pin int, @pout int,
                        @tread int, @twrite int, @terr int, @now datetime

declare @last_users int, @last_runnable int, @last_busy int, @last_io int,
                        @last_idle int, @last_pin int, @last_pout int,
                        @last_tread int, @last_twrite int, @last_terr int, @last_now datetime

declare @secs int

/* Process Stats */
set nocount on

        /* Initialize */
        exec sp__stat2
                  @last_users           output,
                  @last_runnable        output,
                  @last_busy            output,
                  @last_io              output,
                  @last_idle            output,
                  @last_pin             output,
                  @last_pout            output,
                  @last_tread           output,
                  @last_twrite          output,
                  @last_terr            output,
                  @last_now             output

While 1 > 0
begin
        waitfor delay '00:00:05'

        exec sp__stat2
                  @users                output,
                  @runnable             output,
                  @busy                 output,
                  @io                   output,
                  @idle                 output,
                  @pin                  output,
                  @pout                 output,
                  @tread                output,
                  @twrite               output,
                  @terr                 output,
                  @now                  output

        select @secs = @busy - @last_busy + @io - @last_io + @idle - @last_idle
        if @secs = 0
                select @secs=1

        select
                  "Date"    = convert(char(10), @now, 111),
                  "Time"    = convert(char(8), @now, 108),
                  "Usrs"    = convert(char(4), @users),
                  "Run"     = convert(char(3), @runnable),
                  "%Cpu"    = convert(char(4), (100*(@busy-@last_busy))/@secs),
                  "%IO"     = convert(char(4), (100*(@io-@last_io))/@secs),
                  "Net in"  = convert(char(6), @pin-@last_pin),
                  "Net out" = convert(char(6), @pout-@last_pout),
                  "Reads"   = convert(char(6), @tread-@last_tread),
                  "Writes"  = convert(char(6), @twrite-@last_twrite),
                  "Errors"  = convert(char(4), @terr-@last_terr)

        select
                  @last_busy            = @busy,
                  @last_io              = @io,
                  @last_idle            = @idle,
                  @last_pin             = @pin,
                  @last_pout            = @pout,
                  @last_tread           = @tread,
                  @last_twrite          = @twrite,
                  @last_terr            = @terr,
                  @last_now             = @now

end

return(0)

END
go

