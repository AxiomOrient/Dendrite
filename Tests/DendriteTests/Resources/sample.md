# **Preamble: AI Communication Foundational Principles**

This is a test document.


[some link](https://www.axiomorient.com)


[Link to Google](https://www.google.com)

When generating all responses and work, the AI must adhere to the following highest-level principles. These principles are the basic premise that precedes all other guidelines.

#### **Principle 1: Bilingual Communication**

For technical accuracy, internal thought processes and information retrieval are conducted in English, while the final response is delivered in clear and natural Korean.

#### **Principle 2: Objective Analysis**

Excluding personal opinions or emotions, responses are based solely on a neutral analysis of the provided facts, data, and code context.

#### **Principle 3: Transparency & Honesty**

The AI will not speculate on uncertain or unknown information. Instead, it will guarantee the reliability of its answers by clearly admitting its limitations, such as, "I cannot determine this with the current information," or "Further confirmation is needed."

#### **Principle 4: Conciseness & Efficiency**

Responses prioritize the core of the question without unnecessary pleasantries or praise. The content is structured around essential explanations and code. If the code itself is the clearest explanation, only the code will be provided. However, minimal confirmation responses are permitted for interactional clarity.

---

### **Chapter 1: The Four Core Philosophies**

> The highest-level values that form the basis for all principles and directives.

#### **Article 1: Quality First**

- **Mission:** **"We consistently produce production-grade code that is stable, testable, and secure."**
- We aim for deliverables that are reliable in the long term, moving beyond code that simply functions. However, we pursue a pragmatic balance that considers business value and time-to-market.

#### **Article 2: Simplicity & Clarity**

- **Mission:** **"We prioritize the simplest and clearest solutions, focusing only on currently required features."**
- Complexity is a breeding ground for bugs. We actively avoid over-engineering (KISS) and do not implement features prematurely (YAGNI).

#### **Article 3: Contextual Awareness & Reusability**

- **Mission:** **"We maintain consistency with the existing codebase and maximize resource reuse to avoid duplication."**
- Before writing new code, we always examine the existing codebase first, eliminating duplication (DRY) to maintain a Single Source of Truth (SSoT).

#### **Article 4: Proactive Communication**

- **Mission:** **"We clarify intent through questions rather than assumptions and transparently share the reasoning behind our decisions."**
- This principle applies equally to the developer's own process and to directing the AI collaborator, ensuring transparency in all interactions.

---

### **Chapter 2: Universal Engineering Principles**

> Specific engineering directives for implementing the Four Core Philosophies in actual code.

#### **Article 5: Design Principles**

- **Adherence to SOLID:** All code is designed in compliance with SOLID principles, especially the **Single Responsibility Principle (SRP)**, to enhance maintainability and scalability.
- **Design for Testability:** All code is structured with decoupled dependencies to be easily testable.
- **Design for Performance:** We write optimized code that avoids unnecessary resource consumption and actively seek more efficient approaches for performance-critical sections. However, we avoid premature optimization.

#### **Article 6: Coding Principles**

- **Single Responsibility Functions:** Functions should be small and serve a single, clear purpose to enhance readability and testability.
- **Descriptive Naming:** All identifiers (variables, functions, classes, etc.) should be named to clearly reveal their role and intent. The following core naming principles apply across all platforms.

| Type | Format | Cross-Platform Example |
|---|---|---|
| Variables/Functions | `camelCase` | `userName`, `calculatePrice()` |
| Classes/Structs/Types/Enums | `PascalCase` | `class UserProfile`, `struct Point`, `enum Status` |
| Constants | `SCREAMING_SNAKE_CASE` | `let MAX_RETRIES = 3`, `static final int PORT = 8080` |

- **Commenting Principle:** Use concise comments only when necessary to explain the _intent and context ('the why')_ behind a particular implementation, not what the code is doing ('the how'). Do not leave commented-out code or comments that state the obvious.

#### **Article 7: Dependency Management Principle**

- **Judicious Dependency Management:** New external libraries are introduced only when their benefits are clear and substantial. We holistically review licenses, stability, community activity, and security vulnerabilities to minimize project complexity.

#### **Article 8: Error Handling Principle**

- **Explicit Error Handling:** Errors must not be hidden and must be handled explicitly. Predictable errors should be clearly propagated to the caller using a **Result type (Swift, Rust, Kotlin) or specific exception objects**. Error messages must include sufficient context to aid in troubleshooting.

---

### **Chapter 3: Universal Testing Principles**

> The fundamental principles of testing that guarantee the "Quality First" philosophy.

#### **Article 9: The AAA Pattern (Arrange, Act, Assert)**

- All tests are structured in three stages—**Arrange, Act, Assert**—to maximize readability and maintainability.

#### **Article 10: Test Authoring Principles**

- **One Assertion Per Test:** Each test should verify only one behavior or condition to allow for immediate identification of the cause upon failure.
- **Descriptive Test Names:** Test names should be complete sentences that clearly describe their intent.
- **Isolate Dependencies (Mocking):** Dependencies on external systems (networks, databases, etc.) should be isolated using protocols (interfaces) and mock objects to ensure tests are independent and fast.

#### **Article 11: The Testing Pyramid Strategy**

- To ensure stable and fast feedback, we adhere to the **Testing Pyramid (Unit > Integration > E2E) strategy**. Most logic is verified with fast, isolated unit tests; interactions between services are checked with integration tests; and core user scenarios are validated with a minimum of E2E tests.

---

### **Chapter 4: Universal Anti-Patterns**

> A list of code patterns to be actively avoided in all projects and flagged for improvement when discovered.

- **God Object/Class/Method:** A massive function or class that violates the Single Responsibility Principle.
- **Arrowhead Code:** Excessive indentation. Should be improved using guard clauses or other techniques.
- **Magic Numbers / Magic Strings:** Numbers or strings with unexplained meaning. Should be defined as named constants for clarity.
- **Dead Code:** Unused or commented-out code. Should be deleted immediately.
- **Improper Use of Global Mutable State:** Overusing global variables, which increases unpredictability.
- **Shotgun Surgery:** A single, small change that requires numerous modifications across many different classes.
- **Vendor Lock-in:** Becoming too dependent on a specific third-party service or library without an abstraction layer, making it difficult to replace.

### **Tier 3.1: Swift Standard**

**Role:** To define the specific and detailed standards for writing code in the Swift language, regardless of the platform. This guide aims to ensure the quality, readability, maintainability, and stability of the code.

#### **1. Foundational Principles & Style**

- **Language Version:** **Swift 6.0+**
    - Actively utilize all modern language features, including the Strict Concurrency model introduced in Swift 6.
- **Guideline Adherence:** Apple's official **[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)** serve as the "constitution" for all Swift code.

#### **2. Naming Conventions**

_The following Swift-specific rules are based on the foundational principles of Tier 1._

- **Clarity through Fluent Usage:**
    - **Booleans:** Names should start with prefixes like `is…`, `has…`, `does…` to form a question that can be answered with `true`/`false`. (e.g., `isUserLoggedIn`, `line.isEmpty`)
    - **Functions/Methods:** If a method has side-effects, its name should start with a verb. If it returns a value without side-effects, it should start with a noun describing the return value. (e.g., `list.sort()` vs. `list.sorted()`)
    - **Protocols:** Use suffixes like `-able`, `-ing` for protocols that describe a capability (e.g., `Equatable`, `Codable`). Use nouns for protocols that model a specific role (e.g., `RouteProtocol`, `TransactionDataSource`).
    - **Avoid Redundant Type Names:** Do not repeat the type name in a variable's name.
        - **Good:** `let users: [User]`
        - **Bad:** `let userArray: [User]`

#### **3. Code Formatting & Structure**

- **Line Length:** It is recommended that a single line of code does not exceed **120 characters** for readability.
- **File Length:** Files should be written based on an average of 500 lines. If a file exceeds 1000 lines, refactoring should be strongly considered.
- **Folder Structure:** Use folders minimally to group related files, avoiding unnecessary depth.
- **Structuring with `// MARK: -`:** Actively use `// MARK: -` comments to clearly separate logical blocks of code within a file. This greatly improves readability in Xcode's function/type pop-up menu.
    
    Swift
    
    ```
    actor DataCache<T: Sendable> {
        // MARK: - Properties
        private var cache: [String: T] = [:]
        private let expirationInterval: TimeInterval
    
        // MARK: - Initialization
        init(expirationInterval: TimeInterval = 60 * 10) { // 10 minutes
            self.expirationInterval = expirationInterval
        }
    
        // MARK: - Public API
        func value(forKey key: String) -> T? {
            return cache[key]
        }
    
        func setValue(_ value: T, forKey key: String) {
            cache[key] = value
        }
    
        // MARK: - Internal Logic
        private func removeExpiredData() {
            // ... Logic to clean up expired cache data
        }
    }
    ```
    

#### **4. Documentation**

- **Commenting Principle:** Comments should be used minimally. The goal is to write self-documenting code, but when necessary, comments should follow the principles below.
- **Swift-DocC:** All `public` and `internal` APIs (types, methods, properties) must be documented using the **Swift-DocC (`///`)** format.
    
    Swift
    
    ```
    /// Returns the cached value for the specified key.
    ///
    /// - Parameter key: The key for which to return the cached value.
    /// - Returns: The cached value associated with the key, or `nil` if the value is not in the cache or has expired.
    func value(forKey key: String) -> T? { ... }
    ```
    

#### **5. Type Design**

- **Prefer Value Types:**
    - **`struct`:** Use `struct` by default for data models and states where value copying is clear and there are no side-effects. This naturally ensures immutability and thread safety.
    - **`class`:** Consider using `class` only in the following cases: when managing the state of an external system (e.g., a file handler), when a single instance is necessary, or when interoperability with Objective-C is required.
- **State Modeling with Enums:**
    
    - Actively use `enum` with associated values to represent a limited set of states.
    
    Swift
    
    ```
    enum ViewState<T> {
        case loading
        case loaded(data: T)
        case error(message: String)
    }
    ```
    

- **Composition over Inheritance:** Prioritize combining functionality through protocols and object composition over creating rigid class hierarchies.

#### **6. Error Handling Strategy**

- **`Error` Protocol Conformance:** Define all custom error types as an `enum` that conforms to the `Error` protocol, using associated values to pass along useful context for debugging.
- **Utilize `Result` Type:** Actively use the `Result<Success, Failure>` type when passing the result of an asynchronous operation as a callback or to clearly distinguish between success and failure in functions that do not `throw`.

#### **7. Concurrency**

- **`async/await` by Default:** Write all asynchronous code using **`async/await`**. Wrap legacy callback-based APIs into `async` functions using `withCheckedContinuation`.
- **Structured Concurrency:**
    - Use **`async let`** to execute and await multiple independent asynchronous tasks in parallel.
    - Utilize **`TaskGroup`** to handle a dynamic number of parallel asynchronous tasks.
- **Event Bridging with `AsyncStream`:** Use **`AsyncStream`** to bridge continuous event systems like callbacks, delegates, or Notifications with the `async/await` world.
- **State Protection with `actor`:** Use **`actor`** to prevent data races caused by shared mutable state. Optimize performance by marking actor methods that do not access actor state as `nonisolated`.
- **Mandatory `@MainActor` Usage:** Designate all UI-related properties and methods with **`@MainActor`** to have the compiler guarantee they are only accessed on the main thread.
- **`Sendable` Conformance:** To pass Swift 6's strict concurrency checks, all types that cross `actor` boundaries must conform to the **`Sendable`** protocol.
- **`Task` Lifecycle Management:** Explicitly cancel a created `Task` (via `task.cancel()`) by storing it in a variable when the work is no longer needed to prevent resource leaks.

#### **8. Inter-Object Communication & Event Handling**

- **Prioritize Closures and Async/Await:** As a primary principle, use **closures** or **`async/await`** for event passing and callbacks between objects. This reduces coupling, improves readability, and inherently avoids the retain cycle issues of the delegate pattern.
    
    Swift
    
    ```
    // Good: Using a closure
    downloader.fetchData(url: url) { result in /* ... */ }
    
    // Better: Using async/await
    let data = try await downloader.fetchData(url: url)
    ```
    
- **Limited Use of the Delegate Pattern:** **The delegate pattern should only be used when unavoidable for interoperability with Apple's frameworks like UIKit/AppKit.** Avoid this pattern in new Swift code.
    - If its use is necessary, the `delegate` property must be declared with the **`weak` keyword** to prevent retain cycles. (`weak var delegate: MyDelegate?`)

#### **9. Swift API Design**

- **Clarity at the Point of Use:** Design APIs so that the call site reads like natural prose.
- **Use of Default Arguments:** Actively provide default values for parameters to simplify common use cases.
- **Result Builders:** Consider using result builders to provide a Domain-Specific Language (DSL) for creating complex object hierarchies declaratively, similar to SwiftUI's `ViewBuilder`.

#### **10. Other Key Principles**

- **Access Control:** Internal implementation details that do not need to be known externally should be `private` or `fileprivate` by default. APIs between modules should be clearly defined as `internal` (the default) or `public`. However, consider designing parts that are highly likely to be shared more openly for reusability.
- **Prohibit Force Casting and Unwrapping:** The use of **`as!` (forced downcasting)** and **`!` (forced unwrapping)** is forbidden in production code as it can crash the app.
---

| Header 1 | Header 2 | Header 3 |
|---|---|---|
| Row 1 Col 1 | Row 1 Col 2 | Row 1 Col 3 |
| Row 2 Col 1 | Row 2 Col 2 | Row 2 Col 3 |
| Row 3 Col 1 | Row 3 Col 2 | Row 3 Col 3 |