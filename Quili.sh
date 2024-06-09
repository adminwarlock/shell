#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 节点安装功能
function install_node() {

# sudo rm -rf /usr/local/go

# curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local

# echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bashrc

# source ~/.bashrc

# go version

# 增加swap空间
sudo mkdir /swap
sudo fallocate -l 16G /swap/swapfile
sudo chmod 600 /swap/swapfile
sudo mkswap /swap/swapfile
sudo swapon /swap/swapfile
echo '/swap/swapfile swap swap defaults 0 0' >> /etc/fstab

# 向/etc/sysctl.conf文件追加内容
echo -e "\n# 自定义最大接收和发送缓冲区大小" >> /etc/sysctl.conf
echo "net.core.rmem_max=600000000" >> /etc/sysctl.conf
echo "net.core.wmem_max=600000000" >> /etc/sysctl.conf

echo "配置已添加到/etc/sysctl.conf"

# 重新加载sysctl配置以应用更改
sysctl -p

echo "sysctl配置已重新加载"

# 更新并升级Ubuntu软件包
sudo apt update && sudo apt -y upgrade 

# 克隆仓库
git clone https://github.com/quilibriumnetwork/ceremonyclient

# 进入 ceremonyclient/node 目录
cd #HOME
cd ceremonyclient/node
git switch release-cdn

# 写入服务
sudo tee /lib/systemd/system/ceremonyclient.service > /dev/null << EOF
[Unit]
Description=Ceremony Client GO App Service

[Service]
Type=simple
Restart=always
RestartSec=5S
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/ceremonyclient/node/node-1.4.19-linux-amd64

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable ceremonyclient
sudo systemctl start ceremonyclient

echo ====================================== 安装完成 =========================================

}

# 服务版本节点日志查询
function view_logs() {
    sudo journalctl -f -u ceremonyclient.service
}

# 查看服务版本状态
function check_ceremonyclient_service_status() {
    systemctl status ceremonyclient
}

function backup_set() {
    mkdir -p ~/backup
    cat ~/ceremonyclient/node/.config/config.yml > ~/backup/config.txt
    cat ~/ceremonyclient/node/.config/keys.yml > ~/backup/keys.txt

    echo "=======================备份完成，请执行cd ~/backup 查看备份文件========================================="
}

function upload () {
    service ceremonyclient stop
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    cd ~/ceremonyclient
    git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git
    git pull
    git checkout release-cdn
    cd ~/ceremonyclient/node
    sed -i 's/ExecStart=\/root\/ceremonyclient\/node\/node-1.4.18-linux-amd64/ExecStart=\/root\/ceremonyclient\/node\/node-1.4.19-linux-amd64/g' /lib/systemd/system/ceremonyclient.service
    systemctl daemon-reload
    cd ~/ceremonyclient/client
    rm ~/go/bin/qclient
    GOEXPERIMENT=arenas go build -o ~/go/bin/qclient main.go
    cd ~
    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    service ceremonyclient start
    echo ====================================== 更新完成 =========================================
}

# 主菜单
function main_menu() {
    clear
    echo "================================================================"
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 查看节点日志"
    echo "3. 查看服务状态"
    echo "=======================单独使用功能============================="
    echo "4. 备份文件"
    echo "5. 升级"
    echo "=========================备份功能================================"
    read -p "请输入选项（1-4）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) view_logs ;;  
    3) check_ceremonyclient_service_status ;; 
    4) backup_set ;;  
    5) upload ;; 
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu