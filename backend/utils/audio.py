import struct

def linear2ulaw(sample):
    MAX = 0x7FFF; BIAS = 0x84; sign = (sample >> 8) & 0x80
    if sample < 0: sample = -sample
    if sample > MAX: sample = MAX
    sample += BIAS; exponent = 7
    for i in range(7, -1, -1):
        if sample & (1 << (i + 7)): exponent = i; break
    mantissa = (sample >> (exponent + 3)) & 0x0F
    return ~(sign | (exponent << 4) | mantissa) & 0xFF

def convert_pcm_to_mulaw(pcm_bytes):
    num_samples = len(pcm_bytes) // 2
    samples = struct.unpack(f'<{num_samples}h', pcm_bytes)
    return bytes(linear2ulaw(s) for s in samples)