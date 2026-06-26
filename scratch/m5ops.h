#ifndef __M5OPS_H__
#define __M5OPS_H__

#define M5OPS_BASE 0x80002000

#define M5OP_EXIT               0x21
#define M5OP_FAIL               0x22
#define M5OP_RESET_STATS        0x40
#define M5OP_DUMP_STATS         0x41
#define M5OP_DUMP_RESET_STATS   0x42
#define M5OP_WORK_BEGIN         0x5a
#define M5OP_WORK_END           0x5b
#define M5OP_CHECKPOINT         0x43

#ifdef __ASSEMBLER__

/* Assembly macros */

.macro m5_exit delay
    li t6, M5OPS_BASE + (M5OP_EXIT << 8)
    li t5, \delay
    sd t5, 0(t6)
.endm

.macro m5_fail delay, code
    li t6, M5OPS_BASE + (M5OP_FAIL << 8)
    li t5, \delay
    li t4, \code
    slli t4, t4, 32
    or t5, t5, t4
    sd t5, 0(t6)
.endm

.macro m5_reset_stats delay, period
    li t6, M5OPS_BASE + (M5OP_RESET_STATS << 8)
    li t5, \delay
    li t4, \period
    slli t4, t4, 32
    or t5, t5, t4
    sd t5, 0(t6)
.endm

.macro m5_dump_stats delay, period
    li t6, M5OPS_BASE + (M5OP_DUMP_STATS << 8)
    li t5, \delay
    li t4, \period
    slli t4, t4, 32
    or t5, t5, t4
    sd t5, 0(t6)
.endm

.macro m5_dump_reset_stats delay, period
    li t6, M5OPS_BASE + (M5OP_DUMP_RESET_STATS << 8)
    li t5, \delay
    li t4, \period
    slli t4, t4, 32
    or t5, t5, t4
    sd t5, 0(t6)
.endm

.macro m5_work_begin workid, threadid
    li t6, M5OPS_BASE + (M5OP_WORK_BEGIN << 8)
    li t5, \workid
    li t4, \threadid
    slli t4, t4, 32
    or t5, t5, t4
    sd t5, 0(t6)
.endm

.macro m5_work_end workid, threadid
    li t6, M5OPS_BASE + (M5OP_WORK_END << 8)
    li t5, \workid
    li t4, \threadid
    slli t4, t4, 32
    or t5, t5, t4
    sd t5, 0(t6)
.endm

.macro m5_checkpoint delay, period
    li t6, M5OPS_BASE + (M5OP_CHECKPOINT << 8)
    li t5, \delay
    li t4, \period
    slli t4, t4, 32
    or t5, t5, t4
    sd t5, 0(t6)
.endm

#else

#include <stdint.h>

/* C inline functions */

static inline void m5_exit(uint64_t delay) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_EXIT << 8)) = delay;
}

static inline void m5_fail(uint64_t delay, uint64_t code) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_FAIL << 8)) = ((uint64_t)code << 32) | delay;
}

static inline void m5_reset_stats(uint64_t delay, uint64_t period) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_RESET_STATS << 8)) = ((uint64_t)period << 32) | delay;
}

static inline void m5_dump_stats(uint64_t delay, uint64_t period) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_DUMP_STATS << 8)) = ((uint64_t)period << 32) | delay;
}

static inline void m5_dump_reset_stats(uint64_t delay, uint64_t period) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_DUMP_RESET_STATS << 8)) = ((uint64_t)period << 32) | delay;
}

static inline void m5_work_begin(uint64_t workid, uint64_t threadid) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_WORK_BEGIN << 8)) = ((uint64_t)threadid << 32) | workid;
}

static inline void m5_work_end(uint64_t workid, uint64_t threadid) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_WORK_END << 8)) = ((uint64_t)threadid << 32) | workid;
}

static inline void m5_checkpoint(uint64_t delay, uint64_t period) {
    *(volatile uint64_t *)(M5OPS_BASE + (M5OP_CHECKPOINT << 8)) = ((uint64_t)period << 32) | delay;
}

#endif /* __ASSEMBLER__ */

#endif /* __M5OPS_H__ */
