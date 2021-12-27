%macro print 2
  pusha
  push dword %1
  push dword %2
  call printf
  add esp, 8
  popa
%endmacro

%macro printOp 2
  pusha
  push dword %2
  push dword %1
  call printOperand
  add esp, 8
  popa
%endmacro

%macro write 2
    pushad
    mov eax,4 ;system call number (sys_write)
    mov ebx,1 ;stdout
    mov ecx, %1 ;message to write
    mov edx, %2 ;message length
    int 0x80
    popad
%endmacro

%macro is_operand? 0
  mov ecx, 0
  %%.next_digit:
  cmp byte [input+ecx], 10
  jz %%.operand_code
  inc ecx
  jmp %%.next_digit
  %%.operand_code:
  pushad    
  call create_operand
  push_op eax       
  popad   
%endmacro


%macro fprint 3
  pusha
  push dword %1
  push dword %2
  push dword [%3]
  call fprintf
  add esp, 12
  popa
%endmacro


%macro is_operand_numofdigit? 0
  mov ecx, 0
  %%.next_digit:
  cmp byte[numofhexa+ecx], 0
  jz %%.operand_code
  inc ecx
  jmp %%.next_digit
  %%.operand_code:
  pushad 
  mov ebx, 0
  mov al,byte [numofhexa]
  add_link_to_head ebx, al
  push_op ebx       
  popad
%endmacro

%macro overflow? 0
  pushad
  mov eax,dword [O_Stacksize]
  cmp dword [current_size],eax
  jnz %%.no_overflow
  write OverMsg,OverMsglen
  popad
  jmp calcLoop
  %%.no_overflow:
  popad
%endmacro

%macro push_op 1
  overflow?
  push ecx
  mov ecx, dword [current_size]
  mov [Operand_Stack+4*ecx], %1
  inc dword [current_size]
  pop ecx
%endmacro

%macro CheckSufArgs 1
  cmp dword[current_size], %1
  jae %%.heree
  write InsMsg,InsMsglen
    mov esp, ebp 
  pop ebp      
  ret            
  %%.heree:
%endmacro

%macro pop_op 1
  CheckSufArgs 1
  push ecx
  mov ecx, dword[current_size]
  mov %1, [Operand_Stack+4*(ecx-1)]
  dec dword[current_size]
  pop ecx
%endmacro

%macro allocate_link 0    
  pusha
  push dword 1
  push dword 5
  call calloc
  mov [return], eax
  add esp, 8
  popa
%endmacro

%macro free_link 1
  pusha
  push %1
  call free
  add esp, 4
  popa
%endmacro

%macro free_list 1
  cmp %1, 0
  jz %%.end_free
    mov ecx, %1
    mov %1, dword [%1+1]
    free_link ecx
  %%.end_free:
%endmacro

%macro add_link 3
    sub %2,48                    
    cmp %2, 10 
    js %%.FirstByte
		sub %2, 7
	%%.FirstByte:
    cmp %3, 0
    jz %%.SecondByte
    sub %3,48
    cmp %3, 10
    js %%.SecondByte
	sub %3, 7
	%%.SecondByte:
	shl %2,4 				 
	or %2,%3 		 	
    add_link_to_head %1, %2 
%endmacro

%macro add_link_to_head 2 
  push ecx
  mov ecx, %1     
  allocate_link     
  mov %1, dword [return]    
  mov byte[%1],%2             
  mov dword [%1+1],ecx
  pop ecx
%endmacro

%macro appendLink 2     
  push ecx
  allocate_link             
  mov ecx, dword [return]  
  mov byte[ecx],%2          
  mov dword [ecx+1], 0 
  mov dword [%1+1], ecx
  mov %1, ecx
  pop ecx
%endmacro

%macro makeLengthsSuit 2
  pusha
  push %2
  push %1
  call dealWithLengths
  add esp, 8
  popa
  mov ecx, dword [toSuitLen]
%endmacro

