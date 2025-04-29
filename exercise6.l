%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// --- Symbol Table for Variables ---
#define MAX_VARS 100

typedef struct {
    char name[50];
    int value;
    int defined; // Flag to check if the variable has been assigned a value
} Variable;

Variable symbolTable[MAX_VARS];
int varCount = 0;

// --- Helper Functions for Symbol Table ---

// Find a variable's index in the table, return -1 if not found
int findVar(const char* name) {
    for (int i = 0; i < varCount; i++) {
        if (strcmp(symbolTable[i].name, name) == 0) {
            return i;
        }
    }
    return -1;
}

 Add a new variable if it doesn't exist. Returns index.
int findOrAddVar(const char* name) {
    int index = findVar(name);
    if (index != -1) {
        return index;
    } else if (varCount < MAX_VARS) {
        strcpy(symbolTable[varCount].name, name);
        symbolTable[varCount].defined = 0; // Mark as not defined initially
        varCount++;
        return varCount - 1;
    } else {
        fprintf(stderr, "Error: Symbol table full.\n");
        return -1;
    }
}


int getVarValue(const char* name) {
    int index = findVar(name);
    if (index != -1 && symbolTable[index].defined) {
        return symbolTable[index].value;
    } else if (index != -1 && !symbolTable[index].defined) {
         fprintf(stderr, "Warning: Variable '%s' used before assignment. Assuming 0.\n", name);
         return 0;
    }
    else {

        fprintf(stderr, "Error: Undefined variable '%s' used. Assuming 0.\n", name);
        int newIndex = findOrAddVar(name);
        if (newIndex != -1) symbolTable[newIndex].defined = 0;
        return 0;
    }
}

// Get variable state string (for printing)
const char* getVarState(const char* name) {
    int index = findVar(name);
     if (index != -1 && symbolTable[index].defined) {
        static char buffer[100];
        sprintf(buffer, "(Value: %d)", symbolTable[index].value);
        return buffer;
    } else if (index != -1 && !symbolTable[index].defined) {
        return "(Not yet assigned)";
    } else {
        return "(Undefined)";
    }
}


// --- State Management for Simple Control Flow ---
int conditionResult = 0;
int skipElseBlock = 0;
int skipCodeBlock = 0;
int blockLevel = 0;

// --- State Management for Assignment ---
int isAssignment = 0;          
char assignmentTargetVar[50] = ""; // Stores the name of the variable being assigned to

// Simple stack for expression evaluation
#define EVAL_STACK_SIZE 50
int evalStack[EVAL_STACK_SIZE];
int stackTop = -1;

void push(int value) {
    if (stackTop < EVAL_STACK_SIZE - 1) {
        evalStack[++stackTop] = value;
        // printf(" Debug push: %d (Top: %d)\n", value, stackTop); // Optional debug
    } else {
        fprintf(stderr, "Error: Evaluation stack overflow.\n");
    }
}

int pop() {
    if (stackTop >= 0) {
        int val = evalStack[stackTop--];
        // printf(" Debug pop: %d (Top: %d)\n", val, stackTop); // Optional debug
        return val;
    } else {
        // fprintf(stderr, "Error: Evaluation stack underflow.\n"); // Report in caller if needed
        return 0; // Return 0 on underflow
    }
}

// Temporary storage for variable names
char lastIdentifier[50] = ""; // Stores the most recently seen identifier

// Forward declaration for function defined after main
void printFinalState();

%}

/* === Flex Definitions === */
%x PRINT_VAR SKIP_BLOCK

/* Token Definitions */
DIGIT       [0-9]
LETTER      [a-zA-Z_]
IDENTIFIER  {LETTER}({LETTER}|{DIGIT})*
NUMBER      {DIGIT}+
WHITESPACE  [ \t]+
NEWLINE     \n

%%


{WHITESPACE}    { /* Ignore */ }
{NEWLINE}       { printf(" -> Newline\n"); }
"$"             { /* Ignore */ }

"if"            {
                  printf("Keyword: IF\n");
                  if (skipCodeBlock > 0) { BEGIN(SKIP_BLOCK); skipCodeBlock++; }
                  else { isAssignment = 0; skipElseBlock = 0; }
                }
"else"          {
                  printf("Keyword: ELSE\n");
                  isAssignment = 0;
                  if ( (skipCodeBlock > 0 && skipCodeBlock > blockLevel + 1) || skipElseBlock ) {
                      if(skipElseBlock) printf(" -> Skipping ELSE block (IF was true)\n");
                      else printf(" -> Nested in skipped block, continuing skip\n");
                      BEGIN(SKIP_BLOCK); skipCodeBlock = 1;
                  } else { printf(" -> Executing ELSE block (IF was false)\n"); }
                  skipElseBlock = 0;
                }
