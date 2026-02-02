.MODEL small         
.STACK 100h          

.DATA
    prompt      db 'OSShell> $'             ; Shell prompt string
    buffer      db 255, ?, 255 dup(0)       ; Input buffer for user commands
    cmd_buffer  db 20 dup(0)                ; Buffer to store a single parsed command
    newline     db 13,10,'$'                ; Newline string for printing

    ; Command keywords
    cmd_exit    db 'exit',0
    cmd_dir     db 'dir',0
    cmd_echo    db 'echo',0
    cmd_help    db 'help',0
    cmd_mkdir   db 'mkdir',0
    cmd_cd      db 'cd',0
    cmd_rmdir   db 'rmdir',0
    cmd_touch   db 'touch',0
    cmd_type    db 'type',0
    cmd_cls     db 'cls',0
    cmd_rm      db 'rm',0
    cmd_edit    db 'edit',0
    cmd_copy    db 'copy',0
    cmd_rename  db 'mv',0
    cmd_if      db 'if',0
    kw_exist    db 'exist',0
    cmd_bgcolor db 'bgcolor', 0
    cmd_fgcolor db 'fgcolor',0
    cmd_cursor  db 'cursor',0

    ; Buffers for various file operations
    type_done   db 13,10,'$'                ; Newline after type command
    type_buf    db 128 dup(?)               ; Buffer to hold data from file for "type"
    copy_buf    db 128 dup(?)               ; Buffer for copying files
    rename_buf  db 64 dup(?)                ; Buffer for renaming files

    ; Output messages
    help_msg db 'Available commands:',13,10
             db 'dir    - List directory',13,10
             db 'exit   - Quit shell',13,10
             db 'help   - Show help',13,10
             db 'cls    - Clear screen',13,10
             db 'echo <message>  - Display message',13,10
             db 'mkdir <directory name> - Create directory',13,10
             db 'cd  <directory name>   - Change Directory',13,10
             db 'rmdir <directory name>  - Remove Directory',13,10
             db 'touch <file name> - File created/updated',13,10
             db 'type <file name>   - View file contents',13,10
             db 'rm   <file name>  - Delete file',13,10
             db 'edit <file name>  - Create / edit text file',13,10
             db 'copy <file name>  - Copy file from source to destination',13,10
             db 'mv   <file name>  - Rename file',13,10
             db 'if exist <file name>   - Check for file',13,10 
             db 'cursor n  - 0=block, 1=underline, 2=small bar',13,10
             db 'fgcolor <0 to 15> - Change text color',13,10
             db 'bgcolor <0 to 7> - Change background color',13,10, '$'

    mkdir_msg   db 'Directory created',13,10,'$'
    error_msg   db 'Error!',13,10,'$'
    cd_msg      db 'Directory changed',13,10,'$'
    rmdir_msg   db 'Directory removed',13,10,'$'
    touch_msg   db 'File created/updated',13,10,'$'
    rm_msg      db 'File deleted',13,10,'$'
    edit_prompt db 'Enter lines (blank line to save):',13,10,'$'
    edit_saved  db 'File saved',13,10,'$'
    copy_msg    db 'File copied',13,10,'$'
    rename_msg  db 'Renamed successfully',13,10,'$'
    if_found_msg db 'File found',13,10,'$'
    if_nf_msg    db 'File not found',13,10,'$'
    bg_msg      db 'Background color changed',13,10,'$'
    bg_errmsg   db 'Usage: bgcolor <0 to 7>',13,10,'$'
    fg_msg       db 'Foreground color changed',13,10,'$'
    fg_errmsg    db 'Usage: fgcolor <0 to 15>',13,10,'$'
    cur_msg     db 'Cursor size changed',13,10,'$'
    cur_errmsg  db 'Usage: cursor 0|1|2',13,10,'$'

    ; Directory listing
    DTA         db 128 dup(0)               ; Disk Transfer Area for DOS
    dir_mask    db '*.*',0                  ; Mask to list all files

.CODE

main PROC
    mov ax, @data              ; Load address of data segment into AX
    mov ds, ax                 ; Set DS (data segment) to point to data
    mov es, ax                 ; Set ES as well (used for some DOS ops)

    ; Tell DOS where to store file info for directory operations
    mov ah, 1Ah                ; DOS function: set DTA
    lea dx, DTA                ; DX = address of our DTA buffer
    int 21h                    ; Call DOS interrupt

main_loop:
    mov ah, 09h                ; DOS function: print string
    lea dx, prompt             ; Load prompt string address
    int 21h                    ; Show "OSShell>"

    mov ah, 0Ah                ; DOS function: buffered input
    lea dx, buffer             ; DX = address of input buffer
    int 21h                    ; Read user input into buffer

    call process_input         ; Process the command user typed

    jmp main_loop              ; Repeat forever

main ENDP

process_input PROC

    ; --- 1.  Find out how many characters the user typed ----

    mov si, offset buffer + 1   ; SI = address of length byte (buffer[1])
    mov cl, [si]                ; CL = number of characters the user typed
    xor ch, ch                  ; CX = length (CH = 0, CL already set)

    ; --- 2.  Put a 0 at the end of the user’s text (make it a C‑string) ---

    mov si, offset buffer + 2   ; SI = address of first typed char (buffer[2])
    add si, cx                  ; SI = address just after the last char
    mov byte ptr [si], 0        ; Write 0 (NULL) so text ends cleanly

    ; --- 3.  Print a blank line so output appears below user’s command ----

    mov ah, 09h                 ; DOS function 09h = print string
    lea dx, newline             ; DX = pointer to CR/LF string
    int 21h                     ; Call DOS to print newline

    ; --- 4.  Copy *only the first word* (the command) into cmd_buffer -----

    mov si, offset buffer + 2   ; SI = start of user text again
    lea di, cmd_buffer          ; DI = where we want to store the command

