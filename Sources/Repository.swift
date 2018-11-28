import libgit2
import Foundation

enum RepositoryError: LocalizedError {
    case unsupportedURL


    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            return "Unsupported URL"
        }
    }
}

internal typealias git_repository = OpaquePointer

/// Git repository management
/// - See: git2/repository.h
public class Repository {
    internal let repository: git_repository
    
    /// Keep a cache of all repositories open, so libgit2 can cache database calls, etc.
    /// This means that multiple `Repository` objects can point to the same git_repository.
    private static var Cache: [URL: git_repository] = [:]

    public convenience init(url: URL) throws {
        guard url.isFileURL, !url.path.isEmpty else {
            throw RepositoryError.unsupportedURL
        }
        
        if let repository = Repository.Cache[url] {
            self.init(repository: repository)
        } else {
            let repository = try git_try("open repository at URL: \(url.path)") { git_repository_open($0, url.path.cString(using: .utf8)) }
            
            Repository.Cache[url] = repository
            
            self.init(repository: repository)
        }
    }
    
    public enum CloneProgress {
        case fetch(progress: Double)
        case checkout(progress: Double)
    }
    @discardableResult
    public static func clone(from url: URL, to repositoryURL: URL, credentialProvider: @escaping CredentialProvider, progress: ((_ progress: CloneProgress) -> Void)? = nil) throws -> Repository {
        
        // Create a metadata object that will contain the fetch method and the provided credential.
        // This will be passed into the credentials block of the fetchOptions.
        // We can't just pass the CredentialProvider in, since the credential it produces must be retained
        // throughout the lifetime of the clone action.
        var credentialProviderMetadata = CredentialProviderMetadata(
            provider: credentialProvider,
            fetchProgress: { percent in
                progress?(.fetch(progress: percent))
            },
            checkoutProgress: { percent in
                progress?(.checkout(progress: percent))
            }
        )
        
        var options = git_clone_options.init()
        git_clone_init_options(&options, UInt32(GIT_CLONE_OPTIONS_VERSION))
        
        // Options for fetching
        var fetchOptions = git_fetch_options.init()
        git_fetch_init_options(&fetchOptions, UInt32(GIT_FETCH_OPTIONS_VERSION))

        fetchOptions.callbacks.credentials = { cred, url, usernameFromURL, allowedTypes, payload in
            
            guard
                let credentialProviderMetadata = payload?.assumingMemoryBound(to: CredentialProviderMetadata.self).pointee,
                let usernameFromURL = usernameFromURL
            else {
                giterr_set_str(GIT_EUSER.rawValue, "Unable to load credential metadata".cString(using: .utf8))
                return GIT_ERROR.rawValue
            }
            
            let username = String.init(cString: usernameFromURL)
            
            guard let credential = credentialProviderMetadata.credential(forUsername: username) else {
                giterr_set_str(GIT_EUSER.rawValue, "Unable to load credential from credential provider".cString(using: .utf8))
                return GIT_ERROR.rawValue
            }
            
            cred?.pointee = credential.cred
            print("Git: credentials requested.")
            return GIT_OK.rawValue
        }
        
        fetchOptions.callbacks.payload = UnsafeMutableRawPointer(&credentialProviderMetadata)
        
        fetchOptions.callbacks.transfer_progress = { stats, payload in
            print("Git: fetch transfer progressed.")
            
            if
                let metadata = payload?.assumingMemoryBound(to: CredentialProviderMetadata.self).pointee,
                let stats = stats?.pointee
            {
                let percent = Double(stats.received_objects) / Double(stats.total_objects)
                metadata.fetchProgress(percent)
            }
            
            return GIT_OK.rawValue
        }
        
        options.fetch_opts = fetchOptions
        
        // Options for checking out
        var checkoutOptions = git_checkout_options.init()
        git_checkout_init_options(&checkoutOptions, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        checkoutOptions.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue
        
        checkoutOptions.progress_payload = UnsafeMutableRawPointer(&credentialProviderMetadata)
        checkoutOptions.progress_cb = { path, completed, total, payload in
            print("Git: checkout progressed. \(completed) / \(total)")
            
            if let metadata = payload?.assumingMemoryBound(to: CredentialProviderMetadata.self).pointee {
                let percent = Double(completed) / Double(total)
                metadata.checkoutProgress(percent)
            }
        }
        
        checkoutOptions.notify_cb = { why, path, baseline, target, workdir, payload in
            print("Git: checkout notified.")
            return GIT_OK.rawValue
        }
        checkoutOptions.notify_flags = GIT_CHECKOUT_NOTIFY_NONE.rawValue

        options.checkout_opts = checkoutOptions
        
        // Get the remote URL
        let remotePath: String
        if url.isFileURL {
            remotePath = url.standardizedFileURL.path
        } else {
            remotePath = url.absoluteString
        }
        
        let repository = try git_try("clone repository") { git_clone($0, remotePath.cString(using: .utf8), repositoryURL.path.cString(using: .utf8), &options) }
        
        return Repository(repository: repository)
    }
    
    @discardableResult
    public static func create(at url: URL) throws -> Repository {
        guard url.isFileURL, !url.path.isEmpty else {
            throw RepositoryError.unsupportedURL
        }
        
        let repository = try git_try("create repository at URL: \(url.path)") { git_repository_init($0, url.path.cString(using: .utf8), 0) }

        return Repository(repository: repository)
    }
    
    internal init(repository: git_repository) {
        self.repository = repository
    }
    
    /// Get the path of the working directory for this repository
    /// If the repository is bare, this will be nil.
    /// - See: git_repository_workdir
    public var workingDirectory: URL? {
        if let workdir = git_repository_workdir(self.repository) {
            return URL(fileURLWithPath: String(cString: workdir))
        }
        return nil
    }
    
    /// Retrieve and resolve the reference pointed at by HEAD.
    /// - See: git_repository_head
    public var head: Reference? {
        if let head = try? git_try { git_repository_head($0, self.repository) } {
            return try? Reference(reference: head, repository: self)
        }
        return nil
    }
}

extension Repository: Equatable {
    public static func ==(a: Repository, b: Repository) -> Bool {
        return a.workingDirectory == b.workingDirectory
    }
}

// MARK: Branches
/// - See: git2/branch.h
public extension Repository {
    /// A list of the local and remote branches
    public var branches: [Branch] {
        return Branch.branches(inRepo: self, withType: GIT_BRANCH_ALL)
    }
    
    /// A list of the local branches
    public var localBranches: [Branch] {
        return Branch.branches(inRepo: self, withType: GIT_BRANCH_LOCAL)
    }
    
    /// A list of the remote branches
    public var remoteBranches: [Branch] {
        return Branch.branches(inRepo: self, withType: GIT_BRANCH_REMOTE)
    }
}

// MARK: Remotes
/// - See: git2/remote.h
public extension Repository {
    public var remotes: [Remote] {
        do {
            var list = git_strarray.init()
            try git_try("retrieve remote list") { git_remote_list(&list, self.repository) }
            var remotes: [Remote] = []
            for i in 0..<list.count {
                if let str = list.strings.advanced(by: i).pointee {
                    remotes.append(try Remote(repository: self, name: String(cString: str)))
                }
            }
            return remotes
        } catch {
            return []
        }
    }
}

public extension Repository {
    
    func aheadBehind(local: OID, upstream: OID) -> (ahead: Int, behind: Int) {
        var ahead: Int = 0
        var behind: Int = 0
        git_graph_ahead_behind(&ahead, &behind, self.repository, &local.oid, &upstream.oid)
        return (ahead, behind)
    }
    
    /// Returns an array of commits from
    func uniqueCommits(from: OID, to: OID) throws -> [Commit] {
        
        let revwalk = try RevWalk(repository: self, from: from, to: to)
        
        var commits: [Commit] = []
        
        while let oid = revwalk.next() {
            commits.append(try Commit.init(repository: self, oid: oid))
        }
    
        return commits
    }

}

// MARK: Index
public extension Repository {
    
    func index() throws -> Index {
        let index = try git_try("get index for the repository") { git_repository_index($0, self.repository) }
        return Index(index: index)
    }
}

// MARK: Status
/// - See: git2/status.h
public extension Repository {
    
    /// Get file status for a single file.
    ///
    /// - Parameter file: The repository-relative path of a file in the repository
    /// - Returns: Status OptionSet that describes the file's status
    /// - See: git_status_file
    func status(forFile path: String) throws -> Status {
        var status: UInt32 = 0
        try git_try("get status for file \"\(path)\"", { git_status_file(&status, self.repository, path.cString(using: .utf8)) })
        return Status(rawValue: status)
    }
    
    /// Test if the ignore rules apply to a given file.
    ///
    /// This function checks the ignore rules to see if they would apply to the given file.
    /// This indicates if the file would be ignored regardless ofwhether the file is already in the index or committed to the repository.
    ///
    /// One way to think of this is if you were to do "git add ." on the directory containing the file, would it be added or not?
    ///
    /// - Parameter file: The URL of a file in the repository
    /// - See: git_status_should_ignore
    func ignoreRulesApply(toFile file: URL) throws -> Bool {
        var ignored: Int32 = 0
        try git_try("get ignore status for file \"\(file.lastPathComponent)\"", { git_status_should_ignore(&ignored, self.repository, file.absoluteString.cString(using: .utf8)) })
        return ignored == 1
    }
}

// MARK: Reset
/// - See: git2/reset.h
public extension Repository {
    
    /// Kinds of reset operation
    public enum ResetType {
        /// Move the head to the given commit
        case soft
        /// soft plus reset the index to the commit
        case mixed
        /// mixed plus changes in the working tree are discarded
        case hard
        
        internal var resetType: git_reset_t {
            switch self {
            case .soft: return GIT_RESET_SOFT
            case .mixed: return GIT_RESET_MIXED
            case .hard: return GIT_RESET_HARD
            }
        }
    }
    
    /// Sets the current head to the specified commit oid and optionally resets the index and working tree to match.
    /// - See: git_reset
    func reset(toCommit commit: Commit, type: ResetType) throws {
        var options = git_checkout_options.init()
        git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        
        try git_try("reset to commit") { git_reset(self.repository, commit.commit, type.resetType, &options) }
    }
    
    /// Updates some entries in the index from the target commit tree.
    /// The scope of the updated entries is determined by the paths being passed in the `pathspec` parameters.
    ///
    /// Passing a nil commit will result in removing entries in the index matching the provided pathspecs.
    ///
    /// - See: git_reset_default
    func reset(pathspecs: [String], toCommit commit: Commit?) throws {
        let paths = StrArray(pathspecs)
        try git_try("reset pathspecs to commit") { git_reset_default(self.repository, commit?.commit, &paths.strarray) }
    }
}

// MARK: Checkout
/// - See: git2/checkout.h
public extension Repository {
    
    public struct CheckoutOptions {
        
        var strategy: Strategy
        var paths: [String]? {
            didSet {
                if let paths = paths {
                    pathsStrArray = StrArray(paths)
                } else {
                    pathsStrArray = nil
                }
            }
        }
        private var pathsStrArray: StrArray?
        
        public struct Strategy: OptionSet {
            public let rawValue: UInt32
            public init(rawValue: UInt32) { self.rawValue = rawValue }
            
