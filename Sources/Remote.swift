import git2
import Foundation

internal typealias git_remote = OpaquePointer

/// Git remote
/// - See: git2/remote.h
public class Remote {
    internal let remote: git_remote
    /// Get the repository that contains the remote
    public var repository: Repository

    internal init(remote: git_remote, repository: Repository) {
        self.remote = remote
        self.repository = repository
    }
    
    public convenience init(repository: Repository, name: String) throws {
        let remote = try git_try("lookup remote") { git_remote_lookup($0, repository.repository, name.cString(using: .utf8)) }
        self.init(remote: remote, repository: repository)
    }
    
    /// Create a new remote in the repository.
    /// - See: git_remote_create
    public static func create(repository: Repository, name: String, url: URL) throws -> Remote {
        let remote = try git_try("create remote") { git_remote_create($0, repository.repository, name.cString(using: .utf8), url.absoluteString.cString(using: .utf8)) }
        return Remote(remote: remote, repository: repository)
    }
    
    deinit {
        git_remote_free(self.remote)
    }
    
    /// Get the remote's name
    /// - See: git_remote_name, git_remote_rename
    public var name: String {
        get {
            if let name = git_remote_name(self.remote) {
                return String(cString: name)
            }
            return ""
        }
        set {
            var problematic_pathspecs = git_strarray.init()
            try? git_try("rename remote") { git_remote_rename(&problematic_pathspecs, self.repository.repository, self.name.cString(using: .utf8), name.cString(using: .utf8)) }
            git_strarray_free(&problematic_pathspecs)
        }
    }
    
    /// Get the remote's url
    /// - See: git_remote_url, git_remote_set_url
    public var url: URL {
        get {
            // Potentially unsafe. Two nil checks missed here
            return URL(string: String(cString: git_remote_url(self.remote)))!
        }
        set {
            try? git_try { git_remote_set_url(self.repository.repository, self.name.cString(using: .utf8), url.absoluteString.cString(using: .utf8)) }
        }
    }
    
    /// Get the remote's push url
    /// - See: git_remote_pushurl
    public var pushURL: URL? {
        get {
            if let url = git_remote_pushurl(self.remote) {
                let str = String(cString: url)
                return URL(string: str)
            }
            return nil
        }
        set {
            try? git_try { git_remote_set_pushurl(self.repository.repository, self.name.cString(using: .utf8), pushURL?.absoluteString.cString(using: .utf8)) }
        }
    }
}

extension Remote: Equatable {
    
    public static func ==(a: Remote, b: Remote) -> Bool {
        return a.repository == b.repository && a.name == b.name && a.url == b.url
    }
}
