//
//  SearchComponents.swift
//  writepulp
//

import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let onClear: () -> Void
    var placeholder: LocalizedStringKey = "search_placeholder"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isFocused.wrappedValue ? AppColors.primary : AppPalette.appLightGray)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(AppPalette.appLightGray))
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .foregroundStyle(AppColors.onSurface)
            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppPalette.appLightGray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isFocused.wrappedValue ? AppColors.primary : AppColors.outline, lineWidth: isFocused.wrappedValue ? 2 : 1)
        }
    }
}

struct SearchTypeChips: View {
    let types: [SearchType]
    let selection: SearchType
    let onSelect: (SearchType) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.self) { type in
                    FilterChip(title: Text(type.title), isSelected: type == selection) { onSelect(type) }
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let item: SearchResultItem

    var body: some View {
        Group {
            if item.type == .user {
                user
            } else {
                publication
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private var user: some View {
        HStack(spacing: 16) {
            Avatar(imagePath: item.imageUrl, name: item.title, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.onSurface)
                if let subTitle = item.subTitle {
                    Text(subTitle)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
            }
        }
    }

    private var publication: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: AppEnvironment.imageURL(item.imageUrl)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    PlaceholderColor.color(for: item.title)
                        .overlay {
                            Text(item.title.prefix(1).uppercased())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
            }
            .frame(width: 90, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subTitle = item.subTitle {
                    Text("by".localized(subTitle))
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                if let count = item.reviewCount {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundStyle(Color(hex: 0xFFB400))
                        Text(String(format: "%.1f", item.review ?? 0)).fontWeight(.bold)
                        Text("reviews".localized(count)).foregroundStyle(AppColors.onSurfaceVariant)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.onSurface)
                }
                if let categories = item.categories, !categories.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.onSurface)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.primaryContainer.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
    }
}

/// A parent category (tap opens it) with its subcategories as a two-column grid.
struct CategoryGroupCard: View {
    let group: CategoryGroup
    let onSelect: (CategoryGroup.Category) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onSelect(group.parent) } label: {
                HStack(spacing: 12) {
                    if let icon = Self.icon(for: group.parent.translationKey) {
                        Image(icon).resizable().scaledToFit().frame(width: 24, height: 24)
                    }
                    Text(group.parent.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.onSurface)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.onSurface)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())

            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                ForEach(group.subCategories, id: \.identity) { category in
                    Button { onSelect(category) } label: {
                        Text(category.name)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.onSurface)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private static func icon(for translationKey: String?) -> String? {
        switch translationKey {
        case "category.fiction": "Category_fiction"
        case "category.academic": "Category_academic"
        case "category.tech.business": "Category_tech_business"
        case "category.lifestyle": "Category_lifestyle"
        case "category.arts.literature": "Category_arts_literature"
        case "category.society.culture": "Category_society_culture"
        case "category.education.reference": "Category_education_reference"
        case "category.journalism.perspectives": "Category_journalism_perspectives"
        default: nil
        }
    }
}
