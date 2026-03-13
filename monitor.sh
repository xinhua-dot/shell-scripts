#!/bin/bash

# 配置区域 ============================================
# 阈值设置（可根据实际情况修改）
CPU_LOAD_WARN=2.0
CPU_USAGE_WARN=80
MEM_USAGE_WARN=90
DISK_USAGE_WARN=85
PROCESS_LIST="nginx mysql php-fpm sshd"

# 告警配置
ENABLE_ALERT=true
ALERT_EMAIL="2101162533@qq.com"
#WEBHOOK_URL=""https://oapi.dingtalk.com/robot/send?access_token=xxx"  # 钉钉机器人

# 日志配置
LOG_FILE="/var/log/server_monitor.log"
DATA_DIR="/var/log/monitor_data"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
DATE_YED=$(date "+%Y%m%d")

mkdir -p $DATA_DIR

JSON_OUTPUT="{"
JSON_OUTPUT+="\"timestamp\":\"$TIMESTAMP\","

# 1. 系统基本信息采集 ==================================
get_system_iofo(){
 HOSTNAME=$(hostname)
 IP_ADRR=$(ip adrr | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk {print $2} | cut -d'/' f1 | head 1
#系统版本
 OS_VERSION=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2
#内核版本
 KERNEL=$(uname -r)
#系统运行时间
 UPTIME=$(uptime | awk -F'up' {print $2} | awk -F',' {print $1} | sed '/^[ \t]*//')
#系统负载
 LOAD_AVG=$(uptime | awk -F'load average:' {print $2} | sed 's/^[ \t]*//')
 
 JSON_OUTPUT+="\"hostname\":\"$HOSTNAME\","
 JSON_OUTPUT+="\"ip\":\"$IP_ADRR\","
 JSON_OUTPUT+="\"kernel\":\"$KERNEL\","
 JSON_OUTPUT+="\"uptime\":\"$uptime\","
 JSON_OUTPUT+="\"load_avg\":\"$LOAD_AVG\","
}

# 2. CPU监控 ==========================================
get_cup_info(){
 # 获取CPU核心数
 CPU_CORES=$(grep -c processor /proc/cpuinfo)
 # 获取CPU使用率（取1分钟内的平均值）
 CPU_USAGE=$(top -bn1 | grep "CPu(s)" | awk {print $2} | cut -d'%' f1)
 # 如果第一部分没有获取到值,尝试匹配新版 top 的 "%Cpu" 格式
 if [ -z "$CPU_USAGE" ];then
	CPU_USAGE=$(top -bn1 | grep "%Cpu" | awk '{print $2}')
 fi

 # 获取1分钟平均负载
 LOAD_1MIN=$(uptime | awk -F'load_average:' {print $2} | awk -F',' {print $1})

 JSON_OUTPUT+="\"cpu_cores\":$CPU_CORES,"
 JSON_OUTPUT+="\"cpu_usage\":$CPU_USAGE,"
 JSON_OUTPUT+="\"load_1min\":$LOAD_1MIN," 

 # CPU告警检查
 if [ $"ENABLE_ALERT" = true ];then
 	if [$(echo "$LOAD_1MIN > $CPU_LOAD_WARN" | bc) -eq 1 ];then
		ALERT_MSG+="CPU负载过高: $LOAD_1MIN (阈值:$CPU_LOAD_WARN)\n"
	fi
	if [$(echo "$CPU_USAGE > $CPU_USAGE_WARN" | bc) -eq 1 ];then
 		ALERT_MSG+="CPU使用率过高: $CPU_USAGE(阈值:$CPU_USAGE_WARN)\n"
	fi
 fi
}

# 3. 内存监控 ==========================================
get_mem_info(){
 #free命令获取内存信息
 MEM_TOTAL=$(free -m | grep ^MEM: | awk '{print $2}')
 MEM_USED=$(free -m | grep ^MEM: | awk '{print $3}')
 MEM_FREE=$(free -m | grep ^MEM: | awk '{print $4}')
 MEM_AVAILABLE=$(free -m | grep ^MEM: | awk '{print $7}')

 MEM_USAGE_RATE=$(echo "scale=2; $MEM_USED * 100 / $MEM_TOTAL" | bc)

# Swap信息
 SWAP_TOTAL=$(free -m | grep ^Swap: | awk '{print $2}')
 SWAP_USED=$(free -m | grep ^Swap: | awk '{print $3}')

 if [ $SWAP_TOTAL -gt 0 ];then
	SWAP_USAGE_RATE=$(echo "scale=2; $SWAP_USED *100 / $SWAP_TOTAL" | bc)
 else
	SWAP_USAGE_RATE=0
 fi
 
    JSON_OUTPUT+="\"mem_total\":$MEM_TOTAL,"
    JSON_OUTPUT+="\"mem_used\":$MEM_USED,"
    JSON_OUTPUT+="\"mem_free\":$MEM_FREE,"
    JSON_OUTPUT+="\"mem_available\":$MEM_AVAILABLE,"
    JSON_OUTPUT+="\"mem_usage_rate\":$MEM_USAGE_RATE,"
    JSON_OUTPUT+="\"swap_total\":$SWAP_TOTAL,"
    JSON_OUTPUT+="\"swap_used\":$SWAP_USED,"
    JSON_OUTPUT+="\"swap_usage_rate\":$SWAP_USAGE_RATE,"

# 内存告警检查
    if [ "$ENABLE_ALERT" = true ]; then
        if [ $(echo "$MEM_USAGE_RATE > $MEM_USAGE_WARN" | bc) -eq 1 ]; then
            ALERT_MSG+="内存使用率过高: ${MEM_USAGE_RATE}% (阈值:${MEM_USAGE_WARN}%)\n"
        fi
    fi
}

# 4. 磁盘监控 ==========================================
get_disk_info(){
 JSON_OUTPUT+="\"disks\":["

 DISK_FIRST=true
 df -h | grep -E '^/dev/' | while read line; do
	FILESYSTEM=$(echo $line | awk '{print $1}')
        SIZE=$(echo $line | awk '{print $2}') 
	USED=$(echo $line | awk '{print $3}') 
 	AVAIL=$(echo $line | awk '{print $4}')
	USE_PERCENT=$(echo $line | awk '{print $5}')
	MOUNT=$(echo $line | awk '{print $6}')
	
	if [ "$DISK_FIRST" =true ];then
		echo -n ""{\"filesystem\":\"$FILESYSTEM\",\"size\":\"$SIZE\",\"used\":\"$USED\",\"avail\":\"$AVAIL\",\"use_percent\":$USE_PERCENT,\"mount\":\"$MOUNT\"}"
	DISK_FIRST=false

	else
		",{\"filesystem\":\"$FILESYSTEM\",\"size\":\"$SIZE\",\"used\":\"$USED\",\"avail\":\"$AVAIL\",\"use_percent\":$USE_PERCENT,\"mount\":\"$MOUNT\"}"
	fi
	
	if [ "$ENABLE_ALERT" = true ] && [ $USED_PERCENT -gt $DISK_USED_WARN ];then
		ALERT_MSG+="磁盘${MOUNT}使用率过高: ${USE_PERCENT}% (阈值:${DISK_USAGE_WARN}%)\n"
	fi
 done
 
 JSON_OUTPUT+="],"
}

# 5. 进程监控 ==========================================
check_processes() {
    JSON_OUTPUT+="\"processes\":{"
    
    # PROCESS_LIST="nginx mysql php-fpm sshd"  # 需要监控的进程列表

    PROCESS_FIRST=true
    for PROC in $PROCESS_LIST; do
        # 检查进程是否在运行
            
              # 统计指定进程数量
              # ps -ef - 显示所有进程

              # UID        PID  PPID  C STIME TTY          TIME CMD
              # root         1     0  0 14:30 ?        00:00:01 /sbin/init
              # root       123     1  0 14:31 ?        00:00:00 nginx: master process /usr/sbin/nginx
              # www-data   124   123  0 14:31 ?        00:00:00 nginx: worker process
              # mysql      456     1  0 14:32 ?        00:00:01 /usr/sbin/mysqld
              # root       789     1  0 14:33 ?        00:00:00 sshd: /usr/sbin/sshd -D      

              # grep -w $PROC - 精确匹配进程名
              # grep -v grep - 排除 grep 命令自身
              #  wc -l - 统计行数（进程数量）

        PROC_COUNT=$(ps -ef | grep -w $PROC | grep -v grep | wc -l)
        if [ $PROC_COUNT -gt 0 ]; then
            STATUS="running"
        else
            STATUS="stopped"
            # 进程停止告警
            if [ "$ENABLE_ALERT" = true ]; then
                ALERT_MSG+="关键进程${PROC}未运行\n"
            fi
        fi
        
        if [ "$PROCESS_FIRST" = true ]; then
            echo -n "\"$PROC\":\"$STATUS\""
            PROCESS_FIRST=false
        else
            echo -n ",\"$PROC\":\"$STATUS\""
        fi
    done
    
    JSON_OUTPUT+="},"
}

# 6. 网络监控 ==========================================
get_network_info() {
    # 网络连接数统计
    # netstat -ant - 显示所有网络连接 
    # Active Internet connections (servers and established)
    # Proto Recv-Q Send-Q Local Address           Foreign Address         State      
    # tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN  

    # -a：显示所有连接（包括监听和已建立）
    # -n：以数字形式显示地址和端口（不进行 DNS 解析）
    # -t：只显示 TCP 连接

    # grep ESTABLISHED - 筛选已建立的连接
    # wc -l - 统计行数

    CONN_ESTAB=$(netstat -ant | grep ESTABLISHED | wc -l)		# 已建立的连接
    CONN_TIME_WAIT=$(netstat -ant | grep TIME_WAIT | wc -l)		# 等待关闭的连接
    CONN_CLOSE_WAIT=$(netstat -ant | grep CLOSE_WAIT | wc -l)	# 等待关闭（被动）
    CONN_LISTEN=$(netstat -ant | grep LISTEN | wc -l)			# 监听端口
    CONN_SYN_RECV=$(netstat -ant | grep SYN_RECV | wc -l)		# 半连接（可能攻击）
    
    JSON_OUTPUT+="\"network\":{"
    JSON_OUTPUT+="\"established\":$CONN_ESTAB,"
    JSON_OUTPUT+="\"time_wait\":$CONN_TIME_WAIT,"
    JSON_OUTPUT+="\"close_wait\":$CONN_CLOSE_WAIT,"
    JSON_OUTPUT+="\"listen\":$CONN_LISTEN,"
    JSON_OUTPUT+="\"syn_recv\":$CONN_SYN_RECV"
    JSON_OUTPUT+="},"
}

# 7. 日志记录函数 ======================================

# 用于将格式化的日志消息写入指定的日志文件
# level：日志级别（如 INFO、WARNING、ERROR 等）
# message：要记录的日志内容
# LOG_FILE：全局变量，指定日志文件路径

# 使用函数
# write_log "ERROR" "数据库连接失败"
   #  函数内部自动将参数赋值给 $1, $2
   #  local level=$1    # level="ERROR"  (获取第一个参数)
   #  local message=$2   # message="数据库连接失败" (获取第二个参数)

write_log() {

    # =$1：将函数的第一个参数赋值给变量 level
    local level=$1

    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> $LOG_FILE
}

# 8. 告警发送函数 ======================================
send_alert() {
    local alert_msg=$1
    if [ -z "$alert_msg" ]; then    # -z 检查变量是否为空
        return
    fi
    
    # 写入日志
    write_log "ALERT" "$alert_msg"
    
    # 邮件告警
    echo "$alert_msg" | mail -s "[告警] 服务器 $HOSTNAME 异常" $ALERT_EMAIL
    
    # 钉钉告警（如果有配置）
    if [ -n "$WEBHOOK_URL" ]; then      #检查变量是否非空
        curl -s -X POST $WEBHOOK_URL \  #-s: 静默模式        -X POST:指定 HTTP 方法为 POST
            -H "Content-Type: application/json" \       -H	添加 HTTP 头
      
            # -d	发送的数据（body）
	     # > /dev/null 的作用是丢弃命令的输出，不让它显示在屏幕上，也不让它在脚本中造成干扰。
                     # 不加污染脚本输出；如果脚本输出被重定向到日志文件，这些不需要的信息也会进去；用户可能不想看到这些技术细节；：如果脚本的输出去给其他程序处理，这些额外输出会造成问题
            
            -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"服务器告警: $alert_msg\"}}" > /dev/null   # > /dev/null 丢弃输出              
    fi
}

# 9. 数据保存函数 ======================================
save_data() {
    # 保存为JSON格式，便于后续分析
    echo $JSON_OUTPUT > "${DATA_DIR}/monitor_${DATE_YMD}.json"
    
    # 追加到历史CSV文件
    echo "${TIMESTAMP},${LOAD_1MIN},${CPU_USAGE},${MEM_USAGE_RATE},${DISK_USAGE}" >> "${DATA_DIR}/history.csv"
}

# 10. 主函数 ===========================================
main() {
    write_log "INFO" "开始执行监控脚本"
    
    # 初始化告警消息
    ALERT_MSG=""
    
    # 执行各项监控
    get_system_info
    get_cpu_info
    get_mem_info
    get_disk_info
    check_processes
    get_network_info
    
    # 去掉最后一个逗号并闭合JSON
    JSON_OUTPUT=$(echo $JSON_OUTPUT | sed 's/,$//')   #sed 's/,$//'  --- $：行尾锚定，表示行的末尾
    JSON_OUTPUT+="}"
    
    # 输出到控制台（便于调试）
    # jq .：使用 jq 工具格式化 JSON 输出（. 表示原样输出但格式化） 
    # 2>/dev/null：将标准错误（文件描述符 2）重定向到空设备，即丢弃所有错误信息

    echo $JSON_OUTPUT | jq . 2>/dev/null || echo $JSON_OUTPUT    

    
    # 保存数据
    save_data
    
    # 发送告警
    if [ -n "$ALERT_MSG" ]; then   #变量ALERT_MSG为非空
        send_alert "$ALERT_MSG"
    fi
    
    write_log "INFO" "监控脚本执行完成"
}

# 执行主函数
main




























