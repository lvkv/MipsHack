# Lukas Velikov

.text

# Part I
init_game:
li $v0, -200
li $v1, -200

# a0: map_filename
# a1: Map *map_ptr
# a2: Player *player_ptr

move $t0, $a0  # s0: map_filename
move $t1, $a1  # s1: *map_ptr
move $t2, $a2  # s2: *player_ptr

# Open file
li $v0, 13  # Syscall 13: Open file
li $a1, 0  # Read-only flag
li $a2, -1  # Mode (ignored)          
syscall
bltz $v0, fail_1  # Fail if file fails to read off disk

# Read file into input buffer (stack)
move $a0, $v0  # Move file descriptor from syscall 13 to a0
li $v0, 14  # Syscall 14: Read from file
addi $sp, $sp, -6  # Free 6 bytes on the stack
move $a1, $sp  # a1: Address of input buffer (in this case, the stack)
li $a2, 6  # a2: Max number of bytes to read from file (including line feeds)
syscall

# Calculate num_rows (convert first two chars into a single int value)
lbu $t3, 0($sp)  # Load first char from map file (tens digit in num_rows)
addi $t3, $t3, -48  # Convert ascii to int digit
li $t4, 10  # Constant value 10
mul $t3, $t3, $t4  # TensDigit *= 10
lbu $t4, 1($sp)  # Load second char from map file (ones digit in num_rows)
addi $t4, $t4, -48  # Convert ascii to int digit
add $t3, $t3, $t4  # Tens += Ones. t3 now = num_rows

# Calculate num_cols (convert next two chars into single int value)
lbu $t4, 3($sp)  # Load third char (tens digit in num_cols) (note this is the fourth byte - line feed counts as a byte)
addi $t4, $t4, -48  # Convert ascii to int digit
li $t5, 10  # Constant value 10
mul $t4, $t4, $t5  # TensDigit *= 10
lbu $t5, 4($sp)  # Load fourth char from map file (ones digit in num_cols)
addi $t5, $t5, -48  # Convert ascii to int (ones digit)
add $t4, $t4, $t5  # Tens += Ones. t4 now = num_rows

# Save num_rows & num_cols into *map_ptr
sb $t3, 0($t1)  # Save num_rows into byte 0
sb $t4, 1($t1)  # Save num_cols into byte 1
addi $t1, $t1, 2  # Increment *map_ptr (for later)
addi $sp, $sp, 6  # We're done with that now

# Read map into memory buffer (stack)
li $t5, 0  # Row Counter
sub $sp, $sp, $t4  # Allocate num_cols bytes on the stack
row_loop_1:  # For every row in the map
beq $t5, $t3, break_row_loop_1  # Break when row counter = num rows
li $v0, 14  # Syscall 14
move $a1, $sp  # a1: Address of input buffer (in this case, the stack)
move $a2, $t4  # a2: Num bytes to read: num_cols...
addi $a2, $a2, 1  # Include the line feed at the end
syscall
li $t6, 0  # Col Counter
move $t7, $sp  # Temp stack pointer 

	col_loop_1:
	beq $t6, $t4, break_col_loop_1  # Break when col counter = num_cols
	lbu $t0, 0($t7)  # Load current char from map
	beq $t0, '@', player_char_1  # If the char is the player char, @...
	ori $t0, $t0, 0x80  # Setting 'hidden' flag of char
	j rest_of_col_loop_1
	player_char_1:
	sb $t5, 0($t2)  # Store row counter into byte 0 of Player struct
	sb $t6, 1($t2)  # Store col counter into byte 1 of Player struct
	rest_of_col_loop_1:
	sb $t0, 0($t1)  # Store current char into *map_ptr
	addi $t1, $t1, 1  # Increment *map_ptr 
	addi $t6, $t6, 1  # Increment col counter
	addi $t7, $t7, 1  # Increment temp stack pointer
	j col_loop_1
	
