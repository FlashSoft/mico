# @author FlashSoft
# @update 2018.10.26
root=`pwd`
root=""
# 脚本存放地址
mico_path="${root}/root/mico.sh"
# 脚本开机启动
mico_initpath="${root}/etc/init.d/mico_enable"
mico_rcpath="${root}/etc/rc.d/S96mico_enable"
mico_tmppath="/tmp"
rm $mico_initpath
rm $mico_rcpath
echo ""
echo "欢迎使用'小爱拦截器'安装工具 v0.2(2018.10.26)"
echo ""
echo "本工具通过拦截小爱的识别词和响应词"
echo "把拦截的请求转发给NodeRed服务进行自定义设备的操作"
echo ""


# 环境检测,必须为小爱环境才继续
[ -z "`uname -a|grep mico`" ] && echo "当前不是小爱设备,请到小爱上执行此命令" && exit

echo "请输入响应拦截词,多个拦截词使用|分割,默认值为[未知|没有]:"
read -p "" keywords
[ -z "${keywords}" ] && keywords="未知|没有"

echo "请输入响应拦截词的更新频率,单位秒,0为不更新,默认值[0]:"
read -p "" keywords_update_timeout
[ -z "${keywords_update_timeout}" ] && keywords_update_timeout=0

echo "请输入NodeRed服务地址,默认值[http://192.168.1.1:1880/miai]:"
read -p "" nodered_url
[ -z "${nodered_url}" ] && nodered_url="http://192.168.1.1:1880/miai"

echo "请输入你的NodeRed的账号和密码,如果没有密码请直接回车:"
echo "格式为 账号:密码"
read -p "" nodered_auth
[ -z "${nodered_auth}" ] && nodered_auth=':'

echo "==============================================================="
echo ""
echo "           响应拦截词: ${keywords}"
echo "   响应拦截词更新频率: ${keywords_update_timeout}"
echo "      NodeRed服务地址: ${nodered_url}"
echo "      NodeRed账号密码: `[ "$nodered_auth" == ":" ] && echo "无密码" || echo "有密码"`"
echo ""
echo "==============================================================="

echo "以上信息是否正确？任意键继续安装,ctrl+c取消安装:"
read -p "" enterkey

echo "开始验证nodered访问是否通畅"
echo ""
header=`curl –connect-timeout 2 -m 4 -sI -u ${nodered_auth} ${nodered_url}`
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

echo "验证小爱固件版本"

if [ -d "/tmp/mibrain" ];then
  echo "旧版固件"
else
  if [ -d "/tmp/mipns/mibrain" ];then
    mico_tmppath="/tmp/mipns"
    echo "新版固件"
  else
    echo "未知固件版本"
    exit
  fi
fi


# 下载远程脚本并检查是否成功
mico=`curl -s 'https://raw.githubusercontent.com/FlashSoft/mico/master/mico.sh'`
# mico=`cat ./mico.sh`
if [[ -z `echo "${mico}"|awk 'match($0,/VERSION/){print 1}'` ]];then
  echo "脚本下载不成功,可能你需要买个番茄先"
  exit
fi

# 替换变量并存储
echo "${mico}" |
awk '{gsub("^keywords=.*", "keywords=\"'${keywords}'\""); print $0}' |
awk '{gsub("^keywords_update_timeout=.*", "keywords_update_timeout='${keywords_update_timeout}'"); print $0}' |
awk '{gsub("^nodered_url=.*", "nodered_url=\"'${nodered_url}'\""); print $0}' |
awk '{gsub("^asr_file=.*", "asr_file=\"'${mico_tmppath}'/mibrain/mibrain_asr.log\""); print $0}' |
awk '{gsub("^res_file=.*", "res_file=\"'${mico_tmppath}'/mibrain/mibrain_response.log\""); print $0}' |
awk '{gsub("^nodered_auth=.*", "nodered_auth=\"'${nodered_auth}'\""); print $0}' > $mico_path
chmod a+x $mico_path


exit

# 部署脚本
echo "部署启动脚本"
echo "#!/bin/sh /etc/rc.common
START=96
start() {
  sh '${mico_path}' &
}

stop() {
  kill \`ps|grep 'sh ${mico_path}'|grep -v grep|awk '{print \$1}'\`
}" > $mico_initpath
chmod a+x $mico_initpath
$mico_initpath enable

echo "安装完毕"
echo "可以使用/etc/init.d/mico_enable start 启动小爱拦截器"
echo "可以使用/etc/init.d/mico_enable stop 停止小爱拦截器"

