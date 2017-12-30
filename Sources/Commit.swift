import git2
import Foundation

internal typealias git_commit = OpaquePointer

/// A commit in a git repo.
/// - See: git2/commit.h
public class Commit {
    internal let commit: git_commit

    internal init(commit: git_commit) {
        self.commit = commit
    }
    
    deinit {
        git_commit_free(self.commit)
    }
    
    /// Lookup a commit object from a repository.
    ///
    /// - Parameters:
    ///   - repository: repo the repository to look up the branch
    ///   - oid: id of the commit to locate.
    /// - See: git_commit_lookup
    public convenience init(repository: Repository, oid: OID) throws {
        let commit = try git_try("lookup commit") { git_commit_lookup($0, repository.repository, &oid.oid) }
        self.init(commit: commit)
    }
    
    /// Create new commit in the repository
    /// - See: git_commit_create
    public static func create(repository: Repository, updateRef: String?, author: Signature, committer: Signature, messageEncoding: String, message: String, tree: Tree, parents: [Commit]) throws -> Commit {
        
        let parentCommits = UnsafeMutablePointer<git_commit?>.allocate(capacity: parents.count)
        for (i, parent) in parents.enumerated() {
            parentCommits.advanced(by: i).pointee = parent.commit
        }
        
        let oid = OID()
        try git_try("create commit in repository") { git_commit_create(&oid.oid, repository.repository, updateRef?.cString(using: .utf8), author.signature, committer.signature, messageEncoding.cString(using: .utf8), message.cString(using: .utf8), tree.tree, parents.count, parentCommits) }
        
        parentCommits.deallocate(capacity: parents.count)
        
        return try Commit(repository: repository, oid: oid)
    }
    
    /// Amend an existing commit by replacing only non-nil values
    /// - See: git_commit_amend
    public func amend(updateRef: String? = nil, author: Signature? = nil, committer: Signature? = nil, messageEncoding: String? = nil, message: String? = nil, tree: Tree? = nil) throws -> Commit {
        let oid = OID()
        try git_try("amend commit") { git_commit_amend(&oid.oid, self.commit, updateRef?.cString(using: .utf8), author?.signature, committer?.signature, messageEncoding?.cString(using: .utf8), message?.cString(using: .utf8), tree?.tree) }
        
        return try Commit(repository: repository, oid: oid)
    }
    
    /// Get the id of a commit.
    /// - See: git_commit_id
    public var oid: OID {
        return OID(oid: git_commit_id(self.commit))
    }
    
    /// Get the repository that contains the reference
    /// - See: git_commit_owner
    public var repository: Repository {
        let repository = git_commit_owner(self.commit)
        return Repository(repository: repository!)
    }
    
    /// Get the encoding for the message of a commit, as a string representing a standard encoding name.
    /// - See: git_commit_message_encoding
    public var messageEncoding: String {
        if let encoding = git_commit_message_encoding(self.commit) {
            return String.init(cString: encoding)
        }
        return "UTF-8"
    }
    
    /// Get the full message of a commit.
    /// The returned message will be slightly prettified by removing any potential leading newlines
    /// - See: git_commit_message
    public var message: String {
        if let message = git_commit_message(self.commit) {
            return String.init(cString: message)
        }
        return ""
    }
    
    /// Get the full raw message of a commit.
    /// - See: git_commit_message_raw
    public var rawMessage: String {
        if let message = git_commit_message_raw(self.commit) {
            return String.init(cString: message)
        }
        return ""
    }
    
    /// Get the short "summary" of the git commit message.
    /// The returned message is the summary of the commit, comprising the first paragraph of the message with whitespace trimmed and squashed.
    /// - See: git_commit_summary
    public var summary: String? {
        if let summary = git_commit_summary(self.commit) {
            return String.init(cString: summary)
        }
        return nil
    }
    
