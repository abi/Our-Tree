#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "AES.h"
#include "main.h"

using namespace std;

int main(int argc, char **argv) {
	if(argc < 3) {
		printf("USAGE: aes_ecb_d KEY PLAINTEXT [PLAINTEXT...]\n");
		return 1;
	}

	byte *key;
	uint *ct, *pt;
	uint keySize = stringToByteArray(argv[1], &key);
	uint ctSize  = stringToByteArray(argv[2], &ct);

	if(keySize != 16 && keySize != 24 && keySize != 32) {
		printf("Invalid AES key size.\n");
		return 1;
	}

	if(ctSize % 4 != 0) {
		printf("Plaintext size must be a multiple of AES block size.\n");
		return 1;
	}

	pt = (uint *)malloc(ctSize*sizeof(uint));

	AES *aes = new AES();
	aes->makeKey(key, keySize << 3, DIR_DECRYPT);
	aes->decrypt(ct, pt, ctSize >> 2);

	printHexArray(pt, ctSize);

	return 0;
}

uint stringToByteArray(char *str, byte **array) {
	uint i, len  = strlen(str) >> 1;
	*array = (byte *)malloc(len * sizeof(byte));
	
	for(i=0; i<len; i++)
		sscanf(str + i*2, "%02X", *array+i);

	return len;
}

uint stringToByteArray(char *str, uint **array) {
	uint i, len  = strlen(str) >> 3;
	*array = (uint *)malloc(len * sizeof(uint));
	
	for(i=0; i<len; i++)
		sscanf(str + i*8, "%08X", *array+i);

	return len;
}

void printHexArray(uint *array, uint size) {
	uint i;
	for(i=0; i<size; i++)
		printf("%08X", array[i]);
	printf("\n");
}