section .rodata                                                                
    Format_Hex:db "%X",10,0
    Format_Hex1:db "%hhX",0                                         
    Format_string:db "%s",0                                              
    calcMsg: db "calc: ",0
    calcMsglen equ $- calcMsg
    OverMsg: db "Error: Operand Stack Overflow", 10, 0
    OverMsglen equ $- OverMsg 
    InsMsg: db "Error: Insufficient Number of Arguments on Stack", 10, 0
    InsMsglen equ $- InsMsg
    msgDebug: db "Debug is ON...",10,0
    msgDebugLen equ $-msgDebug
    msgStkSizeErr: db "Error: Stack size must be greater than 2.",10,0
    msgStkSizeErrLen equ $-msgStkSizeErr
    msgNewSize: db "New Size is ON...",10,0
    msgNewSizeLen equ $-msgNewSize
    newLine: db 10, 0
    newLineLen equ $-newLine

section .data
    O_Stacksize: dd 5 
    count_op:dd 0
    current_size:dd 0
    return:dd 0
    toSuitLen:dd 0
    debug_mode_byte:db 0
    input_length:dd 0
    count_digit:dd 0

section .bss
    Operand_Stack:resd 20
    input:resb 82
    numofhexa:resb 2
    
section .text
    align 16
    global main
    extern stderr
    extern stdin
    extern stdout
    extern printf
    extern fprintf
    extern malloc
    extern calloc
    extern free
    extern fgets

main:
    push ebp
    mov ebp, esp
    mov ecx, dword[esp+8]           ; ecx = argc
    mov ebx, dword[esp+12]          ; ebx = argv
    cmp ecx,1
    je to_callmycalc 
    Args:
        add ebx,4
        mov edx, [ebx]             
        mov cl, byte[edx]              
        cmp cl, 45                    
        jnz itsNewSize
        write msgDebug,msgDebugLen
        mov [debug_mode_byte],byte 1
        dec ecx
        cmp ecx,1
        je to_callmycalc
        jmp Args
        itsNewSize:
            cmp byte [debug_mode_byte], 1
            jnz here1
            write msgNewSize,msgNewSizeLen
            here1:
            pushad
            mov ecx,0
            mov cl, [edx+1]
            push ecx 
            mov cl,[edx]
            push ecx
            call cnvrtToHex
            add esp,8
            mov [O_Stacksize], al
            popad
            call verifyStkSize
            dec ecx
            cmp ecx,1
            je to_callmycalc
            jmp Args

        verifyStkSize:
            mov ecx, [O_Stacksize]
            cmp ecx, 2
            jbe endht         
    to_callmycalc: 
        pushad                ; backup registers
        call myCalc          ; call the function myCalc
    returnAddress:
      push eax
      push Format_Hex
      call printf
      add esp,8
      popad                 ; restore registers

  finishProgram:
    mov ebx,0     
    mov eax,1
    int 0x80

myCalc:
    push ebp      
    mov ebp, esp 
    push 4
    mov eax, [O_Stacksize] ;eax = stack size
    push eax   
    call calloc        
    add esp, 8
    mov dword[Operand_Stack], eax
  calcLoop:
      write calcMsg,calcMsglen
      push dword [stdin]
      push 82
      push input
      call fgets
      add esp, 12
      mov al, byte[input]
      Quit_op:
        cmp byte [input],113
        je endCalcLoop
      Add_op: 
        cmp byte [input], 43
        je is_add
      P_op: 
        cmp byte [input], 112
        je is_p
      D_op: 
        cmp byte [input], 100
        je is_d
      And_op: 
        cmp byte [input], 38
        je is_and
      Or_op: 
        cmp byte [input], 124
        je is_or
      N_op:
        cmp byte [input],110
        je is_n
      its_number:
        jmp is_num
      
      is_add:
        inc dword[count_op]
        call Plus_f
        jmp calcLoop
      is_p:
        inc dword[count_op]
        call PopAndPrintFunc
        jmp calcLoop
      is_d:
        inc dword[count_op]
        call DuplicateFunc
        jmp calcLoop
      is_and:
        inc dword[count_op]
        call AndFunc
        jmp calcLoop
      is_or:
        inc dword[count_op]
        call Or_function
        jmp calcLoop
      is_n:
        inc dword[count_op]
        call NumOfHexDigit
        jmp calcLoop
      is_num:
          call is_operand?
          jmp calcLoop
  endCalcLoop:
  mov eax, dword [count_op]     ; return count_op in eax
  mov esp, ebp     
  pop ebp          
  ret               
