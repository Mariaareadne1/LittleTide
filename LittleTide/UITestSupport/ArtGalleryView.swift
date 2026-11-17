#if DEBUG
import SwiftUI
import TideKit
import TideUI

/// DEBUG-only: every coast region at low and high water, for art direction review.
///     -LTArtGallery [page]
struct ArtGalleryView: View {
    let regions: [CoastRegion]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(regions, id: \.self) { region in
                HStack(spacing: 6) {
                    CoastArtView(region: region, waterLevel: 0.05)
                    CoastArtView(region: region, waterLevel: 0.95)
                }
                .frame(height: 190)
                .overlay(alignment: .topLeading) {
                    Text(region.rawValue).font(.caption2.bold()).padding(4).background(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 4)
        .ignoresSafeArea(edges: .bottom)
    }

    static func make(arguments: [String]) -> ArtGalleryView? {
        guard let index = arguments.firstIndex(of: "-LTArtGallery") else { return nil }
        let page = index + 1 < arguments.count ? Int(arguments[index + 1]) ?? 0 : 0
        let all = CoastRegion.allCases
        return ArtGalleryView(regions: Array(all.dropFirst(page * 4).prefix(4)))
    }
}
#endif
