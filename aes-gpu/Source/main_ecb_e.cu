#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <sys/time.h>

#include "AES.h"
#include "main.h"

using namespace std;

long long aes_ecb_test(uint ptSize) {
	byte *key;
	uint *ct, *pt;
	uint keySize = 32;

	if(ptSize % 4 != 0) {
		printf("Plaintext size must be a multiple of AES block size.\n");
		exit(1);
	}

	key = (byte *)malloc(keySize * sizeof(byte));
	assert(key != NULL);
	for(uint i=0; i<keySize; i++)
		key[i] = rand();
		
	pt = (uint *)malloc(ptSize*sizeof(uint));
	assert(pt != NULL);
	for(uint i=0; i<ptSize; i++)
		pt[i] = rand();
	
	ct = (uint *)malloc(ptSize*sizeof(uint));
	assert(ct != NULL);

	AES *aes = new AES();

	struct timeval start, end;
	gettimeofday(&start, NULL);
	
	aes->makeKey(key, keySize << 3, DIR_ENCRYPT);
	aes->encrypt(pt, ct, ptSize >> 2);
	
	gettimeofday(&end, NULL);
	long long t = (long long)(end.tv_sec-start.tv_sec)*1000000+(end.tv_usec-start.tv_usec);

	free(key);
	free(pt);
	free(ct);
	return t;
}

const int num_tests = 10;

void run_tests(uint ptSize)
{
    printf("AES ECB test, %d: ", ptSize);
    long long sum = 0;
    for(int i=0; i<num_tests; i++)
    {
		long long t = aes_ecb_test(ptSize / sizeof(uint));
		sum += t;
		printf("%lld, ", t);
    }
    printf(" Average %lld\n", sum/num_tests);
}

int main(int argc, char **argv) {
	run_tests(1048576);
	run_tests(10485760);
	run_tests(104857600);
	run_tests(1048576000);
	return 0;
}
