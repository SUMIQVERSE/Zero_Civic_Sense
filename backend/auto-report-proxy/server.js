const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");

dotenv.config();

const app = express();

const PORT = Number(process.env.PORT || 8787);
const OPENAI_API_KEY = (process.env.OPENAI_API_KEY || "").trim();
const OPENAI_MODEL = (process.env.OPENAI_MODEL || "gpt-5-mini").trim();
const GEMINI_API_KEY = (process.env.GEMINI_API_KEY || "").trim();
const GEMINI_MODEL = (process.env.GEMINI_MODEL || "gemini-2.5-flash-lite").trim();
const AI_PROVIDER = resolveProvider(process.env.AI_PROVIDER);
const AUTOREPORT_TOKEN = (process.env.AUTOREPORT_TOKEN || "").trim();
const SPECIFIC_ISSUE_TYPES = [
  "pothole",
  "road_damage",
  "road_crack",
  "garbage_dump",
  "litter_accumulation",
  "sewage_overflow",
  "sewage_pipe_damage",
  "water_leakage",
  "waterlogging",
  "damaged_streetlight",
  "broken_electric_pole",
  "transformer_damage",
  "electric_sparking",
  "damaged_electric_wire",
  "unclear_or_non_civic",
];

app.use(cors());
app.use(express.json({ limit: "20mb" }));

app.get("/", (_req, res) => {
  res.status(200).send(
    [
      "CIVICSETU auto-report proxy is running.",
      "Use GET /health for backend status.",
      "Use POST /v1/analyze-complaint-image for image analysis.",
    ].join("\n"),
  );
});

app.get("/health", (_req, res) => {
  const providerConfig = getProviderConfig();
  res.json({
    status: "ok",
    provider: providerConfig.provider,
    model: providerConfig.model,
    tokenProtected: AUTOREPORT_TOKEN.length > 0,
  });
});

app.post("/v1/analyze-complaint-image", async (req, res) => {
  if (AUTOREPORT_TOKEN) {
    const authHeader = req.get("Authorization") || "";
    const bearerToken = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (bearerToken !== AUTOREPORT_TOKEN) {
      return res.status(401).json({
        error: "Unauthorized auto-report request.",
      });
    }
  }

  const providerConfig = getProviderConfig();

  if (!providerConfig.apiKey) {
    return res.status(500).json({
      error: `${providerConfig.providerDisplayName} API key is not configured on the backend.`,
    });
  }

  const imageBase64 = stringValue(req.body.imageBase64);
  const mimeType = stringValue(req.body.mimeType) || "image/jpeg";
  const languageCode = stringValue(req.body.language) || "en";
  const reviewWindowSeconds = clampWindow(req.body.reviewWindowSeconds);

  if (!imageBase64) {
    return res.status(400).json({
      error: "imageBase64 is required.",
    });
  }

  try {
    const prompt = buildPrompt({
      languageCode,
      reviewWindowSeconds,
      user: req.body.user,
      location: req.body.location,
    });

    const analysis = providerConfig.provider === "gemini"
      ? await analyzeWithGemini({
          apiKey: providerConfig.apiKey,
          model: providerConfig.model,
          prompt,
          imageBase64,
          mimeType,
        })
      : await analyzeWithOpenAI({
          apiKey: providerConfig.apiKey,
          model: providerConfig.model,
          prompt,
          imageBase64,
          mimeType,
        });

    return res.json(normalizeDraft(analysis.parsed, {
      providerLabel: analysis.providerLabel,
      reviewWindowSeconds,
    }));
  } catch (error) {
    const status = error instanceof UpstreamHttpError ? error.status : 500;
    return res.status(status).json({
      error: error instanceof Error ? error.message : "Unexpected backend error.",
    });
  }
});

app.listen(PORT, () => {
  console.log(
    `CIVICSETU auto-report proxy running at http://localhost:${PORT}`,
  );
});

