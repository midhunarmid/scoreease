# ScoreEase Architecture Overview
[![](https://mermaid.ink/img/pako:eNp1VO9v2jAQ_VcsS52YRNOGhAL5MCkN6Ropowjouh_ZB5MYiJTYke20ZVX_950NgVCxL-Tu3fPd88uRN5zyjGIPrwr-km6IUGgxThhCFxdoOgvn4WThL6KHCYr9n-FMF2S9XAtSbdBUUEmZIirn7HeC2ymKyZaKBP_RBxB6jKD-GKHOXVErRQV6yrM1VfLzgXFb8BQ4tzEPUAeYc-hD0ScUPkNLdE9YVuRs3fApyxK2F-lPp3EU_E-jX1VFnjYSW9lHhZIGRFKpdUqKTIyuUMRALUkVF_LM6LG_8M_MHBNFoI9-fJgyoxWXOXTbQv2Y7MasSEoPzLtc0CWIiMqqAG6TtjqAmQBKCCnSLFo25p9zKfyxCGcTP0bzcPY9CsL5ieLwFeYzoic1IZpT8ZynVJ5IMuPaeg7ggXbPpYJX1SbtIdSRKTApQBYRZZ5ZOTtuwNdc3ddLOLYLzE0_FP1UX08eOXvguEWCv0gq9CLtItgl_euncJHWts21jsdZDEQTLjkRGQIAdai1trroyiBXZJnaPeecn3fxwxMKHiaTMNCbZ-yEtb28_GJWWaf6aYBmtwxnH5vC8WXqUuvV6mJ7A3S5nR8IO-uNqMZkMzHSyN4kDZz4Z5A9fXe2ceukcAo3lrWuiLt4LfIMe0rUtItLKkqiU_ymDydYbWAnE-xBmNEVqQuV4IS9w7GKsF-cl81Jwev1BnsrUkjI6iqD__44J7Cb5QEV4D4VAa-Zwp5ru6YJ9t7wK_ac65Hl2rY76PdHrt13nS7eYs_uWUNn6DjXTu9mZI_6ffe9i_-asdfWaGgPbgbDUW_oDPo9F9rRTHv_bfcxNN_E93-kG6gg?type=png)](https://mermaid.live/edit#pako:eNp1VO9v2jAQ_VcsS52YRNOGhAL5MCkN6Ropowjouh_ZB5MYiJTYke20ZVX_950NgVCxL-Tu3fPd88uRN5zyjGIPrwr-km6IUGgxThhCFxdoOgvn4WThL6KHCYr9n-FMF2S9XAtSbdBUUEmZIirn7HeC2ymKyZaKBP_RBxB6jKD-GKHOXVErRQV6yrM1VfLzgXFb8BQ4tzEPUAeYc-hD0ScUPkNLdE9YVuRs3fApyxK2F-lPp3EU_E-jX1VFnjYSW9lHhZIGRFKpdUqKTIyuUMRALUkVF_LM6LG_8M_MHBNFoI9-fJgyoxWXOXTbQv2Y7MasSEoPzLtc0CWIiMqqAG6TtjqAmQBKCCnSLFo25p9zKfyxCGcTP0bzcPY9CsL5ieLwFeYzoic1IZpT8ZynVJ5IMuPaeg7ggXbPpYJX1SbtIdSRKTApQBYRZZ5ZOTtuwNdc3ddLOLYLzE0_FP1UX08eOXvguEWCv0gq9CLtItgl_euncJHWts21jsdZDEQTLjkRGQIAdai1trroyiBXZJnaPeecn3fxwxMKHiaTMNCbZ-yEtb28_GJWWaf6aYBmtwxnH5vC8WXqUuvV6mJ7A3S5nR8IO-uNqMZkMzHSyN4kDZz4Z5A9fXe2ceukcAo3lrWuiLt4LfIMe0rUtItLKkqiU_ymDydYbWAnE-xBmNEVqQuV4IS9w7GKsF-cl81Jwev1BnsrUkjI6iqD__44J7Cb5QEV4D4VAa-Zwp5ru6YJ9t7wK_ac65Hl2rY76PdHrt13nS7eYs_uWUNn6DjXTu9mZI_6ffe9i_-asdfWaGgPbgbDUW_oDPo9F9rRTHv_bfcxNN_E93-kG6gg)

ScoreEase follows a **Clean Architecture** approach to keep the codebase modular, testable, and scalable.

It is structured in **three primary layers**:

---

## 📌 1. Presentation Layer

Handles everything related to the **UI** and **user interactions**.

| Component             | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `pages` | Visual elements like screens, buttons, and inputs.                         |
| `blocs`                | Converts UI events into state changes. Manages user flows like scoreboard creation and updates. |

---

## 📌 2. Domain Layer

The **business logic layer**, independent of frameworks or Firebase.

| Component                 | Description                                                                 |
|---------------------------|-----------------------------------------------------------------------------|
| `Use Cases` | Contains core application logic (e.g., "Add score to a player"). It coordinates between BLoC and the data layer. |

---

## 📌 3. Data Layer

This layer handles communication with Firebase or other data sources.

| Component                        | Description                                                                 |
|----------------------------------|-----------------------------------------------------------------------------|
| `Repository Interface`           | Defines contracts for operations like `getScoreboard()` or `updatePlayerScore()`. |
| `Firebase Repository Implementation` | Concrete class interacting with Firestore based on the interface.         |

---

## 🌐 External Services

| Service               | Role                                                                 |
|-----------------------|----------------------------------------------------------------------|
| **Firebase Firestore**| Stores scoreboard data, player scores, and score history.            |
| **Firebase Hosting**  | Hosts the web app at [https://scoreease.armid.in](https://scoreease.armid.in) |
| **GitHub + Actions**  | Automates deployment from GitHub to Firebase Hosting.                |
| **Browser Access**    | Scoreboards accessible via shareable URLs (e.g., `/board/abc123`).   |

---

## ✅ Key Features

- Create scoreboards with up to 100 players.
- Real-time live score updates via Firestore.
- Mobile and web-friendly UI using Flutter Web.
- Direct URL support for viewing any scoreboard.
- Free, open-source, and privacy-friendly.

---

## 🧩 Clean Architecture Benefits

- 🔁 **Reusable** logic across platforms (web, Android, iOS).
- 🔍 **Testable** core business logic and data operations.
- 📦 **Modular** structure — easy to extend or replace components.

---

