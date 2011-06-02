/**
 * AES.cpp
 *
 * The Advanced Encryption Standard (AES, aka AES) block cipher,
 * designed by J. Daemen and V. Rijmen.
 *
 * @author Paulo S. L. M. Barreto, Simon Waloschek, Benedikt Krueger
 *
 * This software is hereby placed in the public domain.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS ''AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include <assert.h>
#include <string.h>
#include <stdlib.h>

#ifdef BENCHMARK
#include <stdio.h>
#include <time.h>
#endif

#include "AES.h"
#include "AES.tab"

#define FULL_UNROLL

#ifdef _MSC_VER
#define SWAP(x) (_lrotl(x, 8) & 0x00ff00ff | _lrotr(x, 8) & 0xff00ff00)
#define GETWORD(p) SWAP(*((uint *)(p)))
#define PUTWORD(ct, st) (*((uint *)(ct)) = SWAP((st)))
#else
#define GETWORD(pt) (((uint)(pt)[0] << 24) ^ ((uint)(pt)[1] << 16) ^ ((uint)(pt)[2] <<  8) ^ ((uint)(pt)[3]))
#define PUTWORD(ct, st) ((ct)[0] = (byte)((st) >> 24), (ct)[1] = (byte)((st) >> 16), (ct)[2] = (byte)((st) >>  8), (ct)[3] = (byte)(st), (st))
#endif

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

AES::AES() {
    cudaMalloc((void**)&ce_sched, sizeof(e_sched));
    cudaMalloc((void**)&cd_sched, sizeof(d_sched));
}

AES::~AES() {
    Nr = 0;
    memset(e_sched, 0, sizeof(e_sched));
    memset(d_sched, 0, sizeof(d_sched));

    cudaFree(ce_sched);
    cudaFree(cd_sched);
}

//////////////////////////////////////////////////////////////////////
// Support methods
//////////////////////////////////////////////////////////////////////

void AES::ExpandKey(const byte *cipherKey, uint keyBits) {
    uint *rek = e_sched;
    uint i = 0;
    uint temp;
    rek[0] = GETWORD(cipherKey     );
    rek[1] = GETWORD(cipherKey +  4);
    rek[2] = GETWORD(cipherKey +  8);
    rek[3] = GETWORD(cipherKey + 12);
    if (keyBits == 128) {
        for (;;) {
            temp  = rek[3];
            rek[4] = rek[0] ^
                (Te4[(temp >> 16) & 0xff] & 0xff000000) ^
                (Te4[(temp >>  8) & 0xff] & 0x00ff0000) ^
                (Te4[(temp      ) & 0xff] & 0x0000ff00) ^
                (Te4[(temp >> 24)       ] & 0x000000ff) ^
                rcon[i];
            rek[5] = rek[1] ^ rek[4];
            rek[6] = rek[2] ^ rek[5];
            rek[7] = rek[3] ^ rek[6];
            if (++i == 10) {
                Nr = 10;
                return;
            }
            rek += 4;
        }
    }
    rek[4] = GETWORD(cipherKey + 16);
    rek[5] = GETWORD(cipherKey + 20);
    if (keyBits == 192) {
        for (;;) {
            temp = rek[ 5];
            rek[ 6] = rek[ 0] ^
                (Te4[(temp >> 16) & 0xff] & 0xff000000) ^
                (Te4[(temp >>  8) & 0xff] & 0x00ff0000) ^
                (Te4[(temp      ) & 0xff] & 0x0000ff00) ^
                (Te4[(temp >> 24)       ] & 0x000000ff) ^
                rcon[i];
            rek[ 7] = rek[ 1] ^ rek[ 6];
            rek[ 8] = rek[ 2] ^ rek[ 7];
            rek[ 9] = rek[ 3] ^ rek[ 8];
            if (++i == 8) {
                Nr = 12;
                return;
            }
            rek[10] = rek[ 4] ^ rek[ 9];
            rek[11] = rek[ 5] ^ rek[10];
            rek += 6;
        }
    }
    rek[6] = GETWORD(cipherKey + 24);
    rek[7] = GETWORD(cipherKey + 28);
    if (keyBits == 256) {
        for (;;) {
            temp = rek[ 7];
            rek[ 8] = rek[ 0] ^
                (Te4[(temp >> 16) & 0xff] & 0xff000000) ^
                (Te4[(temp >>  8) & 0xff] & 0x00ff0000) ^
                (Te4[(temp      ) & 0xff] & 0x0000ff00) ^
                (Te4[(temp >> 24)       ] & 0x000000ff) ^
                rcon[i];
            rek[ 9] = rek[ 1] ^ rek[ 8];
            rek[10] = rek[ 2] ^ rek[ 9];
            rek[11] = rek[ 3] ^ rek[10];
            if (++i == 7) {
                Nr = 14;
                return;
            }
            temp = rek[11];
            rek[12] = rek[ 4] ^
                (Te4[(temp >> 24)       ] & 0xff000000) ^
                (Te4[(temp >> 16) & 0xff] & 0x00ff0000) ^
                (Te4[(temp >>  8) & 0xff] & 0x0000ff00) ^
                (Te4[(temp      ) & 0xff] & 0x000000ff);
            rek[13] = rek[ 5] ^ rek[12];
            rek[14] = rek[ 6] ^ rek[13];
            rek[15] = rek[ 7] ^ rek[14];
            rek += 8;
        }
    }
    Nr = 0; // this should never happen
}

void AES::InvertKey() {
    uint *rek = e_sched;
    uint *rdk = d_sched;
    assert(Nr == 10 || Nr == 12 || Nr == 14);
    rek += 4*Nr;
    /* apply the inverse MixColumn transform to all round keys but the first and the last: */
    memcpy(rdk, rek, 16);
    rdk += 4;
    rek -= 4;
    for (uint r = 1; r < Nr; r++) {
        rdk[0] =
            Td0[Te4[(rek[0] >> 24)       ] & 0xff] ^
            Td1[Te4[(rek[0] >> 16) & 0xff] & 0xff] ^
            Td2[Te4[(rek[0] >>  8) & 0xff] & 0xff] ^
            Td3[Te4[(rek[0]      ) & 0xff] & 0xff];
        rdk[1] =
            Td0[Te4[(rek[1] >> 24)       ] & 0xff] ^
            Td1[Te4[(rek[1] >> 16) & 0xff] & 0xff] ^
            Td2[Te4[(rek[1] >>  8) & 0xff] & 0xff] ^
            Td3[Te4[(rek[1]      ) & 0xff] & 0xff];
        rdk[2] =
            Td0[Te4[(rek[2] >> 24)       ] & 0xff] ^
            Td1[Te4[(rek[2] >> 16) & 0xff] & 0xff] ^
            Td2[Te4[(rek[2] >>  8) & 0xff] & 0xff] ^
            Td3[Te4[(rek[2]      ) & 0xff] & 0xff];
        rdk[3] =
            Td0[Te4[(rek[3] >> 24)       ] & 0xff] ^
            Td1[Te4[(rek[3] >> 16) & 0xff] & 0xff] ^
            Td2[Te4[(rek[3] >>  8) & 0xff] & 0xff] ^
            Td3[Te4[(rek[3]      ) & 0xff] & 0xff];
        rdk += 4;
        rek -= 4;
    }
    memcpy(rdk, rek, 16);
}