function buildPrompt({ languageCode, reviewWindowSeconds, user, location }) {
  return [
    "You are an expert civic issue image analyst for a public issue reporting app.",
    `Write title and description in ${mapLanguage(languageCode)}.`,
    "Only use evidence visible in the image. Do not hallucinate hidden details.",
    "Allowed categories are exactly: road, water, electricity, sanitation.",
    "First decide whether the image clearly shows a real civic issue.",
    "If the image is not a real civic issue photo, is a screenshot, is unrelated, is too blurry, or the issue type is unclear, set:",
    "- is_civic_issue=false",
    "- specific_issue_type=unclear_or_non_civic",
    "- should_update_category=false",
    "- needs_manual_review=true",
    "- auto_submit_recommended=false",
    "- confidence <= 0.35",
    "If the image is a real civic issue, choose one specific_issue_type from this exact list:",
    `- ${SPECIFIC_ISSUE_TYPES.join(", ")}`,
    "Specific issue guidance:",
    "- road -> pothole, road_damage, road_crack",
    "- sanitation -> garbage_dump, litter_accumulation",
    "- water -> sewage_overflow, sewage_pipe_damage, water_leakage, waterlogging",
    "- electricity -> damaged_streetlight, broken_electric_pole, transformer_damage, electric_sparking, damaged_electric_wire",
    "Only set should_update_category=true when the civic issue is visually clear and specific enough to trust the category.",
    "Set needs_manual_review=true if the image is unclear, mixed, or confidence is low.",
    "Set auto_submit_recommended=true only when the issue is obvious and specific enough for a safe auto-drafted complaint.",
    `Set review_window_seconds to ${reviewWindowSeconds}.`,
    `User context: ${JSON.stringify(user ?? {})}`,
    `Location context: ${JSON.stringify(location ?? {})}`,
  ].join("\n");
}

function resolveProvider(rawProvider) {
  const requestedProvider = `${rawProvider || ""}`.trim().toLowerCase();
  if (requestedProvider === "openai" || requestedProvider === "gemini") {
    return requestedProvider;
  }
  return GEMINI_API_KEY ? "gemini" : "openai";
}

function getProviderConfig() {
  if (AI_PROVIDER === "gemini") {
    return {
      provider: "gemini",
      providerDisplayName: "Gemini",
      apiKey: GEMINI_API_KEY,
      model: GEMINI_MODEL,
    };
  }
  return {
    provider: "openai",
    providerDisplayName: "OpenAI",
    apiKey: OPENAI_API_KEY,
    model: OPENAI_MODEL,
  };
}

async function analyzeWithOpenAI({ apiKey, model, prompt, imageBase64, mimeType }) {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: prompt,
            },
            {
              type: "input_image",
              image_url: `data:${mimeType};base64,${imageBase64}`,
              detail: "high",
            },
          ],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "civic_auto_report",
          strict: true,
          schema: buildOutputSchema(),
        },
      },
    }),
  });
  const rawResponseText = await response.text();
  const payload = tryParseJson(rawResponseText);
  if (!response.ok) {
    const errorMessage = extractApiError(
      payload,
      rawResponseText,
      response.status,
      response.statusText,
      "OpenAI",
    );
    console.error(
      `[auto-report-proxy] OpenAI upstream error ${response.status} ${response.statusText}: ${errorMessage}`,
    );
    throw new UpstreamHttpError(response.status, errorMessage);
  }

  const rawText = extractOutputText(payload);
  if (!rawText) {
    throw new UpstreamHttpError(502, "OpenAI did not return structured output text.");
  }

  return {
    parsed: parseStructuredText(rawText, "OpenAI"),
    providerLabel: `OpenAI ${model}`,
  };
}

async function analyzeWithGemini({ apiKey, model, prompt, imageBase64, mimeType }) {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseJsonSchema: buildOutputSchema(),
        },
      }),
    },
  );
  const rawResponseText = await response.text();
  const payload = tryParseJson(rawResponseText);
  if (!response.ok) {
    const errorMessage = extractApiError(
      payload,
      rawResponseText,
      response.status,
      response.statusText,
      "Gemini",
    );
    console.error(
      `[auto-report-proxy] Gemini upstream error ${response.status} ${response.statusText}: ${errorMessage}`,
    );
    throw new UpstreamHttpError(response.status, errorMessage);
  }

  const rawText = extractGeminiOutputText(payload);
  if (!rawText) {
    throw new UpstreamHttpError(502, "Gemini did not return structured output text.");
  }

  return {
    parsed: parseStructuredText(rawText, "Gemini"),
    providerLabel: `Gemini ${model}`,
  };
}

function buildOutputSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "category",
      "title",
      "description",
      "urgency",
      "confidence",
      "is_civic_issue",
      "specific_issue_type",
      "should_update_category",
      "detected_objects",
      "summary",
      "reasoning",
      "needs_manual_review",
      "auto_submit_recommended",
      "review_window_seconds",
    ],
    properties: {
      category: {
        type: "string",
        enum: ["road", "water", "electricity", "sanitation"],
      },
      title: { type: "string" },
      description: { type: "string" },
      urgency: {
        type: "string",
        enum: ["high", "medium", "low"],
      },
      confidence: { type: "number" },
      is_civic_issue: { type: "boolean" },
      specific_issue_type: {
        type: "string",
        enum: SPECIFIC_ISSUE_TYPES,
      },
      should_update_category: { type: "boolean" },
      detected_objects: {
        type: "array",
        items: { type: "string" },
      },
      summary: { type: "string" },
      reasoning: { type: "string" },
      needs_manual_review: { type: "boolean" },
      auto_submit_recommended: { type: "boolean" },
      review_window_seconds: { type: "integer" },
    },
  };
}

function parseStructuredText(rawText, providerDisplayName) {
  try {
    return JSON.parse(rawText);
  } catch (_error) {
    throw new UpstreamHttpError(502, `${providerDisplayName} returned invalid JSON output.`);
  }
}

function mapLanguage(code) {
  switch ((code || "").toLowerCase()) {
    case "hi":
      return "Hindi";
    case "ta":
      return "Tamil";
    case "mr":
      return "Marathi";
    case "kn":
      return "Kannada";
    default:
      return "English";
  }
}

function clampWindow(value) {
  const parsed = Number.parseInt(`${value || ""}`, 10);
  if (Number.isNaN(parsed)) {
    return 5;
  }
  return Math.min(10, Math.max(3, parsed));
}

function stringValue(value) {
  return typeof value === "string" ? value.trim() : "";
}

function extractApiError(
  payload,
  rawResponseText = "",
  status = 0,
  statusText = "",
  providerDisplayName = "Upstream provider",
) {
  if (payload && typeof payload === "object") {
    if (typeof payload.error === "string") {
      return payload.error;
    }
    if (payload.error && typeof payload.error.message === "string") {
      return payload.error.message;
    }
  }
  const fallback = `${rawResponseText || ""}`.trim();
  if (fallback) {
    return fallback.slice(0, 400);
  }
  const normalizedStatusText = `${statusText || ""}`.trim();
  if (status || normalizedStatusText) {
    return `${providerDisplayName} request failed with HTTP ${status}${normalizedStatusText ? ` ${normalizedStatusText}` : ""}.`;
  }
  return `${providerDisplayName} request failed.`;
}

function tryParseJson(value) {
  try {
    return JSON.parse(value);
  } catch (_error) {
    return null;
  }
}

function extractOutputText(payload) {
  if (payload && typeof payload.output_text === "string" && payload.output_text.trim()) {
    return payload.output_text.trim();
  }
  if (!payload || !Array.isArray(payload.output)) {
    return "";
  }
  const chunks = [];
  for (const item of payload.output) {
    if (!item || !Array.isArray(item.content)) {
      continue;
    }
    for (const content of item.content) {
      if (
        content &&
        content.type === "output_text" &&
        typeof content.text === "string"
      ) {
        chunks.push(content.text);
      }
    }
  }
  return chunks.join("").trim();
}

function extractGeminiOutputText(payload) {
  if (!payload || !Array.isArray(payload.candidates)) {
    return "";
  }

  const chunks = [];
  for (const candidate of payload.candidates) {
    if (!candidate || !candidate.content || !Array.isArray(candidate.content.parts)) {
      continue;
    }
    for (const part of candidate.content.parts) {
      if (part && typeof part.text === "string" && part.text.trim()) {
        chunks.push(part.text);
      }
    }
  }

  return chunks.join("").trim();
}

