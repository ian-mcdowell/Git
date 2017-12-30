import git2
import Foundation

internal typealias git_revwalk = OpaquePointer

/// Git revision traversal
/// - See: git2/revwalk.h
internal class RevWalk {
    private let revwalk: git_revwalk

    private init(revwalk: git_revwalk) {
        self.revwalk = revwalk
    }

    convenience init(repository: Repository, from: OID?, to: OID?) throws {
        let revwalk = try git_try("create rev walker") { git_revwalk_new($0, repository.repository) }
        
        if let from = from {
            git_revwalk_push(revwalk, &from.oid)
        }
        if let to = to {
            git_revwalk_hide(revwalk, &to.oid)
        }

        self.init(revwalk: revwalk)
    }

    deinit {
        git_revwalk_free(self.revwalk)
    }

    func next() -> OID? {
        let oid = OID()
        if git_revwalk_next(&oid.oid, self.revwalk) == GIT_OK.rawValue {
            return oid
        }
        return nil
    }
}