break_col_loop_1:	
addi $t5, $t5, 1  # Increment row counter
j row_loop_1
break_row_loop_1:

# Read in the health of the player as ascii
li $v0, 14  # Syscall 14
move $a1, $sp  # a1: Address of input buffer (in this case, the stack)
li $a2, 2  # a2: Num bytes to read: 2 bytes/chars
syscall

# Calculate player health (convert two chars into a single int value)
lbu $t3, 0($sp)  # Load first tens digit in player health
addi $t3, $t3, -48  # Convert ascii to int digit
li $t5, 10  # Constant value 10
mul $t3, $t3, $t5  # TensDigit *= 10
lbu $t5, 1($sp)  # Load second char from map file (ones digit in num_rows)
addi $t5, $t5, -48  # Convert ascii to int digit
add $t3, $t3, $t5  # Tens += Ones. t3 now = health of player
sb $t3, 2($t2)  # Store player health
sb $zero, 3($t2)  # Store player coins (zero)
add $sp, $sp, $t4  # We're done with this memory now
li $v0, 0  # Success
jr $ra  # gtfo
fail_1:  # Failure
li $v0, -1
jr $ra  # gtfo


# Part II
is_valid_cell:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: int row
# a2: int col

bltz $a1, fail_2  # Fail if rows < 0
bltz $a2, fail_2  # Fail if cols < 0
lbu $t0, 0($a0)  # Load map_ptr.num_rows
bge $a1, $t0, fail_2  # Fail if rows >= map_ptr.num_rows
lbu $t0, 1($a0)  # Load map_ptr.num_cols
bge $a2, $t0, fail_2  # Fail if cols >= map_ptr.num_cols
li $v0, 0  # Success
jr $ra
fail_2:
li $v0, -1
jr $ra


# Part III
get_cell:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: int row
# a2: int col

# Call is_valid_cell
addi $sp, $sp, -4
sw $ra, 0($sp)
jal is_valid_cell
lw $ra, 0($sp)
addi $sp, $sp, 4
beq $v0, -1, fail_3  # Fail if not valid

# Get char
# Address = Base_Address + 1*(num_cols*i + j)
lbu $t0, 1($a0)  # Num cols
mul $t0, $t0, $a1  # num_cols * i
add $t0, $t0, $a2  # (num_cols * i) + j
addi $a0, $a0, 2  # Whoop over the map
add $t0, $t0, $a0  # Base_Address + num_cols*i + j
lbu $v0, 0($t0)  # Byte at map_ptr.cells[row][col]
jr $ra  # gtfo
fail_3:
li $v0, -1  # Failure
jr $ra  # gtfo


# Part IV
set_cell:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: int row
# a2: int col
# a3: char ch

# Call is_valid_cell
addi $sp, $sp, -4
sw $ra, 0($sp)
jal is_valid_cell
lw $ra, 0($sp)
addi $sp, $sp, 4
beq $v0, -1, fail_4  # Fail if not valid

# Set char
# Address = Base_Address + 1*(num_cols*i + j)
lbu $t0, 1($a0)  # Num cols
mul $t0, $t0, $a1  # num_cols * i
add $t0, $t0, $a2  # (num_cols * i) + j
addi $a0, $a0, 2  # Whoop over the map
add $t0, $t0, $a0  # Base_Address + num_cols*i + j
sb $a3, 0($t0)  # Save the char in the desired  cell
li $v0, 0  # success
jr $ra  # gtfo
fail_4:
li $v0, -1  # failure
jr $ra  # gtfo


# Part V
reveal_area:
li $v0, -200
li $v1, -200

# a0: *map_ptr
# a1: int row
# a2: int col

addi $sp, $sp, -20
sw $s0, 0($sp)
sw $s1, 4($sp)
sw $s2, 8($sp)  # Save to stack
sw $s3, 12($sp)
sw $s4, 16($sp)

