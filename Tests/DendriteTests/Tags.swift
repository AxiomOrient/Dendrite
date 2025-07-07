import Testing

/// Symbolic tags used across the entire test suite.
extension Tag {

    // MARK: Scope
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var ui: Self            // UI·Snapshot 테스트
    @Tag static var e2e: Self           // End‑to‑End

    // MARK: Layer / Component
    @Tag static var model: Self
    @Tag static var viewModel: Self
    @Tag static var view: Self
    @Tag static var network: Self
    @Tag static var storage: Self

    // MARK: Performance
    @Tag static var fast: Self
    @Tag static var slow: Self

    // MARK: Platform / OS
    @Tag static var ios: Self
    @Tag static var ipad: Self
    @Tag static var macos: Self
    @Tag static var watchos: Self
    @Tag static var tvos: Self

    // MARK: Priority / Meta
    @Tag static var critical: Self      // P0 시나리오
    @Tag static var flaky: Self         // 불안정 테스트 표시
}
