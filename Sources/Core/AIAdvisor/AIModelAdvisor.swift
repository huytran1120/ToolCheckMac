import Foundation

/// Runnability evaluation for an individual AI model.
enum AIVerdict: String, Sendable {
    case smooth   // Runs Smoothly
    case runnable // Runnable
    case tight    // Barely Runnable
    case no       // Not Recommended

    var label: String {
        switch self {
        case .smooth: return "Runs Smoothly"
        case .runnable: return "Runnable"
        case .tight: return "Barely Runnable"
        case .no: return "Not Recommended"
        }
    }
    var rank: Int {
        switch self {
        case .smooth: return 3
        case .runnable: return 2
        case .tight: return 1
        case .no: return 0
        }
    }
}

struct AIModelSuggestion: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let params: Double        // Billion parameters (B)
    let footprintGB: Double    // Estimated VRAM/RAM footprint for Q4 quantization + small context
    let verdict: AIVerdict
}

/// Local AI Model Runnability Advisor.
/// The core evaluation factor is **Memory**: Apple Silicon unified memory allows GPU/ANE to share most RAM for inference.
/// RAM is the primary constraint determining model size capability. Conservative estimates are provided for reference.
enum AIModelAdvisor {

    /// Memory budget (GB) allocated for model weights after reserving for system, apps, and KV cache.
    static func budgetGB(ramGB: Double) -> Double {
        max(2, ramGB - 8)
    }

    /// Empirical footprint for Q4_K_M quantization: ~0.55 GB per billion parameters, plus ~1.5 GB for context and runtime overhead.
    static func footprintGB(params: Double) -> Double {
        params * 0.55 + 1.5
    }

    /// Popular open-source models directory (covering various parameter size tiers).
    static let catalog: [(name: String, params: Double)] = [
        ("Llama 3.2 3B", 3),
        ("Gemma 3 4B", 4),
        ("Qwen3 4B", 4),
        ("Llama 3.1 8B", 8),
        ("Qwen3 8B", 8),
        ("DeepSeek-R1 Distill 8B", 8),
        ("Gemma 3 12B", 12),
        ("Phi-4 14B", 14),
        ("Qwen3 14B", 14),
        ("Mistral Small 24B", 24),
        ("Gemma 3 27B", 27),
        ("Qwen3 32B", 32),
        ("Llama 3.3 70B", 70),
        ("Qwen3 72B", 72),
    ]

    static func suggestions(ramGB: Double) -> [AIModelSuggestion] {
        let budget = budgetGB(ramGB: ramGB)
        return catalog.map { m in
            let fp = footprintGB(params: m.params)
            let verdict: AIVerdict
            if fp <= budget * 0.6 { verdict = .smooth }
            else if fp <= budget * 0.9 { verdict = .runnable }
            else if fp <= budget * 1.1 { verdict = .tight }
            else { verdict = .no }
            return AIModelSuggestion(name: m.name, params: m.params, footprintGB: fp, verdict: verdict)
        }
    }

    /// Recommended sweet spot: largest parameter model that can run smoothly or acceptably.
    static func sweetSpot(ramGB: Double) -> AIModelSuggestion? {
        suggestions(ramGB: ramGB)
            .filter { $0.verdict.rank >= AIVerdict.runnable.rank }
            .max { $0.params < $1.params }
    }

    /// Authoritative reference sites for further exploration and comparison.
    static let references: [(title: String, subtitle: String, url: String)] = [
        ("Ollama Model Library", "Run locally with a single command, easiest to get started", "https://ollama.com/library"),
        ("LM Studio", "Desktop GUI client for local LLMs", "https://lmstudio.ai"),
        ("Hugging Face", "The world's largest open-source model community", "https://huggingface.co/models"),
        ("Apple MLX", "Native optimized inference framework for Apple Silicon", "https://github.com/ml-explore/mlx"),
    ]
}
