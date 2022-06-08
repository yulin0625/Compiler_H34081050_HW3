/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* func_sig, int is_param_function);
    static Symbol lookup_symbol(char* name, int tables);
    static void dump_symbol(int level);
    static char* check_type(char* name);

    /* Global variables */
    bool g_has_error = false;
    FILE *fout = NULL;
    int g_indent_cnt = 0;
    //label count
    int cmp_count = -1;
    int if_count = -1;
    int for_count = -1;
    int switch_count = -1;
    int number_of_case = 0; //紀錄case數量
    int case_key[10]; //紀錄case的key
    int has_default = 0; //紀錄是否有default
    //my variable
    Symbol symbol_table[30][40];
    int table_size[30];
    // Symbol *current; //current read in token
    int address = 0; // symbol table variable address(unique)
    int level = -1; // symbol table scope level
    int is_func = 0;
    char operation[10]; //紀錄目前的operation
    int is_left = 1; //紀錄var 是否在=左邊，在左的話紀錄Lvar_addr
    int Lvar_addr = -1; //紀錄=左邊的var addr
    char Lvar_name[10]; //紀錄=左邊的var name(debug用)
    char Lvar_type[10]; //紀錄=左邊的var type(debug用)
    //record function information
    char func_name[15];
    int paraList_not_null;
    char func_signature[15];
    char return_type[10];
%}

/* %error-verbose */

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    char *s_val;
    // int i_val;
    // float f_val;
    /* ... */
}

/* Token without return */
%token VAR 
%token INT FLOAT BOOL STRING
%token INC DEC GEQ LEQ EQL NEQ 
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token PACKAGE
%token FUNC RETURN DEFAULT

/* Token with return, which need to sepcify type */
%token <s_val> INT_LIT FLOAT_LIT STRING_LIT BOOL_LIT
%token <s_val> IDENT NEWLINE 
%token <s_val> LAND LOR PRINT PRINTLN 
%token <s_val> IF ELSE FOR SWITCH CASE

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type Literal Lvalue Condition
%type <s_val> PrintStmt AssignmentStmt SimpleStmt 
%type <s_val> IncDecStmt ExpressionStmt ForStmt SwitchStmt CaseStmt
%type <s_val> Expression LandExpr AddExpr MulExpr 
%type <s_val> CmpExpr PrimaryExpr UnaryExpr ConversionExpr IndexExpr
%type <s_val> Operand Assign_op Unary_op  Cmp_op Add_op Mul_op Block

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE
    | FunctionDeclStmt
    | NEWLINE
;

PackageStmt
    : PACKAGE IDENT { 
        create_symbol();
        printf("package: %s\n", $2); 
    }
;

FunctionDeclStmt
    : FUNC IDENT 
    {
        strcpy(func_name, $2);
        printf("func: %s\n", func_name);
        create_symbol();
    }
    '(' { strcpy(func_signature, "("); } 
    ParameterList
    ')' { strcat(func_signature, ")"); } 
    ReturnType 
    {
        strcat(func_signature, return_type);
    	printf ("func_signature: %s\n", func_signature);
    	insert_symbol(func_name, "func", func_signature, 0);
        if(strcmp(func_name, "main")==0){
            fprintf(fout, ".method public static main([Ljava/lang/String;)V\n");
        }
        else{
            fprintf(fout, ".method public static %s%s\n", func_name, func_signature);
        }
        fprintf(fout, ".limit stack 50\n");
        fprintf(fout, ".limit locals 50\n");
    }  
    FuncBlock
    {
        if(strcmp(return_type, "I")==0){
            fprintf(fout, "\tireturn\n");
        }
        else if(strcmp(return_type, "F")==0){
            fprintf(fout, "\tfreturn\n");
        }
        else if(strcmp(return_type, "V")==0){
            fprintf(fout, "\treturn\n");
        }
        fprintf(fout, ".end method\n\n");
    }
;

ParameterList
    : Parameter
    | ParameterList ',' Parameter
;