create_operand:
  push ebp           
  mov ebp, esp       
  mov eax, 0
  mov ecx, 0
  mov edx, 0
  removeLZ:   ;delete the leading zeros
    cmp byte [input+ecx] , '0'
    jnz lengthCount
    inc ecx
    jmp removeLZ
  lengthCount:
    mov edx, ecx
    cmp byte [input+ecx], 10
    jz .endOfInput
    .next_digit:
      cmp byte [input+ecx], 10
      jz convert_to_hex_list
      inc ecx
      jmp .next_digit
      .endOfInput:
        dec edx
convert_to_hex_list:
  mov dword[input_length],edx
  mov ebx, 0                    
  mov eax, ecx                
  sub eax, edx
  test eax, 1                    
  jz .digits_Loop                
  mov al, '0'          
  mov ah, byte [input+edx]     
  add_link ebx, al,ah            
  inc edx                      
  .digits_Loop:                  
      cmp edx, ecx
      je .return_op
      mov al, byte [input+edx]   
      inc edx                    
      mov ah, byte [input+edx] 
      inc edx                 
      add_link ebx, al, ah        
  jmp .digits_Loop                 
  .return_op:
    mov eax, ebx                  
    mov esp, ebp      
    pop ebp          
    ret               

dealWithLengths:
  push ebp           
  mov ebp, esp       
  mov ebx, dword [ebp+8]
  mov edx, dword [ebp+12]
  mov dword[toSuitLen], 0
    .digits_Loop:
        cmp ebx, 0
        jz .FirstDigit
        cmp edx, 0
        jz .SecondDigit
        inc dword [toSuitLen]
        mov eax, ebx
        mov ebx, dword [ebx+1]
        mov ecx, edx
        mov edx, dword [edx+1]
      jmp .digits_Loop
    .FirstDigit:
        mov ebx, eax
      .dealWithFirst:
        cmp edx, 0
        jz .here3
        inc dword [toSuitLen]
        appendLink ebx, 0
        mov edx, dword [edx+1]
      jmp .dealWithFirst
    .SecondDigit:
        mov edx, ecx
      .dealWithSecond:
        cmp ebx, 0
        jz .here3
        inc dword [toSuitLen]
        appendLink edx, 0
        mov ebx, dword [ebx+1]
      jmp .dealWithSecond
    .here3:
      mov esp, ebp     
      pop ebp          
      ret               

Plus_f:
    push ebp           
    mov ebp, esp       
    CheckSufArgs 2      
    pop_op ebx              
    pop_op edx              
    makeLengthsSuit ebx, edx
    push ebx     
    push edx      
    .digits_Loop:
      mov al, byte[ebx]  
      mov ah, byte[edx] 
      adc al, ah
      mov byte [ebx], al
      mov eax, ebx 
      mov ebx, dword [ebx+1]
      mov edx, dword [edx+1]
    loop .digits_Loop, ecx
    jnc .end_operation         
      mov ebx, eax
      appendLink ebx, 1 
    .end_operation:
      pop edx
      free_list edx
      pop ebx
      push_op ebx 
      mov esp, ebp      
      pop ebp           
      ret             

PopAndPrintFunc:
  push ebp           
  mov ebp, esp       
    CheckSufArgs 1               
    pop_op ebx                      
    printOp ebx, stdout         
    fprint newLine, Format_string, stdout
    free_list ebx                  
    mov esp, ebp     
  pop ebp      
  ret     


printOperand:
  push ebp       
  mov ebp, esp       
    mov ebx, dword [ebp+8]                
    mov edx, dword [ebp+12]       
    mov ecx, 0   
    .digits_Loop:
      cmp ebx,0
      jz .print_list
      mov al, byte[ebx]      
      push eax                  
      mov ebx, dword [ebx+1] 
      inc ecx              
    jmp .digits_Loop
    .print_list:
      pop eax
      dec ecx
      fprint eax, Format_Hex1, edx
      cmp ecx,0
      jz .end_operation
    .next_two_digits:
      pop eax       
      fprint eax,Format_Hex1, edx    
    loop .next_two_digits, ecx 
    .end_operation:
      mov esp, ebp      
      pop ebp          
      ret               


