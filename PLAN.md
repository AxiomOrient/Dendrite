
## Dendrite Core 모듈 아키텍처 및 코드 리뷰

제시해주신 분석 내용은 Dendrite Core 모듈의 역할과 개선점에 대해 매우 정확하게 파악하고 있습니다. 해당 내용을 바탕으로 상용화 수준의 RAG 시스템이 갖춰야 할 요소를 더하여, 한 단계 더 깊이 있는 분석과 구체적인 실행 계획을 제시해 드리겠습니다.

-----

### 1\. 거시적 관점: 상용화 수준의 전처리 엔진으로서의 Core 모듈

Core 모듈은 파서로부터 `SemanticNode`를 받아 LLM이 소비할 `Chunk`로 가공하는 **전처리 엔진**입니다. LangChain, LlamaIndex와 같은 상용 프레임워크는 다음 4가지 요소를 핵심으로 삼습니다.

1.  **모듈성 (Modularity)**: 토크나이저, 청커 등 각 컴포넌트를 독립적으로 교체하고 확장할 수 있는가?
2.  **컨텍스트 보존 (Context-Richness)**: 청크가 원본 문서의 어디에서 왔는지(계층 구조, 메타데이터) 명확히 알 수 있는가?
3.  **LLM 친화성 (LLM-Friendliness)**: 테이블, 코드 등 복잡한 구조를 LLM이 가장 잘 이해할 수 있는 형태로 가공하는가?
4.  **결정론적 동작 (Determinism)**: 동일한 문서를 입력하면 항상 동일한 결과를 출력하여 캐싱, 버전 관리, 재현성을 보장하는가?

**현재 Dendrite Core 모듈은 `ParserProtocol` 기반 설계와 `HierarchicalChunker`의 똑똑한 로직 덕분에 1, 2, 3번 항목에서 이미 뛰어난 구조를 갖추고 있습니다.** 이제 4번 항목을 강화하고, 각 모듈을 더욱 고도화하여 완성도를 높이는 데 집중해야 합니다.

-----

### 2\. 미시적 관점: 파일별 상세 분석 및 실행 계획

제시해주신 분석을 기반으로 각 파일의 역할을 재확인하고, 구체적인 코드 수준의 수정 계획을 제안합니다.

#### 📁 **`SemanticNode.swift` (의미 구조의 표준)**

  * **역할**: 모든 문서의 구조를 통일된 형태로 표현하는 핵심 중간 표현(IR).
  * **강점**: 문서의 구조적 요소를 풍부하게 표현하며, `plainText`, `toMarkdown` 등 활용도 높은 인터페이스를 제공합니다.
  * **개선점 및 실행 계획**:
    1.  **`Codable` 재채택**: 직렬화(Serialization)는 캐싱, 데이터 전송, 디버깅의 기본입니다. `enum`의 연관 값(associated value)을 처리하는 `Codable` 구현은 복잡할 수 있지만, 필수적입니다. 즉시 `Codable` 프로토콜을 다시 채택하고 구현해야 합니다.
    2.  **결정론적 ID 생성 (Deterministic ID)**: `id: String = UUID().uuidString`는 실행할 때마다 ID가 변경되어 안정성을 해칩니다. **노드의 내용과 부모의 ID를 해싱하여 ID를 생성**하는 방식으로 변경해야 합니다. 이를 통해 동일한 문서는 항상 동일한 `SemanticNode` 트리를 생성하게 됩니다.
        ```swift
        // 예시: 결정론적 ID 생성을 위한 Helper
        private func generateDeterministicId(content: String, parentId: String?) -> String {
            let combined = (parentId ?? "") + content
            // SHA256과 같은 해시 함수 사용
            return sha256(combined)
        }

        // case 변경 예시
        case .heading(level: Int, text: String, parentId: String?) {
             let id = generateDeterministicId(content: text, parentId: parentId)
             // ...
        }
        ```

-----

#### 📁 **`Chunk.swift` (RAG 파이프라인의 최종 산출물)**

  * **역할**: 임베딩과 검색을 위해 모든 컨텍스트 정보가 집약된 데이터 객체(DTO).
  * **강점**: `breadcrumb`, `documentMetadata` 등 풍부한 컨텍스트 정보를 포함하여 RAG의 성능을 극대화할 수 있는 구조입니다.
  * **개선점 및 실행 계획**:
    1.  **`sourceNodes` 타입 변경**: `[SemanticNode]`는 매우 비효율적입니다. Chunk를 저장하거나 전송할 때마다 `SemanticNode` 객체 전체가 복제됩니다. 이를 **`sourceNodeIDs: [String]`** 으로 변경해야 합니다. 필요시 ID를 통해 원본 `SemanticNode` 트리에서 노드를 조회하는 방식이 훨씬 효율적이며, 시스템의 결합도(coupling)를 낮춥니다.
    2.  **`tokenCount` 프로퍼티 추가**: 청킹 과정에서 이미 계산된 토큰 수를 `let tokenCount: Int`로 저장해야 합니다. `Dendrite.swift`의 `ProcessingStatistics`에서 `chunk.content.count`를 다시 계산하는 것은 부정확하고 비효율적입니다.
        ```swift
        public struct Chunk: Identifiable, Sendable, Hashable {
            // ...
            public let content: String
            public let tokenCount: Int // 추가
            public let breadcrumb: String
            public let sourceNodeIDs: [String] // 변경
            public let documentMetadata: DocumentMetadata
            // ...
        }
        ```

