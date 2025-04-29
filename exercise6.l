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

//  Add a new variable if it doesn't exist. Returns index.
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
         return -1;
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
#define OPERATOR_STACK_SIZE 50

int evalStack[EVAL_STACK_SIZE];
char operatorStack[OPERATOR_STACK_SIZE];
int stackTop = -1;
int operatorStackTop = -1;

void push(int value) {
    if (stackTop < EVAL_STACK_SIZE - 1) {
        evalStack[++stackTop] = value;
    } else {
        fprintf(stderr, "Error: Evaluation stack overflow.\n");
    }
}

int pop() {
    if (stackTop >= 0) {
        int val = evalStack[stackTop--];
        return val;
    } else {
        return 0; // Return 0 on underflow
    }
}

void pushOperator(char op) {
    if (operatorStackTop < OPERATOR_STACK_SIZE - 1) {
        operatorStack[++operatorStackTop] = op;
    } else {
        fprintf(stderr, "Error: Operator stack overflow.\n");
    }
}

char popOperator() {
    if (operatorStackTop >= 0) {
        return operatorStack[operatorStackTop--];
    } else {
        return '\0'; // Return null character on underflow
    }
}

int operatorPrecedence(char op) {
    if (op == '+' || op == '-') return 1;
    if (op == '*' || op == '/') return 2;
    return 0;
}

void evaluateTopOfStacks() {
    if (stackTop < 1 || operatorStackTop < 0) {
        fprintf(stderr, "Error: Insufficient operands or operators.\n");
        return;
    }

    int right = pop(); // Right operand
    int left = pop();  // Left operand
    char op = operatorStack[operatorStackTop--]; // Operator

    int result = 0;
    if (op == '+') result = left + right;
    else if (op == '-') result = left - right;
    else if (op == '*') result = left * right;
    else if (op == '/') {
        if (right != 0) result = left / right;
        else {
            fprintf(stderr, "Error: Division by zero.\n");
            result = 0;
        }
    }

    printf("SEMANTICS -> Evaluated: %d %c %d = %d\n", left, op, right, result);
    push(result); // Push the result back onto the operand stack
}

// Temporary storage for the most recently seen identifier
char lastIdentifier[50] = "";

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
{NEWLINE}       { /* Ignore */ }
"$"             { /* Ignore */ }

"if"            { printf("Keyword: IF\n"); }

"else"          {
                    printf("Keyword: ELSE\n");
                    isAssignment = 0;
                    if ((skipCodeBlock > 0 && skipCodeBlock > blockLevel + 1) || skipElseBlock) {
                        printf("SEMANTICS -> Skipping ELSE block (IF was true).\n");
                        BEGIN(SKIP_BLOCK);
                        skipCodeBlock = 1;
                    } else {
                        printf("SEMANTICS -> Executing ELSE block (IF was false).\n");
                    }
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
                        findOrAddVar(yytext); // Ensure the variable exists
                        printf("Variable: %s %s\n", yytext, getVarState(yytext));
                        // Push value ONLY if NOT the target of an assignment (i.e., it's RHS/condition/print operand)
                        if (!isAssignment || strcmp(yytext, assignmentTargetVar) != 0) {
                            if (getVarValue(yytext) != -1) {
                                push(getVarValue(yytext)); // Push the variable's value onto the stack
                            } 
                        }
                    }
                }

{NUMBER}        {
                    if (skipCodeBlock == 0) {
                        int val = atoi(yytext);
                        printf("Number: %d\n", val);
                        push(val); // Push the number onto the stack
                        strcpy(lastIdentifier, ""); 
                    }
                }

