import git2
import Foundation

/// Git object id
/// - See: git2/oid.h
public class OID {
    internal var oid: git_oid
    
    public init() {
        self.oid = git_oid()
    }
    internal init(oid: git_oid) {
        self.oid = oid
    }
    internal convenience init(oid: UnsafePointer<git_oid>) {
        self.init()
        git_oid_cpy(&self.oid, oid)
    }
    public convenience init(sha: String) throws {
        self.init()
        try git_try { git_oid_fromstrp(&self.oid, sha.cString(using: .utf8)) }
    }
    
    public var sha: String {
        let str = git_oid_tostr_s(&self.oid)
        return String(cString: str!)
    }
    
    public var sha_short: String {
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        git_oid_tostr(buffer, 8, &self.oid)
        let str = String(cString: buffer)
        buffer.deallocate(capacity: 8)
        return str
    }
    
}
