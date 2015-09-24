--[[
	Originally from xf86drm_ffi
	This are some platform locking primitives which are used in the DRM 
	implementation, but not part of the basic client side API
--]]


--[[
	__drm_dummy_lock(lock) (*(__volatile__ unsigned int *)lock)

	DRM_LOCK_HELD  0x80000000U /**< Hardware lock is held */
	DRM_LOCK_CONT  0x40000000U /**< Hardware lock is contended */
--]]


#if defined(__GNUC__) && (__GNUC__ >= 2)
# if defined(__i386) || defined(__AMD64__) || defined(__x86_64__) || defined(__amd64__)
				/* Reflect changes here to drmP.h */
	DRM_CAS(lock,old,new,__ret)                                    \
	do {                                                           \
                int __dummy;	/* Can't mark eax as clobbered */      \
		__asm__ __volatile__(                                  \
			"lock ; cmpxchg %4,%1\n\t"                     \
                        "setnz %0"                                     \
			: "=d" (__ret),                                \
   			  "=m" (__drm_dummy_lock(lock)),               \
                          "=a" (__dummy)                               \
			: "2" (old),                                   \
			  "r" (new));                                  \
	} while (0)

#elif defined(__alpha__)

#define	DRM_CAS(lock, old, new, ret)		\
	do {					\
		int tmp, old32;			\
		__asm__ __volatile__(		\
		"	addl	$31, %5, %3\n"	\
		"1:	ldl_l	%0, %2\n"	\
		"	cmpeq	%0, %3, %1\n"	\
		"	beq	%1, 2f\n"	\
		"	mov	%4, %0\n"	\
		"	stl_c	%0, %2\n"	\
		"	beq	%0, 3f\n"	\
		"	mb\n"			\
		"2:	cmpeq	%1, 0, %1\n"	\
		".subsection 2\n"		\
		"3:	br	1b\n"		\
		".previous"			\
		: "=&r"(tmp), "=&r"(ret),	\
		  "=m"(__drm_dummy_lock(lock)),	\
		  "=&r"(old32)			\
		: "r"(new), "r"(old)		\
		: "memory");			\
	} while (0)

#elif defined(__sparc__)

	DRM_CAS(lock,old,new,__ret)				\
do {	register unsigned int __old __asm("o0");		\
	register unsigned int __new __asm("o1");		\
	register volatile unsigned int *__lock __asm("o2");	\
	__old = old;						\
	__new = new;						\
	__lock = (volatile unsigned int *)lock;			\
	__asm__ __volatile__(					\
		/*"cas [%2], %3, %0"*/				\
		".word 0xd3e29008\n\t"				\
		/*"membar #StoreStore | #StoreLoad"*/		\
		".word 0x8143e00a"				\
		: "=&r" (__new)					\
		: "0" (__new),					\
		  "r" (__lock),					\
		  "r" (__old)					\
		: "memory");					\
	__ret = (__new != __old);				\
} while(0)

#elif defined(__ia64__)

#ifdef __INTEL_COMPILER
/* this currently generates bad code (missing stop bits)... */
#include <ia64intrin.h>

	DRM_CAS(lock,old,new,__ret)					      \
	do {								      \
		unsigned long __result, __old = (old) & 0xffffffff;		\
		__mf();							      	\
		__result = _InterlockedCompareExchange_acq(&__drm_dummy_lock(lock), (new), __old);\
		__ret = (__result) != (__old);					\
/*		__ret = (__sync_val_compare_and_swap(&__drm_dummy_lock(lock), \
						     (old), (new))	      \
			 != (old));					      */\
	} while (0)

#else
	DRM_CAS(lock,old,new,__ret)					  \
	do {								  \
		unsigned int __result, __old = (old);			  \
		__asm__ __volatile__(					  \
			"mf\n"						  \
			"mov ar.ccv=%2\n"				  \
			";;\n"						  \
			"cmpxchg4.acq %0=%1,%3,ar.ccv"			  \
			: "=r" (__result), "=m" (__drm_dummy_lock(lock))  \
			: "r" ((unsigned long)__old), "r" (new)			  \
			: "memory");					  \
		__ret = (__result) != (__old);				  \
	} while (0)

