#!/bin/bash
#=============================================================
# diy-360t7.sh — 360T7 (MT7981) DIY 脚本
# 格式与 N1/diy-n1.sh 对齐
#=============================================================
set -euo pipefail

log() { echo ">>> [360T7] $*"; }

# ============================================================
# 基础设置（IP）
# ============================================================
log "设置默认 IP → 192.168.125.1"
sed -i 's/192.168.6.1/192.168.125.1/g' package/base-files/files/bin/config_generate

# ============================================================
# Golang + lang rust（部分插件编译依赖）
# ============================================================
log "替换 Golang → 27.x"
rm -rf feeds/packages/lang/golang
git clone --depth=1 -b 27.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

log "修复 lang-rust 404 问题"
rm -rf feeds/packages/lang/rust
git clone https://github.com/sbwml/packages_lang_rust feeds/packages/lang/rust

# ============================================================
# 清理 feeds 冲突包
# ============================================================
log "清理冲突包"
rm -rf feeds/packages/net/nikki 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-nikki 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-passwall 2>/dev/null || true
rm -rf feeds/packages/net/xray-core 2>/dev/null || true
rm -rf feeds/packages/net/sing-box 2>/dev/null || true
rm -rf feeds/packages/net/hysteria 2>/dev/null || true
rm -rf feeds/packages/net/chinadns-ng 2>/dev/null || true
rm -rf feeds/packages/net/dns2socks 2>/dev/null || true
rm -rf feeds/packages/net/ipt2socks 2>/dev/null || true
rm -rf feeds/packages/net/microsocks 2>/dev/null || true
rm -rf feeds/packages/net/tcping 2>/dev/null || true

# ============================================================
# 克隆官方 Passwall + 依赖
# ============================================================
log "克隆官方 Passwall"
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall.git package/passwall

# ============================================================
# 克隆第三方插件
# ============================================================

# --- nikki ---
log "克隆 nikki"
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/nikki
# nikki: 清除默认值，避免与用户配置冲突
log "nikki: 清除默认值 log_level/ui_url/tun_stack"
sed -i "/option 'log_level' 'warning'/d" package/nikki/nikki/files/nikki.conf
sed -i "\#option 'ui_url' 'https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip'#d" package/nikki/nikki/files/nikki.conf
sed -i "/option 'tun_stack' 'mixed'/d" package/nikki/nikki/files/nikki.conf

# --- lucky ---
log "克隆 lucky"
git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/lucky
# 修复 luci-app-lucky 在 uhttpd 下因内存限制导致二进制调用静默失败
log "lucky: 修复 uhttpd 内存限制"
LUCKY_CTRL=package/lucky/luci-app-lucky/luasrc/controller/lucky.lua
sed -i 's#luci.sys.exec("/usr/bin/lucky -info")#luci.sys.exec("ulimit -v unlimited 2>/dev/null; /usr/bin/lucky -info")#' "$LUCKY_CTRL"
sed -i 's#luci.sys.exec("lucky -baseConfInfo -cd "..configPath)#luci.sys.exec("ulimit -v unlimited 2>/dev/null; lucky -baseConfInfo -cd "..configPath)#' "$LUCKY_CTRL"
sed -i 's#luci.sys.exec(cmd)#luci.sys.exec("ulimit -v unlimited 2>/dev/null; "..cmd)#' "$LUCKY_CTRL"

# --- quickfile ---
log "克隆 quickfile"
git clone --depth=1 https://github.com/sbwml/luci-app-quickfile package/quickfile

# --- bandix ---
log "克隆 bandix"
git clone --depth=1 https://github.com/timsaya/luci-app-bandix package/bandix
git clone --depth=1 https://github.com/timsaya/openwrt-bandix package/openwrt-bandix

# ============================================================
# 注入 Nginx Quickfile 修复
# ============================================================
log "注入 Nginx Quickfile 修复"
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-fix-nginx-quickfile << 'EOF'
#!/bin/sh
uci set nginx.global.uci_enable='true'
uci del nginx._lan; uci del nginx._redirect2ssl
uci add nginx server; uci rename nginx.@server[0]='_lan'
uci set nginx._lan.server_name='_lan'
uci add_list nginx._lan.listen='80 default_server'
uci add_list nginx._lan.listen='[::]:80 default_server'
uci add_list nginx._lan.include='conf.d/*.locations'
uci set nginx._lan.access_log='off'
uci commit nginx
/etc/init.d/nginx restart
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-fix-nginx-quickfile

# ============================================================
# opkg 软件源配置
# ============================================================
log "注入 opkg 软件源配置"
mkdir -p package/base-files/files/etc/opkg

cat > package/base-files/files/etc/opkg.conf << 'EOF'
dest root /
dest ram /tmp
lists_dir ext /var/opkg-lists
option overlay_root /overlay
arch all 100
arch aarch64_generic 200
arch aarch64_cortex-a53 300
EOF

cat > package/base-files/files/etc/opkg/customfeeds.conf << 'EOF'
# add your custom package feeds here
src/gz openwrt_kiddin9 https://dl.openwrt.ai/latest/packages/aarch64_cortex-a53/kiddin9
EOF

log "完成 ✓"

# ============================================================
# 注释说明：softethervpn / ttyd 依赖
# ============================================================
# softethervpn 和 ttyd 应已包含在源码的 packages feed 中。
# 若 make defconfig 时提示找不到对应包，请取消以下注释手动克隆：
#
# git clone --depth=1 https://github.com/immortalwrt/packages.git /tmp/iw-pkgs
# cp -r /tmp/iw-pkgs/net/softethervpn5 package/softethervpn5 2>/dev/null || true
# cp -r /tmp/iw-pkgs/net/softethervpn package/softethervpn 2>/dev/null || true
# cp -r /tmp/iw-pkgs/utils/ttyd package/ttyd 2>/dev/null || true
# rm -rf /tmp/iw-pkgs
