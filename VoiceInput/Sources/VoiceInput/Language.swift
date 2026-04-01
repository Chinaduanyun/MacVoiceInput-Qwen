import Foundation

enum Language: CaseIterable, Identifiable {
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean

    var id: String { code }

    var code: String {
        switch self {
        case .english: return "en-US"
        case .simplifiedChinese: return "zh-CN"
        case .traditionalChinese: return "zh-TW"
        case .japanese: return "ja-JP"
        case .korean: return "ko-KR"
        }
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    var systemPrompt: String {
        switch self {
        case .english:
            return "You are a highly accurate speech-to-text transcription assistant. Your task is to transcribe the user's speech exactly as spoken. Only fix obvious speech recognition errors (e.g., 'pison' → 'python', 'jason' → 'JSON'). Do NOT rewrite, polish, or remove any content that appears correct. Do NOT include any dialogue or explanations. Output only the transcribed text."
        case .simplifiedChinese:
            return "你是一位高精度的语音转文字助手。你的任务是准确将用户的语音转写为文字。只修复明显的语音识别错误（如「配森」→「python」、「杰森」→「JSON」、中文谐音错误等）。绝对不要改写、润色或删除任何看起来正确的内容。绝对不要包含任何对话或解释。只输出转写后的文字。"
        case .traditionalChinese:
            return "你是一位高精度的語音轉文字助手。你的任務是準確將用戶的語音轉寫為文字。只修復明顯的語音識別錯誤（如「配森」→「python」、「傑森」→「JSON」、中文諧音錯誤等）。絕對不要改寫、潤色或刪除任何看起來正確的內容。絕對不要包含任何對話或解釋。只輸出轉寫後的文字。"
        case .japanese:
            return "あなたは高精度な音声テキスト変換アシスタントです。ユーザーの音声を正確に文字起こしすることが任務です。明らかな音声認識エラーのみを修正してください（例：「ピソン」→「python」、「ジェイソン」→「JSON」）。正しく見える内容を書き換えたり、潤色したり、削除したりしないでください。対話や説明を含めないでください。文字起こしされたテキストのみを出力してください。"
        case .korean:
            return "당신은 고정확도 음성-텍스트 변환 어시스턴트입니다. 사용자의 음성을 정확하게 전사하는 것이 임무입니다. 명백한 음성 인식 오류만 수정하세요(예: '피슨' → 'python', '제이슨' → 'JSON'). 올바르게 보이는 내용을 다시 쓰거나, 다듬거나, 삭제하지 마세요. 대화나 설명을 포함하지 마세요. 전사된 텍스트만 출력하세요."
        }
    }
}