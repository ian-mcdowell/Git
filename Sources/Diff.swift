import git2
import Foundation

internal typealias git_diff = OpaquePointer

public class Diff {
    
    /// Structure describing options about how the diff should be executed.
    /// - See: git_diff_options
    public struct Options {
        
        public init() {}
        
        internal var options: git_diff_options {
            var options = git_diff_options.init()
            git_diff_init_options(&options, UInt32(GIT_DIFF_OPTIONS_VERSION))
            return options
        }
    }
    
    internal let diff: git_diff
    
    internal init(diff: git_diff) {
        self.diff = diff
    }
    
    
    /// Create a diff with the difference between two tree objects.
    /// The first tree will be used for the "old_file" side of the delta and the second tree will be used for the "new_file" side of the delta.  You can pass NULL to indicate an empty tree, although it is an error to pass NULL for both the `old_tree` and `new_tree`.
    /// - See: git_diff_tree_to_tree
    public convenience init(repository: Repository, oldTree: Tree?, newTree: Tree?, options: Options) throws {
        assert(oldTree != nil || newTree != nil, "Either oldTree or newTree must be provided.")
        var options = options.options
        
        let diff = try git_try("diff tree to tree") { git_diff_tree_to_tree($0, repository.repository, oldTree?.tree, newTree?.tree, &options) }
        self.init(diff: diff)
    }
    
    /// Create a diff between a tree and repository index.
    /// This is equivalent to `git diff --cached <treeish>` or if you pass the HEAD tree, then like `git diff --cached`.
    /// The tree you pass will be used for the "old_file" side of the delta, and the index will be used for the "new_file" side of the delta.
    /// If you pass NULL for the index, then the existing index of the `repo` will be used.  In this case, the index will be refreshed from disk (if it has changed) before the diff is generated.
    /// - See: git_diff_tree_to_index
    public convenience init(repository: Repository, oldTree: Tree, index: Index?, options: Options) throws {
        var options = options.options
        
        let diff = try git_try("diff tree to index") { git_diff_tree_to_index($0, repository.repository, oldTree.tree, index?.index, &options) }
        self.init(diff: diff)
    }
    
    // TODO: Other init
    // TODO: get deltas
    
    public func deltas() throws -> [DiffDelta] {
        return [] // TODO
    }
}

/// Description of changes to one entry.
/// - See: git2/diff.h
public class DiffDelta {

    public enum Status: UInt32 {
        case unmodified
        case added
        case deleted
        case modified
        case renamed
        case copied
        case ignored
        case untracked
        case typeChange
        case unreadable
        case conflicted
        
        internal static func fromStatus(_ status: git_delta_t) -> Status {
            switch status {
            case GIT_DELTA_UNMODIFIED: return .unmodified
            case GIT_DELTA_ADDED: return .added
            case GIT_DELTA_DELETED: return .deleted
            case GIT_DELTA_MODIFIED: return .modified
            case GIT_DELTA_RENAMED: return .renamed
            case GIT_DELTA_COPIED: return .copied
            case GIT_DELTA_IGNORED: return .ignored
            case GIT_DELTA_UNTRACKED: return .untracked
            case GIT_DELTA_TYPECHANGE: return .typeChange
            case GIT_DELTA_UNREADABLE: return .unreadable
            case GIT_DELTA_CONFLICTED: return .conflicted
            default:
                fatalError("Unhandled git_delta_t in Status.fromStatus(_:)")
            }
        }
    }
    internal let delta: UnsafePointer<git_diff_delta>

    internal init(delta: UnsafePointer<git_diff_delta>) {
        self.delta = delta
    }
    
    public var status: Status {
        return Status.fromStatus(delta.pointee.status)
    }
    
    public var newFile: DiffFile {
        return DiffFile(file: delta.pointee.new_file)
    }
    
    public var oldFile: DiffFile {
        return DiffFile(file: delta.pointee.old_file)
    }
    // flags
    // similarity
    // nfiles
}

/// Description of one side of a delta.
/// - See: git2/diff.h
public class DiffFile {
    internal let file: git_diff_file

    internal init(file: git_diff_file) {
        self.file = file
    }

    public var id: OID {
        return OID(oid: self.file.id)
    }
    
    public var path: String? {
        if let path = self.file.path {
            return String(cString: path)
        }
        return nil
    }
    
    // size: git_off_t
    // flags
    // mode
    // id_abbrev
}
