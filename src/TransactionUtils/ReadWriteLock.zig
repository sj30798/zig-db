const std = @import("std");
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Semaphore = Thread.Semaphore;
const Atomic = std.atomic;

// Implements a Read-shared Write-exclusive lock mechanism
pub const ReadWriteLock = struct {
    readerCount: Atomic.Value(u32) = Atomic.Value(u32).store(0),
    writerCount: Atomic.Value(u32) = Atomic.Value(u32).store(0),
    mutexLock: Mutex = Mutex{},

    pub fn init() ReadWriteLock {
        return .{
            .mutexLock = Mutex{},
        };
    }

    pub fn readLock(self: *ReadWriteLock) bool {
        self.mutexLock.lock();
        defer self.mutexLock.unlock();

        if (self.writerCount == 0) {
            self.readerCount.fetchAdd(1);
            return true;
        }

        return false;
    }

    pub fn readUnlock(self: *ReadWriteLock) bool {
        self.readerCount.fetchSub(-1);
    }

    pub fn writeLock(self: *ReadWriteLock) bool {
        self.mutexLock.lock();
        defer self.mutexLock.unlock();

        if (self.readerCount.raw == 0 and self.writerCount.raw == 0) {
            self.writerCount.fetchAdd(1);
            return true;
        }

        return false;
    }

    pub fn writeUnlock(self: *ReadWriteLock) bool {
        self.writerCount.fetchSub(-1);
    }
};
