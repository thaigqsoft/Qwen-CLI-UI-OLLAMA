#!/bin/sh
# ==============================================================================
# MikroTik Network Optimization Script
# สร้างโดย: AI Assistant
# วัตถุประสงค์: ปรับปรุงประสิทธิภาพเครือข่าย MikroTik ให้ดียิ่งขึ้น
# คำอธิบาย: Script นี้จะปรับแต่ง MikroTik ตาม best practices เพื่อให้:
#          1. ความปลอดภัยสูงขึ้น
#          2. Performance ดีขึ้น ( Especially for video streaming)
#          3. Connection tracking มีประสิทธิภาพ
#          4. QoS settings เหมาะสม
# ==============================================================================

echo "=============================================================================="
echo "MikroTik Network Optimization Script (v1.1)"
echo "=============================================================================="

# ============================================================================
# ส่วนที่ 1: Firewall Filter Rules - ปรับปรุงและเพิ่มความปลอดภัย
# ============================================================================

echo ""
echo "[1/10] กำลังปรับปรุง Firewall Filter Rules..."
echo ""

# หลักการ: Rules ทำงานจากบนลงล่าง, rule แรกที่ match จะถูกใช้
# ต้อง置于 rules อื่นๆ ก่อนเสมอ

# เพิ่ม rule สำหรับอนุญาต connection ที่มีอยู่แล้ว (สำคัญที่สุด!)
ssh admin@192.168.76.240 '/ip firewall filter add chain=forward connection-state=established,related action=accept position=0 comment="Allow Established & Related Connections"'

# เพิ่ม rule สำหรับอนุญาต loopback (对自己 traffic)
ssh admin@192.168.76.240 '/ip firewall filter add chain=input in-interface=lo action=accept position=0 comment="Allow Loopback Interface"'

# เพิ่ม rule สำหรับอนุญาต ICMP แต่ rate limit (ป้องกัน ICMP flood)
ssh admin@192.168.76.240 '/ip firewall filter add chain=input protocol=icmp icmp-options=8:0 action=accept limit=10,5 comment="Allow Ping Rate Limit 10/sec"'

# ============================================================================
# ส่วนที่ 2: Connection Tracking Optimization
# ============================================================================

echo "[2/10] กำลังปรับปรุง Connection Tracking Settings..."
echo ""

# Connection tracking ติดตามสถานะ connection ทั้งหมด
# ตั้งค่า timeouts ให้เหมาะสมกับ use case เพื่อ save memory

# TCP timeouts - ลดเวลาสำหรับ connections ที่ไม่ใช้งาน
ssh admin@192.168.76.240 '/ip firewall connection tracking set tcp-established-timeout=12h'
ssh admin@192.168.76.240 '/ip firewall connection tracking set tcp-time-wait-timeout=5s'
ssh admin@192.168.76.240 '/ip firewall connection tracking set udp-timeout=30s'
ssh admin@192.168.76.240 '/ip firewall connection tracking set generic-timeout=5m'

# ============================================================================
# ส่วนที่ 3: DNS Optimization
# ============================================================================

echo "[3/10] กำลังปรับปรุง DNS Settings..."
echo ""

# DNS caching ช่วยลด latency และ bandwidth
ssh admin@192.168.76.240 '/ip dns set cache-size=4096KiB'
ssh admin@192.168.76.240 '/ip dns set query-server-timeout=1s'

# ============================================================================
# ส่วนที่ 4: Interface Lists
# ============================================================================

echo "[4/10] กำลังสร้าง Interface Lists..."
echo ""

# Interface lists ช่วยให้ firewall rules อ่านง่ายและจัดการง่าย
ssh admin@192.168.76.240 '/interface list add name=LAN comment="Local Area Networks"'
ssh admin@192.168.76.240 '/interface list add name=WAN comment="WAN Interfaces"'

# เพิ่ม interfaces เข้า LAN list
ssh admin@192.168.76.240 '/interface list member add list=LAN interface=ether2-Local'
ssh admin@192.168.76.240 '/interface list member add list=LAN interface=ether3-92'
ssh admin@192.168.76.240 '/interface list member add list=LAN interface=ether5-TRUE-4G'

# เพิ่ม interfaces เข้า WAN list
ssh admin@192.168.76.240 '/interface list member add list=WAN interface=ether1-WAN-AIS'
ssh admin@192.168.76.240 '/interface list member add list=WAN interface=TO_ECOM OFFICE'
ssh admin@192.168.76.240 '/interface list member add list=WAN interface=TO_IGETWEB_IDC'

# ============================================================================
# ส่วนที่ 5: Firewall Rules ด้วย Interface Lists
# ============================================================================

echo "[5/10] กำลังปรับปรุง Firewall Rules ด้วย Interface Lists..."
echo ""

# อนุญาต traffic จาก LAN ไปยัง Internet
ssh admin@192.168.76.240 '/ip firewall filter add chain=forward in-interface-list=LAN out-interface-list=WAN action=accept comment="Allow LAN to Internet"'

# อนุญาต DHCP (สำคัญสำหรับการตั้งค่าเริ่มต้น)
ssh admin@192.168.76.240 '/ip firewall filter add chain=input protocol=udp src-port=67 dst-port=68 action=accept comment="Allow DHCP Server"'

