//
//  GroupsService.swift
//  writepulp
//

import Foundation

enum GroupsAPI {
    static func explore(page: Int, size: Int = 20) -> Endpoint<Page<CommunityGroup>> {
        Endpoint(path: "community/explore", query: pageQuery(page, size))
    }

    static func mine(page: Int, size: Int = 20) -> Endpoint<Page<CommunityGroup>> {
        Endpoint(path: "community/me", query: pageQuery(page, size))
    }

    static func owned() -> Endpoint<[CommunityGroup]> {
        Endpoint(path: "community/owned")
    }

    static func search(_ query: String, page: Int, size: Int = 20) -> Endpoint<Page<CommunityGroup>> {
        Endpoint(path: "community/search", query: [URLQueryItem(name: "query", value: query)] + pageQuery(page, size))
    }

    static func preview(id: String) -> Endpoint<CommunityGroup> {
        Endpoint(path: "community/\(id)/preview")
    }

    static func detail(id: String) -> Endpoint<GroupDetail> {
        Endpoint(path: "community/\(id)/detail")
    }

    static func join(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "community/\(id)/join", method: .post)
    }

    static func withdrawRequest(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "community/join-request/\(id)", method: .delete)
    }

    static func leave(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "community/\(id)/leave", method: .delete)
    }

    static func delete(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "community/\(id)", method: .delete)
    }

    static func create(_ form: GroupForm) -> Endpoint<String> {
        Endpoint(path: "community", method: .post, body: form)
    }

    static func update(id: String, _ form: GroupForm) -> Endpoint<String> {
        Endpoint(path: "community/\(id)", method: .put, body: form)
    }

    // MARK: Members

    static func members(id: String, page: Int, size: Int = 20) -> Endpoint<Page<GroupMember>> {
        Endpoint(path: "community/\(id)/members", query: pageQuery(page, size))
    }

    static func kick(id: String, userId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "community/\(id)/kick/\(userId)", method: .delete)
    }

    static func bulkRemove(id: String, userIds: [String]) -> Endpoint<EmptyResponse> {
        Endpoint(path: "community/\(id)/members/bulk-remove", method: .post, body: BulkRemoveRequest(userIds: userIds))
    }

    static func updateRole(id: String, userId: String, role: GroupRole) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "community/\(id)/role/\(userId)",
            method: .patch,
            query: [URLQueryItem(name: "newRole", value: role.rawValue)]
        )
    }

    // MARK: Join requests

    static func requests(id: String, page: Int, size: Int = 20) -> Endpoint<Page<GroupJoinRequest>> {
        Endpoint(path: "community/requests/\(id)/list", query: pageQuery(page, size))
    }

    static func handleRequest(requestId: String, accept: Bool) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "community/requests/\(requestId)/handle",
            method: .post,
            query: [URLQueryItem(name: "accept", value: String(accept))]
        )
    }

    static func handleRequests(id: String, requestIds: [String], approve: Bool) -> Endpoint<EmptyResponse> {
        Endpoint(
            path: "community/requests/\(id)/bulk-handle",
            method: .post,
            body: BulkHandleRequestsRequest(requestIds: requestIds, approve: approve)
        )
    }

    // MARK: Messages

    static func history(groupId: String, page: Int, size: Int = 50) -> Endpoint<Page<GroupMessage>> {
        Endpoint(
            path: "messages/community/\(groupId)/history",
            query: pageQuery(page, size) + [URLQueryItem(name: "sort", value: "sentAt,desc")]
        )
    }

    static func send(groupId: String, _ request: SendGroupMessageRequest) -> Endpoint<String> {
        Endpoint(path: "messages/community/\(groupId)/send", method: .post, body: request)
    }

    static func deleteMessage(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "messages/community/message/\(id)", method: .delete)
    }

    static func markAsRead(groupId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "messages/community/\(groupId)/read-all", method: .post)
    }

    private static func pageQuery(_ page: Int, _ size: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "size", value: String(size))]
    }
}

@MainActor
final class GroupsService {
    private let api: APIClient
    private let session: SessionStore
    let socket: StompClient

