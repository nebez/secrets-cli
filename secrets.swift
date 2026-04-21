import Foundation
import Security
import LocalAuthentication

let serviceName = "com.nebez.secrets"

func requireBiometrics(reason: String) {
    let context = LAContext()
    context.touchIDAuthenticationAllowableReuseDuration = 0

    var authError: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
        fputs("Touch ID not available: \(authError?.localizedDescription ?? "unknown")\n", stderr)
        exit(1)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    var evalError: Error?

    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, err in
        success = ok
        evalError = err
        semaphore.signal()
    }

    semaphore.wait()

    guard success else {
        fputs("Authentication failed: \(evalError?.localizedDescription ?? "cancelled")\n", stderr)
        exit(1)
    }
}

func readSecureInput(prompt: String) -> String {
    fputs(prompt, stderr)

    var oldTermios = termios()
    tcgetattr(STDIN_FILENO, &oldTermios)

    var newTermios = oldTermios
    newTermios.c_lflag &= ~UInt(ECHO)
    tcsetattr(STDIN_FILENO, TCSANOW, &newTermios)

    let value = readLine(strippingNewline: true) ?? ""

    tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
    fputs("\n", stderr)

    return value
}

func setSecret(key: String, value: String) {
    let deleteQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecAttrAccount as String: key,
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecAttrAccount as String: key,
        kSecValueData as String: value.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecSuccess {
        fputs("Stored '\(key)'\n", stderr)
    } else {
        fputs("Error storing secret: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)\n", stderr)
        exit(1)
    }
}

func getSecret(key: String) {
    requireBiometrics(reason: "Access secret '\(key)'")

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) {
        let terminator = isatty(STDOUT_FILENO) == 1 ? "\n" : ""
        print(value, terminator: terminator)
    } else if status == errSecItemNotFound {
        fputs("No secret found for '\(key)'\n", stderr)
        exit(1)
    } else {
        fputs("Error: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)\n", stderr)
        exit(1)
    }
}

func listSecrets() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecReturnAttributes as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecSuccess, let items = result as? [[String: Any]] {
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String {
                print(account)
            }
        }
    } else if status == errSecItemNotFound {
        // No items
    } else {
        fputs("Error listing secrets: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)\n", stderr)
        exit(1)
    }
}

func deleteSecret(key: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecAttrAccount as String: key,
    ]

    let status = SecItemDelete(query as CFDictionary)
    if status == errSecSuccess {
        fputs("Deleted '\(key)'\n", stderr)
    } else if status == errSecItemNotFound {
        fputs("No secret found for '\(key)'\n", stderr)
        exit(1)
    } else {
        fputs("Error: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)\n", stderr)
        exit(1)
    }
}

func printUsage() -> Never {
    fputs("""
    Usage: secrets <command> [args]

    Commands:
      set <key> [value]   Store a secret (prompts securely if value omitted)
      get <key>           Retrieve a secret (Touch ID)
      list                List stored keys
      delete <key>        Delete a secret

    The decrypted value is printed to stdout only (all other output goes to stderr).
    Pipe-friendly: secrets get my-api-key | pbcopy

    """, stderr)
    exit(1)
}

// --- main ---

let args = Array(CommandLine.arguments.dropFirst())

guard let command = args.first else { printUsage() }

switch command {
case "set":
    guard args.count >= 2 else { printUsage() }
    let key = args[1]
    let value: String
    if args.count >= 3 {
        value = args[2...].joined(separator: " ")
    } else {
        let input = readSecureInput(prompt: "Enter value for '\(key)': ")
        guard !input.isEmpty else {
            fputs("No value provided\n", stderr)
            exit(1)
        }
        value = input
    }
    setSecret(key: key, value: value)

case "get":
    guard args.count == 2 else { printUsage() }
    getSecret(key: args[1])

case "list":
    listSecrets()

case "delete":
    guard args.count == 2 else { printUsage() }
    deleteSecret(key: args[1])

default:
    printUsage()
}
