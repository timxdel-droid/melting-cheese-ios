import Foundation

/// Warms the photo cache so the customer never watches a placeholder.
///
/// `AsyncImage` loads through `URLSession.shared`, which reads and writes
/// `URLCache.shared` (sized in `MeltingCheeseApp`). Fetching the same URLs
/// here, through the same session, lands them in the same cache, so when a
/// row scrolls into view the image comes off disk instead of the network.
/// The server marks uploads immutable, so a warmed entry stays valid until
/// the photo itself is replaced - at which point its URL changes too.
///
/// Two passes, in this order:
///
///   1. Thumbnails - the sizes the list, grid and cart actually draw. This
///      is a few hundred kilobytes for the whole menu and runs on any
///      connection.
///   2. Originals - what the product detail hero shows. About 13 MB across
///      the catalogue, so this pass is skipped on cellular that the system
///      flags as expensive or in Low Data Mode. On Wi-Fi it runs after the
///      thumbnails, at low priority.
///
/// Nothing here is awaited by the UI. A failure is just a photo that loads
/// the old way when it is scrolled to.
actor ImagePrefetcher {
    static let shared = ImagePrefetcher()

    /// The widths the list screens request. Keep in step with the
    /// `coveringWidth:` arguments in HomeView, MenuView and OrderStore.
    static let listWidths = [142, 60, 58]

    /// How many downloads run at once. Four keeps the pipe full on a
    /// phone without starving the menu request or the UI's own image
    /// loads, which share the same session.
    private let concurrency = 4

    /// URLs already fetched (or found cached) this launch, so a menu
    /// refresh does not re-walk the whole catalogue.
    private var done = Set<URL>()
    private var running: Task<Void, Never>?

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Kicks off warming for the given products. Safe to call repeatedly:
    /// a run already in progress is cancelled and restarted with the new
    /// list, and URLs done earlier are skipped.
    func warm(_ products: [Product]) {
        running?.cancel()

        let thumbnails = Self.thumbnailURLs(for: products)
        let originals = Self.originalURLs(for: products)

        running = Task { [weak self] in
            guard let self else { return }
            await self.fetch(thumbnails, priority: .utility, expensiveOK: true)
            guard !Task.isCancelled else { return }
            await self.fetch(originals, priority: .background, expensiveOK: false)
        }
    }

    // MARK: - URL selection

    static func thumbnailURLs(for products: [Product]) -> [URL] {
        var seen = Set<URL>()
        var out: [URL] = []
        for product in products {
            for width in listWidths {
                if let url = product.thumbnailURL(coveringWidth: width), seen.insert(url).inserted {
                    out.append(url)
                }
            }
        }
        return out
    }

    static func originalURLs(for products: [Product]) -> [URL] {
        var seen = Set<URL>()
        var out: [URL] = []
        for product in products {
            // The whole gallery, not just the first photo: the detail
            // screen pages through all of them.
            for url in product.gallery where seen.insert(url).inserted {
                out.append(url)
            }
        }
        return out
    }

    // MARK: - Fetching

    private func fetch(_ urls: [URL], priority: TaskPriority, expensiveOK: Bool) async {
        let pending = urls.filter { !done.contains($0) && !isCached($0) }
        guard !pending.isEmpty else { return }

        await withTaskGroup(of: URL?.self) { group in
            var iterator = pending.makeIterator()

            func enqueue() {
                guard let url = iterator.next() else { return }
                group.addTask(priority: priority) { [session] in
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.networkServiceType = .background
                    request.allowsExpensiveNetworkAccess = expensiveOK
                    request.allowsConstrainedNetworkAccess = expensiveOK
                    // The bytes are discarded. Storing them is URLCache's
                    // job, and it has already done so by the time this
                    // returns.
                    guard (try? await session.data(for: request)) != nil else { return nil }
                    return url
                }
            }

            for _ in 0..<concurrency { enqueue() }

            for await finished in group {
                if let finished { done.insert(finished) }
                if Task.isCancelled { group.cancelAll(); break }
                enqueue()
            }
        }
    }

    private func isCached(_ url: URL) -> Bool {
        let request = URLRequest(url: url)
        if session.configuration.urlCache?.cachedResponse(for: request) != nil {
            done.insert(url)
            return true
        }
        return false
    }
}
