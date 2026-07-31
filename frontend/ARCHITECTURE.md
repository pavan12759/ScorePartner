# ScorePartner App Architecture

## 📁 Folder Structure

```
lib/
├── main.dart
├── app.dart                    # App widget with providers
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── colors.dart
│   │   └── strings.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── light_theme.dart
│   │   └── dark_theme.dart
│   ├── utils/
│   │   ├── date_utils.dart
│   │   ├── validation_utils.dart
│   │   └── format_utils.dart
│   ├── widgets/
│   │   ├── custom_button.dart
│   │   ├── custom_text_field.dart
│   │   ├── loading_widget.dart
│   │   └── score_display.dart
│   └── firebase/
│       ├── firebase_config.dart
│       └── firebase_options.dart
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── match_model.dart
│   │   ├── tournament_model.dart
│   │   ├── ball_event_model.dart
│   │   ├── reel_model.dart
│   │   └── news_model.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── match_service.dart
│   │   ├── tournament_service.dart
│   │   ├── storage_service.dart
│   │   ├── messaging_service.dart
│   │   └── tts_service.dart
│   └── repositories/
│       ├── auth_repository.dart
│       ├── match_repository.dart
│       └── tournament_repository.dart
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── match_provider.dart
│   │   ├── scoring_provider.dart
│   │   ├── tournament_provider.dart
│   │   ├── reel_provider.dart
│   │   └── tts_provider.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── phone_auth_screen.dart
│   │   │   ├── otp_verification_screen.dart
│   │   │   └── user_onboarding_screen.dart
│   │   ├── main/
│   │   │   ├── main_navigation.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── reels_screen.dart
│   │   │   ├── my_matches_screen.dart
│   │   │   └── profile_screen.dart
│   │   ├── matches/
│   │   │   ├── live_scoring_screen.dart
│   │   │   ├── match_detail_screen.dart
│   │   │   ├── create_match_screen.dart
│   │   │   └── scorecard_screen.dart
│   │   ├── tournaments/
│   │   │   ├── tournament_list_screen.dart
│   │   │   ├── create_tournament_screen.dart
│   │   │   ├── tournament_detail_screen.dart
│   │   │   └── points_table_screen.dart
│   │   ├── reels/
│   │   │   ├── reel_upload_screen.dart
│   │   │   ├── reel_player_screen.dart
│   │   │   └── reel_comments_screen.dart
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       ├── edit_profile_screen.dart
│   │       └── notifications_screen.dart
│   └── widgets/
│       ├── common/
│       │   ├── match_card.dart
│       │   ├── player_stats_card.dart
│       │   ├── reel_card.dart
│       │   ├── news_card.dart
│       │   └── bottom_nav_bar.dart
│       ├── scoring/
│       │   ├── score_button.dart
│       │   ├── over_display.dart
│       │   ├── wicket_dialog.dart
│       │   └── commentary_widget.dart
│       └── tournament/
│           ├── tournament_card.dart
│           ├── fixture_card.dart
│           └── points_table.dart
```

## 🏗️ Architecture Patterns

### 1. Clean Architecture
- **Presentation Layer**: UI + ViewModels (Providers)
- **Domain Layer**: Business Logic + Use Cases
- **Data Layer**: Repositories + Data Sources

### 2. State Management
- **Provider** for simple state management
- **Repository Pattern** for data access
- **Service Layer** for business logic

### 3. Firebase Integration
- **Authentication**: Firebase Auth (Phone OTP)
- **Database**: Cloud Firestore
- **Storage**: Firebase Storage
- **Messaging**: Cloud Messaging
- **Functions**: Cloud Functions for news generation

## 🔄 Data Flow

1. **Authentication Flow**
   - Phone Number → OTP → User Profile → Home Screen

2. **Match Creation Flow**
   - Create Match → Add Teams → Start Scoring → Live Updates

3. **Tournament Flow**
   - Create Tournament → Add Teams → Generate Fixtures → Update Points

4. **Reels Flow**
   - Upload Video → Process → Store → Display in Feed

## 🎯 Key Features Implementation

### Live Scoring System
- Ball-by-ball event tracking
- Real-time score updates
- Auto-calculation of stats
- Voice commentary integration

### Profile System
- Separate tennis/leather ball stats
- Achievement tracking
- Social media integration

### Tournament System
- Automatic fixture generation
- Points table calculation
- Knockout bracket management

## 📊 Performance Considerations

1. **Caching Strategy**
   - Local caching for frequent data
   - Image caching for reels
   - Score data persistence

2. **Offline Support**
   - Local database for offline scoring
   - Sync when online
   - Queue for pending operations

3. **Optimization**
   - Lazy loading for reels
   - Pagination for match lists
   - Efficient Firestore queries
