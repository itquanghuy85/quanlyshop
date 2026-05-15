# ROADMAP - HULUCA Shop Manager

Lộ trình phát triển, milestones, features planned, timeline.

---

## Vision

HULUCA Shop Manager là nền tảng quản lý cửa hàng sửa chữa điện thoại hàng đầu tại Việt Nam, với:
- ✓ Quản lý đơn sửa chi tiết
- ✓ Kiểm soát kho hàng thực
- ✓ Tích hợp thanh toán
- ✓ Báo cáo tài chính
- ⏳ Mở rộng sang các ngành khác
- ⏳ Nâng cấp features, performance

---

## Current Release (v1.x)

**Status:** Stable / Developing  
**Release Date:** 2026-01-XX  
**Target End Date:** 2026-06-30  

### Features (Implemented)
- ✓ Multi-tenant architecture
- ✓ Offline-first (SQLite + Firestore sync)
- ✓ Real-time notifications (FCM)
- ✓ Role-based access (admin, manager, staff)
- ✓ Repair order management
- ✓ Inventory management
- ✓ Sales management
- ✓ Customer management
- ✓ Financial tracking (v2)
- ✓ KiotViet integration
- ✓ Thermal printer support
- ✓ Image upload (Firebase Storage)

### Planned Improvements (v1.x)
- ⏳ Performance optimization
- ⏳ UI/UX refinement
- ⏳ Bug fixes from KNOWN_ISSUES.md
- ⏳ Build system optimization

---

## Milestone 1: Documentation & Build Fixes (May 2026)

**Duration:** 2 weeks  
**Target Date:** 2026-05-29  
**Status:** 🔄 In Progress  

### Goals
1. Complete comprehensive documentation
2. Fix build issues (NDK, Impeller)
3. Verify all core services
4. Create implementation reports

### Tasks
- Documentation completion (ARCHITECTURE, DESIGN_SYSTEM, etc.)
- Android NDK version fix
- Impeller opt-out removal
- Service verification tests

### Success Criteria
- ✓ All documentation files complete
- ✓ `flutter analyze` no errors
- ✓ `flutter build apk --release` successful
- ✓ All services tested

---

## Milestone 2: Performance & Optimization (June 2026)

**Duration:** 3 weeks  
**Target Date:** 2026-06-20  
**Status:** 🔜 Planned  

### Goals
1. Improve app startup time
2. Optimize Firestore queries
3. Reduce bundle size
4. Fix ANR/frame skip issues

### Key Tasks
- Profile Firebase initialization
- Add Firestore indexes
- Implement query caching
- Optimize assets and dependencies

### Expected Results
- Startup time < 3s
- Query latency < 500ms
- Bundle size < 50MB

---

## Milestone 3: Multi-Industry Expansion (Q3 2026)

**Duration:** 4 weeks  
**Target Date:** 2026-07-30  
**Status:** 🔜 Planned  

### Goals
1. Support multiple business types
2. Feature flags per industry
3. Backward compatibility

### Industries to Support
- Phone repair (existing)
- Laptop repair
- Tablet repair
- Accessories retail
- General retail

### Feature Toggles
- Category system
- Variant system (color, size, etc.)
- Expiry tracking
- Bulk operations

### Constraints
- ✓ DO NOT modify PaymentIntentService
- ✓ DO NOT modify SalaryCalculationService
- ✓ Keep backward compatibility
- ✓ Feature flags per businessType

### Reference
See `DOCS/MULTI_INDUSTRY_EXPANSION_GUIDE.md` for details

---

## Milestone 4: Enhanced Reporting (Q3 2026)

**Duration:** 2 weeks  
**Target Date:** 2026-08-15  
**Status:** 🔜 Planned  

### Goals
1. Advanced analytics
2. Custom reports
3. Data visualization

### Features
- Revenue charts
- Repair trends
- Inventory alerts
- Customer analytics
- Staff performance

---

## Milestone 5: Multi-Language Support (Q4 2026)

**Duration:** 2 weeks  
**Target Date:** 2026-09-30  
**Status:** 🔜 Planned  

### Goals
1. Support multiple languages
2. Regional date/time formats
3. Currency localization

### Languages
- ✓ Vietnamese (existing)
- ⏳ English
- ⏳ Chinese (Simplified)
- ⏳ Thai

---

## Milestone 6: Mobile Payment Integration (Q4 2026)

**Duration:** 2 weeks  
**Target Date:** 2026-10-15  
**Status:** 🔜 Planned  

### Goals
1. Multiple payment providers
2. Improved transaction tracking
3. Better reconciliation

### Payment Methods
- ✓ Bank transfer (existing)
- ⏳ Momo
- ⏳ Zalopay
- ⏳ Credit card (Stripe/Square)
- ⏳ BNPL services

---

## Long-term Vision (2027+)

### Strategic Initiatives
1. **Cloud-based Analytics** - Real-time dashboards, predictive analytics
2. **AI-Powered Features** - Smart scheduling, demand forecasting
3. **Ecosystem Integration** - Suppliers, logistics partners, payment networks
4. **White-label Solution** - Licensed to other businesses
5. **Mobile-first Redesign** - PWA, native mobile apps
6. **Marketplace** - Connect repair shops with customers/suppliers

### Potential Features
- Video repair guides
- Parts marketplace
- Insurance integration
- Repair community
- Training platform

---

## Release Timeline

```
2026
├─ May     [Milestone 1] Documentation & Build Fixes
├─ June    [Milestone 2] Performance & Optimization
├─ July    [Milestone 3] Multi-Industry Expansion
├─ August  [Milestone 4] Enhanced Reporting
├─ Sept    [Milestone 5] Multi-Language Support
└─ Oct     [Milestone 6] Mobile Payment Integration

2027
├─ Q1      [Phase 1] Cloud Analytics & AI
├─ Q2      [Phase 2] Ecosystem Integration
├─ Q3      [Phase 3] White-label Solution
└─ Q4      [Phase 4] Marketplace & Community
```

---

## Dependencies & Blockers

### Current Blockers
- None critical at this time

### Dependencies
- Flutter SDK (latest stable)
- Firebase backend
- KiotViet API access
- Device hardware (printer, GPS)

---

## Success Metrics

### Performance Indicators
- ✓ App startup time < 3s
- ✓ Firestore query latency < 500ms
- ✓ Offline sync reliability > 99%
- ✓ Crash rate < 0.1%

### Business Metrics
- ⏳ User adoption rate
- ⏳ Daily active users (DAU)
- ⏳ Feature usage rate
- ⏳ Customer satisfaction (NPS)

---

## Communication & Updates

- **Status Updates:** Weekly on roadmap progress
- **Milestone Review:** End of each milestone
- **Strategy Review:** Quarterly
- **Documentation:** Updated in HANDOVER.md

---

## How to Update Roadmap

When tasks complete or priorities change:
1. Update milestone status
2. Move completed items to done
3. Update HANDOVER.md
4. Update CHANGELOG.md

---

**Last Updated:** 2026-05-15  
**Maintained By:** GitHub Copilot  
**Review Frequency:** Quarterly (or as needed)
