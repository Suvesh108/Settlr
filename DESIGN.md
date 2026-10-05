# Design System

<!-- impeccable:design-schema 1 -->

## Design Direction & Archetype

**Archetype**: Soft Structuralism & SaasInterface Clean Architecture
- **Inspiration**: saasinterface.com, Linear, Raycast, Apple iOS modal sheets, ReactBits, Aceternity UI, MagicUI, Uiverse.
- **Surface Vibe**: Crisp snow-white surfaces (`#ffffff`), subtle mist backgrounds (`#fafafa`), hairline structural borders (`#e5e5e5`), and diffused ambient depth (`box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.05)`).
- **Zero AI-Slop Directives**: No generic purple-to-blue gradients, no harsh drop-shadows, no unpadded cramped inputs, and no raw default browser select controls.

## Typography & Hierarchy

- **Font Family**: Inter, Plus Jakarta Sans, system UI sans-serif.
- **Numbers & Monies**: Bold tabular figures with prominent currency badges (`₹`, `$`, `€`).
- **Eyebrows**: Microcaps (`text-[10px] font-bold uppercase tracking-wider text-neutral-400`).

## Color Tokens

- **Canvas**: `#fafafa` (Neutral 50)
- **Cards & Surfaces**: `#ffffff` (Pure White)
- **Borders**: `#e5e5e5` (Neutral 200), `#f5f5f5` (Neutral 100 on inner borders)
- **Typography Primary**: `#171717` (Neutral 900)
- **Typography Muted**: `#737373` (Neutral 500)
- **Action / Primary**: `#0ea5e9` (Sky 500 / Sky 600)
- **Success / Settled**: `#10b981` (Emerald 500 / Emerald 600)
- **Debt / Warning**: `#f43f5e` (Rose 500 / Rose 600)
- **Simulate / Highlight**: `#f59e0b` (Amber 500 / Amber 600)

## Component Library Standards

1. **AirPods-Style Floating Card (`SmartSpendPopup`)**:
   - `rounded-t-[32px] sm:rounded-[32px]`, `backdrop-blur-xl`, dismiss pill handle, 1-tap allocation toggle.
2. **Mobile Dock Navigation (`MobileNavigation`)**:
   - Floating center action CTA with glowing elevation, 4 primary views (Overview, Expenses, Settle, Activity).
3. **Double-Bezel Card Hierarchy**:
   - Concentric radii with hairline borders, generous macro-padding (`p-4` to `p-6`).
4. **Universal Custom Selects**:
   - Stripped native OS styling (`appearance-none`), absolute centered `ChevronDown` vector indicators, pure white popover option containers.
