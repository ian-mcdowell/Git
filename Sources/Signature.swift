import libgit2
import Foundation

/// Git signature creation
/// - See: git2/signature.h
public class Signature {
    internal var signature: UnsafePointer<git_signature>

    internal init(signature: UnsafePointer<git_signature>) {
        self.signature = signature
    }
    
    /// Create a new action signature.
    /// - See: git_signature_new
    public convenience init(name: String, email: String, time: Date = Date()) throws {
        let gitTime = time.gitTime()
        
        let signature = try git_try("create signature") { git_signature_new($0, name.cString(using: .utf8), email.cString(using: .utf8), gitTime.time, gitTime.offset) }
        
        self.init(signature: signature)
    }
    
    public var name: String {
        return String(cString: self.signature.pointee.name)
    }
    
    public var email: String {
        return String(cString: self.signature.pointee.email)
    }
}
