#include <wmmintrin.h>

#if !defined (ALIGN16) 
# if defined (__GNUC__) 
#  define ALIGN16 __attribute__ ( (aligned (16))) 
# else 
#  define ALIGN16 __declspec (align (16)) 
# endif 
#endif

int CheckAESSupport();
void AES_256_Key_Expansion (const unsigned char *userkey, unsigned char *key);

void AES_ECB_encrypt(const unsigned char *in, //pointer to the PLAINTEXT 
				     unsigned char *out,	//pointer to the CIPHERTEXT buffer
                     unsigned long length,	//text length in bytes 
                     const unsigned char *key,	//pointer to the expanded key schedule 
                     int number_of_rounds);	//number of AES rounds 10,12 or 14
                     
void AES_ECB_decrypt(const unsigned char *in, //pointer to the CIPHERTEXT 
				     unsigned char *out,	//pointer to the DECRYPTED TEXT buffer
				     unsigned long length,	//text length in bytes 
				     const char *key,	//pointer to the expanded key schedule 
				     int number_of_rounds);	//number of AES rounds 10,12 or 14
				     
void AES_CTR_encrypt (const unsigned char *in,
					  unsigned char *out,
					  const unsigned char ivec[8],
					  const unsigned char nonce[4],
					  unsigned long length,
					  const unsigned char *key,
					  int number_of_rounds);