Parameter
    : IDENT Type 
    {
        char type[20];
        char param_type[20];

        if(strcmp($2, "int32")==0){
            strcpy(param_type,"I");
            strcpy(type, "int32");
            strcat(func_signature, "I");
        }
        else if(strcmp($2, "float32")==0){
            strcpy(param_type, "F");
            strcpy(type, "float32");
            strcat(func_signature, "F");
        }
        printf("param %s, type: %s\n", $1, param_type); 
        insert_symbol($1, type, "-", 1);  
    }
    | 
;    

ReturnType
    : INT { strcpy(return_type,"I"); }
    | FLOAT { strcpy(return_type,"F"); }
    | STRING 
    | BOOL
    | { strcpy(return_type,"V"); }
;    

FuncBlock
    : '{' { level++; }
    StatementList 
    '}' { dump_symbol(level); }
;

CallFunc
    : IDENT '(' CallFuncParamList ')' 
    {
        is_func = 1;
    	Symbol t = lookup_symbol($1, 1);
        if(t.addr == -1){
           printf("call: %s%s\n",$1,t.func_sig);
           is_func = 0;
        }
        fprintf(fout, "\tinvokestatic Main/%s%s\n", $1, t.func_sig); //invoke  method in `Main` class
    }
;    

CallFuncParamList
    : CallFuncParam
    | CallFuncParamList ',' CallFuncParam
;    

CallFuncParam
    : Lvalue
    |
;    

Lvalue
    : Literal { $$ = $1; }
    | IDENT 
    { 
    	Symbol t = lookup_symbol($1, 1);
        if(strcmp(t.name, "NotDefineYet")!=0){ 
            printf("IDENT (name=%s, address=%d)\n", $1, t.addr);

            if(strcmp(t.type, "int32")==0){
                $$ = "int32";
                fprintf(fout, "\tiload %d\n", t.addr);
            }
            else if(strcmp(t.type, "float32")==0){
                $$ = "float32";
                fprintf(fout, "\tfload %d\n", t.addr);
            }
            else if(strcmp(t.type, "string")==0){
                $$ = "string";
                fprintf(fout, "\taload %d\n", t.addr);
            }
            else if(strcmp(t.type, "bool")==0){
                $$ = "bool";
                fprintf(fout, "\tiload %d\n", t.addr);
            }
            
            if(is_left==1){
                Lvar_addr = t.addr;
                strcpy(Lvar_name, t.name);
                strcpy(Lvar_type, t.type);
            }
        }
        else{
            printf("error:%d: undefined: %s\n", yylineno+1, $1);
            Lvar_addr = -1;
            g_has_error = true;
            $$ = "null";
        }
    }
;

Literal
    : INT_LIT 
    {
        printf("INT_LIT %s\n", $1); 
        fprintf(fout, "\tldc %s\n", $1);
        $$ = "int32"; 
    }
    | FLOAT_LIT 
    { 
        printf("FLOAT_LIT %f\n", atof($1));
        fprintf(fout, "\tldc %s\n", $1);
    	$$ = "float32"; 
    }
    | BOOL_LIT 
    {
        printf("%s\n", $1); 
        if(strcmp(yylval.s_val,"TRUE 1")==0){
            fprintf(fout,"\ticonst_1\n");
        }
        else{
            fprintf(fout, "\ticonst_0\n");
        }
        $$ = "bool"; 
    }
    | '"' STRING_LIT '"' 
    { 
        printf("STRING_LIT %s\n", $2); 
        fprintf(fout, "\tldc \"%s\"\n", $2);
    	$$ = "string"; 
    }
; 

ReturnStmt
    : RETURN Expression 
    {
    	if(strcmp(return_type,"I")==0)
    		printf("ireturn\n");
    	else if(strcmp(return_type,"F")==0)
    		printf("freturn\n");
    }
    | RETURN { printf("return\n"); }
;    

Block
    : '{' { create_symbol(); }
    StatementList
    '}' { dump_symbol(level); }
;

