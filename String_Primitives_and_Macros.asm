TITLE Designing low-level I/O procedures      (Proj6_Grierm.asm)

; Author: Max Grier
; Last Modified: 12-06-2020
; OSU email address: grierm@oregonstate.edu
; Course number/section:   CS271 Section 400
; Project Number: 6               Due Date: 12-06-2020
; Description:  This program will take in 10 signed integers from the user.  These numbers will be inputted
;				as strings and stored in an array.  Those strings will be converted to integers before
;				calculating the sum and rounded average. Then the will be converted back into a string 
;				and printed out to the user. The numbers entered must fit in a 32 bit signed register and
;				only numbers will be acceptable inputs.
;

INCLUDE Irvine32.inc

; Define constants for limits
ARRAY_SIZE = 10
MAX_VALUE = 2147483647
MIN_VALUE = (-2147483648)

;-------------------------------------------------------------------------
; Name: mGetString
;
; Description: Gets user string input for the numbers.
;
; Preconditions: None.
;
; Recieves: inputPrompt and the user input
;
; Returns: EDX is the number and ECX is the length.
;
;-------------------------------------------------------------------------

mGetString MACRO	inputPrompt, number
; Macro to get data input from user
	PUSH	EDX								; Preserve registers
	PUSH	ECX

; Display inputPrompt to get user's input
	mDisplayString	inputPrompt

; Store number and size of the string
	MOV		EDX, number
	MOV		ECX, 32

	CALL	ReadString
	
	POP		ECX								; Restore registers
	POP		EDX

ENDM

;-------------------------------------------------------------------------
; Name: mDisplayString
;
; Description: This will print out a string that is passed to it.
;
; Preconditions: None.
;
; Recieves: A string to be outputted.
;
; Returns: EDX is the string printed.
;
;-------------------------------------------------------------------------

mDisplayString MACRO	outputString
; Macro to output string to user
	PUSH	EDX								; Preserve register
	
	MOV		EDX, outputString
	CALL	WriteString
	
	POP		EDX								; Restore register

ENDM


.data
; Intro message
introPrompt			BYTE	"PROGRAMMING ASSIGNMENT 6: Designing low-level I/O procedures.",13,10
					BYTE	"Written by: Max Grier",13,10,13,10
					BYTE	"Please provide 10 signed decimal integers.",13,10
					BYTE	"Each number needs to be small enough to fit inside a 32 bit register. "
					BYTE	"After you have finished inputting the raw numbers I will display a list "
					BYTE	"of the integers, their sum, and their average value.",13,10,13,10,0

; Program prompts to the user
inputPrompt			BYTE	"Please enter a signed number: ",0
enteredPrompt		BYTE	"You entered the following numbers:",13,10,0
averagePrompt		BYTE	"The rounded average is: ",0
sumPrompt			BYTE	"The sum of these numbers is: ",0
farewellPrompt		BYTE	"Thanks for playing!",13,10,0

; Error message
errorMessage		BYTE	"ERROR: You did not enter a signed number or your number was too big. Please try again.",13,10,0

; Counters and other number variables for calculations and output
intCounter			DWORD	0								; Used for counting the numbers entered
currentIndex		SDWORD	0								; Holds the value of the current index
tempInt				SDWORD	0								; Holds the int value for converting
negative			DWORD	0								; Used to check if the number is negative (1) or positive (0)
sum					SDWORD	0								; Holds the sum of the numbers
average				SDWORD	0								; Holds the average of the numbers

; Arrays to hold the strings and integer values
userInput			BYTE	33			DUP(?)				; Holds the user input string
tempString			BYTE	32			DUP(?)				; Used for the string conversion
intArray			SDWORD	ARRAY_SIZE	DUP(?)				; Holds the integer values
stringArray			DWORD	32			DUP(?)				; Holds the strings entered

; Characters for printing the output
negSign				BYTE	"-",0
comma				BYTE	", ",0

.code

main PROC

; Push the intro prompt onto the stack, then introduce the user to the program
	PUSH	OFFSET introPrompt
	CALL 	introduction

; Push the arrays and necessary parameters before calling readVal
	PUSH	MAX_VALUE
	PUSH	MIN_VALUE
	PUSH	ARRAY_SIZE
	PUSH	negative
	PUSH	tempInt
	PUSH	currentIndex
	PUSH	intCounter
	PUSH	OFFSET	errorMessage
	PUSH	OFFSET	intArray
	PUSH	OFFSET	userInput
	PUSH	OFFSET	inputPrompt
	CALL	readVal
	