copy_loop:                      ; Loop: copy letters until we hit space or end
    lodsb                       ; AL = *char pointed by SI*   , SI++
    cmp al, ' '                 ; Is it a space?  (end of command word)
    je  done_copy               ; Yes → stop copying
    cmp al, 0                   ; Is it already NULL? (no more chars)
    je  done_copy               ; Yes → stop copying
    stosb                       ; Store AL into cmd_buffer, DI++
    jmp copy_loop               ; Go copy next character

done_copy:
    mov byte ptr [di], 0        ; Put 0 at end of cmd_buffer (now ASCIIZ)

    ; --- 5.  Move SI to the start of the argument part -------------------

    cmp byte ptr [si], ' '      ; Is SI currently pointing at a space?
    jne args_ready              ; If not a space → already at first argument

skip_space_loop:                ; Otherwise skip one or more spaces
    lodsb                       ; Move SI forward (skip char)
    cmp al, ' '                 ; Still a space?
    je  skip_space_loop         ; Keep skipping until non‑space
args_ready:
    dec si                      ; Step back one so SI now points at the first character of arguments (or NULL)

    lea si, cmd_buffer
    lea di, cmd_exit
    call strcmp
    je do_exit

    lea si, cmd_buffer
    lea di, cmd_dir
    call strcmp
    je do_dir

    lea si, cmd_buffer
    lea di, cmd_echo
    call strcmp
    je do_echo

    lea si, cmd_buffer
    lea di, cmd_help
    call strcmp
    je do_help

    lea si, cmd_buffer
    lea di, cmd_mkdir
    call strcmp
    je do_mkdir

    lea si, cmd_buffer
    lea di, cmd_cd
    call strcmp
    je do_cd

    lea si, cmd_buffer
    lea di, cmd_rmdir
    call strcmp
    je  do_rmdir

    lea si, cmd_buffer
    lea di, cmd_touch
    call strcmp
    je  do_touch

    lea si, cmd_buffer
    lea di, cmd_type
    call strcmp
    je  do_type

    lea si, cmd_buffer
    lea di, cmd_rm
    call strcmp
    je  do_rm

    lea si, cmd_buffer
    lea di, cmd_edit
    call strcmp
    je  do_edit

    lea si, cmd_buffer
    lea di, cmd_copy
    call strcmp
    je  do_copy

    lea si, cmd_buffer
    lea di, cmd_rename
    call strcmp
    je  do_mv

    lea si, cmd_buffer
    lea di, cmd_if
    call strcmp
    je  do_if

    lea si, cmd_buffer
    lea di, cmd_bgcolor
    call strcmp
    je  do_bgcolor

    lea si, cmd_buffer
    lea di, cmd_fgcolor
    call strcmp
    je  do_fgcolor

    lea si, cmd_buffer
    lea di, cmd_cursor
    call strcmp
    je  do_cursor


    lea si, cmd_buffer
    lea di, cmd_cls
    call strcmp
    je do_cls

    mov ah, 09h
    lea dx, error_msg
    int 21h
    ret

; ============================================================
; If user typed  exit
; ============================================================
do_exit:
    mov ax, 4C00h          ; AX = 4C00h   → DOS “Exit program” function
    int 21h                ; Call DOS → Program ends, returns to DOS prompt

; ============================================================
; If user typed  dir
; ============================================================
do_dir:
    call dir_cmd           ; Run our routine that lists the files
    ret                    ; Go back to the main shell loop

; ============================================================
; If user typed  echo  (prints a message)
; ============================================================
do_echo:
    mov si, offset buffer + 2   ; SI points to the whole user line
                                ; (the command and its text)

; We need to skip the word “echo” itself and find the space before the text
skip_command_echo:
    lodsb                   ; AL = next character, SI++ moves forward
    cmp al, ' '             ; Is this char a space?
    je  args_found_echo     ; Yes → we reached the message text
    cmp al, 0               ; Is this the end of the line?
    je  echo_error          ; Yes → user typed only “echo” with nothing after
    jmp skip_command_echo   ; Not a space, keep skipping letters of “echo”

; We’re now at the start of the message the user wants to print
args_found_echo:
    call skip_spaces_custom ; Skip any extra spaces before the real text
    call echo_cmd           ; Print everything from SI onward
    ret                     ; Done, return to shell

; If user typed “echo” with nothing to show, display an error
echo_error:
    mov ah, 09h             ; DOS print‑string function
    lea dx, error_msg       ; DX points to the string “Error!”
    int 21h                 ; Show the error message
    ret                     ; Return to shell

; ============================================================
; If user typed  help
; ============================================================
do_help:
    call help_cmd           ; Show the big help message
    ret                     ; Return to shell

; ===============================
; If user typed: mkdir <folder>
; ===============================
do_mkdir:
    mov si, offset buffer + 2      ; SI points to start of user input (skips length bytes)
    call skip_command_name         ; Skip the command word "mkdir"
    call skip_spaces_custom        ; Skip any spaces after "mkdir"
    call mkdir_cmd                 ; Run your function to make the directory
    ret                            ; Return to the shell loop

; ===============================
; If user typed: cls
; ===============================
do_cls:
    call cls_cmd                   ; Clear the screen using your cls_cmd function
    ret                            ; Return to shell loop

; ===============================
; If user typed: cd <folder>
; ===============================
do_cd:
    mov si, offset buffer + 2      ; SI points to user input (e.g., "cd foldername")
    call skip_command_name         ; Skip the command word "cd"
    call skip_spaces_custom        ; Skip any spaces between "cd" and the folder name
    call cd_cmd                    ; Change to the specified folder
    ret                            ; Return to shell

; ===============================
; If user typed: rmdir <folder>
; ===============================
do_rmdir:
    mov si, offset buffer + 2      ; SI points to start of input
    call skip_command_name         ; Skip past "rmdir"
    call skip_spaces_custom        ; Skip spaces to get to folder name
    call rmdir_cmd                 ; Run command to remove folder
    ret                            ; Return to shell

