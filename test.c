#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/time.h>

#include "arc4.h"
#include "util.h"

#define ITERATIONS 10
#define KEY_LENGTH_BYTES 16 
#define KEY_LENGTH_BITS (KEY_LENGTH_BYTES * 8)

unsigned char *msg;
unsigned char *out;
unsigned char *ks;
unsigned char key[KEY_LENGTH_BYTES];

arc4_context rc4_ctx;

typedef struct RC4Info {
	int thread_id;
	int total_threads;
} RC4Info;
size_t MESSAGE_LENGTH = 0;

//Utils

//Print time difference between `start` and `end` in microseconds
void print_time_diff(struct timeval start, struct timeval end){

	long long seconds  = end.tv_sec  - start.tv_sec;
	long long useconds = end.tv_usec - start.tv_usec;	
	
	seconds = 1000000 * seconds + useconds;
	
	printf("%lld, ", seconds);

}


//A worker function that merely does the XOR for RC4
void* rc4_test_thread(void *a){

	RC4Info* info = (RC4Info *)a;

	//Calculate what work this specific thread ought to do
	//int offset = 0;
	int encrypt_length = MESSAGE_LENGTH / info->total_threads;
	unsigned char* currpos = msg + encrypt_length * info->thread_id;
	unsigned char* cur_ks_pos = ks + encrypt_length * info->thread_id;
	unsigned char* output = out + encrypt_length * info->thread_id;
	
	arc4_crypt( encrypt_length, currpos, cur_ks_pos, output); 	

	return NULL;
}

void rc4_test(int msg_length, int num_thread) {
	printf("RC4, %d, %d, ", msg_length, num_thread);

	MESSAGE_LENGTH = msg_length;

	msg = malloc(MESSAGE_LENGTH);
	out = malloc(MESSAGE_LENGTH);
	ks = NULL;
	
	for(int i = 0; i < MESSAGE_LENGTH; i++) {
		msg[i] = rand() % 255;
	}

	for(int iter = 0; iter < ITERATIONS; iter++) {
		
		struct timeval start, end;
		//Generate a new keystream only once per message (because that's not the parallel
		//part)
		if (ks == NULL)	{
			ks = malloc(MESSAGE_LENGTH);
			for(int i = 0; i < KEY_LENGTH_BYTES; i++) {
				key[i] = rand() % 255;
			}	

			printf ("\nGenerated a new key in ");
			//Generate the keystream
			gettimeofday(&start, NULL);
			arc4_setup( &rc4_ctx, key, KEY_LENGTH_BYTES);
			arc4_prep( &rc4_ctx, MESSAGE_LENGTH, ks);
			gettimeofday(&end, NULL);
			print_time_diff(start, end);	
			printf ("\n");
		}

		pthread_t threads[num_thread];
		pthread_attr_t pthread_custom_attr;
		RC4Info infos[num_thread];
		
		pthread_attr_init(&pthread_custom_attr);
	
	
		gettimeofday(&start, NULL);
		
		for(int tid = 0; tid < num_thread; tid++) {
			infos[tid].thread_id = tid;
			infos[tid].total_threads = num_thread;
			pthread_create(&threads[tid], &pthread_custom_attr, rc4_test_thread, &infos[tid]);
		}
		
		
		for(int tid = 0; tid < num_thread; tid++) {
			pthread_join(threads[tid], NULL);
		}
		
		gettimeofday(&end, NULL);
		
		print_time_diff(start, end);	
	}
	
	MESSAGE_LENGTH = 0;

	/* Be a nice person */
	free(msg);
	free(out);
	
	printf("\n");
}


int main(int argc, char* argv[]){

	srand(1337);
	//setbuf(stdout, NULL);
	
	
	rc4_test(1048576, 1);
	rc4_test(1048576, 2);
	rc4_test(1048576, 4);
	rc4_test(1048576, 8);

	rc4_test(10485760, 1);
	rc4_test(10485760, 2);
	rc4_test(10485760, 4);
	rc4_test(10485760, 8);
	
	rc4_test(104857600, 1);
	rc4_test(104857600, 2);
	rc4_test(104857600, 4);
	rc4_test(104857600, 8);
	
	rc4_test(1048576000, 1);
	rc4_test(1048576000, 2);
	rc4_test(1048576000, 4);
	rc4_test(1048576000, 8);	
	
	//arc4_self_test( 1 );
	arc4_self_test( 2 );
	return 0;
	/*
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
	*/
}
