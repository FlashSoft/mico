# 脚本存放地址
root=`pwd`
root=""
mico_path="${root}/root/mico.sh"
# 脚本开机启动
mico_initpath="${root}/etc/init.d/mico_enable"
mico_rcpath="${root}/etc/rc.d/S96mico_enable"
rm $mico_initpath
rm $mico_rcpath
echo ""
echo "欢迎使用'小爱拦截器'安装工具 v0.1"
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

echo "==============================================================="
echo ""
echo "           响应拦截词: ${keywords}"
echo "   响应拦截词更新频率: ${keywords_update_timeout}"
echo "      NodeRed服务地址: ${nodered_url}"
echo ""
echo "==============================================================="

echo "以上信息是否正确？任意键继续安装,ctrl+c取消安装:"
read -p "" enterkey

# 下载远程脚本并检查是否成功
mico=`curl -s 'https://raw.githubusercontent.com/FlashSoft/mico/master/mico.sh'`
if [[ -z `echo "${mico}"|awk 'match($0,/VERSION/){print 1}'` ]];then
  echo "脚本下载不成功,可能你需要买个番茄先"
  exit
fi

# 替换变量并存储
echo "${mico}" |
awk '{gsub("^keywords=.*", "keywords=\"'${keywords}'\""); print $0}' |
awk '{gsub("^keywords_update_timeout=.*", "keywords_update_timeout='${keywords_update_timeout}'"); print $0}' |
awk '{gsub("^nodered_url=.*", "nodered_url=\"'${nodered_url}'\""); print $0}' > $mico_path
chmod a+x $mico_path

# 检查自启动脚本是否存在
if [ ! -f "${mico_initpath}" ];then
  echo "#!/bin/sh /etc/rc.common
START=96
start() {
  sh '${mico_path}' &
}

stop() {
  kill \`ps|grep 'sh ${mico_path}'|grep -v grep|awk '{print \$1}'\`
}" > $mico_initpath
  chmod a+x $mico_initpath
  # 建立软连接
  ln -sf $mico_initpath $mico_rcpath
else
  echo "启动脚本已存在,忽略"
fi

echo "安装完毕"
echo "可以使用/etc/init.d/mico_enable start 启动小爱拦截器"
echo "可以使用/etc/init.d/mico_enable stop 停止小爱拦截器"

