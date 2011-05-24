/* blake.h - Implementation of BLAKE-512 */

#include <stdint.h>

void blake_hash(uint8_t *out, const uint8_t *in, uint64_t inlen);