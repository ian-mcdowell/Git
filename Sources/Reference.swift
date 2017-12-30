import git2
import Foundation

internal typealias git_reference = OpaquePointer
internal typealias git_object = OpaquePointer

private enum ReferenceError: LocalizedError {
    case invalidReference
    
    var errorDescription: String? {
        switch self {
        case .invalidReference:
            return "The git reference was neither to an object or another reference."
        }
    }
}

/// Git reference management
/// - See: git2/refs.h
public class Reference {
    internal let reference: git_reference
    
    public enum ReferenceType {
        /// A reference pointing to an object
        case object
        
        /// A reference pointing to another reference
        case symbolic
    }

    internal init(reference: git_reference, repository: Repository) throws {
        if git_reference_type(reference) == GIT_REF_INVALID {
            throw ReferenceError.invalidReference
        }
        self.reference = reference
        self.repository = repository
    }
    
    deinit {
        git_reference_free(self.reference)
    }
    
    /// Get the type of a reference.
    /// Can be either object or symbolic
    /// - See: git_reference_type
    public var type: ReferenceType {
        switch git_reference_type(self.reference) {
        case GIT_REF_OID:
            return .object
        case GIT_REF_SYMBOLIC:
            return .symbolic
        default:
            // This should be caught in Reference.init
            fatalError("Type of git reference was invalid")
        }
    }

    /// Get the repository that contains the reference
    public var repository: Repository
    
    /// Get the full name of a reference.
    /// - See: git_reference_name
    public var name: String {
        let name = git_reference_name(self.reference)!
        return String.init(cString: name)
    }
    
    /// Retrieve the OID of the reference.
    /// - See: git_reference_name_to_id
    public var oid: OID {
        let oid = OID()
        try! git_try("resolve reference name to oid") { git_reference_name_to_id(&oid.oid, self.repository.repository, self.name.cString(using: .utf8)) }
        return oid
    }
    
    /// Check if a reference is a remote tracking branch
    /// - See: git_reference_is_remote
    public var isRemoteBranch: Bool {
        return git_reference_is_remote(self.reference) == 1
    }
    
    /// Check if a reference is a local branch
    /// - See: git_reference_is_branch
    public var isLocalBranch: Bool {
        return git_reference_is_branch(self.reference) == 1
    }
    
    /// If the reference is a local or remote branch, returns a branch object that the reference is equivalent to.
    /// If not, returns nil.
    public var asBranch: Branch? {
        if !isLocalBranch && !isRemoteBranch {
            return nil
        }
        let name = try! git_try { git_branch_name($0, self.reference) }
        let reference: git_reference
        if isLocalBranch {
            reference = try! git_try { git_branch_lookup($0, self.repository.repository, name, GIT_BRANCH_LOCAL) }
        } else {
            reference = try! git_try { git_branch_lookup($0, self.repository.repository, name, GIT_BRANCH_REMOTE) }
        }
        return try? Branch(reference: reference, repository: self.repository)
    }
    
    /// Returns the commit that this reference is pointing to.
    public var asCommit: Commit? {
        return try? Commit(repository: self.repository, oid: self.oid)
    }
    
    internal func peel() throws -> git_object {
        return try git_try { git_reference_peel($0, self.reference, GIT_OBJ_ANY) }
    }
}

private extension Reference {
    
    func resolved() throws -> Reference {
        if self.type == .symbolic {
            let resolved = try git_try("resolve reference") { git_reference_resolve($0, self.reference) }
            return try Reference(reference: resolved, repository: repository)
        }
        return self
    }
}
