import git2
import Foundation

internal typealias git_index = OpaquePointer

/// Git index parsing and manipulation
/// - See: git2/index.h
public class Index {
    internal let index: git_index

    internal init(index: git_index) {
        self.index = index
    }
    
    deinit {
        git_index_free(self.index)
    }
    
    public var repository: Repository {
        let repository = git_index_owner(self.index)
        
        return Repository(repository: repository!)
    }
    
    /// Adds a file at the given repository-relative path to the index
    ///
    /// - Parameter path: Path relative to root of git repo
    /// - See: git_index_add_bypath
    public func addFile(at path: String) throws {
        try git_try("add file at \"\(path)\" to index") { git_index_add_bypath(self.index, path.cString(using: .utf8)) }
    }
    
    public func write() throws {
        try git_try("write index") { git_index_write(self.index) }
    }
}

// MARK: Tree
public extension Index {
    
    @discardableResult
    func writeTree() throws -> Tree {

        let oid = OID()
        try git_try("write tree") { git_index_write_tree(&oid.oid, self.index) }
    
        let tree = try git_try("find written tree") { git_tree_lookup($0, self.repository.repository, &oid.oid) }
        
        return Tree(tree: tree)
    }
}
