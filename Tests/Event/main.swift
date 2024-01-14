import Test
import Platform
@testable import Event

#if os(Linux)
let SOCK_STREAM = Int32(Platform.SOCK_STREAM.rawValue)
#endif

extension Int {
    var ms: Instant.Duration { .milliseconds(self) }
}

func createSocketPair() throws -> (Descriptor, Descriptor) {
    let zero = Descriptor(rawValue: 0)!
    var sv: (Descriptor, Descriptor) = (zero, zero)

    try withUnsafeMutableBytes(of: &sv) { buffer in
        let buffer = buffer.baseAddress?.assumingMemoryBound(to: Int32.self)
        try system { socketpair(PF_LOCAL, SOCK_STREAM, 0, buffer) }
    }
    return sv
}

test("event") {
    let message = "test"
    let sv = try createSocketPair()

    _ = Task.detached {
        // wait for "can write" event
        try! await loop.wait(for: sv.0, event: .write, deadline: .now + 10.ms)

        write(sv.0.rawValue, message, message.count)

        // wait for "can read" event
        try! await loop.wait(for: sv.1, event: .read, deadline: .now + 10.ms)

        var buffer = [UInt8](repeating: 0, count: message.count)
        read(sv.1.rawValue, &buffer, message.count)

        expect(String(decoding: buffer, as: UTF8.self) == message)

        await loop.terminate()
    }

    await loop.run()
}

test("event from another task") {
    let message = "test"
    let sv = try createSocketPair()

    _ = Task.detached {
        // wait for "can write" event
        try! await loop.wait(for: sv.0, event: .write, deadline: .now + 10.ms)

        write(sv.0.rawValue, message, message.count)
    }

    _ = Task.detached {
        // wait for "can read" event
        try! await loop.wait(for: sv.1, event: .read, deadline: .now + 10.ms)

        var buffer = [UInt8](repeating: 0, count: message.count)
        read(sv.1.rawValue, &buffer, message.count)

        expect(String(decoding: buffer, as: UTF8.self) == message)

        await loop.terminate()
    }

    await loop.run()
}

await run()
