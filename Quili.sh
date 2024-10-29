#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 节点安装功能
function install_node() {

sudo ufw allow 22
sudo ufw allow 8336
sudo ufw allow 443
sudo ufw status

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
    cd ~
    cp -r ~/ceremonyclient/node/.config ~/backup

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

    sed -i 's/listenMultiaddr: \/ip4\/0.0.0.0\/udp\/8336\/quic/listenMultiaddr: \/ip4\/0.0.0.0\/tcp\/8336/g' ~/ceremonyclient/node/.config/config.yml
    sed -i 's/listenGrpcMultiaddr: ""/listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/g' ~/ceremonyclient/node/.config/config.yml
    sed -i 's/listenRESTMultiaddr: ""/listenRESTMultiaddr: \/ip4\/127.0.0.1\/tcp\/8338/g' ~/ceremonyclient/node/.config/config.yml

    cd ~/ceremonyclient/client
    rm ~/go/bin/qclient
    GOEXPERIMENT=arenas go build -o ~/go/bin/qclient main.go
    cd ~
    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    service ceremonyclient start
    echo ====================================== 更新完成 =========================================
}

function upload2 () {
# stop the service
echo "1. stopping the ceremonyclient service first..."
service ceremonyclient stop
echo "... ceremonyclient service stopped"
 
# make a backup of the whole .config folder on your root folder
echo "2. making a backup of the entire .config folder on ~ folder..."
cd ~
cp -r ~/ceremonyclient/node/.config ~/config
config_copy_status=$?
config_copy_message="Successful"
if [ $config_copy_status != 0 ]; then
    config_copy_message="Unsuccessful"
fi
echo "... Copy Code: $config_copy_status - $config_copy_message"
echo "... backup of .config directory done"
 
# delete and remake the ceremonyclient directory
echo "3. deleting and recreating the ceremonyclient directory, in order to start afresh..."
if [ $config_copy_status != 0 ]; then
    echo "... because backup of .config failed, only renaming ceremonyclient to ceremonyclient_old"
    mv ceremonyclient ceremonyclient_old
else
    echo "... because backup of .config is successful, proceeding with deleting ceremonyclient folder"
    rm -rf ceremonyclient/
fi
mkdir ceremonyclient && cd ceremonyclient
echo "... deleted and recreated"
 
# setting release OS and arch variables
echo "4. setting release OS and arch and current version variables..."
release_os="linux"
release_arch="amd64"
current_version="2.0.2.3"
echo "... \$release_os set to \"$release_os\" and \$release_arch set to \"$release_arch\" and \$current_version set to \"$current_version\""
 
# create node directory and download all required node files (binaries, dgst, and sig files)
echo "5. creating node folder, and downloading all required node-related files (binaries, .dgst and *.sig files)..."
mkdir node && cd node
echo "... node folder recreated"
files=$(curl https://releases.quilibrium.com/release | grep $release_os-$release_arch)
for file in $files; do
    version=$(echo "$file" | cut -d '-' -f 2)
    if ! test -f "./$file"; then
        curl "https://releases.quilibrium.com/$file" > "$file"
        echo "... downloaded $file"
    fi
done
chmod +x ./node-$version-$release_os-$release_arch
cd ..
echo "... download of required node files done"
 
# creating client directory for qclient
echo "6. creating client folder, and downloading qclient binary..."
mkdir client && cd client
echo "... client folder recreated"
files=$(curl https://releases.quilibrium.com/qclient-release | grep $release_os-$release_arch)
for file in $files; do
    clientversion=$(echo "$file" | cut -d '-' -f 2)
    if ! test -f "./$file"; then
        curl "https://releases.quilibrium.com/$file" > "$file"
        echo "... downloaded $file"
    fi
done
chmod +x ./qclient-$clientversion-$release_os-$release_arch
cd ..
echo "... download of required qclient files done"
 
# copying your backed up .config directory inside node
echo "7. copying your backed up .config directory inside node..."
cp -r ~/config ~/ceremonyclient/node/.config
rm -rf ~/config
echo "... .config directory copied back in node folder"
 
# modifying the service configuration file
echo "8. modifying the service configuration file..."
sed -i "s/ExecStart=\/root\/ceremonyclient\/node\/node-$current_version-$release_os-$release_arch/ExecStart=\/root\/ceremonyclient\/node\/node-$version-$release_os-$release_arch/g" /lib/systemd/system/ceremonyclient.service
systemctl daemon-reload
echo "... replaced \"ExecStart=/root/ceremonyclient/node/node-$current_version-$release_os-$release_arch\" with \"ExecStart=/root/ceremonyclient/node/node-$version-$release_os-$release_arch\""
echo "... service configuration file updated"
 
# start the service again
echo "9. starting the service again..."
cd ~
service ceremonyclient start
echo "... service started"
}

function set_grpc () {
    cd ~
    sed -i 's/listenMultiaddr: \/ip4\/0.0.0.0\/udp\/8336\/quic/listenMultiaddr: \/ip4\/0.0.0.0\/tcp\/8336/g' ~/ceremonyclient/node/.config/config.yml
    sed -i 's/listenGrpcMultiaddr: ""/listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/g' ~/ceremonyclient/node/.config/config.yml
    sed -i 's/listenRESTMultiaddr: ""/listenRESTMultiaddr: \/ip4\/127.0.0.1\/tcp\/8338/g' ~/ceremonyclient/node/.config/config.yml
    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
}

function get_balances () {
    cd ~/ceremonyclient/node
    ./node-2.0.2.3-linux-amd64 --node-info
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
    echo "5. 升级2.0.2"
    echo "6. 设置grpc"
    echo "7. 查看余额"
    echo "=========================脚本运行================================"
    # echo "9. 查看日志"
    read -p "请输入选项（1-7）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) view_logs ;;  
    3) check_ceremonyclient_service_status ;; 
    4) backup_set ;;  
    5) upload2 ;; 
    6) set_grpc ;;  
    7) get_balances ;; 
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu