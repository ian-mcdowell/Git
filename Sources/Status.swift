import git2
import Foundation

internal typealias git_status_list = OpaquePointer

/// Git file status
/// - See: git2/status.h

/// Status flags for a single file.
/// - See: git_status_t
public struct Status: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let none = Status(rawValue: GIT_STATUS_CURRENT.rawValue)
    
    public static let indexNew = Status(rawValue: GIT_STATUS_INDEX_NEW.rawValue)
    public static let indexModified = Status(rawValue: GIT_STATUS_INDEX_MODIFIED.rawValue)
    public static let indexDeleted = Status(rawValue: GIT_STATUS_INDEX_DELETED.rawValue)
    public static let indexRenamed = Status(rawValue: GIT_STATUS_INDEX_RENAMED.rawValue)
    public static let indexTypeChanged = Status(rawValue: GIT_STATUS_INDEX_TYPECHANGE.rawValue)
    
    public static let workingDirectoryNew = Status(rawValue: GIT_STATUS_WT_NEW.rawValue)
    public static let workingDirectoryModified = Status(rawValue: GIT_STATUS_WT_MODIFIED.rawValue)
    public static let workingDirectoryDeleted = Status(rawValue: GIT_STATUS_WT_DELETED.rawValue)
    public static let workingDirectoryRenamed = Status(rawValue: GIT_STATUS_WT_RENAMED.rawValue)
    public static let workingDirectoryTypeChanged = Status(rawValue: GIT_STATUS_WT_TYPECHANGE.rawValue)
    
    public static let ignored = Status(rawValue: GIT_STATUS_IGNORED.rawValue)
    public static let conflicted = Status(rawValue: GIT_STATUS_CONFLICTED.rawValue)
    
    /// Flags to control status callbacks
    /// - See: git_status_opt_t
    public struct Options: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        
        /// Callbacks should be made on untracked files.  These will only be made if the workdir files are included in the status "show" option.
        public static let includeUntracked = Options(rawValue: GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue)
        /// Ignored files should get callbacks. Again, these callbacks will only be made if the workdir files are included in the status "show" option.
        public static let includeIgnored = Options(rawValue: GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue)
        /// Callback should be made even on unmodified files.
        public static let includeUnmodified = Options(rawValue: GIT_STATUS_OPT_INCLUDE_UNMODIFIED.rawValue)
        /// Submodules should be skipped.  This only applies if there are no pending typechanges to the submodule (either from or to another type).
        public static let excludeSubmodules = Options(rawValue: GIT_STATUS_OPT_EXCLUDE_SUBMODULES.rawValue)
        /// The given path should be treated as a literal path, and not as a pathspec pattern.
        public static let disablePathspecMatch = Options(rawValue: GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH.rawValue)
        /// All files in untracked directories should be included.  Normally if an entire directory is new, then just the top-level directory is included (with a trailing slash on the entry name).  This flag says to include all of the individual files in the directory instead.
        public static let recurseUntrackedDirectories = Options(rawValue: GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue)
        /// The contents of ignored directories should be included in the status.  This is like doing `git ls-files -o -i --exclude-standard` with core git.
        public static let recurseIgnoredDirectories = Options(rawValue: GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue)
        /// Rename detection should be processed between the head and the index and enables the GIT_STATUS_INDEX_RENAMED as a possible status flag.
        public static let renamesHeadToIndex = Options(rawValue: GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue)
        /// Rename detection should be run between the index and the working directory and enabled GIT_STATUS_WT_RENAMED as a possible status flag.
        public static let renamesIndexToWorkingDirectory = Options(rawValue: GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue)
        /// Overrides the native case sensitivity for the file system and forces the output to be in case-sensitive order
        public static let sortCaseSensitively = Options(rawValue: GIT_STATUS_OPT_SORT_CASE_SENSITIVELY.rawValue)
        /// Overrides the native case sensitivity for the file system and forces the output to be in case-insensitive order
        public static let sortCaseInsenstively = Options(rawValue: GIT_STATUS_OPT_SORT_CASE_INSENSITIVELY.rawValue)
        /// Rename detection should include rewritten files
        public static let renamesFromRewrites = Options(rawValue: GIT_STATUS_OPT_RENAMES_FROM_REWRITES.rawValue)
        /// Bypasses the default status behavior of doing a "soft" index reload (i.e. reloading the index data if the file on disk has been modified outside libgit2).
        public static let noRefresh = Options(rawValue: GIT_STATUS_OPT_NO_REFRESH.rawValue)
        /// Refresh the stat cache in the index for files that are unchanged but have out of date stat information in the index.  It will result in less work being done on subsequent calls to get status.  This is mutually exclusive with the NO_REFRESH option.
        public static let updateIndex = Options(rawValue: GIT_STATUS_OPT_UPDATE_INDEX.rawValue)
        public static let includeUnreadable = Options(rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE.rawValue)
        public static let includeUnreadableAsUntracked = Options(rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE_AS_UNTRACKED.rawValue)
    }
    
    /// Select the files on which to report status.
    /// - See: git_status_show_t
    public enum ShowOptions {
        
        /// Only gives status based on HEAD to index comparison, not looking at working directory changes.
        case index
        /// Only gives status based on index to working directory comparison, not comparing the index to the HEAD.
        case workingDirectory
        /// The default.
        case indexAndWorkingDirectory
        
        internal var showOptions: git_status_show_t {
            switch self {
            case .index: return GIT_STATUS_SHOW_INDEX_ONLY
            case .workingDirectory: return GIT_STATUS_SHOW_WORKDIR_ONLY
            case .indexAndWorkingDirectory: return GIT_STATUS_SHOW_INDEX_AND_WORKDIR
            }
        }
    }
}

/// A status entry, providing the differences between the file as it exists in HEAD and the index, and providing the differences between the index and the working directory.
/// - See: git2/status.h
public class StatusEntry {
    internal let entry: UnsafePointer<git_status_entry>
    
    internal init(entry: UnsafePointer<git_status_entry>) {
        self.entry = entry
    }

    /// Provides the status flags for this file
    public var status: Status {
        return Status(rawValue: entry.pointee.status.rawValue)
    }
    
    /// Provides detailed information about the differences between the file in HEAD and the file in the index.
    public var diffToIndex: DiffDelta? {
        if let diffToIndex = entry.pointee.head_to_index {
            return DiffDelta(delta: diffToIndex)
        }
        return nil
    }
    
    /// Provides detailed information about the differences between the file in the index and the file in the working directory.
    public var diffToWorkingDirectory: DiffDelta? {
        if let diffToWorkingDirectory = entry.pointee.index_to_workdir {
            return DiffDelta(delta: diffToWorkingDirectory)
        }
        return nil
    }
}

public class StatusList: Collection {
    public typealias Index = Int
    
    internal let list: git_status_list
    
    /// Options to control how `git_status_foreach_ext()` will issue callbacks.
    public struct Options {
        
        /// Control which files to scan and in what order.
        let show: Status.ShowOptions
        
        /// Options to apply to the operation
        let flags: Status.Options
        
        /// Array of path patterns to match, or just an array of paths to match exactly if pathspec matching is disabled.
        let pathspec: [String]?
        internal let pathspecStrArray: StrArray?
        
        public init(show: Status.ShowOptions = .indexAndWorkingDirectory, flags: Status.Options, pathspec: [String]? = nil) {
            self.show = show; self.flags = flags; self.pathspec = pathspec;
            if let pathspec = pathspec {
                self.pathspecStrArray = StrArray(pathspec)
            } else {
                self.pathspecStrArray = nil
            }
        }
    }
    
    public init(repository: Repository, options: Options? = nil) throws {
        var statusOptions = git_status_options.init()
        git_status_init_options(&statusOptions, UInt32(GIT_STATUS_OPTIONS_VERSION))
        
        
        if let options = options {
            statusOptions.show = options.show.showOptions
            statusOptions.flags = options.flags.rawValue
            if let pathspec = options.pathspecStrArray {
                statusOptions.pathspec = pathspec.strarray
            }
        }
        
        self.list = try git_try("create git status list for repository", { git_status_list_new($0, repository.repository, &statusOptions) })
    }

    deinit {
        git_status_list_free(list)
    }
    
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }
    public func index(after i: Int) -> Int { return i + 1 }
    
    /// Number of entries in the list.
    public var count: Int {
        return git_status_list_entrycount(list)
    }
    
    /// Retrieve the entry at a given index.
    public subscript(index: Int) -> StatusEntry {
        return StatusEntry(entry: git_status_byindex(list, index)!)
    }

}