function normalizeDraft(parsed, { providerLabel, reviewWindowSeconds }) {
  const specificIssueType = normalizeSpecificIssueType(parsed);
  const derivedCategory = deriveCategory(parsed, specificIssueType);
  const isCivicIssue =
    Boolean(parsed.is_civic_issue) &&
    specificIssueType !== "unclear_or_non_civic";
  const confidence = clampNumber(
    parsed.confidence,
    isCivicIssue ? 0 : 0,
    1,
  );
  const needsManualReview =
    Boolean(parsed.needs_manual_review) ||
    !isCivicIssue ||
    confidence < 0.7;
  const shouldUpdateCategory =
    Boolean(parsed.should_update_category) &&
    isCivicIssue &&
    specificIssueType !== "unclear_or_non_civic";

  return {
    category: derivedCategory,
    title:
      cleanText(parsed.title, 90) ||
      (isCivicIssue
        ? fallbackTitleForIssueType(specificIssueType)
        : "Manual review required"),
    description:
      cleanText(parsed.description, 280) ||
      (isCivicIssue
        ? fallbackDescriptionForIssueType(specificIssueType)
        : "The uploaded image does not clearly show a supported civic issue. Please review the photo manually before filing."),
    urgency: allowedValue(parsed.urgency, ["high", "medium", "low"], "medium"),
    confidence,
    isCivicIssue,
    specificIssueType,
    shouldUpdateCategory,
    detectedObjects: Array.isArray(parsed.detected_objects)
      ? parsed.detected_objects
          .map((value) => `${value}`.trim())
          .filter(Boolean)
          .slice(0, 8)
      : [],
    summary:
      cleanText(parsed.summary, 180) ||
      (isCivicIssue
        ? "Complaint draft generated from visible civic issue evidence in the uploaded image."
        : "The uploaded image needs manual review because a supported civic issue was not clearly confirmed."),
    reasoning:
      cleanText(parsed.reasoning, 220) ||
      (isCivicIssue
        ? "The issue draft was based on the clearly visible objects and scene context."
        : "The visible scene did not provide enough reliable evidence to auto-classify a supported civic issue."),
    providerLabel,
    needsManualReview,
    autoSubmitRecommended:
      Boolean(parsed.auto_submit_recommended) &&
      shouldUpdateCategory &&
      !needsManualReview &&
      confidence >= 0.85,
    reviewWindowSeconds,
  };
}

function normalizeSpecificIssueType(parsed) {
  const direct = allowedValue(
    parsed.specific_issue_type,
    SPECIFIC_ISSUE_TYPES,
    "",
  );
  if (direct) {
    return direct;
  }

  const combinedText = [
    parsed.category,
    parsed.title,
    parsed.description,
    parsed.summary,
    parsed.reasoning,
    ...(Array.isArray(parsed.detected_objects) ? parsed.detected_objects : []),
  ]
    .map((value) => `${value || ""}`.toLowerCase())
    .join(" ");

  const issueTypeMatchers = [
    ["pothole", /(pothole|sinkhole|deep hole)/],
    ["road_damage", /(road damage|damaged road|broken road|surface damage)/],
    ["road_crack", /(road crack|cracked road|large crack|road surface crack)/],
    ["garbage_dump", /(garbage dump|trash pile|waste pile|garbage pile|heap of garbage|dumped garbage)/],
    ["litter_accumulation", /(litter|waste accumulation|trash accumulation|roadside trash)/],
    ["sewage_overflow", /(sewage overflow|sewer overflow|overflowing sewage|drain overflow)/],
    ["sewage_pipe_damage", /(sewage pipe|broken sewer pipe|damaged sewer pipe|damaged drainage pipe)/],
    ["water_leakage", /(water leak|water leakage|burst pipe|pipe leakage)/],
    ["waterlogging", /(waterlogging|water logged|flooded road|standing water)/],
    ["damaged_streetlight", /(damaged streetlight|broken streetlight|street light damage|streetlight not working)/],
    ["broken_electric_pole", /(broken electric pole|damaged pole|tilted pole|electric pole damage)/],
    ["transformer_damage", /(transformer damage|damaged transformer|burnt transformer|transformer fault)/],
    ["electric_sparking", /(electric sparking|electrical spark|sparking wire|short circuit)/],
    ["damaged_electric_wire", /(damaged wire|exposed wire|hanging wire|electric wire damage|broken wire)/],
  ];

  for (const [issueType, matcher] of issueTypeMatchers) {
    if (matcher.test(combinedText)) {
      return issueType;
    }
  }

  return "unclear_or_non_civic";
}