move $s0, $a0  # map_ptr
move $s1, $a1  # row
move $s2, $a2  # col

addi $s1, $s1, -1  # Start at the ...
addi $s2, $s2, -1  # ... upper left of  our 3x3 square
li $s3, 0  # Row cnt
li $s4, 0  # Col cnt
row_loop_5:
beq $s3, 3, break_row_loop_5  # Break when row count is 3
li $s4, 0  # Reset Col cnt

	col_loop_5:
	beq $s4, 3, break_col_loop_5
	
	# is_valid_cell(map_ptr, row, col)
	move $a0, $s0  # Map
	move $a1, $s1  # Row
	move $a2, $s2  # Col
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal is_valid_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	beq $v0, -1, invalid_5
	
	# get_cell(map_ptr, row, col)
	move $a0, $s0  # Map
	move $a1, $s1  # Row
	move $a2, $s2  # Col
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	beq $v0, -1, invalid_5
	
	# set_cell(map_ptr, row, col, ch)
	andi $v0, $v0, 0x7F  # Setting 'hidden' flag of char to NOT HIDDEN
	move $a0, $s0  # Map
	move $a1, $s1  # Row
	move $a2, $s2  # Col
	move $a3, $v0  # Now visible char
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal set_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	invalid_5:
	addi $s2, $s2, 1  # Increment col
	addi $s4, $s4, 1  # Increment Col cnt
	j col_loop_5

break_col_loop_5:
addi $s1, $s1, 1  # Increment row
addi $s3, $s3, 1  # Increment Row cnt
addi $s2, $s2, -3  # Reset col
j row_loop_5
break_row_loop_5:
lw $s0, 0($sp)
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)  # Restore from stack
lw $s4, 16($sp)
addi $sp, $sp, 20  # We're done with this memory
jr $ra

# Part VI
get_attack_target:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: Player *player_ptr
# a2: char direction

lbu $t0, 0($a1)  # Load player row
lbu $t1, 1($a1)  # Load player col
beq $a2, 'U', up_6
beq $a2, 'D', down_6
beq $a2, 'L', left_6
beq $a2, 'R', right_6
j fail_6  # If the direction wasn't any of these valid ones -> fail
up_6:
addi $t0, $t0, -1  # Move up one row
j get_6
down_6:
addi $t0, $t0, 1  # Move down one row
j get_6
left_6:
addi $t1, $t1, -1  # Move left one col
j get_6
right_6:
addi $t1, $t1, 1  # Move right one col
j get_6
get_6:

addi $sp, $sp, -12
sw $s0, 0($sp)  # Storing stuff to stack
sw $s1, 4($sp)
sw $s2, 8($sp)

move $s0, $a0  # Moving args over
move $s1, $a1
move $s2, $a2
	# get_cell(map_ptr, row, col)
	move $a0, $s0 # Moving args for get_cell
	move $a1, $t0
	move $a2, $t1
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell  # get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
lw $s0, 0($sp)
lw $s1, 4($sp)  # restoring from stack
lw $s2, 8($sp)
addi $sp, $sp, 12
beq $v0, 'm', valid_attack_6
beq $v0, 'B', valid_attack_6
beq $v0, '/', valid_attack_6
j fail_6
valid_attack_6:
jr $ra  # gtfo
fail_6:
li $v0, -1  # Failure
jr $ra  # gtfo


# Part VII (VIII?)
monster_attacks:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: Player *player_ptr

addi $sp, $sp, -20
sw $s0, 0($sp)
sw $s1, 4($sp)
sw $s2, 8($sp)
sw $s3, 12($sp)
sw $s4, 16($sp)
move $s0, $a0
move $s1, $a1
lbu $s2, 0($a1)  # Load player row
lbu $s3, 1($a1)  # Load player col
li $s4, 0  # Player damage

