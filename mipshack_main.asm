# Lukas Velikov

.data
map_filename: .asciiz "map3.txt"
# num words for map: 45 = (num_rows * num_cols + 2) // 4 
# map is random garbage initially
.asciiz "Don't touch this region of memory"
map: .word 0x632DEF01 0xAB101F01 0xABCDEF01 0x00000201 0x22222222 0xA77EF01 0x88CDEF01 0x90CDEF01 0xABCD2212 0x632DEF01 0xAB101F01 0xABCDEF01 0x00000201 0x22222222 0xA77EF01 0x88CDEF01 0x90CDEF01 0xABCD2212 0x632DEF01 0xAB101F01 0xABCDEF01 0x00000201 0x22222222 0xA77EF01 0x88CDEF01 0x90CDEF01 0xABCD2212 0x632DEF01 0xAB101F01 0xABCDEF01 0x00000201 0x22222222 0xA77EF01 0x88CDEF01 0x90CDEF01 0xABCD2212 0x632DEF01 0xAB101F01 0xABCDEF01 0x00000201 0x22222222 0xA77EF01 0x88CDEF01 0x90CDEF01 0xABCD2212 
.asciiz "Don't touch this"
# player struct is random garbage initially
player: .word 0x2912FECD
.asciiz "Don't touch this either"
# visited[][] bit vector will always be initialized with all zeroes
# num words for visited: 6 = (num_rows * num*cols) // 32 + 1
visited: .word 0 0 0 0 0 0 
.asciiz "Really, please don't mess with this string"

welcome_msg: .asciiz "Welcome to MipsHack! Prepare for adventure!\n        Get 5 coins and escape to win!"
pos_str: .asciiz "Pos=["
health_str: .asciiz "] Health=["
coins_str: .asciiz "] Coins=["
your_move_str: .asciiz "Your Move: "
you_won_str: .asciiz "Congratulations! You have defeated your enemies and escaped with great riches!\n"
you_died_str: .asciiz "You died!\n"
you_failed_str: .asciiz "You have failed in your quest!\n"


.text
print_map:
la $t0, map  # the function does not need to take arguments
lbu $t1, 0($t0)  # Num rows
lbu $t2, 1($t0)  # Num cols
addi $t0, $t0, 2 # Point to actual map
li $t3, 0  # Rowcnt
li $t4, 0  # Colcnt
li $v0, 11  # Syscall 11: print character
row_loop_pm:
beq $t3, $t1, break_row_loop_pm  # Break when rowcnt = num rows
li $t4, 0  # Reset col counter 	
	
	col_loop_pm:
	beq $t4, $t2, break_col_loop_pm  # Break when colcnt = num cols
	lbu $a0, 0($t0)  # Load current char into a0
	andi $t5, $a0, 0x80  # Mask all bits except for hidden flag
	bnez $t5, print_space
	syscall  # Print current character
	j rest_of_col
	print_space:
	li $a0, ' '
	syscall
	rest_of_col:
	addi $t4, $t4, 1  # Increment colcnt
	addi $t0, $t0, 1  # Point to next byte in map
	j col_loop_pm

break_col_loop_pm:
li $a0, '\n'  # Syscall 11 char
syscall  # Print newline
addi $t3, $t3, 1  # Increment rowcnt
j row_loop_pm
break_row_loop_pm:
jr $ra

print_player_info:
# "Pos=[3,14] Health=[4] Coins=[1]"
la $t0, player
li $v0, 4  # Syscall 4: Print string
la $a0, pos_str  # "Pos=["
syscall  # Print
li $v0, 1  # Syscall 1: Print int
lbu $a0, 0($t0)  # Player row
syscall
li $v0, 11  # Syscall 11: Print char
li $a0, ','
syscall
li  $v0, 1, # Syscall 1: Print int
lbu $a0, 1($t0)  # Player col
syscall
li $v0, 4  # Syscall 4: Print string
la $a0, health_str  # "Health=["
syscall  # Print
li $v0, 1  # Syscall 1: Print int
lb $a0, 2($t0)  # Player health
syscall
li $v0, 4  # Syscall 4: Print string
la $a0, coins_str  # "Coins=["
syscall  # Print
li $v0, 1
lbu $a0, 3($t0)  # Player coins
syscall
li $v0, 11
li $a0, ']'
syscall
li $a0, '\n'
syscall
jr $ra


.globl main
main:
la $a0, welcome_msg
li $v0, 4
syscall

# fill in arguments
la $a0, map_filename
la $a1, map
la $a2, player
jal init_game

la $a0, map
la $a2, player
lbu $a1, 0($a2)
lbu $a2, 1($a2)
jal reveal_area

li $s0, 0  # move = 0

game_loop:  # while player is not dead and move == 0:

jal print_map # takes no args

jal print_player_info # takes no args

# print prompt
la $a0, your_move_str
li $v0, 4
syscall

li $v0, 12  # read character from keyboard
syscall
move $s1, $v0  # $s1 has character entered
li $s0, 0  # move = 0

li $a0, '\n'
li $v0 11
syscall

# handle input: w, a, s or d
# map w, a, s, d  to  U, L, D, R and call player_turn()
beq $s1, 'w', w_m
beq $s1, 'a', a_m
beq $s1, 's', s_m
beq $s1, 'd', d_m
beq $s1, 'r', r_m
j skipping_m
w_m:
	li $s1, 'U'
	j done_mapping_m
a_m:
	li $s1, 'L'
	j done_mapping_m
s_m:
	li $s1, 'D'
	j done_mapping_m
d_m:
	li $s1, 'R'
	j done_mapping_m
r_m:
	la $a0, map
	la $t0, player
	lbu $a1, 0($t0)
	lbu $a2, 1($t0)
	la $a3, visited
	jal flood_fill_reveal
	j game_loop
done_mapping_m:
# player_turn(map_ptr, player_ptr, direction)
la $a0, map
la $a1, player
move $a2, $s1  # Direction char
jal player_turn

# if move == 0, call reveal_area()  Otherwise, exit the loop.
bnez $v0, game_over
beq $t9, -69, game_over  # Check for kill code

# reveal_area(map, row, col)
la $a0, map
la $a2, player
lbu $a1, 0($a2)
lbu $a2, 1($a2)
jal reveal_area

skipping_m:
j game_loop

game_over:
jal print_map
jal print_player_info
li $a0, '\n'
li $v0, 11
syscall
beq $t9, -69, player_dead
la $t9, player
lbu $t9, 3($t9)
blt $t9, 5, failed
# choose between (1) player dead, (2) player escaped but lost, (3) player escaped and won

won:
la $a0, you_won_str
li $v0, 4
syscall
j exit

failed:
la $a0, you_failed_str
li $v0, 4
syscall
j exit

player_dead:
la $a0, you_died_str
li $v0, 4
syscall

exit:
li $v0, 10
syscall

.include "hw4.asm"
