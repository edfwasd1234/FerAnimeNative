import SwiftUI

struct MangaView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var popular: [MangaItem] = []
    @State private var newest: [MangaItem] = []
    @State private var action: [MangaItem] = []
    @State private var results: [MangaItem] = []
    @State private var loading = true
    @State private var errorMessage: String?

    private var client: MangaKatanaClient { MangaKatanaClient(resolverBaseURL: appState.client.baseURL) }

    var body: some View {
        NavigationStack {
            ZStack {
                CinematicBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            mangaGrid(title: "Search Results", items: results)
                        } else {
                            mangaRail(title: "Popular Manga", items: popular)
                            mangaRail(title: "Newest Chapters", items: newest)
                            mangaGrid(title: "Action Picks", items: action)
                        }

                        if loading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .tint(Theme.appleBlue)
                                .padding(.vertical, 32)
                        }

                        if let errorMessage {
                            ContentUnavailableView("Manga Unavailable", systemImage: "books.vertical", description: Text(errorMessage))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 92)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Manga")
            .searchable(text: $query, prompt: "Search manga")
            .navigationDestination(for: MangaItem.self) { item in
                MangaDetailView(item: item)
            }
            .task { await loadHome() }
            .onChange(of: query) { _, _ in search() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manga")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Browse MangaKatana chapters, open a title, and read page-by-page in a native vertical reader.")
                .font(.callout)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .glassAppear(delay: 0.04)
    }

    private func mangaRail(title: String, items: [MangaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            MangaCard(item: item, width: 136, height: 196)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func mangaGrid(title: String, items: [MangaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 20) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        MangaCard(item: item, width: 142, height: 204)
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
    }

    private func loadHome() async {
        guard popular.isEmpty else { return }
        loading = true
        errorMessage = nil
        do {
            async let popularTask = client.list(type: "topview")
            async let newestTask = client.list(type: "newest")
            async let actionTask = client.list(type: "latest", category: "Action")
            let popularResponse = try await popularTask
            let newestResponse = try await newestTask
            let actionResponse = try await actionTask
            popular = popularResponse.mangaList
            newest = newestResponse.mangaList
            action = actionResponse.mangaList
        } catch {
            errorMessage = "Could not load MangaKatana right now."
        }
        loading = false
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        Task {
            do {
                results = try await client.search(trimmed).mangaList
            } catch {
                results = []
            }
        }
    }
}

struct MangaCard: View {
    let item: MangaItem
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PosterImage(url: URL(string: item.image ?? ""), cornerRadius: 18)
                .frame(width: width, height: height)
                .overlay(alignment: .bottomLeading) {
                    if let chapter = item.chapter {
                        Text(chapter.replacingOccurrences(of: "-", with: " "))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                            .padding(10)
                    }
                }
            Text(item.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
            if let view = item.view {
                Text(view)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.tertiary)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}

struct MangaDetailView: View {
    @EnvironmentObject private var appState: AppState
    let item: MangaItem
    @State private var detail: MangaDetail?
    @State private var loading = true
    @State private var errorMessage: String?

    private var client: MangaKatanaClient { MangaKatanaClient(resolverBaseURL: appState.client.baseURL) }

    var body: some View {
        ZStack {
            CinematicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    if let detail {
                        chapterList(detail.chapterList)
                    } else if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .tint(Theme.appleBlue)
                            .padding(.vertical, 40)
                    } else if let errorMessage {
                        ContentUnavailableView("Manga Unavailable", systemImage: "book.closed", description: Text(errorMessage))
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .navigationTitle(detail?.name ?? item.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                PosterImage(url: URL(string: detail?.imageUrl ?? item.image ?? ""), cornerRadius: 22)
                    .frame(width: 126, height: 184)
                VStack(alignment: .leading, spacing: 9) {
                    Text(detail?.name ?? item.title)
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let author = detail?.author {
                        Label(author, systemImage: "person.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondary)
                    }
                    if let status = detail?.status {
                        Label(status, systemImage: "circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondary)
                    }
                    if let view = detail?.view ?? item.view {
                        Label(view, systemImage: "eye.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(4)
            }

            if let detail, !detail.genres.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(detail.genres.prefix(8), id: \.self) { genre in
                        Text(genre)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func chapterList(_ chapters: [MangaChapter]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            LazyVStack(spacing: 10) {
                ForEach(chapters) { chapter in
                    NavigationLink {
                        MangaReaderView(mangaId: item.detailId, chapter: chapter)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "book.pages.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.appleBlue)
                                .frame(width: 34, height: 34)
                                .background(.regularMaterial, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.name)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(chapter.createdAt ?? chapter.view ?? "Chapter")
                                    .font(.caption)
                                    .foregroundStyle(Theme.tertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.tertiary)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressScaleStyle())
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func loadDetail() async {
        guard detail == nil else { return }
        loading = true
        do {
            detail = try await client.detail(id: item.detailId)
        } catch {
            errorMessage = "Could not load chapters for this manga."
        }
        loading = false
    }
}

struct MangaReaderView: View {
    @EnvironmentObject private var appState: AppState
    let mangaId: String
    let chapter: MangaChapter
    @State private var detail: MangaChapterDetail?
    @State private var loading = true
    @State private var errorMessage: String?

    private var client: MangaKatanaClient { MangaKatanaClient(resolverBaseURL: appState.client.baseURL) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let detail {
                        ForEach(detail.images) { page in
                            AsyncImage(url: URL(string: page.image)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                default:
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 420)
                                        .overlay {
                                            ProgressView()
                                                .tint(.white)
                                        }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(.horizontal, 8)
                        }
                    } else if loading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 120)
                    } else if let errorMessage {
                        ContentUnavailableView("Chapter Unavailable", systemImage: "doc.richtext", description: Text(errorMessage))
                            .foregroundStyle(.white)
                            .padding(.top, 80)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(detail?.currentChapter ?? chapter.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await loadChapter() }
    }

    private func loadChapter() async {
        guard detail == nil else { return }
        loading = true
        do {
            detail = try await client.chapter(mangaId: mangaId, chapterId: chapter.id)
        } catch {
            errorMessage = "Could not load pages for this chapter."
        }
        loading = false
    }
}