damage_up_8:
addi $s2, $s2, -1  # Check tile up from current
	# get_cell(map_ptr, row-1, col)
	move $a0, $s0
	move $a1, $s2
	move $a2, $s3
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
addi $s2, $s2, 1  # Undo changes
beq $v0, -1, damage_down_8  # If cell is invalid, skip
beq $v0, 'm', mu_8
beq $v0, 'B', Bu_8
j damage_down_8  # No damage up
mu_8:
addi $s4, $s4, 1  # 1 pt damage
j damage_down_8
Bu_8:
addi $s4, $s4, 2  # 2 pt damage

damage_down_8:
addi $s2, $s2, 1  # Check tile down from current
	# get_cell(map_ptr, row+1, col)
	move $a0, $s0
	move $a1, $s2
	move $a2, $s3
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
addi $s2, $s2, -1  # Undo changes
beq $v0, -1, damage_left_8  # If cell is invalid, skip
beq $v0, 'm', md_8
beq $v0, 'B', Bd_8
j damage_left_8  # No damage down
md_8:
addi $s4, $s4, 1  # 1 pt damage
j damage_left_8
Bd_8:
addi $s4, $s4, 2  # 2 pt damage

damage_left_8:
addi $s3, $s3, -1  # Check tile left from current
	# get_cell(map_ptr, row, col-1)
	move $a0, $s0
	move $a1, $s2
	move $a2, $s3
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
addi $s3, $s3, 1  # Undo changes
beq $v0, -1, damage_right_8  # If cell is invalid, skip
beq $v0, 'm', ml_8
beq $v0, 'B', Bl_8
j damage_right_8  # No damage left
ml_8:
addi $s4, $s4, 1  # 1 pt damage
j damage_right_8
Bl_8:
addi $s4, $s4, 2  # 2 pt damage

damage_right_8:
addi $s3, $s3, 1  # Check tile right from current
	# get_cell(map_ptr, row, col+1)
	move $a0, $s0
	move $a1, $s2
	move $a2, $s3
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
addi $s3, $s3, 1  # Undo changes
beq $v0, -1, apply_damage_8  # If cell is invalid, skip
beq $v0, 'm', mr_8
beq $v0, 'B', Br_8
j apply_damage_8  # No damage right
mr_8:
addi $s4, $s4, 1  # 1 pt damage
j apply_damage_8
Br_8:
addi $s4, $s4, 2  # 2 pt damage

apply_damage_8:
move $v0, $s4
lw $s0, 0($sp)
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
lw $s4, 16($sp)
addi $sp, $sp, 20
jr $ra


# Part VIII (IX?)
player_move:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: Player *player_ptr
# a2: int target_row
# a3: int target_col

addi $sp, $sp, -16
sw $s0, 0($sp)
sw $s1, 4($sp)
sw $s2, 8($sp)
sw $s3, 12($sp)
move $s0, $a0  # Map
move $s1, $a1  # Player
move $s2, $a2  # Target Row
move $s3, $a3  # Target col

	# monster_attacks(map_ptr, player_ptr)
	move $a0, $s0  # Map
	move $a1, $s1  # Player
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal monster_attacks
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
lb $t0, 2($s1)  # Load player health
sub $t0, $t0, $v0  # Health -= Monster Damage
sb $t0, 2($s1)  # Store updated health
blez $t0, killed_9  # If health <= 0 goto killed process

	# get_cell(map_ptr, trow, tcol)
	move $a0, $s0
	move $a1, $s2
	move $a2, $s3
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
beq $v0, '.', move_9
beq $v0, '$', coin_9
beq $v0, '*', guap_9
beq $v0, '>', door_9

move_9:
	j finished_9
coin_9:
	lbu $t0, 3($s1)  # Load player coins
	addi $t0, $t0, 1  # Add 1 to coins
	sb $t0, 3($s1) # Store updated coins
	j finished_9