    nonisolated init(api: APIClient, session: SessionStore, socket: StompClient) {
        self.api = api
        self.session = session
        self.socket = socket
    }

    var currentUserId: String? { session.userId }

    func explore(page: Int) async throws -> Page<CommunityGroup> {
        try await api.send(GroupsAPI.explore(page: page))
    }

    func mine(page: Int) async throws -> Page<CommunityGroup> {
        try await api.send(GroupsAPI.mine(page: page))
    }

    func owned() async throws -> [CommunityGroup] {
        try await api.send(GroupsAPI.owned())
    }

    func search(_ query: String, page: Int) async throws -> Page<CommunityGroup> {
        try await api.send(GroupsAPI.search(query, page: page))
    }

    func preview(id: String) async throws -> CommunityGroup {
        try await api.send(GroupsAPI.preview(id: id))
    }

    func detail(id: String) async throws -> GroupDetail {
        try await api.send(GroupsAPI.detail(id: id))
    }

    func join(id: String) async throws {
        _ = try await api.send(GroupsAPI.join(id: id))
    }

    func withdrawRequest(id: String) async throws {
        _ = try await api.send(GroupsAPI.withdrawRequest(id: id))
    }

    func leave(id: String) async throws {
        _ = try await api.send(GroupsAPI.leave(id: id))
    }

    func delete(id: String) async throws {
        _ = try await api.send(GroupsAPI.delete(id: id))
    }

    func create(_ form: GroupForm) async throws -> String {
        try await api.send(GroupsAPI.create(form))
    }

    func update(id: String, _ form: GroupForm) async throws {
        _ = try await api.send(GroupsAPI.update(id: id, form))
    }

    func categoryGroups() async throws -> [CategoryGroup] {
        try await api.send(CategoryAPI.grouped())
    }

    // MARK: Members

    func members(id: String, page: Int) async throws -> Page<GroupMember> {
        try await api.send(GroupsAPI.members(id: id, page: page))
    }

    func kick(id: String, userId: String) async throws {
        _ = try await api.send(GroupsAPI.kick(id: id, userId: userId))
    }

    func bulkRemove(id: String, userIds: [String]) async throws {
        _ = try await api.send(GroupsAPI.bulkRemove(id: id, userIds: userIds))
    }

    func updateRole(id: String, userId: String, role: GroupRole) async throws {
        _ = try await api.send(GroupsAPI.updateRole(id: id, userId: userId, role: role))
    }

    // MARK: Join requests

    func requests(id: String, page: Int) async throws -> Page<GroupJoinRequest> {
        try await api.send(GroupsAPI.requests(id: id, page: page))
    }

    func handleRequest(requestId: String, accept: Bool) async throws {
        _ = try await api.send(GroupsAPI.handleRequest(requestId: requestId, accept: accept))
    }

    func handleRequests(id: String, requestIds: [String], approve: Bool) async throws {
        _ = try await api.send(GroupsAPI.handleRequests(id: id, requestIds: requestIds, approve: approve))
    }

    // MARK: Messages

    func history(groupId: String, page: Int) async throws -> Page<GroupMessage> {
        try await api.send(GroupsAPI.history(groupId: groupId, page: page))
    }

    /// Over the socket when it's up (the message comes back on the group topic), else over REST.
    /// Returns true when the caller must refetch to see it.
    func send(groupId: String, _ request: SendGroupMessageRequest) async throws -> Bool {
        if await socket.send(destination: "/app/chat.sendGroupMessage/\(groupId)", body: request) {
            return false
        }
        _ = try await api.send(GroupsAPI.send(groupId: groupId, request))
        return true
    }

    func deleteMessage(id: String) async throws {
        _ = try await api.send(GroupsAPI.deleteMessage(id: id))
    }

    func markAsRead(groupId: String) async {
        _ = try? await api.send(GroupsAPI.markAsRead(groupId: groupId))
    }

    /// `.group` for chat images, `.icon` for community avatars.
    func uploadImage(_ jpeg: Data, type: ImageUploadType = .group) async throws -> String {
        let result = try await api.send(ImageUploadAPI.upload(jpeg: jpeg, type: type))
        guard let path = result["filePath"] else { throw APIError.invalidResponse }
        return path
    }
}
