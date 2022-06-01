#ifndef COMPILER_HW_COMMON_H
#define COMPILER_HW_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

/*Symbol table*/
typedef struct Symbol {
    int index;
    char name[15];
    char type[10];
    int addr;
    int lineno;
    char func_sig[10];
} Symbol;

#endif /* COMPILER_HW_COMMON_H */