; ===============================
; If user typed: touch <filename>
; ===============================
do_touch:
    mov si, offset buffer + 2      ; SI points to user input
    call skip_command_name         ; Skip past "touch"
    call touch_cmd                 ; Create or update the file
    ret                            ; Return to shell

; ===============================
; If user typed: type <filename>
; ===============================
do_type:
    mov si, offset buffer + 2      ; SI points to user input
    call skip_command_name         ; Skip past "type"
    call type_cmd                  ; Show contents of the file
    ret                            ; Return to shell

; ===============================
; If user typed: rm <filename>
; ===============================
do_rm:
    mov si, offset buffer + 2       ; SI points to user input (skips metadata)
    call skip_command_name          ; Skip past the command word "rm"
    call rm_cmd                     ; Call your delete file function
    ret                             ; Return to shell

; ===============================
; If user typed: edit <filename>
; ===============================
do_edit:
    mov si, offset buffer + 2       ; Point to user input string
    call skip_command_name          ; Skip past "edit"
    call edit_cmd                   ; Call your text editor function
    ret                             ; Return to shell

; ===============================
; If user typed: copy <file1> <file2>
; ===============================
do_copy:
    mov si, offset buffer + 2       ; Point to user input
    call skip_command_name          ; Skip past "copy"
    call copy_cmd                   ; Call function to copy file1 to file2
    ret                             ; Return to shell

; ===============================
; If user typed: rename <old> <new>
; ===============================
do_mv:
    mov si, offset buffer + 2       ; Point to user input
    call skip_command_name          ; Skip past "rename"
    call rename_cmd                 ; Call function to rename file
    ret                             ; Return to shell

; ===============================
; If user typed: if <some condition>
; ===============================
do_if:
    mov si, offset buffer + 2       ; Point to input after buffer header
    call skip_command_name          ; Skip the word "if"
    call if_cmd                     ; Call your custom if-handler
    ret                             ; Return to shell

; ===============================
; If user typed: bgcolor <code>
; ===============================
do_bgcolor:
    mov si, offset buffer + 2       ; Point to input
    call skip_command_name          ; Skip past "bgcolor"
    call bgcolor_cmd                ; Change the background color
    ret                             ; Return to shell

; ===============================
; If user typed: fgcolor <code>
; ===============================
do_fgcolor:
    mov si, offset buffer + 2       ; Point to input
    call skip_command_name          ; Skip past "fgcolor"
    call fgcolor_cmd                ; Change the foreground/text color
    ret                             ; Return to shell

; ===============================
; If user typed: cursor <on/off>
; ===============================
do_cursor:
    mov si, offset buffer + 2       ; Point to input
    call skip_command_name          ; Skip past "cursor"
    call cursor_cmd                 ; Show or hide cursor
    ret                             ; Return to shell

; ===============================
; End of input processing
; ===============================
process_input ENDP                 ; Marks the end of the input processing procedure

dir_cmd PROC
    ; Step 1: Ask DOS to find the first file (any file)
    mov ah, 4Eh              ; Function to find the first file
    mov cx, 37h              ; Look for all types of files (normal, hidden, etc.)
    lea dx, dir_mask         ; Set the search pattern (like "*. *")
    int 21h                  ; Call DOS
    jc dir_error             ; If there's an error (no file found), go to error

dir_loop:
    ; Step 2: Copy the file name from DOS memory into our buffer

    mov si, offset DTA + 1Eh ; SI points to where the file name is stored

    lea di, cmd_buffer       ; DI points to our own buffer to store the name
    mov cx, 13               ; We'll copy max 13 characters (like "file.txt")

copy_filename:
    lodsb                    ; Load one character from the file name into AL
    cmp al, 0                ; Is it the end of the name?
    je finish_copy           ; If yes, stop copying
    stosb                    ; Store that character into our buffer
    loop copy_filename       ; Repeat until 13 characters or end of name

finish_copy:
    mov byte ptr [di], 0     ; Add a 0 at the end to mark the end of the string

    ; Step 3: Show the file name on screen
    lea dx, cmd_buffer       ; Point to the file name in our buffer
    mov ah, 09h              ; Function to print string
    int 21h                  ; Call DOS to print

    ; Print a new line (move to next line)
    mov ah, 09h
    lea dx, newline
    int 21h

    ; Step 4: Ask DOS for the next file in the list
    mov ah, 4Fh              ; Function to find the next file
    int 21h                  ; Call DOS
    jnc dir_loop             ; If found, go back and print it too

    ret                      ; Done, return

dir_error:
    ; Step 5: Show error if no files found
    mov ah, 09h
    lea dx, error_msg
    int 21h
    ret
dir_cmd ENDP

echo_cmd PROC
    ; DO NOT change SI (it already points to the message after "echo")

    call skip_spaces_custom       ; Skip any spaces before the actual message

    cmp byte ptr [si], 0          ; Check if the message is empty (end of string)
    je echo_err                   ; If it’s empty, go to error

    call print_string             ; Print the message starting from SI

    ; Print a newline after the message (move to next line)
    mov ah, 09h
    lea dx, newline
    int 21h
    ret                           ; Done

echo_err:
    ; Show error message if nothing to echo
    mov ah, 09h
    lea dx, error_msg
    int 21h
    ret
echo_cmd ENDP

help_cmd PROC
    ; AH = 09h tells DOS to print a string
    mov ah, 09h

    ; DX = address of the help message to display
    lea dx, help_msg

    ; Call DOS interrupt to show the message on screen
    int 21h

    ; Return from this function
    ret
help_cmd ENDP

mkdir_cmd PROC
    ; Skip any extra spaces before the folder name
    call skip_spaces_custom

    ; If there is nothing after the command (no folder name), show error
    cmp byte ptr [si], 0
    je mkdir_err

    ; DOS function 39h: Create directory
    mov ah, 39h

    ; DX should point to the folder name (SI already has it)
    mov dx, si

    ; Call DOS to make the directory
    int 21h

    ; If it failed (carry flag set), jump to error
    jc mkdir_err

    ; If successful, print success message
    mov ah, 09h
    lea dx, mkdir_msg
    int 21h
    ret

