#include <stdio.h>
#include <time.h>
#include "blake_single.h"

int main(int argc, char** argv) {

	printf("Timing Run for Single Threaded Single Core\n");

	uint8_t digest[64], data[16384];
	
	for(int i = 0; i < 16384; i++)
		data[i] = i % 255;

	for(int c = 0; c < 10; c++) {
		clock_t start_time = clock();
	
		for(int i = 0; i < 10000; i++)
			blake_hash(digest, data, 16384);	
	
		clock_t end_time = clock();
	
		printf("%12d microsec\n", (int32_t)(end_time - start_time));
	}
	return 0;
}