"while"         {
                  printf("Keyword: WHILE\n");
                  fprintf(stderr, "Warning: 'while' loop simulation is very basic.\n");
                  if (skipCodeBlock > 0) { BEGIN(SKIP_BLOCK); skipCodeBlock++; }
                  else { isAssignment = 0; }
                }
"print"         {
                   if (skipCodeBlock == 0) {
                       printf("Action: PRINT\n");
                       isAssignment = 0;
                       BEGIN(PRINT_VAR);
                   }
                }

{IDENTIFIER}    {
                  if (skipCodeBlock == 0) {
                      strcpy(lastIdentifier, yytext);
                      findOrAddVar(yytext); // Ensure var exists
                      printf("Variable: %s %s\n", yytext, getVarState(yytext));
                      // Push value ONLY if NOT the target of an assignment (i.e., it's RHS/condition/print operand)
                      if (!isAssignment || strcmp(yytext, assignmentTargetVar) != 0) {
                          push(getVarValue(yytext));
                      }
                  }
                }

{NUMBER}        {
                  if (skipCodeBlock == 0) {
                      int val = atoi(yytext);
                      printf("Number: %s (%d)\n", yytext, val);
                      push(val); // Numbers are always operands
                      strcpy(lastIdentifier, ""); 
                  }
                }

"="             {
                  if (skipCodeBlock == 0) {
                      printf("Operator: ASSIGN\n");
                      if (strlen(lastIdentifier) > 0) {
                          isAssignment = 1;
                          strcpy(assignmentTargetVar, lastIdentifier); 
                          printf(" -> Target for assignment: %s\n", assignmentTargetVar);

                      } else {
                          fprintf(stderr, "Error: Assignment '=' without preceding variable.\n");
                          isAssignment = 0;
                      }
         
                  }
                }

"+" |
"-" |
"*" |
"/"             {
                  if (skipCodeBlock == 0) {
                      int right, left, result;
                      const char* op_str = yytext; // Get operator string
                      if (strcmp(op_str, "+") == 0) printf("Operator: ADD\n");
                      else if (strcmp(op_str, "-") == 0) printf("Operator: SUBTRACT\n");
                      else if (strcmp(op_str, "*") == 0) printf("Operator: MULTIPLY\n");
                      else if (strcmp(op_str, "/") == 0) printf("Operator: DIVIDE\n");

                      if (stackTop < 1) { // Need at least two operands
                          fprintf(stderr, "Error: Stack underflow for operator '%s'.\n", op_str);
                          push(0); // Push dummy result
                      } else {
                          right = pop();
                          left = pop();
                          if (strcmp(op_str, "+") == 0) result = left + right;
                          else if (strcmp(op_str, "-") == 0) result = left - right;
                          else if (strcmp(op_str, "*") == 0) result = left * right;
                          else if (strcmp(op_str, "/") == 0) {
                              if (right != 0) result = left / right;
                              else { fprintf(stderr, "Error: Division by zero.\n"); result = 0; }
                          }
                          printf(" -> Evaluated: %d %s %d = %d\n", left, op_str, right, result);
                          push(result);
                      }
                      strcpy(lastIdentifier, ""); // Operator consumed operands
                  }
                }

">" |
"<"             {
                  if (skipCodeBlock == 0) {
                      int right, left;
                      const char* op_str = yytext;
                      if (strcmp(op_str, ">") == 0) printf("Operator: GT\n");
                      else if (strcmp(op_str, "<") == 0) printf("Operator: LT\n");

                      if (stackTop < 1) {
                          fprintf(stderr, "Error: Stack underflow for operator '%s'.\n", op_str);
                          conditionResult = 0; // Default condition to false on error
                      } else {
                          right = pop();
                          left = pop();
                          if (strcmp(op_str, ">") == 0) conditionResult = (left > right);
                          else if (strcmp(op_str, "<") == 0) conditionResult = (left < right);
                          printf(" -> Condition: %d %s %d = %s\n", left, op_str, right, conditionResult ? "true" : "false");
                      }
                       strcpy(lastIdentifier, ""); // Operator consumed operands
                  }
                }