StatementList 
    : StatementList Statement
    | Statement
;

Statement
    : DeclarationStmt NEWLINE
    | FunctionDeclStmt NEWLINE
    | SimpleStmt NEWLINE
    | CallFunc
    | Block
    | IfStmt
    | ForStmt
    | SwitchStmt
    | CaseStmt
    | PrintStmt NEWLINE
    | ReturnStmt NEWLINE
    | NEWLINE
;  

SimpleStmt
    : AssignmentStmt 
    | ExpressionStmt 
    | IncDecStmt
;

ExpressionStmt
    : Expression
;

Expression
    : LandExpr { $$ = $1; }
    | Expression LOR LandExpr 
    {
	    if(strcmp($1, "int32")==0 || strcmp($3, "int32")==0){
		    yyerror("invalid operation: (operator LOR not defined on int32)");
            g_has_error = true;
	    }
	    if(strcmp($1, "float32")==0 || strcmp($3, "float32")==0){
		    yyerror("invalid operation: (operator LOR not defined on float32)");
            g_has_error = true;
        }
	    printf("LOR\n"); 
        fprintf(fout, "\tior\n");
        $$ = "bool"; 
    }
;    

LandExpr 
    : CmpExpr { $$ = $1; }
    | LandExpr LAND CmpExpr 
    {
	    if(strcmp($1, "int32")==0 || strcmp($3, "int32")==0){
		    yyerror("invalid operation: (operator LAND not defined on int32)");
            g_has_error = true;
        }
	    if(strcmp($1, "float32")==0 || strcmp($3, "float32")==0){
		    yyerror("invalid operation: (operator LAND not defined on float32)");
            g_has_error = true;
        }
	    printf("LAND\n"); 
        fprintf(fout, "\tiand\n");
        $$ = "bool"; 
    }
;

CmpExpr
    : AddExpr { $$ = $1; }
    | CmpExpr Cmp_op AddExpr 
    {
        if(strcmp(check_type($1), check_type($3))!=0){
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, "ERROR", $3);
            g_has_error = true;
        }
        $$ = "bool";
        printf("%s\n", $2); 
        if(strcmp($1, "int32")==0){
            fprintf(fout, "\tisub\n");
        }
        else if(strcmp($1, "float32")==0){
            fprintf(fout, "\tfcmpl\n");
        }
            
        if(strcmp($2, "EQL")==0){
            cmp_count++;
            fprintf(fout, "\tifeq L_cmp_%d\n", cmp_count);
        }
        else if(strcmp($2, "NEQ")==0){
            cmp_count++;
            fprintf(fout, "\tifne L_cmp_%d\n", cmp_count);                
        }
        else if(strcmp($2, "LSS")==0){
            cmp_count++;
            fprintf(fout, "\tiflt L_cmp_%d\n", cmp_count);                
        }
        else if(strcmp($2, "LEQ")==0){
            cmp_count++;
            fprintf(fout, "\tifle L_cmp_%d\n", cmp_count);                
        }
        else if(strcmp($2, "GTR")==0){
            cmp_count++;
            fprintf(fout, "\tifgt L_cmp_%d\n", cmp_count);
        }
        else if(strcmp($2, "GEQ")==0){
            cmp_count++;
            fprintf(fout, "\tifge L_cmp_%d\n", cmp_count);
        }

        fprintf(fout, "\ticonst_0\n");
        cmp_count++;
        fprintf(fout, "\tgoto L_cmp_%d\n", cmp_count);

        fprintf(fout, "L_cmp_%d:\n", cmp_count-1);
        fprintf(fout, "\ticonst_1\n");
        fprintf(fout, "L_cmp_%d:\n", cmp_count);
    }
;    

Cmp_op
    : EQL { $$ = "EQL"; }
    | NEQ { $$ = "NEQ"; } 
    | '<' { $$ = "LSS"; }
    | LEQ { $$ = "LEQ"; }
    | '>' { $$ = "GTR"; }
    | GEQ { $$ = "GEQ"; }
;    

