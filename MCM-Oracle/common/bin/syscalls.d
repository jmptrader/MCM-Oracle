#!/usr/sbin/dtrace -s


dtrace:::BEGIN 
{
    self->start  = 0;
    self->vstart = 0;
}

syscall:::entry
/pid == $target/
{
    @Counts[probefunc] = count();
    self->start  = timestamp;
    self->vstart = vtimestamp;
}

syscall:::return
/self->start/
{
    this->elapsed = timestamp  - self->start;
    this->cpu     = vtimestamp - self->vstart;
    @Elapsed[probefunc] = sum(this->elapsed);
    @CPU[probefunc] = sum(this->cpu);
    self->start  = 0;
    self->vstart = 0;
}

dtrace:::END 
{
    printf("### ELAPSED ###\n");
    printa("E:%s:%@d\n",@Elapsed);
    printf("### CPU ###\n");
    printa("C:%s:%@d\n",@CPU);
    printf("### COUNTS ###\n");
    printa("N:%s:%@d\n",@Counts);
}

dtrace:::ERROR
{
    printf("Hit an error");
}
