import git2
import Foundation

/// Try to execute a method, and throw if git returns a non-zero status code
internal func git_try(_ action: String? = nil, _ method: () -> Int32) throws {
    let error = method()
    guard error == GIT_OK.rawValue else {
        throw GitError.create(action)
    }
}

/// Try to execute a method, and throw if git returns a non-zero status code
/// This override is for git methods that return a value into an argument pointer
internal func git_try<T>(_ action: String? = nil, _ method: (UnsafeMutablePointer<T?>) -> Int32) throws -> T {
    var val: T? = nil
    let error = method(&val)
    guard let value = val, error == GIT_OK.rawValue else {
        throw GitError.create(action)
    }
    return value
}

/// Try to execute a method, and throw if git returns a non-zero status code
/// This override is for git methods that return 2 values into argument pointers
internal func git_try<T, V>(_ action: String? = nil, _ method: (UnsafeMutablePointer<T?>, UnsafeMutablePointer<V?>) -> Int32) throws -> (T, V) {
    var val1: T? = nil
    var val2: V? = nil
    let error = method(&val1, &val2)
    guard let value1 = val1, let value2 = val2, error == GIT_OK.rawValue else {
        throw GitError.create(action)
    }
    return (value1, value2)
}

internal func git_try(_ action: String? = nil, _ method: (UnsafeMutablePointer<git_buf>) -> Int32) throws -> Data {
    var buf = git_buf.init()
    let error = method(&buf)
    guard error == GIT_OK.rawValue else {
        throw GitError.create(action)
    }
    let data = try Data.fromBuffer(buffer: &buf)
    git_buf_free(&buf)
    return data
}

enum GitError: LocalizedError {
    case gitError(errorStr: String, action: String?)
    case notImplemented
    
    static func create(_ action: String? = nil) -> GitError {
        let errorStr: String
        if let error = giterr_last() {
            errorStr = String.init(cString: error.pointee.message)
        } else {
            errorStr = ""
        }
        return GitError.gitError(errorStr: errorStr, action: action)
    }
    
    var errorDescription: String? {
        switch self {
        case .gitError(let errorStr, let action):
            if let action = action {
                return "Failed to \(action). \(errorStr)"
            }
            return errorStr
        case .notImplemented:
            return "Method not implemented"
        }
    }
}
