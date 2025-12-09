# Adaptive Business Capability (ABC) Protocol

**Version:** 2.0.0 - LLM-First Edition  
**Status:** Draft Specification  
**Philosophy:** Minimal definitions, maximum LLM intelligence  
**Date:** December 2025

---

## Table of Contents

1. [Philosophy](#1-philosophy)
2. [The Power Distribution](#2-the-power-distribution)
3. [Schema Overview](#3-schema-overview)
4. [Capability Definition](#4-capability-definition)
5. [Flow & Steps](#5-flow--steps)
6. [Fields & Intent](#6-fields--intent)
7. [Conditions](#7-conditions)
8. [Intent Markers](#8-intent-markers)
9. [Optional LLM Guidance](#9-optional-llm-guidance)
10. [What LLM Handles](#10-what-llm-handles)
11. [Examples](#11-examples)
12. [Comparison](#12-comparison)
13. [FAQ](#13-faq)

---

## 1. Philosophy

### 1.1 The Problem with Traditional Approaches

Traditional Server-Driven UI (SDUI) and even early versions of this protocol fell into a trap: **defining too much**.

```yaml
# Traditional approach - 50+ lines for one field
- id: "email"
  type: ValueInput
  input_type: email
  label: "Email Address"
  placeholder: "you@example.com"
  aria_label: "Your email address"
  voice_prompt: "What is your email?"
  validation:
    required: true
    regex: "^[\\w.-]+@[\\w.-]+\\.\\w+$"
    error_msg: "Please enter a valid email"
    async:
      endpoint: "/api/check-email"
      debounce_ms: 500
  i18n:
    label_key: "field.email.label"
    error_key: "field.email.error"
  # ... 30 more lines
```

This is **not** a business protocol. This is a programming language.

### 1.2 The LLM-First Principle

We already have:
- **OpenAPI specs** that define data types, validation rules, and API contracts
- **LLMs** that can translate, generate UI, craft error messages, and adapt for accessibility

Why duplicate what already exists? Why constrain what LLMs do best?

```yaml
# ABC Protocol v2.0 - Same field
- email
  intent: "Primary contact and login credential"
  sensitivity: sensitive
```

**That's it.** The LLM knows:
- It's an email (from OpenAPI or field name)
- Why we need it (from intent)
- How to protect it (from sensitivity)

### 1.3 Core Beliefs

| Belief | Implication |
|--------|-------------|
| **LLMs are intelligent** | Don't over-specify; give context, not instructions |
| **OpenAPI exists** | Don't redefine data types, validation, endpoints |
| **Less is more** | A 20-line capability beats a 500-line one |
| **Business over technical** | Define WHAT and WHY, not HOW |
| **Optional detail** | Add specifics only when business requires it |

---

## 2. The Power Distribution

### 2.1 What the Protocol Defines

The ABC Protocol is a **business conversation**, not a technical specification.

```
┌─────────────────────────────────────────────────────────────────┐
│              ABC PROTOCOL DEFINES (Business Intent)             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  • WHAT we're trying to accomplish (goal)                       │
│  • WHAT information we need (fields)                            │
│  • WHY we need each piece (intent)                              │
│  • WHAT order things happen (flow)                              │
│  • WHEN to branch or skip (conditions)                          │
│  • WHAT are the consequences (reversibility, sensitivity)       │
│  • WHERE to send data (API reference)                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 What LLM + OpenAPI Handle

Everything else is derived or generated:

```
┌─────────────────────────────────────────────────────────────────┐
│                    LLM DETERMINES (Presentation)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  • HOW to render (UI components, layout)                        │
│  • HOW to phrase questions (natural language)                   │
│  • HOW to translate (any language, on-the-fly)                  │
│  • HOW to explain errors (contextual, helpful)                  │
│  • HOW to adapt for accessibility (screen readers, voice)       │
│  • HOW to recover from failures (retry, alternatives)           │
│  • HOW to group and present fields                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   OPENAPI PROVIDES (Technical)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  • Data types (string, number, enum values)                     │
│  • Validation rules (required, min/max, patterns)               │
│  • API endpoints and methods                                    │
│  • Request/response schemas                                     │
│  • Enum options and allowed values                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 The Beautiful Result

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   ABC Protocol   │     │     OpenAPI      │     │       LLM        │
│   (20-50 lines)  │  +  │   (existing)     │  =  │   (intelligent)  │
│                  │     │                  │     │                  │
│  "What & Why"    │     │  "Data & Rules"  │     │  "How & UX"      │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                  │
                                  ▼
                    ┌──────────────────────────┐
                    │   Complete Experience    │
                    │                          │
                    │  • Multi-platform UI     │
                    │  • Multi-language        │
                    │  • Accessible            │
                    │  • Contextually helpful  │
                    └──────────────────────────┘
```

---

## 3. Schema Overview

### 3.1 Minimal Valid Capability

```yaml
capability: "user-registration"
goal: "Create a new user account"
api: "/openapi.json"

flow:
  - step: "signup"
    collect: [email, password]
    action: "POST /users"
```

**That's a complete, valid ABC Protocol definition.**

### 3.2 Full Schema Structure

```yaml
capability: string          # Unique identifier
goal: string                # Natural language goal description
api: string                 # Reference to OpenAPI spec

context: string             # Optional: Additional business context for LLM

flow:                       # Ordered list of steps
  - step: string            # Step identifier
    ask: string             # Optional: Natural language instruction
    
    collect:                # Fields to gather (simple or detailed)
      - field               # Simple: just the field name
      - field:              # Detailed: with metadata
          intent: string
          sensitivity: enum
          options: [...]    # Override OpenAPI options if needed
    
    condition: expression   # Optional: When to show this step
    action: string          # Optional: API endpoint to call
    consequence: string     # Optional: What happens (for user awareness)
    reversible: boolean     # Optional: Can this be undone?
```

---

## 4. Capability Definition

### 4.1 Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `capability` | string | Unique identifier for this capability |
| `goal` | string | Natural language description of what this accomplishes |
| `flow` | array | Ordered list of steps |

### 4.2 Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `api` | string | URL or path to OpenAPI specification |
| `context` | string | Additional business context for LLM understanding |
| `version` | string | Version of this capability definition |

### 4.3 Examples

**Minimal:**
```yaml
capability: "password-reset"
goal: "Help user reset their forgotten password"
flow:
  - step: "request"
    collect: [email]
    action: "POST /auth/reset-request"
```

**With context:**
```yaml
capability: "loan-application"
goal: "Apply for a personal loan"
api: "https://api.bank.com/openapi.json"

context: |
  This is a regulated financial product. Users may be anxious about 
  financial decisions. Be reassuring but accurate. All fields are 
  required for regulatory compliance - we cannot skip any.

flow:
  # ... steps
```

---

## 5. Flow & Steps

### 5.1 Step Definition

A step represents a logical grouping in the user journey.

```yaml
flow:
  - step: "step-id"           # Required: Unique identifier
    ask: "..."                # Optional: Instruction for user/LLM
    collect: [...]            # Optional: Fields to gather
    condition: "..."          # Optional: When to show this step
    action: "..."             # Optional: API to call
    consequence: "..."        # Optional: What happens
    reversible: true|false    # Optional: Can it be undone
```

### 5.2 The `ask` Field

Natural language instruction. LLM can rephrase, translate, or adapt.

```yaml
# Simple
- step: "contact"
  ask: "How can we reach you?"
  collect: [email, phone]

# Detailed context
- step: "payment"
  ask: "Time to pay - don't worry, this is secure"
  collect: [card_number, expiry, cvv]
```

The LLM might render this as:
- **Visual:** A header "How can we reach you?" with form fields
- **Voice:** "I'll need a way to contact you. What's your email address?"
- **Chat:** "Great! Now, how can we reach you? I'll need your email and optionally a phone number."

### 5.3 Step Actions

Reference API endpoints from your OpenAPI spec:

```yaml
- step: "submit"
  ask: "Review and submit your application"
  action: "POST /applications"
  consequence: "Your application will be submitted for review"
  reversible: false
```

---

## 6. Fields & Intent

### 6.1 Simple Field Reference

Just name the field. LLM + OpenAPI figure out the rest.

```yaml
collect: [email, password, first_name, last_name]
```

The LLM will:
- Get data types from OpenAPI (or infer from field names)
- Generate appropriate UI components
- Create validation messages
- Handle errors contextually

### 6.2 Field with Intent

Add `intent` when the WHY matters for user experience:

```yaml
collect:
  - email:
      intent: "We'll send your receipt and order updates here"
  - phone:
      intent: "Only for delivery driver to contact you"
```

The LLM uses intent to:
- Explain why the field is needed
- Reassure users about data usage
- Provide context in voice/chat interfaces

### 6.3 Field with Sensitivity

Mark fields that need special handling:

```yaml
collect:
  - ssn:
      intent: "Required for tax reporting"
      sensitivity: secret
  - salary:
      intent: "To determine loan eligibility"
      sensitivity: sensitive
  - name:
      sensitivity: public
```

| Sensitivity | LLM Behavior |
|-------------|--------------|
| `public` | Normal display, can speak aloud |
| `sensitive` | Mask on screen, don't speak values |
| `secret` | Secure input, never log, never speak |

### 6.4 Field with Options Override

Sometimes you need specific options not in OpenAPI:

```yaml
collect:
  - account_type:
      intent: "Determines features and pricing"
      options:
        - personal: "For individual use"
        - business: "For teams and companies"
        - enterprise: "Custom solutions for large organizations"
```

### 6.5 Complete Field Schema

```yaml
field_name:
  intent: string              # Why we need this
  sensitivity: enum           # public | sensitive | secret
  consequence: string         # What happens with this data
  options:                    # Override options
    - value: "description"
  required: boolean           # Override OpenAPI required
  default: any                # Default value
```

All fields are **optional**. Use only what you need.

---

## 7. Conditions

### 7.1 Simple Expressions

Conditions control when steps or fields appear. Keep them simple.

```yaml
# Step condition
- step: "business-details"
  condition: "account_type == 'business'"
  collect: [company_name, company_size]

# Field condition (within collect)
- step: "contact"
  collect:
    - email
    - phone:
        condition: "contact_preference == 'phone'"
```

### 7.2 Supported Operators

| Expression | Meaning |
|------------|---------|
| `field == 'value'` | Field equals value |
| `field != 'value'` | Field not equals value |
| `field exists` | Field has a value |
| `field empty` | Field has no value |
| `field in ['a', 'b']` | Field is one of values |

### 7.3 Combining Conditions

```yaml
condition: "account_type == 'business' and country == 'US'"
condition: "age >= 18 or has_guardian == true"
```

### 7.4 Philosophy: Keep It Simple

If you need complex conditions, you're probably doing too much. The protocol is for business flow, not business logic.

**Don't do this:**
```yaml
condition: "(age >= 18 and country in ['US', 'CA']) or (has_guardian and guardian_consent and age >= 16)"
```

**Do this instead:**
```yaml
condition: "eligible == true"  # Let your API determine eligibility
```

---

## 8. Intent Markers

### 8.1 Step-Level Markers

```yaml
- step: "payment"
  ask: "Complete your purchase"
  consequence: "Your card will be charged"
  reversible: false
  collect: [card_number, expiry, cvv]
  action: "POST /payments"
```

| Marker | Purpose | LLM Behavior |
|--------|---------|--------------|
| `consequence` | What happens when step completes | Show warning, require confirmation |
| `reversible` | Can this be undone? | false = extra confirmation |

### 8.2 Field-Level Markers

```yaml
collect:
  - delete_reason:
      intent: "Helps us improve our service"
      consequence: "Account will be permanently deleted"
      sensitivity: public
```

### 8.3 When to Use Markers

| Scenario | Markers to Use |
|----------|----------------|
| Payment processing | `consequence`, `reversible: false` |
| Account deletion | `consequence`, `reversible: false`, `sensitivity` |
| Personal data collection | `intent`, `sensitivity` |
| Data that affects eligibility | `intent`, `consequence` |
| Standard form fields | None needed |

---

## 9. Optional LLM Guidance

### 9.1 When You DON'T Need Guidance

Most of the time, the LLM can figure it out:

```yaml
capability: "contact-form"
goal: "Let users send us a message"
flow:
  - step: "message"
    collect: [name, email, subject, message]
    action: "POST /contact"
```

The LLM knows this is a contact form. It will be friendly and helpful.

### 9.2 When You MIGHT Want Guidance

Add `context` at capability level for special situations:

```yaml
capability: "bereavement-claim"
goal: "Submit a claim following the death of a family member"

context: |
  This is an extremely sensitive process. Users are grieving.
  Be compassionate and patient. Never rush. Offer to pause.
  Use gentle, respectful language. Avoid clinical terms.

flow:
  - step: "deceased-info"
    ask: "I'm sorry for your loss. When you're ready, I'll need some information."
    collect: [...]
```

### 9.3 Optional Tone Hints

```yaml
- step: "celebration"
  ask: "Congratulations! Let's set up your new account."
  tone: celebratory

- step: "error-recovery"  
  ask: "Something went wrong, but don't worry - we can fix this."
  tone: reassuring
```

| Tone | When to Use |
|------|-------------|
| `formal` | Legal, financial, official |
| `friendly` | General consumer apps |
| `celebratory` | Achievements, completions |
| `reassuring` | Errors, sensitive topics |
| `urgent` | Time-sensitive actions |

**Note:** These are hints. The LLM may adapt based on user preferences or platform.

---

## 10. What LLM Handles

This section clarifies what the LLM is expected to generate or determine.

### 10.1 UI Component Selection

The LLM chooses components based on:
- Field type (from OpenAPI or inference)
- Platform (mobile, web, voice)
- User preferences
- Accessibility needs

| Field Type | Mobile | Web | Voice |
|------------|--------|-----|-------|
| email | TextField with keyboard | Input type=email | "What's your email?" |
| country | Bottom sheet picker | Dropdown or search | "Which country?" |
| agree_terms | Switch | Checkbox | "Do you agree? Say yes or no." |
| amount | Slider or stepper | Number input | "How much?" |

### 10.2 Translation

The LLM translates on-the-fly based on user's locale. No i18n keys needed.

```yaml
ask: "What's your name?"  # English definition

# LLM outputs:
# Spanish: "¿Cómo te llamas?"
# French: "Comment vous appelez-vous?"
# Japanese: "お名前は何ですか？"
```

### 10.3 Validation Messages

Instead of:
```yaml
# Old way - defining every message
error_msg: "Please enter a valid email address"
error_msg_es: "Por favor ingrese una dirección de correo válida"
```

The LLM generates contextual messages:
```
# User enters "abc"
LLM: "Hmm, that doesn't look like an email. It should have an @ symbol, like name@example.com"

# User enters "abc@"  
LLM: "Almost there! Just need the domain part, like @gmail.com"
```

### 10.4 Error Recovery

When API calls fail:

```yaml
action: "POST /payment"
# If it fails, LLM handles:
# - "Your payment didn't go through. Would you like to try again or use a different card?"
# - "We're having trouble connecting. I've saved your info - try again in a moment?"
```

### 10.5 Accessibility

LLM automatically:
- Generates ARIA labels from field names and intent
- Creates voice prompts from ask text
- Adapts for screen readers
- Respects reduced motion preferences
- Adjusts for cognitive accessibility

### 10.6 Conversational Flow

For voice/chat interfaces, LLM determines:
- How many fields to ask at once
- How to confirm inputs
- How to handle corrections
- Natural transitions between steps

---

## 11. Examples

### 11.1 Minimal Example (10 lines)

```yaml
capability: "newsletter-signup"
goal: "Subscribe to our newsletter"
api: "/openapi.json"

flow:
  - step: "subscribe"
    ask: "Join our newsletter"
    collect: [email]
    action: "POST /newsletter/subscribe"
```

### 11.2 Standard Example (30 lines)

```yaml
capability: "user-registration"
goal: "Create a new user account"
api: "/openapi.json"

flow:
  - step: "account-type"
    ask: "What type of account would you like?"
    collect:
      - account_type:
          options:
            - personal: "For individual use"
            - business: "For teams and companies"

  - step: "credentials"
    ask: "Set up your login"
    collect:
      - email:
          intent: "This will be your username"
      - password:
          sensitivity: secret

  - step: "business-info"
    condition: "account_type == 'business'"
    ask: "Tell us about your business"
    collect: [company_name, company_size, tax_id]

  - step: "complete"
    ask: "Create your account"
    action: "POST /users"
    consequence: "Your account will be created"
```

### 11.3 Detailed Example with Context (50 lines)

```yaml
capability: "loan-application"
goal: "Apply for a personal loan"
api: "https://api.bank.com/v1/openapi.json"
version: "1.0.0"

context: |
  This is a regulated financial product requiring full disclosure.
  Users may be anxious about financial decisions - be supportive.
  All fields are mandatory for regulatory compliance.
  If users seem hesitant, explain why each field is needed.

flow:
  - step: "loan-details"
    ask: "Let's find the right loan for you"
    collect:
      - loan_amount:
          intent: "How much do you need to borrow?"
      - loan_purpose:
          intent: "Helps us find the best rate for your needs"
      - loan_term:
          intent: "Longer terms mean lower monthly payments"

  - step: "personal-info"
    ask: "A bit about yourself"
    collect:
      - full_name
      - date_of_birth:
          intent: "Required to verify your identity"
      - ssn:
          intent: "Required for credit check - we use bank-level security"
          sensitivity: secret

  - step: "financial-info"
    ask: "Your financial situation"
    collect:
      - annual_income:
          intent: "Helps determine what you can comfortably afford"
          sensitivity: sensitive
      - employment_status
      - employer_name:
          condition: "employment_status == 'employed'"

  - step: "review"
    ask: "Review your application"
    action: "POST /loans/applications"
    consequence: "A credit check will be performed"
    reversible: false
```

### 11.4 E-Commerce Checkout

```yaml
capability: "checkout"
goal: "Complete your purchase"
api: "/api/openapi.json"

flow:
  - step: "shipping"
    ask: "Where should we send your order?"
    collect:
      - shipping_address:
          intent: "Delivery address for your items"
      - shipping_method:
          intent: "Faster shipping costs more"

  - step: "payment"
    ask: "How would you like to pay?"
    collect:
      - payment_method:
          options:
            - card: "Credit or debit card"
            - paypal: "PayPal"
            - apple_pay: "Apple Pay"
      - card_number:
          condition: "payment_method == 'card'"
          sensitivity: secret
      - card_expiry:
          condition: "payment_method == 'card'"
          sensitivity: sensitive
      - card_cvv:
          condition: "payment_method == 'card'"
          sensitivity: secret

  - step: "confirm"
    ask: "Place your order"
    action: "POST /orders"
    consequence: "Your payment will be processed"
    reversible: false
```

### 11.5 Multi-Step Wizard with Branching

```yaml
capability: "insurance-quote"
goal: "Get an insurance quote"

flow:
  - step: "insurance-type"
    ask: "What do you want to insure?"
    collect:
      - insurance_type:
          options:
            - auto: "Car or motorcycle"
            - home: "House or apartment"  
            - life: "Life insurance"

  # Auto insurance branch
  - step: "vehicle-info"
    condition: "insurance_type == 'auto'"
    ask: "Tell us about your vehicle"
    collect: [vehicle_make, vehicle_model, vehicle_year, mileage]

  - step: "driving-history"
    condition: "insurance_type == 'auto'"
    ask: "Your driving history"
    collect: [license_years, accidents_last_5_years, tickets_last_3_years]

  # Home insurance branch
  - step: "property-info"
    condition: "insurance_type == 'home'"
    ask: "About your property"
    collect: [property_type, square_footage, year_built, property_value]

  - step: "coverage-options"
    condition: "insurance_type == 'home'"
    ask: "What coverage do you need?"
    collect: [coverage_level, deductible_amount]

  # Life insurance branch  
  - step: "personal-health"
    condition: "insurance_type == 'life'"
    ask: "A few health questions"
    collect: [age, smoker_status, health_conditions]

  - step: "coverage-amount"
    condition: "insurance_type == 'life'"
    ask: "How much coverage?"
    collect: [coverage_amount, term_length]

  # Common final step
  - step: "contact"
    ask: "How can we send your quote?"
    collect:
      - email:
          intent: "We'll send your personalized quote here"
      - phone:
          intent: "For questions about your quote"

  - step: "get-quote"
    action: "POST /quotes"
    ask: "Get your quote"
```

---

## 12. Comparison

### 12.1 Traditional SDUI vs ABC v1.0 vs ABC v2.0

**Scenario:** Collect user's email for registration

#### Traditional SDUI (Server-Driven UI)
```json
{
  "type": "text_field",
  "id": "email_input",
  "label": "Email Address",
  "placeholder": "you@example.com",
  "keyboard_type": "email",
  "validation": {
    "required": true,
    "pattern": "^[\\w.-]+@[\\w.-]+\\.\\w+$",
    "error_message": "Please enter a valid email"
  },
  "style": {
    "margin_top": 16,
    "margin_bottom": 8,
    "border_radius": 8
  },
  "accessibility": {
    "label": "Email address input field",
    "hint": "Enter your email address for account registration"
  }
}
```
**Lines: 20 | Problem: Dictates everything, no flexibility**

#### ABC Protocol v1.0
```yaml
- id: "email"
  type: ValueInput
  input_type: email
  label: "Email Address"
  placeholder: "you@example.com"
  intent:
    criticality: medium
    privacy: sensitive
  validation:
    required: true
    regex: "^[\\w.-]+@[\\w.-]+\\.\\w+$"
    error_msg: "Please enter a valid email"
  a11y:
    aria_label: "Your email address"
    voice_prompt: "What is your email?"
  service_ref:
    param: "email"
```
**Lines: 18 | Problem: Still too technical, duplicates OpenAPI**

#### ABC Protocol v2.0 (LLM-First)
```yaml
- email:
    intent: "This will be your login"
    sensitivity: sensitive
```
**Lines: 3 | Win: Business intent only, LLM handles the rest**

Or even simpler:
```yaml
- email
```
**Lines: 1 | Win: OpenAPI + LLM do everything**

### 12.2 Full Flow Comparison

**Scenario:** User registration with account type selection

#### Traditional SDUI: ~200 lines
#### ABC v1.0: ~100 lines  
#### ABC v2.0: ~25 lines

```yaml
capability: "registration"
goal: "Create a new account"

flow:
  - step: "type"
    ask: "What type of account?"
    collect:
      - account_type:
          options: [personal, business]

  - step: "info"
    ask: "Your information"
    collect:
      - email:
          intent: "Your login"
      - password:
          sensitivity: secret

  - step: "business"
    condition: "account_type == 'business'"
    collect: [company_name]

  - step: "create"
    action: "POST /users"
```

### 12.3 What You Gain

| Metric | Traditional | ABC v1.0 | ABC v2.0 |
|--------|-------------|----------|----------|
| Lines of code | 200+ | 100+ | 20-50 |
| Time to create | Hours | 30 min | 5 min |
| Flexibility | None | Some | Maximum |
| LLM intelligence | Ignored | Limited | Full |
| Translation | Manual | i18n keys | Automatic |
| Accessibility | Manual | Manual | Automatic |
| Maintenance | High | Medium | Low |

---

## 13. FAQ

### Q: What if I need specific validation?

**A:** OpenAPI should define validation. If you have a special case:

```yaml
- promo_code:
    validation_hint: "Must start with PROMO- followed by 6 digits"
```

The LLM will communicate this to users appropriately.

### Q: What if I need specific UI components?

**A:** You probably don't. But if you really do:

```yaml
- rating:
    ui_hint: "star-rating"  # Suggest, don't mandate
```

The LLM will try to honor this but may adapt for platform/accessibility.

### Q: How do I handle complex business logic?

**A:** In your API, not the protocol. The ABC Protocol is for flow, not logic.

```yaml
# Don't do this
condition: "age >= 18 and (country == 'US' or has_guardian)"

# Do this
- step: "eligibility-check"
  action: "POST /check-eligibility"

- step: "proceed"
  condition: "eligible == true"
```

### Q: What if the LLM makes mistakes?

**A:** The protocol ensures:
- Business flow is deterministic
- Required fields must be collected
- Actions only fire when flow completes
- Consequences are shown before irreversible actions

The LLM only controls presentation, not business logic.

### Q: How do I test this?

**A:** Test your API (OpenAPI contract testing) and your flow logic. The LLM's presentation adapts to context - that's a feature, not a bug.

### Q: Can I add more detail if I want?

**A:** Yes! Everything is optional. Start minimal, add detail only when needed.

```yaml
# Minimal
- email

# With intent
- email:
    intent: "For order updates"

# With everything
- email:
    intent: "For order updates"
    sensitivity: sensitive
    consequence: "We'll send marketing emails unless you opt out"
    required: true
```

### Q: What about analytics/tracking?

**A:** Your API and client handle this. The protocol doesn't need to know about tracking.

### Q: What about state management / saving progress?

**A:** Client implementation detail. The protocol defines flow; the client decides how to persist.

---

## Summary

The ABC Protocol v2.0 is a **minimal, business-focused** specification that:

1. **Defines intent**, not implementation
2. **Trusts LLMs** to handle presentation
3. **Leverages OpenAPI** for technical specs
4. **Keeps it simple** - 20-50 lines for most capabilities
5. **Allows detail** when business requires it

The result: faster development, better UX, and truly adaptive interfaces across all platforms and modalities.

---

## Document Information

| Property | Value |
|----------|-------|
| **Version** | 2.0.0 - LLM-First Edition |
| **Status** | Draft |
| **License** | MIT |
| **Repository** | https://github.com/tugrulkarakaya/Adaptive-Business-Capability-ABC-Protocol |

---

*Less specification, more intelligence. That's the ABC Protocol v2.0.*