"="             {
                    if (skipCodeBlock == 0) {
                        printf("Operator: %s\n", yytext);
                        if (strlen(lastIdentifier) > 0) {
                            isAssignment = 1;
                            strcpy(assignmentTargetVar, lastIdentifier); 
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
                        printf("Operator: %s\n", yytext);
                        char currentOp = yytext[0];

                        // Evaluate higher precedence operators first
                        while (operatorStackTop >= 0 &&
                            operatorPrecedence(operatorStack[operatorStackTop]) >= operatorPrecedence(currentOp)) {
                            evaluateTopOfStacks();
                        }

                        // Push the current operator onto the operator stack
                        pushOperator(currentOp);
                    }
                }

">" |
"<" |
">=" |
"<=" |
"==" |
"!="            {
                    if (skipCodeBlock == 0) {
                        int right, left;
                        const char* op_str = yytext;
                        printf("Operator: %s\n", yytext);

                        if (stackTop < 1) {
                            fprintf(stderr, "Error: Stack underflow for operator '%s'.\n", op_str);
                            conditionResult = 0; // Default condition to false on error
                        } else {
                            right = pop();
                            left = pop();
                            if (strcmp(op_str, ">") == 0) conditionResult = (left > right);
                            else if (strcmp(op_str, "<") == 0) conditionResult = (left < right);
                            else if (strcmp(op_str, ">=") == 0) conditionResult = (left >= right);
                            else if (strcmp(op_str, "<=") == 0) conditionResult = (left <= right);
                            else if (strcmp(op_str, "==") == 0) conditionResult = (left == right);
                            else if (strcmp(op_str, "!=") == 0) conditionResult = (left != right);

                            printf("SEMANTICS -> Condition: %d %s %d = %s\n", left, op_str, right, conditionResult ? "true" : "false");
                        }
                        strcpy(lastIdentifier, ""); // Operator consumed operands
                    }
                }

";"             {
                    printf("Delimiter: ;\n");
                    if (skipCodeBlock == 0) {
                        // Evaluate remaining operators
                        while (operatorStackTop >= 0) {
                            evaluateTopOfStacks();
                        }

                        if (isAssignment == 1) {
                            if (strlen(assignmentTargetVar) > 0 && stackTop >= 0) {
                                int value = pop(); // Get the evaluated result
                                int targetIndex = findOrAddVar(assignmentTargetVar);
                                if (targetIndex != -1) {
                                    symbolTable[targetIndex].value = value;
                                    symbolTable[targetIndex].defined = 1; // Mark as defined
                                    printf("SEMANTICS -> Assigned %d to variable %s\n", value, assignmentTargetVar);
                                }
                            } else if (stackTop < 0) {
                                fprintf(stderr, "Error: Missing value for assignment to %s\n", assignmentTargetVar);
                            }
                        } else if (stackTop >= 0) {
                            // Standalone expression result, discard
                            int discarded_val = pop();
                            printf("SEMANTICS -> Statement result %d discarded (not part of assignment)\n", discarded_val);
                        }

                        // Reset state for the next statement
                        isAssignment = 0;
                        strcpy(assignmentTargetVar, "");
                        strcpy(lastIdentifier, "");
                        // Clear stack completely
                        while (stackTop >= 0) pop();
                        stackTop = -1;
                    }
                }

"("             {
                    if (skipCodeBlock == 0) {
                        printf("Delimiter: (\n");
                        push(-1); // Use -1 as a marker for parentheses
                    }
                }
")"             {
                    if (skipCodeBlock == 0) {
                        printf("Delimiter: )\n");
                        int result = 0;
                        // Evaluate the expression inside the parentheses
                        while (stackTop >= 0 && evalStack[stackTop] != -1) {
                            result += pop(); // Simplified: assumes addition; extend for full operator support
                        }
                        if (stackTop >= 0 && evalStack[stackTop] == -1) {
                            pop(); // Remove the marker
                            push(result); // Push the evaluated result back onto the stack
                        } else {
                            fprintf(stderr, "Error: Mismatched parentheses.\n");
                        }
                    }
                }

"{"             {
                  printf("Delimiter: {\n");
                  if (skipCodeBlock > 0) skipCodeBlock++; 
                  else {
                      if (!conditionResult) {
                          skipCodeBlock = 1; printf("SEMANTICS -> Condition FALSE, start skipping block, level = %d\n", skipCodeBlock); BEGIN(SKIP_BLOCK);
                      } else {
                          skipElseBlock = 1; blockLevel++; printf("SEMANTICS -> Condition TRUE, executing block, level = %d\n", blockLevel);
                      }
                  }
                  conditionResult = 1; // Reset for next potential condition check
                }
"}"             {
                   printf("Delimiter: }\n");
                   if (skipCodeBlock > 0) {
                       skipCodeBlock--;
                       if (skipCodeBlock == 0) { BEGIN(INITIAL); }
                   } else {
                       blockLevel--; printf("SEMANTICS -> End executed block brace, level = %d\n", blockLevel);
                   }
                }

.               { fprintf(stderr, "Error: Unexpected character: %s\n", yytext); }


<PRINT_VAR>{IDENTIFIER} {
    //  PRINT_VAR state is entered *after* 'print' keyword. It expects an identifier next.
    if (skipCodeBlock == 0) {
        printf("SEMANTICS -> Printing value of %s: ", yytext);

        if (getVarValue(yytext) != -1) {
            printf("%d\n", getVarValue(yytext));
        } else {
            printf("Undefined variable '%s'.\n", yytext);
        }
    }
    //  Stay in PRINT_VAR state, wait for semicolon
}
<PRINT_VAR>{WHITESPACE} { /* Ignore */ }
<PRINT_VAR>";" {
    printf("End of Statement: ;\n");
    BEGIN(INITIAL); // Return to initial state
}
<PRINT_VAR>.|\n {
    fprintf(stderr, "Error: Expected variable name and semicolon after 'print'. Found: %s\n", yytext);
    BEGIN(INITIAL);
}

<SKIP_BLOCK>"{"     { skipCodeBlock++; }
<SKIP_BLOCK>"}"     {
                        skipCodeBlock--;
                        if (skipCodeBlock == 0) { BEGIN(INITIAL); printf("SEMANTICS -> Exiting SKIP_BLOCK state.\n"); }
                    }
<SKIP_BLOCK>.|\n    { /* Ignore */ }


%%
/* === C Code Section === */

 int yywrap() { return 1; }

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
    printf("\n--- Mini Evaluator Start ---\n\n");
    if (argc > 1) {
        printf("Reading input from file: %s\n", argv[1]);
        FILE *file = fopen(argv[1], "r");
        if (!file) { perror("Error opening file"); return 1; }
        yyin = file;
    } else {
        printf("Reading input from standard input:\n\n");
    }
    yylex();
    if (yyin != stdin) fclose(yyin);
    printFinalState();
    return 0;
}