//////////////////////////////////////////////////////////////////////
// Public Interface
//////////////////////////////////////////////////////////////////////

void AES::byte2int(const byte *b, uint *i) {
    i[0] = GETWORD(b     );
    i[1] = GETWORD(b +  4);
    i[2] = GETWORD(b +  8);
    i[3] = GETWORD(b + 12);
}

void AES::int2byte(const uint *i, byte *b) {
    PUTWORD(b     , i[0]);
    PUTWORD(b +  4, i[1]);
    PUTWORD(b +  8, i[2]);
    PUTWORD(b + 12, i[3]);
}

void AES::makeKey(const byte *cipherKey, uint keySize, uint dir) {
    switch (keySize) {
    case 16:
    case 24:
    case 32:
        keySize <<= 3;
        break;
    case 128:
    case 192:
    case 256:
        break;
    default:
        throw "Invalid AES key size";
    }
    assert(dir <= DIR_BOTH);
    if (dir != DIR_NONE) {
        ExpandKey(cipherKey, keySize);
        cudaMemcpy(ce_sched, e_sched, sizeof(e_sched), cudaMemcpyHostToDevice);
        if (dir & DIR_DECRYPT) {
            InvertKey();
            cudaMemcpy(cd_sched, d_sched, sizeof(e_sched), cudaMemcpyHostToDevice);
        }
    }
}

void AES::encrypt(const uint *pt, uint *ct, uint n = 1) {
	uint *cpt, *cct;
	uint size = (n << 2)*sizeof(uint);

	cudaMalloc((void**)&cpt, size);
	cudaMalloc((void**)&cct, size);
	cudaMemcpy(cpt, pt, size, cudaMemcpyHostToDevice);

    struct cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);

	uint blocks, threads = 1;
	if(n != 1) {
		threads = (n < prop.maxThreadsPerBlock*2) ? n / 2 : prop.maxThreadsPerBlock;
	}
	blocks = n / threads;

	dim3 dimBlock(threads);
	dim3 dimGrid(blocks);

	AES_encrypt<<<dimGrid, dimBlock, size>>>(cpt, cct, ce_sched, Nr);

	cudaMemcpy(ct, cct, size, cudaMemcpyDeviceToHost);
	cudaFree(cpt);
	cudaFree(cct);
}

