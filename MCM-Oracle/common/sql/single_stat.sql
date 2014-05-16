if exists (select * from sysobjects
           where  name = "sp__single_stat"
           and    type = "P")
   drop proc sp__single_stat

go

create proc sp__single_stat (
                  @hostname    char(10),
                  @hostprocess char(8)
)
AS
BEGIN
declare @now datetime

set nocount on

While 1 > 0
begin

    select @now = getdate()

    select 
        "Date"    = convert(char(10), @now, 111),
        "Time"    = convert(char(8), @now, 108),
        SPID      = spid,
        CPU       = cpu,
        IO        = physical_io,
        MEM       = memusage
    from master..sysprocesses
    where hostname = @hostname
    and hostprocess = @hostprocess

    waitfor delay '00:00:05'

end

return(0)

END
go