; Print out the values as strings
	PUSH	ARRAY_SIZE
	PUSH	OFFSET comma
	PUSH	OFFSET negSign
	PUSH	OFFSET tempString
	PUSH	OFFSET stringArray
	PUSH	OFFSET intArray
	PUSH	OFFSET enteredPrompt
	CALL	writeVal

; Push the references and get the sum and the average
	PUSH	ARRAY_SIZE
	PUSH	OFFSET negSign
	PUSH	OFFSET sumPrompt
	PUSH	OFFSET averagePrompt
	PUSH	OFFSET intArray
	PUSH	OFFSET tempString
	PUSH	OFFSET stringArray
	PUSH	OFFSET average
	PUSH	OFFSET sum
	CALL	sumAndAverage

; Print the farewell message to the user
	PUSH	OFFSET farewellPrompt
	CALL	farewell

	exit	; exit to operating system
main ENDP


;-------------------------------------------------------------------------
; Name: introduction
; Description: Procedure to introduce the program and instructions for user input.
; Preconditions: introPrompt is passed by reference
; Postconditions: EDX is changed to display the prompt
; Receives: Uses introPrompt
; Returns: Nothing other than EDX changed
;
;-------------------------------------------------------------------------

introduction PROC
	PUSH    EBP
	MOV     EBP, ESP					;Set the stack frame
	PUSHAD

; Print introPrompt
	mDisplayString	[EBP+8]
	
	POPAD
	POP		EBP

RET 4
introduction ENDP

;-------------------------------------------------------------------------
; Name: readVal
; Description: This procedure will gather a number as a string and add it to the array.
; Preconditions: A valid user input (fits in SWORD)
; Postconditions: None. Restores and registers changed.
; Receives: MIN_VALUE, ARRAY_SIZE, negative, inputPrompt, userInput, intArray, errorMessage, 
;			intCounter, currentIndex, tempInt
; Returns: Add the number to the array.
;
;-------------------------------------------------------------------------

readVal PROC

	PUSH    EBP
	MOV     EBP, ESP					;Set the stack frame
	PUSHAD								; Preserve registers

_getInput:
; Get the user input as a string
	mGetString	[EBP+8], [EBP+12]
; The MIN and MAX values are only 11 digits long, anything longer is too big
	CMP		EAX, 11
	JG		_invalidInput
; If the input is blank, output the error
	CMP		EAX, 0
	JE		_invalidInput
; Move the amount of characters to ECX
	MOV		ECX, EAX
; Set EDI to the maximum numbers to be entered
	MOV		EDI, [EBP+40]
; Set the userInput to ESI
	MOV		ESI, [EBP+12]
; Clear EBX for later
	MOV		EBX, 0

_checkForSign:
; Checks if there is a "+" or "-" in front of the input
	LODSB
; Checks if there is a "+"
	CMP		AL, 43
	JE		_positive
; Checks if there is a "-"
	CMP		AL, 45
	JE		_negative

_checkForNumber:
; Checks for the end of the string
	CMP		AL, 0
	JE		_testLimits
; Checks if input is below 0
	CMP		AL, 48
	JL		_invalidInput
; Check if input is above 9
	CMP		AL, 57
	JG		_invalidInput
	JMP		_continueLoop

_positive:	
; Move to the next character
	LODSB
	JMP		_checkForNumber

_negative:
; If the input is negative, set the negative variable
	MOV		EAX, 1
	MOV		[EBP+36], EAX
; Check for the next character
	LODSB
	JMP		_checkForNumber

_continueLoop:
; Get the integer value of the input
	SUB		AL, 48
	MOVZX	EBX, AL
; Move temp variable to EAX, multiply by 10, add EBX, and move to temp int variable
	MOV		EAX, [EBP+32]
	MUL		EDI
	ADD		EAX, EBX
	MOV		[EBP+32], EAX
; Keep checking the string
	LODSB
	LOOP	_checkForNumber
	JMP		_testLimits

_invalidInput:
; Print the error message and jump to get a new input
	mDisplayString [EBP+20]
; Clear the negative variable
	MOV		EBX, 0
	MOV		[EBP+36], EBX
