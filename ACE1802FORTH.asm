

;===================================================================
;
;                    A        CCCC     EEEEE
;                   A A      C         E
;                  AAAAA     C         EEEE
;                 A     A    C         E
;                A       A    CCCC     EEEEE
;
;  FFFF  I   GGG        FFFF   OO   RRRR   TTTTT  H   H
;  F     I  G           F     O  O  R  R     T    H   H
;  FFF   I  G GGG   XX  FFF   O  O  RRR      T    HHHHH
;  F     I  G   G       F     O  O  R  R     T    H   H
;  F     I   GGG        F      OO   R   R    T    H   H
;
;               1   8888    00   2222
;               1   8  8   0  0     2
;               1   8888   0  0   22
;               1   8  8   0  0  2
;               1   8888    00   2222
;
;=====================================================================
;  FIG-FORTH for the ASSOCIATION OF COMPUTER CHIP EXPERIMMENTERS (ACE)
;=====================================================================
;  
;       THIS PUBLICATION WAS ORIGINALLY MADE AVAILABLE BY THE
;               FORTH INTREST GROUP
;               P. O. BOX 1105
;               SAN CARLOS, CA 94070
;       ALL PUBLICATIONS OF THE FORTH INTEREST GROUP ARE PUBLIC DOMAIN.
;       THEY MAY BE FURTHER DISTRIBUTED BY INCLUSION OF THIS CREDIT NOTICE.
;
;       ORIGINAL IMPLEMENTATION (6502) BY:
;               WILLIAM F RAGSDALE
;               FORTH INTEREST GROUP
;
;       IMPLEMENTAION FOR 1802 BY:
;               GARY R. BRADSHAW;
;       MODIFIED BY:
;               GORDEN FLEMMING
;               JIM MCDANIEL
;
;      EDITOR :
;               WILLIAM F RAGSDALE
;               FORTH INTEREST GROUP
;
;      ASSEMBLER :
;               KEN MANTEI
;               CHEMISTRY DEPARTMENT
;               CAL STATE COLLEGE
;               SAN BERNARDINO, A 92407
;
;      Q & EF SPRTWARE UART SERIAL I/O TAKEN FROM CODE BY :
;               DAVID S MADOLE [ david@madole.net ]
;
;       OTHER MODIFICATIONS BY:
;               ANTHONY HILL  [ hill.anthony@outlook.com ]
;               ASSOCIATION OF COMPUTER CHIP EXPERIMENTERS (ACE)
;               - including ACE hardware, ROMable code, 
;                   interrupt driven 1854 and RTC, 
;                    mutlitasking, hex file download, serial screen load, 
;                    & support for Lee Hart's Membership Card Version
;
;       OTHER ACKNOWLEDGEMENTS:
;               This code has evolved 40 years.  Other contributions may have been used but not acknowleded.
;               Please contact Anthony Hill and you will be gratefully added.
;
;====================================================================
;
;    INSTALLATION & BUILD NOTES :
;    
;    1) Build using the A18 assembler for the 1802 ( https://www.retrotechnology.com/memship/a18.html )
;    2) Predefined build otions for 
;           - a generice 1802 ELF 
;           - Lee Hart's more recent Membership Card with 7 segment LED displays
;           - CDP1854 UART with interrrupt support ( with or without a tic timer interrupt)
;    3) Modify for other 1802 hardware by changing the code at CSEND, getKey, and qTERM
;    4) Build options for precompiled figFORTH line editor
;    5) Build options for precompiled 1802 assembler 
;    6) Build option to include other example code to control external hardwas ( 8255, 6818, etc)
;    7) Full system with all options will fit into a 16K EPROM
l    
;    bork) This file and its documentation are available at 
;
;
;====================================================================
;       1802 Register Allocations For This Version
;               R0    <<unused other than cold start PC >>
;               R1    ISR PC for task timers and / or UART (for Memebership Card, R1 = 0 disables interrupts to protect software UART)
;               R2    Return Stack Pointer
;                     Grows down left pointing to free location
;               R3    PC For I/O And Primitives
;               R4    Multitasker
;               R5    Multitasker stack for storing previous task state ??
;               R6    <<software UART serial code>>
;               R7,R8 Temporary Accumulators
;               R9    Computation Stack Pointer S0
;                     Grows upward left pointing at high byte
;               RA    Forth "I" Register        Ip
;               RB    Forth "W" Register        Wp
;               RC    PC For Inner Interpreter
;               RD    User Pointer              Up
;               RE    <<software UART serial code>>
;               RF    <<unused during cold or warm starts>>


;==========================  Useful Constants ===========================

R0           EQU 0                           ;
R1           EQU 1                           ;
R2           EQU 2                           ;
R3           EQU 3                           ;
R4           EQU 4                           ;
R5           EQU 5                           ;
R6           EQU 6                           ;
R7           EQU 7                           ;
R8           EQU 8                           ;
R9           EQU 9                           ;
RA           EQU 10                          ;
RB           EQU 11                          ;
RC           EQU 12                          ;
RD           EQU 13                          ;
RE           EQU 14                          ;
RF           EQU 15                          ;
no           EQU 0                           ;
yes          EQU 1                           ;
XON          EQU $11                         ;
XOFF         EQU $13                         ;
software     EQU 1                           ; 
hardware     EQU 2                           ; 


;==========================  Build Options ==============================

uart_type       equ software                 ; UART implemented in software or hardware ?
timer_type      equ software                  ; tic timer implemented in software or hardware ?
extra_hardware  equ no                       ; no / yes  = include code for extra hardware support ACE CPU systems
example_screens equ no                        ; no / yes  = include example Forth source screens at block -11

clock_mhz       equ 4                         ; cpu clock speed for bit bash uart timing ( 1.8 Mhz or 4 Mhz )
uart_config     equ $3E                       ; CDP1854 control register : Interrupts enabled, 8 data bits , 2 stop bits , even parity , parity enabled

load_address    equ 0                         ; 0= $0000 ,   1 = $4400 , 2 = $8000
version         equ 5 + load_address          ; version will be 5,6, or depending on load address selected
editor          equ no                       ; 1 = include line editor code
assembler       equ no                       ; 1 = include assembler code
stackptr_show   equ no                       ; show top of stack address after the OK prompt
zero_ram        equ no                        ; zero RAM at startup


;==========================  Memory Maps  =============================

 if load_address = 0                        ; ROM at $0000, RAM at $4000
                ORG $0000                   ; code start
START_OF_RAM    EQU $4000                   ; start of RAM area - must be on a page bountry
END_OF_RAM      EQU $8000                   ; end of RAM block - first byte after
S0_START        EQU END_OF_RAM-$0200        ; data stack (grows up)         S0
R0_START        EQU END_OF_RAM-$0101        ; return stack (grows down)     R0
USER_START      EQU END_OF_RAM-$0100        ; USER area - 64 variables max  UP
TIB_START       EQU END_OF_RAM-$0080        ; terminal input buffer         TIB
 if (uart_type = hardware)
tx_buffer       EQU END_OF_RAM-$0400        ; Reserve 256 bytes of RAM for UART rx and tx buffers NOTE : buffers must be on page boundaries
rx_buffer       EQU END_OF_RAM-$0300        ;
 endi
FIRSTB          EQU END_OF_RAM-$0400        ; used for RAM disk  : address of first disk screen #0 (unusable)
LIMITB          EQU $FFFF                   ; end of RAM disk area  (CONSTANT variable not currently used)
EXAMPLE_SCREENS EQU $3800                   ; BLOCK= -11
task1stacks     EQU END_OF_RAM-$0780        ; Reserve RAM for seven task stacks - task0stacks0 is the user task - uses default S0 & R0 values
task2stacks     EQU END_OF_RAM-$0700        ;
task3stacks     EQU END_OF_RAM-$0680        ;
task4stacks     EQU END_OF_RAM-$0600        ;
task5stacks     EQU END_OF_RAM-$0580        ;
task6stacks     EQU END_OF_RAM-$0500        ;
task7stacks     EQU END_OF_RAM-$0480        ;
 endi                                       ;

 if load_address = 1                        ; Warning: not much RAM so assumes FORTH code built with < $3000 bytes
                ORG $4400                   ; code start
START_OF_RAM    EQU $7400                   ; start of RAM area - must be on a page boundry
END_OF_RAM      EQU $8000                   ; end of RAM block - first byte after
S0_START        EQU END_OF_RAM-$0200        ; data stack (grows up)         S0
R0_START        EQU END_OF_RAM-$0101        ; return stack (grows down)     R0
USER_START      EQU END_OF_RAM-$0100        ; USER area - 64 variables max  UP
 if (uart_type = hardware)
tx_buffer       EQU END_OF_RAM-$0400        ; ; Reserve 256 bytes of RAM for UART rx and tx buffers NOTE : buffers must be on page boundaries
rx_buffer       EQU END_OF_RAM-$0300        ;
 endi
TIB_START       EQU END_OF_RAM-$0080        ; terminal input buffer         TIB
FIRSTB          EQU END_OF_RAM - $0400      ; used for RAM disk  : address of first disk screen #0 (unusable)
LIMITB          EQU $FFFF                   ; end of RAM disk area  (CONSTANT variable not currently used)
EXAMPLE_SCREENS EQU $7800                   ; BLOCK= ??
task1stacks     EQU END_OF_RAM-$0780        ; Reserve RAM for seven task stacks - task0stacks0 is the user task - uses default S0 & R0 values
task2stacks     EQU END_OF_RAM-$0700        ;
task3stacks     EQU END_OF_RAM-$0680        ;
task4stacks     EQU END_OF_RAM-$0600        ;
task5stacks     EQU END_OF_RAM-$0580        ;
task6stacks     EQU END_OF_RAM-$0500        ;
task7stacks     EQU END_OF_RAM-$0480        ;
 endi                                       ;


 if load_address = 2                        ;
                ORG $8000                   ; code start
START_OF_RAM    EQU $C000                   ; start of RAM area - must be on a page boundry
END_OF_RAM      EQU $FF00                   ; end of RAM block - first byte after
S0_START        EQU END_OF_RAM-$0200        ; data stack (grows up)         S0
R0_START        EQU END_OF_RAM-$0101        ; return stack (grows down)     R0
USER_START      EQU END_OF_RAM-$0100        ; USER area - 64 variables max  UP
 if (uart_type = hardware)
tx_buffer       EQU END_OF_RAM-$0400        ; ; Reserve 256 bytes of RAM for UART rx and tx buffers NOTE : buffers must be on page boundaries
rx_buffer       EQU END_OF_RAM-$0300        ;
 endi
TIB_START       EQU END_OF_RAM-$0080        ; terminal input buffer         TIB
FIRSTB          EQU $4000 - $0400           ; used for RAM disk  : address of first disk screen #0 (unusable)
LIMITB          EQU $7FFF                   ; end of RAM disk area  (CONSTANT variable not currently used)
EXAMPLE_SCREENS EQU $B800                   ; BLOCK=1F  (31 decimal)
task1stacks     EQU END_OF_RAM-$0780        ; Reserve RAM for seven task stacks - task0stacks0 is the user task - uses default S0 & R0 values
task2stacks     EQU END_OF_RAM-$0700        ;
task3stacks     EQU END_OF_RAM-$0680        ;
task4stacks     EQU END_OF_RAM-$0600        ;
task5stacks     EQU END_OF_RAM-$0580        ;
task6stacks     EQU END_OF_RAM-$0500        ;
task7stacks     EQU END_OF_RAM-$0480        ;
 endi                                       ;



;========================== Power Up Entry Point ======================================================================

START:                                       ; entry point on power up when PC = R0
        DIS                                  ; disable interrupts / PC = R0  SP =  R0
        DB $00                               ; DIS instruction loads 0 to P and X
 if (uart_type = software)        
        SEQ                                  ; set Q high for software UART
 endi
        LDI high COLD                        ; initialize R3 as program counter
        PHI R3                               ;
        LDI low COLD                         ;
        PLO R3                               ;
        SEP R3                               ;

;========================== Cold Start Entry Point ======================================================================
;
;   entry point assumes P=3, X=? and resets everything to default state
;

COLD:   LDI low (USER_IMAGE_COLD-USER_IMAGE) ; initialize cold start USER data initialization ( currently 22 bytes)
        LSKP                                 ; skip warm start entry point

;========================== Warm  start Entry Point ======================================================================
;
;  entry point assumes P=3, X=? and resets everything except any new dictionary workds
;

WARM:   LDI low (USER_IMAGE_WARM-USER_IMAGE) ; initialize warm start USER data initialization  ( currently 16 bytes)
        PLO RF                               ; RF.0 = count of bytes to initialize
        LDI high USER_BASE                   ; R7 -> USER area image in ROM
        PHI R7                               ;
        LDI low USER_BASE                    ;
        PLO R7                               ;
        LDA R7                               ; RD , R8 -> USER area pointer store in ROM
        PHI RD                               ;
        PHI R8                               ;
        LDA R7                               ;
        PLO R8                               ;
        PLO RD                               ;
        LDI low USER_IMAGE                   ; R7 -> USER area image in ROM
        PLO R7                               ;
COPYLOOP:                                    ; Copy intialization data (warm or cold)
        LDA R7                               ;
        STR R8                               ;
        INC R8                               ;
        DEC RF                               ;
        GLO RF                               ;
        BNZ COPYLOOP                         ;
                                             ; SNEAKY HACK : R7 content flags if this was a warm or cold start for later STARTUP usage
        LDI high NEXT                        ; RC -> inner interpreter NEXT
        PHI RC                               ;
        LDI low NEXT                         ;
        PLO RC                               ;
        LDI low ABRT2                        ; RA = Forth "I" Register = ABORT1
        PLO RA                               ;
        LDI high ABRT2                       ;
        PHI RA                               ;
                                             ;
 if zero_ram eq 1
        LDI high START_OF_RAM                ; zero out all RAM - useful for debugging as memory dumps are easier to understand
        PHI R2                               ;
        LDI low START_OF_RAM                 ;
        PLO R2                               ;
zrloop: LDI $00                              ;
        STR R2                               ;
        INC R2                               ;
        GLO R2                               ;
        SMI low R0_START                     ;
        BNZ zrloop                           ;
        GHI R2                               ;
        SMI high R0_START                    ;
        BNZ zrloop                           ;
 endi
                                             ;
        LDI high R0_START                    ; set R2 to return stack address
        PHI R2                               ;
        LDI low R0_START                     ;
        PLO R2                               ;
        SEX R3                               ; interrupts off, PC=3, SP=2
        DIS                                  ;
        DB $23                               ;
        GLO R7                               ; NOTE : hack to make WARM start work based on where it stopped during copy of initialzed variables
        SMI low USER_IMAGE_COLD - 1          ;
        BGE warm_init                        ;
                                             ;
cold_init:                                   ;
        LDI high (PROM_TABLE_WARM_END-PROM_TABLE) ; warm start tranfer initialized variable table from ROM to RAM
        PHI RF                               ;
        LDI low (PROM_TABLE_WARM_END-PROM_TABLE)  ;
        PLO RF                               ;
        BR start1                            ;
warm_init:                                   ;
        LDI high (PROM_TABLE_COLD_END-PROM_TABLE) ; warm start tranfer initialized variable table from ROM to RAM
        PHI RF                               ;
        LDI low (PROM_TABLE_COLD_END-PROM_TABLE)  ;
        PLO RF                               ;
start1: LDI high PROM_TABLE                  ;
        PHI R7                               ;
        LDI low PROM_TABLE                   ;
        PLO R7                               ;
        LDI high START_OF_RAM                ;
        PHI R8                               ;
        LDI low START_OF_RAM                 ;
        PLO R8                               ;
STRT1:  LDA R7                               ;
        STR R8                               ;
        INC R8                               ;
        DEC RF                               ;
        GLO RF                               ;
        BNZ STRT1                            ;
        GHI RF                               ;
        BNZ STRT1                            ;
                                             ;
 if (uart_type = hardware)

        LDI high rx_optr+DELTA               ; intialize UART Tx and RX buffer pointers
        PHI R8                               ;
        LDI low rx_optr+DELTA                ;
        PLO R8                               ;
        LDI $00                              ;
        STR R8                               ;
        INC R8                               ;
        STR R8                               ;
        INC R8                               ;
        INC R8                               ;
        STR R8                               ;
        INC R8                               ;
        STR R8                               ;
                                             ;
        INP 5                                ; initialize UART
        INP 6                                ;

        LDI uart_config                      ;
        STR R2                               ;
        OUT 5                                ;
        DEC R2                               ;
        INP 5                                ; clear UART status and data registers
        INP 6                                ;

 endi

        LDI high R0_START                    ; initialize R2 = ISR -> stack pointer
        PHI R2                               ;
        LDI low  R0_START                    ;
        PLO R2                               ;
        LDI high TASKLIST+DELTA              ; setup multi tasking registers R4, R4
        PHI R4                               ;
        LDI low  TASKLIST+DELTA              ;
        PLO R4                               ;
        LDI high TCB+DELTA                   ;
        PHI R5                               ;
        LDI low  TCB+DELTA+5                 ;
        PLO R5                               ;

  if (uart_type = hardware)
                                             ;
        LDI high ISRentry                    ; initialize R1 = ISR PC ( for UART and task timers )
        PHI R1                               ;
        LDI low ISRentry                     ; 
        PLO R1                               ;
        LDI $23                              ; enable interrupts / PC = R3  SP =  R2
        STR R2                               ;
        RET                                  ;
  else
        LDI $00                             ; start with interrupts off and ISR disabled
        PHI R1                              ;
        PLO R1                              ;
  endi

        LBR RP1A                             ; jump to RP! word - loads the stack pointer and then does a SEP RC into the inner interpreter



;============================================== Legacy fig-FORTH Standard Initializationds Header Area ========================================

ORIGIN   equ $ - 8                          ; CAUTION : USER variables and some initialization values are hard coded by +ORIGIN from here
                                            ; ( <-- in FIG model,  space for cold and warm start jumps was here )
        DW 1802                             ; CPU NUMBER
        DW $0001+version                    ; REVISION NUMBER
                                            ;
USER_IMAGE:                                 ; base of USER area (copied to RAM @ 7F00) - USER variable are relative to the relocated address?
        DW FORTH-8+DELTA                    ; top most word in FORTH vocabulary  ( was TASK - 7 )  $407D
        DW $0008                            ; backspace
USER_BASE:                                  ;
        DW USER_START                       ; USER area               UP
        DW S0_START                         ; data stack              S0
        DW R0_START                         ; return stack            R0
        DW TIB_START                        ; terminal input buffer   TIB
        DW $001F                            ; name field width        WIDTH
        DW $0001                            ; warning                 WARNING
        DW $0001                            ; caps lock flag          CAPS
USER_IMAGE_WARM:                            ;
        DW PROM_TABLE_COLD_END+DELTA        ;                        FENCE
        DW PROM_TABLE_COLD_END+DELTA        ;                        DP
        DW ASSEM1+DELTA                     ;                        VOC-LINK
USER_IMAGE_COLD:                            ;



;============================================== Preload table of initializtion of variables stored in RAM =====================================================

; Note : this table holds variable with initialized values.  It are relocated to RAM during system startup
;

PROM_TABLE:                                 ; <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

DELTA   EQU START_OF_RAM - PROM_TABLE       ; offset to where intialized variable will be located & initialized from values stored in EPROM

 if (extra_hardware = yes)                  ; Note : this must be on a page boundary when moved to RAM to map 6321's ports via OUT 4 instruction
                                            ;
PPORT:  DB $00, $00, $00, $00               ; 6845 Parrallel Port Bytes 0 - 3  ( relocates to $4000 )
lcd_buffer  DB $0,$0,$0,$0,$0,$0,$0,$0      ; Reserve RAM for LCD display drivers
                                            ;
 endi                                       ;


 if (uart_type = hardware)                  ;
                                            ; CDP1854 UART ISR pointers and data buffers - only needs to be 8 bit ptr as buffers are page aligned and exactly a page long
rx_optr:    DB $0                           ; NOTE : ORDER MATTERS HERE as ISR assumes 5 bytes ordered this way
rx_iptr:    DB $0                           ;
xonxoff:    DB $0                           ; set to one to force an initial XON
tx_iptr:    DB $0                           ;
tx_optr:    DB $0                           ;

 endi

TCB:    DW R0_START,          S0_START   , null_task    ; 0 - terminal task
        DW task1stacks+$0080, task1stacks, demo_task    ; 1
        DW task2stacks+$0080, task2stacks, null_task    ; 2
        DW task3stacks+$0080, task3stacks, null_task    ; 3
        DW task4stacks+$0080, task4stacks, null_task    ; 4
        DW task5stacks+$0080, task5stacks, null_task    ; 5
        DW task6stacks+$0080, task6stacks, null_task    ; 6
        DW task7stacks+$0080, task7stacks, null_task    ; 7

TIMERS:                                                 ;
        DB $00, $00, $00, $00, $00, $00, $00, $00       ; task TIC timers ( Warning: must be on same page )

TASKLIST:                                   ; tasker  ( PC= R4 - each task runs when SKP is replaced with SEP R3 - self modifying code)
        SEP R3                              ; 0
        DB low TCB+DELTA+00                 ;
        SKP                                 ; 1
        DB low TCB+DELTA+06                 ;
        SKP                                 ; 2
        DB low TCB+DELTA+12                 ;
        SKP                                 ; 3
        DB low TCB+DELTA+18                 ;
        SKP                                 ; 4
        DB low TCB+DELTA+24                 ;
        SKP                                 ; 5
        DB low TCB+DELTA+30                 ;
        SKP                                 ; 6
        DB low TCB+DELTA+36                 ;
TL7:    SKP                                 ; 7
        DB low TCB+DELTA+42                 ;
                                            ;
 if (timer_type = software)                   ; fake TIC_timer_update
        LDI high TL7+DELTA                  ; R7 -> last task control block
        PHI R7                              ;
        LDI low TL7+DELTA                   ;
        PLO R7                              ;
        LDI high TIMERS+7+DELTA             ; R8 -> task timers
        PHI R8                              ;
        LDI low TIMERS+7+DELTA              ;
        PLO R8                              ;
check_timer1:                               ;
        LDN R8                              ; get next timer
        DB $32, low (next_timer1+DELTA)     ; BZ to relocated address if its not running
        SMI $01                             ; decrement timer
        STR R8                              ; save new value
        DB $3A, low (next_timer1+DELTA)     ; BNZ jump if still not zero
        LDI $D3                             ; else push $D3 to RAM buffer to activate task as timer has expired
        STR R7                              ;
next_timer1:
        DEC R7                              ; back up task list
        DEC R7                              ;
        DEC R8                              ; next timer byte
        GLO R8                              ; check if pointer back past start of table
        SMI low TIMERS+DELTA-1              ;
        DB $3A, low (check_timer1+DELTA)    ; BNZ loop back if not at end of buffe
 endi
        DB $30, low (TASKLIST+DELTA)        ; trick the assember into creating a short branch ( Warning : must be on same page )

uart_errors DB $0, $0, $0                   ;  overrun error , parity error , framing error counters

 if (uart_type = software) and (timer_type = hardware)

tic_scaler_preset_value EQU $2
TIC_SCALER       DB  tic_scaler_preset_value  ; count down timer for tic update
LED_BUF_POINTER  DB  low LED_BUFFER+DELTA     ; holds the current digit address being displayed on the six digit display
LED_BUFFER       DB  "-Forth"                 ; allocate 6 bytes either blank or a default string

 endi

PROM_TABLE_WARM_END

        ;
        ;  -----------------------------------------------------------------------------
        DB $C9,"ASSEMBLE",$D2               ; ASSEMBLER Vocabulary Link  - must be located in RAM
        DW FORTH_LAST_WORD                  ; link back into main forth vocabulary tree
ASSEMBLER: DW DUZ1                          ; PFA -> DOES
        DW VB1                              ; VOCABULARY
        DW $81A0                            ; fake header ( space ) - its LFA is the next word
 if assembler = 0                           ;
        DW FRTH0+DELTA                      ; link to LATEST address for this vocabulary
 else                                       ;
        DW ASSEMBLER_LAST_WORD              ;
 endi                                       ;

ASSEM1:  DW ED1+DELTA                       ; link to previous dictionary  $407B

        ;
        ;  -----------------------------------------------------------------------------
        DB $C6,"EDITO",$D2                  ; EDITOR Vocabulary Link - must be located in RAM
        DW ASSEMBLER-12+DELTA               ; NFA of ASSEMBLER
EDITOR: DW DUZ1                             ; PFA -> DOES
        DW VB1                              ; VOCABULARY
        DW $81A0                            ; fake header ( space ) - its LFA is the next word
 if editor = 0                              ;
        DW FRTH0+DELTA                      ; link to LATEST address for this vocabulary
 else                                       ;
        DW EDITOR_LAST_WORD                 ; link to LATEST address for this vocabulary
 endi                                       ;

ED1:    DW FRTH1+DELTA                      ; link to previous dictionary  $408D

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,"FORT",$C8                   ; FORTH Vocabulary Link - must be located in RAM
        DW EDITOR-9+DELTA                   ; NFA of EDITOR
FORTH:  DW DUZ1                             ; PFA -> DOES
        DW VB1                              ; VOCABULARY
FRTH0:  DW $81A0                            ; fake header ( space ) - its LFA is the next word
        DW FORTH-8+DELTA                    ; link to LATEST address for this vocabulary
FRTH1:  DW $0000                            ; link to previous dictionary - 0 means this is the root vocab


PROM_TABLE_COLD_END:     ;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


 PAGE