AddExpr
    : MulExpr { $$ = $1; }
    | AddExpr Add_op MulExpr
    {
        if(strcmp($1, $3)!=0){
    	    printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, operation, $1, $3);
            g_has_error = true;
        }
        printf("%s\n", $2);
        if(strcmp($2, "ADD")==0){
            if(strcmp($1, "int32")==0){
                fprintf(fout, "\tiadd\n");
                $$ = "int32";
            }
            else if(strcmp($1, "float32")==0){
                fprintf(fout, "\tfadd\n");
                $$ = "float32";
            }
        }
        else{ //SUB
            if(strcmp($1, "int32")==0){
                fprintf(fout, "\tisub\n");
                $$ = "int32";
            }
            else if(strcmp($1, "float32")==0){
                fprintf(fout, "\tfsub\n");
                $$ = "float32";
            }  
        }
    }
;    

Add_op
    : '+' { $$ = "ADD"; strcpy(operation, "ADD"); }
    | '-' { $$ = "SUB"; strcpy(operation, "SUB"); }
;    

MulExpr
    : UnaryExpr 
    { 
        $$ = $1;
        printf("MulExpr type: %s, Lvar: %s, Lvar_addr: %d\n", $1, Lvar_name, Lvar_addr); //debug
    }
    | MulExpr Mul_op UnaryExpr {
        printf("%s\n", $2);
        if(strcmp($2, "MUL")==0){
            if(strcmp($1, "int32")==0){
                fprintf(fout, "\timul\n");
                $$ = "int32";
            }
            else if(strcmp($1, "float32")==0){
                fprintf(fout, "\tfmul\n");
                $$ = "float32";
            }
        }
        else if(strcmp($2, "QUO")==0){
            if(strcmp($1, "int32")==0){
                fprintf(fout, "\tidiv\n");
                $$ = "int32";
            }
            else if(strcmp($1, "float32")==0){
                fprintf(fout, "\tfdiv\n");
                $$ = "float32";
            }
        }
        else if(strcmp($2, "REM")==0){
            if(strcmp($1, "float32")==0 || strcmp($3, "float32")==0){
                yyerror("invalid operation: (operator REM not defined on float32)");
                g_has_error = true;
            }
           else{
               fprintf(fout, "\tirem\n");
               $$ = "int32";
           }
        }
    }
;      

Mul_op
    : '*' { $$ = "MUL"; strcpy(operation, "MUL"); }
    | '/' { $$ = "QUO"; strcpy(operation, "QUO"); }
    | '%' { $$ = "REM"; strcpy(operation, "REM"); }
;    

UnaryExpr
    : PrimaryExpr { $$ = $1; }
    | Unary_op UnaryExpr 
    {
        printf("%s\n", $1);
        if(strcmp(check_type($2), "null")!=0){
            if(strcmp($1, "POS")==0){
                if(strcmp($2, "int32")==0){
                    $$ = "int32";
                }
                else if(strcmp($2, "float32")==0){
                    $$ = "float32";
                }
            }
            if(strcmp($1, "NEG")==0){
                if(strcmp($2, "int32")==0){
                    fprintf(fout, "\tineg\n");
                    $$ = "int32";
                }
                else if(strcmp($2, "float32")==0){
                    fprintf(fout, "\tfneg\n");
                    $$ = "float32";
                }
            }
            else if(strcmp($1, "NOT")==0){ //!
                fprintf(fout, "\ticonst_1\n"); //load true for "not" operator
                fprintf(fout, "\tixor\n");
                $$ = "bool";
            }
        }
    }
;    

Unary_op
    : '+' { $$ = "POS"; }
    | '-' { $$ = "NEG"; }
    | '!' { $$ = "NOT"; }
;    

PrimaryExpr
    : Operand { $$ = $1; }
    | ConversionExpr { $$ = $1; }
    | IndexExpr
;    

Operand
    : Lvalue { $$ = $1; }
    | '(' Expression ')' { $$ = $2; }
;       