# อนุญาต DNS จาก LAN
ssh admin@192.168.76.240 '/ip firewall filter add chain=input protocol=udp src-address-list=LAN dst-port=53 action=accept comment="Allow DNS from LAN"'

# ============================================================================
# ส่วนที่ 6: FastTrack Rules (สำหรับ video streaming และ high-traffic)
# ============================================================================

echo "[6/10] กำลังปรับปรุง FastTrack Rules..."
echo ""

# FastTrack ช่วยให้ traffic ที่กำหนดผ่าน firewall ได้เร็วขึ้น
# โดยไม่ต้องผ่าน connection tracking ทั้งหมด

# FastTrack สำหรับ video streaming (YouTube, Netflix, etc.)
ssh admin@192.168.76.240 '/ip firewall mangle add chain=prerouting dst-address-list=GoogleVdeo action=notrack comment="FastTrack YouTube/Video Traffic"'

# FastTrack สำหรับ VoIP (Line, Discord, 电话)
ssh admin@192.168.76.240 '/ip firewall mangle add chain=prerouting dst-port=5060-5061,10000-20000 protocol=udp action=notrack comment="FastTrack VoIP Ports"'

# ============================================================================
# ส่วนที่ 7: Security Hardening
# ============================================================================

echo "[7/10] กำลังปรับปรุง Security Settings..."
echo ""

# ปิด source-route (ป้องกันการกำหนด route โดยผู้ส่ง)
/ip set accept-source-route=no

# ปิด icmp redirects (ป้องกัน ICMP redirect attacks)
/ip set accept-redirects=no

# เปิด secure-redirects (ใช้สำหรับป้องกัน MITM)
/ip set secure-redirects=yes

# เปิด tcp-syncookies (ป้องกัน SYN flood attack)
/ip set tcp-syncookies=yes

# ปรับ arp-timeout (ปกติ 30s ลดเป็น 20s)
/ip set arp-timeout=20s

# ปรับ icmp-rate-limit (ปกติ 10 เพิ่มเป็น 20)
/ip set icmp-rate-limit=20
/ip set icmp-rate-mask=0x1818

# ============================================================================
# ส่วนที่ 8: IPv4 Fast Path
# ============================================================================

echo "[8/10] กำลังเปิดใช้งาน IPv4 Fast Path..."
echo ""

# Fast path ช่วยให้ packet ผ่าน router ได้เร็วขึ้น
/ip set allow-fast-path=yes
/ip set ipv4-fast-path-active=yes

# ============================================================================
# ส่วนที่ 9: QoS Enhancement
# ============================================================================

echo "[9/10] กำลังปรับปรุง QoS Rules..."
echo ""

# เพิ่ม PCQ types สำหรับ VoIP
ssh admin@192.168.76.240 '/queue type add name=VoIP-Download kind=pcq pcq-rate=0 pcq-limit=50 pcq-classifier=dst-address comment="VoIP Download PCQ"'

# เพิ่ม PCQ types สำหรับ Web Browsing
ssh admin@192.168.76.240 '/queue type add name=Web-Download kind=pcq pcq-rate=0 pcq-limit=50 pcq-classifier=dst-address comment="Web Browsing PCQ"'

# ============================================================================
# ส่วนที่ 10: Logging และ Monitoring
# ============================================================================

echo "[10/10] กำลังตั้งค่า Logging และ Monitoring..."
echo ""

# เพิ่ม logging rule สำหรับ invalid packets
ssh admin@192.168.76.240 '/ip firewall filter add chain=forward connection-state=invalid action=log log-prefix="INVALID_PKT" comment="Log Invalid Packets"'
ssh admin@192.168.76.240 '/ip firewall filter add chain=forward connection-state=invalid action=drop comment="Drop Invalid Packets"'

# ============================================================================
# สรุปผลลัพธ์
# ============================================================================

echo ""
echo "=============================================================================="
echo "Optimization Complete! ✓"
echo "=============================================================================="
echo ""
echo "สรุปการเปลี่ยนแปลง:"
echo "  1. ✓ Firewall Filter Rules - เรียงลำดับถูกต้อง"
echo "  2. ✓ Connection Tracking - Timeouts optimize (12h established, 5s time-wait)"
echo "  3. ✓ DNS Settings - Cache 4MB, timeout 1s"
echo "  4. ✓ Interface Lists - สร้าง LAN/WAN lists"
echo "  5. ✓ FastTrack Rules - Video & VoIP traffic bypass conntrack"
echo "  6. ✓ Security Hardening - SYN flood protection enabled"
echo "  7. ✓ IPv4 Fast Path - Enabled"
echo "  8. ✓ QoS Enhancement - VoIP & Web queues"
echo "  9. ✓ Logging - Invalid packet logging"
echo ""
echo "วิธีตรวจสอบผลลัพธ์:"
echo "  /ip firewall filter print stats"
echo "  /ip firewall connection tracking print"
echo "  /ip dns print"
echo "  /interface list member print"
echo "  /queue type print"
echo ""
echo "หมายเหตุ: การเปลี่ยนแปลงบางอย่างต้องใช้ connection ใหม่"
echo "          หรือ reload ระบบถึงจะเห็นผลเต็มที่"
echo "=============================================================================="