    /// Get the long "body" of the git commit message.
    /// The returned message is the body of the commit, comprising everything but the first paragraph of the message. Leading and trailing whitespaces are trimmed.
    /// - See: git_commit_body
    public var body: String? {
        if let body = git_commit_body(self.commit) {
            return String.init(cString: body)
        }
        return nil
    }
    
    /// Get the commit time (i.e. committer time) of a commit.
    /// - See: git_commit_time
    public var time: Date {
        return Date.init(timeIntervalSince1970: TimeInterval(git_commit_time(self.commit)))
    }
    
    /// Get the commit timezone offset (i.e. committer's preferred timezone) of a commit.
    /// - See: git_commit_time_offset
    public var timeZone: TimeZone {
        return TimeZone.init(secondsFromGMT: Int(git_commit_time_offset(self.commit) * 60))!
    }
    
    /// Get the committer of a commit.
    /// - See: git_commit_committer
    public var committer: Signature {
        let committer = git_commit_committer(self.commit)
        return Signature(signature: committer!)
    }
    
    /// Get the author of a commit.
    /// - See: git_commit_author
    public var author: Signature {
        let author = git_commit_author(self.commit)
        return Signature(signature: author!)
    }
    
    /// Get the full raw text of the commit header.
    /// - See: git_commit_raw_header
    public var rawHeader: String {
        return String.init(cString: git_commit_raw_header(self.commit))
    }
    
    /// Get the tree pointed to by a commit.
    /// - See: git_commit_tree
    public func tree() throws -> Tree {
        let tree = try git_try("get commit's tree") { git_commit_tree($0, self.commit) }
        return Tree(tree: tree)
    }
    
    /// Get the id of the tree pointed to by a commit. This differs from `git_commit_tree` in that no attempts are made to fetch an object from the ODB.
    /// - See: git_commit_tree_id
    public var treeID: OID? {
        if let oid = git_commit_tree_id(self.commit) {
            return OID(oid: oid)
        }
        return nil
    }
    
    /// Get the number of parents of this commit
    /// - See: git_commit_parentcount
    public var parentCount: UInt32 {
        return git_commit_parentcount(self.commit)
    }
    
    /// Get the specified parent of the commit.
    ///
    /// - Parameter index: the position of the parent (from 0 to `parentcount`)
    /// - See: git_commit_parent
    public func parent(atIndex index: UInt32 = 0) throws -> Commit {
        let commit = try git_try("git commit's parent") { git_commit_parent($0, self.commit, index) }
        return Commit(commit: commit)
    }
    
    /// Get the oid of a specified parent for a commit. This is different from `git_commit_parent`, which will attempt to load the parent commit from the ODB.
    ///
    /// - Parameter index: the position of the parent (from 0 to `parentcount`)
    /// - See: git_commit_parent
    public func parentID(atIndex index: UInt32 = 0) -> OID? {
        if let oid = git_commit_parent_id(self.commit, index) {
            return OID(oid: oid)
        }
        return nil
    }
    
    /// Get the commit object that is the <n>th generation ancestor of the named commit object, following only the first parents.
    /// Passing `0` as the generation number returns another instance of the base commit itself.
    ///
    /// - Parameter generation: the requested generation
    /// - See: git_commit_nth_gen_ancestor
    public func ancestor(generation: UInt32) throws -> Commit {
        let commit = try git_try("git commit's ancestor") { git_commit_nth_gen_ancestor($0, self.commit, generation) }
        return Commit(commit: commit)
    }
    
    /// Get an arbitrary header field
    /// - See: git_commit_header_field
    public func header(field: String) -> String? {
        if let data = try? git_try { git_commit_header_field($0, self.commit, field.cString(using: .utf8)) } {
            return String.init(data: data, encoding: .utf8)
        }
        return nil
    }
    
    /// Extract the signature from a commit
    /// - See: git_commit_extract_signature
    public func signature(field: String? = nil) -> Data? {
        var signed_data = git_buf()
        return try? git_try { git_commit_extract_signature($0, &signed_data, self.repository.repository, &self.oid.oid, field?.cString(using: .utf8)) }
    }
    
}