guap_9:
	lbu $t0, 3($s1)  # Load player coins
	addi $t0, $t0, 5  # Add 5 to coins
	sb $t0, 3($s1) # Store updated coins
	j finished_9
killed_9:  # Replace '@' at player's position with 'X'
	lbu $t0, 0($s1)  # Load player row
	lbu $t1, 1($s1)  # Load player col
	# set_cell(map_ptr, row, col, 'X')
	move $a0, $s0
	move $a1, $t0
	move $a2, $t1
	li $a3, 'X'
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal set_cell
	lw $ra, ($sp)
	addi $sp, $sp, 4
	li $t9, -69
	j end_9
	
finished_9:
lbu $t0, 0($s1)  # Load player row
lbu $t1, 1($s1)  # Load player col
		
	# set_cell(map_ptr, row, col, '.')
	move $a0, $s0
	move $a1, $t0
	move $a2, $t1
	li $a3, '.'
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal set_cell
	lw $ra, ($sp)
	addi $sp, $sp, 4
	
sb $s2, 0($s1)  # Store target row in player struct
sb $s3, 1($s1)  # Store target col in player struct

	# set_cell(map_ptr, trow, tcol, '@')
	move $a0, $s0
	move $a1, $s2
	move $a2, $s3
	li $a3, '@'
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal set_cell
	lw $ra,($sp)
	addi $sp, $sp, 4

end_9:
lw $s0, 0($sp)  # Restore from stack
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
addi $sp, $sp, 16
li $v0, 0  # "Success"
jr $ra
door_9:
lbu $t0, 0($s1)  # Load player row
lbu $t1, 1($s1)  # Load player col
		
	# set_cell(map_ptr, row, col, '.')
	move $a0, $s0
	move $a1, $t0
	move $a2, $t1
	li $a3, '.'
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal set_cell
	lw $ra, ($sp)
	addi $sp, $sp, 4
	
sb $s2, 0($s1)  # Store target row in player struct
sb $s3, 1($s1)  # Store target col in player struct

	# set_cell(map_ptr, trow, tcol, '@')
	move $a0, $s0
	move $a1, $s2
	move $a2, $s3
	li $a3, '@'
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal set_cell
	lw $ra,($sp)
	addi $sp, $sp, 4

lw $s0, 0($sp)
lw $s1, 4($sp)  # Restore from stack
lw $s2, 8($sp)
lw $s3, 12($sp)
addi $sp, $sp, 16
li $v0, -1  # Door code
jr $ra



# Part IX (VII?)
complete_attack:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: Player *player_ptr
# a2: int target_row
# a3: int target_col

addi $sp, $sp, -16
sw $s0, 0($sp)
sw $s1, 4($sp)
sw $s2, 8($sp)
sw $s3, 12($sp)
move $s0, $a0
move $s1, $a1
move $s2, $a2
move $s3, $a3

# get_cell(map_ptr, row, col)
move $a0, $s0
move $a1, $s2
move $a2, $s3
addi $sp, $sp, -4
sw $ra, 0($sp)
jal get_cell
lw $ra, 0($sp)
addi $sp, $sp, 4

move $a0, $s0  # a0: map
move $a1, $s2  # a1: row
move $a2, $s3  # a2: col
beq $v0, 'm', m_7
beq $v0, 'B', B_7
beq $v0, '/', slash_7

m_7:  # Minion kill
lb $t0, 2($s1)  # Load current health
addi $t0, $t0, -1  # Player takes 1 point of damage!
sb $t0, 2($s1)  # Save new updated health
li $a3, '$'  # 'm' is replaced by '$'
addi $sp, $sp, -4
sw $ra, 0($sp)
jal set_cell
lw $ra, 0($sp)
addi $sp, $sp, 4
j health_check_7

B_7:  # Boss kill
lb $t0, 2($s1)  # Load current health
addi $t0, $t0, -2  # Player takes 2 points of damage!
sb $t0, 2($s1)  # Save new updated health
li $a3, '*'  # 'B' is replaced by '*'
addi $sp, $sp, -4
sw $ra, 0($sp)
jal set_cell
lw $ra, 0($sp)
addi $sp, $sp, 4
j health_check_7

