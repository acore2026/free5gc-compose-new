下载镜像包，使用 https://github.com/acore2026/free5gc-compose/tree/ran00101，ran00101分支，为根目录
需要安装 vm，docker

场景一：空白电脑，从零搭建
 1、cd 到代码根目录，cd 5GC,  执行 start-all.sh脚本，一键启动核心网和话音网元

场景二：需要清空当前的核心网所有用户和上下文，并重启
1、 执行./clean_ue_context.sh脚本，即可一键清除所有用户db数据和上下文（不包括签约数据）。

场景三：重启核心网和IMS
1、docker-compose down  && docker-compose up -d
2、./5GC/stop-ims.sh  && ./5GC/start-ims.sh

场景四：IMS网元或网络不通
1、cd 5GC 执行 init_env.sh,  stop-ims.sh, start-ims.sh