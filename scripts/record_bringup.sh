#!/bin/bash
# 一键建图录制: 每次运行创建一个会话目录, 结束后自动把
# bag + PCD + 配置文件快照 归拢到一起。
#
# 用法 (容器内):
#   record_bringup.sh                # 正常录制
#   record_bringup.sh rviz:=false    # 透传 roslaunch 参数
#
# 结束方式: 在终端按一次 Ctrl+C, 等脚本打印 "已保存到" 再关窗口。
# 输出结构:
#   $LIVO2_BAG_DIR/livo2_YYYYMMDD_HHMMSS/
#   ├── livo2_*.bag          (原始传感器数据, 每 4GB 自动切分)
#   ├── *.pcd                (Ctrl+C 后由 FAST-LIVO2 落盘的点云地图)
#   ├── lidar_poses.txt      (每帧雷达位姿)
#   └── config/              (本次运行用的内参/外参/驱动配置快照)

set -u

SESSION_DIR="$(date +%Y%m%d_%H%M%S)"
BAG_BASE="${LIVO2_BAG_DIR:-/root/datasets/recordings}"
SESSION_DIR="${BAG_BASE}/livo2_${SESSION_DIR}"
mkdir -p "${SESSION_DIR}/config"

LIVO_PKG="$(rospack find fast_livo)"
MVS_PKG="$(rospack find mvs_ros_driver)"

# 1. 保存本次运行的配置快照 (内参/外参/标定/驱动参数)
cp "${LIVO_PKG}/config/avia.yaml" \
   "${LIVO_PKG}/config/camera_pinhole.yaml" \
   "${LIVO_PKG}/launch/bringup.launch" \
   "${LIVO_PKG}/launch/mapping_avia.launch" \
   "${MVS_PKG}/config/left_camera_trigger.yaml" \
   "${SESSION_DIR}/config/"

echo "==> 会话目录: ${SESSION_DIR}"
df -h "${BAG_BASE}" | tail -1

# 2. 启动 bringup, bag 直接录进会话目录
LIVO2_BAG_DIR="${SESSION_DIR}" roslaunch fast_livo bringup.launch "$@"

# 3. roslaunch 退出后, 收集 PCD 和位姿文件
#    (PCD 由 FAST-LIVO2 在收到 Ctrl+C 后写到包目录 Log/pcd/ 下)
PCD_DIR="${LIVO_PKG}/Log/pcd"
if compgen -G "${PCD_DIR}/*.pcd" > /dev/null; then
  mv "${PCD_DIR}"/*.pcd "${SESSION_DIR}/"
fi
[ -f "${PCD_DIR}/lidar_poses.txt" ] && mv "${PCD_DIR}/lidar_poses.txt" "${SESSION_DIR}/"

echo "==> 所有数据已保存到 ${SESSION_DIR}"
ls -lh "${SESSION_DIR}"