IndexExpr 
    : PrimaryExpr '[' Expression ']' { $$ = "null"; }
;

ConversionExpr
    : Type '(' Expression ')' 
    {
        if(strcmp(check_type($3), "null")!=0){
            printf("%c2%c\n", $3[0], $1[0]);
            if(strcmp($3, "int32")==0 && strcmp($1, "float32")==0){
                fprintf(fout, "\ti2f\n");
                $$ = "float32";
            }
            else if(strcmp($3, "float32")==0 && strcmp($1, "int32")==0){
                fprintf(fout, "\tf2i\n");
                $$ = "int32";
            }
    	}
        else{ //variable
            Symbol t = lookup_symbol($3, 1);
            if(strcmp(t.name, "NotDefineYet")!=0){
                printf("%c2%c\n", t.type[0], $1[0]);
                if(strcmp($3, "int32")==0 && strcmp($1, "float32")==0){
                    fprintf(fout, "\ti2f\n");
                    $$ = "float32";
                }   
                else if(strcmp($3, "float32")==0 && strcmp($1, "int32")==0){
                    fprintf(fout, "\tf2i\n");
                    $$ = "int32";
                }
            }
    	}
    }
;    

IncDecStmt
    : Expression INC { 
        printf("INC\n");
        if(strcmp($1, "int32")==0){
            fprintf(fout, "\ticonst_1\n");
            fprintf(fout, "\tiadd\n");
            fprintf(fout, "\tistore %d\n", Lvar_addr);
            $$ = "int32";
        }
        else if(strcmp($1, "float32")==0){
            fprintf(fout, "\tldc 1.0\n");
            fprintf(fout, "\tfadd\n");
            fprintf(fout, "\tfstore %d\n", Lvar_addr);
            $$ = "float32";
        }
        else{
            g_has_error = true;
        }
    }
    | Expression DEC { 
        printf("DEC\n");
        if(strcmp($1, "int32")==0){
            fprintf(fout, "\ticonst_1\n");
            fprintf(fout, "\tisub\n");
            fprintf(fout, "\tistore %d\n", Lvar_addr);
            $$ = "int32";
        }
        else if(strcmp($1, "float32")==0){
            fprintf(fout, "\tldc 1.0\n");
            fprintf(fout, "\tfsub\n");
            fprintf(fout, "\tfstore %d\n", Lvar_addr);    
            $$ = "float32";        
        }
        else{
            g_has_error = true;
        }
    }
;    

DeclarationStmt
    : VAR IDENT Type '=' Expression 
    {
        insert_symbol($2, $3, "-", 0); 
        Symbol t = lookup_symbol($2, 1);
        if(strcmp($3, "int32")==0){
            fprintf(fout, "\tistore %d\n", t.addr);
        }
        else if(strcmp($3, "float32")==0){
            fprintf(fout, "\tfstore %d\n", t.addr);
        }
        else if(strcmp($3, "string")==0){
            fprintf(fout, "\tastore %d\n", t.addr);
        }
        else if(strcmp($3, "bool")==0){
            fprintf(fout, "\tistore %d\n", t.addr);
        }
    }
    | VAR IDENT Type {
      	insert_symbol($2, $3, "-", 0);
        Symbol t = lookup_symbol($2, 1);
        if(strcmp($3, "int32")==0){
            fprintf(fout, "\ticonst_0\n");
            fprintf(fout, "\tistore %d\n", t.addr);
        }
        else if(strcmp($3, "float32")==0){
            fprintf(fout, "\tldc 0.0\n");
            fprintf(fout, "\tfstore %d\n", t.addr);
        }
        else if(strcmp($3, "string")==0){
            fprintf(fout, "\tldc \"\"\n");
            fprintf(fout, "\tastore %d\n", t.addr);
        }
        else if(strcmp($3, "bool")==0){
            fprintf(fout, "\ticonst_0\n");
            fprintf(fout, "\tistore %d\n", t.addr);
        }
    }
    | VAR IDENT Type '=' CallFunc {
        insert_symbol($2, $3, "-", 1);
        Symbol t = lookup_symbol($2, 1);
        if(strcmp($3, "int32")==0){
            fprintf(fout, "\tistore %d\n", t.addr);
        }
        else if(strcmp($3, "float32")==0){
            fprintf(fout, "\tfstore %d\n", t.addr);
        }
        else if(strcmp($3, "string")==0){
            fprintf(fout, "\tastore %d\n", t.addr);
        }
        else if(strcmp($3, "bool")==0){
            fprintf(fout, "\tistore %d\n", t.addr);
        }
    }
