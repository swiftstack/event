import Log
import Time
import Platform
import Foundation

public actor Loop {
    var poller = Poller()
    var eventHandlers: UnsafeMutableBufferPointer<Handlers>

    @actorIndependent(unsafe)
    public var isTerminated = false

    struct Handlers {
        var read: UnsafeContinuation<Void, Swift.Error>?
        var write: UnsafeContinuation<Void, Swift.Error>?

        var isEmpty: Bool { read == nil && write == nil }
    }

    public enum Error: Swift.Error {
        case descriptorAlreadyInUse
    }

    public init() {
        eventHandlers = UnsafeMutableBufferPointer.allocate(
            repeating: Handlers(),
            count: Descriptor.maxLimit)
    }

    deinit {
        eventHandlers.deallocate()
    }

    // FIXME: [Concurrency] adapt using custom executors
    public func run() async {
        loop.isTerminated = false
        do {
            while !loop.isTerminated {
                try await loop.poll(deadline: .now)
            }
        } catch {
            print("poll error:", error)
        }
    }

    // FIXME: [Concurrency] can't use deadline here yet
    private func poll(deadline: Time = .distantFuture) throws {
        let events = try poller.poll(deadline: deadline)
        if events.count != 0 {
            scheduleReady(events)
        }
    }

    public func terminate() {
        isTerminated = true
    }

    func scheduleReady(_ events: ArraySlice<Event>) {
        for event in events {
            let pair = eventHandlers[event.descriptor]

            guard !pair.isEmpty else { continue }

            if event.typeOptions.contains(.read), let handler = pair.read {
                removeContinuation(for: event.descriptor, event: .read)
                handler.resume(returning: ())
            }

            if event.typeOptions.contains(.write), let handler = pair.write {
                removeContinuation(for: event.descriptor, event: .write)
                handler.resume(returning: ())
            }
        }
    }

    public func wait(
        for socket: Descriptor,
        event: IOEvent,
        deadline: Time) async throws
    {
        return try await withUnsafeThrowingContinuation { continuation in
            insertContinuation(
                continuation,
                for: socket,
                event: event,
                deadline: deadline)
        }
    }

    func insertContinuation(
        _ handler: UnsafeContinuation<Void, Swift.Error>,
        for descriptor: Descriptor,
        event: IOEvent,
        deadline: Time
    ) {
        switch event {
        case .read:
            guard eventHandlers[descriptor].read == nil else {
                handler.resume(throwing: Error.descriptorAlreadyInUse)
                return
            }
            eventHandlers[descriptor].read = handler
        case .write:
            guard eventHandlers[descriptor].write == nil else {
                handler.resume(throwing: Error.descriptorAlreadyInUse)
                return
            }
            eventHandlers[descriptor].write = handler
        }
        poller.add(socket: descriptor, event: event)
    }

    func removeContinuation(for descriptor: Descriptor, event: IOEvent) {
        switch event {
        case .read: eventHandlers[descriptor].read = nil
        case .write: eventHandlers[descriptor].write = nil
        }
        poller.remove(socket: descriptor, event: event)
    }
}

public let loop: Loop = .init()

extension UnsafeMutableBufferPointer where Element == Loop.Handlers {
    typealias Watchers = Loop.Handlers

    subscript(_ descriptor: Descriptor) -> Watchers{
        get { self[Int(descriptor.rawValue)] }
        set { self[Int(descriptor.rawValue)] = newValue }
    }

    static func allocate(
        repeating element: Watchers,
        count: Int) -> UnsafeMutableBufferPointer<Watchers>
    {
        let pointer = UnsafeMutablePointer<Watchers>.allocate(capacity: count)
        pointer.initialize(repeating: element, count: count)

        return UnsafeMutableBufferPointer(
            start: pointer,
            count: Descriptor.maxLimit)
    }
}
