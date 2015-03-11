#!/bin/bash
source setup.sh
TABLE_SIZE=1000000
RAW_OUTPUT=tmp/raw.log

function mysql_local_test()
{
	num_threads=$1	

	echo "[MySQL] Make sure mysql and sysbench are installed and disabled"
	chmod +x mysql_install.sh
	sudo ./mysql_install.sh

	mysql -u root --password=kvm < /tmp/create_db_local.sql | tee -a $LOGFILE
	sudo service mysql restart
	sysbench --test=oltp --mysql-password=kvm --oltp-table-size=$TABLE_SIZE prepare | tee -a $LOGFILE

	# Exec
	mkdir -p tmp
	rm -f tmp/time.txt
	rm -f tmp/total_time.txt
	rm -f tmp/avg_time.txt
	touch tmp/time.txt
	touch tmp/total_time.txt
	touch tmp/avg_time.txt
	
	for i in `seq 1 $REPTS`; do
		sysbench --test=oltp --mysql-password=kvm --oltp-table-size=$TABLE_SIZE --num-threads=$num_threads run | tee  $RAW_OUTPUT 
		grep 'total time:' $RAW_OUTPUT | awk '{ print $3 }' | sed 's/s//' >> tmp/total_time.txt
		grep 'avg:' $RAW_OUTPUT | awk '{ print $2 }' | sed 's/ms//' >> tmp/avg_time.txt
	done;

	# Cleanup
	sysbench --test=oltp --mysql-password=kvm cleanup| tee -a $LOGFILE
	ssh root@$remote "mysql -u root --password=kvm < /tmp/drop_db.sql" | tee -a $LOGFILE

	# Get time stats
	echo "Requests per second" >> $LOGFILE
	tr '\n' '\t' < tmp/time.txt
	echo ""

	# Output in nice format as well
	echo -en "MySQL (${remote}) \t$num_threads threads\ttotal time\t" >> $OUTFILE
	cat tmp/total_time.txt | tr '\n' '\t' >> $OUTFILE
	echo >> $OUTFILE
	echo -en "MySQL (${remote}) \t$num_threads threads\tavg time\t" >> $OUTFILE
	cat tmp/avg_time.txt | tr '\n' '\t' >> $OUTFILE
	echo >> $OUTFILE

	#ssh root@$remote "service mysql stop" | tee -a $LOGFILE
	MYSQL_STARTED=""
}

until [ -z "$1" ]  # Until all parameters used up . . .
do
	mysql_local_test $1
	shift
done