mkdir_err:
    ; If anything went wrong, show the error message
    mov ah, 09h
    lea dx, error_msg
    int 21h
    ret
mkdir_cmd ENDP

cd_cmd PROC
    ; Skip extra spaces after typing "cd"
    call skip_spaces_custom     

    ; Check if the user typed anything after "cd"
    cmp byte ptr [si], 0        
    je cd_err                   ; If not, show error and exit

    ; Copy the folder name into cmd_buffer
    lea di, cmd_buffer         ; DI will store the folder name
copy_cd:
    mov al, [si]               ; Load one character from user input
    cmp al, 13                 ; Is it Enter key? (end of input)
    je null_term               ; If yes, stop copying
    cmp al, 0                  ; Is it already 0? (end of string)
    je null_term               ; If yes, stop copying
    mov [di], al               ; Copy character to buffer
    inc si                     ; Move to next input character
    inc di                     ; Move to next buffer location
    jmp copy_cd                ; Repeat until end

null_term:
    mov byte ptr [di], 0       ; Add 0 to end of string (null terminate)

    lea dx, cmd_buffer         ; DX = folder name to change to
    mov ah, 3Bh                ; DOS function 3Bh = change directory
    int 21h                    ; Call DOS to change directory
    jc cd_err                  ; If it fails, go to error

    ; If directory change was successful, show success message
    mov ah, 09h
    lea dx, cd_msg
    int 21h
    ret                        ; End of function

cd_err:
    ; If directory change failed, show error message
    mov ah, 09h
    lea dx, error_msg
    int 21h
    ret                        ; End of function
cd_cmd ENDP

rmdir_cmd PROC
    call skip_spaces_custom         ; Skip any spaces after "rmdir"

    cmp  byte ptr [si], 0           ; Check if user typed folder name
    je   rmdir_err                  ; If not, go show error message

    mov  ah, 3Ah                    ; DOS function 3Ah: Remove directory
    mov  dx, si                     ; DX points to folder name (entered by user)
    int  21h                        ; Call DOS to try deleting folder
    jc   rmdir_err                  ; If it fails (folder not found or not empty), show error

    mov  ah, 09h                    ; DOS function 09h: Print string
    lea  dx, rmdir_msg              ; DX points to success message
    int  21h                        ; Show success message
    ret                             ; Return from procedure

rmdir_err:
    mov  ah, 09h                    ; DOS print string function
    lea  dx, error_msg              ; DX = error message location
    int  21h                        ; Show error message
    ret                             ; Return
rmdir_cmd ENDP

touch_cmd PROC
    call skip_spaces_custom            ; Skip any spaces after the word "touch"
    cmp  byte ptr [si], 0              ; Check if the user typed a filename
    je   touch_err                     ; If nothing typed, jump to error

    ; Copy the typed file name into a buffer (cmd_buffer)
    lea  di, cmd_buffer                ; DI points to destination buffer
copy_name:
    lodsb                              ; Load next character from SI into AL
    cmp  al, 0                         ; End of input?
    je   stored_ok                     ; If yes, jump to finish
    cmp  al, ' '                       ; If space found, also stop
    je   stored_ok
    stosb                              ; Store AL into cmd_buffer[DI], move DI forward
    jmp  copy_name                     ; Repeat the loop
stored_ok:
    mov  byte ptr [di], 0              ; Add null terminator at end of filename

    ; Try to create the file using DOS function 3Ch
    mov  ah, 3Ch                       ; DOS: Create File
    xor  cx, cx                        ; Set file attributes to normal
    lea  dx, cmd_buffer                ; DX points to the filename
    int  21h                           ; Interrupt to call DOS
    jc   open_existing                 ; If error (file already exists), try opening it

    jmp  close_file                    ; If created successfully, go close it

open_existing:
    ; If file already exists, open it in write mode (to update timestamp)
    mov  ah, 3Dh                       ; DOS: Open file
    mov  al, 2                         ; Mode 2 = read/write
    lea  dx, cmd_buffer                ; DX points to the file name
    int  21h                           ; Call DOS
    jc   touch_err                     ; If still fails, show error
    ; AX = file handle

close_file:
    mov  bx, ax                        ; Save file handle to BX
    mov  ah, 3Eh                       ; DOS: Close file
    int  21h                           ; Call DOS to close the file

    mov  ah, 09h                       ; Print success message
    lea  dx, touch_msg                 ; DX = pointer to message
    int  21h
    ret                                ; Return

touch_err:
    mov  ah, 09h                       ; Print error message
    lea  dx, error_msg
    int  21h
    ret
touch_cmd ENDP

type_cmd PROC
    ; Start: SI points to user input after the word "type"
    call skip_spaces_custom           ; Skip any spaces after "type"

    cmp  byte ptr [si], 0             ; Check if user typed a file name
    je   type_error                   ; If nothing typed, show error

    ; -------- Copy filename to cmd_buffer --------------------
    lea  di, cmd_buffer               ; DI → buffer to store file name
copy_fname:
    lodsb                             ; Load next character into AL from [SI], SI++
    cmp  al, 0                        ; End of string?
    je   fname_done
    cmp  al, ' '                      ; Stop if space
    je   fname_done
    stosb                             ; Save character to [DI], DI++
    jmp  copy_fname                   ; Repeat until end or space

fname_done:
    mov  byte ptr [di], 0             ; Add NULL (end) to the file name

    ; -------- Try to open the file in read-only mode ---------
    mov  ah, 3Dh                      ; DOS function 3Dh: open file
    mov  al, 0                        ; Mode 0 = read only
    lea  dx, cmd_buffer               ; DX points to the file name
    int  21h                          ; Call DOS
    jc   type_error                   ; If failed, show error
    mov  si, ax                       ; Save file handle in SI