;**********************************************************************************************************************************
;********************************************  Hardware Customization Section Starts Here********************************************
;**********************************************************************************************************************************

 if ( uart_type = software )

        ;=================================================================
        ;
        ; KEY INPUT : software UART  via Q and EF
        ;`
                                            ;
getKEY: GLO R1                              ; are interrupts disabled (i.e. console input in process) ?
        BZ  key_ints_off                    ; go wait for the next character if so
        B3 activate_console                 ; otherwise is an incoming character detected?
        LBR tsk_repeat                      ; keep multi-tasking if not
                                            ;
activate_console:                           ; serial input activity detected so activate console input
        SEX     R3                          ; disable interrupts
        DIS                                 ;
        db    $23                           ; PC = 3,  SP = 2
        LDI $00                             ; flag interrupts as off for console input by destroying the ISR entry address held in R1
        PLO R1                              ;
        INC R9                              ; ignore the incoming character as we were likely too slow to rx it correctly
        INC R9                              ;
        STR R9                              ;
        INC R9                              ;
        LDI $0D                             ; save a CR on the stack instead and send that back
        STR R9                              ;
        DEC R9                              ;
        LBR TASKER                          ; done
                                            ;
key_ints_off:                               ;
        BN3     $                           ; wait for start bit
        LDI     $00                         ; nop - one byte that also sets D=0 and being empty means
                                            ; ... that  no bits will shift out the first 7 times through the loops below
        LDI     $00                         ; nop  (first time through will set a bit to shift in. When it shifts out,
                                            ; ... 8 bits have been sent).
spc:    SMI     $0                          ; set DF  (first time through will set a bit to shift in. When it shifts out,
                                            ; ... 8 bits have been sent).
mark:   SHRC                                ; shift next serial bit in to rx byte ( DF = 0 if we jump directly here.
                                            ; ... DF = 1 if we are falling throught from the SHRC instruction above)
        BDF     kdone                       ; if a bit pops out of D when shifted it means we have shifted 8 times
                                            ;
 if clock_mhz = 4                           ;
        NOP                                 ; 1.5 additional instruction ( 6 usec per nop )
        NOP                                 ; 3.0
        NOP                                 ; 4.5
        NOP                                 ; 6.0
        SEP R3                              ; 2 cycle NOP
 endi                                       ;
        SEP     R3                          ; nop (as P = 3 already )
        SEP     R3                          ; nop
        BN3     spc                         ; jump if next serial bit a zero
        BR      mark                        ; otherwise it's a one
kdone:                                      ;
        INC R9                              ; save received character
        INC R9                              ;
        INC R9                              ;
        STR R9                              ;
        SMI $0D                             ; was it a CR ?
        BNZ kd1                             ; 
        GHI R1                              ; is there a valid ISR address in R1.1 ?
        BZ  kd1                             ; don't reenable interrupts if not - assume ints disabled via the DI word
                                            ;
        LDI low ISR                         ; re=enable interrupts if CR and they are not user disabled
        PLO R1                              
        SEX     R3                          ; enable interrupts
        RET                                 ;
        db    $23                           ; PC = 3,  SP = 2
kd1:                                        ;
        DEC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        LBR TASKER                          ; done
        

;********************************************************** 19200 baud_rate ******
;
; software UART the value in D out on the Q line
;   - 1.8MHz =  5.8 2 cycle instructions per bit
;   - 4.0MHz = 13.0 2 cycle instructions per bit  (add 7 2 cycle or 4 NOP + 1 2 cycle)
; Uses RE
;----------------------------------------------------------------------
;

CSEND:  DW $+2                            ;
        INC R9                              ; pop tx char from computation stack
        LDN R9                              ;
        DEC R9                              ; and cleanup computation stack
        DEC R9                              ;
        DEC R9                              ;
                                            ;
        SEX     R3                          ; disable interrupts for now but don't flag them as being off for console input
        DIS                                 ;
        db    $23                           ;
        REQ                                 ; send start bit
 if clock_mhz = 4
        NOP                                 ; 1.5 additional instruction ( 6 usec per nop )
        NOP                                 ; 3.0
        NOP                                 ; 4.5
        NOP                                 ; 8.0
        REQ                                 ; 9.5
 endi
        SHRC                                ; check first data bit by shifting into DF
        PHI     RE                          ; RE.1 = remaining bits to be sent
                                            ;
        LDI     4                           ; bit count = 4
        PLO     RE                          ; RE.0 = bit counter
        BDF     SEQ1                        ; jump if next data bit is a 1
                                            ;
REQ1:   REQ                                 ; data bit was a zero so reset Q
                                            ;
 if clock_mhz = 4
        NOP                                 ; 1.5 additional instruction ( 6 usec per nop )
        NOP                                 ; 3.0
        NOP                                 ; 4.5
        NOP                                 ; 8.0
        REQ                                 ; 8.0
 endi
        GHI     RE                          ; D = remaining data bits
        SHRC                                ; move next bit into DF
        BDF     SEQ2                        ; jump if it's a 1
REQ2:   SHRC                                ; data bit was a zero
        PHI     RE                          ; RE.1 = remainging data bits
        REQ                                 ; data bit was a zero so reset Q

 if clock_mhz = 4
        NOP                                 ; 1.5 additional instruction ( 6 usec per nop )
        NOP                                 ; 3.0
        NOP                                 ; 4.5
        NOP                                 ; 8.0
        REQ                                 ; 9.5
 endi
                                            ;
        REQ                                 ; 2 cycle "nop" in place of BR at end of EQ2
                                            ;
OLOOP:                                      ;
        DEC     RE                          ; decrement bit count
        GLO     RE                          ; check if we are all done
        BZ      STOP                        ; exit if so
        BNF     REQ1                        ; else go process next bit
                                            ;
SEQ1:   SEQ                                 ; data bit was a one so set Q
                                            ;
 if clock_mhz = 4
        NOP                                 ; 1.5 additional instruction ( 6 usec per nop )
        NOP                                 ; 3.0
        NOP                                 ; 4.5
        NOP                                 ; 8.0
        SEQ                                 ; 8.0
 endi
        GHI     RE                          ; RE.1 = remainging data bits
        SHRC                                ; move next bit into DF
        BNF     REQ2                        ; jump if it's a 0
SEQ2:   SHRC                                ; data bit was a zero
        PHI     RE                          ; RE.1 = remainging data bits
        SEQ                                 ; data bit was a zero so rest Q

 if clock_mhz = 4
        NOP                                 ; 1.5 additional instruction ( 6 usec per nop )
        NOP                                 ; 3.0
        NOP                                 ; 4.5
        NOP                                 ; 8.0
        SEQ                                 ; 8.0
 endi
        BR      OLOOP                       ; go process next bit  (also a 2 cycle "nop")
                                            ;
STOP:   SEQ                                 ; all done so set line to idle state
        GHI R1                              ; is there a valid ISR address in R1.1 ?
        BZ  no_int_enable                   ; don't reenable interrupts if user disabled is DI word
        GLO R1                              ; are interrupts off for console input?
        BZ  no_int_enable                   ; don't turn them back on if so
        SEX     R3                          ; re-enable interupts
        RET                                 ;
        DB     $23                          ;
no_int_enable:
        LBR TASKER                          ; done
        

        ;=================================================================
        ;
        ; ?TERMINAL 

qTERM:                                      ;
        INC R9                              ; prep data stack pointer
        INC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        INC R9                              ;
;        B4  ef4true                        ; FIXME test membership card EF4 pushbutton state
        BR ef4true                          ; FIXME
        LDI $01                             ;
ef4true:                                    ;
        STR R9                              ; save # of chars on stack ( 0 = false = not data )
        DEC R9                              ;
        LBR TASKER                          ; all done if buffer not empty

 else
        ;=================================================================
        ;
        ; KEY INPUT :  CDP1854 UART Version with interrupt support
        ;

XOFF_LIMIT       EQU $80                     ; characters in rx buffer when XOFF sent
XON_LIMIT        EQU $F0                     ; free space in rx buffer when XON sent

getKEY: SEX R8                              ;
        LDI high rx_optr+DELTA              ; R8 -> rx output pointer
        PHI R8                              ;
        LDI low rx_optr+DELTA               ;
        PLO R8                              ;
        LDI high rx_iptr+DELTA              ; R7 -> rx insert pointer
        PHI R7                              ;
        LDI low rx_iptr+DELTA               ;
        PLO R7                              ;
        LDN R7                              ;
        SM                                  ; if rx_iptr = rx_optr then rx buffer is empty
        LBZ tsk_repeat                      ; nothing ready - reset the I/O routine to run on next outer interpreter pass (assume no XON needed)
                                            ;
        INC R9                              ; pull next rx char from buffer to computation stack
        INC R9                              ;
        LDI $00                             ; high byte = 0
        STR R9                              ;
        INC R9                              ;
        LDI high rx_buffer                  ; R7 -> rx buffer
        PHI R7                              ;
        LDN R8                              ; get optr advance and wrap
        ADI $01                             ;
        PLO R7                              ; R7 -> next rx buffer space
        STR R8                              ; save new value of optr
        LDN R7                              ; read from rx buffer <- R7 (optr) and advance pointer
        STR R9                              ; save on data stack
                                            ;
        LDI $00                             ;** FIXME debug - destroy the char in the buffer to make sure we are not getting repeats from there during this debug process
        STR R7                              ;**
                                            ;
        GHI RD                              ; is virtual caps lock enabled in USER variable CAPS?
        PHI R7                              ;
        GLO RD                              ;
        ADI low capslock  + 1               ; low byte only
        PLO R7                              ;
        LDN R7                              ;
        BNZ filter_char                     ;
        LDN R9                              ; check for  SI (shift in) to enable caps lock / filtering
        SMI $0F                             ;
        BNZ accept_char                     ;
                                            ;
filter_char:                                ;
        LDN  R9                             ; check for control characters
        SMI  $1F                            ;
        BGE   not_ctrl                      ;
        LDN  R9                             ; accept a carriage return
        SMI  $0D                            ;
        BZ   accept_char                    ;
        LDN  R9                             ; accept a backspare
        SMI  $08                            ;
        BZ   accept_char                    ;
        LDN  R9                             ;
        SMI  $0E                            ; FIXME :   process SO (shift out) to disable caps lock / CTRL filters
        BNZ  not_SO                         ;
        LDI $00                             ;
        STR R7                              ;
        BR  ignore_char                     ;
not_SO: LDN  R9                             ;
        SMI  $0F                            ; FIXME :  process SI (shift in) to enable caps lock / CTRL filer
        BNZ  ignore_char                    ;
        LDI $01                             ;
        STR R7                              ;
ignore_char:                                ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        LBR tsk_repeat                      ; reset the I/O routine to run on next outer interpreter pass
                                            ;
not_ctrl:                                   ;
        LDN R9                              ;
        ANI $80                             ; accept 7 bit ASCII only
        BNZ ignore_char                     ;

 ;       LDN R9                              ;
 ;       SMI $61                             ; FIXME :  is this a lower case character?
 ;       BL  accept_char                     ;
 ;       LDN R9                              ;
 ;       SMI $7B                             ;
 ;       BGE accept_char                     ;
 ;       LDN R9                              ; FIXME :  convert to  upper case
 ;       ANI $DF                             ;
 ;       STR R9                              ;

accept_char:                                ;
        DEC R9                              ;
        LDI $00                             ;
        STR R9                              ;
                                            ; check space left in input buffer
        LDA R8                              ; load D with optr and set R8 -> iptr
        SM                                  ; check rx buffer space     D = optr - iptr = free space
        SMI XON_LIMIT                       ; $D0   ; $F0  ?      ; check if there is more than 208 bytes free in the buffer
        LBNF TASKER                         ; done if not - no need to check for if an XON is needed yet
                                            ;
        LDI high xonxoff+DELTA              ; otherwise check if we need to send an XON : rx buffer has enough space to re-enable receiving data
        PHI R8                              ;
        LDI low xonxoff+DELTA               ;
        PLO R8                              ;
        LDN R8                              ; XON already sent?
        LBZ TASKER                          ; skip out if so
                                            ;
        SEX R8                              ;
        LDI high tx_iptr+DELTA              ; R8 -> tx buffer insert pointer
        PHI R8                              ;
        LDI low tx_iptr+DELTA               ;
        PLO R8                              ;
        LDI high tx_buffer                  ; R7 -> tx buffer previous character location
        PHI R7                              ;
        LDA R8                              ; R8 moves to -> tx_optr via LDA - order matters
        ADI $01                             ; advance tx_iptr and wrap if necessary
        PLO R7                              ;
        SM                                  ; check if about to overrun tx buffer?
        LBZ TASKER                          ; don't try to send an XON if tx buffer is full
                                            ;
        LDI XON                             ;
        STR R7                              ; store XON char in tx buffer
        DEC R8                              ; update tx_iptr after saving tx character in buffer (i.e. ISR safe)
        GLO R7                              ;
        STR R8                              ;
                                            ;
        LDI high xonxoff+DELTA              ; clear xoff flag  (FIXME : interrupt safe ?)
        PHI R8                              ;
        LDI low xonxoff+DELTA               ;
        PLO R8                              ;
        LDI $00                             ;
        STR R8                              ;
                                            ;
        SEX R2                              ; check if UART currently transmitting and start if not
        DEC R2                              ;
        INP 5                               ;
        ANI $C0                             ;
        SMI $C0                             ; THRE * TSRE both set = UART not transmitting
        BNZ tx_active2                      ;
                                            ;
        LDI uart_config                     ; toggle TR off
        STR R2                              ;
        OUT 5                               ;
        DEC R2                              ;
        LDI uart_config+$80                 ; set TR bit in UART control register
        STR R2                              ;
        OUT 5                               ;
        SKP                                 ;
tx_active2:                                 ;
        INC R2                              ;
        LBR TASKER                          ; done

;********************************************************** 1854 UART ******
;
; Transmit the value in D out via the 1854 UART
;
;----------------------------------------------------------------------

CSEND:  DW $+2                            ;
        SEX R8                              ;
        LDI high tx_iptr+DELTA              ; R8 -> tx buffer insert pointer
        PHI R8                              ;
        LDI low tx_iptr+DELTA               ;
        PLO R8                              ;
        LDI high tx_buffer                  ; R7 -> tx buffer previous character location
        PHI R7                              ;
        LDA R8                              ; R8 moves to -> tx_optr via LDA - order matters
        ADI $01                             ; advance tx_iptr and wrap if necessary
        PLO R7                              ;
        SM                                  ; check if about to overrun tx buffer?
        LBZ tsk_repeat                      ; busy outer interpreter loop until ISR moves the tx_optr
                                            ;
        INC R9                              ; pop tx char from computation stack
        LDN R9                              ;
        DEC R9                              ; and cleanup computation stack
        DEC R9                              ;
        DEC R9                              ;
        STR R7                              ; store char in tx buffer
        DEC R8                              ; update tx_iptr after saving tx character in buffer (i.e. ISR safe)
        GLO R7                              ;
        STR R8                              ;
                                            ;
        SEX R2                              ; check if UART currently transmitting and start if not
        DEC R2                              ;
        INP 5                               ;
        ANI $C0                             ;
        SMI $C0                             ; THRE * TSRE both set = UART not transmitting
        BNZ tx_active1                      ;

        LDI uart_config                     ; toggle TR off
        STR R2                              ;
        OUT 5                               ;
        DEC R2                              ;
        LDI uart_config+$80                 ; set TR bit in UART control register
        STR R2                              ;
        OUT 5                               ;
        SKP                                 ;

tx_active1:                                 ;
        INC R2                              ;
        LBR TASKER                          ; done
        
        ;=================================================================
        ;
        ; ?TERMINAL support

qTERM:                                      ;
        SEX R8                              ;
        INC R9                              ; prep data stack pointer
        INC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        INC R9                              ;
        LDI high rx_optr+DELTA              ; R8  -> rx_optr  (Note: order of optr & iptr matters)
        PHI R8                              ;
        LDI low rx_optr+DELTA               ;
        PLO R8                              ;
        LDA R8                              ; get rx_optr  and advance R8 to rx_iptr
        SM                                  ; compare rx_optr to rx_iptr.  Zero if equal so no rx chars available
        STR R9                              ; save # of chars on stack ( 0 = false = not data )
        DEC R9                              ;
        LBR TASKER                          ; all done if buffer not empty

 endi

 PAGE
        DB $AA                              ; Warning - a one byte pad to make sure ISR address does not start at page bountry (membership card code needs that)
        
 if (uart_type = hardware)

;========================================================================================================ISR
;               ACE CPU CARD ISR
;========================================================================================================

        RET                                 ; return from interrupt
ISRentry:                                   ; use this address for R1 after a program load or reset
ISR:                                        ; label for usual value in R1 while waiting for the next interrupt
        DEC R2                              ; move down to first free byte
        SAV                                 ; save PC and SP registers in use
        DEC R2                              ;
        STXD                                ; save D accumulator
        SHRC                                ;
        STXD                                ; save DF
        GHI R7                              ; save R7
        STXD                                ;
        GLO R7                              ;
        STXD                                ;
        GHI R8                              ; save R8
        STXD                                ;
        GLO R8                              ;
        STXD                                ;

check_uart_status:                          ;
        INP 5                               ; read UART status register
        ANI $0E                             ; check error bits
        BZ  no_errors                       ;
        LDI high uart_errors+DELTA          ; R8 -> uart error counters
        PHI R8                              ;
        LDI low uart_errors+DELTA           ;
        PLO R8                              ;
        LDX                                 ;
        ANI $02                             ; overrun error ?
        BZ not_OE                           ;
        LDN R8                              ;
        ADI $01                             ;
        BZ not_OE                           ;
        STR R8                              ;
not_OE: INC R8                              ;
        LDX                                 ;
        ANI $04                             ; parity error ?
        BZ not_PR                           ;
        LDN R8                              ;
        ADI $01                             ;
        BZ not_PR                           ;
        STR R8                              ;
not_PR: INC R8                              ;
        LDX                                 ;
        ANI $08                             ; framing error ?
        BZ not_FE                           ;
        LDN R8                              ;
        ADI $01                             ;
        BZ not_FE                           ;
        STR R8                              ;
not_FE:                                     ;

no_errors:                                  ;
        LDX                                 ; pull UART status register value saved on entry
        SHR                                 ; bits : 7=THRE  6=TSRE 5=PSI 4=ES 3=FE 2=PE = 1=OE 0=DA
        BNF no_rx_data                      ; DA bit = 0 (data available)


; process next character from UART RX data register to rx buffer

get_rx_char:                                ;
        INP 6                               ; grab the character right away and keep on the R0 stack
        LDI high rx_iptr+DELTA              ; R8 -> rx buffer insert pointer
        PHI R8                              ;
        LDI low rx_iptr+DELTA               ;
        PLO R8                              ;
        LDI high rx_buffer                  ; R7 = ++(buffer insert pointer)
        PHI R7                              ;
        LDN R8                              ;
        ADI $01                             ; advance buffer insert pointer and wrap if necessary
        PLO R7                              ;
        STR R8                              ; save rx buffer insert pointer for next time
        LDI low rx_optr+DELTA               ; R8 -> rx buffer output pointer
        PLO R8                              ;
        GLO R7                              ; check if rx buffer near threshold
        SEX R8                              ; SP -> rx_optr
        SM                                  ; check rx buffer space   ( D = iptr - optr = used space )
        SMI XOFF_LIMIT                      ; send XOFF when buffer space used exceeds 208 bytes
        BNF rx_buffer_okay                  ;
        LDI low xonxoff+DELTA               ;
        PLO R8                              ;
        LDN R8                              ; have we sent XOFF yet?
        BNZ rx_buffer_okay                  ; don't send again if so
        SEX R7                              ; SP -> rx input buffer
xoff_wait:                                  ; check if TX holding register empty
        INP 5                               ;
        SHR                                 ; is there an received character waiting ?
        BDF rx_buffer_okay                  ; skip xoff for now because the next RX char is ready
        SHL                                 ;
        SHL                                 ;
        BNF xoff_wait                       ; loop until TX holding register empty
        LDI XOFF                            ; transmit an XOFF character
        STR R7                              ;
        OUT 6                               ;
        DEC R7                              ;
        LDI $01                             ; set flag to indicate XOFF sent
        STR R8                              ;
rx_buffer_okay:                             ; read data byte to rx buffer
        SEX R2                              ; save the Rx'd byte in the rx buffer slot
        LDX                                 ;
        STR R7                              ;
                                            ; fall through to check for tx needed or RTC interrupt

no_rx_data:                                 ;
        LDX                                 ; get UART status register value again
        SHL                                 ;
        BNF tic_timer

; if available send next character from tx buffer to UART TX data register

send_next_tx_char:                          ;
        LDI high tx_optr+DELTA              ; R8  -> tx output buffer pointer
        PHI R8                              ;
        LDI low tx_optr+DELTA               ;
        PLO R8                              ;
        LDI high tx_iptr+DELTA              ; R7  -> tx insert buffer pointer
        PHI R7                              ;
        LDI low tx_iptr+DELTA               ;
        PLO R7                              ;
        LDN R8                              ; D = tx insert buffer pointer
        SEX R7                              ;
        SM                                  ; check if tx buffer empty ( inptr = outptr )
        SEX R2                              ;
        BZ tic_timer                                ;
        LDN R8                              ; advance output pointer to next character to send (implicit wrap)
        ADI $01                             ;
        STR R8                              ;
        PLO R7                              ;
        LDI high tx_buffer                  ;
        PHI R7                              ;
        SEX R7                              ;
        OUT 6                               ; write data byte to tx buffer
        SEX R2                              ; and go check for interrupt from RTC

tic_timer:                                  ;
        LDX                                 ; get UART status register value again
        SHL                                 ;
        SHL                                 ;
        SHL                                 ;
        BNF isr_done                        ; all done if external interrupt not set (RTC tic timer interrupt)
                                            ;

; tic timer interrupt - update task timers and restart tasks if necessary

        LDI $0C                             ; push $0C onto stack
        STR R2                              ;
        OUT 1                               ; send to port 1 RTC register select
        DEC R2                              ;
        INP 2                               ; read back port 2 RTC data register C to clear interrupt
        LDI high TL7+DELTA                  ; R7 -> task control blocks
        PHI R7                              ;
        LDI low TL7+DELTA                   ;
        PLO R7                              ;
        LDI high TIMERS+7+DELTA             ; R7 -> task control blocks
        PHI R8                              ;
        LDI low TIMERS+7+DELTA              ;
        PLO R8                              ;
check_timer:                                ;
        LDN R8                              ; get next timer
        BZ  next_timer                      ; jump its not running
        SMI $01                             ; decrement timer
        STR R8                              ; save new value
        BNZ next_timer                      ; jump if stil not zero
        LDI $D3                             ; else push $D3 to RAM buffer to activate task as timer has expired
        STR R7                              ;
next_timer:                                 ;
        DEC R7                              ; back up task list
        DEC R7                              ;
        DEC R8                              ; next timer byte
        GLO R8                              ; check if pointer back past start of table
        SMI low TIMERS+DELTA-1              ;
        BNZ check_timer                     ; loop back if not at end of buffer

; interrupt service complete - cleanup, re-enable interrupts, and exit

isr_done:                                   ; clean up and return
        IRX                                 ;
        LDXA                                ; restore R8
        PLO R8                              ;
        LDXA                                ;
        PHI R8                              ;
        LDXA                                ; restore R7
        PLO R7                              ;
        LDXA                                ;
        PHI R7                              ;
        LDXA                                ; restore DF
        SHL                                 ;
        LDXA                                ; restore D
        BR  ISRentry-1                      ; loop back to return from interrupt

 endi


 if (uart_type = software) and (timer_type = software)

;========================================================================================================ISR
;               NO INTERRUPT SOURCE ISR
;========================================================================================================

    DIS                                     ; disable interrupts and return
ISRentry:                                   ; ISR : does nothing but return with interrupts re-enabled
ISR:                                        ; label for usual value in R1 while waiting for the next interrupt
    DEC R2                                  ;
    SAV                                     ;
                                            ; WARNING :  hardware specific to Membership Cards
    DEC R2                                  ; trap interrupt and flag on LED's
    STR R2                                  ;
    DEC R2                                  ;
    LDI $AA                                 ;
    STR R2                                  ;
    OUT 4                                   ;
    LDA R2                                  ;
                                            ;
    BR ISRentry-1                           ;

 endi

 if (uart_type = software) and (timer_type = hardware)

;========================================================================================================ISR
;               MEMBERSHIP CARD CARD ISR
;========================================================================================================

ISRentry:                                   ; use this address for R1 after a program load or reset
        BN2 $                                ; wait for a digit 6 signal on EF2 so that we are sync'd the first time
        SKP                                 ; hop over the RET
ISRRET: RET                                 ; usual 1802 return route, sets current PC=R1 to next instruction
ISR:    DEC R2                              ; R1 is left pointing here so this is the normal entry point to the ISR
        SAV                                 ; push T state (old X and P) for RET to restore
        DEC R2                              ;
        STXD                                ; push whatever was in D
        SHRC                                ;
        STXD                                ; save DF
        GHI R7                              ; push R7
        STXD                                ;
        GLO R7                              ;
        STXD                                ;
        GHI R8                              ; push R8
        STXD                                ;
        GLO R8                              ;
        STXD                                ;
        LDI high LED_BUF_POINTER+DELTA      ; R7 -> address current digit to display
        PHI R7                              ;
        LDI low LED_BUF_POINTER+DELTA       ;
        PLO R7                              ;
        LDN R7                              ; get index into digit buffer
        PLO R7                              ;
        LDN R7                              ; load byte to display
        STR R2                              ;
        OUT 4                               ; output to display (leave R2 pointing to stored value of R7.0)
        LDI low LED_BUF_POINTER+DELTA       ;
        PLO R7                              ;
        B2  NOT_DG6                         ; jump if this is not digit 6
        LDI low LED_BUFFER+DELTA            ;
        BR DG_SAVE                          ;
NOT_DG6:                                    ;
        LDN R7                              ;
        ADI $01                             ;
DG_SAVE:                                    ;
        STR R7                              ;
        LDI high TIC_SCALER+DELTA           ;
        PHI R7                              ;
        LDI low TIC_SCALER+DELTA            ;
        PLO R7                              ;
        LDN R7                              ;
        SMI $01                             ;
        STR R7                              ;
        BZ TIC_UPDATE                       ;
        NOP                                 ; hang loose for some CPU clock time. Calibrate
        NOP                                 ; .. relative to the length of the interrupt signal
        NOP                                 ; ...to avoid double interrupts.
        NOP                                 ;
        NOP                                 ;
        NOP                                 ;
        NOP                                 ;
        NOP                                 ;
        NOP                                 ;
        NOP                                 ;
        NOP                                 ;
        BR ISR_EXIT                         ;

;  Mulitasker Tic Value Update

TIC_UPDATE:
        LDI tic_scaler_preset_value         ; reset tic prescaler
        STR R7                              ;
        LDI high TL7+DELTA                  ; R7 -> task control blocks
        PHI R7                              ;
        LDI low TL7+DELTA                   ;
        PLO R7                              ;
        LDI high TIMERS+7+DELTA             ; R7 -> task control blocks
        PHI R8                              ;
        LDI low TIMERS+7+DELTA              ;
        PLO R8                              ;
check_timer:                                ;
        LDN R8                              ; get next timer
        BZ  next_timer                      ; jump its not running
        SMI $01                             ; decrement timer
        STR R8                              ; save new value
        BNZ next_timer                      ; jump if stil not zero
        LDI $D3                             ; else push $D3 to RAM buffer to activate task as timer has expired
        STR R7                              ;
next_timer:                                 ;
        DEC R7                              ; back up task list
        DEC R7                              ;
        DEC R8                              ; next timer byte
        GLO R8                              ; check if pointer back past start of table
        SMI low TIMERS+DELTA-1              ;
        BNZ check_timer                     ; loop back if not at end of buffer
ISR_EXIT:                                   ;
        LDXA                                ; restore R7 and R8 from stack
        PLO R8                              ;
        LDXA                                ;
        PHI R8                              ;
        LDXA                                ;
        PLO R7                              ;
        LDXA                                ;
        PHI R7                              ;
        LDXA                                ; restore DF
        SHL                                 ;
        LDXA                                ; restore D and clean up stack
        BR ISRRET                           ;

 endi
 
;**********************************************************************************************************************************
;********************************************  Hardware Customization Section Ends Here********************************************
;**********************************************************************************************************************************



 PAGE
;=====================================================================================================
;
;  FORTH standard vocabulary words written mostly in assembler
;
;=====================================================================================================

        ; **-----------------------------------------------------------------------------
        DB $83,"LI",$D4                     ; LIT
        DW $0000                            ; (empty pointer means first word in dictionary)
LIT:    DW $+2                            ;
        INC R9                              ;
        INC R9                              ;
        LDA RA                              ;
        STR R9                              ;
        INC R9                              ;
        LDA RA                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        SEP R3                              ; NEXT inner interpreter
NEXT:   LDA RA                              ;
        PHI RB                              ;
        LDA RA                              ;
        PLO RB                              ;
WBR:    LDA RB                              ;
        PHI R3                              ;
        LDA RB                              ;
        PLO R3                              ;
        BR NEXT - 1                         ;

        ; **-----------------------------------------------------------------------------
        DB $87,"EXECUT",$C5                 ; EXECUTE
        DW LIT - 6                          ;
EXECUTE: DW $+2                           ;
        LDA R9                              ;
        PHI RB                              ;
        LDN R9                              ; load W from stack
        PLO RB                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;

        LDI low WBR                         ; Warning : speed optimization but maybe breaks if WBR crosses a page boundary
;        INC RC                             ; point to WBR:   <-- this old code is safer but slower
;        INC RC                             ;
;        INC RC                             ;
;        INC RC                             ;

        PLO RC                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"(+LOOP",$A9                 ; (+LOOP)
        DW EXECUTE - 10                     ;
bpLOOPr: DW $+2                           ;
        GHI R2                              ;
        PHI R8                              ;
        PHI R7                              ;
        GLO R2                              ;
        PLO R8                              ;
        PLO R7                              ;
        INC R7                              ;
        INC R8                              ;
        SEX R9                              ;
        INC R9                              ;
        LDN R8                              ;
        ADD                                 ;
        STR R8                              ;
        INC R8                              ;
        DEC R9                              ;
        LDN R8                              ;
        ADC                                 ;
        STR R8                              ;
        LDN R9                              ;
        SHL                                 ;
        DEC R9                              ;
        DEC R9                              ;
        BNF LP1                             ;
        INC R8                              ;
        SEX R7                              ;
        LDA R8                              ;
        SM                                  ;
        INC R7                              ;
        LDN R8                              ;
        SMB                                 ;
        BR LP2                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $86,"(LOOP",$A9                  ; (LOOP)
        DW bpLOOPr - 10                     ;
bLOOPr: DW $+2                            ;
        GHI R2                              ;
        PHI R8                              ;
        PHI R7                              ;
        GLO R2                              ;
        PLO R8                              ;
        PLO R7                              ;
        INC R7                              ;
        INC R8                              ;
        LDN R8                              ;
        ADI $01                             ;
        STR R8                              ;
        INC R8                              ;
        LDN R8                              ;
        ADCI $00                            ;
        STR R8                              ;
LP1:    INC R8                              ;
        SEX R7                              ;
        LDA R8                              ;
        SD                                  ;
        INC R7                              ;
        LDN R8                              ;
        SDB                                 ;
LP2:    SHL                                 ;
        BNF LP3                             ;
        LDA RA                              ;
        STR R2                              ;
        LDN RA                              ;
        PLO RA                              ;
        LDN R2                              ;
        PHI RA                              ;
        SEP RC                              ;
LP3:    INC RA                              ;
        INC RA                              ;
        INC R2                              ;
        INC R2                              ;
        INC R2                              ;
        INC R2                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"(DO",$A9                    ; (DO)
        DW bLOOPr - 9                       ;
bDOr:   DW $+2                            ;
        DEC R9                              ;
        DEC R9                              ;
        SEX R2                              ;
        LDA R9                              ;
        STXD                                ;
        LDA R9                              ;
        STXD                                ;
        LDA R9                              ;
        STXD                                ;
        LDN R9                              ;
        STXD                                ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"DIGI",$D4                   ; DIGIT
        DW bDOr - 7                         ;
DIGIT:  DW $+2                            ;
        SEX R9                              ;
        DEC R9                              ;
        LDN R9                              ;
        SMI $30                             ;
        BNF DBAD                            ;
        SMI $11                             ;
        BDF DOK1                            ;
        SMI $F9                             ;
        BDF DBAD                            ;
DOK1:   ADI $0A                             ;
        STR R9                              ;
        INC R9                              ;
        INC R9                              ;
        SM                                  ;
        BDF DOK2                            ;
        LDI 01                              ;
        STXD                                ;
        LDI 00                              ;
        STR R9                              ;
        SEP RC                              ;
DOK2:   DEC R9                              ;
        DEC R9                              ;
DBAD:   LDI $00                             ;
        STXD                                ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"0BRANC",$C8                 ; 0BRANCH
        DW DIGIT - 8                   ;
zBRANCH: DW $+2                           ;
        SEX R9                              ;
        LDA R9                              ;
        OR                                  ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        BZ  BRCH1                           ;
        INC RA                              ;
        INC RA                              ;
        SEP RC                              ;
        
                ;
        ; **-----------------------------------------------------------------------------
        DB $86,"BRANC",$C8                  ; BRANCH
        DW zBRANCH - 10                     ;
BRANCH: DW $+2                            ;
BRCH1:  LDA RA                              ;
        STR R2                              ;
        LDA RA                              ;
        PLO RA                              ;
        LDN R2                              ;
        PHI RA                              ;
        SEP RC                              ;
        ;
        ;
        
        ; **-----------------------------------------------------------------------------
        DB $86,"(FIND",$A9                  ; (FIND)
        DW     BRANCH - 9                   ;  
bFINDr: DW $+2                            ;
        SEX     R7                          ;
        LDA     R9                          ;
        PHI     R7                          ;
        LDN     R9                          ;
        PLO     R7                          ;
        DEC     R9                          ;
        DEC     R9                          ;
F0065:  DEC     R9                          ;
        LDA     R9                          ;
        PHI     R8                          ;
        LDN     R9                          ;
        PLO     R8                          ;
        LDN     R7                          ;
        STR     R2                          ;
        LDA     R8                          ;
        XOR                                 ;
        ANI     $3F                         ;
        BNZ     F0094                       ;
F0072:  INC     R7                          ;
        LDA     R8                          ;
        XOR                                 ;
        SHL                                 ;
        BNZ     F0095                       ;
        BNF     F0072                       ;
        SEX     R9                          ;
        GLO     R7                          ;
        ADI     $05                         ;
        STXD                                ;
        GHI     R7                          ;
        ADCI    $00                         ;
        STR     R9                          ;
        INC     R9                          ;
        INC     R9                          ;
        LDI     $00                         ;
        STR     R9                          ;
        INC     R9                          ;
        LDN     R2                          ;
        STR     R9                          ;
        INC     R9                          ;
        LDI     $00                         ;
        STR     R9                          ;
        INC     R9                          ;
        LDI     $01                         ;
        STXD                                ;
        SEP     RC                          ;
F0094:  INC     R7                          ;
F0095:  LDA     R7                          ;
        SHL                                 ;
        BNF     F0095                       ;
        LDA     R7                          ;
        STR     R2                          ;
        OR                                  ;
        BNZ     F00A2                       ;
        STR     R9                          ;
        DEC     R9                          ;
        STR     R9                          ;
        SEP     RC                          ;
F00A2:  LDN     R7                          ;
        PLO     R7                          ;
        LDN     R2                          ;
        PHI     R7                          ;
        BR      F0065                       ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"ENCLOS",$C5                 ; ENCLOSURE
        DW bFINDr -9                        ;
ENCLOSURE: DW $+2                         ;
        DEC R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        PHI R8                              ;
        LDA R9                              ;
        PLO R8                              ;
        INC R9                              ;
        LDI $00                             ;
        PHI R7                              ;
        PLO R7                              ;
        LDN R9                              ;
        STR R2                              ;
        SEX R2                              ;
        LSKP                                ;
H00C3:  INC  R7                             ;
        INC R8                              ;
        LDN R8                              ;
        SM                                  ;
        BZ  H00C3                           ;
        DEC R9                              ;
        GHI R7                              ;
        STR R9                              ;
        INC R9                              ;
        GLO R7                              ;
        STR R9                              ;
        INC R9                              ;
        SMI $00                             ;
        LDN R8                              ;
        LSNZ                                ;
        SHR                                 ;
        INC R7                              ;
        LSKP                                ;
H00D7:  INC  R7                             ;
        INC R8                              ;
        LDN R8                              ;
        BZ  H00DF                           ;
        XOR                                 ;
        BNZ H00D7                           ;
H00DF:  GHI  R7                             ;
        STR R9                              ;
        INC R9                              ;
        GLO R7                              ;
        STR R9                              ;
        INC R9                              ;
        LDN R8                              ;
        LSNZ                                ;
        DEC R7                              ;
        LSNF                                ;
        INC R7                              ;
        NOP                                 ;
        GHI R7                              ;
        STR R9                              ;
        INC R9                              ;
        GLO R7                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ; ?? -----------------------------------------------------------------------------
        DB $83,"AN",$C4                     ; AND
        DW  ENCLOSURE - 10                  ;
FAND:   DW $+2                            ;
        GLO R9                              ;
        PLO R8                              ;
        GHI R9                              ;
        PHI R8                              ;
        INC R8                              ;
        DEC R9                              ;
        SEX R9                              ;
        LDN R8                              ;
        AND                                 ;
        STXD                                ;
        DEC R8                              ;
        LDN R8                              ;
        AND                                 ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; ?? -----------------------------------------------------------------------------
        DB $82,$4F,$D2                      ; OR
        DW FAND - 6                         ;
FFOR:   DW $+2                            ;
        GLO R9                              ;
        PLO R8                              ;
        GHI R9                              ;
        PHI R8                              ;
        DEC R9                              ;
        INC R8                              ;
        SEX R9                              ;
        LDN R8                              ;
        OR                                  ;
        STXD                                ;
        DEC R8                              ;
        LDN R8                              ;
        OR                                  ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ;  ?? -----------------------------------------------------------------------------
        DB $83,"XO",$D2                     ;  XOR
        DW FFOR - 5                         ;
FXOR:   DW $+2                            ;
        GLO R9                              ;
        PLO R8                              ;
        GHI R9                              ;
        PHI R8                              ;
        INC R8                              ;
        DEC R9                              ;
        SEX R9                              ;
        LDN R8                              ;
        XOR                                 ;
        STXD                                ;
        DEC R8                              ;
        LDN R8                              ;
        XOR                                 ;
        STR R9                              ;
        SEP RC                              ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"CMOV",$C5                   ; CMOVE
        DW FXOR - 6                         ;
CMOVE:  DW $+2                            ;
        LDA R9                              ;
        PHI R7                              ;
        LDN R9                              ;
        PLO R7                              ;
        DEC R7                              ;
        SEX R2                              ;
        GHI RA                              ;
        STXD                                ;
        GLO RA                              ;
        STXD                                ;
        DEC R9                              ;
        DEC R9                              ;
        LDN R9                              ;
        PLO RA                              ;
        STR R2                              ;
        DEC R9                              ;
        LDN R9                              ;
        PHI RA                              ;
        DEC R9                              ;
        LDN R9                              ;
        PLO R8                              ;
        SM                                  ;
        DEC R9                              ;
        LDN R9                              ;
        PHI R8                              ;
        STR R2                              ;
        GHI RA                              ;
        SDB                                 ;
        DEC R9                              ;
        DEC R9                              ;
        BNF R003D                           ;
        GHI R7                              ;
        ADI $01                             ;
        BZ  H005F                           ;
        PHI R7                              ;
R0034:  LDA R8                              ;
        STR RA                              ;
        INC RA                              ;
        DEC R7                              ;
        GHI R7                              ;
        BNZ R0034                           ;
        BR  H005F                           ;
R003D:  GLO  R7                             ;
        STR R2                              ;
        GLO RA                              ;
        ADD                                 ;
        PLO RA                              ;
        GHI R7                              ;
        STR R2                              ;
        GHI RA                              ;
        ADC                                 ;
        PHI RA                              ;
        GLO R7                              ;
        STR R2                              ;
        GLO R8                              ;
        ADD                                 ;
        PLO R8                              ;
        GHI R7                              ;
        STR R2                              ;
        GHI R8                              ;
        ADC                                 ;
        PHI R8                              ;
        GHI R7                              ;
        ADI $01                             ;
        BZ  H005F                           ;
        PHI R7                              ;
        SEX RA                              ;
H0058: LDN  R8                              ;
        STXD                                ;
        DEC R8                              ;
        DEC R7                              ;
        GHI R7                              ;
        BNZ H0058                           ;
H005F:  INC R2                              ;
        LDA R2                              ;
        PLO RA                              ;
        LDN R2                              ;
        PHI RA                              ;
        SEP RC                              ;
        
                

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$55,$AA                      ; U*
        DW  CMOVE - 8                       ;
Us:     DW $+2                            ; UNSIGNED 16 X 16 BIT MULTIPLY : 32 BIT PRODUCT
        SEX R9                              ;
        LDI $00                             ;
        PLO R7                              ; R7 IS LOW 2 BYTES
        PHI R7                              ;
        LDI $10                             ; OF PRODUCT
LP7B:   STR R2                              ; MEM(2) IS LOOP COUNT
        GLO R7                              ;
        SHL                                 ;
        PLO R7                              ;
        GHI R7                              ;
        SHLC                                ;
        PHI R7                              ;
        INC R9                              ; DOUBLE THE PRODUCT AND
        LDN R9                              ; TEST HIGH BIT
        SHLC                                ;
        STXD                                ;
        LDN R9                              ;   OF OP2
        SHLC                                ;
        STR R9                              ;
        BNF SKP9A                           ;
        DEC R9                              ;
        GLO R7                              ;
        ADD                                 ;
        PLO R7                              ;
        DEC R9                              ;   ADD OP1
        GHI R7                              ;
        ADC                                 ;
        PHI R7                              ;
        INC R9                              ; TO 24 BIT PRODUCT
        INC R9                              ;
        INC R9                              ;
        LDI $00                             ;
        ADC                                 ;
        STXD                                ;
SKP9A:  LDN R2                              ;
        SMI $01                             ;
        BNZ LP7B                            ;
UOUT:   DEC R9                              ; MOVE REST OF
        GLO R7                              ;
        STXD                                ;
        GHI R7                              ; PRODUCT TO STACK
        STR R9                              ;
        INC R9                              ;
        INC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$55,$AF                      ; U/ UNSIGNED DIVIDE
        DW Us - 5                           ;
Uh:  DW $+2                               ;
        SEX R9                              ;
        LDA R9                              ;
        OR                                  ;
        BZ  H00E4                           ; divide  by zero ?
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        PHI R7                              ;
        LDN R9                              ;
        PLO R7                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        SHL                                 ;
        INC R9                              ;
        STXD                                ;
        DEC R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        SHLC                                ;
        INC R9                              ;
        STR R9                              ;
        INC R9                              ;
        LDI $10                             ;
        PLO R8                              ;
H00C2:  GLO R7                              ;
        SHLC                                ;
        PLO R7                              ;
        GHI R7                              ;
        SHLC                                ;
        PHI R7                              ;
        INC R9                              ;
        INC R9                              ;
        GLO R7                              ;
        SM                                  ;
        PHI R8                              ;
        DEC R9                              ;
        GHI R7                              ;
        SMB                                 ;
        BNF H00D5                           ;
        PHI R7                              ;
        GHI R8                              ;
        PLO R7                              ;
H00D5:  DEC R9                              ;
        LDN R9                              ;
        SHLC                                ;
        STXD                                ;
        LDN R9                              ;
        SHLC                                ;
        STR R9                              ;
        INC R9                              ;
        DEC R8                              ;
        GLO R8                              ;
        BNZ H00C2                           ;
        DEC R9                              ;
        BR  UOUT                            ;
H00E4:  LDI 01EH                            ; divide by zero error #30
        STXD                                ;
        LDI 000H                            ;
        STR R9                              ;
        LDI high ERROR                      ;
        PHI RB                              ;
        LDI low ERROR                       ;
        PLO RB                              ;
        LDI low WBR                         ; RC= $xx75  skip the inner interpreter ahead a bit
        PLO RC                              ;
        SEP RC                              ;


        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"SP",$C0                     ; SP@
        DW Uh - 5                           ;
SPa:    DW $+2                            ;
        GHI R9                              ;
        STR R2                              ;
        GLO R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        STR R9                              ;
        DEC R9                              ;
        LDN R2                              ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"SP",$A1                     ; SP!  <- initialize data stack pointer
        DW SPa - 6                          ;
SP!:    DW $+2                            ;
        GLO RD                              ; RD -> USER area for initialized variables   ( UP )
        ADI $06                             ; hard coded offset into USER area to S0
        PLO R8                              ;
        GHI RD                              ;
        ADCI $00                            ;
        PHI R8                              ;
        LDA R8                              ; initialze R9 as the data stack pointer ( RP )
        PHI R9                              ;
        LDN R8                              ;
        PLO R9                              ;
        SEP RC                              ;

        ;
        ; **---------------------------- ------------------------------------------------
        DB $83,"RP",$A1                     ; RP!   <- intiialize return stack pointer
        DW SP! - 6                          ;
RP!:    DW $+2                            ;
RP1A:   GLO RD                              ; RD -> USER area for initialized variables   ( UP )
        ADI $08                             ; hard coded offset into USER area to R0
        PLO R8                              ;
        GHI RD                              ;
        ADCI $00                            ; NOTE: this is only necessary if RD is far enough to cross a page boundary - execution time hit that can be fixed page aligning R0
        PHI R8                              ;
        LDA R8                              ; initialze R2 as the return stack pointer  ( RP )
        PHI R2                              ;
        LDN R8                              ;
        PLO R2                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$3B,$D3                      ; ;S (unnest)
        DW RP! - 6                          ;
sS:     DW $+2                            ;
        INC R2                              ;
        LDA R2                              ;
        PLO RA                              ;
        LDN R2                              ;
        PHI RA                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"LEAV",$C5                   ; LEAVE
        DW sS - 5                           ;
LEAVE:  DW $+2                            ;
        GHI R2                              ;
        PHI R8                              ;
        GLO R2                              ;
        PLO R8                              ;
        INC R8                              ;
        LDA R8                              ;
        INC R8                              ;
        STR R8                              ;
        DEC R8                              ;
        LDA R8                              ;
        INC R8                              ;
        STR R8                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$3E,$D2                      ; >R
        DW LEAVE - 8                        ;
gR:     DW $+2                            ;
        SEX R2                              ;
        LDA R9                              ;
        STXD                                ;
        LDN R9                              ;
        STXD                                ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$52,$BE                      ; R>
        DW gR - 5                           ;
Rg:     DW $+2                            ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R2                              ;
        LDA R2                              ;
        STR R9                              ;
        DEC R9                              ;
        LDN R2                              ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DW $81D2                            ; R
        DW Rg - 5                           ;
R:      DW $+2                            ;
        GLO R2                              ;
        PLO R8                              ;
        GHI R2                              ;
        PHI R8                              ;
        INC R8                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        LDA R8                              ;
        STR R9                              ;
        DEC R9                              ;
        LDN R8                              ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$30,$BD                      ; 0=
        DW R - 4                            ;
ze:     DW $+2                            ;
        SEX R9                              ;
        LDA R9                              ;
        OR                                  ;
        BNZ NONE                            ;
ZONE:   LDI 01                              ;
        BR STOR                             ;
NONE:   LDI 00                              ;
STOR:   STXD                                ;
        LDI 00                              ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$30,$BC                      ;  0<
        DW ze - 5                           ;
zl:     DW $+2                            ;
        SEX R9                              ;
        LDA R9                              ;
        SHL                                 ;
        BDF ZONE                            ;
        BR NONE                             ;

        ;
        ; **-----------------------------------------------------------------------------
        DW $81AB                            ;  +
        DW zl - 5                           ;
p:      DW $+2                            ;
        GLO R9                              ;
        PLO R8                              ;
        GHI R9                              ;
        PHI R8                              ;
        INC R8                              ;
        DEC R9                              ;
        SEX R9                              ;
        LDN R8                              ;
        ADD                                 ;
        STXD                                ;
        DEC R8                              ;
        LDN R8                              ;
        ADC                                 ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"MINU",$D3                   ; MINUS
        DW p - 4                            ;
MINUS:  DW $+2                            ;
        SEX R9                              ;
        INC R9                              ;
        LDN R9                              ;
        SDI $00                             ;
        STXD                                ;
        LDN R9                              ;
        SDBI $00                            ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$44,$AB                      ;  D+
        DW MINUS - 8                        ;
Dp:     DW $+2                            ;
        GLO R9                              ;
        PLO R8                              ;
        SMI $05                             ;
        PLO R9                              ;
        GHI R9                              ;
        PHI R8                              ;
        SMBI $00                            ;
        PHI R9                              ;
        DEC R8                              ;
        SEX R9                              ;
        LDN R8                              ;
        ADD                                 ;
        STXD                                ;
        DEC R8                              ;
        LDN R8                              ;
        ADC                                 ;
        STR R9                              ;
        INC R8                              ;
        INC R8                              ;
        INC R8                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        LDN R8                              ;
        ADC                                 ;
        STXD                                ;
        DEC R8                              ;
        LDN R8                              ;
        ADC                                 ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $86,"DMINU",$D3                  ; DMINUS
        DW Dp - 5                           ;
DMINUS: DW $+2                            ;
        SEX R9                              ;
        DEC R9                              ;
        LDN R9                              ;
        SDI $00                             ;
        STXD                                ;
        LDN R9                              ;
        SDBI 00                             ;
        STR R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        LDN R9                              ;
        SDBI 00                             ;
        STXD                                ;
        LDN R9                              ;
        SDBI 00                             ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"OVE",$D2                    ; OVER
        DW DMINUS - 9                       ;
OVER:   DW $+2                            ;
        GLO R9                              ;
        PLO R8                              ;
        GHI R9                              ;
        PHI R8                              ;
        DEC R8                              ;
        DEC R8                              ;
        INC R9                              ;
        INC R9                              ;
        LDA R8                              ;
        STR R9                              ;
        INC R9                              ;
        LDN R8                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"DRO",$D0                    ; DROP
        DW OVER - 7                         ;
DROP:   DW POP                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"SWA",$D0                    ; SWAP
        DW DROP - 7                         ;
SWAP:   DW $+2                            ;
        GLO R9                              ;
        PLO R8                              ;
        GHI R9                              ;
        PHI R8                              ;
        DEC R8                              ;
        LDN R8                              ;
        STR R2                              ;
        INC R9                              ;
        LDN R9                              ;
        STR R8                              ;
        LDN R2                              ;
        STR R9                              ;
        DEC R9                              ;
        DEC R8                              ;
        LDN R8                              ;
        STR R2                              ;
        LDN R9                              ;
        STR R8                              ;
        LDN R2                              ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"DU",$D0                     ; DUP
        DW SWAP - 7                         ;
DUP:    DW $+2                            ;
        LDA R9                              ;
        INC R9                              ;
        STR R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        INC R9                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"PIC",$CB                    ; PICK
        DW DUP - 6                          ;
PICK:   DW $+2                            ;
        SEX R9                              ;
        INC R9                              ;
        LDN R9                              ;
        SHL                                 ;
        PLO R8                              ;
        DEC R9                              ;
        LDN R9                              ;
        SHLC                                ;
        PHI R8                              ;
        GLO R9                              ;
        STR R9                              ;
        GLO R8                              ;
        SD                                  ;
        PLO R8                              ;
        GHI R9                              ;
        STR R9                              ;
        GHI R8                              ;
        SDB                                 ;
        PHI R8                              ;
        LDA R8                              ;
        STR R9                              ;
        INC R9                              ;
        LDA R8                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$2B,$A1                      ; +!
        DW PICK - 7                         ;
p!:     DW $+2                            ;
        LDA R9                              ;
        PHI R8                              ;
        LDN R9                              ;
        PLO R8                              ;
        DEC R9                              ;
        DEC R9                              ;
        INC R8                              ;
        SEX R8                              ;
        LDN R9                              ;
        ADD                                 ;
        STXD                                ;
        DEC R9                              ;
        LDN R9                              ;
        ADC                                 ;
        STR R8                              ;
POP:    DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $86,"TOGGL",$C5                  ; TOGGLE
        DW p! - 5                           ;
TOGGLE: DW $+2                            ;
        INC R9                              ;
        LDN R9                              ;
        PLO R7                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDN R9                              ;
        PLO R8                              ;
        DEC R9                              ;
        LDN R9                              ;
        PHI R8                              ;
        SEX R8                              ;
        GLO R7                              ;
        XOR                                 ;
        STR R8                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;**-----------------------------------------------------------------------------
        DW $81C0                            ; @
        DW TOGGLE - 9                       ;
a:      DW $+2                            ;
        LDA R9                              ;
        PHI R8                              ;
        LDN R9                              ;
        PLO R8                              ;
        DEC R9                              ;
        LDA R8                              ;
        STR R9                              ;
        INC R9                              ;
        LDN R8                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$43,$C0                      ; C@
        DW a - 4                            ;
Ca:     DW $+2                            ;
        LDA R9                              ;
        PHI R8                              ;
        LDN R9                              ;
        PLO R8                              ;
        LDN R8                              ;
        STR R9                              ;
        DEC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DW $81A1                            ; !  store
        DW Ca - 5                           ;
!:      DW $+2                            ;
        LDA R9                              ;
        PHI R8                              ;
        LDN R9                              ;
        PLO R8                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        STR R8                              ;
        INC R8                              ;
        LDN R9                              ;
        STR R8                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$43,$A1                      ; C!   char store
        DW ! - 4                            ;
C!:     DW $+2                            ;
        LDA R9                              ;
        PHI R8                              ;
        LDN R9                              ;
        PLO R8                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDN R9                              ;
        STR R8                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DW $81C9                            ; I
        DW C! - 5                           ;
I:      DW $+2                            ;
        GLO R2                              ;
        PLO R8                              ;
        GHI R2                              ; set R8 = return stack pointer
        PHI R8                              ;
        INC R8                              ; move to loop index
        INC R9                              ; move data stack pointer to next free word
        INC R9                              ;
        INC R9                              ;
        LDA R8                              ; get the value on the return stack
        STR R9                              ; save on the data stack
        DEC R9                              ;
        LDN R8                              ;
        STR R9                              ;
        SEP RC                              ; done

        ;
        ; **-----------------------------------------------------------------------------
        DW $81CA                            ; J : copy the next outer loop index onto the parameter stack
        DW I - 4                            ;
J:      DW $+2                            ;
        GLO R2                              ;
        PLO R8                              ;
        GHI R2                              ; set R8 = return stack pointer
        PHI R8                              ;
        INC R8                              ; move to next loop index
        INC R8                              ;
        INC R8                              ;
        INC R8                              ;
        INC R8                              ;
        INC R9                              ; move data stack pointer to next free word
        INC R9                              ;
        INC R9                              ;
        LDA R8                              ; get the value on the return stack
        STR R9                              ; save on the data stack
        DEC R9                              ;
        LDN R8                              ;
        STR R9                              ;
        SEP RC                              ; done

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"S->",$C4                    ; S->D
        DW J - 4                            ;
SmgD:   DW $+2                            ;
        LDA R9                              ;
        SHL                                 ;
        BDF SNEG                            ;
        LDI $00                             ;
        BR SSKP                             ;
SNEG:   LDI $FF                             ;
SSKP:   INC R9                              ;
        STR R9                              ;
        INC R9                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
         DW $81AD                           ; - (minus sign - subtract top two things on data stack)
         DW SmgD - 7                        ;
m:       DW $+2                           ;
         GLO R9                             ;
         PLO R8                             ;
         GHI R9                             ;
         PHI R8                             ;
         SEX R9                             ;
         DEC R9                             ;
         INC R8                             ;
         LDN R8                             ;
         SD                                 ;
         STXD                               ;
         DEC R8                             ;
         LDN R8                             ;
         SDB                                ;
         STR R9                             ;
         SEP RC                             ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"FIL",$CC                    ; FILL   FILL MEMORY
        DW m - 4                            ;
FILL:   DW $+2                            ;
        INC R9                              ;
        LDN R9                              ;
        STR R2                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDN R9                              ;
        PLO R7                              ;
        DEC R9                              ;
        LDN R9                              ;
        ADI 01                              ;
        PHI R7                              ;
        DEC R9                              ;
        LDN R9                              ;
        PLO R8                              ;
        DEC R9                              ;
        LDN R9                              ;
        PHI R8                              ;
        DEC R9                              ;
        DEC R9                              ;
FILL1:  DEC R7                              ;
        GHI R7                              ;
        BZ  FILL2                           ;
        LDN R2                              ;
        STR R8                              ;
        INC R8                              ;
        BR  FILL1                           ;
FILL2:  SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------
        DW $81BC                            ; < (LESS THAN SIGN)
        DW FILL  - 7                        ;
LESS:   DW $+2                            ;
        SEX R9                              ;
        LDN R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SHL                                 ;
        LDA R9                              ;
        BNF LESS1                           ;
        SHL                                 ;
        BDF LESS2                           ;
LESS0:  LDI 00                              ;
        STXD                                ;
        STR R9                              ;
        SEP RC                              ;
LESS1:  SHL                                 ;
        BDF LESS3                           ;
LESS2:  LDA R9                              ;
        INC R9                              ;
        SM                                  ;
        DEC R9                              ;
        LDN R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SDB                                 ;
        SHL                                 ;
        INC R9                              ;
        BNF LESS0                           ;
LESS3:  LDI 01                              ;
        STXD                                ;
        LDI 00                              ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------                                      ;
        DB $82,"G",$CF                      ; GO    ( addr -- )  - transfer execution to addr with R0 as PC
        DW LESS - 4                         ;
GO:     DW $+2                            ;
        LDA R9                              ;
        PHI R0                              ;
        LDN R9                              ;
        PLO R0                              ;
        SEX R0                                  ;
        SEP R0                                  ;

;  -----------------------------------------------------------------------------
                                            ; 1802 HARDWARE SPECIFIC WORDS
;  -----------------------------------------------------------------------------

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"?E",$C6                     ; ?EF    ( -- 0x0? )  bits 3-0 = EF4 to EF1 status
        DW GO - 5                           ;
qEF:    DW $+2                            ;
        INC R9                              ;
        INC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        INC R9                              ;
        BN1 QEF2                            ;
        ADI $01                             ;
QEF2:   BN2 QEF3                            ;
        ADI $02                             ;
QEF3:   BN3 QEF4                            ;
        ADI $04                             ;
QEF4:   BN4 QEF5                            ;
        ADI $08                             ;
QEF5:   STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"IN",$D0                     ; INP  ( port# -- data )
        DW qEF-6                            ;
INP:    DW $+2                            ;
        SEX R9                              ;
        INC R9                              ;
        LDN R9                              ; safety check the port #
        ANI $07                             ;
        BNZ inp0                            ;
        ADI $01                             ;
inp0:   STR R9                              ;
inp1:   GLO R3                              ;
        ADD                                 ;
        ADD                                 ;
        ADI inp2 - inp1 - 3                 ;
        PLO R3                              ;
inp2:   INP 1                               ;
        SKP                                 ;
        INP 2                               ;
        SKP                                 ;
        INP 3                               ;
        SKP                                 ;
        INP 4                               ;
        SKP                                 ;
        INP 5                               ;
        SKP                                 ;
        INP 6                               ;
        SKP                                 ;
        INP 7                               ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"OUT",$D0                     ; OUTP  ( data port# --  )
        DW INP-6                            ;
OUTP:   DW $+2                            ;
        SEX R9                              ;
        INC R9                              ;
        LDN R9                              ; safety check the port #
        ANI $07                             ;
        BNZ outp0                            ;
        ADI $01                             ;
outp0:  STR R9                              ;
outp1:  GLO R3                              ;
        ADD                                 ;
        ADD                                 ;
        ADI outp2 - outp1 - 3               ;
        DEC R9
        DEC R9
        PLO R3                              ;
outp2:  OUT 1                               ;
        SKP                                 ;
        OUT 2                               ;
        SKP                                 ;
        OUT 3                               ;
        SKP                                 ;
        OUT 4                               ;
        SKP                                 ;
        OUT 5                               ;
        SKP                                 ;
        OUT 6                               ;
        SKP                                 ;
        OUT 7                               ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"QO",$CE                     ; QON
        DW OUTP-7                            ;
QON:    DW $+2                            ;
        SEQ                                 ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"QOF",$C6                    ; QOFF
        DW QON-6                            ;
QOFF:   DW $+2                            ;
        REQ                                 ;
        SEP RC                              ;

;=====================================================================================================

;  FORTH internal execution code

;=====================================================================================================

        ; **-----------------------------------------------------------------------------

NEST:   SEX R2                              ; execution code for outer interpreter
        GHI RA                              ;
        STXD                                ;
        GLO RA                              ;
        STXD                                ;
        GHI RB                              ;
        PHI RA                              ;
        GLO RB                              ;
        PLO RA                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------

VAR:    INC R9                              ; execution code for VARIABLE words
        INC R9                              ;
        GHI RB                              ;
        STR R9                              ;
        INC R9                              ;
        GLO RB                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------

CONST:  INC R9                              ; execution code for CONSTANT words
        INC R9                              ;
        LDA RB                              ;
        STR R9                              ;
        INC R9                              ;
        LDA RB                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ; **-----------------------------------------------------------------------------

USER:   INC R9                              ; execution code for USER variables
        INC R9                              ;
        SEX R9                              ;
        LDA RB                              ;
        STR R9                              ;
        INC R9                              ;
        LDA RB                              ;
        STR R9                              ;
        GLO RD                              ;
        ADD                                 ;
        STXD                                ;
        GHI RD                              ;
        ADC                                 ;
        STR R9                              ;
        SEP RC                              ;


        ;==================================================================================
        ; CONSTANTS
        ;==================================================================================
        ;
        ;  -----------------------------------------------------------------------------
        DW $81B0                            ; 0
        DW  QOFF-7                          ;
z:      DW CONST                            ;
        DW $0000                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DW $81B1                            ; 1
        DW z - 4                            ;
o:      DW CONST                            ;
        DW $0001                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DW $81B2                            ; 2
        DW o - 4                            ;
d:      DW CONST                            ;
        DW $0002                            ;
        ;
        ;  -----------------------------------------------------------------------------
        DW $81B3                            ; 3
        DW d - 4                            ;
x:      DW CONST                            ;
        DW $0003                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$42,$CC                      ; BL  CONSTANT ASCII BLANK
        DW x - 4                            ;
BL:     DW CONST                            ;
        DW $0020                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,$43,$2F,$CC                  ; C/L
        DW BL - 5                           ;
ChL:    DW CONST                            ;
        DW $0040                            ; 64 (DECIMAL)
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"FIRS",$D4                   ; FIRST
        DW ChL - 6                          ;
FIRST:  DW CONST                            ;
        DW FIRSTB                           ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"LIMI",$D4                   ; LIMIT
        DW FIRST - 8                        ;
LIMIT:  DW CONST                            ;
        DW LIMITB                           ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"B/BU",$C6                   ; B/BUF
        DW LIMIT - 8                        ;
BhBUF:  DW CONST                            ;
        DW $0400                            ; 1024 BYTES/BUFFER
        ;
        ;  **-----------------------------------------------------------------------------
        DB $85,"B/SC",$D2                   ; B/SCR
        DW BhBUF - 8                        ;
BhSCR:  DW CONST                            ;
        DW $0001                            ;
        ;
        ;  ??-----------------------------------------------------------------------------
        DB $86,"ORIGI",$CE                  ; ORIGIN
        DW BhSCR - 8                        ;
xORIGIN: DW CONST                           ;
        DW ORIGIN                           ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"+ORIGI",$CE                 ; +ORIGIN
        DW xORIGIN - 9                      ;
pORIGIN: DW NEST                            ;
        DW xORIGIN                          ;
        DW p                                ;
        DW sS                               ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"ERR",$D3                    ; ERRS
        DW pORIGIN - 10                     ;
ERRS:   DW CONST                            ;
        DW uart_errors + DELTA              ;

        ;===========================================================================================
        ; USER VARIABLES - offsets are hard coded assuming the ORIGIN offset by 3 extra words at start
        ;===========================================================================================
        ;
        ; **----------------------------INTIALIZED USER VARIABLES------------
        ;
        ; USER+0000 DW  top most word in cold start FORTH vocabulary pointer
        ; USER+0002 DW  backspace
        ; USER+0004 DW  USER area pointer

        DB $82,$53,$B0                      ; S0
        DW ERRS - 7                         ;
SO:     DW USER                             ;
        DW $0006                            ;  first USER variable offset ( allow 3 words for constants listed above )
        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$52,$B0                      ; R0
        DW SO - 5                           ;
RO:     DW USER                             ;
        DW $0008                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"TI",$C2                     ; TIB
        DW RO - 5                           ;
TIB:    DW USER                             ;
        DW $000A                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"WIDT",$C8                   ; WIDTH
        DW TIB - 6                          ;
WIDTH:  DW USER                             ;
        DW $000C                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"WARNIN",$C7                 ; WARNING
        DW WIDTH - 8                        ;
WARNING: DW USER                            ;
        DW $000E                            ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $84,$43,$41,$50,$D3              ; CAPS   ( caplock )
        DW WARNING - 10                     ;
CAPS:   DW USER                             ;
        DW capslock                         ;
capslock equ $0010                          ; label so I/O driver can access this user variable directly
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"FENC",$C5                   ; FENCE   FORGET boundry
        DW CAPS - 7                         ;
FENCE:  DW USER                             ;
        DW $0012                            ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $82,$44,$D0                      ; DP  - address of next free memory above the dictionary
        DW FENCE - 8                        ;
DP:     DW USER                             ;
        DW $0014                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $88,"VOC-LIN",$CB                ; VOC-LINK
        DW DP - 5                           ;
VOCmLINK: DW USER                           ;
        DW $0016                            ;

        ;
        ; **-------------------------------END OF INITIALIZED USER VARIABLES ---------------
        ;
        DB $83,$42,$4C,$CB                  ; BLK
        DW VOCmLINK - 11                    ;
BLK:    DW USER                             ;
        DW $0018                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$49,$CE                      ; IN
        DW BLK - 6                          ;
IN:     DW USER                             ;
        DW $001A                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"OU",$D4                     ; OUT
        DW IN - 5                           ;
OUT:    DW USER                             ;
        DW $001C                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"SC",$D2                     ; SCR
        DW OUT - 6                          ;
SCR:    DW USER                             ;
        DW $001E                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $86,"OFFSE",$D4                  ; OFFSET
        DW SCR - 6                          ;
OFFSET: DW USER                             ;
        DW $0020                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"CONTEX",$D4                 ; CONTEXT
        DW OFFSET - 9                       ;
CONTEXT: DW USER                            ;
        DW $0022                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"CURREN",$D4                 ; CURRENT
        DW CONTEXT - 10                     ;
CURRENT: DW USER                            ;
        DW $0024                            ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $85,"STAT",$C5                   ; STATE
        DW CURRENT - 10                     ;
STATE:  DW USER                             ;
        DW $0026                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"BAS",$C5                    ; BASE
        DW STATE - 8                        ;
BASE:   DW USER                             ;
        DW $0028                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,$44,$50,$CC                  ; DPL
        DW BASE - 7                         ;
DPL:    DW USER                             ;
        DW $002A                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,$46,$4C,$C4                  ; FLD
        DW DPL - 6                          ;
FLD:    DW USER                             ;
        DW $002C                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,$43,$53,$D0                  ; CSP
        DW FLD - 6                          ;
CSP:    DW USER                             ;
        DW $002E                            ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$52,$A3                      ; R#
        DW CSP - 6                          ;
R#:     DW USER                             ;
        DW $0030                            ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $83,$48,$4C,$C4                  ; HLD
        DW R# - 5                           ;
HLD:    DW USER                             ;
        DW $0032                            ;

        ;================================================================================
        ; END OF USER VARIABLES
        ;================================================================================

;=====================================================================================================
;
;   FORTH vocabulary words written (mostly) in FORTH
;
;=====================================================================================================



        ; **-----------------------------------------------------------------------------
        DB $83,"KE",$D9                     ; KEY
        DW HLD - 6                          ;
KEY:    DW getKEY                           ;

        ; **-----------------------------------------------------------------------------
        DB $84,"EMI",$D4                    ; EMIT
        DW KEY - 6                          ;
EMIT:   DW NEST                             ;
        DW CSEND                            ;
        DW o                                ;
        DW OUT                              ;
        DW p!                               ;
        DW sS                               ;

        ; **-----------------------------------------------------------------------------
        DB $89,"?TERMINA",$CC               ; ?TERMINAL
        DW EMIT - 7                         ;
qTERMINAL:                                  ;
        DW qTERM                            ;

        ; ** -----------------------------------------------------------------------------
        DB $82,$43,$D2                      ; CR
        DW qTERMINAL - 12                   ;
CR:     DW NEST                             ;
        DW bvdr                             ;
        DB $02,$0D,$0A                      ;
        DW sS                               ;

        ; **-----------------------------------------------------------------------------
        DB $82,$31,$AB                      ; 1+
        DW CR - 5                          ;
op:     DW NEST                             ;
        DW o                                ;
        DW p                                ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $82,$32,$AB                      ; 2+
        DW op - 5                           ;
dp:     DW NEST                             ;
        DW d                                ;
        DW p                                ;
        DW sS                               ;
        ;
        ;
        ; ** -----------------------------------------------------------------------------
        DB $84,"HER",$C5                    ; HERE
        DW dp - 5                           ;
HERE:   DW NEST                             ;
        DW DP                               ;
        DW a                                ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"ALLO",$D4                   ; ALLOT
        DW HERE - 7                         ;
ALLOT:  DW NEST                             ;
        DW DP                               ;
        DW p!                               ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DW $81AC                            ; , (comma)
        DW ALLOT - 8                        ;
c:      DW NEST                             ;
        DW HERE                             ;
        DW !                                ;
        DW d                                ;
        DW ALLOT                            ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $82,$43,$AC                      ; C,  push byte on stack into next dictionary byte
        DW c - 4                            ;
Cc:     DW NEST                             ;
        DW HERE                             ;
        DW C!                               ;
        DW o                                ;
        DW ALLOT                            ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DW $81BD                            ; = (EQUAL SIGN)
        DW Cc - 5                           ;
e:      DW NEST                             ;
        DW m                                ;
        DW ze                               ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DW $81BE                            ; > (GTR THAN SIGN)
        DW e - 4                            ;
g:      DW NEST                             ;
        DW SWAP                             ;
        DW LESS                                ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"RO",$D4                     ; ROT
        DW g - 4                            ;
ROT:    DW NEST                             ;
        DW gR                               ;
        DW SWAP                             ;
        DW Rg                               ;
        DW SWAP                             ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"-RO",$D4                   ; -ROT (new)
        DW ROT -6                           ;
mROT:   DW NEST                             ;
        DW SWAP                             ;
        DW gR                               ;
        DW SWAP                             ;
        DW Rg                               ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"SPAC",$C5                   ; SPACE
        DW mROT - 7                         ;
SPACE:  DW NEST                             ;
        DW BL                               ;
        DW EMIT                             ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"-DU",$D0                    ; -DUP
        DW SPACE - 8                        ;
mDUP:   DW NEST                             ;
        DW DUP                              ;
        DW zBRANCH                          ;
        DW mD1                              ;
        DW DUP                              ;
mD1:    DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"2DU",$D0                    ; 2DUP (new)
        DW mDUP - 7                         ;
tDUP:   DW NEST                             ;
        DW OVER                             ;
        DW OVER                             ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $83,"NI",$D0                     ; NIP (new)
        DW tDUP - 7                         ;
NIP:    DW NEST                             ;
        DW SWAP                             ;
        DW DROP                             ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"TUC",$CB                    ; TUCK  (new)
        DW NIP - 6                         ;
TUCK:   DW NEST                             ;
        DW DUP                              ;
        DW mROT                             ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $88,"TRAVERS",$C5                ; TRAVERSE
        DW TUCK - 7                         ;
TRAVERSE:                                   ;
        DW NEST                             ;
        DW SWAP                             ;
TR1:    DW OVER                             ;
        DW p                                ;
        DW LIT                              ;
        DW $007F                            ;
        DW OVER                             ;
        DW Ca                               ;
        DW LESS                                ;
        DW zBRANCH                          ;
        DW TR1                              ;
        DW SWAP                             ;
        DW DROP                             ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $86,"LATES",$D4                  ; LATEST
        DW TRAVERSE - 11                    ;
LATEST: DW NEST                             ;
        DW CURRENT                          ;
        DW a                                ;
        DW a                                ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $83,$4C,$46,$C1                  ; LFA
        DW LATEST - 9                       ; LINK FIELD ADDRESS
LFA:    DW NEST                             ;
        DW LIT                              ;
        DW $0004                            ;
        DW m                                ;
        DW sS                               ;
        ;
        ;
        ; **------------------------------------------------------------------------------
        DB $83,$43,$46,$C1                  ; CFA
        DW LFA - 6                          ; CODE FIELD ADDRESS
CFA:    DW NEST                             ;
        DW d                                ;
        DW m                                ;
        DW sS                               ;
        ;
        ;
        ; **------------------------------------------------------------------------------
        DB $83,$4E,$46,$C1                  ; NFA
        DW CFA - 6                          ; NAME FIELD ADDRESS
NFA:    DW NEST                             ;
        DW LIT                              ;
        DW $0005                            ;
        DW m                                ;
        DW LIT                              ;
        DW $FFFF                            ;
        DW TRAVERSE                         ;
        DW sS                               ;
        ;
        ;
        ; **------------------------------------------------------------------------------
        DB $83,$50,$46,$C1                  ; PFA
        DW NFA - 6                          ; PARAMETER FIELD ADDRESS
PFA:    DW NEST                             ;
        DW o                                ;
        DW TRAVERSE                         ;
        DW LIT                              ;
        DW $0005                            ;
        DW p                                ;
        DW sS                               ;
        ;
        ;
        ; **------------------------------------------------------------------------------
        DB $84,$21,$43,$53,$D0              ; !CSP
        DW PFA - 6                          ;
!CSP:   DW NEST                             ;
        DW SPa                              ;
        DW CSP                              ;
        DW !                                ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $86,"?ERRO",$D2                  ; ?ERROR    ( t/f errmsg# -- )
        DW !CSP - 7                         ;
qERROR: DW NEST                             ;
        DW SWAP                             ;
        DW zBRANCH, qE1                     ;
        DW ERROR                            ;
        DW BRANCH, qE2                      ;
qE1:    DW DROP                             ;
qE2:    DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $85,"?COM",$D0                   ; ?COMP    ( Note : this is just the opposite of ?EXEC )
        DW qERROR - 9                       ;
qCOMP:  DW NEST                             ;
        DW STATE                            ;
        DW a                                ;
        DW ze                               ;
        DW LIT                              ;
        DW $0011                            ; error 17 = compilation only, use in definition
        DW qERROR                           ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $85,"?EXE",$C3                   ; ?EXEC   ( Note : this is just the opposite of ?COMP )
        DW qCOMP - 8                        ;
qEXEC:  DW NEST                             ;
        DW STATE                            ;
        DW a                                ;
        DW LIT                              ;
        DW $0012                            ; error 18 = execution only
        DW qERROR                           ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $86,"?PAIR",$D3                  ; ?PAIRS
        DW qEXEC - 8                        ;
qPAIRS: DW NEST                             ;
        DW m                                ;
        DW LIT                              ;
        DW $0013                            ; error 19 = conditionals not paired
        DW qERROR                           ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $84,$3F,$43,$53,$D0              ; ?CSP  - issue error if stack position is not at value stored in CSP
        DW qPAIRS - 9                       ;
qCSP:   DW NEST                             ;
        DW SPa                              ; push top of stack address onto stack
        DW CSP                              ; push current stack pointer value
        DW a                                ;
        DW m                                ; -
        DW LIT                              ;
        DW $0014                            ; error 20 = definition not finished
        DW qERROR                           ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $88,"?LOADIN",$C7                ; ?LOADING   NOTE : never used anywhere
        DW qCSP - 7                         ;
qLOADING: DW NEST                           ;
        DW BLK                              ;
        DW a                                ;
        DW ze                               ;
        DW LIT                              ;
        DW $0016                            ; error 22 = use only when loading
        DW qERROR                           ;
        DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $87,"COMPIL",$C5                 ; COMPILE
        DW qLOADING - 11                    ;
COMPILE: DW NEST                            ;
        DW qCOMP                            ;
        DW Rg                               ;
        DW DUP                              ;
        DW dp                               ;
        DW gR                               ;
        DW a                                ;
        DW c                                ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DW $C1DB                            ; [   LEFT BRACKET
        DW COMPILE - 10                     ;
[:      DW NEST                             ;
        DW z                                ;
        DW STATE                            ;
        DW !                                ;
        DW sS                               ;
        ;
        ;
        ;  **-----------------------------------------------------------------------------
        DW $81DD                            ; ]   RIGHT BRACKET
        DW [ - 4                            ;
]:      DW NEST                             ;
        DW LIT                              ;
        DW $00C0                            ;
        DW STATE                            ;
        DW !                                ;
        DW sS                               ;
        ;
        ;
        ; ** -----------------------------------------------------------------------------
        DB $86,"SMUDG",$C5                  ; SMUDGE
        DW ] - 4                            ;
SMUDGE: DW NEST                             ;
        DW LATEST                           ;
        DW LIT                              ;
        DW $0020                            ;
        DW TOGGLE                           ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $83,$48,$45,$D8                  ; HEX
        DW SMUDGE - 9                       ;
HEX:    DW NEST                             ;
        DW LIT                              ;
        DW $0010                            ;
        DW BASE                             ;
        DW !                                ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $87,"DECIMA",$CC                 ; DECIMAL
        DW HEX - 6                          ;
DECIMAL: DW NEST                            ;
        DW LIT                              ;
        DW $000A                            ;
        DW BASE                             ;
        DW !                                ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $87,"(;CODE",$A9                 ; (;CODE)
        DW DECIMAL - 10                     ;
lCODEr: DW NEST                             ;
        DW Rg                               ;
        DW LATEST                           ;
        DW PFA                              ;
        DW CFA                              ;
        DW !                                ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------                        
        DB $C5,";COD",$C5                        ;  ;CODE     - used to switch from compiling Forth word to assembler mode
        DW lCODEr - 10                           ;
sCODE:  DW NEST                                  ;
        DW qCSP                                  ;
        DW COMPILE, lCODEr                       ;
        DW [                                     ;
        DW SMUDGE                                ;
        DW ASSEMBLER                             ;
        DW sS                                    ;        
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"COUN",$D4                   ; COUNT
        DW sCODE - 8                       ;
COUNT:  DW NEST                             ;
        DW DUP                              ;
        DW op                               ;
        DW SWAP                             ;
        DW Ca                               ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"TYP",$C5                    ; TYPE
        DW COUNT - 8                        ;
TYPE:   DW NEST                             ;
        DW mDUP                             ;
        DW zBRANCH                          ;
        DW TYP4                             ;
        DW OVER                             ;
        DW p                                ;
        DW SWAP                             ;
        DW bDOr                             ;
TYP1:   DW R                                ;
        DW Ca                               ;
        DW LIT,$007F                        ; make sure it's 7 bit ASCII
        DW FAND                             ;
        DW DUP                              ;
        DW LIT, $0020                       ; print chars > space ( 0x20 )
        DW m                                ;
        DW zl                               ;
        DW zBRANCH,TYP0                     ;
        DW DUP                              ;
        DW LIT, $000D                       ; allow CR to get through
        DW m                                ;
        DW zBRANCH, TYP0                    ;
        DW DUP                              ;
        DW LIT, $000A                       ; allow LF to get through
        DW m                                ;
        DW zBRANCH, TYP0                    ;
        DW DROP                             ;
        DW BRANCH, TYP3                     ;
TYP0:   DW EMIT                             ;
TYP3:   DW bLOOPr, TYP1                     ;
        DW sS                               ;
TYP4:   DW DROP                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $89,"-TRAILIN",$C7               ; -TRAILING
        DW TYPE - 7                         ;
mTRAILING:                                  ;
        DW NEST                             ;
        DW DUP                              ;
        DW z                                ;
        DW bDOr                             ;
TRL1:   DW OVER                             ;
        DW OVER                             ;
        DW p                                ;
        DW o                                ;
        DW m                                ;
        DW Ca                               ;
        DW BL                               ;
        DW m                                ;
        DW zBRANCH, trl1                    ;
        DW LEAVE                            ;
        DW BRANCH, trl2                     ;
trl1:   DW o                                ;
        DW m                                ;
trl2:   DW bLOOPr                           ;
        DW TRL1                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $84,$28,$2E,$22,$A9              ; (.")
        DW mTRAILING - 12                   ;
bvdr:   DW NEST                             ;
        DW R                                ;
        DW COUNT                            ;
        DW DUP                              ;
        DW op                               ;
        DW Rg                               ;
        DW p                                ;
        DW gR                               ;
        DW TYPE                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"EXPEC",$D4                  ; EXPECT
        DW bvdr - 7                         ;
EXPECT: DW NEST                             ;
        DW OVER                             ;
        DW p                                ;
        DW OVER                             ;
        DW bDOr                             ;
EXPT4:  DW KEY                              ;
        DW DUP                              ;
        DW LIT                              ; Warning : hard coded offset to the backspace character buried in the ORIGIN parameter area
        DW $000E                            ;
        DW pORIGIN                          ;
        DW a                                ;
        DW e                                ;
        DW zBRANCH                          ;
        DW EXPT1                            ;
        DW DROP                             ;
        DW LIT                              ;
        DW $0008                            ;
        DW OVER                             ;
        DW R                                ;
        DW e                                ;
        DW DUP                              ;
        DW Rg                               ;
        DW d                                ;
        DW m                                ;
        DW p                                ;
        DW gR                               ;
        DW m                                ;
        DW BRANCH                           ;
        DW EXPT2                            ;
EXPT1:  DW DUP                              ;
        DW LIT                              ;
        DW $000D                            ;
        DW e                                ;
        DW zBRANCH                          ;
        DW EXPT3                            ;
        DW LEAVE                            ;
        DW DROP                             ;
        DW BL                               ;
        DW z                                ;
        DW BRANCH                           ;
        DW EXPT5                            ;
EXPT3:  DW DUP                              ;
EXPT5:  DW R                                ;
        DW C!                               ;
        DW z                                ;
        DW R                                ;
        DW op                               ;
        DW !                                ;
EXPT2:  DW EMIT                             ;
        DW bLOOPr                           ;
        DW EXPT4                            ;
        DW DROP                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"QUER",$D9                   ; QUERY
        DW EXPECT - 9                       ; input line of text
QUERY:  DW NEST                             ;
        DW TIB                              ;
        DW a                                ;
        DW LIT                              ;
        DW $0050                            ;
        DW EXPECT                           ;
        DW z                                ;
        DW IN                               ;
        DW !                                ;
        DW sS                               ;
        ;
        ;  -----------------------------------------------------------------------------
        ; This is pseudonym for the "null" or dictionary entry for a name of
        ; one character of ASCII null. It is the execution procedure to
        ; terminate interpretation of a line of text from the terminal or
        ; within a disc buffer, as both buffers always have a null at the end.
        DW $C180                            ; X   (immediate)
        DW QUERY - 8                        ;
XXX:    DW NEST                             ;
        DW BLK                              ; skip out if we are on BLK 0 - meaning direct from terminal input buffer
        DW a                                ;
        DW zBRANCH, X2                      ;
                                            ; Warning : this appears to be for loading eight 128 byte sectors per BLOCK but doesn't really
        DW o                                ; advance to the next block
        DW BLK                              ;
        DW p!                               ;
        DW z                                ; reset input buffer pointer to start of buffer
        DW IN                               ;
        DW !                                ;
        DW BLK                              ; skip out if end of the 8 128 byte sectors per block (hacked to always with this code)
        DW a                                ;
        DW LIT                              ;
        DW $0000                            ; $0007 in fig model??? = 8 x 128 byte blocks per screen buffer?
        DW FAND                             ;
        DW ze                               ;
        DW zBRANCH, XEND                    ; Warning always branches as we just did an AND with $0000
        DW qEXEC                            ; issue an error message if not executing
X2:     DW Rg                               ; R>
        DW DROP                             ; DROP
XEND:   DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"ERAS",$C5                   ; ERASE   ZERO MEMORY
        DW XXX - 4                          ;
ERASE:  DW NEST                             ;
        DW z                                ;
        DW FILL                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"BLANK",$D3                  ; BLANKS
        DW ERASE - 8                        ; fill memory with ascii blanks
BLANKS: DW NEST                             ;
        DW BL                               ;
        DW FILL                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"HOL",$C4                    ; HOLD
        DW BLANKS - 9                       ;
HOLD:   DW NEST                             ;
        DW LIT                              ;
        DW $FFFF                            ; -1
        DW HLD                              ;
        DW p!                               ;
        DW HLD                              ;
        DW a                                ;
        DW C!                               ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"PA",$C4                     ; PAD
        DW HOLD - 7                         ;
PAD:    DW NEST                             ;
        DW HERE                             ;
        DW LIT                              ;
        DW $0044                            ;
        DW p                                ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"WOR",$C4                    ; WORD
        DW PAD - 6                          ;
WORD:   DW NEST                             ;
        DW BLK                              ; jump if loading from console rather than disk
        DW a                                ;
        DW zBRANCH                          ;
        DW WD1                              ;
        DW BLK                              ; get address in memory of current disk block # if loading from disk
        DW a                                ;
        DW BLOCK                            ;
        DW BRANCH                           ;
        DW WD2                              ;
WD1:    DW TIB                              ; get terminal input buffer address if loading from console
        DW a                                ;
WD2:    DW IN                               ; add current offset position in active input buffer
        DW a                                ;
        DW p                                ;
        DW SWAP                             ;
        DW ENCLOSURE                        ;
        DW HERE                             ;
        DW LIT                              ;
        DW $0022                            ;
        DW BLANKS                           ; 34 blanks ?
        DW IN                               ;
        DW p!                               ;
        DW OVER                             ;
        DW m                                ;
        DW gR                               ;
        DW R                                ;
        DW HERE                             ;
        DW C!                               ;
        DW p                                ;
        DW HERE                             ;
        DW op                               ;
        DW Rg                               ;
        DW CMOVE                            ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $88,"(NUMBER",$A9                ; (NUMBER)
        DW WORD - 7                         ;
lNUMBERr: DW NEST                           ;
        DW op                               ;
        DW DUP                              ;
        DW gR                               ;
        DW Ca                               ;
        DW BASE                             ;
        DW a                                ;
        DW DIGIT                            ;
        DW zBRANCH                          ;
        DW PNM2                             ;
        DW SWAP                             ;
        DW BASE                             ;
        DW a                                ;
        DW Us                               ;
        DW DROP                             ;
        DW ROT                              ;
        DW BASE                             ;
        DW a                                ;
        DW Us                               ;
        DW Dp                               ;
        DW DPL                              ;
        DW a                                ;
        DW op                               ;
        DW zBRANCH                          ;
        DW PNM1                             ;
        DW o                                ;
        DW DPL                              ;
        DW p!                               ;
PNM1:   DW Rg                               ;
        DW BRANCH                           ;
        DW lNUMBERr + 2                     ;
PNM2:   DW Rg                               ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"NUMBE",$D2                  ; NUMBER
        DW lNUMBERr - 11                    ;
NUMBER: DW NEST                             ;
        DW z                                ;
        DW z                                ;
        DW ROT                              ;
        DW DUP                              ;
        DW op                               ;
        DW Ca                               ;
        DW LIT                              ;
        DW $002D                            ;
        DW e                                ;
        DW DUP                              ;
        DW gR                               ;
        DW p                                ;
        DW LIT                              ;
        DW $FFFF                            ; -1
NMB1:   DW DPL                              ;
        DW !                                ;
        DW lNUMBERr                         ;
        DW DUP                              ;
        DW Ca                               ;
        DW BL                               ;
        DW m                                ;
        DW zBRANCH                          ;
        DW NMB2                             ;
        DW DUP                              ;
        DW Ca                               ;
        DW LIT                              ;
        DW $002E                            ;
        DW m                                ;
        DW z                                ; error 0 = not found
        DW qERROR                           ;
        DW z                                ;
        DW BRANCH                           ;
        DW NMB1                             ;
NMB2:   DW DROP                             ;
        DW Rg                               ;
        DW zBRANCH                          ;
        DW NMB3                             ;
        DW DMINUS                           ;
NMB3:   DW sS                               ;
        ;
        ;
        ; **-----------------------------------------------------------------------------
        DB $85,"-FIN",$C4                   ; -FIND
        DW NUMBER - 9                       ;
mFIND:  DW NEST                             ;
        DW BL                               ;
        DW WORD                             ;
        DW HERE                             ;
        DW CONTEXT                          ;
        DW a                                ;
        DW a                                ;
        DW bFINDr                           ;
        DW DUP                              ;
        DW ze                               ;
        DW zBRANCH                          ;
        DW MF1                              ;
        DW DROP                             ;
        DW HERE                             ;
        DW LATEST                           ;
        DW bFINDr                           ;
MF1:    DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $87,"(ABORT",$A9                 ; (ABORT)
        DW mFIND - 8                        ;
lABORTr: DW NEST                            ;
        DW ABORT                            ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"ERRO",$D2                   ; ERROR
        DW lABORTr - 10                     ;
ERROR:  DW NEST                             ;
        DW WARNING                          ; check current WARNING setting
        DW a                                ;
        DW zl                               ; < 0 ?
        DW zBRANCH                          ;
        DW ERR1                             ; ABORT if so
        DW lABORTr                          ;
ERR1:   DW HERE                             ; else print out the text from the current work in process causing the error
        DW COUNT                            ;
        DW TYPE                             ;
        DW bvdr                             ; send a "?" to indicate an error
        DB $03," ? "                        ;
        DW MESSAGE                          ; send the error message indicated by number passed on stack
        DW SP!                              ; reset the data stack
 if (uart_type = software)
        DW xDI                              ; disable interrupts if software UART
 endi        
        DW BLK, a                           ; if reading from console then don't worry about screen and line # of the error
        DW zBRANCH, ERR2                    ;
                                            ;
        DW IN                               ; get offset in current block
        DW a                                ;
        DW LIT,$0040                        ; convert to relative line number (divide by 64 char / line )
        DW h                                ;
        DW LIT,$0010                        ; convert to relative line number and relative block number
        DW hMOD                             ;
        DW BLK                              ; get the current block number
        DW a                                ; add in relative  block to get screen number of error
        DW p                                ;
        DW BASE, a, ROT, ROT                ; print out in decimal regardless of current BASE
        DW DECIMAL                          ;
        DW bvdr                             ; print screen number of error
        DB $05," SCR:"                      ;
        DW v                                ;
        DW bvdr                             ; print line number of error
        DB $06," LINE:"                     ;
        DW v                                ;
        DW BASE, !                          ;
ERR2:                                       ;
        DW QUIT                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"MI",$CE                     ; MIN
        DW ERROR - 8                        ;
MIN:    DW NEST                             ;
        DW OVER                             ;
        DW OVER                             ;
        DW g                                ;
        DW zBRANCH                          ;
        DW MN1                              ;
        DW SWAP                             ;
MN1:    DW DROP                             ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"ID",$AE                     ; ID.
        DW MIN - 6                          ;
IDv:    DW NEST                             ;
        DW DUP                              ;
        DW PFA, LFA, SWAP, op, bDOr         ;
ID0:    DW I, Ca, LIT, $007F, FAND          ;
        DW EMIT,bLOOPr,ID0                  ;
        DW SPACE                            ;
        DW sS                               ;
        ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"CREAT",$C5                  ; CREATE
        DW IDv - 6                          ;
CREATE:                                     ;
        DW NEST                             ;
                                            ; check for dictionary space availabe top of dictionary space
        DW LIT, task1stacks                 ; Warning : use this as it should be the bottom of stack &  user space
        DW HERE                             ; top of dictionary space
        DW LIT                              ; check to be sure there is a random + 160 bytes ( 80 words) free for the new word
        DW $00A0                            ;
        DW p                                ;
        DW LESS                             ; Warning : should this be unsigned in case top of free memory crosses above $8000 ?
        DW d                                ; msg 2 = DICTIONARY FULL error message
        DW qERROR                           ;
                                            ;
        DW mFIND                            ; find if the new word already exists
        DW zBRANCH, CRT1                    ; jump if not
        DW DROP                             ; drop length number
        DW NFA                              ; convert to name field
     ;   DW CR                              ;
        DW IDv                              ; print the word name
        DW LIT, $0004                       ; print ISN'T UNIQUE warning message
        DW MESSAGE                          ;
        DW SPACE                            ;
                                            ;
CRT1:   DW HERE                             ;
        DW DUP                              ;
        DW Ca                               ;
        DW WIDTH                            ;
        DW a                                ;
        DW MIN                              ;
        DW op                               ;
        DW ALLOT                            ;
        DW DUP                              ;
        DW LIT                              ;
        DW $00A0                            ;
        DW TOGGLE                           ;
        DW HERE                             ;
        DW o                                ;
        DW m                                ;
        DW LIT                              ;
        DW $0080                            ;
        DW TOGGLE                           ;
        DW LATEST                           ;
        DW c                                ;
        DW CURRENT                          ;
        DW a                                ;
        DW !                                ;
        DW HERE                             ;
        DW dp                               ;
        DW c                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DW $C1BA                            ; :   (IMMEDIATE)
        DW CREATE - 9                       ;
s:      DW NEST                             ;
        DW qEXEC                            ;
        DW !CSP                             ;
        DW CURRENT                          ;
        DW a                                ;
        DW CONTEXT                          ;
        DW !                                ;
        DW CREATE                           ; create the words dictionary entry header
        DW ]                                ;
        DW LIT                              ;
        DW $FFFE                            ; -2
        DW DP                               ;
        DW p!                               ;
        DW COMPILE                          ; add the NEST word as the first entry in the CODE field
        DW NEST                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"!COD",$C5                   ; !CODE
        DW s - 4                            ;
!CODE:  DW NEST                             ;
        DW CREATE                           ;
        DW SMUDGE                           ;
        DW LATEST                           ;
        DW PFA                              ;
        DW CFA                              ;
        DW !                                ;
        DW c                                ;
        DW BLK                              ; print new words name but only if loaded from SCREEN not console
        DW a                                ;
        DW zBRANCH,code0                    ;
        DW CR,bvdr                          ;
        DB $7," added "                     ;
        DW LATEST                           ; get NFA of the new word
        DW IDv                              ; print the name string
code0:  DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $88,"CONSTAN",$D4                ; CONSTANT
        DW !CODE - 8                        ;
CONSTANT:                                   ;
        DW NEST                             ;
        DW LIT                              ;
        DW CONST                            ;
        DW !CODE                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $88,"VARIABL",$C5                ; VARIABLE
        DW CONSTANT - 11                    ;
VARIABLE:                                   ;
        DW NEST                             ;
        DW LIT                              ;
        DW VAR                              ;
        DW !CODE                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"USE",$D2                    ; USER
        DW VARIABLE - 11                    ;
USR:    DW NEST                             ;
        DW LIT                              ;
        DW USER                             ;
        DW !CODE                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $87,"<BUILD",$D3                 ; <BUILDS
        DW USR - 7                          ;
lBUILDS:                                    ;
        DW NEST                             ;
        DW z                                ;
        DW CONSTANT                         ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"DOES",$BE                   ; DOES>
        DW lBUILDS - 10                     ;
DOESg:  DW NEST                             ;
        DW Rg                               ;
        DW LATEST                           ;
        DW PFA                              ;
        DW !                                ;
        DW lCODEr                           ;
DUZ1:   SEX R2                              ;
        GHI RA                              ;
        STXD                                ;
        GLO RA                              ;
        STXD                                ;
        LDA RB                              ;
        PHI RA                              ;
        LDA RB                              ;
        PLO RA                              ;
        INC R9                              ;
        INC R9                              ;
        GHI RB                              ;
        STR R9                              ;
        INC R9                              ;
        GLO RB                              ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C7,"LITERA",$CC                 ; LITERAL (IMMEDIATE)
        DW DOESg - 8                        ;
LITERAL: DW NEST                            ;
        DW STATE                            ;
        DW a                                ;
        DW zBRANCH                          ;
        DW LT1                              ;
        DW COMPILE                          ;
        DW LIT                              ;
        DW c                                ;
LT1:    DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C8,"DLITERA",$CC                ; DLITERAL (IMMEDIATE)
        DW LITERAL - 10                     ;
DLITERAL: DW NEST                           ;
        DW STATE                            ;
        DW a                                ;
        DW zBRANCH                          ;
        DW DLTL1                            ;
        DW SWAP                             ;
        DW LITERAL                          ;
        DW LITERAL                          ;
DLTL1:  DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"?STAC",$CB                  ; ?STACK
        DW DLITERAL - 11                    ;
qSTACK: DW NEST                             ;
        DW SPa                              ;
        DW SO                               ;
        DW a, OVER, OVER, LESS              ;
        DW o,qERROR                         ;
        DW LIT,$00F6                        ;
        DW p,g                              ;
        DW LIT                              ;
        DW $0007                            ;
        DW qERROR                           ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $89,"INTERPRE",$D4               ; INTERPRET
        DW qSTACK - 9                       ;
INTERPRET: DW NEST                          ;
        DW mFIND                            ;
        DW zBRANCH                          ;
        DW PT1                              ;
        DW STATE                            ;
        DW a                                ;
        DW LESS                              ;
        DW zBRANCH                          ;
        DW PT2                              ;
        DW CFA                              ;
        DW c                                ;
        DW BRANCH                           ;
        DW PT3                              ;
PT2:    DW CFA                              ;
        DW EXECUTE                          ;
PT3:    DW qSTACK                           ;
        DW BRANCH                           ;
        DW PT4                              ;
PT1:    DW HERE                             ;
        DW NUMBER                           ;
        DW DPL                              ;
        DW a                                ;
        DW op                               ;
        DW zBRANCH                          ;
        DW PT5                              ;
        DW DLITERAL                         ;
        DW BRANCH                           ;
        DW PT6                              ;
PT5:    DW DROP                             ;
        DW LITERAL                          ;
PT6:    DW qSTACK                           ;
PT4:    DW BRANCH                           ;
        DW INTERPRET + 2                    ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $8A,"VOCABULAR",$D9              ; VOCABULARY
        DW INTERPRET - 12                   ;
VOCABLUARY: DW NEST                         ;
        DW lBUILDS                          ;
        DW LIT                              ;
        DW $81A0                            ;
        DW c                                ;
        DW CURRENT                          ;
        DW a                                ;
        DW CFA                              ;
        DW c                                ;
        DW HERE                             ;
        DW VOCmLINK                         ;
        DW a                                ;
        DW c                                ;
        DW VOCmLINK                         ;
        DW !                                ;
        DW DOESg                            ;
VB1:    DW dp                               ;
        DW CONTEXT                          ;
        DW !                                ;
        DW sS                               ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $8B,"DEFINITION",$D3             ; DEFINITIONS
        DW VOCABLUARY - 13                  ;
DEFINITIONS:                                ;
        DW NEST                             ;
        DW CONTEXT                          ;
        DW a                                ;
        DW CURRENT                          ;
        DW !                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"QUI",$D4                    ; QUIT
        DW DEFINITIONS - 14                 ;
QUIT:                                       ;
        DW NEST                             ;
        DW z                                ; 0 BLK !
        DW BLK                              ;
        DW !                                ;
        DW [                                ; [
Q1:     DW CR                               ; CR        
Q1a:    DW RP!                              ; RP!
        
        DW QUERY                            ; QUERY
        DW INTERPRET                        ; INTERPRET
        DW STATE                            ; STATE @ 0= 0BRANCH
        DW a                                ;
        DW ze                               ; print prompt only if no longer interpreting
        DW zBRANCH                          ;
        DW Q4                               ;
        DW isr_status                       ;
        DW zBRANCH, Q2                      ;
        DW bvdr                             ; ." running.."
        DB $0B,"  running.."                ;
        DW BRANCH, Q1a                      ;
        
Q2:     DW bvdr                             ; ." OK"
        DB $04,"  OK"                       ;        
 if stackptr_show = 1                       ;
        DW bvdr                             ; ." [ stack ]"
        DB $02," ["                         ;
        DW SPa                              ;
        DW Uv                               ;
        DW bvdr                             ;
        DB $02,$08,"]"                      ;
 endi                                       ;
Q4:     DW BRANCH                           ; LOOP BACK
        DW Q1                               ;

  ;     DW sS                               ; never gets here

isr_status:                                 ; helper routine to check if R1 is zero instead of holding the ISR address
        DW  $+2                             ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        GHI R1                              ;
        BZ isr1                             ;
        GLO R1                              ;
isr1:   STR R9                              ; save either zero or anything else (i.e. not zero)
        DEC R9                              ;
        STR R9                              ;
        SEP RC                              ;
        ;
        ;  **-----------------------------------------------------------------------------
        DB $85,"ABOR",$D4                   ; ABORT
        DW QUIT - 7                         ;
ABORT:  DW NEST                             ;
ABRT2:  DW SP!                              ;
        DW HEX                              ; NOTE : start in hex or decimal mode?
 if extra_hardware = 1                                                ;
        DW LCD_INIT, LED_CLEAR              ;
        DW vlcdd                            ;
        DB $08,"1802 4th"                   ;
 endi    ;

        DW bvdr                             ;
        DB $12,XON,$0A,$0D,"FORTH 1802 V-4."  ; sneak in a XON and CR to the startup message
                                            ;
        DW LIT, $000A                       ;  Warning : hard coded offset to the version number buried in the ORIGIN parameter area
        DW pORIGIN                          ;
        DW a                                ;
        DW v                                ;
        DW FORTH + DELTA                    ; FORTH    make current = FORTH
        DW DEFINITIONS                      ; DEFINITIONS    set CONTEXT = CURRENT too

 if extra_hardware = 1                     ;
        DW QOFF                             ; FIMXE : turn off Q LED that was turned on at start
                                            ;
        DW LIT, $0, LIT, $0, LIT, $0        ; initialize the RTC (for time of day and tic timer interrupts
        DW RTC_SET                          ;
 endi                                       ;

        DW XQUIT                            ; QUIT -  outer console / interpreter
  ;     DW sS                               ; never gets here
        ;
        ;  -----------------------------------------------------------------------------
        DB $C1, $BB                         ;  semicolon
        DW ABORT-8                          ;
SEMIC:  DW NEST, qCSP, COMPILE, sS          ;
        DW SMUDGE, [                        ;

        DW BLK                              ; print new words name but only if loaded from SCREEN not console
        DW a                                ;
        DW zBRANCH,semi0                    ;
        DW CR,bvdr                          ;
        DB $7," added "                     ;
        DW LATEST                           ; get NFA of the new word
    DW IDv                                  ; print the name string
semi0:
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C2,$2E,$A2                      ; ."   (IMMEDIATE)
        DW SEMIC - 4                        ;
vd:     DW NEST                             ;
        DW LIT                              ;
        DW $0022                            ;
        DW STATE                            ;
        DW a                                ;
        DW zBRANCH                          ;
        DW DOTQ1                            ;
        DW COMPILE                          ;
        DW bvdr                             ;
        DW WORD                             ;
        DW HERE                             ;
        DW Ca                               ;
        DW op                               ;
        DW ALLOT                            ;
        DW BRANCH                           ;
        DW DOTQ2                            ;
DOTQ1:  DW WORD                             ;
        DW HERE                             ;
        DW COUNT                            ;
        DW TYPE                             ;
DOTQ2:  DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C9,"[COMPILE",$DD               ; [COMPILE]   (IMMEDIATE)
        DW vd - 5                           ; 
[COMPILE]:                                  ;
        DW NEST                             ;
        DW mFIND                            ;
        DW ze                               ;
        DW z                                ;
        DW qERROR                           ;
        DW DROP                             ;
        DW CFA                              ;
        DW c                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $89,"IMMEDIAT",$C5               ; IMMEDIATE
        DW [COMPILE] - 12                   ;
IMMEDIATE:                                  ;
        DW NEST                             ;
        DW LATEST                           ;
        DW LIT                              ;
        DW $0040                            ;
        DW TOGGLE                           ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DW $C1A8                            ; (   (immediate)
        DW IMMEDIATE - 12                   ;
b:      DW NEST                             ;
        DW LIT                              ;
        DW $0029                            ;
        DW WORD                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DW $C1A7                            ; '   (TICK)   (immediate)
        DW b - 4                            ;
t:      DW NEST                             ;
        DW mFIND                            ;
        DW ze                               ;
        DW z                                ;
        DW qERROR                           ;
        DW DROP                             ;
        DW LITERAL                          ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"FORGE",$D4                  ; FORGET
        DW t - 4                            ;
FORGET: DW NEST                             ;
        DW CURRENT                          ;
        DW a                                ;
        DW CONTEXT                          ;
        DW a                                ;
        DW m                                ;
        DW LIT                              ;
        DW $0018                            ;
        DW qERROR                           ;
        DW t                                ;
        DW DUP                              ;
        DW FENCE                            ;
        DW a                                ;
        DW LESS                             ;
        DW LIT                              ;
        DW $0015                            ; error message 23 = in protected dictionary
        DW qERROR                           ;
        DW DUP                              ;
        DW NFA                              ;
        DW DP                               ;
        DW !                                ;
        DW LFA                              ;
        DW a                                ;
        DW CONTEXT                          ;
        DW a                                ;
        DW !                                ;
        DW sS                               ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$2B,$AD                      ; +-
        DW FORGET - 9                       ;
pm:     DW NEST                             ;
        DW zl                               ;
        DW zBRANCH                          ;
        DW PM1                              ;
        DW MINUS                            ;
PM1:    DW sS                               ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $83,$44,$2B,$AD                  ; D+-
        DW pm - 5                           ;
Dpm:    DW NEST                             ;
        DW zl                               ;
        DW zBRANCH                          ;
        DW DPM1                             ;
        DW DMINUS                           ;
DPM1:   DW sS                               ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $83,$41,$42,$D3                  ; ABS
        DW Dpm - 6                          ;
ABS:    DW NEST                             ;
        DW DUP                              ;
        DW pm                               ;
        DW sS                               ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $84,"DAB",$D3                    ; DABS
        DW ABS - 6                          ;
DABS:   DW NEST                             ;
        DW DUP                              ;
        DW Dpm                              ;
        DW sS                               ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $83,$4D,$41,$D8                  ; MAX
        DW DABS - 7                         ;
MAX:    DW NEST                             ;
        DW OVER                             ;
        DW OVER                             ;
        DW LESS                             ;
        DW zBRANCH                          ;
        DW MAX1                             ;
        DW SWAP                             ;
MAX1:   DW DROP                             ;
        DW sS                               ;

        ;
        ; **-----------------------------------------------------------------------------
        DB $82,$4D,$AA                      ; M*
        DW MAX - 6                          ;
Mf:     DW NEST                             ;
        DW OVER                             ;
        DW OVER                             ;
        DW FXOR                             ;
        DW gR                               ;
        DW ABS                              ;
        DW SWAP                             ;
        DW ABS                              ;
        DW Us                               ;
        DW Rg                               ;
        DW Dpm                              ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,$4D,$AF                      ; M/
        DW Mf - 5                           ;
Mh:     DW NEST                             ;
        DW OVER                             ;
        DW gR                               ;
        DW gR                               ;
        DW DABS                             ;
        DW R                                ;
        DW ABS                              ;
        DW Uh                               ;
        DW Rg                               ;
        DW R                                ;
        DW FXOR                             ;
        DW pm                               ;
        DW SWAP                             ;
        DW Rg                               ;
        DW pm                               ;
        DW SWAP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DW $81AA                            ; *
        DW Mh - 5                           ;
f:      DW NEST                             ;
        DW Mf                               ;
        DW DROP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,$2F,$4D,$4F,$C4              ; /MOD
        DW f - 4                            ;
hMOD:  DW NEST                              ;
        DW gR                               ;
        DW SmgD                             ;
        DW Rg                               ;
        DW Mh                               ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DW $81AF                            ; /
        DW hMOD - 7                         ;
h:  DW NEST                                 ;
        DW hMOD                             ;
        DW SWAP                             ;
        DW DROP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,$4D,$4F,$C4                  ; MOD
        DW h - 4                            ;
MODD:   DW NEST                             ;
        DW hMOD                             ;
        DW DROP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"*/MO",$C4                   ; */MOD
        DW MODD - 6                         ;
fhMOD:  DW NEST                             ;
        DW gR                               ;
        DW Mf                               ;
        DW Rg                               ;
        DW Mh                               ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,$2A,$AF                      ; */
        DW fhMOD - 8                        ;
fh:   DW NEST                               ;
        DW fhMOD                            ;
        DW SWAP                             ;
        DW DROP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"M/MO",$C4                   ; M/MOD
        DW fh - 5                           ;
MhMOD:  DW NEST                             ;
        DW gR                               ;
        DW z                                ;
        DW R                                ;
        DW Uh                               ;
        DW Rg                               ;
        DW SWAP                             ;
        DW gR                               ;
        DW Uh                               ;
        DW Rg                               ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"BY",$C5                     ; BYE
        DW MhMOD - 8                        ;
BYE:    DW $+2                              ; OPTIONAL : location of Monitor entry if there is one
        LDI $00                             ;
        PHI R0                              ;
        LDI $00                             ;
        PLO R0                              ;
        SEX R0                              ;
        SEP R0                              ;
        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"BAC",$CB                    ; BACK
        DW BYE - 6                          ;
BACK:   DW NEST                             ;
        DW c                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,"BEGI",$CE                   ; BEGIN
        DW BACK - 7                         ;
BEGIN:  DW NEST                             ;
        DW qCOMP                            ;
        DW HERE                             ;
        DW o                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,"ENDI",$C6                   ; ENDIF
        DW BEGIN - 8                        ;
ENDIF: DW NEST                              ;
        DW qCOMP                            ;
        DW d                                ;
        DW qPAIRS                           ;
        DW HERE                             ;
        DW SWAP                             ;
        DW !                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C4,"THE",$CE                    ; THEN
        DW ENDIF - 8                        ;
THEN:   DW NEST                             ;
        DW ENDIF                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C2,$44,$CF                      ; DO
        DW THEN - 7                         ;
DO:     DW NEST                             ;
        DW COMPILE                          ;
        DW bDOr                             ;
        DW HERE                             ;
        DW x                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C4,$4C,$4F,$4F,$D0              ; LOOP
        DW DO - 5                           ;
LOOP:   DW NEST                             ;
        DW x                                ;
        DW qPAIRS                           ;
        DW COMPILE                          ;
        DW bLOOPr                           ;
        DW BACK                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,"+LOO",$D0                   ; +LOOP
        DW LOOP - 7                         ;
pLOOP:  DW NEST                             ;
        DW x                                ;
        DW qPAIRS                           ;
        DW COMPILE                          ;
        DW bpLOOPr                          ;
        DW BACK                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,"UNTI",$CC                   ; UNTIL
        DW pLOOP - 8                        ;
UNTIL:  DW NEST                             ;
        DW o                                ;
        DW qPAIRS                           ;
        DW COMPILE                          ;
        DW zBRANCH                          ;
        DW BACK                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C3,$45,$4E,$C4                  ; END
        DW UNTIL - 8                        ;
END:   DW NEST                              ;
        DW UNTIL                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,"AGAI",$CE                   ; AGAIN
        DW END - 6                          ;
AGAIN:  DW NEST                             ;
        DW o                                ;
        DW qPAIRS                           ;
        DW COMPILE                          ;
        DW BRANCH                           ;
        DW BACK                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C6,"REPEA",$D4                  ; REPEAT
        DW AGAIN - 8                        ;
REPEAT:  DW NEST                            ;
        DW gR                               ;
        DW gR                               ;
        DW AGAIN                            ;
        DW Rg                               ;
        DW Rg                               ;
        DW d                                ;
        DW m                                ;
        DW ENDIF                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C2,$49,$C6                      ; IF
        DW REPEAT - 9                       ;
IF:    DW NEST                              ;
        DW COMPILE                          ;
        DW zBRANCH                          ;
        DW HERE                             ;
        DW z                                ;
        DW c                                ;
        DW d                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C4,"ELS",$C5                    ; ELSE
        DW IF - 5                           ;
ELSE:  DW NEST                              ;
        DW d                                ;
        DW qPAIRS                           ;
        DW COMPILE                          ;
        DW BRANCH                           ;
        DW HERE                             ;
        DW z                                ;
        DW c                                ;
        DW SWAP                             ;
        DW d                                ;
        DW ENDIF                            ;
        DW d                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,"WHIL",$C5                   ; WHILE
        DW ELSE - 7                         ;
WHILE:  DW NEST                             ;
        DW IF                               ;
        DW dp                               ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"SPACE",$D3                  ; SPACES
        DW WHILE - 8                        ;
SPACES:  DW NEST                            ;
        DW z                                ;
        DW MAX                              ;
        DW mDUP                             ;
        DW zBRANCH                          ;
        DW SPAX1                            ;
        DW z                                ;
        DW bDOr                             ;
SPAX2:  DW SPACE                            ;
        DW bLOOPr                           ;
        DW SPAX2                            ;
SPAX1:  DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,$3C,$A3                      ; <#
        DW SPACES - 9                       ;
l#:     DW NEST                             ;
        DW PAD                              ;
        DW HLD                              ;
        DW !                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,$23,$BE                      ; #>
        DW l# - 5                           ;
#g:     DW NEST                             ;
        DW DROP                             ;
        DW DROP                             ;
        DW HLD                              ;
        DW a                                ;
        DW PAD                              ;
        DW OVER                             ;
        DW m                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"SIG",$CE                    ; SIGN
        DW #g - 5                           ;
SIGN:   DW NEST                             ;
        DW ROT                              ;
        DW zl                               ;
        DW zBRANCH                          ;
        DW SIGN1                            ;
        DW LIT                              ;
        DW $002D                            ;
        DW HOLD                             ;
SIGN1:  DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DW $81A3                            ; #
        DW SIGN - 7                         ;
#:      DW NEST                             ;
        DW BASE                             ;
        DW a                                ;
        DW MhMOD                            ;
        DW ROT                              ;
        DW LIT                              ;
        DW $0009                            ;
        DW OVER                             ;
        DW LESS                             ;
        DW zBRANCH                          ;
        DW DIG1                             ;
        DW LIT                              ;
        DW $0007                            ;
        DW p                                ;
DIG1:   DW LIT                              ;
        DW $0030                            ;
        DW p                                ;
        DW HOLD                             ;
        DW sS                               ;

        ;
        ;  **-----------------------------------------------------------------------------
        DB $82,$23,$D3                      ; #S
        DW # - 4                            ;
#S:     DW NEST                             ;
DIGS1:  DW #                                ;
        DW OVER                             ;
        DW OVER                             ;
        DW FFOR                             ;
        DW ze                               ;
        DW zBRANCH                          ;
        DW DIGS1                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,$44,$2E,$D2                  ; D.R
        DW #S - 5                           ;
DvR:    DW NEST                             ;
        DW gR                               ;
        DW SWAP                             ;
        DW OVER                             ;
        DW DABS                             ;
        DW l#                               ;
        DW #S                               ;
        DW SIGN                             ;
        DW #g                               ;
        DW Rg                               ;
        DW OVER                             ;
        DW m                                ;
        DW SPACES                           ;
        DW TYPE                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,$2E,$D2                      ; .R
        DW DvR - 6                          ;
vR:   DW NEST                               ;
        DW gR                               ;
        DW SmgD                             ;
        DW Rg                               ;
        DW DvR                              ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,$44,$AE                      ; D.
        DW vR - 5                           ;
Dv:     DW NEST                             ;
        DW z                                ;
        DW DvR                              ;
        DW SPACE                            ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DW $81AE                            ; .   (dot)
        DW Dv - 5                           ;
v:    DW NEST                               ;
        DW SmgD                             ;
        DW Dv                               ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
       DB $83,"2.",$D2                      ; 2.R
       DW v - 4                             ;
tvR:   DW NEST                              ;
       DW z                                 ;
       DW l#                                ;
       DW #                                 ;
       DW #                                 ;
       DW #g                                ;
       DW TYPE                              ;
       DW sS                                ;

        ;
        ;  -----------------------------------------------------------------------------
       DB $83,"4.",$D2                      ; 4.R
       DW tvR - 6                           ;
fvR:   DW NEST                              ;
       DW z                                 ;
       DW l#                                ;
       DW #                                 ;
       DW #                                 ;
       DW #                                 ;
       DW #                                 ;
       DW #g                                ;
       DW TYPE                              ;
       DW sS                                ;

        ;
        ;  -----------------------------------------------------------------------------
       DB $82,"X",$AE                       ;  X.  print top of stack as unsigned hex
       DW fvR - 6                           ;
Xv:    DW NEST                              ;
       DW BASE                              ; save current BASE and switch to HEX
       DW a                                 ;
       DW gR                                ;
       DW HEX                               ;
       DW Uv                                ; print value on stack unsigned
       DW Rg                                ; restore the BASE
       DW BASE                              ;
       DW !                                 ;
       DW sS

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,$55,$AE                      ; U.
        DW Xv - 5                           ;
Uv:    DW NEST                              ;
        DW z                                ;
        DW Dv                               ;
        DW sS                               ;

        ;
        ;  -------------------------------------------------------------------------
        DW $81BF                            ; ?
        DW Uv - 5                           ;
q:   DW NEST                                ;
        DW a                                ;
        DW v                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $82,".",$D3                      ; .S    print stack contents
        DW q - 4                            ;
dStack: DW NEST                             ;
        DW bvdr                             ;
        DB $06, " [ -- "                    ;
        DW SPa, SO, a, m, DUP, ze           ;
        DW zBRANCH, dS1                     ;
        DW bvdr                             ;
        DB $0B, "empty stack"               ;
        DW DROP ,BRANCH, dS3                ;
dS1:    DW d, h, op, o, bDOr                ;
dS2:    DW I, PICK, Xv, bLOOPr, dS2         ;
dS3:    DW bvdr                             ;
        DB $02, " ]"                        ;
        DW sS                               ;
        
        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"VLIS",$D4                   ; VLIST
        DW dStack - 5                            ;
VLIST:  DW NEST                             ;
        DW CR                               ;
        DW LIT                              ;
        DW $0080                            ;
        DW OUT                              ;
        DW !                                ;
        DW CONTEXT                          ;
        DW a                                ;
        DW a                                ;
VLIS1:  DW DUP, Ca, LIT, $001F              ;
        DW FAND, OUT, a, p                  ;
        DW ChL, g, zBRANCH, VL1, CR         ;
        DW LIT, $0002, OUT                  ;
        DW !                                ;
VL1:    DW DUP, IDv                         ;
        DW PFA                              ;
        DW LFA                              ;
        DW a                                ;
        DW DUP                              ;
        DW ze                               ;
        DW qTERMINAL                        ;
        DW FFOR                             ;
        DW zBRANCH                          ;
        DW VLIS1                            ;
        DW DROP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"DUM",$D0                    ; DUMP   ( count addr -- )
        DW VLIST - 8                        ;
DUMP:   DW NEST                             ;
        DW BASE, a, gR, HEX                 ;
        DW DUP, ROT, p, SWAP, bDOr          ;
dmp1:   DW CR, I, fvR, LIT, $03, SPACES, I  ;
        DW LIT, $10, z, bDOr                ;
dmp2:   DW DUP, Ca, SPACE, tvR, op          ;
        DW bLOOPr, dmp2, DROP               ;
        DW qTERMINAL, zBRANCH, dmp3, LEAVE  ;
dmp3:   DW LIT, $10, bpLOOPr, dmp1          ;
        DW Rg,BASE, !                       ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $87,"MESSAG",$C5                 ; MESSAGE
        DW DUMP - 7                         ;
MESSAGE:                                    ;
        DW NEST                             ;
        DW WARNING                          ; no text messages if WARNING = 0
        DW a                                ;
        DW zBRANCH, nomsgtxt                ;
        DW d,Us,DROP                        ;  2 U* DROP LIT[msg_table] + @ COUNT TYPE SPACE
        DW LIT, messages, p,a               ;
        DW COUNT, TYPE, SPACE               ;Fa
        DW BRANCH, xitmsg                   ;

nomsgtxt:                                   ;
        DW bvdr                             ; no message text - just print number
        DB $07," MSG # "                    ;
        DW BASE, a, SWAP, DECIMAL           ;
        DW v, BASE, !                       ;
xitmsg: DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"WAR",$CD                    ; WARM
        DW MESSAGE - 10                     ;
WRM:    DW WARM                             ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"COL",$C4                    ; COLD
        DW WRM - 7                          ;
CLD:    DW COLD                             ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"BLOC",$CB                   ; BLOCK
        DW CLD - 7                          ;
BLOCK:  DW NEST                             ;
    ;    DW o
    ;    DW m
        DW LIT, $0400                       ; 1K block
        DW f                                ;
        DW FIRST                            ;
        DW p                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"LOA",$C4                    ; LOAD
        DW BLOCK-8                          ;
LOAD:   DW NEST                             ;
        DW BLK                              ;
        DW a                                ;
        DW gR                               ;
        DW IN                               ;
        DW a                                ;
        DW gR                               ;
        DW z                                ;
        DW IN                               ;
        DW !                                ;
        DW BhSCR                            ;
        DW f                                ;
        DW BLK                              ;
        DW !                                ;
        DW INTERPRET                        ;
        DW Rg                               ;
        DW IN                               ;
        DW !                                ;
        DW Rg                               ;
        DW BLK                              ;
        DW !                                ;
        DW sS                               ;


        ;  -----------------------------------------------------------------------------
        DB $C3,"--",$BE                     ; -->   ( continue interpretation on next screen ) IMMEDIATE
        DW LOAD - 7                         ;
nxtSCR: DW NEST                             ;
        DW qLOADING, z, IN, !               ; 
        DW BhSCR, BLK, a,  OVER             ;
        DW MODD, m, BLK, p!                  ;  
        DW sS                               ;

 if extra_hardware = 1
  PAGE
 ;=====================================================================================================
;
; ACE CPU CARD HARDWARE SPECIFIC CODE
;
;=====================================================================================================

     ;=============================================================================================================
     ;   Words to access the 6821/6321 Parallel Port chip
     ;    - hardware uses A0 & A1 to select which internal register is addressed when in INP4 or OUT4 is executed so
     ;      the IX must point to a (page) aligned byte at 0x------00, 0x------01, 0x------10, of 0x------11

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P0",$A1                     ; P0!
        DW nxtSCR - 6                           ;
P0!:    DW $+2                            ;
        LDI low PPORT+DELTA + $00           ;
        BR PSTORE                           ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P1",$A1                     ; P1!
        DW P0!-6                            ;
P1!:    DW $+2                            ;
        LDI low PPORT+DELTA + $01           ;
        BR PSTORE                           ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P2",$A1                     ; P2!
        DW P1!-6                            ;
P2!:    DW $+2                            ;
        LDI low PPORT+DELTA + $02           ;
        BR PSTORE                           ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P3",$A1                     ; P3!
        DW P2!-6                            ;
P3!:    DW $+2                            ;
        LDI low PPORT+DELTA + $03           ;
PSTORE: PLO R7                              ;
        LDI high PPORT+DELTA                ;
        PHI R7                              ;
        INC R9                              ;
        LDN R9                              ;
        STR R7                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEX R7                              ;
        OUT 4                               ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P0",$C0                     ; P0@
        DW P3!-6                            ;
P0a:    DW $+2                            ;
        LDI low PPORT+DELTA + $00           ;
        BR PAT                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P1",$C0                     ; P1@
        DW P0a-6                            ;
P1a:    DW $+2                            ;
        LDI low PPORT+DELTA + $01           ;
        BR PAT                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P2",$C0                     ; P2@
        DW P1a-6                            ;
P2a:    DW $+2                            ;
        LDI low PPORT+DELTA + $02           ;
        BR PAT                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"P3",$C0                     ; P3@
        DW P2a - 6                          ;
P3a:    DW $+2                            ;
        LDI low PPORT+DELTA + $03           ;
PAT:    PLO R7                              ;
        LDI high PPORT+DELTA                ;
        PHI R7                              ;
        INC R9                              ;
        INC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        INC R9                              ;
        SEX R7                              ;
        INP 4                               ;
        STR R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        ;  ICM7218 LED Driver Decode
        ;    7       = Decimal point  0=on  1=off
        ;    6,5,4   = digit select  0=right hand  7=left
        ;    3,2,1,0 = code  ( 0-9, - , E, H, L, P, blank )
        ;
        ;   ( char digit# -- )
        ;
        DB $84,"LED",$A1                    ; LED!
        DW  P3a-6
LED!:   DW $+2                            ;
        SEX R7                              ;
        LDI high PPORT+DELTA                ;  R7 -> parrallel port buffer area
        PHI R7                              ;
        LDI low PPORT+DELTA+1               ;
        PLO R7                              ;
        LDI $38                             ; select port A DDR and set CA2 high
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        DEC R7                              ;
        LDI $FF                             ; set DDR A to all outputs
        STR R7                              ;
        OUT 4                               ;
        LDI $3C                             ; reset port A to use output register
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        DEC R7                              ;

        SEX R9                              ;
        DEC R9                              ; mask off lower nibble on data byte for safety
        LDN R9                              ;
        ANI $0F                             ;
        STR R9                              ;
        INC R9                              ; get digit #
        INC R9                              ;
        LDN R9                              ;
        SHL                                 ; convert for 7218 digit addressing
        SHL                                 ;
        SHL                                 ;
        SHL                                 ;
        XRI $80                             ; toggle decimal point digit so that 1=ON
        DEC R9                              ;
        DEC R9                              ;
        ADD                                 ; add data information ( 0 - 15 )
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;

        STR R7                              ; save in data register shadow location
        SEX R7                              ;
        OUT 4                               ; write character to PIA Data register

        LDI $3C                             ; strobe CA2
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        LDI $34                             ;
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;

        LDI $38                             ; reset DDR A to all inputs
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        DEC R7                              ;
        LDI $00                             ;
        STR R7                              ;
        OUT 4                               ;
        LDI $3C                             ;
        STR R7                              ;
        OUT 4                               ;
        SEP RC                              ;

        ;  -----------------------------------------------------------------------------
        DB $89,"LED_CLEA",$D2               ;  ( -- )
        DW LED!-7                           ;
LED_CLEAR:                                  ;
        DW NEST                             ;
        DW LIT, $08, z, bDOr                ;
ledc1:  DW LIT, $0F, I, LED!                ;
        DW bLOOPr, ledc1                    ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $88,"LED_TYP",$C5                ; ( address, char.count -- )
        DW LED_CLEAR-12                     ;
LED_TYPE:                                   ;
        DW NEST                             ;
        DW mDUP, zBRANCH, ledt2             ; skip if char count = 0
        DW LED_CLEAR                        ;
        DW OVER, p,  SWAP, bDOr, LIT, $07   ;
ledt1:  DW I, Ca
        DW DUP, LIT, $2F, g, zBRANCH, leda0 ; jump if less than $30
        DW DUP, LIT, $39, g, zBRANCH, leda7 ; jump if less than $3A

leda0:  DW DUP, LIT, $20, e, zBRANCH, leda1, DROP, LIT, $0F, BRANCH, leda7  ; blank
leda1:  DW DUP, LIT, $50, e, zBRANCH, leda2, DROP, LIT, $0E, BRANCH, leda7  ; P
leda2:  DW DUP, LIT, $4C, e, zBRANCH, leda3, DROP, LIT, $0D, BRANCH, leda7  ; L
leda3:  DW DUP, LIT, $48, e, zBRANCH, leda4, DROP, LIT, $0C, BRANCH, leda7  ; H
leda4:  DW DUP, LIT, $45, e, zBRANCH, leda5, DROP, LIT, $0B, BRANCH, leda7  ; E
leda5:  DW DUP, LIT, $2D, e, zBRANCH, leda6, DROP, LIT, $0A, BRANCH, leda7  ; -
leda6:  DW DROP, BRANCH, leda9                                              ; unprintable

       ;
       ; Warning : byte ahead of 1st char is # of chars in buffer his will trigger 
       ;           an erroneous leading decimal point if there are 46 chars in buffer

leda7:  DW I, o, m, Ca                      ; check if previous character is an (ignored) decimal point
        DW LIT, $2E, e, zBRANCH, leda8      ;
        DW OVER, LIT, $8, FFOR, LED!, o, m  ; toggle the decimal point bit if so
    DW BRANCH, leda9                    ;
leda8:  DW OVER,                 LED!, o, m ; otherwise just output the character with no decimal point

leda9:  DW bLOOPr, ledt1                    ;

ledt2:  DW DROP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,".led",$A2                   ; .lcd" ( address, char.count -- )
        DW LED_TYPE-11                      ;
vledd:  DW NEST                             ;
        DW R, COUNT, DUP, op                ;
        DW Rg, p,  gR, LED_TYPE             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,".LED",$A2                   ;  .LCD" [ IMMEDIATE ]
        DW vledd-8                          ;
vLEDd:  DW NEST                             ;
        DW LIT, $22,  STATE, a              ;
        DW zBRANCH, vLED1                   ;
        DW COMPILE,  vledd                  ;
        DW WORD, HERE, Ca, op, ALLOT        ;
        DW sS                               ;
vLED1:  DW WORD, HERE, COUNT, LED_TYPE      ;
        DW sS


        ;  -----------------------------------------------------------------------------
        ;  Hitachi LM054 LCD display & driver
        ;
        ;    (    n  --  )
        ;
        DB $84,"LCD",$A1                    ; LCD!
        DW vLEDd-8                          ;
LCD!:   DW $+2                            ;
        SEX R7                              ;
        LDI high PPORT+DELTA                ;  R7 -> parrallel port buffer area
        PHI R7                              ;
        LDI low PPORT+DELTA+1               ;
        PLO R7                              ;

        LDI $38                             ; select port A DDR and set CA2 high
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        DEC R7                              ;
        LDI $FF                             ; set DDR A to all outputs
        STR R7                              ;
        OUT 4                               ;
        LDI $3C                             ; reset port A to use output register
        STR R7                              ;
        OUT 4                               ;

        INC R9                              ; get character from stack
        LDN R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R7                              ;
        DEC R7                              ;
        STR R7                              ; save in data register shadow location
        OUT 4                               ; write character to PIA Data register

        INC R7                              ; strobe CB2
        INC R7                              ;
        LDI $3C                             ;
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        LDI $34                             ;
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        DEC R7                              ;
        DEC R7                              ;

        LDI $38                             ; reset DDR A to all inputs
        STR R7                              ;
        OUT 4                               ;
        DEC R7                              ;
        DEC R7                              ;
        LDI $00                             ;
        STR R7                              ;
        OUT 4                               ;
        LDI $3C                             ;
        STR R7                              ;
        OUT 4                               ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $88,"LCD_INI",$D4                ; LCD_INIT
        DW LCD!-7                           ;
LCD_INIT:                                   ;
        DW NEST                             ;
        DW LIT, $30                         ; controller function set - 8 bit data, 1 line, 5x7 dots
        DW LCD!                             ;
        DW LIT, $0C                         ; display on, cursor off, cursor blink off
        DW LCD!                             ;
        DW LIT, $06                         ; cursor increments on write, display shift off
        DW LCD!                             ;
        DW z                                ; clear display
        DW LCD!                             ;
        DW LCD_CLEAR                        ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"LCDBU",$C6                  ;  ( -- a )
        DW LCD_INIT-11                      ;
LCDBUF: DW NEST                             ;
        DW LIT, lcd_buffer + DELTA          ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $8A,"LCD_UPDAT",$C5              ;  ( -- )
        DW LCDBUF-9                         ;
LCD_UPDATE:                                 ;
        DW NEST                             ;
        DW d, LCD!, LIT, $08, z,bDOr        ;
uLCD1:  DW I, LCDBUF, p, Ca                 ;
        DW LIT, $80, FFOR, LCD!             ;
        DW bLOOPr, uLCD1                    ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $89,"LCD_CLEA",$D2               ;  ( -- )
        DW LCD_UPDATE-13                    ;
LCD_CLEAR:                                  ;
        DW NEST                             ;
        DW LIT, $08, z, bDOr                ;
lcdc1:  DW LIT, $20                         ;
        DW I, LCDBUF, p, C!                 ;
        DW bLOOPr, lcdc1                    ;
        DW LCD_UPDATE                       ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,".LC",$C4                    ;  ( char digit# -- )
        DW LCD_CLEAR-12                     ;
vLCD:   DW NEST                             ;
        DW LCDBUF, p, C!                    ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $88,"LCD_TYP",$C5                ; ( address, char.count -- )
        DW vLCD-7                           ;
LCD_TYPE:                                   ;
        DW NEST                             ;
        DW mDUP, zBRANCH, lcdt2             ; skip if char count = 0
        DW LCD_CLEAR
        DW LIT, $02, LCD!                   ;
        DW OVER, p, SWAP, bDOr              ;
lcdt1:  DW I, Ca, LIT, $80, FFOR, LCD!      ;
        DW bLOOPr, lcdt1                    ;
        DW sS                               ;
lcdt2:  DW DROP                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,".lcd",$A2                   ; .lcd" ( address, char.count -- )
        DW LCD_TYPE-11                      ;
vlcdd:  DW NEST                             ;
        DW R, COUNT, DUP, op                ;
        DW Rg, p,  gR, LCD_TYPE             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $C5,".LCD",$A2                   ;  .LCD" [ IMMEDIATE ]
        DW vlcdd-8                          ;
vLCDd:  DW NEST                             ;
        DW LIT, $22,  STATE, a              ;
        DW zBRANCH, vLCD1                   ;
        DW COMPILE,  vlcdd                  ;
        DW WORD, HERE, Ca, op, ALLOT        ;
        DW sS                               ;
vLCD1:  DW WORD, HERE, COUNT, LCD_TYPE      ;
        DW sS                               ;

        ;  -----------------------------------------------------------------------------
        ;  Motorola MC146868 Real Time Clock Chip
        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"RTC",$A1                    ; RTC!     ( data  register -- )    REAL TIME CLOCK
        DW vLCDd-8                            ;
RTC!:   DW $+2                            ;
        SEX R9                              ;
        INC R9                              ;
        OUT 1                               ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        OUT 2                               ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"RTC",$C0                    ; RTC@   ( register -- data )
        DW RTC!-7                           ;
RTCa:   DW $+2                            ;
        SEX R9                              ;
        INC R9                              ;
        OUT 1                               ;
        DEC R9                              ;
        INP 2                               ;
        DEC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"TIME",$C0                   ; TIME@  (  -- hour minute second )
        DW RTCa-7                           ;
TIMEa:  DW $+2                            ;
        INC R9                              ;
        INC R9                              ;
        SEX R3                              ;
        DIS                                 ; interupts off, PC=3 SP=9
        DB  $93                             ;
TM1:    LDI $0A                             ; point to clock update register
        STR R9                              ;
        OUT 1                               ; address it
        DEC R9                              ;
        INP 2                               ;
        SHL                                 ;
        BDF TM1                             ; loop if top bit set = update in process
        LDI $04                             ; point to hour register
        STR R9                              ;
        OUT 1                               ; address it
        DEC R9                              ;
    LDI $00                                 ;
    STR R9                                  ;
        INC R9                              ;
        INP 2                               ; get hour byte
        INC R9                              ;
        LDI $02                             ; point to minute register
        STR R9                              ;
        OUT 1                               ; address it
        DEC R9                              ;
    LDI $00                                 ;
    STR R9                                  ;
    INC R9                                  ;
        INP 2                               ; get minute byte
        INC R9                              ;
        LDI $00                             ; point to seconds register
        STR R9                              ;
        OUT 1                               ; address it
        DEC R9                              ;
    LDI $00                                 ;
    STR R9                                  ;
        INC R9                              ;
        INP 2                               ; get seconds byte
        DEC R9                              ;
        SEX R3                              ;
        RET                                 ; interrups on, PC=3 SP=2
        DB $23                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"DATE",$C0                   ; DATE@ ( -- day )
        DW TIMEa-8                          ;
DATEa:  DW $+2                            ;
        SEX R9                              ;
        INC R9                              ;
        INC R9                              ;
DT1:    LDI $0A                             ; point to clock update register
        STR R9                              ;
        OUT 1                               ; address it
        DEC R9                              ;
        INP 2                               ; get status byte
        SHL                                 ;
        BDF DT1                             ; loop if top bit set = update in process
        LDI $06                             ; point to day register
        STR R9                              ;
        OUT 1                               ; address it
        INP 2                               ; get day byte
        DEC R9                              ;
        LDI $00                             ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $87,"RTC_SE",$D4                 ; ( hour minute second -- )
        DW DATEa-8                          ;
RTC_SET:                                    ;
        DW NEST                             ;
        DW LIT, $0E                         ; set 250 mSec square wave frequency for tic time interrupt
        DW LIT, $0A                         ;
        DW RTC!                             ;
        DW LIT, $42                         ; periodic interrupt enable, binary data, 24 hour mode, daylight savings off ($46=binart $42=BCD)
        DW LIT, $0B                         ;
        DW RTC!                             ;
        DW LIT, $00                         ; set seconds from stack
        DW RTC!                             ;
        DW LIT, $02                         ; set minutes from stack
        DW RTC!                             ;
        DW LIT, $04                         ; set hours from stack
        DW RTC!                             ;
        DW LIT, $0C                         ; read RTC status register C to ensure tic timer interrupt is reset
        DW RTCa                             ;
    DW DROP
        DW sS                               ;

 endi

;=====================================================================================================
;
;     MULTITASKING WORDS
;
;=====================================================================================================

null_task:                                  ; null task does nothing every 64 tics but only if it gets activated via the RUN word
        DW LIT, $40 , TIC                   ;
        DW BRANCH, null_task                ;

        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $83,"RU",$CE                     ; RUN TASK  ( n -- )
 if extra_hardware = 1
        DW RTC_SET-10                       ;
 else
        DW nxtSCR - 6                       ;
 endi
RUN:    DW $+2                              ;
        LDI $D3                             ; TCB status = RUN    (sep r3)
        BR HLT1                             ;

        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $84,"HAL",$D4                    ; HALT TASK
        DW RUN-6                            ;
HALT:   DW $+2                            ;
        LDI $38                             ; TCB status = SKP instruction
HLT1:   SEX R9                              ;
        STR R9                              ; save tasklist requested status (RUN or SKIP) on stack
        INC R9                              ; get task number from statck
        LDN R9                              ;
        ANI $07                             ; mask to prevent buffer overrun if bad task #
        STR R9                              ; save on stack
        LDI high TIMERS+DELTA               ;  R7 -> task timers
        PHI R7                              ;
        LDI low  TIMERS+DELTA               ;
        ADD                                 ; offset into area by task number
        PLO R7                              ;
        LDI $00                             ;>>> OPTIONAL : disable interrupts here ?
        STR R7                              ; stop the task's timer
        LDN R9                              ; get task number again
        SHL                                 ; convert to 16 bit word offset
        STR R9                              ;
        LDI high TASKLIST+DELTA             ;  R7 -> task control list area
        PHI R7                              ;
        LDI low  TASKLIST+DELTA             ;
        ADD                                 ; offset into area by task number *2
        PLO R7                              ;
        DEC R9                              ; pop the desired task status
        LDN R9                              ;
        STR R7                              ; change tasks status in TCB
        DEC R9                              ;>>> OPTIONAL : reenable interrupts here ?
        DEC R9                              ; cleanup stack and exit
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $85,"TASK",$A3                   ; TASK#  returns the current task number to the running task
        DW HALT-7                           ;
TASKa:  DW $+2                            ;
        INC R9                              ; gets the currently active tasks task number
        INC R9                              ;
        LDI $00                             ; push high byte = $00 onto computation stack
        STR R9                              ;
        INC R9                              ;
        GLO R4                              ; get tasker pointer ( i.e. current offset in TASKLIST )
        SMI low (TASKLIST + $02)            ; subtract base of table plus two as R4 was advanced on entry to this task
        SHR                                 ; divide by 2 bytes per entry
        STR R9                              ; push the result to computation stack
        DEC R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $85,"STAR",$D4                   ; START fword   ( task# -- ) puts task start address into TCB
        DW TASKa-8                          ;
STARTa: DW NEST                             ;
        DW mFIND                            ; find word to start
        DW ze                               ;
        DW z                                ; msg 0 = not found
        DW qERROR                           ;
        DW DROP                             ;
        DW SWAP                             ; get task number from stack
        DW LIT, $0006                       ; multiply by offset in task control blocks
        DW Us                               ;
        DW DROP                             ;
        DW LIT, TCB + DELTA + $0004         ; offset to task address field of TCB
        DW p                                ;
        DW !                                ;save address in TCB
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $82,"E",$C9                      ; EI - enable interrupts
        DW STARTa-8                         ;
xEI:     DW $+2                             ; make sure ISR address is in R1 (especially console I/O for Membership Card)
        LDI high ISR                        ; 
        PHI R1                              ; 
        LDI low ISR                         ;
        PLO R1                              ; 
        DEC R2                              ;
        SEX R2                              ;
        LDI $2C                             ;
        STR R2                              ;
        RET                                 ; essentially a SEP RC to re-enter the inner interpreter with X=2 and interrupts enabled

        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $82,"D",$C9                      ; DI  - disable interrupts
        DW xEI-5                             ;
xDI:     DW $+2                             ;
        SEX R2                              ; disable 1802 interrupt 
        DEC R2                              ;
        LDI $23                             ;
        STR R2                              ;
        DIS                                 ; 
        
 if (uart_type = software)
        LDI $00                             ; set R1 to zero to flag interrupts off for console I/O (mostly useful with Membership Card)
        PHI R1                              ;
        PLO R1                              ;
 endi
        SEP RC                              ;
        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $83,"TI",$C3                     ; TIC   ( n --  )
        DW  xDI-5                           ;
TIC:    DW  $+2                             ;
        GLO R4                              ; get task's pointer
        SMI low TASKLIST - low PROM_TABLE - $02   ; subtract table offset + 2
        SHR                                 ; convert from words to get task number
        ADI low TIMERS+DELTA                ; set R7 =  to task timers base address
        PLO R7                              ;
        LDI high TIMERS+DELTA               ;
        PHI R7                              ;
        DEC R4                              ;
        DEC R4                              ;
        INC R9                              ;
        LDN R9                              ; get time interval
        SEX R3                              ;
        DIS                                 ;>>>>> enter critical region : interrupts off - PC=3  SP =3
        DB $33                              ;
        STR R7                              ; save pause interval in task time table
        LDI $38                             ;
        STR R4                              ; set task status to paused
        
 if ( uart_type = software ) or ( uart_type = hardware )   ; FIXME
 
        GHI R1                              ; are interupts allowed ?
        BZ tic0                             ; 
        GLO R1                              ;
        BZ tic0                             ; don't re-enable if not
        RET                                 ;>>>>> interrupts on PC=3  SP=2
        DB  $23                             ;
tic0:                                       ;

 else

 ;       RET                                 ;<<<<<<< exit critical region : iinterrupts on PC=3  SP=2
 ;       DB  $23                             ;

 endi
        DEC R9                              ; clean up and go to tasker for next task
        DEC R9                              ;
        DEC R9                              ;
        INC R4                              ;
        INC R4                              ;
        LBR TASKER                          ;
        

        ;
        ;  -----------------------------------------------------------------------------multi-tasking
        DB $85, "PAUS", $C5                 ; PAUSE 
        DW TIC-6                            ;
PAUSE:  DW $+4                              ;
tsk_repeat:                                 ; I/O triggers a task switch by jumping here if in a busy wait
        DEC RA                              ; nothing ready - reset the routine to run on next outer interpreter pass
        DEC RA                              ;
TASKER: SEX R5                              ;
        GLO RA                              ;  push R0 S0 I (R2,R9,RA) into TCB for this current task
        STXD                                ;
        GHI RA                              ;
        STXD                                ;
        GLO R9                              ;
        STXD                                ;
        GHI R9                              ;
        STXD                                ;
        GLO R2                              ;
        STXD                                ;
        GHI R2                              ;
        STR R5                              ;
        SEP R4                              ; task switch ?  call R4 subroutine to find the next task ready to run
        LDA R4                              ;
        PLO R5                              ;
        LDA R5                              ; restore next tasks R2, R9, and RA from its TCB based on the inline TCB # in the task table
        PHI R2                              ;
        LDA R5                              ;
        PLO R2                              ;
        LDA R5                              ;
        PHI R9                              ;
        LDA R5                              ;
        PLO R9                              ;
        LDA R5                              ;
        PHI RA                              ;
        LDN R5                              ;
        PLO RA                              ;
        SEP RC                              ; return to inner interpreter to activate the next task        

;
; ===========================================================================================

  ;  LIST WORDS - added to FORTH dictionary to avoid needing EDITOR just to print our screens

        ;
        ;  -----------------------------------------------------------------------------
        DB $86,"(LINE",$A9                  ;  (LINE)
        DW PAUSE-8                          ;
bLINEr: DW NEST                             ;
        DW gR                               ;
        DW ChL                              ;
        DW BhBUF                            ;
        DW fhMOD                            ;
        DW Rg                               ;
        DW BhSCR                            ;
        DW f                                ;
        DW p                                ;
        DW BLOCK                            ;
        DW p                                ;
        DW ChL                              ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,".LIN",$C5                   ; .LINE
        DW bLINEr - 9                       ;
dLINE:  DW NEST                             ;
        DW bLINEr                           ;
        DW mTRAILING                        ;
        DW TYPE                             ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"LIS",$D4                    ;  LIST
        DW dLINE - 8                        ;
LIST:   DW NEST                             ;
        DW BASE                             ;
        DW a                                ;
        DW gR                               ;
        DW DECIMAL                          ;
        DW CR                               ;
        DW DUP                              ;
        DW SCR                              ;
        DW !                                ;
        DW bvdr                             ;
        DB $05, "SCR# "                     ;
        DW v                                ;
        DW LIT, $0010                       ;
        DW z                                ;
        DW bDOr                             ;
lst1:   DW CR                               ;
        DW I                                ;
        DW d                                ;
        DW vR                               ;
        DW x                                ;
        DW SPACES                           ;
        DW I                                ;
        DW SCR                              ;
        DW a                                ;
        DW dLINE                            ;
        DW bLOOPr, lst1                     ;
        DW CR                               ;
        DW Rg                               ;
        DW BASE                             ;
        DW !                                ;
        DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $85,"XQUI",$D4                   ; XQUIT
        DW LIST-7                           ;
XQUIT:  DW NEST                             ;
        DW z                                ;
        DW BLK                              ;
        DW !                                ;
        DW [                                ;
        DW RP!                              ;
 if (uart_type = hardware)                  ;
        DW qEF                              ; hardware specific options
        DW LIT, $0008                       ; test EF4 ( dip switch selection for load from RAM disk )
        DW FAND                             ;
        DW zBRANCH                          ; skip RAM disk screen load
        DW XQ2                              ;
 else
        DW QUIT                             ; no extra processing if not useing extra hardware
 endi

        DW FENCE, a, DP, a                  ; assume cold start if DP = FENCE
        DW m, ze, zBRANCH, XQ2              ; don't load on WARM start
        DW CR,bvdr                          ;
        DB 21,"loading from RAM disk"       ;
 if extra_hardware = 1
        DW vlcdd                            ;
        DB $08,"loading>"                   ;
 endi
 if load_address = 0                        ; 
        DW LIT, $FFEF                       ; RAM disk screen -11 on restart when ORIGIN is at $0000
 endi
  if load_address = 1
        DW LIT, $0000                       ; RAM disk screen -?? on restart when ORIGIN is at $4000
 endi
 if load_address = 2
        DW LIT, $001F                       ; RAM disk screen 31 on restart when ORIGIN is at $8000
 endi
        DW LOAD                             ; LOAD from RAM disk
        DW CR,bvdr                          ;
        DB 4,"done"                         ;
 if extra_hardware = 1
        DW vlcdd                            ;
        DB $08,"done    "                   ;
 endi
XQ2:    DW QUIT                             ; QUIT  - never returns

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"A2H",$B1                    ; A2H1  - combines two nibbles on TOS into one byte  - used by Intel Hex Loader
        DW XQUIT-8                          ;
A2H1:   DW $+2                            ;
        GHI R9                              ;
        PHI R8                              ;
        GLO R9                              ;
        PLO R8                              ;
        SEX R9                              ;
        DEC R9                              ;
        LDN R9                              ;
        SMI $3A                             ;
        LDN R9                              ;
        LSNF                                ;
        SMI $07                             ;
        SHL                                 ;
        SHL                                 ;
        SHL                                 ;
        SHL                                 ;
        ANI $F0                             ;
        STR R9                              ;
        INC R8                              ;
        LDN R8                              ;
        SMI $3A                             ;
        LDN R8                              ;
        LSNF                                ;
        SMI $07                             ;
        ANi $0F                             ;
        OR                                  ;
        STXD                                ;
        LDI $00                             ;
        STR R9                              ;
        SEP RC                              ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"QKE",$D9                    ; QKEY - used by Intel Hex Loader
        DW A2H1 -  7                        ;
QKEY:   DW NEST                             ;
        DW KEY                              ;
        DW DUP                              ;
        DW LIT, $001B                       ; aborts on ESC character
        DW e                                ;
        DW zBRANCH, qk1                     ;
        DW ABORT                            ;
qk1:    DW sS                               ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $88,"NEXTBYT",$C5                 ; NEXTBYTE - used by Intel Hex Loader
        DW QKEY - 7                          ; - reads in two ASCII Hex character and converts to binary byte
NEXTBYTE:                                    ;
        DW NEST                              ;
        DW QKEY                              ;
        DW QKEY                              ;
        DW A2H1                              ;
        DW sS                                ;

        ;
        ;  ---------------------------------------------------------------------------
        DB $84,">SC",$D2                     ;  >SCR -  load Forth screen from ASCII text file
        DW NEXTBYTE - 11                     ;
tSCR:   DW NEST                              ;
        DW SPa , SO , a, m, d, m, LIT, $05, qERROR  ; if stack empty there is no screen number
        DW CR, bvdr                          ;
        DB $09,"rx ready>"                   ; send a start message                              ;
sl1:    DW KEY, DUP, EMIT                    ;
        DW LIT, $007E, e, zBRANCH, sl1, CR   ; wait for first ~ (tilde) to indicate start of text
        DW BLOCK                             ; get screen memory address
sl2:    DW KEY, DUP, LIT, $007E              ;
        DW m, zBRANCH, sl7                   ;
        DW DUP, LIT, $000A, e                ;
        DW OVER,  LIT, $000D, e, FFOR        ;
        DW zBRANCH, sl5, DROP                ;
sl3:    DW DUP, LIT, $003F,  FAND            ;
        DW zBRANCH, s16                      ;
        DW LIT, $0020,  OVER,  C!, op        ;
        DW BRANCH, sl3                       ;
sl5:    DW OVER, C!, op                      ;
s16:    DW BRANCH, sl2                       ;
sl7:    DW CR, LIT, $0A, EMIT                ;
        DW DROP, DROP                        ;
        DW bvdr                              ;
        DB $06," <done"                      ; send the end message
        DW CR                                ;
        DW sS                                ;

        ;
        ;  ---------------------------------------------------------------------------
        DB $84,"SCR",$BE                     ;  SCR> -  ( n scr -- )) output Forth screen for saving as ASCII text file
        DW tSCR-7                            ;
xL:     DW NEST                              ;
        DW SPa , SO , a, m, LIT, $04, m, LIT, $05, qERROR ; if stack empty there is no screen number
        DW CR, bvdr                          ;
        DB $09,"tx ready>"                   ; send a start message
        DW KEY, DROP, CR                     ; wait for a keypress
        DW BLOCK, SWAP, LIT, $10, f          ;
        DW z, bDOr                           ;
xx0:    DW DUP, DUP                          ;
        DW z, DUP, ROT, DUP                  ;
        DW LIT, $40, p, SWAP                 ;
        DW bDOr                              ;
xx1:    DW op, I, Ca, LIT, $20, m            ;
        DW zBRANCH, xx2, SWAP, DROP, DUP     ;
xx2:    DW bLOOPr, xx1, DROP, TYPE           ;
        DW CR, LIT, $40, p, bLOOPr,  xx0      ;
        DW DROP,  sS                         ;

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,">I",$C8                               ;  >IH  load from Intel Hex file
        DW xL-7                                       ;
IH:     DW NEST                                       ;
        DW HEX                                        ;
        DW CR, bvdr                                   ;
        DB $09,"rx ready>"                            ; send a start message
ih00:   DW QKEY                                       ; wait for a ":" indicating a line of intel hex data
        DW LIT, $003A                                 ;
        DW e                                          ;
        DW zBRANCH, ih00                              ;
        DW NEXTBYTE                                   ; get record length - two ASCII hex character converted to binary
        DW DUP                                        ;
        DW z, e, zBRANCH, ih02                        ; zero = end of file record done if so
        DW DROP                                       ; clean up and exit ...
        DW CR                                         ;
        DW bvdr                                       ;
        DB $05, "done "                               ;
ih01:   DW QKEY                                       ; wait for rest of end of file record to be received (ignore it)
        DW LIT, $000D                                 ; carriage return at end of line?
        DW e, zBRANCH,ih01                            ; loop back until true
        DW sS                                         ; exit >>
ih02:   DW DUP                                        ; extract the load address from the incomeing data record and start checksum accumulator
        DW NEXTBYTE                                   ; high byte
        DW DUP                                        ;
        DW gR                                         ;
        DW p                                          ;
        DW NEXTBYTE                                   ; low byte
        DW DUP                                        ;
        DW gR, p, Rg                                  ;
        DW Rg                                         ;
        DW LIT, $0100                                 ;
        DW f, p                                       ; multiply high byte by 100 hex and add to low byte to create load address
        DW SWAP                                       ;
        DW NEXTBYTE                                   ; ignore two chars after the address
        DW p                                          ; but add to checksum
        DW ROT, z                                     ;
        DW bDOr                                       ; loop to receive, translate, and store ASCII hex bytes from data record
ih03:   DW gR                                         ;
        DW NEXTBYTE                                   ; get two ASCII hex characters and convert to binary
        DW DUP                                        ;
        DW Rg, p , gR                                 ;add to checksum accumulator
        DW OVER                                       ;
        DW C!                                         ; and save converted binary byte in memory
        DW op                                         ; advance the memory pointer
        DW Rg                                         ;
        DW bLOOPr, ih03                               ; loop back for next character
        DW SWAP                                       ;
        DW DROP                                       ;
        DW NEXTBYTE                                   ; get checksum byte
        DW p                                          ; add to checksum total
        DW LIT, $00FF                                 ; test bottom half of checksum
        DW FAND                                       ;
        DW ze                                         ; if not zero then its a checksum error
        DW zBRANCH, ih04                              ;
        DW bvdr                                       ; checksum okay
        DB $04," ok "                                 ;
        DW BRANCH,ih00                                ; go back and receive next line
ih04:   DW bvdr                                       ;
        DB $09," **bad** "                            ; checksum error
        DW CR                                         ;
        DW BRANCH, ih00                               ; go back and receive next line

        ;
        ;  -----------------------------------------------------------------------------
        DB $83,"IH",$BE                                ;  IH>  save to Intel Hex file
        DW IH - 6                                     ;
IHs:    DW NEST                                        ;
        DW  CR, z, SWAP, bDOr
ih0:    DW  LIT, $3A, EMIT, LIT, $20
        DW  I, LESS, zBRANCH, ih1
        DW  LIT, $20, BRANCH, ih2
ih1:    DW  I
ih2:    DW  DUP, tvR
        DW  OVER, DUP, fvR,  z, tvR
        DW  z, LIT, $100, Uh, p, OVER, p, mROT
        DW  z, bDOr
ih3:    DW  DUP, Ca, DUP, tvR, ROT, p, SWAP, op, bLOOPr, ih3
        DW  SWAP, MINUS, tvR, CR, LIT, -$20, bpLOOPr, ih0
        DW  bvdr
        DB  $0B, ":00000001FF"
        DW  CR, DROP, sS

FORTH_LAST_WORD:                             ; <<***** label for last word in FORTH dictionary
        ;
        ;  -----------------------------------------------------------------------------
        DB $84,"TAS",$CB                    ;    TASK a legacy "do nothing word" that can mark the boundary between applications.
                                            ;    By forgetting TASK and re-compiling, an application can be discarded
                                            ;    in its entirety.
        DW IHs - 6                          ;   Note : currently shows up as "in protected dictionary"
TASK:   DW NEST                             ;
        DW sS                               ;

 if editor=1                                ;
 PAGE 
;================================================================ EDITOR
;
;   Line Editor
;
        ;
        ;  -----------------------------------------------------------------------------editor
        DB $85,"MATC",$C8                   ;  MATCH
        DW FRTH0+DELTA                      ;   <-- link into editor vocabulary header
MATCH:  DW $+2                            ;
        GHI R9                              ;
        PHI R7                              ;
        GLO R9                              ;
        PLO R7                              ;
        DEC R7                              ;
        LDN R7                              ;
        INC R9                              ;
        SEX R9                              ;
        ADD                                 ;
        STXD                                ;
        DEC R7                              ;
        LDN R7                              ;
        ADC                                 ;
        STXD                                ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R7                              ;
        DEC R7                              ;
        DEC R7                              ;
        LDN R7                              ;
        STR R2                              ;
        DEC R2                              ;
        ADD                                 ;
        STXD                                ;
        DEC R7                              ;
        LDN R7                              ;
        STR R2                              ;
        DEC R2                              ;
        ADC                                 ;
        STXD                                ;
        LDN R9                              ;
        ADI $00                             ;
        BR  MATCH02                         ;
MATCH01 DEC R9                              ;
        LDN R9                              ;
        ADI $01                             ;
MATCH02 STXD                                ;
        PLO R8                              ;
        LDN R9                              ;
        ADCI $00                            ;
        STR R9                              ;
        PHI R8                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        LDA R9                              ;
        PHI R7                              ;
        LDN R9                              ;
        PLO R7                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        INC R9                              ;
        SM                                  ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        LDA R9                              ;
        INC R9                              ;
        SMB                                 ;
        BDF MATCH04                         ;
MATCH03 INC R9                              ;
        GLO R8                              ;
        SM                                  ;
        DEC R9                              ;
        GHI R8                              ;
        SMB                                 ;
        BDF MATCH01                         ;
        LDN R7                              ;
        SEX R8                              ;
        XOR                                 ;
        SEX R9                              ;
        BNZ MATCH01                         ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R7                              ;
        INC R8                              ;
        GLO R7                              ;
        XOR                                 ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        DEC R9                              ;
        BNZ MATCH03                         ;
        LDI $FF                             ;
        LSKP                                ;
MATCH04  LDI $00                            ;
        PLO R7                              ;
        INC R9                              ;
        INC R2                              ;
        INC R2                              ;
        SEX R2                              ;
        GLO R8                              ;
        SM                                  ;
        STR R9                              ;
        DEC R9                              ;
        DEC R2                              ;
        GHI R8                              ;
        SMB                                 ;
        SEX R9                              ;
        STXD                                ;
        GLO R7                              ;
        STXD                                ;
        STR R9                              ;
        INC R9                              ;
        INC R9                              ;
        INC R2                              ;
        SEP RC                              ;

        ;  -----------------------------------------------------------------------------editor
EDIT01:                                     ;
   DB $84,"TEX",$D4                         ;  TEXT
   DW MATCH-8                               ;
TEXT:                                       ;
   DW NEST                                  ;
   DW HERE                                  ;
   DW ChL                                   ;
   DW op                                    ;
   DW BLANKS                                ;
   DW WORD                                  ;
   DW HERE                                  ;
   DW PAD                                   ;
   DW ChL                                   ;
   DW op                                    ;
   DW CMOVE                                 ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT02:                                     ;
   DB $84,"LIN",$C5                         ;  LINE
   DW EDIT01                                ;
LINE:                                       ;
   DW NEST                                  ;
   DW DUP                                   ;
   DW LIT, $FFF0                            ;
   DW FAND                                  ;
   DW LIT, $0017                            ;
   DW qERROR                                ;
   DW SCR                                   ;
   DW a                                     ;
   DW bLINEr                                ;
   DW DROP                                  ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT03:                                     ;
   DB $87,"#LOCAT",$C5                      ;  #LOCATE
   DW EDIT02                                ;
#LOCATE:                                    ;
   DW NEST                                  ;
   DW R#                                    ; gets R#
   DW a                                     ;
   DW ChL                                   ;
   DW hMOD                                  ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT04:                                     ;
   DB $85,"#LEA",$C4                        ;  #LEAD
   DW EDIT03                                ;
#LEAD:                                      ;
   DW NEST                                  ;
   DW #LOCATE                               ;
   DW LINE                                  ;
   DW SWAP                                  ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT05:                                     ;
   DB $84,"#LA",$C7                         ;  #LAG
   DW EDIT04                                ;
#LAG:                                       ;
   DW NEST                                  ;
   DW #LEAD                                 ;
   DW DUP                                   ;
   DW gR                                    ;
   DW p                                     ;
   DW ChL                                   ;
   DW Rg                                    ;
   DW m                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT06:                                     ;
   DB $85,"-MOV",$C5                        ;  -MOVE
   DW EDIT05                                ;
mMOVE:                                      ;
   DW NEST                                  ;
   DW LINE                                  ;
   DW ChL                                   ;
   DW CMOVE                                 ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT07:                                     ;
   DB $81,$C8                               ;  H
   DW EDIT06                                ;
H:                                          ;
   DW NEST                                  ;
   DW LINE                                  ;
   DW PAD                                   ;
   DW op                                    ;
   DW ChL                                   ;
   DW DUP                                   ;
   DW PAD                                   ;
   DW C!                                    ;
   DW CMOVE                                 ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT08:                                     ;
   DB $81,$C5                               ;  E
   DW EDIT07                                ;
E:                                          ;
   DW NEST                                  ;
   DW LINE                                  ;
   DW ChL                                   ;
   DW BLANKS                                ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT09:                                     ;
   DB $81,$D3                               ;  S
   DW EDIT08                                ;
S:                                          ;
   DW NEST                                  ;
   DW DUP                                   ;
   DW o                                     ;
   DW m                                     ;
   DW LIT, $000E                            ;
   DW bDOr                                  ;
eS1:
   DW I                                     ;
   DW LINE                                  ;
   DW I                                     ;
   DW op                                    ;
   DW mMOVE                                 ;
   DW LIT, $FFFF                            ;
   DW bpLOOPr, eS1                          ;
   DW E                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT10:                                     ;
   DB $81,$C4                               ;  D
   DW EDIT09                                ;
D:                                          ;
   DW NEST                                  ;
   DW DUP                                   ;
   DW H                                     ;
   DW LIT, $000F                            ;
   DW DUP                                   ;
   DW ROT                                   ;
   DW bDOr                                  ;
sD1:
   DW I                                     ;
   DW op                                    ;
   DW LINE                                  ;
   DW I                                     ;
   DW mMOVE                                 ;
   DW bLOOPr, sD1                           ;
   DW E                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT11:                                     ;
   DB $81,$CD                               ;  M
   DW EDIT10                                ;
M:                                          ;
   DW NEST                                  ;
   DW R#                                    ;
   DW p!                                    ; moves R# by value on stack
   DW CR                                    ;
   DW #LOCATE                               ;
   DW d                                     ;
   DW vR                                    ;
   DW DROP                                  ;
   DW bvdr                                  ;
   DB $03,">  "                             ;
   DW #LEAD                                 ;
   DW TYPE                                  ;
   DW LIT, $005E                            ;
   DW EMIT                                  ;
   DW #LAG                                  ;
   DW TYPE                                  ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT12:                                     ;
   DB $81,$D4                               ;  T
   DW EDIT11                                ;
T:                                          ;
   DW NEST                                  ;
   DW DUP                                   ;
   DW ChL                                   ;
   DW f                                     ; 
   DW R#                                    ;
   DW !                                     ; sets R# to start of requested line #
   DW H                                     ;
   DW z                                     ;
   DW M                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT13:                                     ;
   DB $81,$CC                               ;  L
   DW EDIT12                                ;
L:                                          ;
   DW NEST                                  ;
   DW SCR                                   ;
   DW a                                     ;
   DW LIST                                  ;
   DW z                                     ;
   DW M                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT14:                                     ;
   DB $81,$D2                               ;  R
   DW EDIT13                                ;
aR:                                         ;
   DW NEST                                  ;
   DW PAD                                   ;
   DW op                                    ;
   DW SWAP                                  ;
   DW mMOVE                                 ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT15:                                     ;
   DB $81,$D0                               ;  P
   DW EDIT14                                ;
P:                                          ;
   DW NEST                                  ;
   DW o                                     ;
   DW TEXT                                  ;
   DW aR                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT16:                                     ;
   DB $81,$C9                               ;  I
Ia: DW EDIT15                               ;
   DW NEST                                  ;
   DW DUP                                   ;
   DW S                                     ;
   DW aR                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT17:                                     ;
   DB $83,"TO",$D0                          ;  TOP
   DW EDIT16                                ;
TOP:                                        ;
   DW NEST                                  ;
   DW z                                     ;
   DW R#                                    ; resets # to top of screen
   DW !                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT19:                                     ;
   DB $81,$EE                               ;  n
   DW EDIT17                                ;
n:                                          ;
   DW NEST                                  ;
   DW o                                     ;
   DW SCR                                   ;
   DW p!                                    ;
   DW L                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT20:                                     ;
   DB $81,$E2                               ;  b
   DW EDIT19                                ;
   DW NEST                                  ;
   DW LIT, $FFFF                            ;
   DW SCR                                   ;
   DW p!                                    ;
   DW L                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT21:                                     ;
   DB $85,"CLEA",$D2                        ;
   DW EDIT20                                ;  CLEAR
   DW NEST                                  ;
   DW BLOCK                                 ;
   DW LIT, $0400                            ;
   DW BLANKS                                ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT22:                                     ;
   DB $84,"COP",$D9                         ;  COPY
   DW EDIT21                                ;
   DW NEST                                  ;
   DW BLOCK                                 ;
   DW SWAP                                  ;
   DW BLOCK                                 ;
   DW SWAP                                  ;
   DW LIT, $0400                            ;
   DW CMOVE                                 ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT23:                                     ;
   DB $85,"1LIN",$C5                        ;  1LINE
   DW EDIT22                                ;
oLINE:                                      ;
   DW NEST                                  ;
   DW #LAG                                  ;
   DW PAD                                   ;
   DW COUNT                                 ;
   DW MATCH                                 ;
   DW R#                                    ; moves R#
   DW p!                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT24:                                     ;
   DB $84,"fin",$E4                         ;  eFIND
   DW EDIT23                                ;
eFIND:                                      ;
   DW NEST                                  ;
eF0:                                        ;
   DW LIT, $03FF                            ;
   DW R#                                    ; checks if R# is off current screen
   DW a                                     ;
   DW LESS                                  ;
   DW zBRANCH, eF1                          ;
   DW TOP                                   ;
   DW PAD                                   ;
   DW HERE                                  ;
   DW ChL                                   ;
   DW op                                    ;
   DW CMOVE                                 ;
   DW z                                     ;
   DW ERROR                                 ;
eF1:                                        ;
   DW oLINE                                 ;
   DW zBRANCH, eF0                          ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT25:                                     ;
   DB $86,"DELET",$C5                       ;  DELETE
   DW EDIT24                                ;
DELETE:                                     ;
   DW NEST                                  ;
   DW gR                                    ;
   DW #LAG                                  ;
   DW p                                     ;
   DW R                                     ;
   DW m                                     ;
   DW #LAG                                  ;
   DW R                                     ;
   DW MINUS                                 ;
   DW R#                                    ; moves R#
   DW p!                                    ;
   DW #LEAD                                 ;
   DW p                                     ;
   DW SWAP                                  ;
   DW CMOVE                                 ;
   DW Rg                                    ;
   DW BLANKS                                ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT26:                                     ;
   DB $81,$E6                               ;  f
   DW EDIT25                                ;
af:                                         ;
   DW NEST                                  ;
   DW eFIND                                 ;
   DW z                                     ;
   DW M                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT27:                                     ;
   DB $81,$C6                               ;  F
   DW EDIT26                                ;
F:                                          ;
   DW NEST                                  ;
   DW LIT, $005E                            ;
   DW TEXT                                  ;
   DW af                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT28:                                     ;
   DB $81,$C2                               ;  B
   DW EDIT27                                ;
B:                                          ;
   DW NEST                                  ;
   DW PAD                                   ;
   DW Ca                                    ;
   DW MINUS                                 ;
   DW M                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT29:                                     ;
   DB $81,$D8                               ;  X
   DW EDIT28                                ;
X:                                          ;
   DW NEST                                  ;
   DW o                                     ;
   DW TEXT                                  ;
   DW eFIND                                 ;
   DW PAD                                   ;
   DW Ca                                    ;
   DW DELETE                                ;
   DW z                                     ;
   DW M                                     ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------editor
EDIT30:                                     ;
   DB $84,"TIL",$CC                         ;  TILL
   DW EDIT29                                ;
TILL:                                       ;
   DW NEST                                  ;
   DW #LEAD                                 ;
   DW p                                     ;
   DW o                                     ;
   DW TEXT                                  ;
   DW oLINE                                 ;
   DW ze                                    ;
   DW z                                     ;
   DW qERROR                                ;
   DW #LEAD                                 ;
   DW p                                     ;
   DW SWAP                                  ;
   DW m                                     ;
   DW DELETE                                ;
   DW z                                     ;
   DW M                                     ;
   DW sS                                    ;
        ;
        ;  -----------------------------------------------------------------------------editor
EDITOR_LAST_WORD:                           ;        
EDIT31:                                     ;
   DB $81,$C3                               ;  C
   DW EDIT30                                ;
C:                                          ;
   DW NEST                                  ;
   DW o                                     ;
   DW TEXT                                  ;
   DW PAD                                   ;
   DW COUNT                                 ;
   DW #LAG                                  ;
   DW ROT                                   ;
   DW OVER                                  ;
   DW MIN                                   ;
   DW gR                                    ;
   DW R                                     ;
   DW R#                                    ; moves R# for spreading test at cursor 
   DW p!                                    ;
   DW R                                     ;
   DW m                                     ;
   DW gR                                    ;
   DW DUP                                   ;
   DW HERE                                  ;
   DW R                                     ;
   DW CMOVE                                 ;
   DW HERE                                  ;
   DW #LEAD                                 ;
   DW p                                     ;
   DW Rg                                    ;
   DW CMOVE                                 ;
   DW Rg                                    ;
   DW CMOVE                                 ;
   DW z                                     ;
   DW M                                     ;
   DW sS                                    ;

 endi                                       ; end of if editor = 1



 if assembler = 1                           ;

;============================================================================ ASSEMBLER
;
;     1802 ASSEMBLER
;
;
;  -----------------------------------------------------------------------------

        ;
        ;  -----------------------------------------------------------------------------assembler
CODE:                                       ;
   DB $C4,"COD",$C5                         ;  CODE
   DW FRTH0+DELTA                           ;
   DW NEST                                  ;
   DW qEXEC                                 ; are we executing ? -  this word is used in compile mode only
   DW IN                                    ; get buffer address
   DW a                                     ;
   DW LIT, $0020                            ; space = delimiter
   DW WORD                                  ; read iin the name of the new CODE word being created
   DW IN                                    ; update buffer address
   DW !                                     ;
   DW BLK                                   ; print new words name but only if loaded from SCREEN not console
   DW a                                     ;
   DW zBRANCH,CODE1                         ;
   DW CR,bvdr                               ;
   DB $7," added "                          ;
   DW HERE                                  ; print the new word's name
   DW COUNT                                 ;
   DW TYPE                                  ;
   DW SPACE                                 ;
CODE1:
   DW CREATE                                ; create the dictionary header
   DW ASSEMBLER                             ; switch to assembler vocab
   DW HEX                                   ; and hex numbers
   DW !CSP                                  ; reset stack pointer for "compiler security reasons"
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM001:                                     ;
   DB $84,"STR",$AC                         ;  STR,
   DW CODE                                  ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $0050                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM002:                                     ;
   DB $84,"LDA",$AC                         ;  LDA,
   DW ASM001                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $0040                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM003:                                     ;
   DB $84,"LDN",$AC                         ; LDN,
   DW ASM002                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM004:                                     ;
   DB $84,"INC",$AC                         ;  INC,
   DW ASM003                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $0010                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM005:                                     ;
   DB $84,"DEC",$AC                         ;  DEC,
   DW ASM004                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $0020                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM006:                                     ;
   DB $84,"GLO",$AC                         ;  GLO,
   DW ASM005                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $0080                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM007:                                     ;
   DB $84,"GHI",$AC                         ;  GHI,
   DW ASM006                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $0090                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM008:                                     ;
   DB $84,"PLO",$AC                         ;   PLO,
   DW ASM007                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $00A0                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM009:                                     ;
   DB $84,"PHI",$AC                         ;  PHI,
   DW ASM008                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $00B0                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM010:                                     ;
   DB $84,"SEP",$AC                         ;  SEP,
   DW ASM009                                ;
SEPc:                                       ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $00D0                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM011:                                     ;
   DB $84,"SEX",$AC                         ;  SEX.
   DW ASM010                                ;
   DW NEST                                  ;
   DW LIT, $000F                            ;
   DW FAND                                  ;
   DW LIT, $00E0                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM012:                                     ;
   DB $84,"INP",$AC                         ;  INP,
   DW ASM011                                ;
   DW NEST                                  ;
   DW LIT, $0007                            ;
   DW FAND                                  ;
   DW LIT, $0068                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM013:                                     ;
   DB $84,"OUT",$AC                         ;  OUT,
   DW ASM012                                ;
   DW NEST                                  ;
   DW LIT, $0007                            ;
   DW FAND                                  ;
   DW LIT, $0060                            ;
   DW FFOR                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM014:                                     ;
   DB $85,"STXD",$AC                        ; STXD,
   DW ASM013                                ;
   DW NEST                                  ;
   DW LIT, $0073                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM015:                                     ;
   DB $84,"NOP",$AC                         ;  NOP,
   DW ASM014                                ;
   DW NEST                                  ;
   DW LIT, $00C4                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM016:                                     ;
   DB $84,"SEQ",$AC                         ;  SEQ,
   DW ASM015                                ;
   DW NEST                                  ;
   DW LIT, $007B                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM017:                                     ;
   DB $84,"REQ",$AC                         ;  REQ,
   DW ASM016                                ;
   DW NEST                                  ;
   DW LIT, $007A                            ;
   DW Cc                                    ;
   DW sS                                    ;


        ;  -----------------------------------------------------------------------------assembler
ASM018:                                     ;
   DB $85,"MARK",$AC                        ;  MARK,
   DW ASM017                                ;
   DW NEST                                  ;
   DW LIT, $0079                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM019:                                     ;
   DB $84,"SAV",$AC                         ;  SAV,
   DW ASM018                                ;
   DW NEST                                  ;
   DW LIT, $0078                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM020:                                     ;
   DB $84,"RET",$AC                         ;  RET,
   DW ASM019                                ;
   DW NEST                                  ;
   DW LIT, $0070                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM021:                                     ;
   DB $84,"LDI",$AC                         ;  LDI,
   DW ASM020                                ;
   DW NEST                                  ;
   DW LIT, $00F8                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM022:                                     ;
   DB $85,"LDXA",$AC                        ;  LDXA,
   DW ASM021                                ;
   DW NEST                                  ;
   DW LIT, $0072                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM023:                                     ;
   DB $84,"LDX",$AC                         ;  LDX,
   DW ASM022                                ;
   DW NEST                                  ;
   DW LIT, $00F0                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM024:                                     ;
   DB $84,"IRX",$AC                         ;  IRX,
   DW ASM023                                ;
   DW NEST                                  ;
   DW LIT, $0060                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM025:                                     ;
   DB $84,"IDL",$AC                         ;  IDL,
   DW ASM024                                ;
   DW NEST                                  ;
   DW LIT, $0000                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM026:                                     ;
   DB $85,"SHRC",$AC                        ;  SNRC,
   DW ASM025                                ;
   DW NEST                                  ;
   DW LIT, $0076                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM027:                                     ;
   DB $84,"SHR",$AC                         ;  SHR,
   DW ASM026                                ;
   DW NEST                                  ;
   DW LIT, $00F6                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM028:                                     ;
   DB $84,"SHL",$AC                         ;  SHL,
   DW ASM027                                ;
   DW NEST                                  ;
   DW LIT, $00FE                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM029:                                     ;
   DB $84,"DIS",$AC                         ;  DIS,
   DW ASM028                                ;
   DW NEST                                  ;
   DW LIT, $0071                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM030:                                     ;
   DB $85,"SHLC",$AC                        ;  SHLC,
   DW ASM029                                ;
   DW NEST                                  ;
   DW LIT, $007E                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM031:                                     ;
   DB $84,"AND",$AC                         ;  AND,
   DW ASM030                                ;
   DW NEST                                  ;
   DW LIT, $00F2                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM032:                                     ;
   DB $84,"XOR",$AC                         ;  XOR,
   DW ASM031                                ;
   DW NEST                                  ;
   DW LIT, $00F3                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ;  -----------------------------------------------------------------------------assembler
ASM033:                                     ;
   DB $83,"OR",$AC                          ;  OR,
   DW ASM032                                ;
   DW NEST                                  ;
   DW LIT, $00F1                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM034:                                     ;
   DB $84,"SDB",$AC                         ;  SDB,
   DW ASM033                                ;
   DW NEST                                  ;
   DW LIT, $0075                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM035:                                     ;
   DB $84,"ADD",$AC                         ;  ADD,
   DW ASM034                                ;
   DW NEST                                  ;
   DW LIT, $00F4                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM036:                                     ;
   DB $83,"SM",$AC                          ;  SM,
   DW ASM035                                ;
   DW NEST                                  ;
   DW LIT, $00F7                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM037:                                     ;
   DB $84,"SMB",$AC                         ;  SMB,
   DW ASM036                                ;
   DW NEST                                  ;
   DW LIT, $0077                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM038:                                     ;
   DB $84,"ADC",$AC                         ;  ADC,
   DW ASM037                                ;
   DW NEST                                  ;
   DW LIT, $0074                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM039:                                     ;
   DB $83,"SD",$AC                          ;  SD,
   DW ASM038                                ;
   DW NEST                                  ;
   DW LIT, $00F5                            ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM040:                                     ;
   DB $84,"XRI",$AC                         ;  XRI,
   DW ASM039                                ;
   DW NEST                                  ;
   DW LIT, $00FB                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM041:                                     ;
   DB $84,"ORI",$AC                         ;  ORI,
   DW ASM040                                ;
   DW NEST                                  ;
   DW LIT, $00F9                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM042:                                     ;
   DB $84,"ANI",$AC                         ;  ANI,
   DW ASM041                                ;
   DW NEST                                  ;
   DW LIT, $00FA                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM043:                                     ;
   DB $84,"SMI",$AC                         ;  SMI,
   DW ASM042                                ;
   DW NEST                                  ;
   DW LIT, $00FF                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM044:                                     ;
   DB $84,"ADI",$AC                         ;  ADI,
   DW ASM043                                ;
   DW NEST                                  ;
   DW LIT, $00FC                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM045:                                     ;
   DB $84,"SDI",$AC                         ;  SDI,
   DW ASM044                                ;
   DW NEST                                  ;
   DW LIT, $00FD                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM046:                                     ;
   DB $85,"ADCI",$AC                        ;  ADCI,
   DW ASM045                                ;
   DW NEST                                  ;
   DW LIT, $007C                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM047:                                     ;
   DB $85,"SMBI",$AC                        ;  SMBI,
   DW ASM046                                ;
   DW NEST                                  ;
   DW LIT, $007F                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM048:                                     ;
   DB $85,"SDBI",$AC                        ;  SDBI,
   DW ASM047                                ;
   DW NEST                                  ;
   DW LIT, $007D                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM049:                                     ;
   DB $C4,"NEX",$D4                         ;  NEXT
   DW ASM048                                ;
   DW NEST                                  ;
   DW qEXEC                                 ;
   DW qCSP                                  ;
   DW LIT, $000C                            ; push a SEP RC
   DW SEPc                                  ;
   
;  DW DECIMAL                               ; OPTIONAL : change to decimal and set CONTEXT=CURRENT
;   DW CURRENT                              ; 
;   DW a                                    ;
;   DW CONTEXT                              ;
;   DW !                                    ;

   DW SMUDGE                                ;
   DW sS

        ;
        ; ------------------------------------------------------------------------------assembler
ASM050:                                     ;
   DB $81,$D1                               ; Q
   DW ASM049                                ;
   DW NEST
   DW LIT, $0039                            ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM051:                                     ;
   DB $81,$DA                               ; Z
   DW ASM050                                ;
   DW NEST                                  ;
   DW LIT, $003A                            ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM052:                                     ;
   DB $82,"D",$C6                           ; DF
   DW ASM051                                ;
   DW NEST
   DW LIT, $003B                            ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM053:                                     ;
   DB $83,"NO",$D4                          ; NOT
   DW ASM052                                ;
   DW NEST
   DW LIT, $0008                            ;
   DW m                                     ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM054:                                     ;
   DB $83,"EF",$B1                          ; EF1
   DW ASM053                                ;
   DW NEST                                  ;
   DW LIT, $003C                            ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM055:                                     ;
   DB $83,"EF",$B2                          ; EF2
   DW ASM054                                ;
   DW NEST
   DW LIT, $003D                            ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM056:                                     ;
   DB $83,"EF",$B3                          ; EF3
   DW ASM055                                ;
   DW NEST
   DW LIT, $003E                            ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM057:                                     ;
   DB $83,"EF",$B4                          ; EF4
   DW ASM056                                ;
   DW NEST
   DW LIT, $003F                            ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM058:                                     ;
   DB $86,"?FAUL",$D4                       ; ?FAULT
   DW ASM057                                ;
qFAULT:                                     ;
   DW NEST
   DW OVER                                  ;
   DW LIT, $FF00                            ;
   DW FAND                                  ;
   DW OVER                                  ;
   DW LIT, $FF00                            ;
   DW FAND                                  ;
   DW m                                     ;
   DW LIT                                   ;
   DW 29                                    ;
   DW qERROR                                ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM059:                                     ;
   DB $83,"IF",$AC                          ;  IF,
   DW ASM058                                ;
   DW NEST                                  ;
   DW Cc                                    ;
   DW HERE                                  ;
   DW z                                     ;
   DW Cc                                    ;
   DW d                                     ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM060:                                     ;
   DB $85,"ELSE",$AC                        ;  ELSE,
   DW ASM059                                ;
   DW NEST                                  ;
   DW d                                     ;
   DW qPAIRS                                ;
   DW LIT, $0030                            ;
   DW Cc                                    ;
   DW HERE                                  ;
   DW op                                    ;
   DW SWAP                                  ;
   DW qFAULT                                ;
   DW C!                                    ;
   DW HERE                                  ;
   DW z                                     ;
   DW Cc                                    ;
   DW d                                     ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM061:                                     ;
   DB $86,"ENDIF",$AC                       ;  ENDIF,
   DW ASM060                                ;
   DW NEST                                  ;
   DW qEXEC                                 ;
   DW d                                     ;
   DW qPAIRS                                ;
   DW HERE                                  ;
   DW SWAP                                  ;
   DW qFAULT                                ;
   DW C!                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM062:                                     ;
   DB $86,"BEGIN",$AC                       ;  BEGIN,
   DW ASM061                                ;
   DW NEST                                  ;
   DW qEXEC                                 ;
   DW HERE                                  ;
   DW o                                     ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM063:                                     ;
   DB $86,"UNTIL",$AC                       ;  UNTIL,
   DW ASM062                                ;
   DW NEST                                  ;
   DW SWAP                                  ;
   DW o                                     ;
   DW qPAIRS                                ;
   DW Cc                                    ;
   DW HERE                                  ;
   DW qFAULT                                ;
   DW DROP                                  ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM064:                                     ;
   DB $83,"BR",$AC                          ;  BR,
   DW ASM063                                ;
   DW NEST                                  ;
   DW HERE                                  ;
   DW op                                    ;
   DW qFAULT                                ;
   DW DROP                                  ;
   DW LIT, $0030                            ;
   DW Cc                                    ;
   DW Cc                                    ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM065:                                     ;
   DB $84,"LBR",$AC                         ;  LBR,
   DW ASM064                                ;
   DW NEST                                  ;
   DW LIT, $00C0                            ;
   DW Cc                                    ;
   DW c                                     ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM066:                                     ;
   DB $86,"WHILE",$AC                       ; WHILE,
   DW ASM065                                ;
   DW NEST                                  ;
   DW SWAP                                  ;
   DW o                                     ;
   DW qPAIRS                                ;
   DW Cc                                    ;
   DW HERE                                  ;
   DW z                                     ;
   DW Cc                                    ;
   DW x                                     ;
   DW sS                                    ;

        ;
        ; ------------------------------------------------------------------------------assembler
ASM067:                                     ;
   DB $86,"AGAIN",$AC                       ;  AGAIN,
   DW ASM066                                ;
   DW NEST                                  ;
   DW o                                     ;
   DW qPAIRS                                ;
   DW LIT, $0030                            ;
   DW Cc                                    ;
   DW HERE                                  ;
   DW op
   DW qFAULT                                ;
   DW C!                                    ;
   DW sS                                    ;
   

        ;
        ; ------------------------------------------------------------------------------assembler
ASSEMBLER_LAST_WORD:                        ;
   DB $87,"REPEAT",$AC                      ;  REPEAT,
   DW ASM067                                ;
   DW NEST                                  ;
   DW x                                     ;
   DW qPAIRS                                ;
   DW LIT, $0030                            ;
   DW Cc                                    ;
   DW HERE                                  ;
   DW ROT                                   ;
   DW qFAULT                                ;
   DW Cc                                    ;
   DW op                                    ;
   DW SWAP                                  ;
   DW qFAULT                                ;
   DW C!                                    ;
   DW sS                                    ;

 endi

;====================================================================================================== Error Messages =======

messages:
  dw msg0,  msg1,  msg2,  msg3,  msg4,  msg5
  dw msg6,  msg7,  msg8,  msg9,  msg10, msg11
  dw msg12, msg13, msg14, msg15, msg16
  dw msg17, msg18, msg19, msg20, msg21
  dw msg22, msg23, msg24, msg25, msg26
  dw msg27, msg28, msg29, msg30, msg31

msg0:   db  9,"not found"                           ;
msg1:   db 11,"empty stack"                         ;
msg2:   db 15,"dictionary full"                     ;
msg3:   db 26,"has incorrect address mode"          ;
msg4:   db 12,"isn't unique"                        ;
msg5:   db 27,"too few parameters on stack"         ;
msg6:   db 12,"disc range ?"                        ;
msg7:   db 10,"full stack"                          ;
msg8:   db 12,"disc error !"                        ;
msg9:   db  3,"09?"                                 ;
msg10:  db  3,"10?"                                 ;
msg11:  db  3,"11?"                                 ;
msg12:  db  3,"12?"                                 ;
msg13:  db  3,"13?"                                 ;
msg14:  db  3,"14?"                                 ;
msg15:  db  3,"15?"                                 ;
msg16:  db  3,"16?"                                 ;
msg17:  db 35,"compilation only, use in definition" ;
msg18:  db 14,"execution only"                      ;
msg19:  db 23,"conditionals not paired"             ;
msg20:  db 23,"definition not finished"             ;
msg21:  db 23,"in protected dictionary"             ;
msg22:  db 21,"use only when loading"               ;
msg23:  db 26,"off current editing screen"          ;
msg24:  db 18,"declare vocabulary"                  ;
msg25:  db  3,"25?"                                 ;
msg26:  db  3,"26?"                                 ;
msg27:  db  3,"27?"                                 ;
msg28:  db  3,"28?"                                 ;
msg29:  db  21,"off page branch error"              ;
msg30:  db  14,"divide by zero"                     ;
msg31:  db  3,"31?"                                 ;

;***************************************************************************************************



 if (uart_type = software) and (timer_type = software)
       ;====================================
       ; Generic Demo Task
       ;====================================

cbuf    db 00

demo_task:
        DW LIT, cbuf                    ;
        DW DUP, Ca, op, SWAP, C!        ;
        DW LIT, cbuf                    ;
        DW Ca, LIT, $04, OUTP           ;
        DW LIT, $30 , TIC               ; DW PAUSE
        DW BRANCH, demo_task            ;
 endi

 if (uart_type = software) and (timer_type = hardware)

       ;====================================
       ;  Membership Card Demo Task
       ;====================================

demo_task:
        DW LIT, LED_BUFFER+DELTA, Ca                               ;  push D0 on stack
        DW LIT, LED_BUFFER+DELTA,   DUP, op, Ca, SWAP, C!          ;  D1 -> D0
        DW LIT, LED_BUFFER+DELTA+1, DUP, op, Ca, SWAP, C!          ;  D2 -> D1
        DW LIT, LED_BUFFER+DELTA+2, DUP, op, Ca, SWAP, C!          ;  D3 -> D2
        DW LIT, LED_BUFFER+DELTA+3, DUP, op, Ca, SWAP, C!          ;  D4 -> D3
        DW LIT, LED_BUFFER+DELTA+4, DUP, op, Ca, SWAP, C!          ;  D5 -> D4
        DW LIT, LED_BUFFER+DELTA+5, C!                             ;  D0 -> D5
        DW LIT, $20 , TIC                                          ;
        DW BRANCH, demo_task                                       ;    
 endi

 if (uart_type = hardware)
       ;====================================
       ; ACE CPU Card Demo Task
       ;====================================
demo_task:
        DW LIT, $7F , TIC                     ;
        DW BRANCH, demo_task                ;
 endi
 
  if (example_screens = yes)

;============================================================== Runtime Forth Loadable Source Screen =======


 ORG EXAMPLE_SCREENS

 if (extra_hardware = yes)                                              ;   for extra hardware only - other systems won't want this

  db "ASSEMBLER HEX",$20
  db "CODE splitBCD  9 INC, 9 LDN, 8 PLO, F ANI, 30 ADI, 9 STR,",$20
  db "9 DEC, 8 GLO, SHR, SHR, SHR, SHR, 30 ADI, 9 STR, NEXT",$20
  db ": .clock",$20
  db "LCDBUF OVER OVER 2 + C! 5 + C! TIME@",$20
  db "splitBCD LCDBUF 6 + ! splitBCD LCDBUF 3 + !",$20
  db "splitBCD LCDBUF ! LCD_UPDATE ;",$20
  db ": CLOCK  BEGIN  3A .clock  2 TIC 3A .clock 2 TIC",$20
  db "3A .clock  2 TIC 20 .clock 1 TIC AGAIN ;",$20
  db "FORTH DECIMAL",$20
  db "0 VARIABLE T1 18 ALLOT",$20
  db "0 VARIABLE T2 18 ALLOT",$20
  db "0 VARIABLE TEMP1",$20
  db "0 VARIABLE TEMP2",$20
  db "HEX",$20
  db "FD VARIABLE PB",$20
  db ": PINIT FD PB ! 00 P1! 00 P0! 04 P1!",$20
  db "00 P3!  FF P2! 04 P3! PB @ P2! ;",$20
  db ": scan    03 AND 20 *",$20
  db "PB @ 9F AND + DUP PB ! P2!",$20
  db "PB @ FB AND DUP P2! F7 AND P2! P0@ PB @ P2!",$20
  db "PB @ FB AND DUP P2! EF AND P2!     PB @ P2! ;",$20
  db ": SCAN 2 * DUP 2 scan SWAP T2 + ! 0 scan SWAP T1 + ! ;",$20
  db "DECIMAL",$20
  db ": T1->F   482 U* -1 D+- 136690. D+ 1000  U/ SWAP DROP TEMP1 ! ;",$20
  db ": T2->F   709 U* -1 D+- 127706. D+ 1000  U/ SWAP DROP TEMP2 ! ;",$20
  db ": SCANNER PINIT BEGIN 10 0 DO I SCAN LOOP",$20
  db "0 20 0 DO 1 TIC I T1 + @ + 2 +LOOP 10 /  T1->F",$20
  db "0 20 0 DO 1 TIC I T2 + @ + 2 +LOOP 10 /  T2->F AGAIN ;",$20
  db "HEX",$20
  db ": .T1 TEMP1 @ 0A /MOD 6 LED! 5 LED! ;",$20
  db ": .T2 TEMP2 @ 0A /MOD 2 LED! 1 LED! ;",$20
  db ": THERMOMETER PINIT BEGIN .T1 18 TIC .T2 08 TIC AGAIN ;",$20
  db ": BLINKER  BEGIN  QON 2 TIC QOFF 8 TIC 0 UNTIL ;",$20
  db "2 HALT 2 START SCANNER 2 RUN",$20
  db "3 HALT 3 START THERMOMETER 3 RUN",$20
  db "4 HALT 4 START CLOCK 4 RUN",$20
  db "5 HALT 5 START BLINKER 5 RUN",$20
  db " ;S",$20

 else

                                                                            ; alternative screen of sample 1802 assembler code for membership card

  db "HEX  0A VARIABLE byte_align                                     "
  db ': check   20 -FIND IF DROP DUMP ELSE ." not found" ENDIF ;      '
  db ": ALGN HERE 100 + FF00 AND HERE - byte_align @ - ALLOT ;        "
  db "ASSEMBLER                                                       "
  db "ALGN CODE test1  Z IF,  SEQ,   ELSE,  REQ,  ENDIF, IRX,  NEXT   "
  db "ALGN CODE test2  BEGIN,  SEQ,  Z UNTIL, IRX,  NEXT              "
  db "ALGN CODE test3  BEGIN,  SEQ,    AGAIN, IRX,  NEXT              "
  db "ALGN CODE test4  BEGIN,  SEQ,  Z WHILE,  REQ, REPEAT, IRX, NEXT "
  db "ALGN CODE >leds 9 INC, 9 LDN, STXD, IRX, 4 OUT,                 "
  db "     9 DEC, 9 DEC, 9 DEC, 9 DEC, NEXT                           "
  db "FORTH                                                                "
  db ";S                                                              "
  db "                                                                "
  db "                                                                "
  db "                                                                "
  db "                                                                "

 endi
 
;=========================================================================================================================
 endi 

     END                                     ;
