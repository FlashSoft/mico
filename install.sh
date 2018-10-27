# @author FlashSoft
root=`pwd`
root=""
# 脚本存放地址
mico_path="${root}/root/mico.sh"
# 脚本开机启动
mico_initpath="${root}/etc/init.d/mico_enable"
mico_tmppath="/tmp"
rm $mico_initpath > /dev/null 2>&1
echo "==============================================================="
echo ""
echo "     欢迎使用'小爱拦截器'安装工具 v0.8(2018.10.27)"
echo ""
echo "     本工具通过拦截小爱的识别词和响应词"
echo "     把拦截的请求转发给NodeRed服务进行自定义设备的操作"
echo "     论坛地址 https://bbs.hassbian.com/thread-5110-1-1.html"
echo ""
echo "==============================================================="
echo ""

# 环境检测,必须为小爱环境才继续
[ -z "`uname -a|grep mico`" ] && echo "当前不是小爱设备,请到小爱上执行此命令" && exit


echo "[!!!注意] 需要先有NodeRed服务并且提供了/miai这样的get接口(导入论坛提供的流就好)"
echo "请输入NodeRed服务地址,默认值[http://192.168.1.1:1880/miai]:"
read -p "" nodered_url
[ -z "${nodered_url}" ] && nodered_url="http://192.168.1.1:1880/miai"

echo "请输入你的NodeRed的账号和密码,如果没有密码请直接回车:"
echo "格式为 账号:密码"
read -p "" nodered_auth
[ -z "${nodered_auth}" ] && nodered_auth=':'

echo "[!!!注意] 从安装器v0.5版本开始,拦截未知设备无需填写拦截词,如果需要拦截特定情况的可以输入"
echo "请输入响应拦截词,多个拦截词使用|分割,默认值为[空]:"
read -p "" keywords
[ -z "${keywords}" ] && keywords=""

echo "请输入响应拦截词的更新频率,单位秒,0为不更新,默认值[0]:"
read -p "" keywords_update_timeout
[ -z "${keywords_update_timeout}" ] && keywords_update_timeout=0

echo "==============================================================="
echo ""
echo "      NodeRed服务地址: ${nodered_url}"
echo "      NodeRed账号密码: `[ "$nodered_auth" == ":" ] && echo "无密码" || echo "有密码"`"
echo "           响应拦截词: `[ "$keywords" == "" ] && echo "无" || echo "有"`"
echo "   响应拦截词更新频率: ${keywords_update_timeout}"
echo ""
echo "==============================================================="

echo "以上信息是否正确？任意键继续安装,ctrl+c取消安装:"
read -p "" enterkey

echo "开始验证nodered访问是否通畅"
echo ""
header=`curl --insecure –connect-timeout 2 -m 4 -sI -u "${nodered_auth}" ${nodered_url}|head -n 1`
echo "状态信息: ${header}"
echo ""
if [ -z "`echo ${header}`" ];then
  echo "验证不通过: NodeRed网址不通"
  exit
else
  if [[ "`echo $header|awk '{print $2}'`" -eq "401" ]];then
    echo "验证不通过: NodeRed密码不正确"
    exit
  else
    echo "验证通过"
  fi
fi

if [ -d "/tmp/mibrain" ];then
  echo "小爱固件版本: 旧版固件"
else
  if [ -d "/tmp/mipns/mibrain" ];then
    mico_tmppath="/tmp/mipns" 
    echo "小爱固件版本: 新版固件"
  else
    echo "小爱固件版本: 未知固件版本"
    exit
  fi
fi

# 下载远程脚本并检查是否成功
now=`date +%s`
mico=`curl --insecure -s –connect-timeout 4 -m 4 "https://raw.githubusercontent.com/FlashSoft/mico/master/mico.sh?${now}"`
# mico=`cat ./mico.sh`
if [[ -z `echo "${mico}"|awk 'match($0,/FlashSoft/){print 1}'` ]];then
  echo "脚本下载不成功,可能你需要个酸酸乳"
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
chmod a+x $mico_initpath > /dev/null 2>&1
$mico_initpath enable > /dev/null 2>&1
$mico_initpath stop > /dev/null 2>&1

echo "安装完毕"
echo "可以使用/etc/init.d/mico_enable start 启动小爱拦截器"