import git2
import Foundation

public typealias CredentialProvider = (_ username: String) throws -> Credential
internal class CredentialProviderMetadata {
    
    private let provider: CredentialProvider
    internal let fetchProgress: (Double) -> Void
    internal let checkoutProgress: (Double) -> Void
    
    private var credential: Credential?
    
    internal init(provider: @escaping CredentialProvider, fetchProgress: @escaping (Double) -> Void, checkoutProgress: @escaping (Double) -> Void) {
        self.provider = provider
        self.fetchProgress = fetchProgress
        self.checkoutProgress = checkoutProgress
        self.credential = nil
    }
    
    internal func credential(forUsername username: String) -> Credential? {
        do {
            self.credential = try provider(username)
            return self.credential
        } catch {
            return nil
        }
    }
}

/// Credential used for authenticating with remotes.
/// - See: git2/transport.h
public class Credential {
    internal let cred: UnsafeMutablePointer<git_cred>

    internal init(cred: UnsafeMutablePointer<git_cred>) {
        self.cred = cred
    }

        /// Create a credential to specify a username.
    /// - See: git_cred_username_new
    public convenience init(username: String) throws {
        let cred = try git_try("create credential") { git_cred_username_new($0, username.cString(using: .utf8)) }
        self.init(cred: cred)
    }

    /// Create a new plain-text username and password credential object.
    /// - See: git_cred_userpass_plaintext_new
    public convenience init(username: String, password: String) throws {
        let cred = try git_try("create credential") { git_cred_userpass_plaintext_new($0, username.cString(using: .utf8), password.cString(using: .utf8)) }
        self.init(cred: cred)
    }

    /// Create a new passphrase-protected ssh key credential object.
    /// - See: git_cred_ssh_key_new
    public convenience init(username: String, publicKey: URL, privateKey: URL, passphrase: String?) throws {
        let cred = try git_try("create credential") { git_cred_ssh_key_new($0, username.cString(using: .utf8), publicKey.path.cString(using: .utf8), privateKey.path.cString(using: .utf8), passphrase?.cString(using: .utf8)) }
        self.init(cred: cred)
    }

    /// Create a new ssh key credential object reading the keys from memory.
    /// - See: git_cred_ssh_key_memory_new
    public convenience init(username: String, publicKey: String, privateKey: String, passphrase: String?) throws {
        let cred = try git_try("create credential") { git_cred_ssh_key_memory_new($0, username.cString(using: .utf8), publicKey.cString(using: .utf8), privateKey.cString(using: .utf8), passphrase?.cString(using: .utf8)) }
        self.init(cred: cred)
    }

    // TODO: Interactive credential: git_cred_ssh_interactive_new
    
}
