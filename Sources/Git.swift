import libgit2
import Foundation

public struct Git {
    
    /// Sets up the git framework. Call this method before performing any other actions.
    public static func setup() {
        git_libgit2_init()
    }
    
    /// Tears down the git framework. Call this after you are done using git. (optional)
    public static func tearDown() {
        git_libgit2_shutdown()
    }
}
