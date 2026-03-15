#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if command -v apt >/dev/null 2>&1; then
  apt update
  apt list --upgradable 2>/dev/null
  read -p "Install updates now? (y/n): " ans
  if [ "$ans" = "y" ]; then
    apt upgrade -y
  fi
  echo ""
  echo "=== PACKAGE VERIFY ==="
  dpkg -V 2>/dev/null

elif command -v dnf >/dev/null 2>&1; then
  dnf check-update || true
  read -p "Install updates now? (y/n): " ans
  if [ "$ans" = "y" ]; then
    dnf update -y
  fi
  echo ""
  echo "=== PACKAGE VERIFY ==="
  rpm -Va 2>/dev/null

elif command -v yum >/dev/null 2>&1; then
  yum check-update || true
  read -p "Install updates now? (y/n): " ans
  if [ "$ans" = "y" ]; then
    yum update -y
  fi
  echo ""
  echo "=== PACKAGE VERIFY ==="
  rpm -Va 2>/dev/null

else
  echo "No supported package manager found."
  exit 1
fi
