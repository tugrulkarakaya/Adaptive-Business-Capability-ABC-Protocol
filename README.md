# Technical Specification: Adaptive Business Capability (ABC) Protocol

**Version:** 1.0.0 (Draft)  
**Type:** Interface Description Language (IDL)  
**Target Architecture:** Server-Driven, LLM-Assisted, Multi-Modal Clients  
**Date:** December 2025

---

## 1. Executive Summary

This standard defines a protocol for decoupling **Business Logic** from **User Experience**. Unlike traditional Server-Driven UI (SDUI) approaches which dictate specific visual components (e.g., "Red Button"), the ABC Protocol transmits **Semantic Intent** (e.g., "Critical Confirmation").

[cite_start]This enables the client (Mobile, Web, Voice Agent) to generate the optimal interface dynamically based on user preferences, device capabilities, and accessibility needs [cite: 16-25].

### 1.1 Core Philosophy
* **Separation of Concerns:**
    * **Data Structure:** Handled by standard OpenAPI/Swagger specifications (Standard A).
    * **User Experience:** Handled by the **ABC Protocol** (Standard B).
* [cite_start]**Deterministic Logic:** The flow of steps, business rules, and validation constraints are rigid and defined by the backend[cite: 51].
* [cite_start]**Adaptive Presentation:** The visual rendering is flexible and decided by the Client/LLM logic [cite: 45-50].

---

## 2. Architecture & Data Flow

The architecture consists of three distinct layers:

1.  **The Service Layer (Backend):** Exposes atomic operations (e.g., `POST /create-user`) defined via OpenAPI. [cite_start]This layer handles the core execution and data persistence [cite: 6-12].
2.  [cite_start]**The Experience Layer (ABC Protocol):** A YAML-based manifest that groups API calls into a "User Journey," adding validation messages, human-readable instructions, and UI behavior hints [cite: 6-12].
3.  [cite_start]**The Client Layer (Flutter):** Consumes the Experience definition and renders native widgets using a "Block-Based Renderer" pattern .

---

## 3. The Primitives Registry

The standard forbids the use of specific UI terms (e.g., "Dropdown", "Modal"). Instead, it utilizes **10 Semantic Primitives**. [cite_start]The Client maps these primitives to the appropriate UI component based on the current `InteractionMode` (Visual, Voice, Hybrid).

| # | Primitive Type | Definition | Visual Example | Voice/Chat Example |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `ValueInput` | Entry of raw data (text, numbers). | `TextField` | "Please say your name." |
| **2** | `Selection` | Choosing from a defined set of options. | `Dropdown`, `Radio`, `Chips` | "Would you like A or B?" |
| **3** | `Confirmation` | Boolean consent for a specific action. | `Switch`, `Checkbox` | "Say 'Yes' to agree." |
| **4** | `Quantifier` | Numeric input relative to min/max limits. | `Slider`, `Stepper` | "Increase amount to 50." |
| **5** | `Temporal` | Date, time, or duration selection. | `DatePicker`, `Clock` | "Next Friday at 2 PM." |
| **6** | `MediaCapture` | Input from hardware sensors. | `CameraPreview`, `MicButton` | "I'm listening..." |
| **7** | `Instruction` | Passive informational content. | `TextBlock`, `Banner` | (TTS reads text) |
| **8** | `Status` | Feedback on system state/progress. | `ProgressBar`, `Spinner` | "Processing, please wait." |
| **9** | `Navigation` | Moving between contexts or resources. | `Link`, `Tab`, `ListTile` | "Go to Settings." |
| **10** | `ActionTrigger` | Executing a finalized capability. | `Button` (Primary/Ghost) | "Submit Application." |

---

## 4. Intent & Behavior Metadata

[cite_start]To support personalization (high contrast, voice-first, large font) [cite: 17-24], every Primitive carries "Intent Attributes."

### 4.1 Criticality
Defines the consequence of the interaction.
* `low`: Reversible, trivial (e.g., Search filter).
* `medium`: Standard data entry (e.g., Profile update).
* `irreversible`: Dangerous (e.g., Transfer money, Delete account). [cite_start]*Client must enforce "Step-up Auth" or explicit confirmation.* [cite: 40]

### 4.2 Privacy
Defines how data is displayed or spoken.
* `public`: Safe to display/speak anywhere.
* `sensitive`: Mask on screen (****), do not speak aloud in Voice Mode.

### 4.3 Urgency
Defines the flow control.
* `passive`: Can be ignored (e.g., optional survey).
* `blocking`: User cannot proceed until resolved (e.g., Terms of Service).

---

## 5. Protocol Schema (YAML)

The definition file must adhere to the following structure.

```yaml
capability_id: string       # Unique ID for this flow
version: string             # Semantic versioning
meta:
  title: string             # Human-readable title
  [cite_start]description: string       # Context for the LLM [cite: 43-45]
  
steps:                      # Ordered list of logical groups
  - step_id: string
    instruction: string     # The "Goal" of this step
    primitives:             # List of interactions in this step
      - id: string
        type: PrimitiveType # One of the 10 Primitives
        label: string
        intent:             # Behavioral metadata
          criticality: enum
          privacy: enum
        validation:         # Rules [cite: 9]
          required: boolean
          regex: string
          error_msg: string
        service_ref:        # Mapping to OpenAPI [cite: 7]
          param: string     # Which API field this maps to