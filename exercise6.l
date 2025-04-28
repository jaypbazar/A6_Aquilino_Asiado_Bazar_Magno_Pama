%{
    #include <stdio.h>
    #include <string.h>
    #include <stdlib.h>

    int yywrap(void) { return 1; } 

    // Define a new data type for tokens
    typedef struct {
        char type[32];
        char value[100];
    } Token;

    // Declare a token variable to store the tokens
    Token tokens[1000];
    int token_index = 0;
    int current_token = 0;
%}

%%
"if"                    { 
                            // Add the if keyword to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "IF");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }
"else"                  { 
                            // Add the else keyword to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "ELSE");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }
"while"                 { 
                            // Add the while keyword to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "WHILE");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }
"print"                 { 
                            // Add the print function to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "PRINT");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }
[a-zA-Z_][a-zA-Z0-9_]*  { 
                            // Add the identifier to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "ID");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }
[0-9]+                  { 
                            // Add the number literal to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "NUM");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++; 
                        }
"=="|"!="|"<="|">="|"<"|">" {
                            // Add the relational operator to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "RELOP");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }
"="                     {
                            // Add the assignment operator to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "ASSIGN");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }
[+\-*/]                 { 
                            // Add the arithmetic operator to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "OP");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }   
[(){};]                 { 
                            // Add the delimeter to the lists of tokens and move to the next index
                            strcpy(tokens[token_index].type, "DELIM");
                            strcpy(tokens[token_index].value, yytext);
                            token_index++;
                        }   
[\n\t ]+                 // ignore whitespaces
%%

int main() {
    yylex(); 
    return 0;
}