;

AssignmentStmt
    : Lvalue Assign_op Expression { 
    	if(strcmp(check_type($1), "null")==0){
        	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, "ERROR", $3);
            g_has_error = true;
        }
    	else if(strcmp($1, $3)!=0){
        	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, Lvar_type, $3);
    	    g_has_error = true;
        }	
        else{
            if(strcmp($2, "ADD")==0){
                if(strcmp($1, "int32")==0){
                    fprintf(fout, "\tiload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tiadd\n");
                }
                else if(strcmp($1, "float32")==0){
                    fprintf(fout, "\tfload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tfadd\n");
                }
            }
            else if(strcmp($2, "SUB")==0){
                if(strcmp($1, "int32")==0){
                    fprintf(fout, "\tiload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tisub\n");
                }
                else if(strcmp($1, "float32")==0){
                    fprintf(fout, "\tfload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tfsub\n");
                }
            }
            else if(strcmp($2, "MUL")==0){
                if(strcmp($1, "int32")==0){
                    fprintf(fout, "\tiload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\timul\n");
                }
                else if(strcmp($1, "float32")==0){
                    fprintf(fout, "\tfload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tfmul\n");
                }                
            }
            else if(strcmp($2, "QUO")==0){
                if(strcmp($1, "int32")==0){
                    fprintf(fout, "\tiload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tidiv\n");
                }
                else if(strcmp($1, "float32")==0){
                    fprintf(fout, "\tfload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tfdiv\n");
                }                
            }
            else if(strcmp($2, "REM")==0){
                if(strcmp($1, "int32")==0){
                    fprintf(fout, "\tiload %d\n", Lvar_addr);
                    fprintf(fout, "\tswap\n");
                    fprintf(fout, "\tirem\n");
                }             
            }
        }

        if(strcmp($1, "int32")==0){
            fprintf(fout, "\tistore %d\n", Lvar_addr);
        }
        else if(strcmp($1, "float32")==0){
            fprintf(fout, "\tfstore %d\n", Lvar_addr);
        }
        else if(strcmp($1, "string")==0){
            fprintf(fout, "\tastore %d\n", Lvar_addr);
        }
        else if(strcmp($1, "bool")==0){
            fprintf(fout, "\tistore %d\n", Lvar_addr);
        }
    	printf("%s\n", $2);
        is_left = 1;
        Lvar_addr = -1;
        strcpy(Lvar_name, "null");
    }
;

Assign_op
    : '=' { $$ = "ASSIGN"; is_left = 0; }
    | ADD_ASSIGN { $$="ADD"; is_left = 0; }
    | SUB_ASSIGN { $$="SUB"; is_left = 0; }
    | MUL_ASSIGN { $$="MUL"; is_left = 0; }
    | QUO_ASSIGN { $$="QUO"; is_left = 0; }
    | REM_ASSIGN { $$="REM"; is_left = 0; }
;    

Condition
    : Expression 
    { 
        if(strcmp(check_type($1), "null")!=0){
            if(strcmp($1, "int32")==0 || strcmp($1, "float32")==0){
                printf("error:%d: non-bool (type %s) used as for condition\n", yylineno+1, $1);
                g_has_error = true;
            }
        }
        else{
            g_has_error = true;
        }
    }
;

