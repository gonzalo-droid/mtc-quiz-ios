import Testing
import Foundation
@testable import MTCDomain

@Suite struct QuestionTests {
    private let question = MTCDomain.Question(
        id: 1, section: "Materias generales", category: "AI",
        topic: "Reglamento de Tránsito", title: "¿Pregunta?",
        answer: "c", argument: "",
        options: [
            "a) Opción A", "b) Opción B", "c) Opción C", "d) Opción D",
        ],
        images: []
    )

    @Test func isCorrectAnswerMatchesLetterIndex() {
        #expect(question.isCorrectAnswer(2) == true)
        #expect(question.isCorrectAnswer(0) == false)
    }

    @Test func isCorrectAnswerFallsBackToIndexThreeForUnknownLetters() {
        // Ports Android's exact `else -> 3` fallback in Question.isCorrectAnswer.
        let weird = MTCDomain.Question(answer: "z", options: ["a) A", "b) B", "c) C", "d) D"])
        #expect(weird.isCorrectAnswer(3) == true)
    }

    @Test func optionForLetterIsCaseInsensitive() {
        #expect(question.option(for: "C") == "c) Opción C")
        #expect(question.option(for: "c") == "c) Opción C")
    }

    @Test func optionForUnknownLetterReturnsFallbackText() {
        #expect(question.option(for: "z") == "Opción no disponible")
    }

    @Test func decodesRealAndroidJSONShapeIncludingTypoKeysAndExtraFields() throws {
        // Real shape from app/src/main/assets/json/a3c_questions.json id 1 — includes the
        // extraneous "part" bookkeeping key (must be silently ignored) and omits "fundamento"/"imagens".
        let json = """
        {
          "id": 1,
          "part": 1,
          "section": "Materias generales",
          "category": "Todas",
          "topic": "Reglamento de Tránsito y Manual de Dispositivos de Control de Tránsito",
          "title": "Está permitido en la vía:",
          "options": ["a) Uno", "b) Dos", "c) Tres", "d) Cuatro"],
          "answer": "c"
        }
        """
        let decoded = try JSONDecoder().decode(MTCDomain.Question.self, from: Data(json.utf8))
        #expect(decoded.id == 1)
        #expect(decoded.answer == "c")
        #expect(decoded.argument == "")
        #expect(decoded.images == [])
    }

    @Test func decodesFundamentoAndImagensJSONKeys() throws {
        // Real shape from a2a_questions.json — "fundamento" -> argument, "imagens" -> images.
        let json = """
        {
          "id": 201, "topic": "t", "title": "t", "answer": "b",
          "fundamento": "Artículo 1 del RENAT",
          "options": ["a) A", "b) B", "c) C", "d) D"],
          "imagens": ["q4_a_a2a"]
        }
        """
        let decoded = try JSONDecoder().decode(MTCDomain.Question.self, from: Data(json.utf8))
        #expect(decoded.argument == "Artículo 1 del RENAT")
        #expect(decoded.images == ["q4_a_a2a"])
    }

    @Test func decodesQuestionResponseTopLevelObjectShape() throws {
        let json = """
        { "data": [ { "id": 1, "topic": "t", "title": "t", "answer": "a", "options": ["a) A"] } ] }
        """
        let decoded = try JSONDecoder().decode(MTCDomain.QuestionResponse.self, from: Data(json.utf8))
        #expect(decoded.data.count == 1)
        #expect(decoded.data[0].id == 1)
    }
}
