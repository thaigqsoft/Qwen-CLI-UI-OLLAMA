#!/bin/sh
# MikroTik YouTube Optimization Script
# เพิ่มประสิทธิภาพการเล่นวีดีโอ YouTube โดยใช้ QoS

echo "=== YouTube Optimization Script for MikroTik ==="
echo ""

# 1. Create PCQ Queue Types for Video Streaming
echo "[1/5] Creating PCQ queue types for video streaming..."
ssh admin@192.168.76.240 '/queue type add name=YouTube-Download kind=pcq pcq-rate=0 pcq-limit=50 pcq-classifier=dst-address pcq-src-address-mask=32 pcq-dst-address-mask=32'
ssh admin@192.168.76.240 '/queue type add name=YouTube-Upload kind=pcq pcq-rate=0 pcq-limit=50 pcq-classifier=src-address pcq-src-address-mask=32 pcq-dst-address-mask=32'

# 2. Mark YouTube Connections (Prerouting)
echo "[2/5] Marking YouTube connections..."
# YouTube uses googlevideo.com domain
ssh admin@192.168.76.240 '/ip firewall mangle add chain=prerouting dst-address-list=GoogleVdeo action=mark-connection new-connection-mark=YouTube-Conn passthrough=yes comment="Mark YouTube Connections"'

# 3. Mark YouTube Packets (Prerouting)
echo "[3/5] Marking YouTube packets..."
ssh admin@192.168.76.240 '/ip firewall mangle add chain=prerouting connection-mark=YouTube-Conn action=mark-packet new-packet-mark=YouTube-Pkt passthrough=no comment="Mark YouTube Packets"'

# 4. Create Queue Tree for YouTube
echo "[4/5] Creating queue tree for YouTube..."
# Root queue for download
ssh admin@192.168.76.240 '/queue tree add name=YouTube-Download parent=ether2-Local packet-mark=YouTube-Pkt queue=YouTube-Download priority=1 comment="YouTube Download Priority"'

# 5. Optional: Bypass connection tracking for high-volume video (advanced)
echo "[5/5] Optional: Setup raw table for bypass (to save CPU)..."
# Warning: This bypasses conntrack, so filter rules cannot use connection-state matching
ssh admin@192.168.76.240 '/ip firewall raw add chain=prerouting dst-address-list=GoogleVdeo action=notrack comment="Bypass conntrack for YouTube"'

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "To verify, run:"
echo "  /ip firewall mangle print stats"
echo "  /queue tree print"
echo ""
echo "Note: If using 'notrack', your filter rules cannot use 'connection-state' matching"
echo "      for YouTube traffic. Use port-based matching instead."