IfStmt
    : IF Condition 
    {
        if_count++;
        fprintf(fout, "\tifeq L_if_exit_%d\n", if_count);
    }
    Block
    { fprintf(fout, "L_if_exit_%d:\n", if_count); }
    //| IF Condition Block ELSE IfStmt
    //| IF Condition Block ELSE Block
;    

ForStmt
    : FOR 
    {
        for_count++;
        fprintf(fout, "L_for_begin_%d:\n", for_count);
    }
    Condition{ fprintf(fout, "\tifeq L_for_exit_%d\n", for_count); }
    Block
    {
        fprintf(fout, "\tgoto L_for_begin_%d\n", for_count);
        fprintf(fout, "L_for_exit_%d:\n", for_count);
    }
    /* | FOR SimpleStmt ';' Condition ';' SimpleStmt Block */
;    

SwitchStmt
    : SWITCH Expression
    {
        switch_count++;
        fprintf(fout, "\tgoto L_switch%d_begin\n", switch_count);
    }
    Block
    {
        fprintf(fout, "L_switch%d_begin:\n", switch_count);
        fprintf(fout, "lookupswitch\n");
        for(int i=0; i<number_of_case; i++){
            fprintf(fout, "\t%d: L_case%d_%d\n", case_key[i], switch_count, case_key[i]);
        }
        if(has_default==1){
            fprintf(fout, "\tdefault: L_default%d\n", switch_count);
        }
        fprintf(fout, "L_switch%d_end:\n", switch_count);
        number_of_case = 0;
        has_default = 0;
    }
;

CaseStmt 
    : CASE INT_LIT ':' 
    { 
        printf("case %s\n", $<s_val>2); 
        number_of_case++;
        case_key[number_of_case-1] = atoi($2);
        fprintf(fout, "L_case%d_%d:\n", switch_count, case_key[number_of_case-1]);
    } 
    Block{ fprintf(fout, "\tgoto L_switch%d_end\n", switch_count); }  
    | DEFAULT { fprintf(fout, "L_default%d:\n", switch_count); }
    ':' Block 
    { 
        fprintf(fout, "\tgoto L_switch%d_end\n", switch_count);
        $$ = "DEFAULT";
        has_default = 1;
    }       
;

Type
    : INT { $$ = "int32"; }
    | FLOAT { $$ = "float32"; }
    | STRING { $$ = "string"; }
    | BOOL { $$ = "bool"; }
;

