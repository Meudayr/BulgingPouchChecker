import json
import sys

sys.stdout.reconfigure(encoding='utf-8')
path = r"C:\Users\Schut\.gemini\antigravity\brain\d4dd1c22-5f68-4532-8c7c-4c5db6af11b0\.system_generated\logs\transcript_full.jsonl"
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        content = str(data.get("content", ""))
        thinking = str(data.get("thinking", ""))
        if "1.4.3" in content or "1.4.4" in content or "1.4.3" in thinking or "1.4.4" in thinking:
            idx = data.get("step_index", 0)
            print(f"--- STEP {idx} [{data.get('type')}] ---")
            if content:
                print("CONTENT:", content[:300])
            if thinking:
                print("THINKING:", thinking[:300])