; Clear the temp int value
	MOV		[EBP+32], EBX
	JMP		_getInput

_testLimits:
; Move the negative variable to EBX and see if it is set
	MOV		EBX, [EBP+36]
	CMP		EBX, 1
	JNE		_positiveCheck
; If the negative variable is set, check negative limit
_negCheck:
; Set temp value to EAX
	MOV		EAX, [EBP+32]
	NEG		EAX
; Check if it is lower than the limit
	MOV		EBX, [EBP+44]
	NEG		EBX
	ADD		EAX, EBX
	CMP		EAX, 0
	JL		_invalidInput
	JMP		_continueCheck

_positiveCheck:
; Check for the MAX_VALUE
	MOV		EAX, [EBP+32]
	MOV		EBX, [EBP+48]
	SUB		EAX, EBX
	CMP		EAX, 0
	JG		_invalidInput

_continueCheck:
; Set the index to ECX
	MOV		ECX, [EBP+28]
; Set the intArray to EDI
	MOV		EDI, [EBP+16]

_appendArray:
; Set the temp value to EAX
	MOV		EAX, [EBP+32]
; If the value is negative, make it negative.  Otherwise, store as positive
	MOV		EBX, [EBP+36]
	CMP		EBX, 1
	JNE		_append
; Make temp value negative
	NEG		EAX

_append:
; Move the temp value to the intArray
	MOV		[EDI+ECX], EAX

_continueAppend:
; Clear the temp int value
	MOV		EAX, 0
	MOV		[EBP+32], EAX
; Clear the negative variable
	MOV		EBX, 0
	MOV		[EBP+36], EBX
; Add 4 to move to the next index
	MOV		ECX, 4
	ADD		[EBP+28], ECX
; Increment the counter and check if we have received 10 inputs
	MOV		EAX, 1
	ADD		[EBP+24], EAX
	MOV		EAX, [EBP+24]
	MOV		EDX, [EBP+40]
	CMP		EAX, EDX
	JL		_getInput

_end:

	CALL	CrLf
	POPAD
	POP		EBP

RET 32
readVal ENDP

;-------------------------------------------------------------------------
; Name: sumAndAverage
; Description: This procedure finds the sum and the average of the users inputs.
; Preconditions: Have 10 valid inputs from the user.
; Postconditions: Saves the sum and average.
; Receives: average, averagePrompt, negSign, tempString, intArray, sumPrompt, sum
; Returns: The sum and average.
;
;-------------------------------------------------------------------------
sumAndAverage PROC
	PUSH	EBP
	MOV		EBP, ESP								; Set the stack frame
	PUSHAD											; Preserve registers

; Set loop counter to 10
	MOV		ECX, [EBP+40]
; Clear EAX for the sum loop
	MOV		EBX, 0
; Set the intArray to EDI
	MOV		ESI, [EBP+24]

_sum:
; Loop to sum the values

;Move the value to EAX and add it to EBX and increment
	LODSD
	ADD		EBX, EAX
	LOOP	_sum
; Move the sum to the sum variable
	MOV		[EBP+8], EBX

_sumToString:
; Move the sum into the sum variable and push it, the ARRAY_SIZE, stringArray, and tempString to the stack
	PUSH	[EBP+20]
	PUSH	[EBP+40]
	PUSH	[EBP+8]
	PUSH	[EBP+16]
; Switch it to a string
	CALL	intToString

; Print the sumPrompt
	mDisplayString [EBP+32]

; If the sum is positive, print it, otherwise print negSign and make number positive
	MOV		EAX, [EBP+8]
	CMP		EAX, 0
	JG		_printSum
	mDisplayString [EBP+36]
; Make the number positive
	MOV		EAX, [EBP+8]
	NEG		EAX

_printSum:
; Print the sum
	mDisplayString [EBP+20]

_average:
; Gets the average of the values

; Divide by 10 (ARRAY_SIZE)
	MOV		EBX, [EBP+40]
	CDQ
	IDIV	EBX
; Move the average to it's variable
	MOV		[EBP+12], EAX
; Push the ARRAY_SIZE, value, and tempString on the stack for the string switch
	PUSH	[EBP+20]
	PUSH	[EBP+40]
	PUSH	[EBP+12]
	PUSH	[EBP+16]
	CALL	intToString

