# @author FlashSoft
# == 自定义配置 ==============================================

# 配置nodered的接收地址
nodered_url="https://node.flashsoft.cn"

# 设定asr拦截词,以竖线分割每个拦截词
asr_keywords=""

# 设定res拦截词,以竖线分割每个拦截词
res_keywords=""

# 配置从nodered更新拦截词的间隔,单位秒
# 0代表不更新,一直使用本地拦截词
# 大于0则更新,会从上面设定的nodered_url去获取拦截词,并覆盖本地的拦截词
keywords_update_timeout=10

# NodeRed账号密码
nodered_auth=":"
# 小爱asr日志地址
asr_file="/tmp/mipns/mibrain/mibrain_asr.log"
# 小爱res日志地址
res_file="/tmp/mipns/mibrain/mibrain_response.log"
# == /自定义配置 ==============================================
 
# 解决可能存在第一次文件不存在问题
touch ${asr_file}
touch ${res_file} 
res_md5=""
last_time="0"

echo "==============================================================="
echo ""
echo "      NodeRed服务地址: ${nodered_url}"
echo "      NodeRed账号密码: `[ "${nodered_auth}" == ":" ] && echo "无密码" || echo "有密码"`     "
echo "            asr拦截词: `[ "${asr_keywords}" == "" ] && echo "无拦截词" || echo ${asr_keywords}`    "
echo "            res拦截词: `[ "${res_keywords}" == "" ] && echo "无拦截词" || echo ${res_keywords}`    "
echo "       拦截词更新频率: `[ "${keywords_update_timeout}" == "0" ] && echo "不更新" || echo ${keywords_update_timeout}`    "
echo ""
echo "==============================================================="


echo "开始验证NodeRed访问是否通畅"
echo ""
header=`curl --insecure –connect-timeout 2 -m 2 -sI -u "${nodered_auth}" ${nodered_url}`
if [ -z "`echo ${header}`" ];then
  echo "验证不通过: NodeRed网址不通"
  exit
else
  if [ -z "`echo "${header}" |grep 'HTTP/'|awk '($2==200){print 1}'`" ];then
    echo "验证不通过: NodeRed接口状态值非200 [可能密码不正确]"
    exit
  else
    echo "验证通过"
  fi
fi
 
while true;do
  # 计算md5值 
  new_md5=`md5sum ${res_file} | awk '{print $1}'`
  # 如果是第一次,就赋值比较用的md5
  [ -z ${res_md5} ] && res_md5=${new_md5}
  # 如果md5不等则文件变化
  if [[ ${new_md5} != ${res_md5} ]];then
    # 记录md5变化后结果
    res_md5=${new_md5}
    
    # 获取asr内容
    asr_content=`cat ${asr_file}`
    # 获取res内容
    res_content=`cat ${res_file}`

    
    miai_domain=`echo "${res_content}"|awk -F '"domain": ' '{print $2}'|awk -F '"' '{print $2}'`
    miai_errcode=`echo "${res_content}"|awk -F '\"extend\":' '{print $2}'|awk -F '\"code\": ' '{print $2}'|awk -F ',' '($1>200){print $1}'`

    echo "== 有内容更新 | domain: ${miai_domain} errcode: ${miai_errcode}"
    
    if ([[ ! -z ${asr_keywords} ]] && [[  ! -z `echo "${asr_content}"|awk 'match($0,/'${asr_keywords}'/){print 1}'` ]]) || ([[ ! -z ${res_keywords} ]] && [[  ! -z `echo "${res_content}"|awk 'match($0,/'${res_keywords}'/){print 1}'` ]]) || [ ${miai_errcode} ];then
      echo "== 试图停止"

      # @TODO: doamin是scenes的情况下,暂停播放,记录播放状态并暂停以及继续播放时有问题的
      # 为了保证不影响暂停效果,所以调整不同的停止播放方式
      if [ "${miai_domain}" != "scenes" ];then
        echo "== 其他模式 | ${miai_domain}"
        # 若干循环,直到resume成功一次直接跳出
        seq 1 200 | while read line;do
          code=`ubus call mediaplayer player_play_operation {\"action\":\"resume\"}|awk -F 'code":' '{print $2}'`
          if [[ "${code}" -eq "0" ]];then
            echo "== 停止成功"
            break
          fi
          usleep 50
        done
      else
        echo "== 场景模式 | ${miai_domain}"
        seq 1 10 | while read line;do
          ubus call mediaplayer player_play_operation {\"action\":\"stop\"} > /dev/null 2>&1
          usleep 50
        done
      fi
 
      # 记录播放状态并暂停,方便在HA服务器处理逻辑的时候不会插播音乐,0为未播放,1为播放中,2为暂停
      play_status=`ubus -t 1 call mediaplayer player_get_play_status | awk -F 'status' '{print $2}' | cut -c 5`
      if [ "${miai_domain}" != "scenes" ];then
        ubus call mediaplayer player_play_operation {\"action\":\"pause\"} > /dev/null 2>&1
      fi
 
      # @todo:
      # 转发asr和res给服务端接口,远端可以处理控制逻辑完成后返回需要播报的TTS文本
      # 2秒连接超时,4秒传输超时
      tts=`curl --insecure –connect-timeout 2 -m 2 -s -u "${nodered_auth}" --data-urlencode "asr=${asr_content}" --data-urlencode "res=${res_content}" "${nodered_url}/miai"`
      echo "== 请求完成"

      # 如果远端返回内容不为空则用TTS播报之
      if [[ -n "${tts}" ]];then
        echo "== 播报TTS | TTS内容: ${tts}"
        ubus call mibrain text_to_speech "{\"text\":\"${tts}\",\"save\":0}" > /dev/null 2>&1
        # 最长20秒TTS播报时间,20秒内如果播报完成跳出
        seq 1 20 | while read line;do
          media_type=`ubus -t 1 call mediaplayer player_get_play_status|awk -F 'media_type' '{print $2}'|cut -c 5`
          if [ "${media_type}" == "" ] || [ "${media_type}" -ne "1" ];then
            echo "== 播报TTS结束"
            break
          fi
          sleep 1
        done
      fi
 
      # 如果之前音乐是播放的则接着播放
      if [[ "${play_status}" -eq "1" ]];then
        echo "== 继续播放音乐"
        # 这里延迟一秒是因为前面处理如果太快,可能引起恢复播放不成功
        sleep 1
        if [ "${miai_domain}" != "scenes" ];then
          ubus call mediaplayer player_play_operation {\"action\":\"play\"} > /dev/null 2>&1
        fi
      fi
    fi

    log_res=`curl --insecure –connect-timeout 2 -m 2 -s -u "${nodered_auth}" --data-urlencode "asr=${asr_content}" --data-urlencode "res=${res_content}" "${nodered_url}/miai/set/log"`
    echo "== 投日志 | ${log_res}"
  fi
 
  # 以某频度去更新拦截词
  if [[ "${keywords_update_timeout}" -gt "0" ]];then
    now=`date +%s`
    step=`expr ${now} - ${last_time}`
    # 根据设定时间间隔获取更新词
    if [[ "$step" -gt "${keywords_update_timeout}" ]];then
        asr_keywords=`curl --insecure –connect-timeout 2 -m 2 -s -u "${nodered_auth}" "${nodered_url}/miai/get/asr"`
        res_keywords=`curl --insecure –connect-timeout 2 -m 2 -s -u "${nodered_auth}" "${nodered_url}/miai/get/res"`
        echo "== 更新关键词 | asr关键词内容: ${asr_keywords} | res关键词内容: ${res_keywords}"
        last_time=`date +%s`
    fi
  fi
  usleep 10
done