read_loop:
    mov  ah, 3Fh                      ; DOS function 3Fh: read file
    lea  dx, type_buf                 ; Read data into type_buf
    mov  cx, 128                      ; Read 128 bytes at a time
    mov  bx, si                       ; BX = file handle
    int  21h                          ; Call DOS
    jc   type_error                   ; If read fails, show error
    or   ax, ax                       ; AX = number of bytes read
    jz   close_ok                     ; If 0 bytes read → end of file

    ; -------- Print read bytes to screen (stdout) ------------
    mov  cx, ax                       ; Number of bytes to write
    mov  ah, 40h                      ; DOS function 40h: write to screen
    mov  bx, 1                        ; File handle 1 = screen
    lea  dx, type_buf                 ; Data to print
    int  21h                          ; Call DOS
    jmp  read_loop                    ; Read more

close_ok:
    ; Print a newline after file contents
    mov  ah, 09h
    lea  dx, type_done                ; Message with newline
    int  21h

    ; Close the file
    mov  bx, si                       ; File handle
    mov  ah, 3Eh                      ; DOS function 3Eh: close file
    int  21h
    ret                               ; Done

type_error:
    ; Print error if anything failed
    mov  ah, 09h
    lea  dx, error_msg
    int  21h
    ret
type_cmd ENDP

rm_cmd PROC
    call skip_spaces_custom            ; Skip any spaces after "rm"

    cmp  byte ptr [si], 0              ; Check if there's anything typed after "rm"
    je   rm_err                        ; If not, show error message and return

    ; ---- Copy the filename from user input to cmd_buffer ----
    lea  di, cmd_buffer                ; DI now points to the start of cmd_buffer

copy_name:
    lodsb                              ; Load one character from [SI] into AL and move SI to next
    cmp  al, 0                         ; Is it end of string?
    je   name_done                     ; If yes, stop copying
    cmp  al, ' '                       ; Is it a space (which separates more input)?
    je   name_done                     ; If yes, stop copying
    stosb                              ; Store the character into [DI] and move DI forward
    jmp  copy_name                     ; Repeat for next character

name_done:
    mov  byte ptr [di], 0              ; Add a null (0) at the end to mark end of filename

    ; ---- Try to delete the file using DOS function ----
    mov  ah, 41h                       ; AH = 41h means "delete file" in DOS
    lea  dx, cmd_buffer                ; DX points to the filename (cmd_buffer)
    int  21h                           ; Call DOS to delete the file
    jc   rm_err                        ; If error (Carry Flag set), go to error message

    ; ---- File deleted successfully ----
    mov  ah, 09h                       ; DOS print string function
    lea  dx, rm_msg                    ; DX points to message like "File deleted successfully"
    int  21h                           ; Show success message
    ret                                ; Return from procedure

rm_err:
    ; ---- Something went wrong ----
    mov  ah, 09h                       ; DOS print string function
    lea  dx, error_msg                ; DX points to error message like "Invalid input" or "File not found"
    int  21h                           ; Show the error message
    ret                                ; Return from procedure
rm_cmd ENDP

edit_cmd PROC
    ;; — STEP 1: Read the file name from user input —

    call skip_spaces_custom            ; Skip any spaces after the "edit" command
    cmp  byte ptr [si], 0              ; Check if user typed anything after "edit"
    je   edit_err                      ; If nothing was typed, show error and exit

    lea  di, cmd_buffer                ; DI will store the filename

copy_name:
    lodsb                              ; Load one character from input (SI) to AL, then SI++
    cmp  al, 0                         ; End of string?
    je   name_ok
    cmp  al, ' '                       ; Space (end of filename)?
    je   name_ok
    stosb                              ; Store AL into DI (i.e. copy character)
    jmp  copy_name                     ; Keep copying

name_ok:
    mov  byte ptr [di], 0              ; End filename with a 0 (null terminator)

    ;; — STEP 2: Create or overwrite the file —

    mov  ah, 3Ch                       ; DOS function 3Ch: Create a file
    xor  cx, cx                        ; CX = 0 (normal file attributes)
    lea  dx, cmd_buffer                ; DX points to the filename
    int  21h                           ; Call DOS to create the file
    jc   edit_err                      ; If creation fails, show error and exit
    mov  si, ax                        ; Save the file handle (returned in AX) to SI

    ;; — STEP 3: Ask user to type lines for the file —

    mov  ah, 09h                       ; Print string function
    lea  dx, edit_prompt               ; DX = pointer to "Start typing..." message
    int  21h

edit_loop:
    ;; — STEP 4: Take input line from user —

    mov  byte ptr [buffer], 254        ; Set max input length to 254 characters
    mov  ah, 0Ah                       ; DOS buffered input function
    lea  dx, buffer                    ; DS:DX points to the input buffer
    int  21h                           ; Call DOS to read a line

    mov  al, [buffer + 1]              ; AL = number of characters actually typed
    cmp  al, 0                         ; Did user press Enter without typing anything?
    je   save_file                     ; If yes, finish and save the file

    ;; — STEP 5: Write the line to the file —

    mov  ah, 0                         ; Clear AH
    mov  cx, ax                        ; CX = number of characters to write
    lea  dx, buffer + 2                ; DS:DX points to typed text (skip length bytes)
    mov  bx, si                        ; BX = file handle (from earlier)
    mov  ah, 40h                       ; DOS function 40h: Write to file
    int  21h

    ;; — STEP 6: Add a new line (CR + LF) to the file —

    mov  ah, 40h                       ; DOS write function
    mov  bx, si                        ; File handle
    lea  dx, newline                   ; Pointer to CR+LF (new line)
    mov  cx, 2                         ; Write 2 bytes
    int  21h

    jmp  edit_loop                     ; Go back to take next line from user

save_file:
    ;; — STEP 7: Close the file —

    mov  bx, si                        ; BX = file handle
    mov  ah, 3Eh                       ; DOS function 3Eh: Close file
    int  21h

    ;; — STEP 8: Show confirmation message —

    mov  ah, 09h                       ; Print string function
    lea  dx, edit_saved               ; Message: "File saved"
    int  21h
    ret