DuplicateFunc:
  push ebp          
  mov ebp, esp       
    CheckSufArgs 1
    pop_op edx                
    push_op edx              
    mov al, byte[edx]
    mov ebx, 0
    add_link_to_head ebx, al
    push ebx       
    .digits_Loop:
      mov edx, dword [edx+1]
      cmp edx, 0
      jz .end_operation
      mov al,byte[edx]      
      appendLink ebx, al  
    jmp .digits_Loop
    .end_operation:
      pop ebx
      push_op ebx     
      mov esp, ebp      
      pop ebp          
      ret              


AndFunc:
    push ebp       
  mov ebp, esp      
    CheckSufArgs 2 
    pop_op ebx      
    pop_op edx          
    makeLengthsSuit ebx, edx
    push ebx          
    mov dword[toSuitLen], ebx 
    push edx 
    .digits_Loop:
      mov al,byte[edx]
      and byte [ebx], al
      jz .same_msb
        mov dword[toSuitLen], ebx
      .same_msb:
      mov ebx, dword [ebx+1]     
      mov edx, dword [edx+1]       
    loop .digits_Loop, ecx
    .end_operation:
      pop edx
      free_list edx
      mov ebx, dword[toSuitLen]
      mov edx, ebx
      mov edx, dword [edx+1]
      free_list(edx)   
      mov dword [ebx+1], 0
      pop ebx       
      push_op ebx 
      mov esp, ebp     
      pop ebp          
      ret              


Or_function:
    push ebp      
  mov ebp, esp       
    CheckSufArgs 2   
    pop_op ebx          
    pop_op edx    
    makeLengthsSuit ebx, edx
    push ebx         
    mov dword[toSuitLen], ebx  
    push edx     
    .digits_Loop:
        mov al,byte[edx]
        or byte [ebx], al
        jz .same_msb
        mov dword[toSuitLen], ebx 
    .same_msb:
        mov ebx, dword [ebx+1]        
        mov edx, dword [edx+1]          
        loop .digits_Loop, ecx
    .end_operation:
        pop edx
        free_list edx
        mov ebx, dword[toSuitLen]
        mov edx, ebx
        mov edx, dword [edx+1]      
        free_list(edx)       
        mov dword [ebx+1],0
        pop ebx                 
        push_op ebx   
        mov esp, ebp     
        pop ebp          
        ret              


NumOfHexDigit:
    push ebp          
    mov ebp, esp
    CheckSufArgs 1
    pop_op edx
    mov ebx,0
    get_next_Node:
    mov al, byte [edx] ;data
    mov edx, dword [edx+1]
    cmp edx,0
    je end_count
    inc dword[count_digit]
    inc dword[count_digit]
    jmp get_next_Node
    end_count:
      mov eax,0
      inc dword[count_digit]
      inc dword[count_digit]
      mov al,byte[count_digit]
      mov dword[numofhexa],eax
      is_operand_numofdigit?
      mov dword[count_digit],0
      mov dword[numofhexa],0
      mov esp, ebp      
      pop ebp          
      ret   

endht:
  cmp byte [debug_mode_byte], 1
  jnz here
  write msgStkSizeErr,msgStkSizeErrLen
  here:
  mov	eax,1	
  int	0x80


cnvrtToHex:
    push ebp
    mov ebp,esp
    mov eax, 0
    mov ecx, 0
    mov al, byte[ebp+8] ;
    mov bh, byte[ebp+12] ;
    sub al,48                    
    cmp al, 10 
    js FirstByte
		sub al, 7
	FirstByte:
    cmp bh, 0
    jz SecondByte
    mov bl,16
    mul bl
    sub bh,48
    cmp bh, 10
    js SecondByte
	sub bh, 7
	SecondByte:
    add ax,cx
    mov esp,ebp
    pop ebp
    ret