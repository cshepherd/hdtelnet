# HD Telnet

Zero-Configuration Telnet client for 65C02-based Apple II computers with Uthernet II (NOT Uthernet I) ethernet cards, with VidHD wide-carriage text mode support

9/20/2024 Status: Pre-Alpha

Good:
- Uses Wiznet 5100 TCP offloading
- Support for 80-column and VidHD-specific wide-carriage text modes
- Connect to any DNS name / ip address on any port
- Uther II Card slot detection and network configuration via DHCP
- VT100 emulation (subset) - good enough for blinkenlights but only about halfway done
- VidHD card slot detection and mode setting
- Use ADB controller to write VidHD escape sequences
- Use Pascal write vector to output character except when it's the first after CH/CV change

Next Steps:
- More Telnet IAC support, now that it's its own submodule
- Finish vt100 support
- Limited character substitutions (mousetext for ANSI where it makes good sense) - TODO

Note:
Other stuff is much better. Use Telnet65 if you aren't concerned with VidHD support. I have my own reasons for writing this, but will happily review and merge any pull requests.
