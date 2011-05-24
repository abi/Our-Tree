#include <stdio.h>
#include <time.h>
#include "blake.h"

int main(int argc, char** argv) {

	uint8_t digest[64], data[144];
	

	clock_t start_time = clock();
	
	for(int i = 0; i < 10000; i++)
		blake_hash(digest, data, 144);	
	
	clock_t end_time = clock();
	
	printf("Diff %d / %d\n", (int32_t)(end_time - start_time), CLOCKS_PER_SEC);
	
	return 0;
}