void AES::decrypt(const uint *ct, uint *pt, uint n = 1) {
	uint *cpt, *cct;
	uint size = (n << 2)*sizeof(uint);

	cudaMalloc((void**)&cpt, size);
	cudaMalloc((void**)&cct, size);
	cudaMemcpy(cct, ct, size, cudaMemcpyHostToDevice);

    struct cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);

	uint blocks, threads = 1;
	if(n != 1) {
		threads = (n < prop.maxThreadsPerBlock*2) ? n / 2 : prop.maxThreadsPerBlock;
	}
	blocks = n / threads;

	dim3 dimBlock(threads);
	dim3 dimGrid(blocks);

	AES_decrypt<<<dimGrid, dimBlock, size>>>(cct, cpt, cd_sched, Nr);

	cudaMemcpy(pt, cpt, size, cudaMemcpyDeviceToHost);
	cudaFree(cpt);
	cudaFree(cct);
}

__global__ void AES_encrypt(const uint *pt, uint *ct, uint *rek, uint Nr) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int i = x + y * gridDim.x * blockDim.x;
    int offset = i << 2;

    __shared__ __device__ uint s0, s1, s2, s3, t0, t1, t2, t3;

    s0 = pt[offset + 0] ^ rek[0];
    s1 = pt[offset + 1] ^ rek[1];
    s2 = pt[offset + 2] ^ rek[2];
    s3 = pt[offset + 3] ^ rek[3];

    /* round 1: */
    t0 = cTe0[s0 >> 24] ^ cTe1[(s1 >> 16) & 0xff] ^ cTe2[(s2 >>  8) & 0xff] ^ cTe3[s3 & 0xff] ^ rek[ 4];
    t1 = cTe0[s1 >> 24] ^ cTe1[(s2 >> 16) & 0xff] ^ cTe2[(s3 >>  8) & 0xff] ^ cTe3[s0 & 0xff] ^ rek[ 5];
    t2 = cTe0[s2 >> 24] ^ cTe1[(s3 >> 16) & 0xff] ^ cTe2[(s0 >>  8) & 0xff] ^ cTe3[s1 & 0xff] ^ rek[ 6];
    t3 = cTe0[s3 >> 24] ^ cTe1[(s0 >> 16) & 0xff] ^ cTe2[(s1 >>  8) & 0xff] ^ cTe3[s2 & 0xff] ^ rek[ 7];
    /* round 2: */
    s0 = cTe0[t0 >> 24] ^ cTe1[(t1 >> 16) & 0xff] ^ cTe2[(t2 >>  8) & 0xff] ^ cTe3[t3 & 0xff] ^ rek[ 8];
    s1 = cTe0[t1 >> 24] ^ cTe1[(t2 >> 16) & 0xff] ^ cTe2[(t3 >>  8) & 0xff] ^ cTe3[t0 & 0xff] ^ rek[ 9];
    s2 = cTe0[t2 >> 24] ^ cTe1[(t3 >> 16) & 0xff] ^ cTe2[(t0 >>  8) & 0xff] ^ cTe3[t1 & 0xff] ^ rek[10];
    s3 = cTe0[t3 >> 24] ^ cTe1[(t0 >> 16) & 0xff] ^ cTe2[(t1 >>  8) & 0xff] ^ cTe3[t2 & 0xff] ^ rek[11];
    /* round 3: */
    t0 = cTe0[s0 >> 24] ^ cTe1[(s1 >> 16) & 0xff] ^ cTe2[(s2 >>  8) & 0xff] ^ cTe3[s3 & 0xff] ^ rek[12];
    t1 = cTe0[s1 >> 24] ^ cTe1[(s2 >> 16) & 0xff] ^ cTe2[(s3 >>  8) & 0xff] ^ cTe3[s0 & 0xff] ^ rek[13];
    t2 = cTe0[s2 >> 24] ^ cTe1[(s3 >> 16) & 0xff] ^ cTe2[(s0 >>  8) & 0xff] ^ cTe3[s1 & 0xff] ^ rek[14];
    t3 = cTe0[s3 >> 24] ^ cTe1[(s0 >> 16) & 0xff] ^ cTe2[(s1 >>  8) & 0xff] ^ cTe3[s2 & 0xff] ^ rek[15];
    /* round 4: */
    s0 = cTe0[t0 >> 24] ^ cTe1[(t1 >> 16) & 0xff] ^ cTe2[(t2 >>  8) & 0xff] ^ cTe3[t3 & 0xff] ^ rek[16];
    s1 = cTe0[t1 >> 24] ^ cTe1[(t2 >> 16) & 0xff] ^ cTe2[(t3 >>  8) & 0xff] ^ cTe3[t0 & 0xff] ^ rek[17];
    s2 = cTe0[t2 >> 24] ^ cTe1[(t3 >> 16) & 0xff] ^ cTe2[(t0 >>  8) & 0xff] ^ cTe3[t1 & 0xff] ^ rek[18];
    s3 = cTe0[t3 >> 24] ^ cTe1[(t0 >> 16) & 0xff] ^ cTe2[(t1 >>  8) & 0xff] ^ cTe3[t2 & 0xff] ^ rek[19];
    /* round 5: */
    t0 = cTe0[s0 >> 24] ^ cTe1[(s1 >> 16) & 0xff] ^ cTe2[(s2 >>  8) & 0xff] ^ cTe3[s3 & 0xff] ^ rek[20];
    t1 = cTe0[s1 >> 24] ^ cTe1[(s2 >> 16) & 0xff] ^ cTe2[(s3 >>  8) & 0xff] ^ cTe3[s0 & 0xff] ^ rek[21];
    t2 = cTe0[s2 >> 24] ^ cTe1[(s3 >> 16) & 0xff] ^ cTe2[(s0 >>  8) & 0xff] ^ cTe3[s1 & 0xff] ^ rek[22];
    t3 = cTe0[s3 >> 24] ^ cTe1[(s0 >> 16) & 0xff] ^ cTe2[(s1 >>  8) & 0xff] ^ cTe3[s2 & 0xff] ^ rek[23];
    /* round 6: */
    s0 = cTe0[t0 >> 24] ^ cTe1[(t1 >> 16) & 0xff] ^ cTe2[(t2 >>  8) & 0xff] ^ cTe3[t3 & 0xff] ^ rek[24];
    s1 = cTe0[t1 >> 24] ^ cTe1[(t2 >> 16) & 0xff] ^ cTe2[(t3 >>  8) & 0xff] ^ cTe3[t0 & 0xff] ^ rek[25];
    s2 = cTe0[t2 >> 24] ^ cTe1[(t3 >> 16) & 0xff] ^ cTe2[(t0 >>  8) & 0xff] ^ cTe3[t1 & 0xff] ^ rek[26];
    s3 = cTe0[t3 >> 24] ^ cTe1[(t0 >> 16) & 0xff] ^ cTe2[(t1 >>  8) & 0xff] ^ cTe3[t2 & 0xff] ^ rek[27];
    /* round 7: */
    t0 = cTe0[s0 >> 24] ^ cTe1[(s1 >> 16) & 0xff] ^ cTe2[(s2 >>  8) & 0xff] ^ cTe3[s3 & 0xff] ^ rek[28];
    t1 = cTe0[s1 >> 24] ^ cTe1[(s2 >> 16) & 0xff] ^ cTe2[(s3 >>  8) & 0xff] ^ cTe3[s0 & 0xff] ^ rek[29];
    t2 = cTe0[s2 >> 24] ^ cTe1[(s3 >> 16) & 0xff] ^ cTe2[(s0 >>  8) & 0xff] ^ cTe3[s1 & 0xff] ^ rek[30];
    t3 = cTe0[s3 >> 24] ^ cTe1[(s0 >> 16) & 0xff] ^ cTe2[(s1 >>  8) & 0xff] ^ cTe3[s2 & 0xff] ^ rek[31];
    /* round 8: */
    s0 = cTe0[t0 >> 24] ^ cTe1[(t1 >> 16) & 0xff] ^ cTe2[(t2 >>  8) & 0xff] ^ cTe3[t3 & 0xff] ^ rek[32];
    s1 = cTe0[t1 >> 24] ^ cTe1[(t2 >> 16) & 0xff] ^ cTe2[(t3 >>  8) & 0xff] ^ cTe3[t0 & 0xff] ^ rek[33];
    s2 = cTe0[t2 >> 24] ^ cTe1[(t3 >> 16) & 0xff] ^ cTe2[(t0 >>  8) & 0xff] ^ cTe3[t1 & 0xff] ^ rek[34];
    s3 = cTe0[t3 >> 24] ^ cTe1[(t0 >> 16) & 0xff] ^ cTe2[(t1 >>  8) & 0xff] ^ cTe3[t2 & 0xff] ^ rek[35];
    /* round 9: */
    t0 = cTe0[s0 >> 24] ^ cTe1[(s1 >> 16) & 0xff] ^ cTe2[(s2 >>  8) & 0xff] ^ cTe3[s3 & 0xff] ^ rek[36];
    t1 = cTe0[s1 >> 24] ^ cTe1[(s2 >> 16) & 0xff] ^ cTe2[(s3 >>  8) & 0xff] ^ cTe3[s0 & 0xff] ^ rek[37];
    t2 = cTe0[s2 >> 24] ^ cTe1[(s3 >> 16) & 0xff] ^ cTe2[(s0 >>  8) & 0xff] ^ cTe3[s1 & 0xff] ^ rek[38];
    t3 = cTe0[s3 >> 24] ^ cTe1[(s0 >> 16) & 0xff] ^ cTe2[(s1 >>  8) & 0xff] ^ cTe3[s2 & 0xff] ^ rek[39];
    if (Nr > 10) {
        /* round 10: */
        s0 = cTe0[t0 >> 24] ^ cTe1[(t1 >> 16) & 0xff] ^ cTe2[(t2 >>  8) & 0xff] ^ cTe3[t3 & 0xff] ^ rek[40];
        s1 = cTe0[t1 >> 24] ^ cTe1[(t2 >> 16) & 0xff] ^ cTe2[(t3 >>  8) & 0xff] ^ cTe3[t0 & 0xff] ^ rek[41];
        s2 = cTe0[t2 >> 24] ^ cTe1[(t3 >> 16) & 0xff] ^ cTe2[(t0 >>  8) & 0xff] ^ cTe3[t1 & 0xff] ^ rek[42];
        s3 = cTe0[t3 >> 24] ^ cTe1[(t0 >> 16) & 0xff] ^ cTe2[(t1 >>  8) & 0xff] ^ cTe3[t2 & 0xff] ^ rek[43];
        /* round 11: */
        t0 = cTe0[s0 >> 24] ^ cTe1[(s1 >> 16) & 0xff] ^ cTe2[(s2 >>  8) & 0xff] ^ cTe3[s3 & 0xff] ^ rek[44];
        t1 = cTe0[s1 >> 24] ^ cTe1[(s2 >> 16) & 0xff] ^ cTe2[(s3 >>  8) & 0xff] ^ cTe3[s0 & 0xff] ^ rek[45];
        t2 = cTe0[s2 >> 24] ^ cTe1[(s3 >> 16) & 0xff] ^ cTe2[(s0 >>  8) & 0xff] ^ cTe3[s1 & 0xff] ^ rek[46];
        t3 = cTe0[s3 >> 24] ^ cTe1[(s0 >> 16) & 0xff] ^ cTe2[(s1 >>  8) & 0xff] ^ cTe3[s2 & 0xff] ^ rek[47];
        if (Nr > 12) {
            /* round 12: */
            s0 = cTe0[t0 >> 24] ^ cTe1[(t1 >> 16) & 0xff] ^ cTe2[(t2 >>  8) & 0xff] ^ cTe3[t3 & 0xff] ^ rek[48];
            s1 = cTe0[t1 >> 24] ^ cTe1[(t2 >> 16) & 0xff] ^ cTe2[(t3 >>  8) & 0xff] ^ cTe3[t0 & 0xff] ^ rek[49];
            s2 = cTe0[t2 >> 24] ^ cTe1[(t3 >> 16) & 0xff] ^ cTe2[(t0 >>  8) & 0xff] ^ cTe3[t1 & 0xff] ^ rek[50];
            s3 = cTe0[t3 >> 24] ^ cTe1[(t0 >> 16) & 0xff] ^ cTe2[(t1 >>  8) & 0xff] ^ cTe3[t2 & 0xff] ^ rek[51];
            /* round 13: */
            t0 = cTe0[s0 >> 24] ^ cTe1[(s1 >> 16) & 0xff] ^ cTe2[(s2 >>  8) & 0xff] ^ cTe3[s3 & 0xff] ^ rek[52];
            t1 = cTe0[s1 >> 24] ^ cTe1[(s2 >> 16) & 0xff] ^ cTe2[(s3 >>  8) & 0xff] ^ cTe3[s0 & 0xff] ^ rek[53];
            t2 = cTe0[s2 >> 24] ^ cTe1[(s3 >> 16) & 0xff] ^ cTe2[(s0 >>  8) & 0xff] ^ cTe3[s1 & 0xff] ^ rek[54];
            t3 = cTe0[s3 >> 24] ^ cTe1[(s0 >> 16) & 0xff] ^ cTe2[(s1 >>  8) & 0xff] ^ cTe3[s2 & 0xff] ^ rek[55];
        }
    }
    rek += Nr << 2;

    ct[offset + 0] =
        (cTe4[(t0 >> 24)       ] & 0xff000000) ^
        (cTe4[(t1 >> 16) & 0xff] & 0x00ff0000) ^
        (cTe4[(t2 >>  8) & 0xff] & 0x0000ff00) ^
        (cTe4[(t3      ) & 0xff] & 0x000000ff) ^
        rek[0];
    ct[offset + 1] =
        (cTe4[(t1 >> 24)       ] & 0xff000000) ^
        (cTe4[(t2 >> 16) & 0xff] & 0x00ff0000) ^
        (cTe4[(t3 >>  8) & 0xff] & 0x0000ff00) ^
        (cTe4[(t0      ) & 0xff] & 0x000000ff) ^
        rek[1];
    ct[offset + 2] =
        (cTe4[(t2 >> 24)       ] & 0xff000000) ^
        (cTe4[(t3 >> 16) & 0xff] & 0x00ff0000) ^
        (cTe4[(t0 >>  8) & 0xff] & 0x0000ff00) ^
        (cTe4[(t1      ) & 0xff] & 0x000000ff) ^
        rek[2];
    ct[offset + 3] =
        (cTe4[(t3 >> 24)       ] & 0xff000000) ^
        (cTe4[(t0 >> 16) & 0xff] & 0x00ff0000) ^
        (cTe4[(t1 >>  8) & 0xff] & 0x0000ff00) ^
        (cTe4[(t2      ) & 0xff] & 0x000000ff) ^
        rek[3];
}

