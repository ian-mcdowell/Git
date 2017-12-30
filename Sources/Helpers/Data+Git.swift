import git2
import Foundation

extension Data {

    static func fromBuffer(buffer: UnsafeMutablePointer<git_buf>) throws -> Data {
        if buffer.pointee.size == 0 {
            return Data()
        }

        try git_try("grow git buffer") { git_buf_grow(buffer, 0) }

        return Data(bytes: buffer.pointee.ptr, count: buffer.pointee.size)
    }
}