            /// Default value. A dry run. No actual updates
            public static let none = Strategy(rawValue: GIT_CHECKOUT_NONE.rawValue)
            /// Allow safe updates that cannot overwrite uncommitted data
            public static let safe = Strategy(rawValue: GIT_CHECKOUT_SAFE.rawValue)
            /// Allow all updates to force working directory to look like index
            public static let force = Strategy(rawValue: GIT_CHECKOUT_FORCE.rawValue)
            /// Allow checkout to recreate missing files
            public static let recreateMissingFiles = Strategy(rawValue: GIT_CHECKOUT_RECREATE_MISSING.rawValue)
            /// Allow checkout to make safe updates even if conflicts are found
            public static let allowConflicts = Strategy(rawValue: GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue)
            /// Remove untracked files not in index (that are not ignored)
            public static let removeUntracked = Strategy(rawValue: GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue)
            /// Remove ignored files that are not in index
            public static let removeIgnored = Strategy(rawValue: GIT_CHECKOUT_REMOVE_IGNORED.rawValue)
            /// Only update existing files, don't create new ones
            public static let updateOnly = Strategy(rawValue: GIT_CHECKOUT_UPDATE_ONLY.rawValue)
            /// Normally checkout updates index entries as it goes; this stops that. Implies `GIT_CHECKOUT_DONT_WRITE_INDEX`.
            public static let dontUpdateIndex = Strategy(rawValue: GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue)
            /// Don't refresh index/config/etc before doing checkout
            public static let noRefresh = Strategy(rawValue: GIT_CHECKOUT_NO_REFRESH.rawValue)
            /// Allow checkout to skip unmerged files
            public static let skipUnmerged = Strategy(rawValue: GIT_CHECKOUT_SKIP_UNMERGED.rawValue)
            /// For unmerged files, checkout stage 2 from index
            public static let useOurs = Strategy(rawValue: GIT_CHECKOUT_USE_OURS.rawValue)
            /// For unmerged files, checkout stage 3 from index
            public static let useTheirs = Strategy(rawValue: GIT_CHECKOUT_USE_THEIRS.rawValue)
            /// Treat pathspec as simple list of exact match file paths
            public static let disablePathspecMatch = Strategy(rawValue: GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH.rawValue)
            /// Ignore directories in use, they will be left empty
            public static let skipLockedDirectories = Strategy(rawValue: GIT_CHECKOUT_SKIP_LOCKED_DIRECTORIES.rawValue)
            /// Don't overwrite ignored files that exist in the checkout target
            public static let dontOverwriteIgnored = Strategy(rawValue: GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue)
            /// Write normal merge files for conflicts
            public static let conflictStyleMerge = Strategy(rawValue: GIT_CHECKOUT_CONFLICT_STYLE_MERGE.rawValue)
            /// Include common ancestor data in diff3 format files for conflicts
            public static let conflictStyleDiff3 = Strategy(rawValue: GIT_CHECKOUT_CONFLICT_STYLE_DIFF3.rawValue)
            /// Don't overwrite existing files and folders
            public static let dontRemoveExisting = Strategy(rawValue: GIT_CHECKOUT_DONT_REMOVE_EXISTING.rawValue)
            /// Normally checkout writes the index upon completion; This prevents that.
            public static let dontWriteIndex = Strategy(rawValue: GIT_CHECKOUT_DONT_WRITE_INDEX.rawValue)
            
            // updateSubmodules : Not implemented
            // updateSubmodulesIfChanged : Not implemented
        }
        
        public init(strategy: Strategy = .none, paths: [String]? = nil) {
            self.strategy = strategy; self.paths = paths;
            if let paths = paths {
                self.pathsStrArray = StrArray(paths)
            }
        }
        
        internal var options: git_checkout_options {
            var options = git_checkout_options.init()
            git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
            
            options.checkout_strategy = strategy.rawValue
            if let paths = pathsStrArray {
                options.paths = paths.strarray
            }
            
            return options
        }
    }
    
    func checkout(reference: Reference, options: CheckoutOptions) throws {
        let obj = try reference.peel()
        var checkoutOptions = options.options
        
        try git_try("checkout tree") { git_checkout_tree(self.repository, obj, &checkoutOptions)}
        try git_try("move head") { git_repository_set_head(self.repository, reference.name.cString(using: .utf8)) }
    }
    
    /// Updates files in the index and the working tree to match the content of the commit pointed at by HEAD.
    /// - See: git_checkout_head
    func checkoutHead(options: CheckoutOptions) throws {
        var checkoutOptions = options.options
        
        try git_try("checkout HEAD") { git_checkout_head(self.repository, &checkoutOptions) }
    }
}