slash_7:  # Door destroy
li $a3, '.'  # '/' is replaced by '.'
addi $sp, $sp, -4
sw $ra, 0($sp)
jal set_cell
lw $ra, 0($sp)
addi $sp, $sp, 4
j health_check_7

health_check_7:
lb $t0, 2($s1)  # Load current health
bgtz $t0, skip_death
move $a0, $s0  # a0: map
move $a1, $s2  # a1: row
move $a2, $s3  # a2: col
li $a3, 'X'
addi $sp, $sp, -4
sw $ra, 0($sp)
jal set_cell
lw $ra, 0($sp)
addi $sp, $sp, 4
skip_death:
addi $sp, $sp, 16
jr $ra


# Part X
player_turn:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: Player *player_ptr
# a2: char direction

lbu $t0, 0($a1)  # Load player row
lbu $t1, 1($a1)  # Load player col
beq $a2, 'U', up_10
beq $a2, 'D', down_10
beq $a2, 'L', left_10
beq $a2, 'R', right_10
j fail_10
up_10:
	addi $t0, $t0, -1  # Row -= 1
	j p23_10
down_10:
	addi $t0, $t0, 1  # Row += 1
	j p23_10
left_10:
	addi $t1, $t1, -1  # Col -= 1
	j p23_10
right_10:
	addi $t1, $t1, 1  # Col += 1
	j p23_10
p23_10:
addi $sp, $sp, -20  # Make space on stack
sw $s0, 0($sp)
sw $s1, 4($sp)
sw $s2, 8($sp)
sw $s3, 12($sp)
sw $s4, 16($sp)
move $s0, $a0  # Map
move $s1, $a1  # Player
move $s2, $a2  # Direction
move $s3, $t0  # Target row
move $s4, $t1  # Target col

	# get_cell(map_ptr, row, col)
	move $a0, $s0  # Map
	move $a1, $s3  # TRow
	move $a2, $s4  # TCol
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4

beq $v0, -1, end_10  # Return 0 on invalid
beq $v0, '#', end_10  # Return 0 on '#' (wall)
p4_10:
	
	# get_attack_targer(map_ptr, player_ptr, direction)
	move $a0, $s0  # Map
	move $a1, $s1  # Player
	move $a2, $s2  # Direction
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_attack_target
	lw $ra, 0($sp)
	addi $sp, $sp, 4

beq $v0, -1, no_attack_10  # If returned -1, then there's no monster or door
	
	# Else, call complete attack to see if target cell is attackable
	# complete_attack(map_ptr, player_ptr, target_row, target_col)
	move $a0, $s0  # Map
	move $a1, $s1  # Player
	move $a2, $s3  # TRow
	move $a3, $s4  # TCol
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal complete_attack
	lw $ra, 0($sp)
	addi $sp, $sp, 4

j end_10
no_attack_10:  # Otherwise, call player move and return that function’s return value as the return value of player turn

	# player_move(map_ptr, player_ptr, target_row, target_col)
	move $a0, $s0  # Map
	move $a1, $s1  # Player
	move $a2, $s3  # TRow
	move $a3, $s4  # TCol
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal player_move
	lw $ra, 0($sp)
	addi $sp, $sp, 4

lw $s0, 0($sp)  # Restore from stack
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
lw $s4, 16($sp)
addi $sp, $sp, 20  # Deallocate memory
jr $ra  # Return value in $v0 should already be present from player_move
end_10:
lw $s0, 0($sp)  # Restore from stack
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
lw $s4, 16($sp)
addi $sp, $sp, 20  # Deallocate memory
li $v0, 0
jr $ra
fail_10:
li $v0, -1  # Failure
jr $ra


