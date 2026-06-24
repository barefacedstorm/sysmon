# XFCE CPU & Memory Panel Monitor Installer

A lightweight, automated Bash script to display real-time **CPU Core Graph** and **Memory Usage** on the top panel bar of your XFCE desktop environment, mimicking the default styling found in the x86 installer version of Kali Linux.

## Features

- **Multi-Distribution Compatibility**: Automatically detects your Linux distribution and uses the appropriate package manager (`apt-get`, `dnf`, or `pacman`) to install the required panel plugins.
- **Dynamic Xfconf Interactivity**: Directly interacts with the XFCE Configuration Engine (`xfconf-query`) to locate, configure, and register the plugins without corrupting configuration files.
- **Optimized Layout**: Places the CPU Graph and System Load (Memory) indicators right before the system tray/systray for visual balance.
- **Zero Redundancy**: Configures the System Load Monitor to show only RAM usage, relying on the visual CPU Graph to display active processor/core utilization.

## Supported Distributions

- **Kali Linux** (and Debian/Ubuntu derivatives)
- **Arch Linux**
- **Fedora**

## Prerequisites

- **XFCE Desktop Environment** with a running `xfce4-panel`.
- `sudo` privileges to install panel plugin packages if they are not already installed on the system.

## Installation

Run the script directly from your Desktop to install dependencies and configure the panel:

```bash
chmod +x ~/Desktop/install_sysmon_panel.sh
~/Desktop/install_sysmon_panel.sh
```

The script will automatically refresh your panel to load the widgets.

## Customization

Once installed, you can further customize both widgets via the GUI:
1. **CPU Graph**: Right-click the graph → **Properties** to configure colors, history time scale, display mode (LED, Fire, Grid, or Normal), and per-core usage bars.
2. **System Load (Memory)**: Right-click the memory bar → **Properties** to adjust colors, update intervals, or re-enable Swap/Uptime if desired.
