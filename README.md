# BeautifulSky
It is a cross-platform W32/W64 single execution path x86/x64 code base for self-replicators.<br />
For a detailed description, read SKYBEA2.TXT.

# What's new in BeautifulSky

– uses the same code to run in both x86/x64 modes, single execution path<br />
– fully x86/x64 compatible encoding<br />
– no self-modifying code to achieve compatibility<br />
– position independent-code and compatible with Address Space Layout Randomization<br />
– uses Process Environment Block (PEB) to get kernel32/ntdll directly on both platforms<br />
– stdcall/x64 calling convention compatible<br />
– own GetProcAddress() that supports PE32/PE32+<br />
– uses CRC32 instead of name strings<br />
– uses Vectored Exception Handler for common exception handling on both platforms<br />

BeautifulSky searches the current directory for any file (e.g find mask *.*). To open and map files for infection it uses an adapted and more efficient version of a technique used by W32.Cabanas virus by Jacky Qwerty in 1998.

# Compilation

Compile with masm32:<br />

ml /c /coff /Cp "beautifulsky.asm" <br />
link /SUBSYSTEM:CONSOLE /SECTION:.text,erw /OUT:"beautifulsky.asm" "beautifulsky.obj"<br />

Options:<br />
When mode64 option is defined (uncommented), SkyBeautiful64.exe is generated, but it must be run *manually*.<br />
When usefsgs is defined (uncommented), BeautifulSky uses the fs/gs procedure to get PEB address.<br />
When usefsgs is undefined (commented), BeautifulSky uses the cmov procedure to get PEB address from registers.<br />

# Contact
Contact me for comments, bug reports to: com.gmail@fsendjinn