# Part XI
flood_fill_reveal:
li $v0, -200
li $v1, -200

# a0: Map *map_ptr
# a1: int row
# a2: int col
# a3: bit[][] visited

addi $sp, $sp, -20
sw $s0, 0($sp)
sw $s1, 4($sp)
sw $s2, 8($sp)
sw $s3, 12($sp)
sw $fp, 16($sp)
move $s0, $a0  # Map
move $s1, $a1  # row
move $s2, $a2  # col
move $s3, $a3  # bit[][] visited

	# is_valid_cell(Map row, col)
	move $a0, $s0  # map
	move $a1, $s1  # row
	move $a2, $s2  # col
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal is_valid_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4

beq $v0, -1, fail_11  # if (row, col) represents an invalid index then return -1
move $fp, $sp  # $fp = $sp
addi $sp, $sp, -8
sb $s1, 0($sp)  # $sp.push(row)
sb $s2, 4($sp)  # $sp.push(col)
while_11:
	beq $sp, $fp, break_while_11  # while $sp != $fp:
	lbu $t8, 4($sp)  # col = $sp.pop()
	lbu $t9, 0($sp)  # row = $sp.pop()
	addi $sp, $sp, 8
	# make the cell at index (row,col) visible in the world map
		# get_cell(map, row, col)
		move $a0, $s0  # Map
		move $a1, $t9  # Row
		move $a2, $t8  # Col
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		jal get_cell
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
		andi $v0, $v0, 0x7F  # Setting 'hidden' flag of char to NOT HIDDEN
		
		# set_cell(map, row, col, char)
		move $a0, $s0  # Map
		move $a1, $t9  # Row
		move $a2, $t8  # Col
		move $a3, $v0  # (now visible) Char
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		jal set_cell
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
	addi $t0, $t9, -1  # (-1, 0)
	addi $t1, $t8, 0
		
		# if_help_11(row, col, Map, bit[][]visited)
		move $a0, $t0  # Row
		move $a1, $t1  # Col
		move $a2, $s0  # Map
		move $a3, $s3  # bit[][]visited
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		jal if_help_11
		lw $ra, 0($sp)
		addi $sp, $sp, 4
	
	beq $v0, -1, next_1_11  # If that tile wasn't floor, then skip stack pushing
	addi $sp, $sp, -8
	addi $t0, $t9, -1  # Recalculate coords
	addi $t1, $t8, 0
	sw $t0, 0($sp)  # Save them to the stack
	sw $t1, 4($sp)
	
	next_1_11:
	addi $t0, $t9, 1  # (1, 0)
	addi $t1, $t8, 0
	
		# if_help_11(row, col, Map, bit[][]visited)
		move $a0, $t0  # Row
		move $a1, $t1  # Col
		move $a2, $s0  # Map
		move $a3, $s3  # bit[][]visited
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		jal if_help_11
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
	beq $v0, -1, next_2_11  # If that tile wasn't floor, then skip stack pushing
	addi $sp, $sp, -8
	addi $t0, $t9, 1  # (1, 0)
	addi $t1, $t8, 0
	sw $t0, 0($sp)  # Save them to the stack
	sw $t1, 4($sp)
	
	next_2_11:
	addi $t0, $t9, 0  # (0, -1)
	addi $t1, $t8, -1
	
		# if_help_11(row, col, Map, bit[][]visited)
		move $a0, $t0  # Row
		move $a1, $t1  # Col
		move $a2, $s0  # Map
		move $a3, $s3  # bit[][]visited
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		jal if_help_11
		lw $ra, 0($sp)
		addi $sp, $sp, 4

	beq $v0, -1, next_3_11  # If that tile wasn't floor, then skip stack pushing
	addi $sp, $sp, -8
	addi $t0, $t9, 0  # (0, -1)
	addi $t1, $t8, -1
	sw $t0, 0($sp)  # Save them to the stack
	sw $t1, 4($sp)
	
	next_3_11:
	addi $t0, $t9, 0  # (0, 1)
	addi $t1, $t8, 1
	
		# if_help_11(row, col, Map, bit[][]visited)
		move $a0, $t0  # Row
		move $a1, $t1  # Col
		move $a2, $s0  # Map
		move $a3, $s3  # bit[][]visited
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		jal if_help_11
		lw $ra, 0($sp)
		addi $sp, $sp, 4

	beq $v0, -1, next_4_11  # If that tile wasn't floor, then skip stack pushing
	addi $sp, $sp, -8
	addi $t0, $t9, 0  # (0, 1)
	addi $t1, $t8, 1
	sw $t0, 0($sp)  # Save them to the stack
	sw $t1, 4($sp)
	
	next_4_11:
	j while_11