PrintStmt
    : PRINT '(' Expression ')'
    {
    	if(strcmp(check_type($3), "null")!=0){
    		printf("PRINT %s\n", $3);
            if(strcmp($3, "int32")==0){
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(I)V\n");
            }
            else if(strcmp($3, "float32")==0){
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(F)V\n");
            }
            else if(strcmp($3, "bool")==0){
                cmp_count++;
                fprintf(fout, "\tifne L_cmp_%d\n", cmp_count);
                fprintf(fout, "\tldc \"false\"\n");
                cmp_count++;
                fprintf(fout, "\tgoto L_cmp_%d\n", cmp_count);
                fprintf(fout, "L_cmp_%d:\n", cmp_count-1);
                fprintf(fout, "\tldc \"true\"\n");
                fprintf(fout, "L_cmp_%d:\n", cmp_count);
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
            }
            else if(strcmp($3, "string")==0){
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
            }
    	}
    	else{
            printf("type wrong\n");
            printf("PRINT %s\n", $3);
    	}
    }
    | PRINTLN '(' Expression ')' 
    {
    	if(strcmp(check_type($3), "null")!=0){
    		printf("PRINTLN %s\n", $3);

            if(strcmp($3, "int32")==0){
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/println(I)V\n");
            }
            else if(strcmp($3, "float32")==0){
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/println(F)V\n");
            }
            else if(strcmp($3, "bool")==0){
                cmp_count++;
                fprintf(fout, "\tifne L_cmp_%d\n", cmp_count);
                fprintf(fout, "\tldc \"false\"\n");
                cmp_count++;
                fprintf(fout, "\tgoto L_cmp_%d\n", cmp_count);
                fprintf(fout, "L_cmp_%d:\n", cmp_count-1);
                fprintf(fout, "\tldc \"true\"\n");
                fprintf(fout, "L_cmp_%d:\n", cmp_count);
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
            }
            else if(strcmp($3, "string")==0){
                fprintf(fout, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                fprintf(fout, "\tswap\n");
                fprintf(fout, "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
            }
    	}
    	else{
            printf("type wrong\n");
            printf("PRINTLN %s\n", $3);
    	}     
    }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");

    fprintf(fout, ".source hw3.j\n");
    fprintf(fout, ".class public Main\n");
    fprintf(fout, ".super java/lang/Object\n\n");

    /* Symbol table init */

    yylineno = 0;
    yyparse();

    /* Symbol table dump */
    dump_symbol(level);

	printf("Total lines: %d\n", yylineno);

    fclose(fout);
    fclose(yyin);

    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
    return 0;
}

static void create_symbol() {
    level++;
    printf("> Create symbol table (scope level %d)\n", level);
}

static void insert_symbol(char* name, char* type, char* func_sig, int is_param_function) {
    Symbol t = lookup_symbol(name, 0);
    
    if(strcmp(t.name, "NotDefineYet")!=0){ //redeclared error, but still need to insert
        printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, name, t.lineno);
    }

    /*insert part*/
    if(strcmp(type, "func")==0){ //whether its type is function
    	level--;
    	symbol_table[level][table_size[level]].addr = -1;
    	symbol_table[level][table_size[level]].lineno = yylineno+1;
    }
    else if(is_param_function==0){ //whether its a parameter or the value is from calling function
    	symbol_table[level][table_size[level]].addr = address;
    	symbol_table[level][table_size[level]].lineno = yylineno;
    	address++;
    }
    else{
        symbol_table[level][table_size[level]].addr = address;
    	symbol_table[level][table_size[level]].lineno = yylineno+1;
    	address++;
    }
    strcpy(symbol_table[level][table_size[level]].name, name);
    strcpy(symbol_table[level][table_size[level]].type, type);
    strcpy(symbol_table[level][table_size[level]].func_sig, func_sig);
    
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, symbol_table[level][table_size[level]].addr, level);
    table_size[level]++;
}

static Symbol lookup_symbol(char* name, int tables){
    //function，從level 0找
    if(is_func){
    	for(int i=0; i<table_size[0]; i++){
            if(strcmp(symbol_table[0][i].name, name)==0)
                return symbol_table[0][i];
	    }
        Symbol node;
        strcpy(node.name, "NotDefineYet");

        return node;
    }
    /*non function*/
    else{
        if(tables!=0){ //all symbol_table
            for(int i=level; i>=0; i--){
                for(int j=0; j<table_size[i]; j++){
                    if(strcmp(symbol_table[i][j].name, name)==0)
                        return symbol_table[i][j];
                }
            }

            Symbol node;
            strcpy(node.name, "NotDefineYet");
            return node;
        }
    	else{ //current symbol_table
            for(int i=0; i<table_size[level]; i++){
                if(strcmp(symbol_table[level][i].name, name)==0)
                    return symbol_table[level][i];
	        }

            Symbol node;
            strcpy(node.name, "NotDefineYet");
            return node;
    	}
    }
}

static void dump_symbol(int scope_level){
    printf("\n> Dump symbol table (scope level: %d)\n", scope_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
    for(int i=0; i < table_size[scope_level]; i++){
        printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",
            i, symbol_table[scope_level][i].name, symbol_table[scope_level][i].type, symbol_table[scope_level][i].addr, symbol_table[scope_level][i].lineno, symbol_table[scope_level][i].func_sig);
    }
    table_size[level] = 0;
    printf("\n");      
    level--;
}

static char* check_type(char* name){
        char* type[4] = {"int32",
                     "float32",
                     "bool",
                     "string"};
    for(int i = 0; i < 4; i++){
        if(strcmp(name, type[i])==0){
            return type[i];
        } 
    }
    return "null";
}