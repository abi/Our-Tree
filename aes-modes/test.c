#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <pthread.h>
#include "aes.h"

#define ITERATIONS 10
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

size_t MESSAGE_LENGTH = 0;

/* ------------------ ELECTRONIC CODE-BOOK ------------------ */
void* ecb_test_thread(void* a) {
	AESInfo* info = (AESInfo *)a;
	//unsigned char output[AES_BLOCK_SIZE];
	
	int encrypt_length = MESSAGE_LENGTH / info->total_threads;
	unsigned char* currpos = msg + encrypt_length * info->thread_id;
	unsigned char* output = out + encrypt_length * info->thread_id;
	
	for(int i = 0; i < encrypt_length / AES_BLOCK_SIZE; i++) {
		aes_crypt_ecb(&aes_ctx, AES_ENCRYPT, currpos, output);
		currpos += AES_BLOCK_SIZE;
		output += AES_BLOCK_SIZE;
	}
	
	return NULL;
}

void ecb_test(int msg_length, int num_thread) {
	printf("Plain ECB, %d, %d, ", msg_length, num_thread);

	MESSAGE_LENGTH = msg_length;

	msg = malloc(MESSAGE_LENGTH);
	out = malloc(MESSAGE_LENGTH);
	
	for(int i = 0; i < MESSAGE_LENGTH; i++) {
		msg[i] = rand() % 255;
	}

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
		
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		clock_t time_end = clock();
		
		printf("%.6f, ", (double)((int)time_end - (int)time_start)/(double)(num_thread)/CLOCKS_PER_SEC);
	
	}
	
	MESSAGE_LENGTH = 0;
	
	free(msg);
	free(out);
	
	printf("\n");
}

/* ------------------ COUNTER MODE ------------------ */
void* ctr_test_thread(void* a) {
	AESInfo* info = (AESInfo *)a;
	//unsigned char output[AES_BLOCK_SIZE];
	
	int offset = 0;
	int encrypt_length = MESSAGE_LENGTH / info->total_threads;
	unsigned char* currpos = msg + encrypt_length * info->thread_id;
	unsigned char* output = out + encrypt_length * info->thread_id;
	
	unsigned char nonce[16];
	unsigned char block[16];
	
	//for(int i = 0; i < encrypt_length / AES_BLOCK_SIZE; i++) {
	aes_crypt_ctr(&aes_ctx, encrypt_length, &offset, nonce, block, msg, out);
	//	currpos += AES_BLOCK_SIZE;
	//	output += AES_BLOCK_SIZE;
	//}
	
	return NULL;
}

void ctr_test(int msg_length, int num_thread) {
	printf("Plain CTR, %d, %d, ", msg_length, num_thread);

	MESSAGE_LENGTH = msg_length;

	msg = malloc(MESSAGE_LENGTH);
	out = malloc(MESSAGE_LENGTH);
	
	for(int i = 0; i < MESSAGE_LENGTH; i++) {
		msg[i] = rand() % 255;
	}

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
		
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		clock_t time_end = clock();
		
		printf("%.6f, ", (double)((int)time_end - (int)time_start)/(double)(num_thread)/CLOCKS_PER_SEC);
	
	}
	
	MESSAGE_LENGTH = 0;
	
	free(msg);
	free(out);
	
	printf("\n");
}


int main() {
	srand(1337);
	setbuf(stdout, NULL);
	
	/*
	ecb_test(1048576, 1);
	ecb_test(1048576, 2);
	ecb_test(1048576, 4);
	ecb_test(1048576, 8);

	ecb_test(10485760, 1);
	ecb_test(10485760, 2);
	ecb_test(10485760, 4);
	ecb_test(10485760, 8);
	
	ecb_test(104857600, 1);
	ecb_test(104857600, 2);
	ecb_test(104857600, 4);
	ecb_test(104857600, 8);
	
	ecb_test(1048576000, 1);
	ecb_test(1048576000, 2);
	ecb_test(1048576000, 4);
	ecb_test(1048576000, 8);	
	*/
	
	ctr_test(1048576, 1);
	ctr_test(1048576, 2);
	ctr_test(1048576, 4);
	ctr_test(1048576, 8);

	ctr_test(10485760, 1);
	ctr_test(10485760, 2);
	ctr_test(10485760, 4);
	ctr_test(10485760, 8);
	
	ctr_test(104857600, 1);
	ctr_test(104857600, 2);
	ctr_test(104857600, 4);
	ctr_test(104857600, 8);
	
	ctr_test(1048576000, 1);
	ctr_test(1048576000, 2);
	ctr_test(1048576000, 4);
	ctr_test(1048576000, 8);		
	
	return 0;
}