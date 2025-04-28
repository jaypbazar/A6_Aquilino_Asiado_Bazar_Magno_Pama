

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Simple symbol table structure (for basic variable handling)
typedef struct {
    char *name;
    int value;
} Symbol;

#define MAX_SYMBOLS 100
Symbol symbolTable[MAX_SYMBOLS];
int symbolCount = 0;

// Function to look up or add a variable
int lookupOrAddSymbol(char *name) {
    for (int i = 0; i < symbolCount; i++) {
        if (strcmp(symbolTable[i].name, name) == 0) {
            return i; // Return index if found
        }
    }
    // Add if not found
    if (symbolCount < MAX_SYMBOLS) {
        symbolTable[symbolCount].name = strdup(name); // Store a copy of the name
        symbolTable[symbolCount].value = 0; // Default value
        return symbolCount++;
    } else {
        fprintf(stderr, "Error: Symbol table full.\n");
        exit(EXIT_FAILURE);
    }
}

// Simple stack for basic expression evaluation (demonstration only)
#define STACK_SIZE 50
int evalStack[STACK_SIZE];
int stackTop = -1;

void push(int value) {
    if (stackTop < STACK_SIZE - 1) {
        evalStack[++stackTop] = value;
    } else {
        fprintf(stderr, "Error: Evaluation stack overflow.\n");
        // In a real evaluator, more robust error handling is needed.
    }
}

int pop() {
    if (stackTop >= 0) {
        return evalStack[stackTop--];
    } else {
        fprintf(stderr, "Error: Evaluation stack underflow.\n");
        // In a real evaluator, more robust error handling is needed.
        return 0; // Return a default value
    }
}

// --- Global state for simple control flow simulation ---
int if_condition_result = 0; // Simulate the result of the last 'if' condition check
int in_if_block = 0;         // Flag to track if we are inside an 'if' block's actions
int in_else_block = 0;       // Flag to track if we are inside an 'else' block's actions

%}

/* Lex Definitions */
/* Suppress warning about unused yywrap */
%option noyywrap

DIGIT       [0-9]
ID          [a-zA-Z_][a-zA-Z_0-9]*
WHITESPACE  [ \t]+
NEWLINE     \n

%%

{WHITESPACE}    { /* Ignore whitespace */ }
{NEWLINE}       { printf(" -> Newline\n"); /* Optionally track lines */ }

"if"            {
                  printf("Keyword: IF\n");
                  // --- Simulation Logic ---
                  if_condition_result = 1; // Simulate TRUE condition
                  in_if_block = 1;
                  in_else_block = 0;
                  // --- End Simulation ---
                }
"else"          {
                  printf("Keyword: ELSE\n");
                  // --- Simulation Logic ---
                  if (in_if_block) { // 'else' should follow an 'if' context
                     if (if_condition_result == 1) {
                         printf(" -> Skipping ELSE block (IF was true)\n");
                         in_else_block = 0; // Don't execute else
                     } else {
                         printf(" -> Entering ELSE block (IF was false)\n");
                         in_else_block = 1; // Execute else
                     }
                     in_if_block = 0; // Exiting the 'if'/'else' context for this rule
                  } else {
                      fprintf(stderr, "Syntax Error: 'else' without matching 'if'\n");
                  }
                  // --- End Simulation ---
                }
"while"         { printf("Keyword: WHILE\n"); /* Simple recognition */ }

{DIGIT}+        {
                  int num = atoi(yytext);
                  printf("Number: %s (%d)\n", yytext, num);
                  // Push number onto the evaluation stack for basic arithmetic demo
                  push(num);
                }

{ID}            {
                  int index = lookupOrAddSymbol(yytext);
                  printf("Variable: %s (Value: %d)\n", yytext, symbolTable[index].value);
                  // push variable's value onto the stack
                  push(symbolTable[index].value);
                }

"+"             {
                  printf("Operator: ADD\n");
                  if (stackTop >= 1) {
                      int right = pop();
                      int left = pop();
                      push(left + right);
                      printf(" -> Evaluated: %d + %d = %d\n", left, right, evalStack[stackTop]);
                  } else {
                      fprintf(stderr, "Syntax Error: Not enough operands for +\n");
                  }
                }
"-"             {
                  printf("Operator: SUBTRACT\n");
                  if (stackTop >= 1) {
                      int right = pop();
                      int left = pop();
                      push(left - right);
                      printf(" -> Evaluated: %d - %d = %d\n", left, right, evalStack[stackTop]);
                  } else {
                       fprintf(stderr, "Syntax Error: Not enough operands for -\n");
                  }
                }
"*"             {
                  printf("Operator: MULTIPLY\n");
                  if (stackTop >= 1) {
                      int right = pop();
                      int left = pop();
                      push(left * right);
                      printf(" -> Evaluated: %d * %d = %d\n", left, right, evalStack[stackTop]);
                  } else {
                      fprintf(stderr, "Syntax Error: Not enough operands for *\n");
                  }
                }
"/"             {
                  printf("Operator: DIVIDE\n");
                  if (stackTop >= 1) {
                      int right = pop();
                      int left = pop();
                      if (right != 0) {
                          push(left / right);
                          printf(" -> Evaluated: %d / %d = %d\n", left, right, evalStack[stackTop]);
                      } else {
                          fprintf(stderr, "Runtime Error: Division by zero.\n");
                          push(0); // Push a default value on error
                      }
                  } else {
                      fprintf(stderr, "Syntax Error: Not enough operands for /\n");
                  }
                }
"="             {
                  printf("Operator: ASSIGN\n");
                  // Basic assignment: expects value then variable identifier just before '='
                  if (stackTop >= 0 && symbolCount > 0) {
                       int value_to_assign = pop();
                       // Assume the last processed ID is the target.
                       int target_var_index = symbolCount - 1;
                       symbolTable[target_var_index].value = value_to_assign;
                       printf(" -> Assigned %d to %s\n", value_to_assign, symbolTable[target_var_index].name);
                  } else {
                       fprintf(stderr, "Syntax Error: Invalid assignment sequence.\n");
                  }
                }

.               { printf("Unrecognized character: %s\n", yytext); }

%%

/* C Code Section */
int main(int argc, char **argv) {
    // If a filename is provided, read from the file
    if (argc > 1) {
        FILE *file = fopen(argv[1], "r");
        if (!file) {
            perror("Error opening file");
            return EXIT_FAILURE;
        }
        yyin = file; // Point Flex input to the file
    }
    // Otherwise, Flex reads from standard input (stdin) by default

    printf("--- Mini Evaluator Start ---\n");
    yylex(); // Start the lexical analysis
    printf("--- Mini Evaluator End ---\n");

    // Optional: Print final stack state or symbol table
    printf("\n--- Final State ---\n");
    if (stackTop >= 0) {
       printf("Final value on stack: %d\n", evalStack[stackTop]);
    } else {
       printf("Evaluation stack is empty.\n");
    }
     printf("Symbol Table:\n");
    for (int i = 0; i < symbolCount; i++) {
        printf("  %s = %d\n", symbolTable[i].name, symbolTable[i].value);
    }


    // Clean up allocated memory for symbol names
    for (int i = 0; i < symbolCount; i++) {
        free(symbolTable[i].name);
    }


    return EXIT_SUCCESS;
}