; Print the averagePrompt
	CALL	CrLf
	mDisplayString [EBP+28]

; If the number is positive, print it, otherwise print negSign first
	MOV		EAX, [EBP+8]
	CMP		EAX, 0
	JG		_printAverage
	mDisplayString [EBP+36]

_printAverage:
; Print the average
	mDisplayString [EBP+20]

_end:
	CALL	CrLf
	CALL	CrLf
	POPAD											; Restore registers
	POP EBP
RET 32
sumAndAverage ENDP

;-------------------------------------------------------------------------
; Name: intToString
; Description: This procdure converts the integer value to a string for output.
; Preconditions: The integer value is a valid input.
; Postconditions: The int will be a string.
; Receives: tempString, number to convert, ARRAY_SIZE, stringArray.
; Returns: The integer as a string.
;
;-------------------------------------------------------------------------

intToString PROC
	PUSH	EBP
	MOV		EBP, ESP					; Set the stack frame
	PUSHAD								; Preserve registers

; Set ARRAY_SIZE to EBX
	MOV		EBX, [EBP+16]
; Set index to EAX
	MOV		EAX, [EBP+12]
; Move the stringArray to EDI
	MOV		EDI, [EBP+8]
; Set the temp string to ESI
	MOV		ESI, [EBP+20]

; Clear ECX for the counter
	MOV		ECX, 0

_checkNegative:
; If the number is positve turn it to a string, otherwise we make it positve then turn to string
	CMP		EAX, 0
	JGE		_toString
	NEG		EAX

_toString:
; Divide by 10
	CDQ		
	IDIV		EBX
; Make remainder ASCII and push on stack
	ADD		EDX, 48
	PUSH	EDX	
; Add one to the counter
	INC		ECX
; See if we reached the end, otherwise keep converting
	CMP		EAX, 0
	JNE		_toString

_loadString:
; Pop the values off the stack and store the strings
	POP		[ESI]
; Load value from ESI to AL
	LODSB
; Store value in AL to EDI
	STOSB
; Continue loading
	LOOP	_loadString

_end:

	POPAD								; Restore registers
	POP EBP
RET 16
intToString ENDP

;-------------------------------------------------------------------------
; Name: writeVal
; Description: This procedure will take a number and use inToString and the mDisplayString macro to print it.
; Preconditions: None.
; Postconditions: String printed.
; Receives: ARRAY_SIZE, comma, negSign, tempString, enteredPrompt, intArray, stringArray
; Returns: The printed string.
;
;-------------------------------------------------------------------------

writeVal PROC
	PUSH    EBP
	MOV     EBP, ESP					;Set the stack frame
	PUSHAD								; Preserve registers

; Set ARRAY_SIZE to ECX
	MOV		ECX, [EBP+32]
; Set the intArray to ESI
	MOV		ESI, [EBP+12]
; Print the enteredPrompt
	mDisplayString [EBP+8]

_printLoop:
; Set the int value into EAX and increment ESI
	LODSD

_toString:
; Push the tempString, ARRAY_SIZE, int value, and stringArray to intToString procedure
	PUSH	[EBP+20]
	PUSH	[EBP+32]
	PUSH	EAX
	PUSH	[EBP+16]
	CALL	intToString

_checkNeg:
; If the number is positive, print it, otherwise print the negative sign then number
	CMP		EAX, 0
	JGE		_outputString
	mDisplayString [EBP+24]

_outputString:	
; Display the string after it's converted from the integer value
	mDisplayString [EBP+20]

_printComma:
; Print the comma except for after the last number
	CMP		ECX, 1
	JE		_nextValue
	mDisplayString [EBP+28]

_nextValue:
; Move to the next value
	LOOP	_printLoop

_end:
	CALL CrLf
	POPAD
	POP		EBP

RET 20
writeVal ENDP


;-------------------------------------------------------------------------
; Name: farewell
; Description: Displays a farewellMessage to the user
; Preconditions: All other procedures worked properly, passed farewellMessage
; Postconditions: Changes EDX
; Receives: farewellMessage
; Returns: Printed the farewell.
;
;-------------------------------------------------------------------------

farewell PROC
	PUSH    EBP
	MOV     EBP, ESP					;Set the stack frame

; Print the farewellMessage
	mDisplayString [EBP+8]

	POP EBP
RET	4
farewell ENDP

END main