break_while_11:
lw $s0, 0($sp)
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
lw $fp, 16($sp)
addi $sp, $sp, 20
li $v0, 0  # Success 
jr $ra
fail_11:
lw $s0, 0($sp)
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
lw $fp, 16($sp)
addi $sp, $sp, 20
li $v0, -1  # Failure
jr $ra


if_help_11:
# a0: row
# a1: col
# a2: Map
# a3: bit[][]visited

addi $sp, $sp, -16
sw $s0, 0($sp)
sw $s1, 4($sp)
sw $s2, 8($sp)
sw $s3, 12($sp)
move $s0, $a0  # Row
move $s1, $a1  # Col
move $s2, $a2  # Map
move $s3, $a3  # bit[][] visited

	# get_cell(map, row, col)
	move $a0, $s2  # Map
	move $a1, $s0  # Row
	move $a2, $s1  # Col
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal get_cell
	lw $ra, 0($sp)
	addi $sp, $sp, 4

beq $v0, '.', nice_floor_dude_11  # if the cell at index (row+i, col+j) is floor, then, damn... nice floor, dude!
beq $v0, 174, nice_floor_dude_11  # checking for invisible floor
j fail_help_11  # Else do nothing
nice_floor_dude_11:
# offset = (row * num_cols) + col
lbu $t0, 1($s2)  # num cols
mul $t0, $t0, $s0  # t0 = num_cols * rows
add $t0, $t0, $s1  # t0 = offset = (row * num_cols) + col
li $t1, 8  # 8 bits per byte
div $t0, $t1  # Offset // 8 = byte offset
mflo $t1  # t1 = number of bytes offset
mfhi $t2  # t2 = nth bit to get after incrementing bytes
add $s3, $s3, $t1  # byte offset
lbu $t3, 0($s3)  # Get the relevant byte
addi $t2, $t2, -1  # n-1 = number of right shifts to shift nth byte into LSB
srlv $t3, $t3, $t2  # Shift relevant byte right n-1 times to put nth byte into LSB
andi $t3, $t3, 1  # bitwise AND shifted byte with 1
beq $t3, 1, fail_help_11  #  If this is a 1, then we've visited already. Leave.
lbu $t3, 0($s3)  # Get the relevant byte (again)
ror $t3, $t3, $t2  # ROTATE RIGHT n-1 times to put nth bit in LSB
ori $t3, $t3, 1  # bitwise AND rotated product with 1 to flip LSB (traversed bit) to 1
rol $t3, $t3, $t2  # ROTATE RIGHT n-1 times to restore byte to normal state
sb $t3, 0($s3)  # Save byte back into bit vector
move $t0, $s0
move $t1, $s1
lw $s0, 0($sp)
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
addi $sp, $sp, 16
li $v0, 0  # Code for "push me to stack"
jr $ra
fail_help_11:
lw $s0, 0($sp)
lw $s1, 4($sp)
lw $s2, 8($sp)
lw $s3, 12($sp)
addi $sp, $sp, 16
li $v0, -1  # Code for "ignore me like the worthless thing I am"
jr $ra