#endif

#elif defined(__powerpc__)

	DRM_CAS(lock,old,new,__ret)			\
	do {						\
		__asm__ __volatile__(			\
			"sync;"				\
			"0:    lwarx %0,0,%1;"		\
			"      xor. %0,%3,%0;"		\
			"      bne 1f;"			\
			"      stwcx. %2,0,%1;"		\
			"      bne- 0b;"		\
			"1:    "			\
			"sync;"				\
		: "=&r"(__ret)				\
		: "r"(lock), "r"(new), "r"(old)		\
		: "cr0", "memory");			\
	} while (0)

#endif /* architecture */
#endif /* __GNUC__ >= 2 */
--]]

--[[
#ifndef DRM_CAS
	DRM_CAS(lock,old,new,ret) do { ret=1; } while (0) /* FAST LOCK FAILS */
#endif

#if defined(__alpha__)
	DRM_CAS_RESULT(_result)		long _result
#elif defined(__powerpc__)
	DRM_CAS_RESULT(_result)		int _result
#else
	DRM_CAS_RESULT(_result)		char _result
#endif
--]]

--[[
	DRM_LIGHT_LOCK(fd,lock,context)                                \
	do {                                                           \
                DRM_CAS_RESULT(__ret);                                 \
		DRM_CAS(lock,context,DRM_LOCK_HELD|context,__ret);     \
                if (__ret) drmGetLock(fd,context,0);                   \
        } while(0)

				/* This one counts fast locks -- for
                                   benchmarking only. */
	DRM_LIGHT_LOCK_COUNT(fd,lock,context,count)                    \
	do {                                                           \
                DRM_CAS_RESULT(__ret);                                 \
		DRM_CAS(lock,context,DRM_LOCK_HELD|context,__ret);     \
                if (__ret) drmGetLock(fd,context,0);                   \
                else       ++count;                                    \
        } while(0)

	DRM_LOCK(fd,lock,context,flags)                                \
	do {                                                           \
		if (flags) drmGetLock(fd,context,flags);               \
		else       DRM_LIGHT_LOCK(fd,lock,context);            \
	} while(0)

	DRM_UNLOCK(fd,lock,context)                                    \
	do {                                                           \
                DRM_CAS_RESULT(__ret);                                 \
		DRM_CAS(lock,DRM_LOCK_HELD|context,context,__ret);     \
                if (__ret) drmUnlock(fd,context);                      \
        } while(0)

				/* Simple spin locks */
	DRM_SPINLOCK(spin,val)                                         \
	do {                                                           \
            DRM_CAS_RESULT(__ret);                                     \
	    do {                                                       \
		DRM_CAS(spin,0,val,__ret);                             \
		if (__ret) while ((spin)->lock);                       \
	    } while (__ret);                                           \
	} while(0)

	DRM_SPINLOCK_TAKE(spin,val)                                    \
	do {                                                           \
            DRM_CAS_RESULT(__ret);                                     \
            int  cur;                                                  \
	    do {                                                       \
                cur = (*spin).lock;                                    \
		DRM_CAS(spin,cur,val,__ret);                           \
	    } while (__ret);                                           \
	} while(0)

	DRM_SPINLOCK_COUNT(spin,val,count,__ret)                       \
	do {                                                           \
            int  __i;                                                  \
            __ret = 1;                                                 \
            for (__i = 0; __ret && __i < count; __i++) {               \
		DRM_CAS(spin,0,val,__ret);                             \
		if (__ret) for (;__i < count && (spin)->lock; __i++);  \
	    }                                                          \
	} while(0)

	DRM_SPINUNLOCK(spin,val)                                       \
	do {                                                           \
            DRM_CAS_RESULT(__ret);                                     \
            if ((*spin).lock == val) { /* else server stole lock */    \
	        do {                                                   \
		    DRM_CAS(spin,val,0,__ret);                         \
	        } while (__ret);                                       \
            }                                                          \
	} while(0)

