%{
    #include <stdio.h>
    int yywrap(void) { return 1; } 
%}

%%

%%

int main() {
    yylex(); 
    return 0;
}