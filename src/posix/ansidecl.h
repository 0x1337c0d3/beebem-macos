#pragma once
// Stub for GCC binutils <ansidecl.h> — not needed on modern C++ compilers.

#ifndef ATTRIBUTE_UNUSED
#define ATTRIBUTE_UNUSED __attribute__((unused))
#endif

#ifndef ATTRIBUTE_NORETURN
#define ATTRIBUTE_NORETURN __attribute__((noreturn))
#endif

#ifndef ATTRIBUTE_PRINTF
#define ATTRIBUTE_PRINTF(m, n) __attribute__((format(printf, m, n)))
#endif
