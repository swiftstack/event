import Platform

public typealias Instant = ContinuousClock.Instant

// Converts deadline to timeout milliseconds/timespec expected by epoll/kqueue

extension Instant {
#if os(macOS) || os(iOS)
    var timeoutSinceNow: timespec {
        let components = Self.now.duration(to: self).components
        return timespec(
            tv_sec: max(0, Int(components.seconds)),
            tv_nsec: max(0, Int(components.attoseconds / 1_000_000_000)))
    }
#else
    var timeoutSinceNow: Int32 {
        let components = Self.now.duration(to: self).components
        let timeout = components.seconds * 1_000 +
            components.attoseconds / 1_000_000_000_000_000
        return max(0, Int32(clamping: timeout))
    }
#endif
}
