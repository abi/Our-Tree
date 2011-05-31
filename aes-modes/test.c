#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <pthread.h>
#include "aes.h"

#define ITERATIONS 10
#define MESSAGE_LENGTH (100 * (1 << 20))
#define AES_BLOCK_SIZE 16
#define KEY_LENGTH_BYTES 32
#define KEY_LENGTH_BITS (KEY_LENGTH_BYTES * 8)

aes_context aes_ctx;
unsigned char *msg;
unsigned char *out;
unsigned char key[KEY_LENGTH_BYTES];

typedef struct AESInfo {
	int thread_id;
	int total_threads;
} AESInfo;

void* ecb_test_thread(void* a) {
	AESInfo* info = (AESInfo *)a;
	//unsigned char output[AES_BLOCK_SIZE];
	
	int encrypt_length = MESSAGE_LENGTH / info->total_threads;
	unsigned char* currpos = msg + encrypt_length * info->thread_id;
	unsigned char* output = out + encrypt_length * info->thread_id;
	
	for(int i = 0; i < encrypt_length / AES_BLOCK_SIZE; i++) {
		//for(int i = 0; i < (MESSAGE_LENGTH / AES_BLOCK_SIZE); i++) {
			aes_crypt_ecb(&aes_ctx, AES_ENCRYPT, currpos, output);
			currpos += AES_BLOCK_SIZE;
			output += AES_BLOCK_SIZE;
		//}		
	}
	
	return NULL;
}

void ecb_test(int num_thread) {
	printf("Plain ECB, %d, ", num_thread);

	for(int iter = 0; iter < ITERATIONS; iter++) {
		
		for(int i = 0; i < KEY_LENGTH_BYTES; i++) {
			key[i] = rand() % 255;
		}	
			
		aes_setkey_enc(&aes_ctx, key, KEY_LENGTH_BITS);
	
		pthread_t threads[num_thread];
		pthread_attr_t pthread_custom_attr;
		AESInfo infos[num_thread];
		
		pthread_attr_init(&pthread_custom_attr);
	
		clock_t time_start = clock();
		
		for(int tid = 0; tid < num_thread; tid++) {
			infos[tid].thread_id = tid;
			infos[tid].total_threads = num_thread;
			
			pthread_create(&threads[tid], &pthread_custom_attr, ecb_test_thread, &infos[tid]);
		}
		
		/*
		unsigned char* currpos = msg;
		for(int i = 0; i < (MESSAGE_LENGTH / AES_BLOCK_SIZE); i++) {
			aes_crypt_ecb(&aes_ctx, AES_ENCRYPT, currpos, output);
			currpos += AES_BLOCK_SIZE;
		}
		*/
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		clock_t time_end = clock();
		
		printf("%.6f, ", (double)((int)time_end - (int)time_start)/(double)(num_thread)/CLOCKS_PER_SEC);
	
	}
	
	printf("\n");
}

int main() {
	srand(1337);
	setbuf(stdout, NULL);

	printf("MESSAGE-LENGTH: %d | ITERATIONS %d\n", MESSAGE_LENGTH, ITERATIONS);

	msg = malloc(MESSAGE_LENGTH);
	out = malloc(MESSAGE_LENGTH);
	
	for(int i = 0; i < MESSAGE_LENGTH; i++) {
		msg[i] = rand() % 255;
	}	
	
	ecb_test(1);
	ecb_test(2);
	ecb_test(4);

	
	return 0;
}