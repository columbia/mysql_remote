
source setup.sh
TABLE_SIZE=1000000
RAW_OUTPUT=tmp/raw.log

function mysql_remote_test()
{
	num_threads=$1	
	remote=$HOST	# dns/ip for machine to test
        clientIP=$(ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}')

	echo "Client IP is $clientIP"
	echo "[Server] Make sure mysql and sysbench are installed and disabled"
	ssh root@$remote "cat > /tmp/i.sh && chmod a+x /tmp/i.sh && /tmp/i.sh" < mysql_install.sh | \
		tee -a $LOGFILE
	
	echo "[Server] Allow remote access to mysql"
	ssh root@$remote sed -i 's/^bind/#bind/g' /etc/mysql/my.cnf

	echo "[Server] Prep"
	sed "s/remote/$clientIP/g" create_db_remote.sql > create_db_remote_tmp.sql
	$SCP *.sql root@$remote:/tmp/.
	ssh root@$remote "service mysql start" | tee -a $LOGFILE
	ssh root@$remote "mysql -u root --password=kvm < /tmp/create_db_remote_tmp.sql" | tee -a $LOGFILE

	echo "[Client] Make sure mysql and sysbench are installed and disabled"
	chmod +x mysql_install.sh
	sudo ./mysql_install.sh
	echo "[Client] Prep"
	sudo service mysql start
	sysbench --test=oltp --mysql-password=kvm --oltp-table-size=$TABLE_SIZE --mysql-host=$remote prepare | tee -a $LOGFILE

	MYSQL_STARTED="$remote"
	POWEROUT=/tmp

	# Exec
	rm -f tmp/time.txt
	touch tmp/time.txt
	touch tmp/total_time.txt
	touch tmp/avg_time.txt
	
	for i in `seq 1 $REPTS`; do
		sysbench --test=oltp --mysql-password=kvm --oltp-table-size=$TABLE_SIZE --mysql-host=$remote --num-threads=$num_threads run | tee  $RAW_OUTPUT 
		grep 'total time:' $RAW_OUTPUT | awk '{ print $3 }' | sed 's/s//' >> tmp/total_time.txt
		grep 'avg:' $RAW_OUTPUT | awk '{ print $2 }' | sed 's/ms//' >> tmp/avg_time.txt
	done;

	# Cleanup
	sysbench --test=oltp --mysql-password=kvm --mysql-host=$remote cleanup| tee -a $LOGFILE
	ssh root@$remote "mysql -u root --password=kvm < /tmp/drop_db.sql" | tee -a $LOGFILE

	# Get time stats
	echo "Requests per second" >> $LOGFILE
	tr '\n' '\t' < tmp/time.txt
	echo ""

	# Output in nice format as well
	echo -en "MySQL (${remote}) $num_threads threads total time\t" >> $OUTFILE
	cat tmp/total_time.txt | tr '\n' '\t' >> $OUTFILE
	echo >> $OUTFILE
	echo -en "MySQL (${remote}) $num_threads threads avg time\t" >> $OUTFILE
	cat tmp/avg_time.txt | tr '\n' '\t' >> $OUTFILE
	echo >> $OUTFILE

	#ssh root@$remote "service mysql stop" | tee -a $LOGFILE
	MYSQL_STARTED=""
}

until [ -z "$1" ]  # Until all parameters used up . . .
do
	mysql_remote_test $1
	shift
done
