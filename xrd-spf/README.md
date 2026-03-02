# 替换 YAML 文件中的 config path

sed -i '' 's|startup-config: config/|startup-config: evpn-srte-fallback/|g' evpn.clab.yaml

# 抓包

示例:
`./xrd_cap.sh clab-evpn-lab-PE4 Gi0-0-0-0 30`

# XRD 镜像

load 镜像:

sudo docker load -i xrd-control-plane-container-x64.dockerv1.tgz

上传镜像到 dokerhub

docker login
docker tag ios-xr/xrd-control-plane:7.9.2 xuxing123/xrd-control-plane:7.9.2
docker push xuxing123/xrd-control-plane:7.9.2

# 配置规范

## 互联接口和 loopback IP 地址配置要求:

loopback: 10.1.X.X X 为设备 number ， 例如 R1， 则 loopback 地址为 10.1.1.1
互联接口地址: 10.1.XY.X, 例如 R1--R2， 则互联接口地址为 10.1.12.1 10.1.12.2
互联接口启用 lldp

## mpls ldp 配置模版:

mpls ldp
router-id <Lo0>

interface <Port>

## isis 配置模版:

router isis CORE
set-overload-bit on-startup 30
is-type level-2-only
net 49.0001.x.y.z.w.00
nsr
distribute link-state level 2
nsf ietf
log adjacency changes
lsp-refresh-interval 32768
max-lsp-lifetime 65535
address-family ipv4 unicast
metric-style wide
mpls traffic-eng level-2-only
mpls traffic-eng router-id Loopback1066
mpls traffic-eng igp-intact
maximum-paths 64
segment-routing mpls
!
address-family ipv6 unicast
maximum-paths 64

interface <Port>
circuit-type level-2-only
point-to-point
hello-padding disable
address-family ipv4 unicast

## xrd 的每台设备必须包含的配置

username admin
group root-lr
group cisco-support
password cisco!123
ssh server v2
