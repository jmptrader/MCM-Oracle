#!/usr/bin/sh

while getopts o: name
do
    case $name in
        o) output_file=$OPTARG ;;
    esac
done
shift `expr $OPTIND - 1`
command="$*"

dtrace='
 #pragma D option quiet

 dtrace:::BEGIN 
 {
	self->start = 0;
	self->vstart = 0;
 }

 syscall:::entry
 /pid == $target/
 {
	@Counts[probefunc] = count();
	@Counts["TOTAL"] = count();
	self->start = timestamp;
	self->vstart = vtimestamp;
 }

 syscall:::return
/self->start/
 {
	this->elapsed = timestamp - self->start;
	@Elapsed[probefunc] = sum(this->elapsed);
	@Elapsed["TOTAL"] = sum(this->elapsed);
	self->start = 0;
 }

 syscall:::return
/self->vstart/
 {
	this->cpu = vtimestamp - self->vstart;
	@CPU[probefunc] = sum(this->cpu);
	@CPU["TOTAL"] = sum(this->cpu);
	self->vstart = 0;
 }

 dtrace:::END 
 {
   printf("### ELAPSED ###\n");
	printa("%s:%@d\n",@Elapsed);
   printf("### CPU ###\n");
	printa("%s:%@d\n",@CPU);
   printf("### COUNTS ###\n");
	printa("%s:%@d\n",@Counts);
 }
'

/usr/sbin/dtrace -n "$dtrace" -x evaltime=exec -c "$command" -o $output_file

