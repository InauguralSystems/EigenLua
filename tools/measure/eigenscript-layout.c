/* Compile against the pinned EigenScript checkout:
 * cc -Isrc /path/to/eigenscript-layout.c -o layout && ./layout
 * This is a layout probe only; it is not linked into EigenLua. */
#include <stdio.h>
#include "eigenscript.h"

int main(void) {
    printf("Value\t%zu\n", sizeof(Value));
    printf("EigsSlot\t%zu\n", sizeof(EigsSlot));
    printf("EnvHash\t%zu\n", sizeof(EnvHash));
    printf("ObserverSlot\t%zu\n", sizeof(ObserverSlot));
    printf("Value_list_payload\t%zu\n", sizeof(((Value *)0)->data.list));
    printf("Value_dict_payload\t%zu\n", sizeof(((Value *)0)->data.dict));
    return 0;
}
