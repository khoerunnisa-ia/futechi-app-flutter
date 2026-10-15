import { createFileRoute } from "@tanstack/react-router";
import { createOpenAI } from "@ai-sdk/openai";
import { convertToModelMessages, streamText, type UIMessage } from "ai";
import { createRunIdFetch } from "@/lib/ai/run-id";

type ChatBody = { messages?: UIMessage[]; threadId?: string; caseId?: string };

const caseContext: Record<string, string> = {
  a24: "Kasus Sangkar A-24: kemungkinan Newcastle Disease 94%, Infectious Bronchitis 72%, dan Avian Influenza 58%.",
  b5: "Kasus Sangkar B-5: kemungkinan Heat Stress 86%, Dehidrasi 69%, dan Infeksi Saluran Pernapasan 47%.",
  c9: "Kasus Sangkar C-9: kemungkinan Avian Influenza 91%, Newcastle Disease 76%, dan Infectious Coryza 54%.",
};

export const Route = createFileRoute("/api/chat")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let body: ChatBody;
        try {
          body = (await request.json()) as ChatBody;
        } catch {
          return Response.json({ error: "Permintaan chat tidak valid." }, { status: 400 });
        }
        if (!Array.isArray(body.messages) || typeof body.threadId !== "string")
          return Response.json({ error: "Pesan atau percakapan tidak valid." }, { status: 400 });
        const apiKey = process.env["LOVABLE_API_KEY"];
        if (!apiKey)
          return Response.json({ error: "Techi AI belum dikonfigurasi." }, { status: 401 });

        const correlatedFetch = createRunIdFetch(
          request.headers.get("X-Lovable-AIG-Run-ID") ?? undefined,
        );
        const openai = createOpenAI({
          baseURL: "https://ai.gateway.lovable.dev/v1",
          apiKey,
          headers: { "Lovable-API-Key": apiKey, "X-Lovable-AIG-SDK": "vercel-ai-sdk" },
          fetch: correlatedFetch.fetch,
        });
        try {
          const context = typeof body.caseId === "string" ? caseContext[body.caseId] : undefined;
          const result = streamText({
            model: openai.responses("openai/gpt-6-astra"),
            system: `Anda adalah Techi, asisten operasional peternakan ayam Futechi. Jawab dalam Bahasa Indonesia yang ringkas, praktis, dan empatik. Utamakan biosekuriti, kesejahteraan ayam, dan keselamatan pekerja. Jangan mengklaim diagnosis pasti atau memberi resep/dosis obat mandiri; untuk gejala serius, mortalitas meningkat, atau dugaan penyakit menular, sarankan isolasi dan konsultasi dokter hewan. Gunakan markdown yang mudah dipindai.${context ? ` Konteks konsultasi aktif: ${context}` : ""} Jika pesan pengguna diawali [FORM SUSPECTION], analisis hanya gejala yang ditandai observed:true dibandingkan tiga kandidat. Jawaban wajib hanya berupa blok berikut tanpa markdown tambahan: SUSPECTION_RESULT_START lalu satu objek JSON valid dengan properti disease (string), confidence (number 0-100), rationale (string), mitigation (array berisi 3 string tindakan praktis), medication (string saran penanganan/kelas obat tanpa dosis, selalu mewajibkan persetujuan dokter hewan), lalu SUSPECTION_RESULT_END. Hindari diagnosis pasti dan nyatakan hasil sebagai kemungkinan tertinggi berdasarkan observasi.`,
            messages: await convertToModelMessages(body.messages),
            abortSignal: request.signal,
            providerOptions: {
              openai: {
                forceReasoning: true,
                reasoningEffort: "low",
                reasoningSummary: "auto",
                store: false,
                include: ["reasoning.encrypted_content"],
              },
            },
            maxRetries: 0,
          });
          const runId = correlatedFetch.getRunId();
          return result.toUIMessageStreamResponse({
            originalMessages: body.messages,
            sendReasoning: true,
            ...(runId ? { headers: { "X-Lovable-AIG-Run-ID": runId } } : {}),
            onError: (error) =>
              error instanceof Error ? error.message : "Techi AI sedang tidak tersedia.",
          });
        } catch (error) {
          const message =
            error instanceof Error ? error.message : "Techi AI sedang tidak tersedia.";
          return Response.json({ error: message }, { status: 500 });
        }
      },
    },
  },
});
