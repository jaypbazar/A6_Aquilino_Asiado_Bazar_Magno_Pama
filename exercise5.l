%{
    #include <stdio.h>
    int yywrap(void) { return 1; } 
%}

%%
"if"                    { 
                            printf("Keyword: %s\n", yytext); 
                        }
"else"                  { 
                            printf("Keyword: %s\n", yytext); 
                        }
"while"                 { 
                            printf("Keyword: %s\n", yytext); 
                        }
"print"                 { 
                            printf("Function: %s\n", yytext); 
                        }
[a-zA-Z_][a-zA-Z0-9_]*  { 
                            printf("Identifier: %s\n", yytext); 
                        }
[0-9]+                  { 
                            printf("Integer: %s\n", yytext); 
                        }
[+\-*/=<>]+             { 
                            printf("Operator: %s\n", yytext); 
                        }   
[(){};]                 { 
                            printf("Delimiter: %s\n", yytext); 
                        }   
[\n\t ]+                 // ignore whitespaces
%%

int main() {
    yylex(); 
    return 0;
}