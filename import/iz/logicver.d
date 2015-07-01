/**
 * The module logicver defines some constant bools for the 
 * predefined version identifiers. 
 *
 * These constants can be used to perform logical tests, 
 * in a much simpler way than when using nested version() statements.
 */
module iz.logicver;


/*
    
        DO NOT USE TEMPLATES OR MIXINS TO GENERATE THE VALUES. 
        
        this would break code completion in several IDE !!
*/

version(AArch64)            enum verAArch64 = true;
else                        enum verAArch64 = false;
    
version(AIX)                enum verAIX = true;
else                        enum verAIX = false;

version(ARM)                enum verARM = true;
else                        enum verARM = false;

version(ARM_HardFloat)      enum verARM_HardFloat = true;
else                        enum verARM_HardFloat = false;

version(ARM_SoftFP)         enum verARM_SoftFP = true;
else                        enum verARM_SoftFP = false;

version(ARM_SoftFloat)      enum verARM_SoftFloat = true;
else                        enum verARM_SoftFloat = false;

version(ARM_Thumb)          enum verARM_Thumb = true;
else                        enum verARM_Thumb = false;

version(Alpha)              enum verAlpha = true;
else                        enum verAlpha = false;

version(Alpha_HardFloat)    enum verAlpha_HardFloat = true;
else                        enum verAlpha_HardFloat = false;       

version(Alpha_SoftFloat)    enum verAlpha_SoftFloat = true;
else                        enum verAlpha_SoftFloat = false;  

version(Android)            enum verAndroid = true;
else                        enum verAndroid = false;   

version(BSD)                enum verBSD = true;
else                        enum verBSD = false;

version(BigEndian)          enum verBigEndian = true;
else                        enum verBigEndian = false; 

version(Cygwin)             enum verCygwin = true;
else                        enum verCygwin = false; 

version(D_Coverage)         enum verD_Coverage = true;
else                        enum verD_Coverage = false; 

version(D_Ddoc)             enum verD_D_Ddoc = true;
else                        enum verD_D_Ddoc = false;

version(D_HardFloat)        enum verD_HardFloat = true;
else                        enum verD_HardFloat = false;

version(D_InlineAsm_X86)    enum verD_InlineAsm_X86 = true;
else                        enum verD_InlineAsm_X86 = false;

version(D_InlineAsm_X86_64) enum verD_InlineAsm_X86_64 = true;
else                        enum verD_InlineAsm_X86_64 = false;

version(D_LP64)             enum verD_LP64 = true;
else                        enum verD_LP64 = false;

version(D_NoBoundsChecks)   enum verD_NoBoundsChecks = true;
else                        enum verD_NoBoundsChecks = false;

version(D_PIC)              enum verD_PIC = true;
else                        enum verD_PIC = false;

version(D_SIMD)             enum verD_SIMD = true;
else                        enum verD_SIMD = false;

version(D_SoftFloat)        enum verD_SoftFloat = true;
else                        enum verD_SoftFloat = false;

version(D_Version2)         enum verD_Version2 = true;
else                        enum verD_Version2 = false;

version(D_X32)              enum verD_X32 = true;
else                        enum verD_X32 = false;

version(DigitalMars)        enum verDigitalMars = true;
else                        enum verDigitalMars = false;

version(DragonFlyBSD)       enum verDragonFlyBSD = true;
else                        enum verDragonFlyBSD = false;

version(FreeBSD)            enum verFreeBSD = true;
else                        enum verFreeBSD = false;

version(FreeStanding)       enum verFreeFreeStanding = true;
else                        enum verFreeFreeStanding = false;

version(GNU)                enum verGNU = true;
else                        enum verGNU = false;

version(HPPA)               enum verHPPA = true;
else                        enum verHPPA = false;

version(HPPA64)             enum verHPPA64 = true;
else                        enum verHPPA64 = false;

version(Haiku)              enum verHaiku = true;
else                        enum verHaiku = false;

version(Hurd)               enum verHurd = true;
else                        enum verHurd = false;

version(IA64)               enum verIA64 = true;
else                        enum verIA64 = false;

version(LDC)                enum verLDC = true;
else                        enum verLDC = false;

version(LittleEndian)       enum verLittleEndian = true;
else                        enum verLittleEndian = false;

version(MIPS32)             enum verMIPS32 = true;
else                        enum verMIPS32 = false;

