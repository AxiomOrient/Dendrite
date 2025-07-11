
# Swift Testing 구체 가이드

## 1. AAA 패턴 (Arrange‑Act‑Assert)

```swift
@Test("사용자 이름 업데이트 검증")
func testUpdateUserName() {
    // Arrange
    var user = User(name: "Old")
    let newName = "New"

    // Act
    user.updateName(to: newName)

    // Assert
    #expect(user.name == newName)
}
```

## 2. 테스트 작성 원칙

* **단일 책임**: 하나의 테스트는 하나의 기능만 검증
* **서술적 이름**

  * 좋은 예: `testEmptyName_ThrowsInvalidNameError()`
  * 나쁜 예: `test1()`
* **독립성**: 테스트 간 공유 상태 금지
* **최소 코드**: 통과에 필요한 최소 구현만

## 3. 태그(Tag) 활용

### 3.1 Enum 기반 태그

```swift
enum TestTag {
    static let unit = "unit"
    static let integration = "integration"
}

@Tag(TestTag.unit)
@Test("간단한 단위 테스트")
func testAddition() {
    #expect(1 + 1 == 2)
}
```

### 3.2 네임스페이스 기반 태그 (추천)

```swift
enum Tags {
    enum Level { static let unit = "unit"; static let integration = "integration" }
    enum Speed { static let fast = "fast"; static let slow = "slow" }
}

@Tag(Tags.Level.integration, Tags.Speed.slow)
@Test("API로부터 사용자 데이터 가져오기 (비동기)")
func testFetchUserAsync() async throws {
    let api = MockAPI()
    let user = try await api.fetchUser(id: "123")
    #expect(user.id == "123")
}
```

#### 실행 제어

* 단위 테스트만 실행:

  ```bash
  swift test --filter-tag unit
  ```
* 느린 테스트 제외:

  ```bash
  swift test --skip-tag slow
  ```

## 4. Mock & Dependency 분리

```swift
protocol UserService {
    func fetchUser(id: String) throws -> User
}

class MockUserService: UserService {
    func fetchUser(id: String) throws -> User {
        return User(id: id, name: "Mock")
    }
}

@Test("MockService를 이용한 fetch 검증")
func testFetchWithMock() throws {
    // Arrange
    let service: UserService = MockUserService()
    // Act
    let user = try service.fetchUser(id: "X")
    // Assert
    #expect(user.name == "Mock")
}
```

## 5. 주석 & 문서화 모범 사례

* **Swift‑Doc 스타일**: Intent, Given, When, Then
* **`// MARK:`** 로 테스트 그룹 시각적 구분
* **필요한 설명(Why)만** 주석으로 작성

```swift
/// 사용자 저장 및 불러오기 기능 검증
/// - Intent: UserStorage.save와 fetch가 올바르게 동작하는지 확인
/// - Given: ID와 이름을 가진 User 객체
/// - When: save → fetch 호출
/// - Then: 반환된 User가 동일한 속성인지 검증
@Test("사용자 저장 및 불러오기")
func testSaveAndFetchUser() throws {
    // Arrange
    let storage = MockUserStorage()
    let userToSave = User(id: "u1", name: "Alice")
    // Act
    try storage.save(userToSave)
    let fetched = try storage.fetch(id: "u1")
    // Assert
    #expect(fetched.id == "u1")
    #expect(fetched.name == "Alice")
}
```