__global__ void AES_decrypt(const uint *ct, uint *pt, uint *rdk, uint Nr) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int i = x + y * gridDim.x * blockDim.x;
    int offset = i << 2;

    __shared__ __device__ uint s0, s1, s2, s3, t0, t1, t2, t3;

    s0 = ct[offset + 0] ^ rdk[0];
    s1 = ct[offset + 1] ^ rdk[1];
    s2 = ct[offset + 2] ^ rdk[2];
    s3 = ct[offset + 3] ^ rdk[3];

    /* round 1: */
    t0 = cTd0[s0 >> 24] ^ cTd1[(s3 >> 16) & 0xff] ^ cTd2[(s2 >>  8) & 0xff] ^ cTd3[s1 & 0xff] ^ rdk[ 4];
    t1 = cTd0[s1 >> 24] ^ cTd1[(s0 >> 16) & 0xff] ^ cTd2[(s3 >>  8) & 0xff] ^ cTd3[s2 & 0xff] ^ rdk[ 5];
    t2 = cTd0[s2 >> 24] ^ cTd1[(s1 >> 16) & 0xff] ^ cTd2[(s0 >>  8) & 0xff] ^ cTd3[s3 & 0xff] ^ rdk[ 6];
    t3 = cTd0[s3 >> 24] ^ cTd1[(s2 >> 16) & 0xff] ^ cTd2[(s1 >>  8) & 0xff] ^ cTd3[s0 & 0xff] ^ rdk[ 7];
    /* round 2: */
    s0 = cTd0[t0 >> 24] ^ cTd1[(t3 >> 16) & 0xff] ^ cTd2[(t2 >>  8) & 0xff] ^ cTd3[t1 & 0xff] ^ rdk[ 8];
    s1 = cTd0[t1 >> 24] ^ cTd1[(t0 >> 16) & 0xff] ^ cTd2[(t3 >>  8) & 0xff] ^ cTd3[t2 & 0xff] ^ rdk[ 9];
    s2 = cTd0[t2 >> 24] ^ cTd1[(t1 >> 16) & 0xff] ^ cTd2[(t0 >>  8) & 0xff] ^ cTd3[t3 & 0xff] ^ rdk[10];
    s3 = cTd0[t3 >> 24] ^ cTd1[(t2 >> 16) & 0xff] ^ cTd2[(t1 >>  8) & 0xff] ^ cTd3[t0 & 0xff] ^ rdk[11];
    /* round 3: */
    t0 = cTd0[s0 >> 24] ^ cTd1[(s3 >> 16) & 0xff] ^ cTd2[(s2 >>  8) & 0xff] ^ cTd3[s1 & 0xff] ^ rdk[12];
    t1 = cTd0[s1 >> 24] ^ cTd1[(s0 >> 16) & 0xff] ^ cTd2[(s3 >>  8) & 0xff] ^ cTd3[s2 & 0xff] ^ rdk[13];
    t2 = cTd0[s2 >> 24] ^ cTd1[(s1 >> 16) & 0xff] ^ cTd2[(s0 >>  8) & 0xff] ^ cTd3[s3 & 0xff] ^ rdk[14];
    t3 = cTd0[s3 >> 24] ^ cTd1[(s2 >> 16) & 0xff] ^ cTd2[(s1 >>  8) & 0xff] ^ cTd3[s0 & 0xff] ^ rdk[15];
    /* round 4: */
    s0 = cTd0[t0 >> 24] ^ cTd1[(t3 >> 16) & 0xff] ^ cTd2[(t2 >>  8) & 0xff] ^ cTd3[t1 & 0xff] ^ rdk[16];
    s1 = cTd0[t1 >> 24] ^ cTd1[(t0 >> 16) & 0xff] ^ cTd2[(t3 >>  8) & 0xff] ^ cTd3[t2 & 0xff] ^ rdk[17];
    s2 = cTd0[t2 >> 24] ^ cTd1[(t1 >> 16) & 0xff] ^ cTd2[(t0 >>  8) & 0xff] ^ cTd3[t3 & 0xff] ^ rdk[18];
    s3 = cTd0[t3 >> 24] ^ cTd1[(t2 >> 16) & 0xff] ^ cTd2[(t1 >>  8) & 0xff] ^ cTd3[t0 & 0xff] ^ rdk[19];
    /* round 5: */
    t0 = cTd0[s0 >> 24] ^ cTd1[(s3 >> 16) & 0xff] ^ cTd2[(s2 >>  8) & 0xff] ^ cTd3[s1 & 0xff] ^ rdk[20];
    t1 = cTd0[s1 >> 24] ^ cTd1[(s0 >> 16) & 0xff] ^ cTd2[(s3 >>  8) & 0xff] ^ cTd3[s2 & 0xff] ^ rdk[21];
    t2 = cTd0[s2 >> 24] ^ cTd1[(s1 >> 16) & 0xff] ^ cTd2[(s0 >>  8) & 0xff] ^ cTd3[s3 & 0xff] ^ rdk[22];
    t3 = cTd0[s3 >> 24] ^ cTd1[(s2 >> 16) & 0xff] ^ cTd2[(s1 >>  8) & 0xff] ^ cTd3[s0 & 0xff] ^ rdk[23];
    /* round 6: */
    s0 = cTd0[t0 >> 24] ^ cTd1[(t3 >> 16) & 0xff] ^ cTd2[(t2 >>  8) & 0xff] ^ cTd3[t1 & 0xff] ^ rdk[24];
    s1 = cTd0[t1 >> 24] ^ cTd1[(t0 >> 16) & 0xff] ^ cTd2[(t3 >>  8) & 0xff] ^ cTd3[t2 & 0xff] ^ rdk[25];
    s2 = cTd0[t2 >> 24] ^ cTd1[(t1 >> 16) & 0xff] ^ cTd2[(t0 >>  8) & 0xff] ^ cTd3[t3 & 0xff] ^ rdk[26];
    s3 = cTd0[t3 >> 24] ^ cTd1[(t2 >> 16) & 0xff] ^ cTd2[(t1 >>  8) & 0xff] ^ cTd3[t0 & 0xff] ^ rdk[27];
    /* round 7: */
    t0 = cTd0[s0 >> 24] ^ cTd1[(s3 >> 16) & 0xff] ^ cTd2[(s2 >>  8) & 0xff] ^ cTd3[s1 & 0xff] ^ rdk[28];
    t1 = cTd0[s1 >> 24] ^ cTd1[(s0 >> 16) & 0xff] ^ cTd2[(s3 >>  8) & 0xff] ^ cTd3[s2 & 0xff] ^ rdk[29];
    t2 = cTd0[s2 >> 24] ^ cTd1[(s1 >> 16) & 0xff] ^ cTd2[(s0 >>  8) & 0xff] ^ cTd3[s3 & 0xff] ^ rdk[30];
    t3 = cTd0[s3 >> 24] ^ cTd1[(s2 >> 16) & 0xff] ^ cTd2[(s1 >>  8) & 0xff] ^ cTd3[s0 & 0xff] ^ rdk[31];
    /* round 8: */
    s0 = cTd0[t0 >> 24] ^ cTd1[(t3 >> 16) & 0xff] ^ cTd2[(t2 >>  8) & 0xff] ^ cTd3[t1 & 0xff] ^ rdk[32];
    s1 = cTd0[t1 >> 24] ^ cTd1[(t0 >> 16) & 0xff] ^ cTd2[(t3 >>  8) & 0xff] ^ cTd3[t2 & 0xff] ^ rdk[33];
    s2 = cTd0[t2 >> 24] ^ cTd1[(t1 >> 16) & 0xff] ^ cTd2[(t0 >>  8) & 0xff] ^ cTd3[t3 & 0xff] ^ rdk[34];
    s3 = cTd0[t3 >> 24] ^ cTd1[(t2 >> 16) & 0xff] ^ cTd2[(t1 >>  8) & 0xff] ^ cTd3[t0 & 0xff] ^ rdk[35];
    /* round 9: */
    t0 = cTd0[s0 >> 24] ^ cTd1[(s3 >> 16) & 0xff] ^ cTd2[(s2 >>  8) & 0xff] ^ cTd3[s1 & 0xff] ^ rdk[36];
    t1 = cTd0[s1 >> 24] ^ cTd1[(s0 >> 16) & 0xff] ^ cTd2[(s3 >>  8) & 0xff] ^ cTd3[s2 & 0xff] ^ rdk[37];
    t2 = cTd0[s2 >> 24] ^ cTd1[(s1 >> 16) & 0xff] ^ cTd2[(s0 >>  8) & 0xff] ^ cTd3[s3 & 0xff] ^ rdk[38];
    t3 = cTd0[s3 >> 24] ^ cTd1[(s2 >> 16) & 0xff] ^ cTd2[(s1 >>  8) & 0xff] ^ cTd3[s0 & 0xff] ^ rdk[39];
    if (Nr > 10) {
        /* round 10: */
        s0 = cTd0[t0 >> 24] ^ cTd1[(t3 >> 16) & 0xff] ^ cTd2[(t2 >>  8) & 0xff] ^ cTd3[t1 & 0xff] ^ rdk[40];
        s1 = cTd0[t1 >> 24] ^ cTd1[(t0 >> 16) & 0xff] ^ cTd2[(t3 >>  8) & 0xff] ^ cTd3[t2 & 0xff] ^ rdk[41];
        s2 = cTd0[t2 >> 24] ^ cTd1[(t1 >> 16) & 0xff] ^ cTd2[(t0 >>  8) & 0xff] ^ cTd3[t3 & 0xff] ^ rdk[42];
        s3 = cTd0[t3 >> 24] ^ cTd1[(t2 >> 16) & 0xff] ^ cTd2[(t1 >>  8) & 0xff] ^ cTd3[t0 & 0xff] ^ rdk[43];
        /* round 11: */
        t0 = cTd0[s0 >> 24] ^ cTd1[(s3 >> 16) & 0xff] ^ cTd2[(s2 >>  8) & 0xff] ^ cTd3[s1 & 0xff] ^ rdk[44];
        t1 = cTd0[s1 >> 24] ^ cTd1[(s0 >> 16) & 0xff] ^ cTd2[(s3 >>  8) & 0xff] ^ cTd3[s2 & 0xff] ^ rdk[45];
        t2 = cTd0[s2 >> 24] ^ cTd1[(s1 >> 16) & 0xff] ^ cTd2[(s0 >>  8) & 0xff] ^ cTd3[s3 & 0xff] ^ rdk[46];
        t3 = cTd0[s3 >> 24] ^ cTd1[(s2 >> 16) & 0xff] ^ cTd2[(s1 >>  8) & 0xff] ^ cTd3[s0 & 0xff] ^ rdk[47];
        if (Nr > 12) {
            /* round 12: */
            s0 = cTd0[t0 >> 24] ^ cTd1[(t3 >> 16) & 0xff] ^ cTd2[(t2 >>  8) & 0xff] ^ cTd3[t1 & 0xff] ^ rdk[48];
            s1 = cTd0[t1 >> 24] ^ cTd1[(t0 >> 16) & 0xff] ^ cTd2[(t3 >>  8) & 0xff] ^ cTd3[t2 & 0xff] ^ rdk[49];
            s2 = cTd0[t2 >> 24] ^ cTd1[(t1 >> 16) & 0xff] ^ cTd2[(t0 >>  8) & 0xff] ^ cTd3[t3 & 0xff] ^ rdk[50];
            s3 = cTd0[t3 >> 24] ^ cTd1[(t2 >> 16) & 0xff] ^ cTd2[(t1 >>  8) & 0xff] ^ cTd3[t0 & 0xff] ^ rdk[51];
            /* round 13: */
            t0 = cTd0[s0 >> 24] ^ cTd1[(s3 >> 16) & 0xff] ^ cTd2[(s2 >>  8) & 0xff] ^ cTd3[s1 & 0xff] ^ rdk[52];
            t1 = cTd0[s1 >> 24] ^ cTd1[(s0 >> 16) & 0xff] ^ cTd2[(s3 >>  8) & 0xff] ^ cTd3[s2 & 0xff] ^ rdk[53];
            t2 = cTd0[s2 >> 24] ^ cTd1[(s1 >> 16) & 0xff] ^ cTd2[(s0 >>  8) & 0xff] ^ cTd3[s3 & 0xff] ^ rdk[54];
            t3 = cTd0[s3 >> 24] ^ cTd1[(s2 >> 16) & 0xff] ^ cTd2[(s1 >>  8) & 0xff] ^ cTd3[s0 & 0xff] ^ rdk[55];
        }
    }
    rdk += Nr << 2;

    pt[offset + 0] =
        (cTd4[(t0 >> 24)       ] & 0xff000000) ^
        (cTd4[(t3 >> 16) & 0xff] & 0x00ff0000) ^
        (cTd4[(t2 >>  8) & 0xff] & 0x0000ff00) ^
        (cTd4[(t1      ) & 0xff] & 0x000000ff) ^
        rdk[0];
    pt[offset + 1] =
        (cTd4[(t1 >> 24)       ] & 0xff000000) ^
        (cTd4[(t0 >> 16) & 0xff] & 0x00ff0000) ^
        (cTd4[(t3 >>  8) & 0xff] & 0x0000ff00) ^
        (cTd4[(t2      ) & 0xff] & 0x000000ff) ^
        rdk[1];
    pt[offset + 2] =
        (cTd4[(t2 >> 24)       ] & 0xff000000) ^
        (cTd4[(t1 >> 16) & 0xff] & 0x00ff0000) ^
        (cTd4[(t0 >>  8) & 0xff] & 0x0000ff00) ^
        (cTd4[(t3      ) & 0xff] & 0x000000ff) ^
        rdk[2];
    pt[offset + 3] =
        (cTd4[(t3 >> 24)       ] & 0xff000000) ^
        (cTd4[(t2 >> 16) & 0xff] & 0x00ff0000) ^
        (cTd4[(t1 >>  8) & 0xff] & 0x0000ff00) ^
        (cTd4[(t0      ) & 0xff] & 0x000000ff) ^
        rdk[3];
}
