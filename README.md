# build_openwrt_mf289F_24.10.5
Automates downloading, configuring, and building a custom OpenWrt firmware for the ZTE MF289F. Adds custom feeds, keys, local packages, and default configs, then compiles the image and exports the final sysupgrade file automatically.

# OpenWrt Custom Image Builder Script for ZTE MF289F
# 📘 Overview
This script automates the full process of building a custom OpenWrt firmware image for the ZTE MF289F (target ipq40xx/generic).
It handles downloading the correct ImageBuilder, configuring official and custom feeds, installing repository keys, bundling local packages, applying default configurations, and finally producing a ready‑to‑flash sysupgrade.bin.

The goal is to provide a repeatable, clean, and fully automated build pipeline for custom OpenWrt images.

# ✨ Features
# 🔽 Automated ImageBuilder Setup
Downloads the correct OpenWrt ImageBuilder based on version/target.

Verifies required system tools.

Extracts and prepares the build environment.

# 🔍 Automatic Kernel Hash Detection
Fetches the correct kmod hash from the official OpenWrt repository.

Regenerates repositories.conf with the proper feeds.

# 📦 Custom Feeds Integration
Registers additional feeds:

cristian_repo

IceG_repo

These are added to customfeeds.conf without downloading packages.

# 🔐 Repository Keys Handling
Copies all .pub keys from the keys/ directory.

Generates UCI-defaults scripts to install keys on first boot.

Ensures main repo keys are always added.

# 📁 Local Packages Support
Automatically checks, copies, and includes local .ipk packages:

luci-app-modemband

luci-app-sms-tool-js

luci-app-3ginfo-lite

luci-app-atcommands

These are added to the final firmware image.

# ⚙️ Predefined System Configurations
Injects default configs for:

network

firewall

(optional) wireless and other system files

All included via the FILES=files/ mechanism.

# 🏗️ Automated Firmware Build
Runs:
<pre>make image PROFILE=zte_mf289f FILES=files/ PACKAGES="...</pre>

and compiles a complete firmware image with all required packages.

# 💾 Final sysupgrade Export
Detects the generated sysupgrade.bin

Copies it to the user’s Desktop

Adds a timestamp to avoid overwriting previous builds

# Requirements
The following tools must be installed on the host system:

<pre>wget

tar

make

unzstd

sha256sum</pre>

# On Debian/Ubuntu:
<pre>sudo apt install wget tar make unzstd coreutils</pre>

# Place your local .ipk packages inside:

<pre>_local_packages/</pre>

# (Optional) Add your .pub keys inside:

<pre>keys/</pre>

# Run the script:

<pre>sudo ./build.sh</pre>

# After the build completes, the final firmware will be copied to:

<pre>~/Desktop/sysupgrade-zte_mf289f-YYYYMMDD-HHMM.bin</pre>

# Notes
The script is designed specifically for OpenWrt 24.10.x and the ZTE MF289F profile.

Custom feeds are registered but not automatically downloaded.

All keys are installed at first boot via UCI-defaults.

Local packages must follow the naming pattern <name>*.ipk.
