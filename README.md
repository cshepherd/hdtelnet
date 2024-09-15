# HD Telnet

Zero-Configuration Telnet client for 65C02-based Apple II computers with Uthernet II (NOT Uthernet I) ethernet cards

9/15/2024 Status:

Goals (kinda in order):
- Use Wiznet 5100 TCP offloading - DONE
- Support for 80-column and VidHD-specific wide-carriage text modes - DONE
- Connect to any DNS name / ip address on any port - DONE
- Card slot detection and network configuration via DHCP - DONE
- VT100 emulation (subset) - good enough for blinkenlights
- Limited character substitutions (mousetext for ANSI where it makes good sense) - TODO