edit_err:
    ;; — If something went wrong, show error message —

    mov  ah, 09h                       ; Print string
    lea  dx, error_msg                 ; Error message
    int  21h
    ret
edit_cmd ENDP

copy_cmd PROC
    call skip_spaces_custom            ; Skip any spaces after "copy"
    cmp  byte ptr [si], 0              ; Is there anything typed after "copy"?
    je   copy_err                      ; If not, show error and exit

    ; -------- Read the source filename from user input --------
    lea  di, cmd_buffer                ; Store source filename in cmd_buffer

src_loop:
    lodsb                              ; Load a character from input (SI → AL), SI++
    cmp  al, 0                         ; End of input?
    je   copy_err                      ; If yes, show error
    cmp  al, ' '                       ; If space, end of filename
    je   src_done
    stosb                              ; Store character in DI and increment DI
    jmp  src_loop

src_done:
    mov  byte ptr [di], 0              ; End filename with a null (ASCIIZ string)

    call skip_spaces_custom            ; Skip spaces before destination name
    cmp  byte ptr [si], 0              ; Is destination filename present?
    je   copy_err                      ; If not, show error

    ; -------- Read destination filename into cmd_buffer+64 ----
    lea  di, cmd_buffer+64             ; Store destination filename in a separate spot

dst_loop:
    lodsb                              ; Load character from input
    cmp  al, 0
    je   dst_done
    cmp  al, ' '
    je   dst_done
    stosb                              ; Save character in DI
    jmp  dst_loop

dst_done:
    mov  byte ptr [di], 0              ; End destination filename string with 0

    ; -------- Open source file for reading --------------------
    mov  ah, 3Dh                        ; DOS function 3Dh = open file
    mov  al, 0                          ; Open mode 0 = read
    lea  dx, cmd_buffer                 ; DX points to source file name
    int  21h
    jc   copy_err                       ; If failed, go to error
    mov  di, ax                         ; Save source file handle to DI

    ; -------- Create destination file -------------------------
    mov  ah, 3Ch                        ; DOS function 3Ch = create file
    xor  cx, cx                         ; Normal file attributes
    lea  dx, cmd_buffer+64              ; DX points to destination file name
    int  21h
    jc   close_src_err                  ; If fail, close source and go to error
    mov  si, ax                         ; Save destination file handle to SI

copy_loop:
    ; -------- Read from source file --------------------------
    mov  bx, di                         ; BX = source file handle
    mov  ah, 3Fh                        ; DOS function 3Fh = read file
    mov  cx, 128                        ; Number of bytes to read
    lea  dx, copy_buf                   ; DX points to buffer
    int  21h
    jc   copy_fail                      ; If read fails, go to error
    or   ax, ax
    jz   copy_done                      ; AX = 0 → EOF reached

    ; -------- Write to destination file ----------------------
    mov  bx, si                         ; BX = destination file handle
    mov  cx, ax                         ; CX = number of bytes to write
    mov  ah, 40h                        ; DOS function 40h = write file
    lea  dx, copy_buf                   ; DX = buffer to write
    int  21h
    jc   copy_fail                      ; If write fails, go to error
    jmp  copy_loop                      ; Keep reading and writing

copy_done:
    ; -------- Close both files after success -----------------
    mov  bx, si                         ; Close destination file
    mov  ah, 3Eh
    int  21h

    mov  bx, di                         ; Close source file
    mov  ah, 3Eh
    int  21h

    mov  ah, 09h                        ; Print "copy done" message
    lea  dx, copy_msg
    int  21h
    ret

copy_fail:                              ; Read/write error handling
    mov  bx, si                         ; Close dest file (if opened)
    mov  ah, 3Eh
    int  21h

close_src_err:                          ; Close source file
    mov  bx, di
    mov  ah, 3Eh
    int  21h

copy_err:                               ; General error message
    mov  ah, 09h
    lea  dx, error_msg
    int  21h
    ret
copy_cmd ENDP

rename_cmd PROC

    ; ---- Read old filename from user input into cmd_buffer ----
    call skip_spaces_custom           ; Skip any spaces after "rename"
    cmp  byte ptr [si], 0             ; Nothing typed after command?
    je   rename_err                   ; If yes, show error and exit

    lea  di, cmd_buffer               ; Destination buffer for old name

old_copy:
    lodsb                             ; Load next character from input
    cmp  al, 0
    je   rename_err                   ; If line ends early, error
    cmp  al, ' '
    je   old_done                     ; Stop at space (end of old name)
    stosb                             ; Store character in cmd_buffer
    jmp  old_copy

old_done:
    mov  byte ptr [di], 0             ; Null-terminate old filename

    ; ---- Read new filename into rename_buf ---------------------
    call skip_spaces_custom           ; Skip spaces before new name
    cmp  byte ptr [si], 0
    je   rename_err                   ; No new name given → error

    lea  di, rename_buf               ; Destination buffer for new name

new_copy:
    lodsb                             ; Load next character from input
    cmp  al, 0
    je   new_done
    cmp  al, ' '
    je   new_done
    stosb                             ; Store character in rename_buf
    jmp  new_copy

new_done:
    mov  byte ptr [di], 0             ; Null-terminate new filename

    ; ---- Perform actual rename using DOS function 56h ----------
    mov  ax, ds                       ; ES must be equal to DS
    mov  es, ax

    mov  ah, 56h                      ; DOS function: Rename file
    lea  dx, cmd_buffer               ; DX = pointer to old name
    lea  di, rename_buf               ; DI = pointer to new name
    int  21h
    jc   rename_err                   ; If carry flag set → failed

    mov  ah, 09h                      ; Show success message
    lea  dx, rename_msg
    int  21h
    ret                               ; All done, return

rename_err:
    mov  ah, 09h                      ; Show error message
    lea  dx, error_msg
    int  21h
    ret
rename_cmd ENDP

