import Platform

public typealias Instant = ContinuousClock.Instant

// Converts deadline to timeout in seconds expected by epoll/kqueue

extension Instant {
#if os(macOS) || os(iOS)
    var kqueueMaximumTimeout: Duration {
        return .seconds(60*60*24)
    }

    var timeoutSinceNow: timespec {
        guard self < .now + kqueueMaximumTimeout else {
            return timespec(
                tv_sec: Int(kqueueMaximumTimeout.components.seconds),
                tv_nsec: Int(kqueueMaximumTimeout.components.attoseconds / 1_000_000_000))
        }
        let duration = Self.now.duration(to: self)
        return timespec(
            tv_sec: Int(duration.components.seconds),
            tv_nsec: Int(duration.components.attoseconds / 1_000_000_000))
    }
#else
    var timeoutSinceNow: Int32 {
        let duration = Self.now.duration(to: self)
        let timeout = duration.components.seconds * 1_000 + duration.components.attoseconds / 1_000_000_000_000_000
        guard timeout < Int(Int32.max) else {
            return Int32.max
        }
        return Int32(timeout)
    }
#endif
}