function deriveCategory(parsed, specificIssueType) {
  const mappedCategory = categoryForIssueType(specificIssueType);
  if (mappedCategory) {
    return mappedCategory;
  }
  return allowedValue(
    parsed.category,
    ["road", "water", "electricity", "sanitation"],
    "road",
  );
}

function categoryForIssueType(issueType) {
  switch (`${issueType || ""}`.trim().toLowerCase()) {
    case "pothole":
    case "road_damage":
    case "road_crack":
      return "road";
    case "garbage_dump":
    case "litter_accumulation":
      return "sanitation";
    case "sewage_overflow":
    case "sewage_pipe_damage":
    case "water_leakage":
    case "waterlogging":
      return "water";
    case "damaged_streetlight":
    case "broken_electric_pole":
    case "transformer_damage":
    case "electric_sparking":
    case "damaged_electric_wire":
      return "electricity";
    default:
      return "";
  }
}

function fallbackTitleForIssueType(issueType) {
  switch (issueType) {
    case "pothole":
      return "Road pothole detected";
    case "road_damage":
      return "Road damage detected";
    case "road_crack":
      return "Road crack detected";
    case "garbage_dump":
      return "Garbage dump detected";
    case "litter_accumulation":
      return "Roadside litter accumulation detected";
    case "sewage_overflow":
      return "Sewage overflow detected";
    case "sewage_pipe_damage":
      return "Damaged sewage pipe detected";
    case "water_leakage":
      return "Water leakage detected";
    case "waterlogging":
      return "Waterlogging detected";
    case "damaged_streetlight":
      return "Damaged streetlight detected";
    case "broken_electric_pole":
      return "Broken electric pole detected";
    case "transformer_damage":
      return "Transformer damage detected";
    case "electric_sparking":
      return "Electric sparking detected";
    case "damaged_electric_wire":
      return "Damaged electric wire detected";
    default:
      return "Civic issue detected";
  }
}

function fallbackDescriptionForIssueType(issueType) {
  switch (issueType) {
    case "pothole":
      return "A pothole is visible on the road surface and may create a safety risk for vehicles and pedestrians.";
    case "road_damage":
      return "Visible road surface damage appears to require civic repair and inspection.";
    case "road_crack":
      return "A visible crack or split appears on the road surface and may worsen without repair.";
    case "garbage_dump":
      return "A visible garbage dump is present in the public area and needs sanitation cleanup.";
    case "litter_accumulation":
      return "Visible litter and waste accumulation appear to require sanitation cleanup.";
    case "sewage_overflow":
      return "Visible sewage overflow appears to be affecting the public area and needs urgent attention.";
    case "sewage_pipe_damage":
      return "A damaged sewage or drainage pipe appears visible and requires civic repair.";
    case "water_leakage":
      return "Visible water leakage appears to require inspection and repair.";
    case "waterlogging":
      return "Water has accumulated in the public area and may affect movement or safety.";
    case "damaged_streetlight":
      return "A streetlight appears damaged or non-functional and may need electrical maintenance.";
    case "broken_electric_pole":
      return "An electric pole appears damaged and may pose a safety risk.";
    case "transformer_damage":
      return "A transformer appears damaged and may require urgent electrical inspection.";
    case "electric_sparking":
      return "Visible electrical sparking suggests an urgent electrical safety risk.";
    case "damaged_electric_wire":
      return "A damaged or exposed electric wire appears visible and may pose a safety hazard.";
    default:
      return "Potential civic issue detected from the uploaded image. Please review before filing.";
  }
}

function cleanText(value, maxLength) {
  const text = `${value || ""}`.replace(/\s+/g, " ").trim();
  if (!text) {
    return "";
  }
  return text.slice(0, maxLength);
}

function allowedValue(value, allowed, fallback) {
  const text = `${value || ""}`.trim().toLowerCase();
  return allowed.includes(text) ? text : fallback;
}

function clampNumber(value, min, max) {
  const parsed = Number.parseFloat(`${value ?? ""}`);
  if (Number.isNaN(parsed)) {
    return min;
  }
  return Math.min(max, Math.max(min, parsed));
}

class UpstreamHttpError extends Error {
  constructor(status, message) {
    super(message);
    this.name = "UpstreamHttpError";
    this.status = status;
  }
}