if_cmd PROC

    call skip_spaces_custom             ; Skip spaces after typing "if"
    cmp  byte ptr [si], 0               ; Check if anything is typed after "if"
    je   if_syntax_err                  ; If not, show error

    ; --- Check if the next word is "exist" --------------------
    lea  di, kw_exist                   ; DI points to the string "exist"
chk_exist:
    mov  al, [si]                       ; Load character from user input
    mov  bl, [di]                       ; Load character from "exist"
    or   bl, bl                         ; If bl is zero, end of "exist"
    jz   after_exist                    ; If end of "exist", continue
    cmp  al, bl                         ; Compare both characters
    jne  if_syntax_err                  ; If they don't match, it's not "exist"
    inc  si                             ; Move to next character in input
    inc  di                             ; Move to next character in "exist"
    jmp  chk_exist                      ; Keep checking next characters

after_exist:
    call skip_spaces_custom             ; Skip spaces after "exist"
    cmp  byte ptr [si], 0               ; Is filename present?
    je   if_syntax_err                  ; If not, show error

    ; --- Copy filename into cmd_buffer -------------------------
    lea  di, cmd_buffer                 ; DI will point to where we store the name
copy_name:
    lodsb                               ; Load character from input (SI → AL)
    cmp  al, 0
    je   name_ok                        ; End of string reached
    cmp  al, ' '
    je   name_ok                        ; Stop if we hit a space
    stosb                               ; Store character in cmd_buffer
    jmp  copy_name

name_ok:
    mov  byte ptr [di], 0               ; Null-terminate the filename

    ; --- Use DOS to check if file or directory exists ----------
    mov  ah, 4Eh                        ; DOS function: Find first file
    mov  cx, 37h                        ; Search attributes: any file or folder
    lea  dx, cmd_buffer                 ; DX points to filename
    int  21h
    jc   not_found                      ; If CF=1 → file not found

found:
    mov  ah, 09h                        ; Print "Found" message
    lea  dx, if_found_msg
    int  21h
    ret

not_found:
    mov  ah, 09h                        ; Print "Not Found" message
    lea  dx, if_nf_msg
    int  21h
    ret

if_syntax_err:
    mov  ah, 09h                        ; Print generic error message
    lea  dx, error_msg
    int  21h
    ret

if_cmd ENDP

bgcolor_cmd PROC

    call skip_spaces_custom           ; Skip any spaces after typing "bgcolor"
    cmp  byte ptr [si], 0             ; Check if user entered a color digit
    je   bg_err                       ; If nothing entered, show error

    lodsb                             ; Load the color digit character into AL
    sub  al, '0'                      ; Convert ASCII '0'–'7' to number 0–7
    cmp  al, 7                        ; Make sure value is not above 7
    ja   bg_err                       ; If it is > 7, show error

    mov  bl, al                       ; Store background color in BL (0–7)
    mov  cl, 4
    shl  bl, cl                       ; Shift it to upper nibble (bg is high 4 bits)
    or   bl, 7                        ; OR with 07h to set text color as light gray

    ; ---- Clear screen using BIOS scroll function (AH=06h) ----
    mov  ax, 0600h                    ; scroll full screen window
    mov  bh, bl                       ; BH = attribute for filling screen (bg|text)
    mov  cx, 0000h                    ; Start color from top-left corner (row=0, col=0)
    mov  dx, 184Fh                    ; End color at bottom-right corner (row=24, col=79)
    int  10h                          ; BIOS interrupt to apply attribute to screen

    ; ---- Set cursor position to top-left (home) ---------------
    mov  ah, 02h                      ; Function: Set cursor position
    mov  bh, 00h                      ; Page number 0
    xor  dx, dx                       ; DX = 0 → row 0, col 0
    int  10h                          ; BIOS interrupt to move cursor

    ; ---- Show success message ---------------------------------
    mov  ah, 09h
    lea  dx, bg_msg                   ; Message like: "Background changed."
    int  21h
    ret

bg_err:
    ; ---- Show error message if wrong input --------------------
    mov  ah, 09h
    lea  dx, bg_errmsg               ; Message like: "Invalid background color."
    int  21h
    ret

bgcolor_cmd ENDP

fgcolor_cmd PROC

    call skip_spaces_custom             ; Skip any spaces after "fgcolor"
    cmp  byte ptr [si], 0               ; Check if user typed a color number
    je   fg_err                         ; If not, show error message

    ; --- Try to read a single-digit color number (0–9) --------
    xor  ax, ax                         ; Clear AX register
    mov  bl, [si]                       ; Load first char into BL
    sub  bl, '0'                        ; Convert ASCII to number
    cmp  bl, 9
    ja   maybe_hex                      ; If > 9, maybe it's 10–15
    mov  al, bl                         ; Save result in AL
    jmp  have_num                       ; Go to use it

maybe_hex:
    ; --- Try to read two-digit color like 10–15 ---------------
    cmp  bl, ('1' + 16)                 ; Check if above valid input
    jb   fg_err                         ; If invalid, show error

    lodsb                               ; Read first char (should be '1')
    sub  bl, '0'
    cmp  bl, 1
    jne  fg_err                         ; If not '1', it's not valid

    lodsb                               ; Read second char
    sub  al, '0'                        ; Convert to number
    cmp  al, 5
    ja   fg_err                         ; Only 0–5 allowed after '1'
    add  al, 10                         ; Add 10 to make 10–15