version(MIPS64)             enum verMIPS64 = true;
else                        enum verMIPS64 = false;

version(MIPS_EABI)          enum verMIPS_EABI = true;
else                        enum verMIPS_EABI = false;

version(MIPS_HardFloat)     enum verMIPS_HardFloat = true;
else                        enum verMIPS_HardFloat = false;

version(MIPS_N32)           enum verMIPS_N32 = true;
else                        enum verMIPS_N32 = false;

version(MIPS_N64)           enum verMIPS_N64 = true;
else                        enum verMIPS_N64 = false;

version(MIPS_O32)           enum verMIPS_O32 = true;
else                        enum verMIPS_O32 = false;

version(MIPS_O64)           enum verMIPS_O64 = true;
else                        enum verMIPS_O64 = false;

version(MIPS_SoftFloat)     enum verMIPS_SoftFloat = true;
else                        enum verMIPS_SoftFloat = false;


version(NetBSD)             enum verNetBSD = true;
else                        enum verNetBSD = false;

version(OSX)                enum verOSX = true;
else                        enum verOSX = false;

version(OpenBSD)            enum verOpenBSD = true;
else                        enum verOpenBSD = false;

version(PPC)                enum verPPC = true;
else                        enum verPPC = false;

version(PPC64)              enum verPPC64 = true;
else                        enum verPPC64 = false;

version(PPC_HardFloat)      enum verPPC_HardFloat = true;
else                        enum verPPC_HardFloat = false;

version(PPC_SoftFloat)      enum verPPC_SoftFloat = true;
else                        enum verPPC_SoftFloat = false;

version(Posix)              enum verPosix = true;
else                        enum verPosix = false;

version(S390)               enum verS390 = true;
else                        enum verS390 = false;

version(S390X)              enum verS390X = true;
else                        enum verS390X = false;

version(SDC)                enum verSDC = true;
else                        enum verSDC = false;

version(SH)                 enum verSH = true;
else                        enum verSH = false;

version(SH64)               enum verSH64 = true;
else                        enum verSH64 = false;

version(SPARC)              enum verSPARC = true;
else                        enum verSPARC = false;

version(SPARC64)            enum verSPARC64 = true;
else                        enum verSPARC64 = false;

version(SPARC_HardFloat)    enum verSPARC_HardFloat = true;
else                        enum verSPARC_HardFloat = false;

version(SPARC_SoftFloat)    enum verSPARC_SoftFloat = true;
else                        enum verSPARC_SoftFloat = false;

version(SPARC_V8Plus)       enum verSPARC_V8Plus = true;
else                        enum verSPARC_V8Plus = false;

version(SkyOS)              enum verSkyOS = true;
else                        enum verSkyOS = false;

version(Solaris)            enum verSolaris = true;
else                        enum verSolaris = false;

version(SysV3)              enum verSysV3 = true;
else                        enum verSysV3 = false;

version(SysV4)              enum verSysV4 = true;
else                        enum verSysV4 = false;

version(Win32)              enum verWin32 = true;
else                        enum verWin32 = false;

version(Win64)              enum verWin64 = true;
else                        enum verWin64 = false;

version(Windows)            enum verWindows = true;
else                        enum verWindows = false;

version(X86)                enum verX86 = true;
else                        enum verX86 = false;

version(X86_64)             enum verX86_64 = true;
else                        enum verX86_64 = false;

version(all)                enum verAll = true;
else                        enum verAll = false;

version(assert)             enum verAssert = true;
else                        enum verAssert = false;

version(linux)              enum verLinux = true;
else                        enum verLinux = false;

version(none)               enum verNone = true;
else                        enum verNone = false;

version(unittest)           enum verUnittest = true;
else                        enum verUnittest = false;

unittest
{
    static if (verD_InlineAsm_X86 && verDigitalMars)
        uint foo;
    else
        ulong foo;
        
    version(D_InlineAsm_X86)
        version(DigitalMars)
            static assert (is(typeof(foo) == uint)); 
    version(D_InlineAsm_X86_64)
        static assert (is(typeof(foo) == ulong));
        
        
    static if (verD_InlineAsm_X86_64 && verDigitalMars)
        uint bar;
    else
        ulong bar;  
        
        
    version(D_InlineAsm_X86_64)
        version(DigitalMars)
            static assert (is(typeof(bar) == uint)); 
    version(D_InlineAsm_X86)
        static assert (is(typeof(bar) == ulong));              
}

