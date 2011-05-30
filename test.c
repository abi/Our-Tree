#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "rc4.h"
#include "util.h"

int main(int argc, char* argv[]){
	struct rc4_state *state = malloc (sizeof (struct rc4_state));
	char *buffer = malloc(1000 * sizeof(char));
	strcpy(buffer, "Plaintext");
	printf ("Your plaintext is %s\n", buffer);
	char *key = malloc(1000 * sizeof(char));
	strcpy(key, "Key");
	rc4_init(state, "Key", 3);
	printh (state->perm);
	rc4_crypt(state, buffer, buffer, 9); 
	printf ("Your ciphertext is ");
	printh (buffer);
	return 0;
}