have_num:
    cmp  al, 15
    ja   fg_err                         ; If value >15, it's invalid
    mov  cl, al                         ; Store final foreground color in CL

    ; --- Get current screen attribute (text & background color) ---
    mov  bh, 0
    mov  ah, 08h                        ; BIOS: Read character + attribute
    int  10h                            ; AH = attribute (bg|fg), AL = char

    ; --- Set new foreground while keeping background ----------
    and  ah, 0F0h                       ; Clear lower nibble (keep background)
    or   ah, cl                         ; OR with new foreground color
    mov  bl, ah                         ; BL = final text attribute

    ; --- Update whole screen with new color -------------------
    mov  ax, 0600h                      ; BIOS: scroll 0 lines (clear screen)
    mov  bh, bl                         ; Use new attribute for fill
    mov  cx, 0000h                      ; Start from top-left
    mov  dx, 184Fh                      ; End at bottom-right (80x25)
    int  10h                            ; Clear & recolor screen

    ; --- Move cursor to top-left ------------------------------
    mov  ah, 02h                        ; BIOS: set cursor position
    xor  dx, dx                         ; Position (0,0)
    int  10h

    ; --- Show success message ---------------------------------
    mov  ah, 09h
    lea  dx, fg_msg                     ; Point to success message
    int  21h
    ret

fg_err:
    ; --- Show error if color value is invalid -----------------
    mov  ah, 09h
    lea  dx, fg_errmsg
    int  21h
    ret

fgcolor_cmd ENDP

cursor_cmd PROC

    call skip_spaces_custom        ; Skip any spaces after "cursor"
    cmp  byte ptr [si], 0          ; Check if user typed anything
    je   cur_err                   ; If not, show error

    lodsb                          ; Load the first character (style number)
    sub  al, '0'                   ; Convert ASCII to number (0, 1, or 2)
    cmp  al, 2                     ; Only 0, 1, or 2 are allowed
    ja   cur_err                   ; If greater than 2, show error

    ; --- Map user input to cursor shape ----------------------
    cmp  al, 0
    jne  not_block                 ; If not 0, check for others
    mov  ch, 0                     ; Start scan line = 0
    mov  cl, 15                    ; End scan line = 15 → Full block cursor
    jmp  set_cursor

not_block:
    cmp  al, 1
    jne  small_bar                 ; If not 1, go to next
    mov  ch, 14                    ; Start scan line = 14
    mov  cl, 15                    ; End scan line = 15 → Thin underline bar
    jmp  set_cursor

small_bar:
    mov  ch, 12                    ; Start scan line = 12
    mov  cl, 15                    ; End scan line = 15 → Even thinner bar

set_cursor:
    mov  ah, 01h                   ; BIOS: Set cursor shape function
    mov  bh, 00h                   ; Page number 0
    int  10h                       ; Call BIOS interrupt to set cursor

    ; --- Show success message -------------------------------
    mov  ah, 09h
    lea  dx, cur_msg               ; Message like: "Cursor style changed."
    int  21h
    ret

cur_err:
    ; --- Show error message if wrong input ------------------
    mov  ah, 09h
    lea  dx, cur_errmsg           ; Message like: "Invalid cursor style."
    int  21h
    ret

cursor_cmd ENDP

cls_cmd PROC

    ; ---------- Clear the screen ----------
    mov ax, 0600h       ; BIOS function: Scroll up window (AH=06h), 0 lines (AL=00h)
    mov bh, 07h         ; Attribute for clearing: light gray text on black background
    mov cx, 0000h       ; Upper-left corner of the screen (row=0, col=0)
    mov dx, 184Fh       ; Bottom-right corner (row=24, col=79 = 25 rows x 80 cols)
    int 10h             ; Call BIOS video interrupt to clear the screen

    ; ---------- Move the cursor to top-left ----------
    mov ah, 02h         ; BIOS function: Set cursor position
    mov bh, 00h         ; Page number 0
    mov dx, 0000h       ; Position the cursor at row 0, column 0
    int 10h             ; Call BIOS to move the cursor

    ret                 ; Return from the procedure

cls_cmd ENDP

;-----------------------------------------------------------
; skip_command_name: Skip the command (like "cd", "dir")
; After this, SI points to the argument
;-----------------------------------------------------------
skip_command_name PROC
next_char:
    cmp byte ptr [si], ' '       ; Is current character a space?
    je end_skip                  ; If yes, stop skipping
    cmp byte ptr [si], 0         ; Is it end of string?
    je end_skip                  ; If yes, stop
    inc si                       ; Move to next character
    jmp next_char                ; Repeat
end_skip:
    ret
skip_command_name ENDP

;-----------------------------------------------------------
; skip_spaces_custom: Skip all space characters
; After this, SI points to next non-space character
;-----------------------------------------------------------
skip_spaces_custom PROC
skip:
    cmp byte ptr [si], ' '       ; Is current character a space?
    jne done                     ; If not, done skipping
    inc si                       ; Move to next character
    jmp skip                     ; Repeat
done:
    ret
skip_spaces_custom ENDP

;-----------------------------------------------------------
; print_string: Print a string on screen using SI pointer
; Ends when null character (0) is found
;-----------------------------------------------------------
print_string PROC
    push ax                      ; Save registers
    push dx
    push si

print:
    mov dl, [si]                 ; Load current character into DL
    cmp dl, 0                    ; Is it null terminator?
    je finish                    ; If yes, done
    mov ah, 02h                  ; DOS print character function
    int 21h
    inc si                       ; Go to next character
    jmp print

finish:
    pop si                       ; Restore registers
    pop dx
    pop ax
    ret
print_string ENDP

;-----------------------------------------------------------
; strcmp: Compare two strings at SI and DI
; Returns AX=0 if same, AX=1 if different
;-----------------------------------------------------------
strcmp PROC
    push si                      ; Save registers
    push di
    push ax

compare:
    mov al, [si]                 ; Load character from string 1
    mov ah, [di]                 ; Load character from string 2
    cmp al, ah                   ; Compare characters
    jne not_equal                ; If different, jump
    test al, al                  ; Is it end of string (0)?
    jz equal                     ; If yes, both ended — equal
    inc si                       ; Go to next character in both
    inc di
    jmp compare

equal:
    xor ax, ax                   ; ax = 0 means equal
    jmp done_cmp

not_equal:
    mov ax, 1                    ; ax = 1 means not equal

done_cmp:
    pop ax                       ; Restore registers
    pop di
    pop si
    ret
strcmp ENDP

END main
