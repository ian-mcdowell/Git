import libgit2
import Foundation

/// A branch in a git repo.
/// - See: git2/branch.h
public class Branch: Reference {
    
    internal override init(reference: git_reference, repository: Repository) throws {
        try super.init(reference: reference, repository: repository)
    }
    
    public enum Location: Int {
        case local = 1
        case remote = 2
        
        fileprivate var branchType: git_branch_t {
            switch self {
            case .local:
                return GIT_BRANCH_LOCAL
            case .remote:
                return GIT_BRANCH_REMOTE
            }
        }
    }
    
    /// Retrieves the branch in the repository with the given name
    ///
    /// - Parameters:
    ///   - repository: repo the repository to look up the branch
    ///   - name: Name of the branch to be looked-up; this name is validated for consistency.
    ///   - type: Type of the considered branch.
    /// - See: git_branch_lookup
    public convenience init(repository: Repository, name: String, type: Branch.Location) throws {
        let reference = try git_try("lookup branch") { git_branch_lookup($0, repository.repository, name.cString(using: .utf8), type.branchType) }
        try self.init(reference: reference, repository: repository)
    }
    
    /// Create a new branch pointing at a target commit
    ///
    /// A new direct reference will be created pointing to this target commit. If `force` is true and a reference already exists with the given name, it'll be replaced.
    /// The branch name will be checked for validity.
    /// - See: git_branch_create
    public static func create(repository: Repository, name: String, commit: Commit, force: Bool = false) throws -> Branch {
        let reference = try git_try("create branch") { git_branch_create($0, repository.repository, name.cString(using: .utf8), commit.commit, force ? 1 : 0) }
        return try Branch(reference: reference, repository: repository)
    }
    
    /// Create a new branch pointing at a remote branch
    ///
    /// The branch name will be checked for validity.
    /// - See: git_reference_symbolic_create
    public static func create(repository: Repository, name: String, remoteBranch: Branch, force: Bool = false) throws -> Branch {
        let reference = try git_try("create local branch") { git_reference_create($0, repository.repository, ("refs/heads/" + name).cString(using: .utf8), &remoteBranch.oid.oid, force ? 1 : 0, []) }
        return try Branch(reference: reference, repository: repository)
    }
    
    /// The location of the branch, either local or remote
    public var location: Location {
        if self.isRemoteBranch {
            return .remote
        } else {
            return .local
        }
    }

    /// The name of the local or remote branch.
    /// - See: git_branch_name
    public var branchName: String? {
        do {
            let name = try git_try { git_branch_name($0, self.reference) }
            return String.init(cString: name)
        } catch {
            print("Unable to get name for branch: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Helper method: The branchName, without the first part of the path (if remote)
    public var shortBranchName: String? {
        var name = branchName
        if isRemoteBranch, let firstSlash = name?.index(of: "/"), let afterFirstSlash = name?.index(after: firstSlash) {
            name = String(name!.suffix(from: afterFirstSlash))
        }
        return name
    }
    
    /// Determine if the current local branch is pointed at by HEAD.
    /// - See: git_branch_is_head
    public var isHead: Bool {
        return git_branch_is_head(self.reference) == 1
    }
    
    /// The reference supporting the remote tracking branch, given that this is a local branch.
    /// - See: git_branch_upstream
    public var upstream: Branch? {
        get {
            if let branchRef = try? git_try { git_branch_upstream($0, self.reference) }, let branch = try? Branch(reference: branchRef, repository: self.repository) {
                return branch
            }
            return nil
        }
    }
    
    /// Set the reference supporting the remote tracking branch, given that this is a local branch.
    /// - See: git_branch_set_upstream
    public func setUpstream(_ upstream: Branch?) throws {
        let name: String?
        if let upstream = upstream, upstream.isRemoteBranch {
            name = upstream.name.replacingOccurrences(of: "refs/remotes/", with: "")
        } else {
            name = upstream?.shortBranchName
        }
        try git_try { git_branch_set_upstream(self.reference, name?.cString(using: .utf8)) }
    }
    
    /// The upstream configuration for the local branch
    /// - See: git_branch_upstream_name
    public var upstreamName: String? {
        get {
            if let data = try? git_try { git_branch_upstream_name($0, self.repository.repository, self.name.cString(using: .utf8)) } {
                return String.init(data: data, encoding: .utf8)
            }
            return nil
        }
    }
    
    public func setUpstreamName(_ upstreamName: String?) throws {
        try git_try { git_branch_set_upstream(self.reference, upstreamName?.cString(using: .utf8)) }
    }
    
    /// Return the name of remote that the remote tracking branch belongs to.
    /// - See: git_branch_remote_name
    public var remoteName: String? {
        if let data = try? git_try { git_branch_remote_name($0, self.repository.repository, self.name.cString(using: .utf8)) } {
            return String.init(data: data, encoding: .utf8)
        }

        return nil
    }
    
    /// Retrieve the name of the upstream remote of a local branch
    /// - See: git_branch_upstream_remote
    public var upstreamRemoteName: String? {
        if let data = try? git_try { git_branch_upstream_remote($0, self.repository.repository, self.name.cString(using: .utf8)) } {
            return String.init(data: data, encoding: .utf8)
        }
        
        return nil
    }

    /// Delete an existing branch reference.
    /// - See: git_branch_delete
    public func delete() throws {
        try git_try("delete branch") { git_branch_delete(self.reference) }
    }
    
    /// Move/rename an existing local branch reference
    ///
    /// The new branch name will be checked for validity.
    ///
    /// - Parameters:
    ///   - newName: Target name of the branch once the move is performed; this name is validated for consistency.
    ///   - force: Overwrite existing branch.
    /// - Returns: The renamed branch.
    /// - See: git_branch_move
    public func move(to newName: String, force: Bool = false) throws -> Branch {
        let reference = try git_try("move branch") { git_branch_move($0, self.reference, newName.cString(using: .utf8), force ? 1 : 0) }
        return try Branch(reference: reference, repository: self.repository)
    }
    
    /// The number of commits on the branch
    public var commitCount: Int {
        guard let revwalk = try? RevWalk(repository: self.repository, from: self.oid, to: nil) else {
            return 0
        }
        
        var count = 0
        while let _ = revwalk.next() {
            count += 1
        }
        return count
    }
    
    /// Commits on the branch. Caution: May be expensive to call.
    /// TODO: Paginate the results.
    public func commits() throws -> [Commit] {
        let revwalk = try RevWalk(repository: self.repository, from: self.oid, to: nil)
        
        var commits = [Commit]()
        while let oid = revwalk.next() {
            let commit = try Commit.init(repository: self.repository, oid: oid)
            commits.append(commit)
        }
        return commits
    }
    
    public func commits(relativeTo otherBranch: Branch) throws -> [Commit] {
        return []
    }
}

// MARK: Helpers
internal extension Branch {
    
    /// Iterates through all branches in a repository with the given type.
    /// - See: git_branch_iterator
    static func branches(inRepo repo: Repository, withType type: git_branch_t) -> [Branch] {
        var branches = [Branch]()
        do {
            let iterator = try git_try("create branch enumerator") { git_branch_iterator_new($0, repo.repository, type) }
            
            var branchType: git_branch_t = GIT_BRANCH_ALL
            while let branchRef = try? git_try { git_branch_next($0, &branchType, iterator) }, let branch = try? Branch(reference: branchRef, repository: repo) {
                branches.append(branch)
            }
            
            git_branch_iterator_free(iterator)
        } catch {
            return []
        }
        return branches
    }
}