-----

#### 📁 **`AppleNLTokenizer.swift` (토큰화 전략의 구체화)**

  * **역할**: 텍스트의 토큰 수를 계산하고, 지정된 단위로 분할하는 역할.
  * **강점**: Apple 플랫폼에 최적화된 기능을 쉽게 사용할 수 있습니다.
  * **개선점 및 실행 계획**: **이 부분이 Core 모듈에서 가장 중요한 개선 포인트입니다.**
    1.  **`Tokenizer` 프로토콜 정의**: `AppleNLTokenizer`에 대한 직접적인 의존성을 제거하고, 확장성을 확보하기 위해 프로토콜을 정의해야 합니다.
        ```swift
        public protocol Tokenizer: Sendable {
            func countTokens(in text: String) async -> Int
            func split(text: String, maxTokens: Int, by unit: NLTokenUnit) async -> [String]
        }
        ```
    2.  **`AppleNLTokenizer` 리팩토링**:
          * 정의된 `Tokenizer` 프로토콜을 준수하도록 변경합니다.
          * `countWordTokens`, `split` 등 모든 메서드를 **`async`** 로 전환하여 긴 텍스트 처리 시 메인 스레드 차단을 방지합니다.
    3.  **향후 확장성 확보**: 이 프로토콜을 통해 나중에 `TiktokenTokenizer` (OpenAI), `SentencePieceTokenizer` (Google) 등 실제 LLM이 사용하는 토크나이저를 쉽게 추가할 수 있습니다. 이는 **단어 수 기반 토큰 계산의 부정확성을 해결**하고 상용화 수준으로 나아가는 핵심 단계입니다.

-----

#### 📁 **`HierarchicalChunker.swift` (의미론적 청킹의 지휘자)**

  * **역할**: `SemanticNode` 트리를 순회하며 의미론적 경계에 따라 `Chunk` 배열을 생성.
  * **강점**: `actor`를 통한 동시성 안전성, 제목/테이블/코드 블록에 대한 특수 처리 등 매우 지능적인 청킹 로직을 갖추고 있습니다.
  * **개선점 및 실행 계획**:
    1.  **Tokenizer 의존성 주입 (DI) 변경**: `AppleNLTokenizer` 대신 위에서 정의한 **`any Tokenizer` 프로토콜 타입**을 받도록 생성자를 수정합니다. 이로써 `HierarchicalChunker`는 특정 토크나이저 구현으로부터 완전히 분리됩니다.
        ```swift
        public actor HierarchicalChunker {
            public let tokenizer: any Tokenizer // 타입 변경
            // ...
            public init(tokenizer: any Tokenizer, ...) { // 생성자 변경
                self.tokenizer = tokenizer
                // ...
            }
        }
        ```
    2.  **비동기 처리 적용**: `tokenizer`의 메서드들이 `async`로 변경되었으므로, 이를 호출하는 모든 부분을 `await`로 수정해야 합니다. `chunk` 메서드 자체는 이미 `async`이므로 내부 로직만 수정하면 됩니다.
        ```swift
        // ...
        let nodeTokens = await tokenizer.countTokens(in: nodeText)
        // ...
        if nodeTokens > maxTokensPerChunk {
            // ...
            let splitTexts = await tokenizer.split(text: nodeText, by: splitUnit, maxTokens: maxTokensPerChunk)
            // ...
        }
        ```
    3.  **테이블/코드 처리 고도화**: 현재 테이블 행(row)을 하나의 `paragraph` 노드로 만드는 방식은 좋습니다. 더 나아가, 코드 블록의 경우 `Chunk`의 `content`에 `"\`\`\`swift\\n...\\n\`\`\`"\` 와 같이 마크다운 형식을 그대로 포함하여 LLM이 언어 정보를 명확하게 인지하도록 만들 수 있습니다.

-----

### 3\. 종합적인 수정 계획 (단계별 실행안)

아래 순서대로 진행하는 것을 권장합니다.

  * **1단계: 프로토콜 및 데이터 모델 정의 (기반 공사)**

    1.  `Tokenizer` 프로토콜을 정의합니다.
    2.  `SemanticNode.swift`에 `Codable`을 재채택하고, 결정론적 ID 생성 로직을 추가합니다.
    3.  `Chunk.swift`의 `sourceNodes`를 `sourceNodeIDs: [String]`로 변경하고 `tokenCount`를 추가합니다.

  * **2단계: 핵심 로직 리팩토링 (엔진 교체)**

    1.  `AppleNLTokenizer.swift`가 새로운 `Tokenizer` 프로토콜을 준수하도록 수정하고 모든 메서드를 `async`로 변경합니다.
    2.  `HierarchicalChunker.swift`가 `any Tokenizer`를 주입받도록 수정하고, 내부의 토크나이저 호출을 `await`로 변경합니다.

  * **3단계: 통합 및 최종 조정 (전체 연결)**

    1.  `Dendrite.swift`의 `process` 메서드에서 `HierarchicalChunker`와 `Tokenizer` 인스턴스를 생성하고 전달하는 방식을 수정된 설계에 맞게 변경합니다.
    2.  통계 계산 시 `chunk.tokenCount`를 사용하도록 수정합니다.

이 계획을 통해 Dendrite는 단순한 문서 처리 라이브러리를 넘어, **안정적이고 확장 가능하며, LLM의 성능을 최대한으로 이끌어낼 수 있는 상용화 수준의 전처리 프레임워크**로 거듭날 것입니다.