";"             {
                  printf("End of Statement: ;\n");
                  if (skipCodeBlock == 0) {
                      if (isAssignment == 1) {
                          if (strlen(assignmentTargetVar) > 0 && stackTop >= 0) {
                              int value = pop();
                              int targetIndex = findOrAddVar(assignmentTargetVar);
                              if(targetIndex != -1) {
                                 symbolTable[targetIndex].value = value;
                                 symbolTable[targetIndex].defined = 1; // Mark defined *after* assignment
                                 printf(" -> Assigned %d to %s\n", value, assignmentTargetVar);
                              }
                          } else if (stackTop < 0) {
                              fprintf(stderr, "Error: Missing RHS value for assignment to %s\n", assignmentTargetVar);
                          }
                      } else if (stackTop >= 0) {
                           // Standalone expression result, discard
                           int discarded_val = pop();
                           printf(" -> Statement result %d discarded (not part of assignment)\n", discarded_val);
                      }

                      // Reset state for the next statement
                      isAssignment = 0;
                      strcpy(assignmentTargetVar, "");
                      strcpy(lastIdentifier, "");
                      // Clear stack completely
                      while(stackTop >= 0) pop();
                      stackTop = -1;
                  }
                }

"("             { if (skipCodeBlock == 0) printf("Syntax: (\n"); }
")"             { if (skipCodeBlock == 0) printf("Syntax: )\n"); }

"{"             {
                  printf("Syntax: {\n");
                  if (skipCodeBlock > 0) { skipCodeBlock++; printf(" -> Skipping nested block, level = %d\n", skipCodeBlock); }
                  else {
                      if (!conditionResult) {
                          skipCodeBlock = 1; printf(" -> Condition FALSE, start skipping block, level = %d\n", skipCodeBlock); BEGIN(SKIP_BLOCK);
                      } else {
                          skipElseBlock = 1; blockLevel++; printf(" -> Condition TRUE, executing block, level = %d\n", blockLevel);
                      }
                  }
                  conditionResult = 1; // Reset for next potential condition check
                }
"}"             {
                   printf("Syntax: }\n");
                   if (skipCodeBlock > 0) {
                       skipCodeBlock--; printf(" -> End skipping block brace, level = %d\n", skipCodeBlock);
                       if (skipCodeBlock == 0) { printf(" -> Finished skipping block.\n"); BEGIN(INITIAL); }
                   } else {
                       blockLevel--; printf(" -> End executed block brace, level = %d\n", blockLevel);
                   }
                }

.               { fprintf(stderr, "Error: Unexpected character: %s\n", yytext); }


<PRINT_VAR>{IDENTIFIER} {
     PRINT_VAR state is entered *after* 'print' keyword. It expects an identifier next.
    if (skipCodeBlock == 0) {
        printf(" -> Printing value of %s: ", yytext);
         We need the value of the variable named yytext
        printf("%d\n", getVarValue(yytext));  Get value directly
    }
     Stay in PRINT_VAR state, wait for semicolon
}
<PRINT_VAR>{WHITESPACE} { /* Ignore */ }
<PRINT_VAR>";" {
    printf("End of Statement: ;\n");
    BEGIN(INITIAL);  Return to initial state
}
<PRINT_VAR>.|\n {
    fprintf(stderr, "Error: Expected variable name and semicolon after 'print'. Found: %s\n", yytext);
    BEGIN(INITIAL);
}

<SKIP_BLOCK>"{"     { skipCodeBlock++; printf(" -> Skipping nested {\n"); }
<SKIP_BLOCK>"}"     {
                        skipCodeBlock--; printf(" -> Skipping nested }\n");
                        if (skipCodeBlock == 0) { BEGIN(INITIAL); printf(" -> Exiting SKIP_BLOCK state.\n"); }
                    }
<SKIP_BLOCK>.|\n    { /* Ignore */ }


%%
/* === C Code Section === */

 int yywrap() { return 1; }  Uncomment if not linking with -lfl

void printFinalState() {
    printf("\n--- Mini Evaluator End ---\n");
    printf("\n--- Final State ---\n");
    if (stackTop >= 0) {
        printf("Final stack state: Not empty (Top: %d) - Issue likely.\n", stackTop);
        printf("  Remaining stack: ");
        for(int i=0; i <= stackTop; i++) printf("%d ", evalStack[i]);
        printf("\n");
    } else {
        printf("Final stack state: Empty\n");
    }
    printf("Symbol Table:\n");
    if (varCount == 0) printf("  (empty)\n");
    else {
        for (int i = 0; i < varCount; i++) {
            if (symbolTable[i].defined) printf("  %s = %d\n", symbolTable[i].name, symbolTable[i].value);
            else printf("  %s = (Not yet assigned)\n", symbolTable[i].name);
        }
    }
}

int main(int argc, char *argv[]) {
    printf("--- Mini Evaluator Start ---\n\n");
    if (argc > 1) {
        printf("Reading input from file: %s\n", argv[1]);
        FILE *file = fopen(argv[1], "r");
        if (!file) { perror("Error opening file"); return 1; }
        yyin = file;
    } else {
        printf("Reading input from standard input (Ctrl+D to end):\n");
    }
    yylex();
    if (yyin != stdin) fclose(yyin);
    printFinalState();
    return 0;
}
