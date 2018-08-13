// Written in the D programming language.
/**
Source: $(PHOBOSSRC std/experimental/allocator/_mmap_allocator.d)
*/
module std.experimental.allocator.mmap_allocator;

/**
Allocator (currently defined only for Posix and Windows) using
$(D $(LINK2 https://en.wikipedia.org/wiki/Mmap, mmap))
and $(D $(LUCKY munmap)) directly (or their Windows equivalents). There is no
additional structure: each call to `allocate(s)` issues a call to
$(D mmap(null, s, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)),
and each call to `deallocate(b)` issues $(D munmap(b.ptr, b.length)).
So `MmapAllocator` is usually intended for allocating large chunks to be
managed by fine-granular allocators.
*/
struct MmapAllocator
{
    /// The one shared instance.
    static shared MmapAllocator instance;

    /**
    Alignment is page-size and hardcoded to 4096 (even though on certain systems
    it could be larger).
    */
    enum size_t alignment = 4096;

    version(Posix)
    {
        /// Allocator API.
        nothrow @nogc @safe
        void[] allocate(size_t bytes) shared
        {
            import core.sys.posix.sys.mman : mmap, MAP_ANON, PROT_READ,
                PROT_WRITE, MAP_PRIVATE, MAP_FAILED;
            if (!bytes) return null;
            auto p = (() @trusted => mmap(null, bytes, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANON, -1, 0))();
            if (p is MAP_FAILED) return null;
            return (() @trusted => p[0 .. bytes])();
        }

        /// Ditto
        nothrow @nogc
        bool deallocate(void[] b) shared
        {
            import core.sys.posix.sys.mman : munmap;
            if (b.ptr) munmap(b.ptr, b.length) == 0 || assert(0);
            return true;
        }

        // Anonymous mmap might be zero-filled on all Posix systems but
        // not all commit to this in the documentation.
        version(linux)
            // http://man7.org/linux/man-pages/man2/mmap.2.html
            package alias allocateZeroed = allocate;
        else version(NetBSD)
            // http://netbsd.gw.com/cgi-bin/man-cgi?mmap+2+NetBSD-current
            package alias allocateZeroed = allocate;
        else version(Solaris)
            // https://docs.oracle.com/cd/E88353_01/html/E37841/mmap-2.html
            package alias allocateZeroed = allocate;
        else version(AIX)
            // https://www.ibm.com/support/knowledgecenter/en/ssw_aix_71/com.ibm.aix.basetrf1/mmap.htm
            package alias allocateZeroed = allocate;
    }
    else version(Windows)
    {
        import core.sys.windows.windows : VirtualAlloc, VirtualFree, MEM_COMMIT,
            PAGE_READWRITE, MEM_RELEASE;

        /// Allocator API.
        nothrow @nogc @safe
        void[] allocate(size_t bytes) shared
        {
            if (!bytes) return null;
            auto p = (() @trusted => VirtualAlloc(null, bytes, MEM_COMMIT, PAGE_READWRITE))();
            if (p == null)
                return null;
            return (() @trusted => p[0 .. bytes])();
        }

        /// Ditto
        nothrow @nogc
        bool deallocate(void[] b) shared
        {
            return b.ptr is null || VirtualFree(b.ptr, 0, MEM_RELEASE) != 0;
        }

        package alias allocateZeroed = allocate;
    }
}

nothrow @safe @nogc unittest
{
    alias alloc = MmapAllocator.instance;
    auto p = alloc.allocate(100);
    assert(p.length == 100);
    () @trusted { alloc.deallocate(p); p = null; }();
}
