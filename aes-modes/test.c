#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/time.h>
#include "aes.h"
#include "aesni.h"

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

		struct timeval start, end;
	
		gettimeofday(&start, NULL);
		
		for(int tid = 0; tid < num_thread; tid++) {
			infos[tid].thread_id = tid;
			infos[tid].total_threads = num_thread;
			
			pthread_create(&threads[tid], &pthread_custom_attr, ecb_test_thread, &infos[tid]);
		}
		
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		gettimeofday(&end, NULL);
		
		long long seconds  = end.tv_sec  - start.tv_sec;
   		long long useconds = end.tv_usec - start.tv_usec;	
   		
   		seconds = 1000000 * seconds + useconds;
   		
   		printf("%lld, ", seconds);
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
	//unsigned char* currpos = msg + encrypt_length * info->thread_id;
	//unsigned char* output = out + encrypt_length * info->thread_id;
	
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
	
		struct timeval start, end;
	
		gettimeofday(&start, NULL);
		
		for(int tid = 0; tid < num_thread; tid++) {
			infos[tid].thread_id = tid;
			infos[tid].total_threads = num_thread;
			
			pthread_create(&threads[tid], &pthread_custom_attr, ecb_test_thread, &infos[tid]);
		}
		
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		gettimeofday(&end, NULL);
		
		long long seconds  = end.tv_sec  - start.tv_sec;
   		long long useconds = end.tv_usec - start.tv_usec;	
   		
   		seconds = 1000000 * seconds + useconds;
   		
   		printf("%lld, ", seconds);
	
	}
	
	MESSAGE_LENGTH = 0;
	
	free(msg);
	free(out);
	
	printf("\n");
}


/* ------------------ AESNI BASED ELECTRONIC CODE-BOOK ------------------ */
ALIGN16 unsigned char AESNI_KEY[16*15];


void* aes_ecb_test_thread(void* a) {

	AESInfo* info = (AESInfo *)a;
	//unsigned char output[AES_BLOCK_SIZE];
	
	int encrypt_length = MESSAGE_LENGTH / info->total_threads;
	unsigned char* currpos = msg + encrypt_length * info->thread_id;
	unsigned char* output = out + encrypt_length * info->thread_id;
	
	AES_ECB_encrypt(currpos, output, encrypt_length, AESNI_KEY, 14);
	
	return NULL;
}

void aes_ecb_test(int msg_length, int num_thread) {
	printf("AESNI ECB, %d, %d, ", msg_length, num_thread);

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
			
		AES_256_Key_Expansion(key, AESNI_KEY);
	
		pthread_t threads[num_thread];
		pthread_attr_t pthread_custom_attr;
		AESInfo infos[num_thread];
		
		pthread_attr_init(&pthread_custom_attr);

		struct timeval start, end;
	
		gettimeofday(&start, NULL);
		
		for(int tid = 0; tid < num_thread; tid++) {
			infos[tid].thread_id = tid;
			infos[tid].total_threads = num_thread;
			
			pthread_create(&threads[tid], &pthread_custom_attr, aes_ecb_test_thread, &infos[tid]);
		}
		
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		gettimeofday(&end, NULL);
		
		long long seconds  = end.tv_sec  - start.tv_sec;
   		long long useconds = end.tv_usec - start.tv_usec;	
   		
   		seconds = 1000000 * seconds + useconds;
   		
   		printf("%lld, ", seconds);
	}
	
	MESSAGE_LENGTH = 0;
	
	free(msg);
	free(out);
	
	printf("\n");
}


/* ------------------ AESNI BASED COUNTER MODE ------------------ */
	unsigned char ivec[8];
	unsigned char nonce[4];

void* aes_ctr_test_thread(void* a) {

	AESInfo* info = (AESInfo *)a;
	//unsigned char output[AES_BLOCK_SIZE];
	
	int encrypt_length = MESSAGE_LENGTH / info->total_threads;
	unsigned char* currpos = msg + encrypt_length * info->thread_id;
	unsigned char* output = out + encrypt_length * info->thread_id;
	
	AES_CTR_encrypt(currpos, output, ivec, nonce, encrypt_length, AESNI_KEY, 14);
	
	return NULL;
}

void aes_ctr_test(int msg_length, int num_thread) {
	printf("AESNI CTR, %d, %d, ", msg_length, num_thread);

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
		
		ivec[0] = 'H'; ivec[1] = 'l'; ivec[2] = 'o'; ivec[3] = 'E';
		ivec[4] = 'e'; ivec[5] = 'l'; ivec[6] = 'A'; ivec[7] = 'S';
		
		nonce[0] = '3'; nonce[1] = '1'; nonce[2] = '5'; nonce[3] = 'A';
			
		AES_256_Key_Expansion(key, AESNI_KEY);
	
		pthread_t threads[num_thread];
		pthread_attr_t pthread_custom_attr;
		AESInfo infos[num_thread];
		
		pthread_attr_init(&pthread_custom_attr);

		struct timeval start, end;
	
		gettimeofday(&start, NULL);
		
		for(int tid = 0; tid < num_thread; tid++) {
			infos[tid].thread_id = tid;
			infos[tid].total_threads = num_thread;
			
			pthread_create(&threads[tid], &pthread_custom_attr, aes_ctr_test_thread, &infos[tid]);
		}
		
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		gettimeofday(&end, NULL);
		
		long long seconds  = end.tv_sec  - start.tv_sec;
   		long long useconds = end.tv_usec - start.tv_usec;	
   		
   		seconds = 1000000 * seconds + useconds;
   		
   		printf("%lld, ", seconds);
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
	*/
	
	if(CheckAESSupport()) {
		printf("## CPU Supports AES-NI instructions. Continuing...\n");
		/*aes_ecb_test(1048576, 1);
		aes_ecb_test(1048576, 2);
		aes_ecb_test(1048576, 4);
		aes_ecb_test(1048576, 8);
	
		aes_ecb_test(10485760, 1);
		aes_ecb_test(10485760, 2);
		aes_ecb_test(10485760, 4);
		aes_ecb_test(10485760, 8);
		
		aes_ecb_test(104857600, 1);
		aes_ecb_test(104857600, 2);
		aes_ecb_test(104857600, 4);
		aes_ecb_test(104857600, 8);
		
		aes_ecb_test(1048576000, 1);
		aes_ecb_test(1048576000, 2);
		aes_ecb_test(1048576000, 4);
		aes_ecb_test(1048576000, 8);	*/
		
		aes_ctr_test(1048576, 1);
		aes_ctr_test(1048576, 2);
		aes_ctr_test(1048576, 4);
		aes_ctr_test(1048576, 8);
	
		aes_ctr_test(10485760, 1);
		aes_ctr_test(10485760, 2);
		aes_ctr_test(10485760, 4);
		aes_ctr_test(10485760, 8);
		
		aes_ctr_test(104857600, 1);
		aes_ctr_test(104857600, 2);
		aes_ctr_test(104857600, 4);
		aes_ctr_test(104857600, 8);
		
		aes_ctr_test(1048576000, 1);
		aes_ctr_test(1048576000, 2);
		aes_ctr_test(1048576000, 4);
		aes_ctr_test(1048576000, 8);			
	} else {
		printf("## CPU Does Not Support AES-NI instructions. Skipping...\n");
	}
	
	return 0;
}









