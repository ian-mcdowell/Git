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
    
    deinit {
        git_remote_free(self.remote)
    }
    
    /// Get the remote's name
    /// - See: git_remote_name
    public var name: String {
        if let name = git_remote_name(self.remote) {
            return String(cString: name)
        }
        return ""
    }
    
    /// Get the remote's url
    /// - See: git_remote_url
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
