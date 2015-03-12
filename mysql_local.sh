#!/bin/bash
source setup.sh
TABLE_SIZE=1000000
RAW_OUTPUT=tmp/raw.log

TOTAL=tmp/total_time.txt
AVG=tmp/avg_time.txt

function init()
{
	echo "[MySQL] Make sure mysql and sysbench are installed and disabled"
	chmod +x mysql_install.sh
	sudo ./mysql_install.sh

	sudo service mysql restart
	mysql -u root --password=kvm < create_db_local.sql | tee -a $LOGFILE
	sysbench --test=oltp --mysql-password=kvm --oltp-table-size=$TABLE_SIZE prepare | tee -a $LOGFILE

	mkdir -p tmp

}
function finish()
{
	# Cleanup
	sysbench --test=oltp --mysql-password=kvm cleanup| tee -a $LOGFILE
	mysql -u root --password=kvm < drop_db.sql | tee -a $LOGFILE

#	echo $OUT_FILE
#	cat $OUT_FILE
}

function mysql_local_test()
{
	rm -f TOTAL
	rm -f AVG
	touch TOTAL
	touch AVG

	num_threads=$1	
		
	for i in `seq 1 $REPTS`; do
		sysbench --test=oltp --mysql-password=kvm --oltp-table-size=$TABLE_SIZE --num-threads=$num_threads run | tee  $RAW_OUTPUT 
		grep 'total time:' $RAW_OUTPUT | awk '{ print $3 }' | sed 's/s//' >> TOTAL
		grep 'avg:' $RAW_OUTPUT | awk '{ print $2 }' | sed 's/ms//' >> AVG
	done;

	# Output in nice format as well
	echo -en "MySQL (localhost) \t$num_threads threads\ttotal time\t" >> $OUTFILE
	cat TOTAL | tr '\n' '\t' >> $OUTFILE
	echo >> $OUTFILE
	echo -en "MySQL (localhost) \t$num_threads threads\tavg time\t" >> $OUTFILE
	cat AVG | tr '\n' '\t' >> $OUTFILE
	echo >> $OUTFILE
}


init
until [ -z "$1" ]  # Until all parameters used up . . .
do
	mysql_local_test $1
	shift
done
finish
