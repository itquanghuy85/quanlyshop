import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop Manager'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get changeLanguage;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @parts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get parts;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @debts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debts;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get loginError;

  /// No description provided for @shopManagement.
  ///
  /// In en, this message translates to:
  /// **'SHOP MANAGEMENT'**
  String get shopManagement;

  /// No description provided for @storeIcon.
  ///
  /// In en, this message translates to:
  /// **'Store icon'**
  String get storeIcon;

  /// No description provided for @manageStaff.
  ///
  /// In en, this message translates to:
  /// **'Manage staff'**
  String get manageStaff;

  /// No description provided for @createInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get createInviteCode;

  /// No description provided for @shareQR.
  ///
  /// In en, this message translates to:
  /// **'Share QR code'**
  String get shareQR;

  /// No description provided for @staffList.
  ///
  /// In en, this message translates to:
  /// **'Staff list'**
  String get staffList;

  /// No description provided for @addEditDeleteStaff.
  ///
  /// In en, this message translates to:
  /// **'Add/Edit/Delete staff, Create invite code'**
  String get addEditDeleteStaff;

  /// No description provided for @superAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get superAdmin;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'DASHBOARD'**
  String get dashboard;

  /// No description provided for @warranty.
  ///
  /// In en, this message translates to:
  /// **'WARRANTY'**
  String get warranty;

  /// No description provided for @auditLog.
  ///
  /// In en, this message translates to:
  /// **'AUDIT LOG'**
  String get auditLog;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'PERFORMANCE'**
  String get performance;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE'**
  String get attendance;

  /// No description provided for @payroll.
  ///
  /// In en, this message translates to:
  /// **'PAYROLL'**
  String get payroll;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'QUICK ACCESS'**
  String get quickActions;

  /// No description provided for @checkInventory.
  ///
  /// In en, this message translates to:
  /// **'CHECK INVENTORY'**
  String get checkInventory;

  /// No description provided for @manageInventory.
  ///
  /// In en, this message translates to:
  /// **'MANAGE INVENTORY'**
  String get manageInventory;

  /// No description provided for @viewPrintLabels.
  ///
  /// In en, this message translates to:
  /// **'View & Print labels'**
  String get viewPrintLabels;

  /// No description provided for @accountInfo.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT INFO'**
  String get accountInfo;

  /// No description provided for @viewPermissions.
  ///
  /// In en, this message translates to:
  /// **'View permissions and account info'**
  String get viewPermissions;

  /// No description provided for @syncData.
  ///
  /// In en, this message translates to:
  /// **'Sync data'**
  String get syncData;

  /// No description provided for @syncCompleted.
  ///
  /// In en, this message translates to:
  /// **'DATA SYNCED'**
  String get syncCompleted;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'SYNC ERROR'**
  String get syncError;

  /// No description provided for @accountInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT INFORMATION'**
  String get accountInfoTitle;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @viewInventory.
  ///
  /// In en, this message translates to:
  /// **'View inventory'**
  String get viewInventory;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @otherPermissions.
  ///
  /// In en, this message translates to:
  /// **'Other permissions'**
  String get otherPermissions;

  /// No description provided for @viewSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get viewSales;

  /// No description provided for @viewRepairs.
  ///
  /// In en, this message translates to:
  /// **'Repairs'**
  String get viewRepairs;

  /// No description provided for @viewPrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get viewPrinter;

  /// No description provided for @viewRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get viewRevenue;

  /// No description provided for @viewExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get viewExpenses;

  /// No description provided for @viewDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get viewDebts;

  /// No description provided for @viewSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get viewSettings;

  /// No description provided for @shopLocked.
  ///
  /// In en, this message translates to:
  /// **'Shop locked'**
  String get shopLocked;

  /// No description provided for @shopLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'SHOP IS TEMPORARILY LOCKED BY SUPER ADMIN. All features are restricted until unlocked.'**
  String get shopLockedMessage;

  /// No description provided for @searchCustomerByPhone.
  ///
  /// In en, this message translates to:
  /// **'Quick search by phone'**
  String get searchCustomerByPhone;

  /// No description provided for @arrowForward.
  ///
  /// In en, this message translates to:
  /// **'Arrow forward'**
  String get arrowForward;

  /// No description provided for @perpetualCalendar.
  ///
  /// In en, this message translates to:
  /// **'Perpetual calendar'**
  String get perpetualCalendar;

  /// No description provided for @quickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick stats'**
  String get quickStats;

  /// No description provided for @completedToday.
  ///
  /// In en, this message translates to:
  /// **'Done/Delivered today'**
  String get completedToday;

  /// No description provided for @soldToday.
  ///
  /// In en, this message translates to:
  /// **'Sold today'**
  String get soldToday;

  /// No description provided for @todaySummary.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S WORK'**
  String get todaySummary;

  /// No description provided for @newRepairsToday.
  ///
  /// In en, this message translates to:
  /// **'Devices received today'**
  String get newRepairsToday;

  /// No description provided for @salesToday.
  ///
  /// In en, this message translates to:
  /// **'Sales today'**
  String get salesToday;

  /// No description provided for @expensesToday.
  ///
  /// In en, this message translates to:
  /// **'Expenses today'**
  String get expensesToday;

  /// No description provided for @outstandingDebts.
  ///
  /// In en, this message translates to:
  /// **'Outstanding debts'**
  String get outstandingDebts;

  /// No description provided for @gridMenu.
  ///
  /// In en, this message translates to:
  /// **'Grid menu'**
  String get gridMenu;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'SELL'**
  String get sell;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'CHAT'**
  String get chat;

  /// No description provided for @profitLoss.
  ///
  /// In en, this message translates to:
  /// **'PROFIT/LOSS'**
  String get profitLoss;

  /// No description provided for @netProfit.
  ///
  /// In en, this message translates to:
  /// **'NET PROFIT'**
  String get netProfit;

  /// No description provided for @inventorySnapshot.
  ///
  /// In en, this message translates to:
  /// **'DAILY INVENTORY'**
  String get inventorySnapshot;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total items'**
  String get totalItems;

  /// No description provided for @inventoryValue.
  ///
  /// In en, this message translates to:
  /// **'Stock value'**
  String get inventoryValue;

  /// No description provided for @noItemsInStock.
  ///
  /// In en, this message translates to:
  /// **'No stock items'**
  String get noItemsInStock;

  /// No description provided for @closingCard.
  ///
  /// In en, this message translates to:
  /// **'DAILY CLOSING'**
  String get closingCard;

  /// No description provided for @cashStart.
  ///
  /// In en, this message translates to:
  /// **'Cash start of day'**
  String get cashStart;

  /// No description provided for @bankStart.
  ///
  /// In en, this message translates to:
  /// **'Bank start of day'**
  String get bankStart;

  /// No description provided for @cashEnd.
  ///
  /// In en, this message translates to:
  /// **'Cash end of day'**
  String get cashEnd;

  /// No description provided for @bankEnd.
  ///
  /// In en, this message translates to:
  /// **'Bank end of day'**
  String get bankEnd;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @saveClosing.
  ///
  /// In en, this message translates to:
  /// **'Save closing'**
  String get saveClosing;

  /// No description provided for @revenueDistribution.
  ///
  /// In en, this message translates to:
  /// **'REVENUE DISTRIBUTION'**
  String get revenueDistribution;

  /// No description provided for @salesProfit.
  ///
  /// In en, this message translates to:
  /// **'Sales profit'**
  String get salesProfit;

  /// No description provided for @repairProfit.
  ///
  /// In en, this message translates to:
  /// **'Repair profit'**
  String get repairProfit;

  /// No description provided for @totalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get totalExpenses;

  /// No description provided for @totalProfit.
  ///
  /// In en, this message translates to:
  /// **'TOTAL PROFIT'**
  String get totalProfit;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @quickActionButton.
  ///
  /// In en, this message translates to:
  /// **'Quick action button'**
  String get quickActionButton;

  /// No description provided for @reportCard.
  ///
  /// In en, this message translates to:
  /// **'Report card'**
  String get reportCard;

  /// No description provided for @summaryRow.
  ///
  /// In en, this message translates to:
  /// **'Summary row'**
  String get summaryRow;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM SETTINGS'**
  String get settingsTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language:'**
  String get languageLabel;

  /// No description provided for @brandInfoSection.
  ///
  /// In en, this message translates to:
  /// **'BRAND INFO'**
  String get brandInfoSection;

  /// No description provided for @shopPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get shopPhoneLabel;

  /// No description provided for @shopAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop address'**
  String get shopAddressLabel;

  /// No description provided for @invoiceConfigSection.
  ///
  /// In en, this message translates to:
  /// **'INVOICE CONFIG'**
  String get invoiceConfigSection;

  /// No description provided for @invoiceFooterLabel.
  ///
  /// In en, this message translates to:
  /// **'Footer message'**
  String get invoiceFooterLabel;

  /// No description provided for @createInvoiceTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create invoice template'**
  String get createInvoiceTemplate;

  /// No description provided for @joinShopCode.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code to join shop'**
  String get joinShopCode;

  /// No description provided for @cleanupManagement.
  ///
  /// In en, this message translates to:
  /// **'Cleanup management: Delete old repair history (optional)'**
  String get cleanupManagement;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutSection;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Shop Manager'**
  String get appName;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Multi-industry shop management solution'**
  String get appDescription;

  /// No description provided for @versionNumber.
  ///
  /// In en, this message translates to:
  /// **'2.6.0'**
  String get versionNumber;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @developerName.
  ///
  /// In en, this message translates to:
  /// **'Quang Huy'**
  String get developerName;

  /// No description provided for @developerRole.
  ///
  /// In en, this message translates to:
  /// **'Mobile app development expert'**
  String get developerRole;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone/Zalo: 0964 095 979'**
  String get contactPhone;

  /// No description provided for @businessSolutions.
  ///
  /// In en, this message translates to:
  /// **'Business management solutions'**
  String get businessSolutions;

  /// No description provided for @saveAllSettings.
  ///
  /// In en, this message translates to:
  /// **'SAVE ALL SETTINGS'**
  String get saveAllSettings;

  /// No description provided for @enterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code'**
  String get enterInviteCode;

  /// No description provided for @inviteCode8Chars.
  ///
  /// In en, this message translates to:
  /// **'Invite code (8 characters)'**
  String get inviteCode8Chars;

  /// No description provided for @scanQR.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQR;

  /// No description provided for @codeMustBe8Chars.
  ///
  /// In en, this message translates to:
  /// **'Code must be 8 characters'**
  String get codeMustBe8Chars;

  /// No description provided for @joinedShopSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Joined shop successfully!'**
  String get joinedShopSuccessfully;

  /// No description provided for @invalidOrExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get invalidOrExpiredCode;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'JOIN'**
  String get join;

  /// No description provided for @cleanupConfigOptIn.
  ///
  /// In en, this message translates to:
  /// **'Cleanup config (opt-in)'**
  String get cleanupConfigOptIn;

  /// No description provided for @enableCleanup.
  ///
  /// In en, this message translates to:
  /// **'Enable cleanup'**
  String get enableCleanup;

  /// No description provided for @daysToDeleteAfter.
  ///
  /// In en, this message translates to:
  /// **'Days (delete after N days)'**
  String get daysToDeleteAfter;

  /// No description provided for @noPermissionToConfigure.
  ///
  /// In en, this message translates to:
  /// **'Account not permitted to configure'**
  String get noPermissionToConfigure;

  /// No description provided for @shopInfoSaved.
  ///
  /// In en, this message translates to:
  /// **'SHOP INFO SAVED!'**
  String get shopInfoSaved;

  /// No description provided for @cleanupConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Cleanup config saved'**
  String get cleanupConfigSaved;

  /// No description provided for @scanQRCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQRCode;

  /// No description provided for @noPermissionRepair.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to access REPAIR section. Contact shop owner for permissions.'**
  String get noPermissionRepair;

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get allowed;

  /// No description provided for @notAllowed.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get notAllowed;

  /// No description provided for @repairPermission.
  ///
  /// In en, this message translates to:
  /// **'Repair permission'**
  String get repairPermission;

  /// No description provided for @salesPermission.
  ///
  /// In en, this message translates to:
  /// **'Sales permission'**
  String get salesPermission;

  /// No description provided for @inventoryPermission.
  ///
  /// In en, this message translates to:
  /// **'Inventory permission'**
  String get inventoryPermission;

  /// No description provided for @suppliersPermission.
  ///
  /// In en, this message translates to:
  /// **'Suppliers permission'**
  String get suppliersPermission;

  /// No description provided for @customersPermission.
  ///
  /// In en, this message translates to:
  /// **'Customers permission'**
  String get customersPermission;

  /// No description provided for @warrantyPermission.
  ///
  /// In en, this message translates to:
  /// **'Warranty permission'**
  String get warrantyPermission;

  /// No description provided for @chatPermission.
  ///
  /// In en, this message translates to:
  /// **'Chat permission'**
  String get chatPermission;

  /// No description provided for @printerPermission.
  ///
  /// In en, this message translates to:
  /// **'Printer permission'**
  String get printerPermission;

  /// No description provided for @revenuePermission.
  ///
  /// In en, this message translates to:
  /// **'Revenue permission'**
  String get revenuePermission;

  /// No description provided for @expensesPermission.
  ///
  /// In en, this message translates to:
  /// **'Expenses permission'**
  String get expensesPermission;

  /// No description provided for @debtsPermission.
  ///
  /// In en, this message translates to:
  /// **'Debts permission'**
  String get debtsPermission;

  /// No description provided for @noPermissionRevenue.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to view REVENUE screen. Contact shop owner for permissions.'**
  String get noPermissionRevenue;

  /// No description provided for @noPermissionRevenueReport.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to view REVENUE REPORT screen. Contact shop owner for permissions.'**
  String get noPermissionRevenueReport;

  /// No description provided for @noPermissionSales.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to access SALES section. Contact shop owner for permissions.'**
  String get noPermissionSales;

  /// No description provided for @noPermissionInventory.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to access INVENTORY section. Contact shop owner for permissions.'**
  String get noPermissionInventory;

  /// No description provided for @noPermissionCustomers.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to view CUSTOMER SYSTEM. Contact shop owner for permissions.'**
  String get noPermissionCustomers;

  /// No description provided for @noPermissionWarranty.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to access WARRANTY section. Contact shop owner for permissions.'**
  String get noPermissionWarranty;

  /// No description provided for @noPermissionChat.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to use INTERNAL CHAT. Contact shop owner for permissions.'**
  String get noPermissionChat;

  /// No description provided for @noPermissionPrinter.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to configure PRINTER. Contact shop owner for permissions.'**
  String get noPermissionPrinter;

  /// No description provided for @noPermissionCreateRepair.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to create repair orders. Contact shop owner for permissions.'**
  String get noPermissionCreateRepair;

  /// No description provided for @viewInventoryPermission.
  ///
  /// In en, this message translates to:
  /// **'View inventory permission'**
  String get viewInventoryPermission;

  /// No description provided for @inventoryCheck.
  ///
  /// In en, this message translates to:
  /// **'INVENTORY CHECK'**
  String get inventoryCheck;

  /// No description provided for @checkInventoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Check phone & accessory stock'**
  String get checkInventoryDesc;

  /// No description provided for @receiptPrinter.
  ///
  /// In en, this message translates to:
  /// **'RECEIPT PRINTER'**
  String get receiptPrinter;

  /// No description provided for @printReceiptsDesc.
  ///
  /// In en, this message translates to:
  /// **'Print invoices, receipts'**
  String get printReceiptsDesc;

  /// No description provided for @repairReceipt.
  ///
  /// In en, this message translates to:
  /// **'REPAIR RECEIPT'**
  String get repairReceipt;

  /// No description provided for @createRepairReceiptDesc.
  ///
  /// In en, this message translates to:
  /// **'Create repair intake form'**
  String get createRepairReceiptDesc;

  /// No description provided for @thermalPrinter.
  ///
  /// In en, this message translates to:
  /// **'THERMAL PRINTER'**
  String get thermalPrinter;

  /// No description provided for @printLabelsDesc.
  ///
  /// In en, this message translates to:
  /// **'Print device labels'**
  String get printLabelsDesc;

  /// No description provided for @quickMenu.
  ///
  /// In en, this message translates to:
  /// **'Quick menu'**
  String get quickMenu;

  /// No description provided for @customerAddress.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER ADDRESS'**
  String get customerAddress;

  /// No description provided for @addToContacts.
  ///
  /// In en, this message translates to:
  /// **'ADD TO CONTACTS'**
  String get addToContacts;

  /// No description provided for @viewCustomerHistory.
  ///
  /// In en, this message translates to:
  /// **'VIEW CUSTOMER HISTORY'**
  String get viewCustomerHistory;

  /// No description provided for @appearanceCondition.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE CONDITION'**
  String get appearanceCondition;

  /// No description provided for @appearanceHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: SCRATCHED, CRACKED, BENT...'**
  String get appearanceHint;

  /// No description provided for @accessoriesIncluded.
  ///
  /// In en, this message translates to:
  /// **'ACCESSORIES INCLUDED'**
  String get accessoriesIncluded;

  /// No description provided for @accessoriesHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: CHARGER, EARPHONES...'**
  String get accessoriesHint;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHOD'**
  String get paymentMethod;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'CREDIT'**
  String get credit;

  /// No description provided for @installment.
  ///
  /// In en, this message translates to:
  /// **'INSTALLMENT (BANK)'**
  String get installment;

  /// No description provided for @t86.
  ///
  /// In en, this message translates to:
  /// **'T86'**
  String get t86;

  /// No description provided for @bankT86.
  ///
  /// In en, this message translates to:
  /// **'BANK T86'**
  String get bankT86;

  /// No description provided for @enterPhoneFirst.
  ///
  /// In en, this message translates to:
  /// **'PLEASE ENTER PHONE NUMBER FIRST'**
  String get enterPhoneFirst;

  /// No description provided for @priceMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'PRICE MUST BE GREATER THAN OR EQUAL TO 0!'**
  String get priceMustBePositive;

  /// No description provided for @customerAddedToContacts.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER ADDED TO CONTACTS'**
  String get customerAddedToContacts;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'NEW ORDER'**
  String get newOrder;

  /// No description provided for @receivedDevice.
  ///
  /// In en, this message translates to:
  /// **'RECEIVE'**
  String get receivedDevice;

  /// No description provided for @addProductToInventory.
  ///
  /// In en, this message translates to:
  /// **'ADD PRODUCT TO INVENTORY'**
  String get addProductToInventory;

  /// No description provided for @productType.
  ///
  /// In en, this message translates to:
  /// **'Product type'**
  String get productType;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'PHONE'**
  String get phone;

  /// No description provided for @accessory.
  ///
  /// In en, this message translates to:
  /// **'ACCESSORY'**
  String get accessory;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product/Part name'**
  String get productName;

  /// No description provided for @imeiNumber.
  ///
  /// In en, this message translates to:
  /// **'IMEI number (if any)'**
  String get imeiNumber;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity (e.g.: 64GB, 128GB)'**
  String get capacity;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @supplierRequired.
  ///
  /// In en, this message translates to:
  /// **'Supplier (required)'**
  String get supplierRequired;

  /// No description provided for @addSupplierQuick.
  ///
  /// In en, this message translates to:
  /// **'Add supplier quick'**
  String get addSupplierQuick;

  /// No description provided for @addSupplier.
  ///
  /// In en, this message translates to:
  /// **'ADD SUPPLIER'**
  String get addSupplier;

  /// No description provided for @enterProductNameAndSupplier.
  ///
  /// In en, this message translates to:
  /// **'PLEASE ENTER PRODUCT NAME AND SELECT SUPPLIER'**
  String get enterProductNameAndSupplier;

  /// No description provided for @productAddedToInventory.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT ADDED TO INVENTORY'**
  String get productAddedToInventory;

  /// No description provided for @deleteMultipleProducts.
  ///
  /// In en, this message translates to:
  /// **'DELETE MULTIPLE PRODUCTS'**
  String get deleteMultipleProducts;

  /// No description provided for @confirmDeleteSelectedProducts.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected products from inventory?'**
  String confirmDeleteSelectedProducts(int count);

  /// No description provided for @productsDeleted.
  ///
  /// In en, this message translates to:
  /// **'SELECTED PRODUCTS DELETED'**
  String get productsDeleted;

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT DELETED FROM INVENTORY'**
  String get productDeleted;

  /// No description provided for @onlyAdminCanDelete.
  ///
  /// In en, this message translates to:
  /// **'Only MANAGER accounts can delete products from inventory'**
  String get onlyAdminCanDelete;

  /// No description provided for @selectPrinter.
  ///
  /// In en, this message translates to:
  /// **'SELECT PRINTER'**
  String get selectPrinter;

  /// No description provided for @noPrintersFound.
  ///
  /// In en, this message translates to:
  /// **'No printers found. Please connect a printer first.'**
  String get noPrintersFound;

  /// No description provided for @labelPrintedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'LABEL PRINTED SUCCESSFULLY'**
  String get labelPrintedSuccessfully;

  /// No description provided for @labelPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'LABEL PRINT FAILED - CHECK PRINTER'**
  String get labelPrintFailed;

  /// No description provided for @errorPrintingLabel.
  ///
  /// In en, this message translates to:
  /// **'ERROR PRINTING LABEL'**
  String get errorPrintingLabel;

  /// No description provided for @financeCenter.
  ///
  /// In en, this message translates to:
  /// **'FINANCE CENTER'**
  String get financeCenter;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'STAFF'**
  String get staff;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @priceHint.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceHint;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @saveRepairOrder.
  ///
  /// In en, this message translates to:
  /// **'Save repair order'**
  String get saveRepairOrder;

  /// No description provided for @noPermissionSuppliers.
  ///
  /// In en, this message translates to:
  /// **'This account is not permitted to view SUPPLIERS. Contact shop owner for permissions.'**
  String get noPermissionSuppliers;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @supplierShort.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplierShort;

  /// No description provided for @imei.
  ///
  /// In en, this message translates to:
  /// **'IMEI'**
  String get imei;

  /// No description provided for @quantityShort.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantityShort;

  /// No description provided for @printPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Print phone label'**
  String get printPhoneLabel;

  /// No description provided for @deleteFromInventory.
  ///
  /// In en, this message translates to:
  /// **'Delete from inventory'**
  String get deleteFromInventory;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// No description provided for @addNewProduct.
  ///
  /// In en, this message translates to:
  /// **'Add new product'**
  String get addNewProduct;

  /// No description provided for @modelRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter device model'**
  String get modelRequired;

  /// No description provided for @issueRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter device issue'**
  String get issueRequired;

  /// No description provided for @orderCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Repair order created successfully!'**
  String get orderCreatedSuccessfully;

  /// No description provided for @createNewOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to create a new repair order?'**
  String get createNewOrderQuestion;

  /// No description provided for @saveOrderError.
  ///
  /// In en, this message translates to:
  /// **'Error saving order: {error}'**
  String saveOrderError(String error);

  /// No description provided for @confirmPrintLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm print label'**
  String get confirmPrintLabel;

  /// No description provided for @printLabel.
  ///
  /// In en, this message translates to:
  /// **'Print label'**
  String get printLabel;

  /// No description provided for @confirmDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete product \'{name}\' from inventory?'**
  String confirmDeleteProduct(String name);

  /// No description provided for @deleteProductFromInventory.
  ///
  /// In en, this message translates to:
  /// **'Delete product from inventory'**
  String get deleteProductFromInventory;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @productDeletedFromInventory.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT DELETED FROM INVENTORY'**
  String get productDeletedFromInventory;

  /// No description provided for @confirmDeleteMultipleProducts.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected products from inventory?'**
  String confirmDeleteMultipleProducts(int count);

  /// No description provided for @multipleProductsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} PRODUCTS DELETED'**
  String multipleProductsDeleted(int count);

  /// No description provided for @imeiOptional.
  ///
  /// In en, this message translates to:
  /// **'IMEI (Optional)'**
  String get imeiOptional;

  /// No description provided for @capacityExample.
  ///
  /// In en, this message translates to:
  /// **'Capacity (e.g.: 64GB, 128GB)'**
  String get capacityExample;

  /// No description provided for @addSupplierQuickly.
  ///
  /// In en, this message translates to:
  /// **'Add supplier quick'**
  String get addSupplierQuickly;

  /// No description provided for @supplierName.
  ///
  /// In en, this message translates to:
  /// **'Supplier name'**
  String get supplierName;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get contactPerson;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @accessories.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessories;

  /// No description provided for @labelPrintError.
  ///
  /// In en, this message translates to:
  /// **'Label print error: {error}'**
  String labelPrintError(String error);

  /// No description provided for @cashClosingSaved.
  ///
  /// In en, this message translates to:
  /// **'DAILY CLOSING SAVED'**
  String get cashClosingSaved;

  /// No description provided for @netProfitAfterExpenses.
  ///
  /// In en, this message translates to:
  /// **'NET PROFIT AFTER EXPENSES'**
  String get netProfitAfterExpenses;

  /// No description provided for @timePeriod.
  ///
  /// In en, this message translates to:
  /// **'Time period'**
  String get timePeriod;

  /// No description provided for @todayCashFlow.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S CASH FLOW'**
  String get todayCashFlow;

  /// No description provided for @saveCashClosing.
  ///
  /// In en, this message translates to:
  /// **'Save closing'**
  String get saveCashClosing;

  /// No description provided for @syncHealthCheck.
  ///
  /// In en, this message translates to:
  /// **'SYNC HEALTH CHECK'**
  String get syncHealthCheck;

  /// No description provided for @syncHealthy.
  ///
  /// In en, this message translates to:
  /// **'SYNC COMPLETE'**
  String get syncHealthy;

  /// No description provided for @syncIssues.
  ///
  /// In en, this message translates to:
  /// **'SYNC ISSUES FOUND'**
  String get syncIssues;

  /// No description provided for @checkingSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking sync status...'**
  String get checkingSyncStatus;

  /// No description provided for @localData.
  ///
  /// In en, this message translates to:
  /// **'Local data'**
  String get localData;

  /// No description provided for @cloudData.
  ///
  /// In en, this message translates to:
  /// **'Cloud data'**
  String get cloudData;

  /// No description provided for @notSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get notSynced;

  /// No description provided for @autoFix.
  ///
  /// In en, this message translates to:
  /// **'AUTO FIX'**
  String get autoFix;

  /// No description provided for @downloadShopData.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD SHOP DATA'**
  String get downloadShopData;

  /// No description provided for @uploadToCloud.
  ///
  /// In en, this message translates to:
  /// **'SYNC DATA TO CLOUD'**
  String get uploadToCloud;

  /// No description provided for @resetShopData.
  ///
  /// In en, this message translates to:
  /// **'RESET SHOP DATA'**
  String get resetShopData;

  /// No description provided for @logoutAccount.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT ACCOUNT'**
  String get logoutAccount;

  /// No description provided for @shopInfo.
  ///
  /// In en, this message translates to:
  /// **'SHOP INFORMATION'**
  String get shopInfo;

  /// No description provided for @staffPermissions.
  ///
  /// In en, this message translates to:
  /// **'STAFF PERMISSION MANAGEMENT'**
  String get staffPermissions;

  /// No description provided for @debtDebug.
  ///
  /// In en, this message translates to:
  /// **'DEBT DEBUG'**
  String get debtDebug;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM SETTINGS'**
  String get systemSettings;

  /// No description provided for @languageApp.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageApp;

  /// No description provided for @yourRole.
  ///
  /// In en, this message translates to:
  /// **'Your role'**
  String get yourRole;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Shop owner'**
  String get owner;

  /// No description provided for @manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get manager;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get user;

  /// No description provided for @debugTools.
  ///
  /// In en, this message translates to:
  /// **'DEBUG TOOLS'**
  String get debugTools;

  /// No description provided for @syncManagement.
  ///
  /// In en, this message translates to:
  /// **'DATA SYNC'**
  String get syncManagement;

  /// No description provided for @shopAdmin.
  ///
  /// In en, this message translates to:
  /// **'SHOP ADMIN'**
  String get shopAdmin;

  /// No description provided for @advancedAdmin.
  ///
  /// In en, this message translates to:
  /// **'ADVANCED ADMIN'**
  String get advancedAdmin;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get confirmLogout;

  /// No description provided for @warningNewDevice.
  ///
  /// In en, this message translates to:
  /// **'This device has very little data'**
  String get warningNewDevice;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'products'**
  String get products;

  /// No description provided for @continueAnyway.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE ANYWAY'**
  String get continueAnyway;

  /// No description provided for @newStaffWarning.
  ///
  /// In en, this message translates to:
  /// **'Please DOWNLOAD DATA first, DO NOT sync to cloud without data.'**
  String get newStaffWarning;

  /// No description provided for @dataToUpload.
  ///
  /// In en, this message translates to:
  /// **'Data to upload'**
  String get dataToUpload;

  /// No description provided for @newRepairOrders.
  ///
  /// In en, this message translates to:
  /// **'new repair orders'**
  String get newRepairOrders;

  /// No description provided for @newSaleOrders.
  ///
  /// In en, this message translates to:
  /// **'new sale orders'**
  String get newSaleOrders;

  /// No description provided for @existingCloudData.
  ///
  /// In en, this message translates to:
  /// **'Existing cloud data will NOT be deleted.'**
  String get existingCloudData;

  /// No description provided for @downloadAllData.
  ///
  /// In en, this message translates to:
  /// **'Download all shop data from cloud.'**
  String get downloadAllData;

  /// No description provided for @downloadingData.
  ///
  /// In en, this message translates to:
  /// **'Downloading data...'**
  String get downloadingData;

  /// No description provided for @uploadingData.
  ///
  /// In en, this message translates to:
  /// **'Syncing data...'**
  String get uploadingData;

  /// No description provided for @uploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data synced to cloud!'**
  String get uploadSuccess;

  /// No description provided for @confirmResetShop.
  ///
  /// In en, this message translates to:
  /// **'Type \'XOA HET\' to confirm'**
  String get confirmResetShop;

  /// No description provided for @confirmResetButton.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM RESET'**
  String get confirmResetButton;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'SHOP DATA RESET!'**
  String get resetSuccess;

  /// No description provided for @onlySuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'ONLY SUPER ADMIN CAN RESET SHOP DATA!'**
  String get onlySuperAdmin;

  /// No description provided for @repairListTitle.
  ///
  /// In en, this message translates to:
  /// **'REPAIR LIST'**
  String get repairListTitle;

  /// No description provided for @machinesCount.
  ///
  /// In en, this message translates to:
  /// **'devices'**
  String get machinesCount;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get processing;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @searchFullApp.
  ///
  /// In en, this message translates to:
  /// **'Search entire app'**
  String get searchFullApp;

  /// No description provided for @saleListTitle.
  ///
  /// In en, this message translates to:
  /// **'SALES MANAGEMENT'**
  String get saleListTitle;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S SALES'**
  String get todaySales;

  /// No description provided for @ordersCount.
  ///
  /// In en, this message translates to:
  /// **'orders'**
  String get ordersCount;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @searchByNameImei.
  ///
  /// In en, this message translates to:
  /// **'Search by customer, device or IMEI...'**
  String get searchByNameImei;

  /// No description provided for @financeManagement.
  ///
  /// In en, this message translates to:
  /// **'FINANCE MANAGEMENT'**
  String get financeManagement;

  /// No description provided for @revenueExpenseOverview.
  ///
  /// In en, this message translates to:
  /// **'Revenue, expense overview'**
  String get revenueExpenseOverview;

  /// No description provided for @filterByTime.
  ///
  /// In en, this message translates to:
  /// **'Filter by time'**
  String get filterByTime;

  /// No description provided for @partnerManagement.
  ///
  /// In en, this message translates to:
  /// **'PARTNER MANAGEMENT'**
  String get partnerManagement;

  /// No description provided for @suppliersCount.
  ///
  /// In en, this message translates to:
  /// **'suppliers'**
  String get suppliersCount;

  /// No description provided for @partnersCount.
  ///
  /// In en, this message translates to:
  /// **'partners'**
  String get partnersCount;

  /// No description provided for @supplierTab.
  ///
  /// In en, this message translates to:
  /// **'SUPPLIERS'**
  String get supplierTab;

  /// No description provided for @repairPartnerTab.
  ///
  /// In en, this message translates to:
  /// **'REPAIR PARTNERS'**
  String get repairPartnerTab;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @generateQRInvite.
  ///
  /// In en, this message translates to:
  /// **'Generate QR invite'**
  String get generateQRInvite;

  /// No description provided for @saleDetail.
  ///
  /// In en, this message translates to:
  /// **'SALE DETAILS'**
  String get saleDetail;

  /// No description provided for @repairDetail.
  ///
  /// In en, this message translates to:
  /// **'REPAIR DETAILS'**
  String get repairDetail;

  /// No description provided for @attendanceManagement.
  ///
  /// In en, this message translates to:
  /// **'Manage work hours'**
  String get attendanceManagement;

  /// No description provided for @deleteSupplier.
  ///
  /// In en, this message translates to:
  /// **'DELETE SUPPLIER'**
  String get deleteSupplier;

  /// No description provided for @confirmDeleteSupplier.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this supplier?'**
  String get confirmDeleteSupplier;

  /// No description provided for @deleteSaleOrder.
  ///
  /// In en, this message translates to:
  /// **'DELETE SALE ORDER'**
  String get deleteSaleOrder;

  /// No description provided for @confirmDeleteSaleOrder.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this sale order?'**
  String get confirmDeleteSaleOrder;

  /// No description provided for @permissionManagement.
  ///
  /// In en, this message translates to:
  /// **'PERMISSION MANAGEMENT'**
  String get permissionManagement;

  /// No description provided for @ownerFullAccess.
  ///
  /// In en, this message translates to:
  /// **'SHOP OWNER has full access to all features in the system'**
  String get ownerFullAccess;

  /// No description provided for @managerFullAccess.
  ///
  /// In en, this message translates to:
  /// **'MANAGER has full access to all features in the system'**
  String get managerFullAccess;

  /// No description provided for @bluetoothPrinterTest.
  ///
  /// In en, this message translates to:
  /// **'BLUETOOTH PRINTER TEST'**
  String get bluetoothPrinterTest;

  /// No description provided for @checkBluetoothPermission.
  ///
  /// In en, this message translates to:
  /// **'Check detailed Bluetooth permissions...'**
  String get checkBluetoothPermission;

  /// No description provided for @checkBluetoothOn.
  ///
  /// In en, this message translates to:
  /// **'Check if Bluetooth is on...'**
  String get checkBluetoothOn;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'SAVE SETTINGS'**
  String get saveSettings;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get deleteTemplate;

  /// No description provided for @saveTemplate.
  ///
  /// In en, this message translates to:
  /// **'SAVE TEMPLATE'**
  String get saveTemplate;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'SAVE CHANGES'**
  String get saveChanges;

  /// No description provided for @addCode.
  ///
  /// In en, this message translates to:
  /// **'ADD CODE'**
  String get addCode;

  /// No description provided for @deletePartner.
  ///
  /// In en, this message translates to:
  /// **'Delete partner'**
  String get deletePartner;

  /// No description provided for @scanSettings.
  ///
  /// In en, this message translates to:
  /// **'Scan settings'**
  String get scanSettings;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @pleaseEnter.
  ///
  /// In en, this message translates to:
  /// **'Please enter'**
  String get pleaseEnter;

  /// No description provided for @pleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Please select'**
  String get pleaseSelect;

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get invalidInput;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createNew.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get createNew;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @viewMore.
  ///
  /// In en, this message translates to:
  /// **'View more'**
  String get viewMore;

  /// No description provided for @viewLess.
  ///
  /// In en, this message translates to:
  /// **'View less'**
  String get viewLess;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @hideAll.
  ///
  /// In en, this message translates to:
  /// **'Hide all'**
  String get hideAll;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @by.
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get by;

  /// No description provided for @at.
  ///
  /// In en, this message translates to:
  /// **'At'**
  String get at;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get or;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'And'**
  String get and;

  /// No description provided for @withLabel.
  ///
  /// In en, this message translates to:
  /// **'With'**
  String get withLabel;

  /// No description provided for @without.
  ///
  /// In en, this message translates to:
  /// **'Without'**
  String get without;

  /// No description provided for @old.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get old;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @close2.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close2;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @modified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modified;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email, we will send a password reset link.'**
  String get forgotPasswordDesc;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}'**
  String passwordResetEmailSent(String email);

  /// No description provided for @errorSendingEmail.
  ///
  /// In en, this message translates to:
  /// **'Error sending email'**
  String get errorSendingEmail;

  /// No description provided for @emailNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Email not registered'**
  String get emailNotRegistered;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmailFormat;

  /// No description provided for @sendEmail.
  ///
  /// In en, this message translates to:
  /// **'SEND EMAIL'**
  String get sendEmail;

  /// No description provided for @noAccountRegisterNow.
  ///
  /// In en, this message translates to:
  /// **'No account? Register now'**
  String get noAccountRegisterNow;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Please login.'**
  String get registerSuccess;

  /// No description provided for @emailExample.
  ///
  /// In en, this message translates to:
  /// **'E.g.: name@domain.com or name@gmail.com'**
  String get emailExample;

  /// No description provided for @perpetualCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Perpetual Calendar'**
  String get perpetualCalendarTitle;

  /// No description provided for @todayDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Today: {date}'**
  String todayDateFormat(String date);

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sunday;

  /// No description provided for @languageAndInterface.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE & INTERFACE'**
  String get languageAndInterface;

  /// No description provided for @accountAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT & SECURITY'**
  String get accountAndSecurity;

  /// No description provided for @selectOtherShop.
  ///
  /// In en, this message translates to:
  /// **'SELECT OTHER SHOP'**
  String get selectOtherShop;

  /// No description provided for @logoutFromApp.
  ///
  /// In en, this message translates to:
  /// **'Logout from app'**
  String get logoutFromApp;

  /// No description provided for @logoutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Logout?'**
  String get logoutQuestion;

  /// No description provided for @logoutError.
  ///
  /// In en, this message translates to:
  /// **'Logout error: {error}'**
  String logoutError(String error);

  /// No description provided for @syncCenter.
  ///
  /// In en, this message translates to:
  /// **'SYNC CENTER'**
  String get syncCenter;

  /// No description provided for @syncCenterDesc.
  ///
  /// In en, this message translates to:
  /// **'Download, upload, check and restore data'**
  String get syncCenterDesc;

  /// No description provided for @viewShopAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin can select shop to view data'**
  String get viewShopAsAdmin;

  /// No description provided for @noShops.
  ///
  /// In en, this message translates to:
  /// **'No shops available'**
  String get noShops;

  /// No description provided for @selectShopLabel.
  ///
  /// In en, this message translates to:
  /// **'Select shop'**
  String get selectShopLabel;

  /// No description provided for @selectShopPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'-- Select shop to view --'**
  String get selectShopPlaceholder;

  /// No description provided for @currentlyViewing.
  ///
  /// In en, this message translates to:
  /// **'Viewing: {shopName}'**
  String currentlyViewing(String shopName);

  /// No description provided for @ownerRole.
  ///
  /// In en, this message translates to:
  /// **'SHOP OWNER'**
  String get ownerRole;

  /// No description provided for @managerRole.
  ///
  /// In en, this message translates to:
  /// **'MANAGER'**
  String get managerRole;

  /// No description provided for @employeeRole.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEE'**
  String get employeeRole;

  /// No description provided for @technicianRole.
  ///
  /// In en, this message translates to:
  /// **'TECHNICIAN'**
  String get technicianRole;

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'ADMIN'**
  String get adminRole;

  /// No description provided for @userRole.
  ///
  /// In en, this message translates to:
  /// **'USER'**
  String get userRole;

  /// No description provided for @dangerWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ DANGER WARNING'**
  String get dangerWarningTitle;

  /// No description provided for @resetShopWarning.
  ///
  /// In en, this message translates to:
  /// **'This action will permanently delete 100% of Orders, Inventory, Debts and Logs from both Cloud and this Device. CANNOT BE UNDONE!'**
  String get resetShopWarning;

  /// No description provided for @resetCloudError.
  ///
  /// In en, this message translates to:
  /// **'ERROR DELETING CLOUD DATA: {error}'**
  String resetCloudError(String error);

  /// No description provided for @viewAndEditStaffPermissions.
  ///
  /// In en, this message translates to:
  /// **'View and edit staff access permissions'**
  String get viewAndEditStaffPermissions;

  /// No description provided for @resetShopAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Use to reset all shop data (SUPER ADMIN ONLY)'**
  String get resetShopAdminOnly;

  /// No description provided for @syncErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get syncErrorTitle;

  /// No description provided for @noTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'No transaction history'**
  String get noTransactionHistory;

  /// No description provided for @noActivityLogs.
  ///
  /// In en, this message translates to:
  /// **'No activity logs yet'**
  String get noActivityLogs;

  /// No description provided for @noRepairOrders.
  ///
  /// In en, this message translates to:
  /// **'No repair orders'**
  String get noRepairOrders;

  /// No description provided for @noSaleOrders.
  ///
  /// In en, this message translates to:
  /// **'No sale orders'**
  String get noSaleOrders;

  /// No description provided for @noPaymentData.
  ///
  /// In en, this message translates to:
  /// **'No payment data'**
  String get noPaymentData;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @notSyncedCount.
  ///
  /// In en, this message translates to:
  /// **'Not synced ({count})'**
  String notSyncedCount(int count);

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete'**
  String get confirmDelete;

  /// No description provided for @confirmActionWithName.
  ///
  /// In en, this message translates to:
  /// **'Confirm {action}'**
  String confirmActionWithName(String action);

  /// No description provided for @confirmDeleteOrder.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM DELETE ORDER'**
  String get confirmDeleteOrder;

  /// No description provided for @enterPasswordToDelete.
  ///
  /// In en, this message translates to:
  /// **'Enter account password to delete:'**
  String get enterPasswordToDelete;

  /// No description provided for @deletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'DELETED SUCCESSFULLY'**
  String get deletedSuccessfully;

  /// No description provided for @addToStock.
  ///
  /// In en, this message translates to:
  /// **'ADD TO STOCK'**
  String get addToStock;

  /// No description provided for @continueAdding.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE ADDING'**
  String get continueAdding;

  /// No description provided for @manualEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get manualEntry;

  /// No description provided for @confirmStagingStock.
  ///
  /// In en, this message translates to:
  /// **'Confirm add to staging stock'**
  String get confirmStagingStock;

  /// No description provided for @addToStagingStock.
  ///
  /// In en, this message translates to:
  /// **'Add to Staging Stock'**
  String get addToStagingStock;

  /// No description provided for @purchaseOrderCreated.
  ///
  /// In en, this message translates to:
  /// **'Purchase order created'**
  String get purchaseOrderCreated;

  /// No description provided for @addMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get addMore;

  /// No description provided for @confirmStockIn.
  ///
  /// In en, this message translates to:
  /// **'Confirm stock in?'**
  String get confirmStockIn;

  /// No description provided for @pleaseEnterPartnerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter partner name'**
  String get pleaseEnterPartnerName;

  /// No description provided for @pleaseEnterSupplierName.
  ///
  /// In en, this message translates to:
  /// **'Please enter supplier name'**
  String get pleaseEnterSupplierName;

  /// No description provided for @supplierAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Supplier added successfully'**
  String get supplierAddedSuccess;

  /// No description provided for @supplierAddError.
  ///
  /// In en, this message translates to:
  /// **'Error: Cannot add supplier'**
  String get supplierAddError;

  /// No description provided for @partnerDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Partner deleted successfully'**
  String get partnerDeletedSuccess;

  /// No description provided for @partnerDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error: Cannot delete partner'**
  String get partnerDeleteError;

  /// No description provided for @supplierDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Supplier deleted successfully'**
  String get supplierDeletedSuccess;

  /// No description provided for @supplierDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error: Cannot delete supplier'**
  String get supplierDeleteError;

  /// No description provided for @partnerAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Partner added successfully'**
  String get partnerAddedSuccess;

  /// No description provided for @partnerUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Partner updated'**
  String get partnerUpdatedSuccess;

  /// No description provided for @partnerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Partner not found!'**
  String get partnerNotFound;

  /// No description provided for @partnerInfoNotFound.
  ///
  /// In en, this message translates to:
  /// **'Partner info not found!'**
  String get partnerInfoNotFound;

  /// No description provided for @loadingList.
  ///
  /// In en, this message translates to:
  /// **'Loading list...'**
  String get loadingList;

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'Search error: {error}'**
  String searchError(String error);

  /// No description provided for @qrProcessError.
  ///
  /// In en, this message translates to:
  /// **'QR processing error: {error}'**
  String qrProcessError(String error);

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(String error);

  /// No description provided for @loadCustomerListError.
  ///
  /// In en, this message translates to:
  /// **'Error loading customer list: {error}'**
  String loadCustomerListError(String error);

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Delete error: {error}'**
  String deleteError(String error);

  /// No description provided for @shopTab.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopTab;

  /// No description provided for @templateTab.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templateTab;

  /// No description provided for @versionFormat.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionFormat(String version);

  /// No description provided for @displayInfoOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Info displayed on label'**
  String get displayInfoOnLabel;

  /// No description provided for @shopNameField.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopNameField;

  /// No description provided for @shopNameHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: HULUCA MOBILE'**
  String get shopNameHint;

  /// No description provided for @hotlineHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: 0909 123 456'**
  String get hotlineHint;

  /// No description provided for @zalo.
  ///
  /// In en, this message translates to:
  /// **'Zalo'**
  String get zalo;

  /// No description provided for @slogan.
  ///
  /// In en, this message translates to:
  /// **'Slogan'**
  String get slogan;

  /// No description provided for @sloganHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: Best prices guaranteed'**
  String get sloganHint;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: 123 ABC, District 1, HCM'**
  String get addressHint;

  /// No description provided for @invoiceSaved.
  ///
  /// In en, this message translates to:
  /// **'Invoice template saved'**
  String get invoiceSaved;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'PROFILE SAVED'**
  String get profileSaved;

  /// No description provided for @partDeleted.
  ///
  /// In en, this message translates to:
  /// **'Part deleted'**
  String get partDeleted;

  /// No description provided for @partsDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} parts deleted'**
  String partsDeletedCount(int count);

  /// No description provided for @csvCopied.
  ///
  /// In en, this message translates to:
  /// **'CSV copied to clipboard'**
  String get csvCopied;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get statusDone;

  /// No description provided for @receiptSavedAndPrinted.
  ///
  /// In en, this message translates to:
  /// **'Receipt saved and printed successfully!'**
  String get receiptSavedAndPrinted;

  /// No description provided for @partnerDeleted.
  ///
  /// In en, this message translates to:
  /// **'PARTNER DELETED'**
  String get partnerDeleted;

  /// No description provided for @refreshingFcmToken.
  ///
  /// In en, this message translates to:
  /// **'Refreshing FCM token...'**
  String get refreshingFcmToken;

  /// No description provided for @isActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get isActive;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get confirmButton;

  /// No description provided for @shopField.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopField;

  /// No description provided for @selectShopToViewData.
  ///
  /// In en, this message translates to:
  /// **'SELECT SHOP TO VIEW'**
  String get selectShopToViewData;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @salesTab.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesTab;

  /// No description provided for @repairsTab.
  ///
  /// In en, this message translates to:
  /// **'Repairs'**
  String get repairsTab;

  /// No description provided for @inventoryTab.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryTab;

  /// No description provided for @financeTab.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get financeTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @exitAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit app?'**
  String get exitAppTitle;

  /// No description provided for @groupChat.
  ///
  /// In en, this message translates to:
  /// **'GROUP CHAT'**
  String get groupChat;

  /// No description provided for @newMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new messages'**
  String newMessagesCount(int count);

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages;

  /// No description provided for @financialOverview.
  ///
  /// In en, this message translates to:
  /// **'FINANCIAL OVERVIEW'**
  String get financialOverview;

  /// No description provided for @todayOverview.
  ///
  /// In en, this message translates to:
  /// **'TODAY OVERVIEW'**
  String get todayOverview;

  /// No description provided for @todayExpenseLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY EXPENSE'**
  String get todayExpenseLabel;

  /// No description provided for @todayActivities.
  ///
  /// In en, this message translates to:
  /// **'TODAY ACTIVITIES'**
  String get todayActivities;

  /// No description provided for @profitFormula.
  ///
  /// In en, this message translates to:
  /// **'= Income - Expense - Cost'**
  String get profitFormula;

  /// No description provided for @featureLockedByAdmin.
  ///
  /// In en, this message translates to:
  /// **'This feature has been locked by Administrator.\nPlease contact developer for support.'**
  String get featureLockedByAdmin;

  /// No description provided for @featureLockedByOwner.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to access this feature.\nPlease contact Shop Owner for access.'**
  String get featureLockedByOwner;

  /// No description provided for @technicalSupport.
  ///
  /// In en, this message translates to:
  /// **'TECHNICAL SUPPORT'**
  String get technicalSupport;

  /// No description provided for @contactShopOwner.
  ///
  /// In en, this message translates to:
  /// **'CONTACT SHOP OWNER'**
  String get contactShopOwner;

  /// No description provided for @hulucaTech.
  ///
  /// In en, this message translates to:
  /// **'Huluca Tech'**
  String get hulucaTech;

  /// No description provided for @shopOwnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Owner'**
  String get shopOwnerLabel;

  /// No description provided for @adminLocked.
  ///
  /// In en, this message translates to:
  /// **'ADMIN LOCKED'**
  String get adminLocked;

  /// No description provided for @ownerPermissionLocked.
  ///
  /// In en, this message translates to:
  /// **'OWNER PERMISSION LOCKED'**
  String get ownerPermissionLocked;

  /// No description provided for @featureLocked.
  ///
  /// In en, this message translates to:
  /// **'Feature locked'**
  String get featureLocked;

  /// No description provided for @supportAvailability.
  ///
  /// In en, this message translates to:
  /// **'24/7 Support • Response within 30 minutes'**
  String get supportAvailability;

  /// No description provided for @requestPermission.
  ///
  /// In en, this message translates to:
  /// **'Request permission'**
  String get requestPermission;

  /// No description provided for @contactShopOwnerOrManager.
  ///
  /// In en, this message translates to:
  /// **'Contact Shop Owner or Manager'**
  String get contactShopOwnerOrManager;

  /// No description provided for @requestFeatureAccess.
  ///
  /// In en, this message translates to:
  /// **'Request access to this feature'**
  String get requestFeatureAccess;

  /// No description provided for @loginAgainAfterPermission.
  ///
  /// In en, this message translates to:
  /// **'After permission granted, login again to apply'**
  String get loginAgainAfterPermission;

  /// No description provided for @cannotMakeCall.
  ///
  /// In en, this message translates to:
  /// **'Cannot make call: {phoneNumber}'**
  String cannotMakeCall(String phoneNumber);

  /// No description provided for @cannotOpenZalo.
  ///
  /// In en, this message translates to:
  /// **'Cannot open Zalo. Please contact: {phoneNumber}'**
  String cannotOpenZalo(String phoneNumber);

  /// No description provided for @notificationActive.
  ///
  /// In en, this message translates to:
  /// **'Notifications (active)'**
  String get notificationActive;

  /// No description provided for @notificationInactive.
  ///
  /// In en, this message translates to:
  /// **'Notifications (inactive)'**
  String get notificationInactive;

  /// No description provided for @searchWholeApp.
  ///
  /// In en, this message translates to:
  /// **'Search whole app'**
  String get searchWholeApp;

  /// No description provided for @contactAdminToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Contact Admin to unlock'**
  String get contactAdminToUnlock;

  /// No description provided for @systemAdminLabel.
  ///
  /// In en, this message translates to:
  /// **'System Administrator'**
  String get systemAdminLabel;

  /// No description provided for @shopOwnerLabelFull.
  ///
  /// In en, this message translates to:
  /// **'Shop Owner'**
  String get shopOwnerLabelFull;

  /// No description provided for @managerLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get managerLabel;

  /// No description provided for @staffLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffLabel;

  /// No description provided for @userLabel.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userLabel;

  /// No description provided for @welcomeNewStaff.
  ///
  /// In en, this message translates to:
  /// **'Welcome new staff!'**
  String get welcomeNewStaff;

  /// No description provided for @newStaffSyncGuide.
  ///
  /// In en, this message translates to:
  /// **'Go to Shop Settings → Download shop data to sync'**
  String get newStaffSyncGuide;

  /// No description provided for @downloadShopDataToStart.
  ///
  /// In en, this message translates to:
  /// **'Download shop data to start working'**
  String get downloadShopDataToStart;

  /// No description provided for @downloadShopDataTitle.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD SHOP DATA'**
  String get downloadShopDataTitle;

  /// No description provided for @fromCloudToDevice.
  ///
  /// In en, this message translates to:
  /// **'from cloud to this device.'**
  String get fromCloudToDevice;

  /// No description provided for @debtsAndExpenses.
  ///
  /// In en, this message translates to:
  /// **'Debts & Expenses'**
  String get debtsAndExpenses;

  /// No description provided for @customersAndSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Customers & Suppliers'**
  String get customersAndSuppliers;

  /// No description provided for @downloadOnlyThisShop.
  ///
  /// In en, this message translates to:
  /// **'Only download this shop\'s data, won\'t affect other shops.'**
  String get downloadOnlyThisShop;

  /// No description provided for @downloadMayTakeFewMinutes.
  ///
  /// In en, this message translates to:
  /// **'Process may take a few minutes depending on data size.'**
  String get downloadMayTakeFewMinutes;

  /// No description provided for @startDownload.
  ///
  /// In en, this message translates to:
  /// **'START DOWNLOAD'**
  String get startDownload;

  /// No description provided for @downloadingShopData.
  ///
  /// In en, this message translates to:
  /// **'Downloading shop data...'**
  String get downloadingShopData;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// No description provided for @shopDataDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Shop data downloaded!'**
  String get shopDataDownloaded;

  /// No description provided for @quickAccess.
  ///
  /// In en, this message translates to:
  /// **'QUICK ACCESS'**
  String get quickAccess;

  /// No description provided for @salesOrder.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesOrder;

  /// No description provided for @salesOrderList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get salesOrderList;

  /// No description provided for @repairOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Repairs'**
  String get repairOrderTitle;

  /// No description provided for @pendingStockShort.
  ///
  /// In en, this message translates to:
  /// **'Pending Stock'**
  String get pendingStockShort;

  /// No description provided for @temporaryImport.
  ///
  /// In en, this message translates to:
  /// **'Temp Import'**
  String get temporaryImport;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @incomeExpense.
  ///
  /// In en, this message translates to:
  /// **'Income/Expense'**
  String get incomeExpense;

  /// No description provided for @createSaleOrder.
  ///
  /// In en, this message translates to:
  /// **'CREATE SALE ORDER'**
  String get createSaleOrder;

  /// No description provided for @sellProductsQuickly.
  ///
  /// In en, this message translates to:
  /// **'Sell products quickly'**
  String get sellProductsQuickly;

  /// No description provided for @receiveDeviceForRepair.
  ///
  /// In en, this message translates to:
  /// **'Receive device for repair'**
  String get receiveDeviceForRepair;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'+ ADD STOCK'**
  String get addStock;

  /// No description provided for @newStockIn.
  ///
  /// In en, this message translates to:
  /// **'New stock in'**
  String get newStockIn;

  /// No description provided for @scanToCheck.
  ///
  /// In en, this message translates to:
  /// **'Scan to check'**
  String get scanToCheck;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'REPORT'**
  String get report;

  /// No description provided for @checkInOut.
  ///
  /// In en, this message translates to:
  /// **'Check in/out'**
  String get checkInOut;

  /// No description provided for @quickWarrantyLookup.
  ///
  /// In en, this message translates to:
  /// **'Quick warranty lookup'**
  String get quickWarrantyLookup;

  /// No description provided for @createSale.
  ///
  /// In en, this message translates to:
  /// **'Create sale'**
  String get createSale;

  /// No description provided for @createRepair.
  ///
  /// In en, this message translates to:
  /// **'Create repair'**
  String get createRepair;

  /// No description provided for @stockIn.
  ///
  /// In en, this message translates to:
  /// **'Stock in'**
  String get stockIn;

  /// No description provided for @revenueReport.
  ///
  /// In en, this message translates to:
  /// **'Revenue report'**
  String get revenueReport;

  /// No description provided for @createNewSaleOrder.
  ///
  /// In en, this message translates to:
  /// **'CREATE NEW SALE ORDER'**
  String get createNewSaleOrder;

  /// No description provided for @createSaleOrderQuickly.
  ///
  /// In en, this message translates to:
  /// **'Create sale order quickly'**
  String get createSaleOrderQuickly;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'MANAGEMENT'**
  String get management;

  /// No description provided for @saleOrderList.
  ///
  /// In en, this message translates to:
  /// **'Sale order list'**
  String get saleOrderList;

  /// No description provided for @viewSearchTrackSales.
  ///
  /// In en, this message translates to:
  /// **'View, search and track all sale orders.'**
  String get viewSearchTrackSales;

  /// No description provided for @addEditViewCustomers.
  ///
  /// In en, this message translates to:
  /// **'Add, edit and view customer information.'**
  String get addEditViewCustomers;

  /// No description provided for @viewProcessWarrantyRequests.
  ///
  /// In en, this message translates to:
  /// **'View and process warranty requests.'**
  String get viewProcessWarrantyRequests;

  /// No description provided for @repairs.
  ///
  /// In en, this message translates to:
  /// **'REPAIRS'**
  String get repairs;

  /// No description provided for @createNewRepairOrder.
  ///
  /// In en, this message translates to:
  /// **'CREATE NEW REPAIR ORDER'**
  String get createNewRepairOrder;

  /// No description provided for @repairOrderList.
  ///
  /// In en, this message translates to:
  /// **'Repair order list'**
  String get repairOrderList;

  /// No description provided for @viewSearchTrackRepairs.
  ///
  /// In en, this message translates to:
  /// **'View, search and track all repair orders.'**
  String get viewSearchTrackRepairs;

  /// No description provided for @holdForDetailedGuide.
  ///
  /// In en, this message translates to:
  /// **'Hold for detailed guide'**
  String get holdForDetailedGuide;

  /// No description provided for @stockInNew.
  ///
  /// In en, this message translates to:
  /// **'STOCK IN NEW'**
  String get stockInNew;

  /// No description provided for @stockInNewGuide.
  ///
  /// In en, this message translates to:
  /// **'Stock in with full information:\n\n✅ Support: Phones, Accessories, Parts\n✅ Save temp: Input when info is incomplete\n✅ Confirm: Stock officially enters inventory\n\n📌 Use when: Inputting new stock from supplier, need full IMEI/SKU, cost price, supplier...'**
  String get stockInNewGuide;

  /// No description provided for @fullInformation.
  ///
  /// In en, this message translates to:
  /// **'Full information'**
  String get fullInformation;

  /// No description provided for @quickStockIn.
  ///
  /// In en, this message translates to:
  /// **'QUICK STOCK IN'**
  String get quickStockIn;

  /// No description provided for @quickStockInGuide.
  ///
  /// In en, this message translates to:
  /// **'Super fast stock in - just scan:\n\n⚡ Scan barcode/QR continuously\n⚡ Auto-fill info from library\n⚡ Suitable for large quantities\n\n📌 Use when: Quick input of accessories, parts already in system.'**
  String get quickStockInGuide;

  /// No description provided for @continuousScan.
  ///
  /// In en, this message translates to:
  /// **'Continuous scan'**
  String get continuousScan;

  /// No description provided for @checkInventoryGuide.
  ///
  /// In en, this message translates to:
  /// **'Check inventory by scanning:\n\n🔍 Scan QR/Barcode to check stock\n🔍 Compare actual vs system quantity\n🔍 Record discrepancies\n\n📌 Use when: Periodic inventory check, stock reconciliation.'**
  String get checkInventoryGuide;

  /// No description provided for @contactOwnerForAccess.
  ///
  /// In en, this message translates to:
  /// **'Contact shop owner for access'**
  String get contactOwnerForAccess;

  /// No description provided for @compareInventory.
  ///
  /// In en, this message translates to:
  /// **'Compare inventory'**
  String get compareInventory;

  /// No description provided for @pendingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Pending confirmation'**
  String get pendingConfirmation;

  /// No description provided for @viewPendingStockList.
  ///
  /// In en, this message translates to:
  /// **'View pending stock confirmation list.'**
  String get viewPendingStockList;

  /// No description provided for @productList.
  ///
  /// In en, this message translates to:
  /// **'Product list'**
  String get productList;

  /// No description provided for @viewManageProducts.
  ///
  /// In en, this message translates to:
  /// **'View and manage products in stock.'**
  String get viewManageProducts;

  /// No description provided for @suppliersPartners.
  ///
  /// In en, this message translates to:
  /// **'Suppliers - Partners'**
  String get suppliersPartners;

  /// No description provided for @manageSupplierPartnerDebt.
  ///
  /// In en, this message translates to:
  /// **'Manage suppliers, repair partners and debts.'**
  String get manageSupplierPartnerDebt;

  /// No description provided for @quickInputCodeList.
  ///
  /// In en, this message translates to:
  /// **'Quick input code list'**
  String get quickInputCodeList;

  /// No description provided for @viewManageQuickInputCodes.
  ///
  /// In en, this message translates to:
  /// **'View and manage quick input codes.'**
  String get viewManageQuickInputCodes;

  /// No description provided for @contactOwnerForPermission.
  ///
  /// In en, this message translates to:
  /// **'Contact shop owner for permission'**
  String get contactOwnerForPermission;

  /// No description provided for @staffManagement.
  ///
  /// In en, this message translates to:
  /// **'STAFF MANAGEMENT'**
  String get staffManagement;

  /// No description provided for @recordWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Record working hours'**
  String get recordWorkingHours;

  /// No description provided for @employeeManagement.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEE MANAGEMENT'**
  String get employeeManagement;

  /// No description provided for @salaryCalculation.
  ///
  /// In en, this message translates to:
  /// **'SALARY\nCalculation'**
  String get salaryCalculation;

  /// No description provided for @workSchedule.
  ///
  /// In en, this message translates to:
  /// **'Work\nSchedule'**
  String get workSchedule;

  /// No description provided for @salaryCommissionSettings.
  ///
  /// In en, this message translates to:
  /// **'Salary &\nCommission Settings'**
  String get salaryCommissionSettings;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'REPORTS'**
  String get reports;

  /// No description provided for @viewAllStaffAttendance.
  ///
  /// In en, this message translates to:
  /// **'View all staff attendance by day/month.'**
  String get viewAllStaffAttendance;

  /// No description provided for @personalAttendance.
  ///
  /// In en, this message translates to:
  /// **'Personal attendance'**
  String get personalAttendance;

  /// No description provided for @checkInOutAndHistory.
  ///
  /// In en, this message translates to:
  /// **'Check-in/out and view personal attendance history.'**
  String get checkInOutAndHistory;

  /// No description provided for @salaryGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'SALARY CALCULATION GUIDE'**
  String get salaryGuideTitle;

  /// No description provided for @goToPayroll.
  ///
  /// In en, this message translates to:
  /// **'GO TO PAYROLL'**
  String get goToPayroll;

  /// No description provided for @financialManagement.
  ///
  /// In en, this message translates to:
  /// **'FINANCIAL MANAGEMENT'**
  String get financialManagement;

  /// No description provided for @closeCashToday.
  ///
  /// In en, this message translates to:
  /// **'CLOSE CASH TODAY'**
  String get closeCashToday;

  /// No description provided for @reconcileCashAndBank.
  ///
  /// In en, this message translates to:
  /// **'Reconcile cash & bank'**
  String get reconcileCashAndBank;

  /// No description provided for @reportsAndAnalysis.
  ///
  /// In en, this message translates to:
  /// **'REPORTS & ANALYSIS'**
  String get reportsAndAnalysis;

  /// No description provided for @revenueOverview.
  ///
  /// In en, this message translates to:
  /// **'Revenue\nOverview'**
  String get revenueOverview;

  /// No description provided for @financialReport.
  ///
  /// In en, this message translates to:
  /// **'Financial\nReport'**
  String get financialReport;

  /// No description provided for @debtManagement.
  ///
  /// In en, this message translates to:
  /// **'Debt\nManagement'**
  String get debtManagement;

  /// No description provided for @bankInstallmentStats.
  ///
  /// In en, this message translates to:
  /// **'Bank\nInstallment Stats'**
  String get bankInstallmentStats;

  /// No description provided for @warrantyTracking.
  ///
  /// In en, this message translates to:
  /// **'Warranty\nTracking'**
  String get warrantyTracking;

  /// No description provided for @debtManagementIncomeExpense.
  ///
  /// In en, this message translates to:
  /// **'Debt Management (Income/Expense)'**
  String get debtManagementIncomeExpense;

  /// No description provided for @summaryAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'Summary of all income/expense transactions.'**
  String get summaryAllTransactions;

  /// No description provided for @financialLog.
  ///
  /// In en, this message translates to:
  /// **'Financial Log'**
  String get financialLog;

  /// No description provided for @trackAllFinancialActivities.
  ///
  /// In en, this message translates to:
  /// **'Track all financial activities.'**
  String get trackAllFinancialActivities;

  /// No description provided for @shopInfoLogoLocationMembers.
  ///
  /// In en, this message translates to:
  /// **'Shop info, logo, location and member management.'**
  String get shopInfoLogoLocationMembers;

  /// No description provided for @configureNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Configure notification and alert settings.'**
  String get configureNotificationSettings;

  /// No description provided for @designPrintTemplates.
  ///
  /// In en, this message translates to:
  /// **'Design print templates for thermal printer.'**
  String get designPrintTemplates;

  /// No description provided for @manageSystemForSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Manage entire system for super admin.'**
  String get manageSystemForSuperAdmin;

  /// No description provided for @developerAndAppInfo.
  ///
  /// In en, this message translates to:
  /// **'Developer and app information.'**
  String get developerAndAppInfo;

  /// No description provided for @dataSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Data sync complete'**
  String get dataSyncComplete;

  /// No description provided for @localCloudMatch100.
  ///
  /// In en, this message translates to:
  /// **'Local and Cloud match 100%'**
  String get localCloudMatch100;

  /// No description provided for @needsDataSync.
  ///
  /// In en, this message translates to:
  /// **'Needs data sync'**
  String get needsDataSync;

  /// No description provided for @salesAndRepairOrders.
  ///
  /// In en, this message translates to:
  /// **'sales + repair orders'**
  String get salesAndRepairOrders;

  /// No description provided for @expiringWarrantiesMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} devices expiring warranty. View now!'**
  String expiringWarrantiesMessage(int count);

  /// No description provided for @productsInStock.
  ///
  /// In en, this message translates to:
  /// **'Products in stock'**
  String get productsInStock;

  /// No description provided for @repairOrdersDataItem.
  ///
  /// In en, this message translates to:
  /// **'Repair orders'**
  String get repairOrdersDataItem;

  /// No description provided for @saleOrdersDataItem.
  ///
  /// In en, this message translates to:
  /// **'Sale orders'**
  String get saleOrdersDataItem;

  /// No description provided for @debtsAndExpensesDataItem.
  ///
  /// In en, this message translates to:
  /// **'Debts & Expenses'**
  String get debtsAndExpensesDataItem;

  /// No description provided for @customersAndSuppliersDataItem.
  ///
  /// In en, this message translates to:
  /// **'Customers & Suppliers'**
  String get customersAndSuppliersDataItem;

  /// No description provided for @downloadDataOf.
  ///
  /// In en, this message translates to:
  /// **'Download data of'**
  String get downloadDataOf;

  /// No description provided for @fromCloudToThisDevice.
  ///
  /// In en, this message translates to:
  /// **'from cloud to this device.'**
  String get fromCloudToThisDevice;

  /// No description provided for @onlyDownloadThisShopData.
  ///
  /// In en, this message translates to:
  /// **'Only download this shop\'s data, won\'t affect others.'**
  String get onlyDownloadThisShopData;

  /// No description provided for @processMayTakeFewMinutes.
  ///
  /// In en, this message translates to:
  /// **'Process may take a few minutes depending on data size.'**
  String get processMayTakeFewMinutes;

  /// No description provided for @downloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shop data downloaded successfully!'**
  String get downloadSuccess;

  /// No description provided for @downloadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String downloadError(String error);

  /// No description provided for @dataFullySynced.
  ///
  /// In en, this message translates to:
  /// **'Data fully synced'**
  String get dataFullySynced;

  /// No description provided for @localAndCloudMatched.
  ///
  /// In en, this message translates to:
  /// **'Local and cloud data matched'**
  String get localAndCloudMatched;

  /// No description provided for @syncNeeded.
  ///
  /// In en, this message translates to:
  /// **'Sync needed'**
  String get syncNeeded;

  /// No description provided for @comparingLocalVsCloud.
  ///
  /// In en, this message translates to:
  /// **'Comparing local and cloud data...'**
  String get comparingLocalVsCloud;

  /// No description provided for @saleAndRepairCount.
  ///
  /// In en, this message translates to:
  /// **'{saleCount} sales + {repairCount} repairs'**
  String saleAndRepairCount(int saleCount, int repairCount);

  /// No description provided for @saleAndRepairOrders.
  ///
  /// In en, this message translates to:
  /// **'{saleCount} sales + {repairCount} repairs'**
  String saleAndRepairOrders(int saleCount, int repairCount);

  /// No description provided for @expenseItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} expense items'**
  String expenseItemsCount(int count);

  /// No description provided for @expiringWarrantiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} devices expiring warranty. View now!'**
  String expiringWarrantiesCount(int count);

  /// No description provided for @registerAccount.
  ///
  /// In en, this message translates to:
  /// **'Account Registration'**
  String get registerAccount;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get step;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @storeOwner.
  ///
  /// In en, this message translates to:
  /// **'Store Owner'**
  String get storeOwner;

  /// No description provided for @createNewShop.
  ///
  /// In en, this message translates to:
  /// **'Create a new shop and manage employees'**
  String get createNewShop;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employee;

  /// No description provided for @joinExistingShop.
  ///
  /// In en, this message translates to:
  /// **'Join an existing shop via invitation code'**
  String get joinExistingShop;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopName;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Login Email'**
  String get loginEmail;

  /// No description provided for @emailAutoGenerated.
  ///
  /// In en, this message translates to:
  /// **'Email is automatically generated from name and shop name'**
  String get emailAutoGenerated;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @shopInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Shop Invitation Code'**
  String get shopInviteCode;

  /// No description provided for @howToGetInviteCode.
  ///
  /// In en, this message translates to:
  /// **'HOW TO GET INVITATION CODE'**
  String get howToGetInviteCode;

  /// No description provided for @joinShopInstructions.
  ///
  /// In en, this message translates to:
  /// **'To join a shop, please ask the store owner to follow these steps:'**
  String get joinShopInstructions;

  /// No description provided for @storeOwnerLogin.
  ///
  /// In en, this message translates to:
  /// **'Store owner logs into the app'**
  String get storeOwnerLogin;

  /// No description provided for @selectStaffTab.
  ///
  /// In en, this message translates to:
  /// **'Select the \'Staff\' tab in bottom navigation'**
  String get selectStaffTab;

  /// No description provided for @selectEmployeeList.
  ///
  /// In en, this message translates to:
  /// **'Select \'Employee List\''**
  String get selectEmployeeList;

  /// No description provided for @selectRegisterEmployee.
  ///
  /// In en, this message translates to:
  /// **'Select register account for shop employee'**
  String get selectRegisterEmployee;

  /// No description provided for @ownerProvidesCredentials.
  ///
  /// In en, this message translates to:
  /// **'Store owner provides account and password to you'**
  String get ownerProvidesCredentials;

  /// No description provided for @loginWithCredentials.
  ///
  /// In en, this message translates to:
  /// **'After having account and password, you can log in and join the shop.'**
  String get loginWithCredentials;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'REGISTER'**
  String get register;

  /// No description provided for @step1of2.
  ///
  /// In en, this message translates to:
  /// **'Step 1/2'**
  String get step1of2;

  /// No description provided for @step2of2.
  ///
  /// In en, this message translates to:
  /// **'Step 2/2'**
  String get step2of2;

  /// No description provided for @printerSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Printer settings saved'**
  String get printerSettingsSaved;

  /// No description provided for @bluetoothPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission required'**
  String get bluetoothPermissionRequired;

  /// No description provided for @enableBluetoothToScan.
  ///
  /// In en, this message translates to:
  /// **'Enable Bluetooth to scan printers'**
  String get enableBluetoothToScan;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found. Pair first in Bluetooth settings.'**
  String get noDevicesFound;

  /// No description provided for @bluetoothScanError.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth scan error: {error}'**
  String bluetoothScanError(String error);

  /// No description provided for @selectBluetoothPrinter.
  ///
  /// In en, this message translates to:
  /// **'Select Bluetooth Printer'**
  String get selectBluetoothPrinter;

  /// No description provided for @enterIpFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter IP address first'**
  String get enterIpFirst;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing connection...'**
  String get testingConnection;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful!'**
  String get connectionSuccessful;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect: {error}'**
  String connectionFailed(String error);

  /// No description provided for @selectBluetoothPrinterFirst.
  ///
  /// In en, this message translates to:
  /// **'Select Bluetooth printer first'**
  String get selectBluetoothPrinterFirst;

  /// No description provided for @bluetoothConnectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth connection successful!'**
  String get bluetoothConnectionSuccessful;

  /// No description provided for @bluetoothConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect Bluetooth'**
  String get bluetoothConnectionFailed;

  /// No description provided for @printerSettings.
  ///
  /// In en, this message translates to:
  /// **'PRINTER SETTINGS'**
  String get printerSettings;

  /// No description provided for @labelDesign.
  ///
  /// In en, this message translates to:
  /// **'LABEL DESIGN'**
  String get labelDesign;

  /// No description provided for @wifiPrinterConnection.
  ///
  /// In en, this message translates to:
  /// **'WIFI PRINTER CONNECTION'**
  String get wifiPrinterConnection;

  /// No description provided for @bluetoothPrinterConnection.
  ///
  /// In en, this message translates to:
  /// **'BLUETOOTH PRINTER CONNECTION'**
  String get bluetoothPrinterConnection;

  /// No description provided for @receiptSettings.
  ///
  /// In en, this message translates to:
  /// **'RECEIPT SETTINGS'**
  String get receiptSettings;

  /// No description provided for @productLabelDesign.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT LABEL DESIGN'**
  String get productLabelDesign;

  /// No description provided for @customizeContentAndFontSize.
  ///
  /// In en, this message translates to:
  /// **'Customize content and font size'**
  String get customizeContentAndFontSize;

  /// No description provided for @layoutShopInfoFormula.
  ///
  /// In en, this message translates to:
  /// **'Layout, shop info, CPK formula'**
  String get layoutShopInfoFormula;

  /// No description provided for @hot.
  ///
  /// In en, this message translates to:
  /// **'HOT'**
  String get hot;

  /// No description provided for @wifiPrinter.
  ///
  /// In en, this message translates to:
  /// **'WIFI PRINTER'**
  String get wifiPrinter;

  /// No description provided for @printerIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Printer IP address'**
  String get printerIpAddress;

  /// No description provided for @backupIpOptional.
  ///
  /// In en, this message translates to:
  /// **'Backup IP (optional)'**
  String get backupIpOptional;

  /// No description provided for @testWifiConnection.
  ///
  /// In en, this message translates to:
  /// **'TEST WIFI CONNECTION'**
  String get testWifiConnection;

  /// No description provided for @bluetoothPrinter.
  ///
  /// In en, this message translates to:
  /// **'BLUETOOTH PRINTER'**
  String get bluetoothPrinter;

  /// No description provided for @noBluetoothPrinterSelected.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth printer selected'**
  String get noBluetoothPrinterSelected;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'SCANNING...'**
  String get scanning;

  /// No description provided for @scanBluetooth.
  ///
  /// In en, this message translates to:
  /// **'SCAN BLUETOOTH'**
  String get scanBluetooth;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'TEST'**
  String get test;

  /// No description provided for @receiptSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'RECEIPT SETTINGS'**
  String get receiptSettingsTitle;

  /// No description provided for @showShopLogo.
  ///
  /// In en, this message translates to:
  /// **'Show shop logo'**
  String get showShopLogo;

  /// No description provided for @showPhoneAndAddress.
  ///
  /// In en, this message translates to:
  /// **'Show phone & address'**
  String get showPhoneAndAddress;

  /// No description provided for @showQrCodeLookup.
  ///
  /// In en, this message translates to:
  /// **'Show QR code lookup'**
  String get showQrCodeLookup;

  /// No description provided for @receiptClosingMessage.
  ///
  /// In en, this message translates to:
  /// **'Receipt closing message'**
  String get receiptClosingMessage;

  /// No description provided for @thankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get thankYou;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {deviceName}'**
  String selected(String deviceName);

  /// No description provided for @learnHowToUseApp.
  ///
  /// In en, this message translates to:
  /// **'Learn how to use the Shopmanager app'**
  String get learnHowToUseApp;

  /// No description provided for @searchGuides.
  ///
  /// In en, this message translates to:
  /// **'Search guides...'**
  String get searchGuides;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newLabel;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @tryDifferentKeywords.
  ///
  /// In en, this message translates to:
  /// **'Try searching with different keywords'**
  String get tryDifferentKeywords;

  /// No description provided for @foundResults.
  ///
  /// In en, this message translates to:
  /// **'Found {count} results'**
  String foundResults(int count);

  /// No description provided for @needMoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Need more help?'**
  String get needMoreHelp;

  /// No description provided for @supportTeamReady.
  ///
  /// In en, this message translates to:
  /// **'If you can\'t find the answer, our support team is ready to help.'**
  String get supportTeamReady;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'support@huluca.com'**
  String get supportEmail;

  /// No description provided for @hotline.
  ///
  /// In en, this message translates to:
  /// **'Hotline: 1900 xxxx'**
  String get hotline;

  /// No description provided for @supportHotline.
  ///
  /// In en, this message translates to:
  /// **'Support hotline: 1900 xxxx'**
  String get supportHotline;

  /// No description provided for @stepsToPerform.
  ///
  /// In en, this message translates to:
  /// **'Steps to perform'**
  String get stepsToPerform;

  /// No description provided for @usefulTips.
  ///
  /// In en, this message translates to:
  /// **'💡 Useful tips'**
  String get usefulTips;

  /// No description provided for @importantNotes.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Important notes'**
  String get importantNotes;

  /// No description provided for @relatedArticles.
  ///
  /// In en, this message translates to:
  /// **'📚 Related articles'**
  String get relatedArticles;

  /// No description provided for @wasArticleHelpful.
  ///
  /// In en, this message translates to:
  /// **'Was this article helpful?'**
  String get wasArticleHelpful;

  /// No description provided for @thankYouForFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback! 🎉'**
  String get thankYouForFeedback;

  /// No description provided for @weWillImprove.
  ///
  /// In en, this message translates to:
  /// **'We will improve this content!'**
  String get weWillImprove;

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;

  /// No description provided for @stepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String stepsCount(int count);

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get skip;

  /// No description provided for @welcomeToShopManager.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Shop Manager'**
  String get welcomeToShopManager;

  /// No description provided for @welcomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Multi-industry shop management: Electronics, Food, Fashion & more. Easy to use, powerful and efficient for all business needs.'**
  String get welcomeDesc;

  /// No description provided for @professionalSalesManagement.
  ///
  /// In en, this message translates to:
  /// **'Professional Sales Management'**
  String get professionalSalesManagement;

  /// No description provided for @salesDesc.
  ///
  /// In en, this message translates to:
  /// **'Create sales orders quickly, track revenue, manage customers and product warranties easily.'**
  String get salesDesc;

  /// No description provided for @repairAndWarranty.
  ///
  /// In en, this message translates to:
  /// **'Repair & Warranty'**
  String get repairAndWarranty;

  /// No description provided for @repairDesc.
  ///
  /// In en, this message translates to:
  /// **'Track repair progress, manage parts, update order status and handle warranties efficiently.'**
  String get repairDesc;

  /// No description provided for @smartInventoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Smart Inventory Management'**
  String get smartInventoryManagement;

  /// No description provided for @inventoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Ultra-fast inventory input with QR code and IMEI. 100% accurate inventory control with automatic inventory system.'**
  String get inventoryDesc;

  /// No description provided for @staffAndAttendance.
  ///
  /// In en, this message translates to:
  /// **'Staff & Attendance'**
  String get staffAndAttendance;

  /// No description provided for @staffDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage employees, track attendance with selfie, calculate salary and evaluate work performance.'**
  String get staffDesc;

  /// No description provided for @financeAndReports.
  ///
  /// In en, this message translates to:
  /// **'Finance & Reports'**
  String get financeAndReports;

  /// No description provided for @financeDesc.
  ///
  /// In en, this message translates to:
  /// **'View detailed revenue reports, manage expenses, track debts and comprehensive financial analysis.'**
  String get financeDesc;

  /// No description provided for @internalChatAndNotifications.
  ///
  /// In en, this message translates to:
  /// **'Internal Chat & Notifications'**
  String get internalChatAndNotifications;

  /// No description provided for @chatDesc.
  ///
  /// In en, this message translates to:
  /// **'Real-time communication with staff, instant notifications and management of general shop information.'**
  String get chatDesc;

  /// No description provided for @printReceiptsAndDeviceConnection.
  ///
  /// In en, this message translates to:
  /// **'Print Receipts & Device Connection'**
  String get printReceiptsAndDeviceConnection;

  /// No description provided for @printDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect Bluetooth/WiFi thermal printers. Print professional labels and receipts with one touch.'**
  String get printDesc;

  /// No description provided for @cloudSync247.
  ///
  /// In en, this message translates to:
  /// **'24/7 Cloud Sync'**
  String get cloudSync247;

  /// No description provided for @cloudDesc.
  ///
  /// In en, this message translates to:
  /// **'Data always safe and synchronized instantly between all devices. Manage shop remotely anytime, anywhere.'**
  String get cloudDesc;

  /// No description provided for @startJourney.
  ///
  /// In en, this message translates to:
  /// **'Start Your Journey'**
  String get startJourney;

  /// No description provided for @startDesc.
  ///
  /// In en, this message translates to:
  /// **'Explore all features and manage your shop efficiently. Wish you success!'**
  String get startDesc;

  /// No description provided for @hulucaShop.
  ///
  /// In en, this message translates to:
  /// **'HULUCA SHOP'**
  String get hulucaShop;

  /// No description provided for @phoneRepairShopManagement.
  ///
  /// In en, this message translates to:
  /// **'Multi-Industry Shop Management'**
  String get phoneRepairShopManagement;

  /// No description provided for @repairManagement.
  ///
  /// In en, this message translates to:
  /// **'Repair Management'**
  String get repairManagement;

  /// No description provided for @repairManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Track repair orders from receiving to delivery'**
  String get repairManagementDesc;

  /// No description provided for @inventoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management'**
  String get inventoryManagement;

  /// No description provided for @inventoryManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Import goods, export inventory, check parts'**
  String get inventoryManagementDesc;

  /// No description provided for @salesAndDebt.
  ///
  /// In en, this message translates to:
  /// **'Sales & Debt'**
  String get salesAndDebt;

  /// No description provided for @salesAndDebtDesc.
  ///
  /// In en, this message translates to:
  /// **'Fast sales, track customer debt'**
  String get salesAndDebtDesc;

  /// No description provided for @supplierAndPartnerManagement.
  ///
  /// In en, this message translates to:
  /// **'Supplier & Partner Management'**
  String get supplierAndPartnerManagement;

  /// No description provided for @supplierAndPartnerManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Track supplier and partner debt'**
  String get supplierAndPartnerManagementDesc;

  /// No description provided for @reportsAndStatistics.
  ///
  /// In en, this message translates to:
  /// **'Reports & Statistics'**
  String get reportsAndStatistics;

  /// No description provided for @reportsAndStatisticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Revenue, profit, inventory over time'**
  String get reportsAndStatisticsDesc;

  /// No description provided for @cloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudSync;

  /// No description provided for @cloudSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Safe data, access anytime, anywhere'**
  String get cloudSyncDesc;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @salaryCalculationGuide.
  ///
  /// In en, this message translates to:
  /// **'SALARY CALCULATION GUIDE'**
  String get salaryCalculationGuide;

  /// No description provided for @accessSalaryTable.
  ///
  /// In en, this message translates to:
  /// **'Access salary table'**
  String get accessSalaryTable;

  /// No description provided for @accessSalaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Go to Staff tab → Press \"SALARY Calculate salary\" to view all employees\' salary table.'**
  String get accessSalaryDesc;

  /// No description provided for @salarySettings.
  ///
  /// In en, this message translates to:
  /// **'Salary settings'**
  String get salarySettings;

  /// No description provided for @salarySettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'• Default settings: ⚙️ icon → \"DEFAULT\" tab\n• Individual settings: \"EMPLOYEES\" tab → Select employee → \"Individual settings\"'**
  String get salarySettingsDesc;

  /// No description provided for @salaryComponents.
  ///
  /// In en, this message translates to:
  /// **'Salary components'**
  String get salaryComponents;

  /// No description provided for @salaryComponentsDesc.
  ///
  /// In en, this message translates to:
  /// **'• Basic salary (monthly/daily/hourly)\n• Sales commission (% or fixed)\n• Repair commission\n• Allowances (travel, lunch, phone...)\n• Overtime OT (150%, 200% rates...)'**
  String get salaryComponentsDesc;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @viewDetailsDesc.
  ///
  /// In en, this message translates to:
  /// **'Click on employee name to view:\n• INCOME: Salary + Commission + Allowances + Bonus + OT\n• DEDUCTIONS: PIT + SI + HI + UI\n• NET PAY: Total income - Total deductions'**
  String get viewDetailsDesc;

  /// No description provided for @printSalarySlip.
  ///
  /// In en, this message translates to:
  /// **'Print salary slip'**
  String get printSalarySlip;

  /// No description provided for @printSalaryDesc.
  ///
  /// In en, this message translates to:
  /// **'• Print summary: 🖨️ icon → \"Print consolidated salary table\"\n• Print individual: Open employee details → \"Print salary slip\"'**
  String get printSalaryDesc;

  /// No description provided for @taxAndInsurance.
  ///
  /// In en, this message translates to:
  /// **'Tax & Insurance'**
  String get taxAndInsurance;

  /// No description provided for @taxAndInsuranceDesc.
  ///
  /// In en, this message translates to:
  /// **'💳 \"Deduction/Tax Settings\" icon:\n• Personal deduction: 11 million\n• SI 8%, HI 1.5%, UI 1%'**
  String get taxAndInsuranceDesc;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'UNDERSTOOD'**
  String get understood;

  /// No description provided for @goToSalaryTable.
  ///
  /// In en, this message translates to:
  /// **'GO TO SALARY TABLE'**
  String get goToSalaryTable;

  /// No description provided for @staffListLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff\nList'**
  String get staffListLabel;

  /// No description provided for @viewAttendanceAllStaff.
  ///
  /// In en, this message translates to:
  /// **'View attendance of all staff by day/month.'**
  String get viewAttendanceAllStaff;

  /// No description provided for @personalAttendanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Check-in/out and view personal attendance history.'**
  String get personalAttendanceDescription;

  /// No description provided for @usageGuide.
  ///
  /// In en, this message translates to:
  /// **'Usage guide'**
  String get usageGuide;

  /// No description provided for @cashClosingToday.
  ///
  /// In en, this message translates to:
  /// **'CASH CLOSING TODAY'**
  String get cashClosingToday;

  /// No description provided for @reportAndAnalysis.
  ///
  /// In en, this message translates to:
  /// **'REPORTS & ANALYSIS'**
  String get reportAndAnalysis;

  /// No description provided for @manageAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'Manage all income/expense transactions.'**
  String get manageAllTransactions;

  /// No description provided for @expenseManagement.
  ///
  /// In en, this message translates to:
  /// **'Expense Management'**
  String get expenseManagement;

  /// No description provided for @addTrackShopExpenses.
  ///
  /// In en, this message translates to:
  /// **'Add and track shop expenses.'**
  String get addTrackShopExpenses;

  /// No description provided for @debtManagementInOut.
  ///
  /// In en, this message translates to:
  /// **'Debt Management (In/Out)'**
  String get debtManagementInOut;

  /// No description provided for @recordPayDebts.
  ///
  /// In en, this message translates to:
  /// **'Record and pay debts.'**
  String get recordPayDebts;

  /// No description provided for @financialReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Financial Report'**
  String get financialReportLabel;

  /// No description provided for @summarizeAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'Summarize all income/expense transactions.'**
  String get summarizeAllTransactions;

  /// No description provided for @financialActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Financial Activity Log'**
  String get financialActivityLog;

  /// No description provided for @trackAllIncomeExpenseActivities.
  ///
  /// In en, this message translates to:
  /// **'Track all income/expense activities.'**
  String get trackAllIncomeExpenseActivities;

  /// No description provided for @todayIncome.
  ///
  /// In en, this message translates to:
  /// **'TODAY INCOME'**
  String get todayIncome;

  /// No description provided for @todayExpense.
  ///
  /// In en, this message translates to:
  /// **'TODAY EXPENSE'**
  String get todayExpense;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'sales'**
  String get sales;

  /// No description provided for @repair.
  ///
  /// In en, this message translates to:
  /// **'repair'**
  String get repair;

  /// No description provided for @expenseItems.
  ///
  /// In en, this message translates to:
  /// **'expense items'**
  String get expenseItems;

  /// No description provided for @todayNetProfit.
  ///
  /// In en, this message translates to:
  /// **'TODAY NET PROFIT'**
  String get todayNetProfit;

  /// No description provided for @totalDebt.
  ///
  /// In en, this message translates to:
  /// **'TOTAL DEBT'**
  String get totalDebt;

  /// No description provided for @shopSettings.
  ///
  /// In en, this message translates to:
  /// **'Shop Settings'**
  String get shopSettings;

  /// No description provided for @shopSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Information, logo, location and shop member management.'**
  String get shopSettingsDescription;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure notification and alert settings.'**
  String get notificationSettingsDescription;

  /// No description provided for @printer.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printer;

  /// No description provided for @printerSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Setup connection and print template design.'**
  String get printerSettingsDescription;

  /// No description provided for @adminCenter.
  ///
  /// In en, this message translates to:
  /// **'Admin Center'**
  String get adminCenter;

  /// No description provided for @adminCenterDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage entire system for super admin.'**
  String get adminCenterDescription;

  /// No description provided for @aboutDeveloperDescription.
  ///
  /// In en, this message translates to:
  /// **'Information about developer and application.'**
  String get aboutDeveloperDescription;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT'**
  String get logout;

  /// No description provided for @logoutFromAccount.
  ///
  /// In en, this message translates to:
  /// **'Logout from account'**
  String get logoutFromAccount;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout from this account?'**
  String get logoutConfirmMessage;

  /// No description provided for @needSyncData.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Need data sync'**
  String get needSyncData;

  /// No description provided for @recordsNotSynced.
  ///
  /// In en, this message translates to:
  /// **'records not synced. Tap to open Sync Center.'**
  String recordsNotSynced(int count);

  /// No description provided for @todayFinancialReport.
  ///
  /// In en, this message translates to:
  /// **'TODAY FINANCIAL REPORT'**
  String get todayFinancialReport;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @saleOrders.
  ///
  /// In en, this message translates to:
  /// **'sale orders'**
  String get saleOrders;

  /// No description provided for @repairOrders.
  ///
  /// In en, this message translates to:
  /// **'repair orders'**
  String get repairOrders;

  /// No description provided for @todayActivity.
  ///
  /// In en, this message translates to:
  /// **'TODAY ACTIVITY'**
  String get todayActivity;

  /// No description provided for @pendingRepairs.
  ///
  /// In en, this message translates to:
  /// **'Pending repairs'**
  String get pendingRepairs;

  /// No description provided for @netProfitFormula.
  ///
  /// In en, this message translates to:
  /// **'= Income - Expense - Cost'**
  String get netProfitFormula;

  /// No description provided for @userGuide.
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get userGuide;

  /// No description provided for @viewDetailedGuideForEachFeature.
  ///
  /// In en, this message translates to:
  /// **'View detailed guide for each feature in app'**
  String get viewDetailedGuideForEachFeature;

  /// No description provided for @warrantyReminder.
  ///
  /// In en, this message translates to:
  /// **'WARRANTY REMINDER'**
  String get warrantyReminder;

  /// No description provided for @devicesExpiringWarranty.
  ///
  /// In en, this message translates to:
  /// **'devices expiring warranty soon. View now!'**
  String get devicesExpiringWarranty;

  /// No description provided for @checkingSync.
  ///
  /// In en, this message translates to:
  /// **'Checking sync...'**
  String get checkingSync;

  /// No description provided for @checkingLocalVsCloud.
  ///
  /// In en, this message translates to:
  /// **'Checking local vs cloud data'**
  String get checkingLocalVsCloud;

  /// No description provided for @dataSyncedFully.
  ///
  /// In en, this message translates to:
  /// **'✅ Data synced fully'**
  String get dataSyncedFully;

  /// No description provided for @localCloudMatched.
  ///
  /// In en, this message translates to:
  /// **'Local and Cloud matched 100%'**
  String get localCloudMatched;

  /// No description provided for @recheckingSync.
  ///
  /// In en, this message translates to:
  /// **'🔄 Rechecking...'**
  String get recheckingSync;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit app?'**
  String get exitApp;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get exit;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered by someone else.'**
  String get emailAlreadyInUse;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password too weak, at least 6 characters required.'**
  String get weakPassword;

  /// No description provided for @invalidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address format.'**
  String get invalidEmailAddress;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network connection error. Please check your internet and try again.'**
  String get networkError;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get tooManyRequests;

  /// No description provided for @pleaseEnterShopName.
  ///
  /// In en, this message translates to:
  /// **'Please enter shop name.'**
  String get pleaseEnterShopName;

  /// No description provided for @pleaseEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter full name.'**
  String get pleaseEnterFullName;

  /// No description provided for @pleaseEnterRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in required fields.'**
  String get pleaseEnterRequiredFields;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Password confirmation does not match.'**
  String get passwordMismatch;

  /// No description provided for @invalidOrExpiredInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code is incorrect or expired.'**
  String get invalidOrExpiredInviteCode;

  /// No description provided for @loadingShopData.
  ///
  /// In en, this message translates to:
  /// **'Loading shop data...'**
  String get loadingShopData;

  /// No description provided for @switchedToShop.
  ///
  /// In en, this message translates to:
  /// **'Switched to shop: {shopName}'**
  String switchedToShop(String shopName);

  /// No description provided for @errorSwitchingShop.
  ///
  /// In en, this message translates to:
  /// **'Error switching shop: {error}'**
  String errorSwitchingShop(String error);

  /// No description provided for @onlySuperAdminCanDelete.
  ///
  /// In en, this message translates to:
  /// **'ONLY SUPER ADMIN CAN DELETE SHOP DATA!'**
  String get onlySuperAdminCanDelete;

  /// No description provided for @dangerWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ DANGER WARNING'**
  String get dangerWarning;

  /// No description provided for @deleteAllDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This action will delete 100% of Orders, Inventory, Debts and Logs of the Shop on both Cloud and this Device. CANNOT BE RECOVERED!'**
  String get deleteAllDataWarning;

  /// No description provided for @typeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type \'DELETE ALL\' to confirm:'**
  String get typeToConfirm;

  /// No description provided for @deleteAllPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'DELETE ALL'**
  String get deleteAllPlaceholder;

  /// No description provided for @confirmDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM DELETE ALL'**
  String get confirmDeleteAll;

  /// No description provided for @shopDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'SHOP DATA DELETED!'**
  String get shopDataDeleted;

  /// No description provided for @errorDeletingCloudData.
  ///
  /// In en, this message translates to:
  /// **'ERROR DELETING CLOUD DATA: {error}'**
  String errorDeletingCloudData(String error);

  /// No description provided for @userGuideSection.
  ///
  /// In en, this message translates to:
  /// **'📚 User Guide'**
  String get userGuideSection;

  /// No description provided for @userGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get userGuideTitle;

  /// No description provided for @userGuideDesc.
  ///
  /// In en, this message translates to:
  /// **'Detailed step-by-step guide for every feature in the app.'**
  String get userGuideDesc;

  /// No description provided for @inventoryFeature.
  ///
  /// In en, this message translates to:
  /// **'📦 Inventory'**
  String get inventoryFeature;

  /// No description provided for @salesFeature.
  ///
  /// In en, this message translates to:
  /// **'🛒 Sales'**
  String get salesFeature;

  /// No description provided for @repairFeature.
  ///
  /// In en, this message translates to:
  /// **'🔧 Repair'**
  String get repairFeature;

  /// No description provided for @reportFeature.
  ///
  /// In en, this message translates to:
  /// **'📊 Reports'**
  String get reportFeature;

  /// No description provided for @reviewUserGuide.
  ///
  /// In en, this message translates to:
  /// **'Review User Guide'**
  String get reviewUserGuide;

  /// No description provided for @resetGuidesDesc.
  ///
  /// In en, this message translates to:
  /// **'Reset to show first-time guides again'**
  String get resetGuidesDesc;

  /// No description provided for @guidesReset.
  ///
  /// In en, this message translates to:
  /// **'Done! Guides will show again when entering screens.'**
  String get guidesReset;

  /// No description provided for @changedToVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Changed to Vietnamese'**
  String get changedToVietnamese;

  /// No description provided for @changedToEnglish.
  ///
  /// In en, this message translates to:
  /// **'Changed to English'**
  String get changedToEnglish;

  /// No description provided for @replacePin.
  ///
  /// In en, this message translates to:
  /// **'REPLACE PIN'**
  String get replacePin;

  /// No description provided for @pressGlass.
  ///
  /// In en, this message translates to:
  /// **'PRESS GLASS'**
  String get pressGlass;

  /// No description provided for @replaceScreen.
  ///
  /// In en, this message translates to:
  /// **'REPLACE SCREEN'**
  String get replaceScreen;

  /// No description provided for @noPower.
  ///
  /// In en, this message translates to:
  /// **'NO POWER'**
  String get noPower;

  /// No description provided for @speakerMic.
  ///
  /// In en, this message translates to:
  /// **'SPEAKER/MIC'**
  String get speakerMic;

  /// No description provided for @charging.
  ///
  /// In en, this message translates to:
  /// **'CHARGING'**
  String get charging;

  /// No description provided for @software.
  ///
  /// In en, this message translates to:
  /// **'SOFTWARE'**
  String get software;

  /// No description provided for @sim.
  ///
  /// In en, this message translates to:
  /// **'SIM'**
  String get sim;

  /// No description provided for @backCover.
  ///
  /// In en, this message translates to:
  /// **'BACK COVER'**
  String get backCover;

  /// No description provided for @walkInCustomerNoSave.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer - not saved to contacts'**
  String get walkInCustomerNoSave;

  /// No description provided for @pleaseEnterNameAndPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter both name and phone number'**
  String get pleaseEnterNameAndPhone;

  /// No description provided for @customerWithPhoneExists.
  ///
  /// In en, this message translates to:
  /// **'Customer with this phone already exists: {name}'**
  String customerWithPhoneExists(String name);

  /// No description provided for @customerAdded.
  ///
  /// In en, this message translates to:
  /// **'Customer added: {name}'**
  String customerAdded(String name);

  /// No description provided for @errorAddingCustomer.
  ///
  /// In en, this message translates to:
  /// **'Error adding customer: {error}'**
  String errorAddingCustomer(String error);

  /// No description provided for @pleaseEnterModel.
  ///
  /// In en, this message translates to:
  /// **'Please enter device Model'**
  String get pleaseEnterModel;

  /// No description provided for @pleaseEnterPhoneAndModel.
  ///
  /// In en, this message translates to:
  /// **'Please enter Phone and device Model'**
  String get pleaseEnterPhoneAndModel;

  /// No description provided for @syncingDataToServer.
  ///
  /// In en, this message translates to:
  /// **'Syncing data to server...'**
  String get syncingDataToServer;

  /// No description provided for @createRepairOrder.
  ///
  /// In en, this message translates to:
  /// **'CREATE REPAIR'**
  String get createRepairOrder;

  /// No description provided for @repairOrderCreated.
  ///
  /// In en, this message translates to:
  /// **'Created repair order {model} for customer {customer}'**
  String repairOrderCreated(String model, String customer);

  /// No description provided for @orderSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'ORDER SAVED SUCCESSFULLY'**
  String get orderSavedSuccess;

  /// No description provided for @sendingPrintCommand.
  ///
  /// In en, this message translates to:
  /// **'Sending print command...'**
  String get sendingPrintCommand;

  /// No description provided for @partnerCost.
  ///
  /// In en, this message translates to:
  /// **'Partner: {partner} - Cost: {cost}'**
  String partnerCost(String partner, String cost);

  /// No description provided for @costOnly.
  ///
  /// In en, this message translates to:
  /// **'Cost: {cost}'**
  String costOnly(String cost);

  /// No description provided for @totalCost.
  ///
  /// In en, this message translates to:
  /// **'Total cost: {amount}'**
  String totalCost(String amount);

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'ADD SERVICE'**
  String get addService;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service name *'**
  String get serviceName;

  /// No description provided for @costVND.
  ///
  /// In en, this message translates to:
  /// **'Cost (VND)'**
  String get costVND;

  /// No description provided for @partnerOptional.
  ///
  /// In en, this message translates to:
  /// **'Partner (optional)'**
  String get partnerOptional;

  /// No description provided for @noPartner.
  ///
  /// In en, this message translates to:
  /// **'No partner'**
  String get noPartner;

  /// No description provided for @partnerPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Partner payment method *'**
  String get partnerPaymentMethod;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @saveOrder.
  ///
  /// In en, this message translates to:
  /// **'SAVE ORDER'**
  String get saveOrder;

  /// No description provided for @customerAndDevice.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER & DEVICE'**
  String get customerAndDevice;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone *'**
  String get phoneRequired;

  /// No description provided for @customerNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Customer name (optional)'**
  String get customerNameOptional;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerName;

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'DEVICE MODEL *'**
  String get deviceModel;

  /// No description provided for @deviceIssue.
  ///
  /// In en, this message translates to:
  /// **'DEVICE ISSUE *'**
  String get deviceIssue;

  /// No description provided for @estimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'ESTIMATED PRICE'**
  String get estimatedPrice;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'SERVICES'**
  String get services;

  /// No description provided for @securityAccessories.
  ///
  /// In en, this message translates to:
  /// **'SECURITY & ACCESSORIES'**
  String get securityAccessories;

  /// No description provided for @screenPassword.
  ///
  /// In en, this message translates to:
  /// **'Screen password'**
  String get screenPassword;

  /// No description provided for @otherAccessories.
  ///
  /// In en, this message translates to:
  /// **'Other accessories'**
  String get otherAccessories;

  /// No description provided for @notesAndImages.
  ///
  /// In en, this message translates to:
  /// **'NOTES & IMAGES'**
  String get notesAndImages;

  /// No description provided for @notesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Notes...'**
  String get notesPlaceholder;

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer (not saved to contacts)'**
  String get walkInCustomer;

  /// No description provided for @walkInCustomerDesc.
  ///
  /// In en, this message translates to:
  /// **'Name/Phone only saved on receipt, phone not required'**
  String get walkInCustomerDesc;

  /// No description provided for @saveToContactsDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter phone to save customer to contacts'**
  String get saveToContactsDesc;

  /// No description provided for @walkInCustomerDefault.
  ///
  /// In en, this message translates to:
  /// **'WALK-IN CUSTOMER'**
  String get walkInCustomerDefault;

  /// No description provided for @createRepairOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'CREATE REPAIR ORDER'**
  String get createRepairOrderTitle;

  /// No description provided for @fillCustomerAndDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Fill customer and device info'**
  String get fillCustomerAndDeviceInfo;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get selectCustomer;

  /// No description provided for @todayClosedNoRepair.
  ///
  /// In en, this message translates to:
  /// **'❌ Today is closed! Cannot create new repair order.'**
  String get todayClosedNoRepair;

  /// No description provided for @selectCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'SELECT CUSTOMER'**
  String get selectCustomerTitle;

  /// No description provided for @searchByNameOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get searchByNameOrPhone;

  /// No description provided for @noCustomerFound.
  ///
  /// In en, this message translates to:
  /// **'No customer found'**
  String get noCustomerFound;

  /// No description provided for @repairInputAction.
  ///
  /// In en, this message translates to:
  /// **'CREATE REPAIR ORDER'**
  String get repairInputAction;

  /// No description provided for @repairInputDesc.
  ///
  /// In en, this message translates to:
  /// **'Created repair order {model} for customer {customer}'**
  String repairInputDesc(String model, String customer);

  /// No description provided for @repairPartner.
  ///
  /// In en, this message translates to:
  /// **'Repair partner'**
  String get repairPartner;

  /// No description provided for @resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get resetAll;

  /// No description provided for @repairing.
  ///
  /// In en, this message translates to:
  /// **'Repairing'**
  String get repairing;

  /// No description provided for @repairDone.
  ///
  /// In en, this message translates to:
  /// **'Repair done'**
  String get repairDone;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @selectedStatuses.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count} statuses'**
  String selectedStatuses(int count);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'APPLY'**
  String get apply;

  /// No description provided for @orderHasAccounting.
  ///
  /// In en, this message translates to:
  /// **'Order has accounting data:\n• Price: {price}\n• Cost: {cost}'**
  String orderHasAccounting(String price, String cost);

  /// No description provided for @orderHasParts.
  ///
  /// In en, this message translates to:
  /// **'Order has parts:'**
  String get orderHasParts;

  /// No description provided for @statusRepairing.
  ///
  /// In en, this message translates to:
  /// **'REPAIRING'**
  String get statusRepairing;

  /// No description provided for @statusRepairDone.
  ///
  /// In en, this message translates to:
  /// **'REPAIR DONE'**
  String get statusRepairDone;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'DELIVERED'**
  String get statusDelivered;

  /// No description provided for @deletedRepairDesc.
  ///
  /// In en, this message translates to:
  /// **'Deleted repair {model} - {customer} - {phone}{partsInfo}'**
  String deletedRepairDesc(String model, String customer, String phone, String partsInfo);

  /// No description provided for @returnedParts.
  ///
  /// In en, this message translates to:
  /// **' (returned parts: {parts})'**
  String returnedParts(String parts);

  /// No description provided for @displayedRepairs.
  ///
  /// In en, this message translates to:
  /// **'Displayed {count} repair orders'**
  String displayedRepairs(int count);

  /// No description provided for @statusReceivedUpper.
  ///
  /// In en, this message translates to:
  /// **'RECEIVED'**
  String get statusReceivedUpper;

  /// No description provided for @statusRepairingUpper.
  ///
  /// In en, this message translates to:
  /// **'REPAIRING'**
  String get statusRepairingUpper;

  /// No description provided for @statusRepairDoneUpper.
  ///
  /// In en, this message translates to:
  /// **'REPAIR DONE'**
  String get statusRepairDoneUpper;

  /// No description provided for @statusDeliveredUpper.
  ///
  /// In en, this message translates to:
  /// **'DELIVERED'**
  String get statusDeliveredUpper;

  /// No description provided for @statusPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'PENDING APPROVAL'**
  String get statusPendingApproval;

  /// No description provided for @statusOther.
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get statusOther;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @statusSelectMultiple.
  ///
  /// In en, this message translates to:
  /// **'STATUS (select multiple)'**
  String get statusSelectMultiple;

  /// No description provided for @timeFilter.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get timeFilter;

  /// No description provided for @partsWillReturn.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Parts will be returned to inventory!'**
  String get partsWillReturn;

  /// No description provided for @deleteRepairAction.
  ///
  /// In en, this message translates to:
  /// **'DELETE REPAIR'**
  String get deleteRepairAction;

  /// No description provided for @orderPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Order is pending approval from manager/owner'**
  String get orderPendingApproval;

  /// No description provided for @deliveredDevice.
  ///
  /// In en, this message translates to:
  /// **'Delivered device {model} to customer {customer}. Warranty: {warranty}'**
  String deliveredDevice(String model, String customer, String warranty);

  /// No description provided for @repairOrderShare.
  ///
  /// In en, this message translates to:
  /// **'REPAIR ORDER - {customer} - {phone} - {model} - {price}'**
  String repairOrderShare(String customer, String phone, String model, String price);

  /// No description provided for @statusUpdated.
  ///
  /// In en, this message translates to:
  /// **'UPDATED: {status}'**
  String statusUpdated(String status);

  /// No description provided for @orderWillBeSentForApproval.
  ///
  /// In en, this message translates to:
  /// **'Order will be sent to manager for approval before delivery'**
  String get orderWillBeSentForApproval;

  /// No description provided for @sentDeliveryApprovalRequest.
  ///
  /// In en, this message translates to:
  /// **'Sent delivery approval request'**
  String get sentDeliveryApprovalRequest;

  /// No description provided for @approvedDelivery.
  ///
  /// In en, this message translates to:
  /// **'Approved delivery of {model} to customer {customer}. Warranty: {warranty}'**
  String approvedDelivery(String model, String customer, String warranty);

  /// No description provided for @approvedAndCompletedDelivery.
  ///
  /// In en, this message translates to:
  /// **'Approved and completed delivery'**
  String get approvedAndCompletedDelivery;

  /// No description provided for @rejectedBackToRepairDone.
  ///
  /// In en, this message translates to:
  /// **'Rejected - order returned to Repair Done status'**
  String get rejectedBackToRepairDone;

  /// No description provided for @editRepairAction.
  ///
  /// In en, this message translates to:
  /// **'EDIT REPAIR'**
  String get editRepairAction;

  /// No description provided for @savedOrderChanges.
  ///
  /// In en, this message translates to:
  /// **'SAVED ORDER CHANGES'**
  String get savedOrderChanges;

  /// No description provided for @orderHasParts2.
  ///
  /// In en, this message translates to:
  /// **'This order already has parts:'**
  String get orderHasParts2;

  /// No description provided for @addedPartsFromInventory.
  ///
  /// In en, this message translates to:
  /// **'Added parts from inventory: {parts}\n(Cost already recorded when imported)'**
  String addedPartsFromInventory(String parts);

  /// No description provided for @partsSupplier.
  ///
  /// In en, this message translates to:
  /// **'Parts supplier'**
  String get partsSupplier;

  /// No description provided for @addedPartsWithPayment.
  ///
  /// In en, this message translates to:
  /// **'Added parts ({method}): {parts}'**
  String addedPartsWithPayment(String method, String parts);

  /// No description provided for @savedTechnicianNotes.
  ///
  /// In en, this message translates to:
  /// **'Saved technician notes'**
  String get savedTechnicianNotes;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @phoneRequired2.
  ///
  /// In en, this message translates to:
  /// **'Phone cannot be empty'**
  String get phoneRequired2;

  /// No description provided for @addressLabel2.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel2;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// No description provided for @partnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Partner: {name}'**
  String partnerLabel(String name);

  /// No description provided for @orderPendingYourApproval.
  ///
  /// In en, this message translates to:
  /// **'Order is pending your approval for delivery'**
  String get orderPendingYourApproval;

  /// No description provided for @waitingManagerApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for manager approval for delivery'**
  String get waitingManagerApproval;

  /// No description provided for @repairDoneReadyForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Repair done - ready for delivery'**
  String get repairDoneReadyForDelivery;

  /// No description provided for @repairingButton.
  ///
  /// In en, this message translates to:
  /// **'REPAIRING'**
  String get repairingButton;

  /// No description provided for @repairDoneButton.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get repairDoneButton;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @orderAlreadyHasParts.
  ///
  /// In en, this message translates to:
  /// **'This order already has parts:'**
  String get orderAlreadyHasParts;

  /// No description provided for @partsWillBeAddedAndDeducted.
  ///
  /// In en, this message translates to:
  /// **'If you continue, new parts will be ADDED and DEDUCTED FROM INVENTORY immediately.\n\nDo you want to continue?'**
  String get partsWillBeAddedAndDeducted;

  /// No description provided for @continueAddMore.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE ADDING'**
  String get continueAddMore;

  /// No description provided for @editPrice.
  ///
  /// In en, this message translates to:
  /// **'Edit price'**
  String get editPrice;

  /// No description provided for @editService.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get editService;

  /// No description provided for @addServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get addServiceTitle;

  /// No description provided for @partnerOptional2.
  ///
  /// In en, this message translates to:
  /// **'Partner (optional)'**
  String get partnerOptional2;

  /// No description provided for @serviceUpdated.
  ///
  /// In en, this message translates to:
  /// **'SERVICE UPDATED'**
  String get serviceUpdated;

  /// No description provided for @serviceAdded.
  ///
  /// In en, this message translates to:
  /// **'SERVICE ADDED'**
  String get serviceAdded;

  /// No description provided for @serviceDeleted.
  ///
  /// In en, this message translates to:
  /// **'SERVICE DELETED'**
  String get serviceDeleted;

  /// No description provided for @preparingPrint.
  ///
  /// In en, this message translates to:
  /// **'Preparing print command...'**
  String get preparingPrint;

  /// No description provided for @printSuccess.
  ///
  /// In en, this message translates to:
  /// **'Printed successfully!'**
  String get printSuccess;

  /// No description provided for @smartphoneSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Smartphone Specialist'**
  String get smartphoneSpecialist;

  /// No description provided for @editOrderInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit order information'**
  String get editOrderInfoTitle;

  /// No description provided for @customerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerNameLabel;

  /// No description provided for @deviceModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Device model'**
  String get deviceModelLabel;

  /// No description provided for @deviceIssueLabel.
  ///
  /// In en, this message translates to:
  /// **'Device issue'**
  String get deviceIssueLabel;

  /// No description provided for @accessoriesIncludedLabel.
  ///
  /// In en, this message translates to:
  /// **'Accessories included'**
  String get accessoriesIncludedLabel;

  /// No description provided for @warrantyLabel2.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get warrantyLabel2;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get saveButton;

  /// No description provided for @cancelButtonLower.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButtonLower;

  /// No description provided for @enterModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter device model'**
  String get enterModelRequired;

  /// No description provided for @enterIssueRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter issue description'**
  String get enterIssueRequired;

  /// No description provided for @editInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit information'**
  String get editInfoTooltip;

  /// No description provided for @noPartnerOption.
  ///
  /// In en, this message translates to:
  /// **'No partner'**
  String get noPartnerOption;

  /// No description provided for @enterServiceName.
  ///
  /// In en, this message translates to:
  /// **'Please enter service name'**
  String get enterServiceName;

  /// No description provided for @chargeCustomerVnd.
  ///
  /// In en, this message translates to:
  /// **'Charge customer (VND)'**
  String get chargeCustomerVnd;

  /// No description provided for @partsCostVnd.
  ///
  /// In en, this message translates to:
  /// **'Parts cost (VND)'**
  String get partsCostVnd;

  /// No description provided for @repairOrderFinance.
  ///
  /// In en, this message translates to:
  /// **'REPAIR ORDER FINANCE'**
  String get repairOrderFinance;

  /// No description provided for @customerCharge.
  ///
  /// In en, this message translates to:
  /// **'Customer charge'**
  String get customerCharge;

  /// No description provided for @partsCost.
  ///
  /// In en, this message translates to:
  /// **'Parts cost'**
  String get partsCost;

  /// No description provided for @editInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT INFO'**
  String get editInfoTitle;

  /// No description provided for @partsInventoryShort.
  ///
  /// In en, this message translates to:
  /// **'Parts Inv'**
  String get partsInventoryShort;

  /// No description provided for @techShort.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get techShort;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed! Please check printer settings.'**
  String get printFailed;

  /// No description provided for @printError.
  ///
  /// In en, this message translates to:
  /// **'Print error: {error}'**
  String printError(String error);

  /// No description provided for @noAccessPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to access this feature'**
  String get noAccessPermission;

  /// No description provided for @repairDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'REPAIR ORDER DETAIL'**
  String get repairDetailTitle;

  /// No description provided for @sendApprovalRequest.
  ///
  /// In en, this message translates to:
  /// **'SEND APPROVAL REQUEST'**
  String get sendApprovalRequest;

  /// No description provided for @selectWarrantyPeriod.
  ///
  /// In en, this message translates to:
  /// **'Select warranty period:'**
  String get selectWarrantyPeriod;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select payment method:'**
  String get selectPaymentMethod;

  /// No description provided for @confirmDeliveryAndPayment.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM DELIVERY & PAYMENT'**
  String get confirmDeliveryAndPayment;

  /// No description provided for @completeDelivery.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE DELIVERY'**
  String get completeDelivery;

  /// No description provided for @noWarranty.
  ///
  /// In en, this message translates to:
  /// **'NO WARRANTY'**
  String get noWarranty;

  /// No description provided for @oneMonth.
  ///
  /// In en, this message translates to:
  /// **'1 MONTH'**
  String get oneMonth;

  /// No description provided for @threeMonths.
  ///
  /// In en, this message translates to:
  /// **'3 MONTHS'**
  String get threeMonths;

  /// No description provided for @sixMonths.
  ///
  /// In en, this message translates to:
  /// **'6 MONTHS'**
  String get sixMonths;

  /// No description provided for @twelveMonths.
  ///
  /// In en, this message translates to:
  /// **'12 MONTHS'**
  String get twelveMonths;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'CASH'**
  String get cash;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'BANK TRANSFER'**
  String get bankTransfer;

  /// No description provided for @debt.
  ///
  /// In en, this message translates to:
  /// **'DEBT'**
  String get debt;

  /// No description provided for @financeTitleUpper.
  ///
  /// In en, this message translates to:
  /// **'FINANCE'**
  String get financeTitleUpper;

  /// No description provided for @luuYTitle.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get luuYTitle;

  /// No description provided for @partsInventoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Parts inventory empty. '**
  String get partsInventoryEmpty;

  /// No description provided for @noProductsInInventory.
  ///
  /// In en, this message translates to:
  /// **'No products in inventory yet.'**
  String get noProductsInInventory;

  /// No description provided for @totalProductsLinhKien.
  ///
  /// In en, this message translates to:
  /// **'Total: {total}, PARTS: {parts}. '**
  String totalProductsLinhKien(int total, int parts);

  /// No description provided for @goToInventoryAddParts.
  ///
  /// In en, this message translates to:
  /// **'Go to Inventory → Add Product → Select type \'PARTS\''**
  String get goToInventoryAddParts;

  /// No description provided for @addedPartsFromInventoryMsg.
  ///
  /// In en, this message translates to:
  /// **'Added parts from inventory: {parts}\n(Cost already recorded when imported)'**
  String addedPartsFromInventoryMsg(String parts);

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'PRICE'**
  String get priceLabel;

  /// No description provided for @costLabel.
  ///
  /// In en, this message translates to:
  /// **'COST'**
  String get costLabel;

  /// No description provided for @chargeCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer charge'**
  String get chargeCustomerLabel;

  /// No description provided for @partsLabel.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get partsLabel;

  /// No description provided for @profitLabel.
  ///
  /// In en, this message translates to:
  /// **'PROFIT'**
  String get profitLabel;

  /// No description provided for @expectedProfit.
  ///
  /// In en, this message translates to:
  /// **'Expected profit'**
  String get expectedProfit;

  /// No description provided for @partsUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Parts: {parts}'**
  String partsUsedLabel(String parts);

  /// No description provided for @servicesCount.
  ///
  /// In en, this message translates to:
  /// **'SERVICES ({count})'**
  String servicesCount(int count);

  /// No description provided for @repairServices.
  ///
  /// In en, this message translates to:
  /// **'REPAIR SERVICES'**
  String get repairServices;

  /// No description provided for @imagesCount.
  ///
  /// In en, this message translates to:
  /// **'IMAGES ({count})'**
  String imagesCount(int count);

  /// No description provided for @receivedImages.
  ///
  /// In en, this message translates to:
  /// **'RECEIVED DEVICE IMAGES'**
  String get receivedImages;

  /// No description provided for @noImages.
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get noImages;

  /// No description provided for @statusReceivedMsg.
  ///
  /// In en, this message translates to:
  /// **'RECEIVED DEVICE'**
  String get statusReceivedMsg;

  /// No description provided for @statusStartRepairMsg.
  ///
  /// In en, this message translates to:
  /// **'START REPAIR'**
  String get statusStartRepairMsg;

  /// No description provided for @debtNoteRepair.
  ///
  /// In en, this message translates to:
  /// **'Debt for repair: {model}'**
  String debtNoteRepair(String model);

  /// No description provided for @pendingDeliveryApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending delivery approval - {customer}'**
  String pendingDeliveryApproval(String customer);

  /// No description provided for @requestDeliveryApprovalDesc.
  ///
  /// In en, this message translates to:
  /// **'Request delivery approval for {model} - customer {customer}'**
  String requestDeliveryApprovalDesc(String model, String customer);

  /// No description provided for @notifRequestDeliveryApproval.
  ///
  /// In en, this message translates to:
  /// **'📋 DELIVERY APPROVAL REQUEST'**
  String get notifRequestDeliveryApproval;

  /// No description provided for @chatRequestDeliveryApproval.
  ///
  /// In en, this message translates to:
  /// **'📋 DELIVERY REQUEST: {model} - {customer} - {price}đ'**
  String chatRequestDeliveryApproval(String model, String customer, String price);

  /// No description provided for @defaultShopName.
  ///
  /// In en, this message translates to:
  /// **'QUAN LY SHOP'**
  String get defaultShopName;

  /// No description provided for @defaultShopDesc.
  ///
  /// In en, this message translates to:
  /// **'Smartphone Specialist'**
  String get defaultShopDesc;

  /// No description provided for @defaultShopPhone.
  ///
  /// In en, this message translates to:
  /// **'0123.456.789'**
  String get defaultShopPhone;

  /// No description provided for @techNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'TECHNICIAN NOTES'**
  String get techNotesTitle;

  /// No description provided for @repairProcessNotes.
  ///
  /// In en, this message translates to:
  /// **'Repair process notes:'**
  String get repairProcessNotes;

  /// No description provided for @techNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Ex: Replace power IC, check mainboard, replace charging cable...'**
  String get techNotesHint;

  /// No description provided for @trackRepairProgress.
  ///
  /// In en, this message translates to:
  /// **'Track repair progress and update status.'**
  String get trackRepairProgress;

  /// No description provided for @repairOrderDetail.
  ///
  /// In en, this message translates to:
  /// **'REPAIR ORDER DETAIL'**
  String get repairOrderDetail;

  /// No description provided for @partsShort.
  ///
  /// In en, this message translates to:
  /// **'PT: {parts}'**
  String partsShort(String parts);

  /// No description provided for @noServicesYet.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get noServicesYet;

  /// No description provided for @totalServices.
  ///
  /// In en, this message translates to:
  /// **'Total SVC:'**
  String get totalServices;

  /// No description provided for @deliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryLabel;

  /// No description provided for @approveDelivery.
  ///
  /// In en, this message translates to:
  /// **'APPROVE DELIVERY'**
  String get approveDelivery;

  /// No description provided for @deliverDevice.
  ///
  /// In en, this message translates to:
  /// **'DELIVER'**
  String get deliverDevice;

  /// No description provided for @sendDeliveryRequest.
  ///
  /// In en, this message translates to:
  /// **'SEND DELIVERY REQUEST'**
  String get sendDeliveryRequest;

  /// No description provided for @addServiceButton.
  ///
  /// In en, this message translates to:
  /// **'ADD SERVICE'**
  String get addServiceButton;

  /// No description provided for @noServicesMessage.
  ///
  /// In en, this message translates to:
  /// **'No services added'**
  String get noServicesMessage;

  /// No description provided for @totalServiceCost.
  ///
  /// In en, this message translates to:
  /// **'Total service cost'**
  String get totalServiceCost;

  /// No description provided for @customerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerLabel;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberLabel;

  /// No description provided for @issueLabel.
  ///
  /// In en, this message translates to:
  /// **'Device issue'**
  String issueLabel(String issue);

  /// No description provided for @accessoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessoriesLabel;

  /// No description provided for @noAccessories.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noAccessories;

  /// No description provided for @errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String errorSaving(String error);

  /// No description provided for @rejectDeliveryDesc.
  ///
  /// In en, this message translates to:
  /// **'Reject delivery approval for {model}'**
  String rejectDeliveryDesc(String model);

  /// No description provided for @customerInfo.
  ///
  /// In en, this message translates to:
  /// **'Customer: {name}'**
  String customerInfo(String name);

  /// No description provided for @deviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device: {model}'**
  String deviceInfo(String model);

  /// No description provided for @priceInfo.
  ///
  /// In en, this message translates to:
  /// **'Price: {price}đ'**
  String priceInfo(String price);

  /// No description provided for @paymentInfo.
  ///
  /// In en, this message translates to:
  /// **'Payment: {method}'**
  String paymentInfo(String method);

  /// No description provided for @selectWarrantyNote.
  ///
  /// In en, this message translates to:
  /// **'Select warranty (can change before approval):'**
  String get selectWarrantyNote;

  /// No description provided for @confirmApproveDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm approve delivery and complete transaction?'**
  String get confirmApproveDelivery;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'REJECT'**
  String get reject;

  /// No description provided for @chatApprovedDelivery.
  ///
  /// In en, this message translates to:
  /// **'✅ APPROVED DELIVERY: {summary}'**
  String chatApprovedDelivery(String summary);

  /// No description provided for @noneYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get noneYet;

  /// No description provided for @deliveryDate.
  ///
  /// In en, this message translates to:
  /// **'Delivery date'**
  String get deliveryDate;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'APPROVE'**
  String get approve;

  /// No description provided for @shareRepairReceipt.
  ///
  /// In en, this message translates to:
  /// **'🌟 REPAIR/WARRANTY RECEIPT 🌟\n----------------------------\nShop: {shopName}\nModel: {model}\nCustomer: {customerName} - {phone}\nIssue: {issue}\nWarranty: {warranty}\nTotal: {total}\n----------------------------\nThank you for your trust!'**
  String shareRepairReceipt(String shopName, String model, String customerName, String phone, String issue, String warranty, String total);

  /// No description provided for @actionDeliverDevice.
  ///
  /// In en, this message translates to:
  /// **'DELIVER DEVICE'**
  String get actionDeliverDevice;

  /// No description provided for @actionRequestDeliveryApproval.
  ///
  /// In en, this message translates to:
  /// **'REQUEST DELIVERY APPROVAL'**
  String get actionRequestDeliveryApproval;

  /// No description provided for @debtNoteForRepair.
  ///
  /// In en, this message translates to:
  /// **'Debt for repair: {model}'**
  String debtNoteForRepair(String model);

  /// No description provided for @repairOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'REPAIR ORDER - {customerName} - {phone} - {model} - {total}'**
  String repairOrderSummary(String customerName, String phone, String model, String total);

  /// No description provided for @chatDeviceDelivered.
  ///
  /// In en, this message translates to:
  /// **'✅ DEVICE DELIVERED: {summary}'**
  String chatDeviceDelivered(String summary);

  /// No description provided for @partsPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'PARTS PAYMENT'**
  String get partsPaymentTitle;

  /// No description provided for @totalPartsAmount.
  ///
  /// In en, this message translates to:
  /// **'TOTAL PARTS AMOUNT'**
  String get totalPartsAmount;

  /// No description provided for @partsDesc.
  ///
  /// In en, this message translates to:
  /// **'Parts: {parts}'**
  String partsDesc(String parts);

  /// No description provided for @supplierOptional.
  ///
  /// In en, this message translates to:
  /// **'Supplier (optional)'**
  String get supplierOptional;

  /// No description provided for @supplierHint.
  ///
  /// In en, this message translates to:
  /// **'e.g.: Parts ABC'**
  String get supplierHint;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHOD:'**
  String get paymentMethodLabel;

  /// No description provided for @debtWarning.
  ///
  /// In en, this message translates to:
  /// **'Debt will be recorded in Debt Management'**
  String get debtWarning;

  /// No description provided for @defaultPartsSupplier.
  ///
  /// In en, this message translates to:
  /// **'Parts supplier'**
  String get defaultPartsSupplier;

  /// No description provided for @recordDebt.
  ///
  /// In en, this message translates to:
  /// **'RECORD DEBT'**
  String get recordDebt;

  /// No description provided for @viewRepairPartners.
  ///
  /// In en, this message translates to:
  /// **'View repair partners'**
  String get viewRepairPartners;

  /// No description provided for @serviceNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Service name *'**
  String get serviceNameRequired;

  /// No description provided for @pleaseEnterServiceName.
  ///
  /// In en, this message translates to:
  /// **'Please enter service name'**
  String get pleaseEnterServiceName;

  /// No description provided for @costVnd.
  ///
  /// In en, this message translates to:
  /// **'Cost (VND)'**
  String get costVnd;

  /// No description provided for @costField.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get costField;

  /// No description provided for @partnerPaymentMethodRequired.
  ///
  /// In en, this message translates to:
  /// **'Partner payment method *'**
  String get partnerPaymentMethodRequired;

  /// No description provided for @pleaseSelectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Please select payment method'**
  String get pleaseSelectPaymentMethod;

  /// No description provided for @selectPartsTitle.
  ///
  /// In en, this message translates to:
  /// **'SELECT PARTS / COMPONENTS'**
  String get selectPartsTitle;

  /// No description provided for @searchPartOrSupplier.
  ///
  /// In en, this message translates to:
  /// **'Search by name or supplier'**
  String get searchPartOrSupplier;

  /// No description provided for @noPartsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching parts found'**
  String get noPartsFound;

  /// No description provided for @mainWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Main warehouse'**
  String get mainWarehouse;

  /// No description provided for @oldWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Old stock'**
  String get oldWarehouse;

  /// No description provided for @stockQty.
  ///
  /// In en, this message translates to:
  /// **'Stock: {qty}'**
  String stockQty(int qty);

  /// No description provided for @costPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost: {price}'**
  String costPrice(String price);

  /// No description provided for @sellPrice.
  ///
  /// In en, this message translates to:
  /// **'Sell: {price}'**
  String sellPrice(String price);

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'OUT OF STOCK'**
  String get outOfStock;

  /// No description provided for @confirmQty.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM ({qty})'**
  String confirmQty(int qty);

  /// No description provided for @confirmBtn.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get confirmBtn;

  /// No description provided for @invoiceTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'CREATE INVOICE TEMPLATE'**
  String get invoiceTemplateTitle;

  /// No description provided for @invoiceTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Invoice template saved'**
  String get invoiceTemplateSaved;

  /// No description provided for @headerLabel.
  ///
  /// In en, this message translates to:
  /// **'Header:'**
  String get headerLabel;

  /// No description provided for @invoiceHeaderHint.
  ///
  /// In en, this message translates to:
  /// **'INVOICE HEADER'**
  String get invoiceHeaderHint;

  /// No description provided for @bodyLabelWithPlaceholders.
  ///
  /// In en, this message translates to:
  /// **'Body (use placeholders like customerName, total):'**
  String get bodyLabelWithPlaceholders;

  /// No description provided for @invoiceBodyHint.
  ///
  /// In en, this message translates to:
  /// **'MAIN CONTENT'**
  String get invoiceBodyHint;

  /// No description provided for @footerLabel.
  ///
  /// In en, this message translates to:
  /// **'Footer:'**
  String get footerLabel;

  /// No description provided for @invoiceFooterHint.
  ///
  /// In en, this message translates to:
  /// **'INVOICE FOOTER'**
  String get invoiceFooterHint;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview:'**
  String get previewLabel;

  /// No description provided for @generateQrSampleOrder.
  ///
  /// In en, this message translates to:
  /// **'CREATE QR FOR SAMPLE ORDER'**
  String get generateQrSampleOrder;

  /// No description provided for @qrCodeScanInfo.
  ///
  /// In en, this message translates to:
  /// **'QR Code (scan to view order info):'**
  String get qrCodeScanInfo;

  /// No description provided for @workScheduleSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'WORK SCHEDULE SETTINGS'**
  String get workScheduleSettingsTitle;

  /// No description provided for @generalSettingsTab.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSettingsTab;

  /// No description provided for @staffTab.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffTab;

  /// No description provided for @workScheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Work schedule settings saved'**
  String get workScheduleSaved;

  /// No description provided for @staffSalarySaved.
  ///
  /// In en, this message translates to:
  /// **'Staff salary saved'**
  String get staffSalarySaved;

  /// No description provided for @saveErrorMsg.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String saveErrorMsg(String error);

  /// No description provided for @staffScheduleSavedFor.
  ///
  /// In en, this message translates to:
  /// **'Saved work schedule for {name}'**
  String staffScheduleSavedFor(String name);

  /// No description provided for @loadingStaffList.
  ///
  /// In en, this message translates to:
  /// **'Loading staff list...'**
  String get loadingStaffList;

  /// No description provided for @noStaffData.
  ///
  /// In en, this message translates to:
  /// **'No staff data'**
  String get noStaffData;

  /// No description provided for @tapToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Tap reload to refresh'**
  String get tapToRefresh;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @staffCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff count: {count}'**
  String staffCountLabel(int count);

  /// No description provided for @staffWorkSchedule.
  ///
  /// In en, this message translates to:
  /// **'Individual staff schedules'**
  String get staffWorkSchedule;

  /// No description provided for @scheduleNotSet.
  ///
  /// In en, this message translates to:
  /// **'Schedule not set'**
  String get scheduleNotSet;

  /// No description provided for @workHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Work Hours'**
  String get workHoursLabel;

  /// No description provided for @startTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTimeLabel;

  /// No description provided for @endTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTimeLabel;

  /// No description provided for @lunchBreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Lunch break'**
  String get lunchBreakLabel;

  /// No description provided for @maxOvertimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Max OT'**
  String get maxOvertimeLabel;

  /// No description provided for @workDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Work Days'**
  String get workDaysLabel;

  /// No description provided for @holidaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Holidays:'**
  String get holidaysLabel;

  /// No description provided for @addBtn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addBtn;

  /// No description provided for @overtimeRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Overtime Rate'**
  String get overtimeRateLabel;

  /// No description provided for @weekdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get weekdayLabel;

  /// No description provided for @weekendLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get weekendLabel;

  /// No description provided for @holidayLabel.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get holidayLabel;

  /// No description provided for @saveSettingsBtn.
  ///
  /// In en, this message translates to:
  /// **'SAVE SETTINGS'**
  String get saveSettingsBtn;

  /// No description provided for @noStaffFoundMsg.
  ///
  /// In en, this message translates to:
  /// **'No staff found'**
  String get noStaffFoundMsg;

  /// No description provided for @addStaffFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Please add staff in \"Staff Management\" first'**
  String get addStaffFirstHint;

  /// No description provided for @salarySettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Salary Settings'**
  String get salarySettingsLabel;

  /// No description provided for @selectStaffHint.
  ///
  /// In en, this message translates to:
  /// **'Select staff'**
  String get selectStaffHint;

  /// No description provided for @baseSalaryVnd.
  ///
  /// In en, this message translates to:
  /// **'Base salary (VND)'**
  String get baseSalaryVnd;

  /// No description provided for @attendanceLookupLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance Lookup'**
  String get attendanceLookupLabel;

  /// No description provided for @noAttendanceDataFor.
  ///
  /// In en, this message translates to:
  /// **'No attendance data for {date}'**
  String noAttendanceDataFor(String date);

  /// No description provided for @checkInLabel.
  ///
  /// In en, this message translates to:
  /// **'In:'**
  String get checkInLabel;

  /// No description provided for @checkOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Out:'**
  String get checkOutLabel;

  /// No description provided for @approvedStatus.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvedStatus;

  /// No description provided for @rejectedStatus.
  ///
  /// In en, this message translates to:
  /// **'❌ Rejected'**
  String get rejectedStatus;

  /// No description provided for @pendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingStatus;

  /// No description provided for @selectStaffToViewAttendance.
  ///
  /// In en, this message translates to:
  /// **'Select staff to view attendance'**
  String get selectStaffToViewAttendance;

  /// No description provided for @displayError.
  ///
  /// In en, this message translates to:
  /// **'Display Error'**
  String get displayError;

  /// No description provided for @errorMsg.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMsg(String error);

  /// No description provided for @noStaffHint.
  ///
  /// In en, this message translates to:
  /// **'No staff yet. Tap \"Reload\" below or add staff in Staff Management.'**
  String get noStaffHint;

  /// No description provided for @staffScheduleFor.
  ///
  /// In en, this message translates to:
  /// **'Work schedule: {name}'**
  String staffScheduleFor(String name);

  /// No description provided for @workTimeSettings.
  ///
  /// In en, this message translates to:
  /// **'Work Time Settings'**
  String get workTimeSettings;

  /// No description provided for @startTimeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTimeFieldLabel;

  /// No description provided for @endTimeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTimeFieldLabel;

  /// No description provided for @lunchBreakHours.
  ///
  /// In en, this message translates to:
  /// **'Lunch break (hours)'**
  String get lunchBreakHours;

  /// No description provided for @maxOvertimePerDay.
  ///
  /// In en, this message translates to:
  /// **'Max overtime per day'**
  String get maxOvertimePerDay;

  /// No description provided for @selectTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTimeLabel;

  /// No description provided for @workDaysSettings.
  ///
  /// In en, this message translates to:
  /// **'Work Days Settings'**
  String get workDaysSettings;

  /// No description provided for @workDaysInWeek.
  ///
  /// In en, this message translates to:
  /// **'Work days in week:'**
  String get workDaysInWeek;

  /// No description provided for @addHolidayBtn.
  ///
  /// In en, this message translates to:
  /// **'Add holiday'**
  String get addHolidayBtn;

  /// No description provided for @holidayListLabel.
  ///
  /// In en, this message translates to:
  /// **'Holiday list:'**
  String get holidayListLabel;

  /// No description provided for @overtimeSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Overtime Settings'**
  String get overtimeSettingsLabel;

  /// No description provided for @weekdayOvertimeRate.
  ///
  /// In en, this message translates to:
  /// **'Weekday overtime (% of salary/hour)'**
  String get weekdayOvertimeRate;

  /// No description provided for @weekendOvertimeRate.
  ///
  /// In en, this message translates to:
  /// **'Weekend overtime (% of salary/hour)'**
  String get weekendOvertimeRate;

  /// No description provided for @holidayOvertimeRate.
  ///
  /// In en, this message translates to:
  /// **'Holiday overtime (% of salary/hour)'**
  String get holidayOvertimeRate;

  /// No description provided for @staffSalarySettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff Salary Settings'**
  String get staffSalarySettingsLabel;

  /// No description provided for @addUpdateSalary.
  ///
  /// In en, this message translates to:
  /// **'Add/Update Salary'**
  String get addUpdateSalary;

  /// No description provided for @saveSalary.
  ///
  /// In en, this message translates to:
  /// **'Save salary'**
  String get saveSalary;

  /// No description provided for @currentSalaryList.
  ///
  /// In en, this message translates to:
  /// **'Current salary list:'**
  String get currentSalaryList;

  /// No description provided for @manageStaffAttendance.
  ///
  /// In en, this message translates to:
  /// **'Manage Staff Attendance'**
  String get manageStaffAttendance;

  /// No description provided for @selectDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDateLabel;

  /// No description provided for @attendanceInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance Info'**
  String get attendanceInfoLabel;

  /// No description provided for @staffNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff:'**
  String get staffNameLabel;

  /// No description provided for @checkInTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Check-in:'**
  String get checkInTimeLabel;

  /// No description provided for @checkOutTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Check-out:'**
  String get checkOutTimeLabel;

  /// No description provided for @selectStaffForAttendance.
  ///
  /// In en, this message translates to:
  /// **'Please select staff to view attendance info'**
  String get selectStaffForAttendance;

  /// No description provided for @aboutDeveloper.
  ///
  /// In en, this message translates to:
  /// **'About Developer'**
  String get aboutDeveloper;

  /// No description provided for @hulucaStoreDongNai.
  ///
  /// In en, this message translates to:
  /// **'HULUCA STORE DONG NAI'**
  String get hulucaStoreDongNai;

  /// No description provided for @professionalStoreManagementApp.
  ///
  /// In en, this message translates to:
  /// **'Professional store management application'**
  String get professionalStoreManagementApp;

  /// No description provided for @developerAndDesigner.
  ///
  /// In en, this message translates to:
  /// **'Developer & Designer'**
  String get developerAndDesigner;

  /// No description provided for @hulucaStore.
  ///
  /// In en, this message translates to:
  /// **'HULUCA STORE'**
  String get hulucaStore;

  /// No description provided for @dongNai.
  ///
  /// In en, this message translates to:
  /// **'DONG NAI'**
  String get dongNai;

  /// No description provided for @professionalPhoneRepairShop.
  ///
  /// In en, this message translates to:
  /// **'Professional shop management solution'**
  String get professionalPhoneRepairShop;

  /// No description provided for @hotlineAndZalo.
  ///
  /// In en, this message translates to:
  /// **'Hotline & Zalo'**
  String get hotlineAndZalo;

  /// No description provided for @shopManagerApp.
  ///
  /// In en, this message translates to:
  /// **'Shop Manager App'**
  String get shopManagerApp;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @appFullDescription.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive multi-industry shop management: Electronics (IMEI, warranty), Food (expiry), Fashion (size/color variants) with real-time sync.'**
  String get appFullDescription;

  /// No description provided for @attendanceTracking.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE TRACKING'**
  String get attendanceTracking;

  /// No description provided for @viewByMonth.
  ///
  /// In en, this message translates to:
  /// **'View by month'**
  String get viewByMonth;

  /// No description provided for @viewByDay.
  ///
  /// In en, this message translates to:
  /// **'View by day'**
  String get viewByDay;

  /// No description provided for @attendanceForDate.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE {date}'**
  String attendanceForDate(String date);

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'MONTH {month}'**
  String monthLabel(String month);

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @lateArrival.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get lateArrival;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absent;

  /// No description provided for @totalStaff.
  ///
  /// In en, this message translates to:
  /// **'Total Staff'**
  String get totalStaff;

  /// No description provided for @checkedInStatus.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkedInStatus;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @noStaffYet.
  ///
  /// In en, this message translates to:
  /// **'No staff yet'**
  String get noStaffYet;

  /// No description provided for @notCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not checked in'**
  String get notCheckedIn;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedStatus;

  /// No description provided for @workingStatus.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get workingStatus;

  /// No description provided for @workDaysCount.
  ///
  /// In en, this message translates to:
  /// **'Work days'**
  String get workDaysCount;

  /// No description provided for @workHoursCount.
  ///
  /// In en, this message translates to:
  /// **'Work hours'**
  String get workHoursCount;

  /// No description provided for @roleOwnerShort.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwnerShort;

  /// No description provided for @roleManagerShort.
  ///
  /// In en, this message translates to:
  /// **'Mgr'**
  String get roleManagerShort;

  /// No description provided for @roleTechnicianShort.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get roleTechnicianShort;

  /// No description provided for @roleEmployeeShort.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleEmployeeShort;

  /// No description provided for @noAttendanceData.
  ///
  /// In en, this message translates to:
  /// **'No attendance data'**
  String get noAttendanceData;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @checkInTimeShort.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkInTimeShort;

  /// No description provided for @checkOutTimeShort.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get checkOutTimeShort;

  /// No description provided for @earlyLeave.
  ///
  /// In en, this message translates to:
  /// **'Early leave'**
  String get earlyLeave;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @attendancePhotos.
  ///
  /// In en, this message translates to:
  /// **'Attendance photos:'**
  String get attendancePhotos;

  /// No description provided for @checkInPhoto.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get checkInPhoto;

  /// No description provided for @checkOutPhoto.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get checkOutPhoto;

  /// No description provided for @hasPhoto.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get hasPhoto;

  /// No description provided for @noPhoto.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noPhoto;

  /// No description provided for @monthYearFormat.
  ///
  /// In en, this message translates to:
  /// **'Month {monthYear}'**
  String monthYearFormat(String monthYear);

  /// No description provided for @errorLoadingCustomers.
  ///
  /// In en, this message translates to:
  /// **'Error loading customers: {error}'**
  String errorLoadingCustomers(String error);

  /// No description provided for @editCustomerAction.
  ///
  /// In en, this message translates to:
  /// **'edit customer'**
  String get editCustomerAction;

  /// No description provided for @deleteCustomerAction.
  ///
  /// In en, this message translates to:
  /// **'delete customer'**
  String get deleteCustomerAction;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete customer \"{name}\"?'**
  String confirmDeleteCustomer(String name);

  /// No description provided for @confirmActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm {action}'**
  String confirmActionTitle(String action);

  /// No description provided for @ownerPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Only shop owner can perform this action.\nEnter account password to confirm:'**
  String get ownerPasswordRequired;

  /// No description provided for @pleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Please login again'**
  String get pleaseLoginAgain;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password!'**
  String get incorrectPassword;

  /// No description provided for @customerManagement.
  ///
  /// In en, this message translates to:
  /// **'Customer Management'**
  String get customerManagement;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomer;

  /// No description provided for @searchCustomers.
  ///
  /// In en, this message translates to:
  /// **'Search customers...'**
  String get searchCustomers;

  /// No description provided for @noCustomersYet.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get noCustomersYet;

  /// No description provided for @customerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Customer not found'**
  String get customerNotFound;

  /// No description provided for @notePrefix.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String notePrefix(String note);

  /// No description provided for @totalPurchasedAmount.
  ///
  /// In en, this message translates to:
  /// **'Purchased: {amount}'**
  String totalPurchasedAmount(String amount);

  /// No description provided for @repairCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Repairs: {count} times'**
  String repairCountLabel(int count);

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @addCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomerTitle;

  /// No description provided for @editCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomerTitle;

  /// No description provided for @customerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Customer name *'**
  String get customerNameRequired;

  /// No description provided for @enterCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Enter customer name'**
  String get enterCustomerName;

  /// No description provided for @pleaseEnterCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter customer name'**
  String get pleaseEnterCustomerName;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number *'**
  String get phoneNumberRequired;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumber;

  /// No description provided for @pleaseEnterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get pleaseEnterPhoneNumber;

  /// No description provided for @enterEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter email (optional)'**
  String get enterEmailOptional;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address: {address}'**
  String addressLabel(String address);

  /// No description provided for @enterAddressOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter address (optional)'**
  String get enterAddressOptional;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String notesLabel(String notes);

  /// No description provided for @enterNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter notes (optional)'**
  String get enterNotesOptional;

  /// No description provided for @totalPurchasesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total purchases'**
  String get totalPurchasesLabel;

  /// No description provided for @totalRepairsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total repairs'**
  String get totalRepairsLabel;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistoryYet;

  /// No description provided for @fastInventoryCheck.
  ///
  /// In en, this message translates to:
  /// **'Fast Inventory Check'**
  String get fastInventoryCheck;

  /// No description provided for @checklistTitle.
  ///
  /// In en, this message translates to:
  /// **'📋 Checklist'**
  String get checklistTitle;

  /// No description provided for @checklistDescription.
  ///
  /// In en, this message translates to:
  /// **'System displays all products in stock. Scan QR code of each product to mark as checked.'**
  String get checklistDescription;

  /// No description provided for @scanImeiBarcode.
  ///
  /// In en, this message translates to:
  /// **'📷 Scan IMEI/Barcode'**
  String get scanImeiBarcode;

  /// No description provided for @scanInstructions.
  ///
  /// In en, this message translates to:
  /// **'Press \"Start scan\" and point camera to QR/barcode to begin checking.'**
  String get scanInstructions;

  /// No description provided for @checkedVsMissing.
  ///
  /// In en, this message translates to:
  /// **'✅ Checked vs ❌ Missing'**
  String get checkedVsMissing;

  /// No description provided for @checkStatusDescription.
  ///
  /// In en, this message translates to:
  /// **'Green = scanned and found. Red = not yet scanned. Report shows checked vs missing.'**
  String get checkStatusDescription;

  /// No description provided for @inventoryReport.
  ///
  /// In en, this message translates to:
  /// **'📊 Inventory Report'**
  String get inventoryReport;

  /// No description provided for @reportDescription.
  ///
  /// In en, this message translates to:
  /// **'After scanning, view summary report to know missing and excess items.'**
  String get reportDescription;

  /// No description provided for @errorLoadingInventory.
  ///
  /// In en, this message translates to:
  /// **'Error loading inventory: {error}'**
  String errorLoadingInventory(String error);

  /// No description provided for @phonesCategory.
  ///
  /// In en, this message translates to:
  /// **'Phones'**
  String get phonesCategory;

  /// No description provided for @checkAllPhones.
  ///
  /// In en, this message translates to:
  /// **'Check all phones in stock'**
  String get checkAllPhones;

  /// No description provided for @accessoriesCategory.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessoriesCategory;

  /// No description provided for @checkAllAccessories.
  ///
  /// In en, this message translates to:
  /// **'Check all accessories'**
  String get checkAllAccessories;

  /// No description provided for @specialCategory.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get specialCategory;

  /// No description provided for @specialProductsCheck.
  ///
  /// In en, this message translates to:
  /// **'Special products need separate check'**
  String get specialProductsCheck;

  /// No description provided for @duplicateScanWarning.
  ///
  /// In en, this message translates to:
  /// **'Scanned this code recently! Wait 3 seconds before scanning again'**
  String get duplicateScanWarning;

  /// No description provided for @phoneMissingImei.
  ///
  /// In en, this message translates to:
  /// **'Phone QR missing IMEI'**
  String get phoneMissingImei;

  /// No description provided for @notInStockError.
  ///
  /// In en, this message translates to:
  /// **'Not in stock'**
  String get notInStockError;

  /// No description provided for @accessoryMissingCode.
  ///
  /// In en, this message translates to:
  /// **'Accessory QR missing code'**
  String get accessoryMissingCode;

  /// No description provided for @unknownAccessory.
  ///
  /// In en, this message translates to:
  /// **'Unknown accessory'**
  String get unknownAccessory;

  /// No description provided for @invalidQrForInventory.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR for inventory check: {error}'**
  String invalidQrForInventory(String error);

  /// No description provided for @productNotFoundById.
  ///
  /// In en, this message translates to:
  /// **'Product not found with ID: {id}'**
  String productNotFoundById(String id);

  /// No description provided for @productNotSupportedForInventory.
  ///
  /// In en, this message translates to:
  /// **'Product not supported for inventory: {type}'**
  String productNotSupportedForInventory(String type);

  /// No description provided for @errorCheckingProduct.
  ///
  /// In en, this message translates to:
  /// **'Error checking product: {error}'**
  String errorCheckingProduct(String error);

  /// No description provided for @qrScanSettings.
  ///
  /// In en, this message translates to:
  /// **'QR SCAN SETTINGS'**
  String get qrScanSettings;

  /// No description provided for @soundFeedback.
  ///
  /// In en, this message translates to:
  /// **'Sound feedback'**
  String get soundFeedback;

  /// No description provided for @playSoundOnScan.
  ///
  /// In en, this message translates to:
  /// **'Play sound when scan'**
  String get playSoundOnScan;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedback;

  /// No description provided for @vibrateOnScan.
  ///
  /// In en, this message translates to:
  /// **'Vibrate device when scan'**
  String get vibrateOnScan;

  /// No description provided for @scanTips.
  ///
  /// In en, this message translates to:
  /// **'Tip: Keep 20-30cm distance from QR code for best results'**
  String get scanTips;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get closeButton;

  /// No description provided for @fastInventoryCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'FAST INVENTORY CHECK'**
  String get fastInventoryCheckTitle;

  /// No description provided for @selectZone.
  ///
  /// In en, this message translates to:
  /// **'Select Zone'**
  String get selectZone;

  /// No description provided for @hideChecklist.
  ///
  /// In en, this message translates to:
  /// **'Hide checklist'**
  String get hideChecklist;

  /// No description provided for @showChecklist.
  ///
  /// In en, this message translates to:
  /// **'Show checklist'**
  String get showChecklist;

  /// No description provided for @scanSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Scan settings'**
  String get scanSettingsButton;

  /// No description provided for @stopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop scan'**
  String get stopScan;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start scan'**
  String get startScan;

  /// No description provided for @toggleFlash.
  ///
  /// In en, this message translates to:
  /// **'Toggle flash'**
  String get toggleFlash;

  /// No description provided for @phonesChecked.
  ///
  /// In en, this message translates to:
  /// **'📱 Checked'**
  String get phonesChecked;

  /// No description provided for @phonesMissing.
  ///
  /// In en, this message translates to:
  /// **'📱 Missing'**
  String get phonesMissing;

  /// No description provided for @phonesExtra.
  ///
  /// In en, this message translates to:
  /// **'📱 Extra'**
  String get phonesExtra;

  /// No description provided for @accessoriesChecked.
  ///
  /// In en, this message translates to:
  /// **'🔧 Checked'**
  String get accessoriesChecked;

  /// No description provided for @accessoriesMissing.
  ///
  /// In en, this message translates to:
  /// **'🔧 Missing'**
  String get accessoriesMissing;

  /// No description provided for @accessoriesExtra.
  ///
  /// In en, this message translates to:
  /// **'🔧 Extra'**
  String get accessoriesExtra;

  /// No description provided for @pressToStartScan.
  ///
  /// In en, this message translates to:
  /// **'Press scan button to start inventory check'**
  String get pressToStartScan;

  /// No description provided for @scanInstructionsShort.
  ///
  /// In en, this message translates to:
  /// **'Phones: scan IMEI\nAccessories: scan each item'**
  String get scanInstructionsShort;

  /// No description provided for @processingLabel.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processingLabel;

  /// No description provided for @pendingCheckCount.
  ///
  /// In en, this message translates to:
  /// **'Pending ({count})'**
  String pendingCheckCount(int count);

  /// No description provided for @scannedCount.
  ///
  /// In en, this message translates to:
  /// **'Scanned ({count})'**
  String scannedCount(int count);

  /// No description provided for @noProductsInStockMsg.
  ///
  /// In en, this message translates to:
  /// **'No products in stock'**
  String get noProductsInStockMsg;

  /// No description provided for @scannedLabel.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {count}'**
  String scannedLabel(int count);

  /// No description provided for @holdQrSteady.
  ///
  /// In en, this message translates to:
  /// **'Hold QR steady in front of camera'**
  String get holdQrSteady;

  /// No description provided for @selectCheckArea.
  ///
  /// In en, this message translates to:
  /// **'Select check area'**
  String get selectCheckArea;

  /// No description provided for @completedExclamation.
  ///
  /// In en, this message translates to:
  /// **'Completed!'**
  String get completedExclamation;

  /// No description provided for @switchedToZone.
  ///
  /// In en, this message translates to:
  /// **'Switched to zone: {zone}'**
  String switchedToZone(String zone);

  /// No description provided for @labelSettings.
  ///
  /// In en, this message translates to:
  /// **'Product Label Settings'**
  String get labelSettings;

  /// No description provided for @labelTemplates.
  ///
  /// In en, this message translates to:
  /// **'Label Templates'**
  String get labelTemplates;

  /// No description provided for @labelDisplayInfo.
  ///
  /// In en, this message translates to:
  /// **'Information displayed on label'**
  String get labelDisplayInfo;

  /// No description provided for @shopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopNameLabel;

  /// No description provided for @shopNameExample.
  ///
  /// In en, this message translates to:
  /// **'Ex: HULUCA MOBILE'**
  String get shopNameExample;

  /// No description provided for @hotlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Hotline'**
  String get hotlineLabel;

  /// No description provided for @hotlineExample.
  ///
  /// In en, this message translates to:
  /// **'Ex: 0909 123 456'**
  String get hotlineExample;

  /// No description provided for @sloganLabel.
  ///
  /// In en, this message translates to:
  /// **'Slogan'**
  String get sloganLabel;

  /// No description provided for @sloganExample.
  ///
  /// In en, this message translates to:
  /// **'Ex: Best price guaranteed'**
  String get sloganExample;

  /// No description provided for @addressOptional.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// No description provided for @addressExample.
  ///
  /// In en, this message translates to:
  /// **'Ex: 123 ABC Street, District 1, HCM'**
  String get addressExample;

  /// No description provided for @cpkPriceSettings.
  ///
  /// In en, this message translates to:
  /// **'CPK Price Settings'**
  String get cpkPriceSettings;

  /// No description provided for @cpkFormulaTitle.
  ///
  /// In en, this message translates to:
  /// **'📌 CPK Price Formula (With Accessories):'**
  String get cpkFormulaTitle;

  /// No description provided for @formulaLabel.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get formulaLabel;

  /// No description provided for @formulaExample.
  ///
  /// In en, this message translates to:
  /// **'price + 500000 or price * 1.05'**
  String get formulaExample;

  /// No description provided for @formulaHint.
  ///
  /// In en, this message translates to:
  /// **'Ex: \"price + 500000\" = Selling price + 500k for with-accessories price'**
  String get formulaHint;

  /// No description provided for @fixedLabelContent.
  ///
  /// In en, this message translates to:
  /// **'Fixed content on label'**
  String get fixedLabelContent;

  /// No description provided for @fixedLabelContentHint.
  ///
  /// In en, this message translates to:
  /// **'These text lines will display by default on all labels'**
  String get fixedLabelContentHint;

  /// No description provided for @line1Label.
  ///
  /// In en, this message translates to:
  /// **'Line 1'**
  String get line1Label;

  /// No description provided for @line2Label.
  ///
  /// In en, this message translates to:
  /// **'Line 2'**
  String get line2Label;

  /// No description provided for @line3Label.
  ///
  /// In en, this message translates to:
  /// **'Line 3'**
  String get line3Label;

  /// No description provided for @line1Example.
  ///
  /// In en, this message translates to:
  /// **'Ex: 100% Authentic guaranteed'**
  String get line1Example;

  /// No description provided for @line2Example.
  ///
  /// In en, this message translates to:
  /// **'Ex: 7-day return policy'**
  String get line2Example;

  /// No description provided for @line3Example.
  ///
  /// In en, this message translates to:
  /// **'Ex: 0% installment support'**
  String get line3Example;

  /// No description provided for @savingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingLabel;

  /// No description provided for @saveSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'SAVE SETTINGS'**
  String get saveSettingsButton;

  /// No description provided for @labelSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'✅ Label settings saved!'**
  String get labelSettingsSaved;

  /// No description provided for @errorPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'❌ Error: {error}'**
  String errorPrefixLabel(String error);

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @deleteTemplateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get deleteTemplateQuestion;

  /// No description provided for @confirmDeleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete template \"{name}\"?'**
  String confirmDeleteTemplate(String name);

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteButton;

  /// No description provided for @editTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit label template'**
  String get editTemplateTitle;

  /// No description provided for @templateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateNameLabel;

  /// No description provided for @labelSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Label size'**
  String get labelSizeLabel;

  /// No description provided for @cpkPriceFormulaLabel.
  ///
  /// In en, this message translates to:
  /// **'CPK price formula'**
  String get cpkPriceFormulaLabel;

  /// No description provided for @productInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Info'**
  String get productInfoLabel;

  /// No description provided for @productNameField.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productNameField;

  /// No description provided for @productCodeField.
  ///
  /// In en, this message translates to:
  /// **'Product code'**
  String get productCodeField;

  /// No description provided for @qrCodeField.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCodeField;

  /// No description provided for @imeiSerialField.
  ///
  /// In en, this message translates to:
  /// **'IMEI/Serial'**
  String get imeiSerialField;

  /// No description provided for @capacityField.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get capacityField;

  /// No description provided for @colorField.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorField;

  /// No description provided for @conditionField.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get conditionField;

  /// No description provided for @priceInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Price Info'**
  String get priceInfoLabel;

  /// No description provided for @priceKpkField.
  ///
  /// In en, this message translates to:
  /// **'KPK Price (no accessories)'**
  String get priceKpkField;

  /// No description provided for @priceCpkField.
  ///
  /// In en, this message translates to:
  /// **'CPK Price (with accessories)'**
  String get priceCpkField;

  /// No description provided for @originalPriceField.
  ///
  /// In en, this message translates to:
  /// **'Original price (strikethrough)'**
  String get originalPriceField;

  /// No description provided for @discountPercentField.
  ///
  /// In en, this message translates to:
  /// **'Discount %'**
  String get discountPercentField;

  /// No description provided for @shopInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Info'**
  String get shopInfoLabel;

  /// No description provided for @otherInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherInfoLabel;

  /// No description provided for @warrantyField.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get warrantyField;

  /// No description provided for @supplierField.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplierField;

  /// No description provided for @importDateField.
  ///
  /// In en, this message translates to:
  /// **'Import date'**
  String get importDateField;

  /// No description provided for @pleaseEnterTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Please enter template name'**
  String get pleaseEnterTemplateName;

  /// No description provided for @saveTemplateButton.
  ///
  /// In en, this message translates to:
  /// **'SAVE TEMPLATE'**
  String get saveTemplateButton;

  /// No description provided for @templateUpdated.
  ///
  /// In en, this message translates to:
  /// **'✅ Updated template \"{name}\"'**
  String templateUpdated(String name);

  /// No description provided for @productNameLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productNameLabelShort;

  /// No description provided for @detailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsLabel;

  /// No description provided for @labelInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Label Info'**
  String get labelInfoTitle;

  /// No description provided for @priceKpkLabel.
  ///
  /// In en, this message translates to:
  /// **'KPK Price'**
  String get priceKpkLabel;

  /// No description provided for @priceCpkLabel.
  ///
  /// In en, this message translates to:
  /// **'CPK Price'**
  String get priceCpkLabel;

  /// No description provided for @imeiLabel.
  ///
  /// In en, this message translates to:
  /// **'IMEI'**
  String get imeiLabel;

  /// No description provided for @qrLabel.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get qrLabel;

  /// No description provided for @shopLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopLabel;

  /// No description provided for @labelDesignSaved.
  ///
  /// In en, this message translates to:
  /// **'✅ Label design saved!'**
  String get labelDesignSaved;

  /// No description provided for @resetToDefaultQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reset to default?'**
  String get resetToDefaultQuestion;

  /// No description provided for @layoutWillReset.
  ///
  /// In en, this message translates to:
  /// **'Label layout will be reset to original settings.'**
  String get layoutWillReset;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetButton;

  /// No description provided for @labelDesignTitle.
  ///
  /// In en, this message translates to:
  /// **'LABEL DESIGN'**
  String get labelDesignTitle;

  /// No description provided for @layoutTab.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layoutTab;

  /// No description provided for @ptyDesignerTab.
  ///
  /// In en, this message translates to:
  /// **'PTY 1:1 Designer'**
  String get ptyDesignerTab;

  /// No description provided for @paperTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Paper type:'**
  String get paperTypeLabel;

  /// No description provided for @rollMmLabel.
  ///
  /// In en, this message translates to:
  /// **'Roll (mm)'**
  String get rollMmLabel;

  /// No description provided for @stickerCmLabel.
  ///
  /// In en, this message translates to:
  /// **'Sticker (cm)'**
  String get stickerCmLabel;

  /// No description provided for @rollPaperSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Roll paper size (mm):'**
  String get rollPaperSizeLabel;

  /// No description provided for @customPaperSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom paper size (mm)'**
  String get customPaperSizeLabel;

  /// No description provided for @stickerSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Sticker size (cm):'**
  String get stickerSizeLabel;

  /// No description provided for @widthCmLabel.
  ///
  /// In en, this message translates to:
  /// **'Width (cm)'**
  String get widthCmLabel;

  /// No description provided for @heightCmLabel.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCmLabel;

  /// No description provided for @codeTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code type:'**
  String get codeTypeLabel;

  /// No description provided for @offOption.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offOption;

  /// No description provided for @qrOption.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get qrOption;

  /// No description provided for @barcodeOption.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcodeOption;

  /// No description provided for @designInstructions.
  ///
  /// In en, this message translates to:
  /// **'👆 Tap element on template to edit...'**
  String get designInstructions;

  /// No description provided for @zoomPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Zoom preview:'**
  String get zoomPreviewLabel;

  /// No description provided for @labelPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'LABEL PREVIEW'**
  String get labelPreviewTitle;

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get tapToSelect;

  /// No description provided for @displayOption.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displayOption;

  /// No description provided for @spacingLabel.
  ///
  /// In en, this message translates to:
  /// **'Spacing:'**
  String get spacingLabel;

  /// No description provided for @boldOption.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get boldOption;

  /// No description provided for @fontStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Font style:'**
  String get fontStyleLabel;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Shop Owner'**
  String get roleOwner;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleTechnician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get roleTechnician;

  /// No description provided for @roleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get roleCashier;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @helpCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenterTitle;

  /// No description provided for @searchByKeyword.
  ///
  /// In en, this message translates to:
  /// **'Search by keyword, feature...'**
  String get searchByKeyword;

  /// No description provided for @suggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestionsLabel;

  /// No description provided for @feedbackContact.
  ///
  /// In en, this message translates to:
  /// **'Have feature suggestions? Contact support@huluca.com'**
  String get feedbackContact;

  /// No description provided for @feedbackSupport.
  ///
  /// In en, this message translates to:
  /// **'Feedback / Support'**
  String get feedbackSupport;

  /// No description provided for @noGuideFound.
  ///
  /// In en, this message translates to:
  /// **'No guide found matching keyword.'**
  String get noGuideFound;

  /// No description provided for @otherTopics.
  ///
  /// In en, this message translates to:
  /// **'Other topics'**
  String get otherTopics;

  /// No description provided for @stepsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String stepsCountLabel(int count);

  /// No description provided for @tipsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} tips'**
  String tipsCountLabel(int count);

  /// No description provided for @quickGuide.
  ///
  /// In en, this message translates to:
  /// **'Quick Guide'**
  String get quickGuide;

  /// No description provided for @quickGuideDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a topic or enter keyword...'**
  String get quickGuideDescription;

  /// No description provided for @contentStandard.
  ///
  /// In en, this message translates to:
  /// **'All content is prepared according to Shopmanager standards.'**
  String get contentStandard;

  /// No description provided for @forRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'For {role}'**
  String forRoleLabel(String role);

  /// No description provided for @estimatedTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated time: {time}'**
  String estimatedTimeLabel(String time);

  /// No description provided for @difficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty: {level}'**
  String difficultyLabel(String level);

  /// No description provided for @prerequisitesLabel.
  ///
  /// In en, this message translates to:
  /// **'Prerequisites'**
  String get prerequisitesLabel;

  /// No description provided for @stepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get stepsLabel;

  /// No description provided for @tipsAndNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Tips & Notes'**
  String get tipsAndNotesLabel;

  /// No description provided for @watchVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Watch video tutorial'**
  String get watchVideoLabel;

  /// No description provided for @attachmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachmentsLabel;

  /// No description provided for @relatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get relatedLabel;

  /// No description provided for @needHelpLabel.
  ///
  /// In en, this message translates to:
  /// **'Need help? Contact support team: support@huluca.com'**
  String get needHelpLabel;

  /// No description provided for @understoodGuide.
  ///
  /// In en, this message translates to:
  /// **'I understood this guide'**
  String get understoodGuide;

  /// No description provided for @markedAsViewed.
  ///
  /// In en, this message translates to:
  /// **'Marked this guide as viewed.'**
  String get markedAsViewed;

  /// No description provided for @videoGuideLabel.
  ///
  /// In en, this message translates to:
  /// **'Video Guide'**
  String get videoGuideLabel;

  /// No description provided for @videosBeingUpdated.
  ///
  /// In en, this message translates to:
  /// **'Video tutorials are being updated.'**
  String get videosBeingUpdated;

  /// No description provided for @contactSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupportLabel;

  /// No description provided for @sendEmailForHelp.
  ///
  /// In en, this message translates to:
  /// **'Send email to support@huluca.com for quick assistance.'**
  String get sendEmailForHelp;

  /// No description provided for @suggestImprovementLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggest Improvement'**
  String get suggestImprovementLabel;

  /// No description provided for @feedbackHelps.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps make documentation better!'**
  String get feedbackHelps;

  /// No description provided for @filteredByRole.
  ///
  /// In en, this message translates to:
  /// **'Filtered guides matching your role.'**
  String get filteredByRole;

  /// No description provided for @featuredLabel.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featuredLabel;

  /// No description provided for @quickLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get quickLabel;

  /// No description provided for @needMoreHelpLabel.
  ///
  /// In en, this message translates to:
  /// **'Need more help?'**
  String get needMoreHelpLabel;

  /// No description provided for @hulucaTeamSupport.
  ///
  /// In en, this message translates to:
  /// **'Huluca team is ready to support via email, Zalo or direct training.'**
  String get hulucaTeamSupport;

  /// No description provided for @emailSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Email support@huluca.com'**
  String get emailSupportLabel;

  /// No description provided for @emailCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied email support@huluca.com'**
  String get emailCopied;

  /// No description provided for @zaloSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Zalo Support'**
  String get zaloSupportLabel;

  /// No description provided for @contactZaloLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Zalo Support: 0901 234 567'**
  String get contactZaloLabel;

  /// No description provided for @scheduleTrainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule Training'**
  String get scheduleTrainingLabel;

  /// No description provided for @scheduleTrainingThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Schedule online training this week.'**
  String get scheduleTrainingThisWeek;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @defaultSettings.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultSettings;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @switchShop.
  ///
  /// In en, this message translates to:
  /// **'Switch shop'**
  String get switchShop;

  /// No description provided for @currentShop.
  ///
  /// In en, this message translates to:
  /// **'Current Shop'**
  String get currentShop;

  /// No description provided for @shopSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to: {shopName}'**
  String shopSwitched(Object shopName);

  /// No description provided for @cannotSwitchShop.
  ///
  /// In en, this message translates to:
  /// **'Cannot switch shop'**
  String get cannotSwitchShop;

  /// No description provided for @createNewBranch.
  ///
  /// In en, this message translates to:
  /// **'Create new branch'**
  String get createNewBranch;

  /// No description provided for @branchName.
  ///
  /// In en, this message translates to:
  /// **'Branch name'**
  String get branchName;

  /// No description provided for @branchCreated.
  ///
  /// In en, this message translates to:
  /// **'Branch created: {name}'**
  String branchCreated(Object name);

  /// No description provided for @errorCreatingBranch.
  ///
  /// In en, this message translates to:
  /// **'Error creating branch'**
  String get errorCreatingBranch;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @phoneLengthInvalid.
  ///
  /// In en, this message translates to:
  /// **'Phone number must be 9-12 digits'**
  String get phoneLengthInvalid;

  /// No description provided for @imeiMinLength.
  ///
  /// In en, this message translates to:
  /// **'IMEI must be at least 6 characters'**
  String get imeiMinLength;

  /// No description provided for @imeiLengthInvalid.
  ///
  /// In en, this message translates to:
  /// **'IMEI must be 6-20 characters'**
  String get imeiLengthInvalid;

  /// No description provided for @imeiDigitsOnly.
  ///
  /// In en, this message translates to:
  /// **'IMEI must contain only digits'**
  String get imeiDigitsOnly;

  /// No description provided for @modelMinLength.
  ///
  /// In en, this message translates to:
  /// **'Model must be at least 2 characters'**
  String get modelMinLength;

  /// No description provided for @modelMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Model must not exceed 50 characters'**
  String get modelMaxLength;

  /// No description provided for @printLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Print Label'**
  String get printLabelTitle;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @productInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Information'**
  String get productInfoTitle;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name:'**
  String get productNameLabel;

  /// No description provided for @productDetailLabel.
  ///
  /// In en, this message translates to:
  /// **'Detail:'**
  String get productDetailLabel;

  /// No description provided for @imeiLabelWithColon.
  ///
  /// In en, this message translates to:
  /// **'IMEI:'**
  String get imeiLabelWithColon;

  /// No description provided for @originalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Original Price:'**
  String get originalPriceLabel;

  /// No description provided for @labelModeAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Mode'**
  String get labelModeAutoTitle;

  /// No description provided for @labelModeAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use label design settings'**
  String get labelModeAutoSubtitle;

  /// No description provided for @labelModeCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Mode'**
  String get labelModeCustomTitle;

  /// No description provided for @labelModeCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter custom prices and text'**
  String get labelModeCustomSubtitle;

  /// No description provided for @labelCustomContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Content'**
  String get labelCustomContentTitle;

  /// No description provided for @labelKpkExplain.
  ///
  /// In en, this message translates to:
  /// **'KPK: \"Không phải không\" price'**
  String get labelKpkExplain;

  /// No description provided for @labelCpkExplain.
  ///
  /// In en, this message translates to:
  /// **'CPK: \"Có phải không\" price'**
  String get labelCpkExplain;

  /// No description provided for @currencySymbol.
  ///
  /// In en, this message translates to:
  /// **'₫'**
  String get currencySymbol;

  /// No description provided for @deviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceNameLabel;

  /// No description provided for @productDetailLabelPlain.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get productDetailLabelPlain;

  /// No description provided for @qrCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCodeLabel;

  /// No description provided for @addCustomLinesLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Lines'**
  String get addCustomLinesLabel;

  /// No description provided for @customLine1Hint.
  ///
  /// In en, this message translates to:
  /// **'Custom line 1...'**
  String get customLine1Hint;

  /// No description provided for @customLine2Hint.
  ///
  /// In en, this message translates to:
  /// **'Custom line 2...'**
  String get customLine2Hint;

  /// No description provided for @customLine3Hint.
  ///
  /// In en, this message translates to:
  /// **'Custom line 3...'**
  String get customLine3Hint;

  /// No description provided for @printQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Print Quantity'**
  String get printQuantityLabel;

  /// No description provided for @priceKpkPrefix.
  ///
  /// In en, this message translates to:
  /// **'KPK: '**
  String get priceKpkPrefix;

  /// No description provided for @priceCpkPrefix.
  ///
  /// In en, this message translates to:
  /// **'CPK: '**
  String get priceCpkPrefix;

  /// No description provided for @imeiPrefix.
  ///
  /// In en, this message translates to:
  /// **'IMEI: '**
  String get imeiPrefix;

  /// No description provided for @printingLabel.
  ///
  /// In en, this message translates to:
  /// **'Printing...'**
  String get printingLabel;

  /// No description provided for @printLabelQuantity.
  ///
  /// In en, this message translates to:
  /// **'Print {count} labels'**
  String printLabelQuantity(int count);

  /// No description provided for @printLabelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully printed {count} labels'**
  String printLabelSuccess(int count);

  /// No description provided for @printLabelPartial.
  ///
  /// In en, this message translates to:
  /// **'Printed {success}/{total} labels'**
  String printLabelPartial(int success, int total);

  /// No description provided for @printLabelError.
  ///
  /// In en, this message translates to:
  /// **'Print error: {error}'**
  String printLabelError(String error);

  /// No description provided for @imeiWithValue.
  ///
  /// In en, this message translates to:
  /// **'IMEI: {imei}'**
  String imeiWithValue(String imei);

  /// No description provided for @labelNoteFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Label Note'**
  String get labelNoteFieldLabel;

  /// No description provided for @labelNoteFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Additional note for label...'**
  String get labelNoteFieldHint;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{fieldName} is required'**
  String fieldRequired(String fieldName);

  /// No description provided for @approveAttendance.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get approveAttendance;

  /// No description provided for @rejectAttendance.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectAttendance;

  /// No description provided for @bulkApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve all'**
  String get bulkApprove;

  /// No description provided for @forgotCheckin.
  ///
  /// In en, this message translates to:
  /// **'Forgot check-in'**
  String get forgotCheckin;

  /// No description provided for @forgotCheckinRequest.
  ///
  /// In en, this message translates to:
  /// **'Forgot check-in request'**
  String get forgotCheckinRequest;

  /// No description provided for @editOvertime.
  ///
  /// In en, this message translates to:
  /// **'Edit overtime'**
  String get editOvertime;

  /// No description provided for @overtimeFrom.
  ///
  /// In en, this message translates to:
  /// **'OT from'**
  String get overtimeFrom;

  /// No description provided for @overtimeTo.
  ///
  /// In en, this message translates to:
  /// **'OT to'**
  String get overtimeTo;

  /// No description provided for @overtimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'OT minutes'**
  String get overtimeMinutes;

  /// No description provided for @editCheckTime.
  ///
  /// In en, this message translates to:
  /// **'Edit time'**
  String get editCheckTime;

  /// No description provided for @leaveRequest.
  ///
  /// In en, this message translates to:
  /// **'Leave request'**
  String get leaveRequest;

  /// No description provided for @leaveRequests.
  ///
  /// In en, this message translates to:
  /// **'LEAVE REQUESTS'**
  String get leaveRequests;

  /// No description provided for @createLeaveRequest.
  ///
  /// In en, this message translates to:
  /// **'Create leave request'**
  String get createLeaveRequest;

  /// No description provided for @leaveType.
  ///
  /// In en, this message translates to:
  /// **'Leave type'**
  String get leaveType;

  /// No description provided for @annualLeave.
  ///
  /// In en, this message translates to:
  /// **'Annual leave'**
  String get annualLeave;

  /// No description provided for @sickLeave.
  ///
  /// In en, this message translates to:
  /// **'Sick leave'**
  String get sickLeave;

  /// No description provided for @unpaidLeave.
  ///
  /// In en, this message translates to:
  /// **'Unpaid leave'**
  String get unpaidLeave;

  /// No description provided for @personalLeave.
  ///
  /// In en, this message translates to:
  /// **'Personal leave'**
  String get personalLeave;

  /// No description provided for @maternityLeave.
  ///
  /// In en, this message translates to:
  /// **'Maternity leave'**
  String get maternityLeave;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @totalDays.
  ///
  /// In en, this message translates to:
  /// **'Total days'**
  String get totalDays;

  /// No description provided for @leaveReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get leaveReason;

  /// No description provided for @approveLeave.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveLeave;

  /// No description provided for @rejectLeave.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectLeave;

  /// No description provided for @rejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason...'**
  String get rejectReasonHint;

  /// No description provided for @noLeaveRequests.
  ///
  /// In en, this message translates to:
  /// **'No leave requests'**
  String get noLeaveRequests;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get noPendingRequests;

  /// No description provided for @attendanceApproval.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE APPROVAL'**
  String get attendanceApproval;

  /// No description provided for @confirmAttendanceMsg.
  ///
  /// In en, this message translates to:
  /// **'Confirm this attendance counts toward salary?'**
  String get confirmAttendanceMsg;

  /// No description provided for @rejectAttendanceMsg.
  ///
  /// In en, this message translates to:
  /// **'Reject this attendance record?'**
  String get rejectAttendanceMsg;

  /// No description provided for @approvedCount.
  ///
  /// In en, this message translates to:
  /// **'Approved: {count}'**
  String approvedCount(int count);

  /// No description provided for @bulkApproveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Approved {count} attendance records'**
  String bulkApproveSuccess(int count);

  /// No description provided for @leaveRequestCreated.
  ///
  /// In en, this message translates to:
  /// **'Leave request created'**
  String get leaveRequestCreated;

  /// No description provided for @leaveRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Leave request approved'**
  String get leaveRequestApproved;

  /// No description provided for @leaveRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Leave request rejected'**
  String get leaveRequestRejected;

  /// No description provided for @attendanceApproved.
  ///
  /// In en, this message translates to:
  /// **'Attendance confirmed'**
  String get attendanceApproved;

  /// No description provided for @attendanceRejected.
  ///
  /// In en, this message translates to:
  /// **'Attendance rejected'**
  String get attendanceRejected;

  /// No description provided for @overtimeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Overtime updated'**
  String get overtimeUpdated;

  /// No description provided for @timeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Time updated'**
  String get timeUpdated;

  /// No description provided for @forgotCheckinCreated.
  ///
  /// In en, this message translates to:
  /// **'Forgot check-in request sent'**
  String get forgotCheckinCreated;

  /// No description provided for @tabApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get tabApproval;

  /// No description provided for @tabLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get tabLeave;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @pendingApprovalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingApprovalCount(int count);

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @submitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get submitRequest;

  /// No description provided for @forgotCheckinDate.
  ///
  /// In en, this message translates to:
  /// **'Date forgot check-in'**
  String get forgotCheckinDate;

  /// No description provided for @forgotCheckinTime.
  ///
  /// In en, this message translates to:
  /// **'Check-in time'**
  String get forgotCheckinTime;

  /// No description provided for @forgotCheckoutTime.
  ///
  /// In en, this message translates to:
  /// **'Check-out time'**
  String get forgotCheckoutTime;

  /// No description provided for @requestNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get requestNote;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get remaining;

  /// No description provided for @incidentalUpper.
  ///
  /// In en, this message translates to:
  /// **'INCIDENTAL'**
  String get incidentalUpper;

  /// No description provided for @technician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get technician;

  /// No description provided for @paymentCashLower.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCashLower;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export Excel'**
  String get exportExcel;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @last7days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get last7days;

  /// No description provided for @combined.
  ///
  /// In en, this message translates to:
  /// **'COMBINED'**
  String get combined;

  /// No description provided for @weekUpper.
  ///
  /// In en, this message translates to:
  /// **'WEEK'**
  String get weekUpper;

  /// No description provided for @paymentTransferLower.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get paymentTransferLower;

  /// No description provided for @salePrice.
  ///
  /// In en, this message translates to:
  /// **'Sale price'**
  String get salePrice;

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settled;

  /// No description provided for @paymentDone.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentDone;

  /// No description provided for @retailCustomer.
  ///
  /// In en, this message translates to:
  /// **'Retail customer'**
  String get retailCustomer;

  /// No description provided for @quickCode.
  ///
  /// In en, this message translates to:
  /// **'Quick code'**
  String get quickCode;

  /// No description provided for @refundUpper.
  ///
  /// In en, this message translates to:
  /// **'REFUND'**
  String get refundUpper;

  /// No description provided for @transferShort.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferShort;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @utilities.
  ///
  /// In en, this message translates to:
  /// **'UTILITIES'**
  String get utilities;

  /// No description provided for @sold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get sold;

  /// No description provided for @paySupplierDebt.
  ///
  /// In en, this message translates to:
  /// **'Pay supplier debt'**
  String get paySupplierDebt;

  /// No description provided for @returnGoods.
  ///
  /// In en, this message translates to:
  /// **'Return goods'**
  String get returnGoods;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @payable.
  ///
  /// In en, this message translates to:
  /// **'Payable'**
  String get payable;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'PERSONAL'**
  String get personal;

  /// No description provided for @salePriceVnd.
  ///
  /// In en, this message translates to:
  /// **'Sale price (VND)'**
  String get salePriceVnd;

  /// No description provided for @deduction.
  ///
  /// In en, this message translates to:
  /// **'Deduction'**
  String get deduction;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @costPriceVnd.
  ///
  /// In en, this message translates to:
  /// **'Cost price (VND)'**
  String get costPriceVnd;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @addNewSupplier.
  ///
  /// In en, this message translates to:
  /// **'Add new supplier'**
  String get addNewSupplier;

  /// No description provided for @noShopName.
  ///
  /// In en, this message translates to:
  /// **'Unnamed shop'**
  String get noShopName;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get totalAmount;

  /// No description provided for @editLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editLabel;

  /// No description provided for @rejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reject reason'**
  String get rejectReason;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @payDebt.
  ///
  /// In en, this message translates to:
  /// **'Pay debt'**
  String get payDebt;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @incidentalIncome.
  ///
  /// In en, this message translates to:
  /// **'Incidental income'**
  String get incidentalIncome;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add new'**
  String get addNew;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @noPermission.
  ///
  /// In en, this message translates to:
  /// **'No permission'**
  String get noPermission;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @deleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete data'**
  String get deleteData;

  /// No description provided for @aiFilledRepairOrder.
  ///
  /// In en, this message translates to:
  /// **'AI auto-filled repair order.'**
  String get aiFilledRepairOrder;

  /// No description provided for @parsedRepairOrderFilled.
  ///
  /// In en, this message translates to:
  /// **'Recognized and filled repair order.'**
  String get parsedRepairOrderFilled;

  /// No description provided for @orderSavedUploadingImages.
  ///
  /// In en, this message translates to:
  /// **'Order saved. Uploading images, please don\'t close the app.'**
  String get orderSavedUploadingImages;

  /// No description provided for @uploadingImagesToSystem.
  ///
  /// In en, this message translates to:
  /// **'Uploading images, please don\'t close the app.'**
  String get uploadingImagesToSystem;

  /// No description provided for @searchPartner.
  ///
  /// In en, this message translates to:
  /// **'Search partner'**
  String get searchPartner;

  /// No description provided for @noPartnerFound.
  ///
  /// In en, this message translates to:
  /// **'No matching partner found'**
  String get noPartnerFound;

  /// No description provided for @quickInputTooltip.
  ///
  /// In en, this message translates to:
  /// **'Quick input by command'**
  String get quickInputTooltip;

  /// No description provided for @saveAndPrint.
  ///
  /// In en, this message translates to:
  /// **'Save & Print'**
  String get saveAndPrint;

  /// No description provided for @hideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get hideDetails;

  /// No description provided for @showMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details (security, appearance, accessories, photos)'**
  String get showMoreDetails;

  /// No description provided for @customerOwesDebt.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get customerOwesDebt;

  /// No description provided for @shopOwesCustomer.
  ///
  /// In en, this message translates to:
  /// **'Shop owes'**
  String get shopOwesCustomer;

  /// No description provided for @customerAddressOptional.
  ///
  /// In en, this message translates to:
  /// **'Customer address (optional)'**
  String get customerAddressOptional;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @paymentRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Request'**
  String get paymentRequestTitle;

  /// No description provided for @searchNamePhoneBankAmount.
  ///
  /// In en, this message translates to:
  /// **'Search name, phone, bank, amount...'**
  String get searchNamePhoneBankAmount;

  /// No description provided for @createNewRequest.
  ///
  /// In en, this message translates to:
  /// **'Create new request'**
  String get createNewRequest;

  /// No description provided for @pendingApprovalStatus.
  ///
  /// In en, this message translates to:
  /// **'⏳ Pending approval'**
  String get pendingApprovalStatus;

  /// No description provided for @paidStatus.
  ///
  /// In en, this message translates to:
  /// **'✅ Paid'**
  String get paidStatus;

  /// No description provided for @noPaymentRequests.
  ///
  /// In en, this message translates to:
  /// **'No payment requests'**
  String get noPaymentRequests;

  /// No description provided for @tapPlusToCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Tap ⊕ on the title bar to create new'**
  String get tapPlusToCreateNew;

  /// No description provided for @overdueLabel.
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get overdueLabel;

  /// No description provided for @customerBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Customer bank transfer'**
  String get customerBankTransfer;

  /// No description provided for @customerCash.
  ///
  /// In en, this message translates to:
  /// **'Customer cash payment'**
  String get customerCash;

  /// No description provided for @ownerTransferredToBank.
  ///
  /// In en, this message translates to:
  /// **'Owner transferred to bank'**
  String get ownerTransferredToBank;

  /// No description provided for @paymentBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Payment (bank transfer)'**
  String get paymentBankTransfer;

  /// No description provided for @deleteRequest.
  ///
  /// In en, this message translates to:
  /// **'Delete request'**
  String get deleteRequest;

  /// No description provided for @rejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectButton;

  /// No description provided for @accountContractNumber.
  ///
  /// In en, this message translates to:
  /// **'Account / Contract No.'**
  String get accountContractNumber;

  /// No description provided for @bankOrLoanOrg.
  ///
  /// In en, this message translates to:
  /// **'Bank / Loan organization'**
  String get bankOrLoanOrg;

  /// No description provided for @customerPaysStaff.
  ///
  /// In en, this message translates to:
  /// **'Customer pays staff'**
  String get customerPaysStaff;

  /// No description provided for @bankTransferLabelWithEmoji.
  ///
  /// In en, this message translates to:
  /// **'🏦 Bank transfer'**
  String get bankTransferLabelWithEmoji;

  /// No description provided for @cashLabelWithEmoji.
  ///
  /// In en, this message translates to:
  /// **'💵 Cash'**
  String get cashLabelWithEmoji;

  /// No description provided for @ownerTransferBank.
  ///
  /// In en, this message translates to:
  /// **'Owner transfer to bank'**
  String get ownerTransferBank;

  /// No description provided for @transferredToBank.
  ///
  /// In en, this message translates to:
  /// **'🏦 Transferred to bank'**
  String get transferredToBank;

  /// No description provided for @staffSender.
  ///
  /// In en, this message translates to:
  /// **'Sent by staff'**
  String get staffSender;

  /// No description provided for @createdDate.
  ///
  /// In en, this message translates to:
  /// **'Created date'**
  String get createdDate;

  /// No description provided for @processedBy.
  ///
  /// In en, this message translates to:
  /// **'Processed by'**
  String get processedBy;

  /// No description provided for @processedDate.
  ///
  /// In en, this message translates to:
  /// **'Processed date'**
  String get processedDate;

  /// No description provided for @attachedImages.
  ///
  /// In en, this message translates to:
  /// **'Attached images (invoice, bank transfer):'**
  String get attachedImages;

  /// No description provided for @confirmBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Confirm bank transfer'**
  String get confirmBankTransfer;

  /// No description provided for @bankTransferNoteMsg.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer will be recorded in the cash book.\nAfter confirming, please send a screenshot of the transfer as proof.'**
  String get bankTransferNoteMsg;

  /// No description provided for @confirmedBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transferred to bank ✓'**
  String get confirmedBankTransfer;

  /// No description provided for @rejectRequest.
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get rejectRequest;

  /// No description provided for @selectProofImageHint.
  ///
  /// In en, this message translates to:
  /// **'💡 Select bank transfer screenshot to send as proof'**
  String get selectProofImageHint;

  /// No description provided for @selectRequestToSendImage.
  ///
  /// In en, this message translates to:
  /// **'Select request to send bank transfer image...'**
  String get selectRequestToSendImage;

  /// No description provided for @selectRequestForBankImage.
  ///
  /// In en, this message translates to:
  /// **'Select request to send bank transfer image'**
  String get selectRequestForBankImage;

  /// No description provided for @uploadingProofImages.
  ///
  /// In en, this message translates to:
  /// **'Uploading proof images, please do not exit the app.'**
  String get uploadingProofImages;

  /// No description provided for @sendPaymentRequest.
  ///
  /// In en, this message translates to:
  /// **'Send payment request'**
  String get sendPaymentRequest;

  /// No description provided for @paymentType.
  ///
  /// In en, this message translates to:
  /// **'Payment type'**
  String get paymentType;

  /// No description provided for @customerInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer information'**
  String get customerInfoLabel;

  /// No description provided for @searchCustomerShort.
  ///
  /// In en, this message translates to:
  /// **'Find customer'**
  String get searchCustomerShort;

  /// No description provided for @customerPaysStaffLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer pays staff'**
  String get customerPaysStaffLabel;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment details'**
  String get paymentDetails;

  /// No description provided for @amountVnd.
  ///
  /// In en, this message translates to:
  /// **'Amount (₫)'**
  String get amountVnd;

  /// No description provided for @accountOrContractCode.
  ///
  /// In en, this message translates to:
  /// **'Account / Contract code'**
  String get accountOrContractCode;

  /// No description provided for @bankOrInstallmentOrg.
  ///
  /// In en, this message translates to:
  /// **'Bank / Installment organization'**
  String get bankOrInstallmentOrg;

  /// No description provided for @noteForOwner.
  ///
  /// In en, this message translates to:
  /// **'Note for shop owner'**
  String get noteForOwner;

  /// No description provided for @imagesInvoiceBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Images (invoice, bank transfer...)'**
  String get imagesInvoiceBankTransfer;

  /// No description provided for @sendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendingLabel;

  /// No description provided for @sendRequestLabel.
  ///
  /// In en, this message translates to:
  /// **'SEND REQUEST'**
  String get sendRequestLabel;

  /// No description provided for @paymentTypeName.
  ///
  /// In en, this message translates to:
  /// **'Payment type name'**
  String get paymentTypeName;

  /// No description provided for @electricityPayment.
  ///
  /// In en, this message translates to:
  /// **'Electricity bill'**
  String get electricityPayment;

  /// No description provided for @waterPayment.
  ///
  /// In en, this message translates to:
  /// **'Water bill'**
  String get waterPayment;

  /// No description provided for @internetPayment.
  ///
  /// In en, this message translates to:
  /// **'Internet bill'**
  String get internetPayment;

  /// No description provided for @bankLoanPayment.
  ///
  /// In en, this message translates to:
  /// **'Bank loan'**
  String get bankLoanPayment;

  /// No description provided for @installmentPayment.
  ///
  /// In en, this message translates to:
  /// **'Installment'**
  String get installmentPayment;

  /// No description provided for @insurancePayment.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insurancePayment;

  /// No description provided for @selectCustomerDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get selectCustomerDialogTitle;

  /// No description provided for @searchByNamePhoneAddress.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, address...'**
  String get searchByNamePhoneAddress;

  /// No description provided for @sentPaymentRequest.
  ///
  /// In en, this message translates to:
  /// **'✅ Payment request sent'**
  String get sentPaymentRequest;

  /// No description provided for @errorSendingRequest.
  ///
  /// In en, this message translates to:
  /// **'❌ Error sending request'**
  String get errorSendingRequest;

  /// No description provided for @adminConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'SUPER ADMIN CONSOLE'**
  String get adminConsoleTitle;

  /// No description provided for @adminAuthSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Authenticate Super Admin'**
  String get adminAuthSuperAdmin;

  /// No description provided for @adminAuthPin.
  ///
  /// In en, this message translates to:
  /// **'Authenticate PIN'**
  String get adminAuthPin;

  /// No description provided for @adminEnterPinForDangerous.
  ///
  /// In en, this message translates to:
  /// **'Enter Super Admin PIN to continue dangerous operation.'**
  String get adminEnterPinForDangerous;

  /// No description provided for @adminPinHint.
  ///
  /// In en, this message translates to:
  /// **'PIN (4-6 digits)'**
  String get adminPinHint;

  /// No description provided for @adminPinWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get adminPinWrong;

  /// No description provided for @adminEditUser.
  ///
  /// In en, this message translates to:
  /// **'Edit user'**
  String get adminEditUser;

  /// No description provided for @adminUserPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get adminUserPhone;

  /// No description provided for @adminShopId.
  ///
  /// In en, this message translates to:
  /// **'Shop ID'**
  String get adminShopId;

  /// No description provided for @adminExitConsole.
  ///
  /// In en, this message translates to:
  /// **'Exit Console?'**
  String get adminExitConsole;

  /// No description provided for @adminExitConsoleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the Super Admin Console?'**
  String get adminExitConsoleConfirm;

  /// No description provided for @adminStayHere.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get adminStayHere;

  /// No description provided for @adminLogoutConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout from the Super Admin Console?'**
  String get adminLogoutConfirmMsg;

  /// No description provided for @adminNoAccess.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to the Super Admin Console.'**
  String get adminNoAccess;

  /// No description provided for @adminReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get adminReload;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminShops.
  ///
  /// In en, this message translates to:
  /// **'Shops'**
  String get adminShops;

  /// No description provided for @adminUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// No description provided for @adminLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get adminLogs;

  /// No description provided for @adminMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get adminMore;

  /// No description provided for @adminBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get adminBroadcast;

  /// No description provided for @adminPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get adminPermissions;

  /// No description provided for @adminDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get adminDangerZone;

  /// No description provided for @adminAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get adminAuditLogs;

  /// No description provided for @adminTotalShops.
  ///
  /// In en, this message translates to:
  /// **'Total shops'**
  String get adminTotalShops;

  /// No description provided for @adminActiveShops.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminActiveShops;

  /// No description provided for @adminTotalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total users'**
  String get adminTotalUsers;

  /// No description provided for @adminLockedShops.
  ///
  /// In en, this message translates to:
  /// **'Locked shops'**
  String get adminLockedShops;

  /// No description provided for @adminGoToShopsToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Go to Shops tab to unlock.'**
  String get adminGoToShopsToUnlock;

  /// No description provided for @adminSystemNormal.
  ///
  /// In en, this message translates to:
  /// **'System operating normally'**
  String get adminSystemNormal;

  /// No description provided for @adminNoLockedShops.
  ///
  /// In en, this message translates to:
  /// **'No shops are currently locked.'**
  String get adminNoLockedShops;

  /// No description provided for @adminShopLockedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shops are locked'**
  String adminShopLockedCount(int count);

  /// No description provided for @adminSearchShops.
  ///
  /// In en, this message translates to:
  /// **'Search shops by name, email, ID...'**
  String get adminSearchShops;

  /// No description provided for @adminShowDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get adminShowDeleted;

  /// No description provided for @adminNoMatchingShops.
  ///
  /// In en, this message translates to:
  /// **'No matching shops'**
  String get adminNoMatchingShops;

  /// No description provided for @adminViewDetail.
  ///
  /// In en, this message translates to:
  /// **'View detail'**
  String get adminViewDetail;

  /// No description provided for @adminEnterShop.
  ///
  /// In en, this message translates to:
  /// **'Enter shop'**
  String get adminEnterShop;

  /// No description provided for @adminUnlockApp.
  ///
  /// In en, this message translates to:
  /// **'Unlock app'**
  String get adminUnlockApp;

  /// No description provided for @adminLockApp.
  ///
  /// In en, this message translates to:
  /// **'Lock app'**
  String get adminLockApp;

  /// No description provided for @adminResetData.
  ///
  /// In en, this message translates to:
  /// **'Reset data'**
  String get adminResetData;

  /// No description provided for @adminFullApp.
  ///
  /// In en, this message translates to:
  /// **'Entire app'**
  String get adminFullApp;

  /// No description provided for @adminNoUsersInShop.
  ///
  /// In en, this message translates to:
  /// **'No users in this shop'**
  String get adminNoUsersInShop;

  /// No description provided for @adminNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get adminNoActivity;

  /// No description provided for @adminSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search by name, email, role, shop ID...'**
  String get adminSearchUsers;

  /// No description provided for @adminNoShopAssigned.
  ///
  /// In en, this message translates to:
  /// **'No shop assigned'**
  String get adminNoShopAssigned;

  /// No description provided for @adminNoMatchingUsers.
  ///
  /// In en, this message translates to:
  /// **'No matching users'**
  String get adminNoMatchingUsers;

  /// No description provided for @adminDeleteUserDoc.
  ///
  /// In en, this message translates to:
  /// **'Delete user doc'**
  String get adminDeleteUserDoc;

  /// No description provided for @adminDeleteCompletely.
  ///
  /// In en, this message translates to:
  /// **'Delete completely'**
  String get adminDeleteCompletely;

  /// No description provided for @adminAuthAndUserData.
  ///
  /// In en, this message translates to:
  /// **'Auth + data created by user'**
  String get adminAuthAndUserData;

  /// No description provided for @adminDeleteProfileOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete profile only, Auth remains'**
  String get adminDeleteProfileOnly;

  /// No description provided for @adminPermissionPanel.
  ///
  /// In en, this message translates to:
  /// **'Permission Panel'**
  String get adminPermissionPanel;

  /// No description provided for @adminPermissionPanelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard role-based baseline for owner/manager/staff. Shop-level locks will override at runtime.'**
  String get adminPermissionPanelSubtitle;

  /// No description provided for @adminNoAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'No matching audit logs.'**
  String get adminNoAuditLogs;

  /// No description provided for @adminFilterShopId.
  ///
  /// In en, this message translates to:
  /// **'Filter shopId'**
  String get adminFilterShopId;

  /// No description provided for @adminFilterAction.
  ///
  /// In en, this message translates to:
  /// **'Filter action'**
  String get adminFilterAction;

  /// No description provided for @adminSearchEmailUser.
  ///
  /// In en, this message translates to:
  /// **'Search email/user'**
  String get adminSearchEmailUser;

  /// No description provided for @adminSyncClaims.
  ///
  /// In en, this message translates to:
  /// **'Sync custom claims'**
  String get adminSyncClaims;

  /// No description provided for @adminSyncClaimsDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync claims for all users when rules/roles change.'**
  String get adminSyncClaimsDesc;

  /// No description provided for @adminSyncClaimsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync claims successful.'**
  String get adminSyncClaimsSuccess;

  /// No description provided for @adminSyncClaimsError.
  ///
  /// In en, this message translates to:
  /// **'Sync claims error: {error}'**
  String adminSyncClaimsError(String error);

  /// No description provided for @adminPinSecurity.
  ///
  /// In en, this message translates to:
  /// **'PIN Security'**
  String get adminPinSecurity;

  /// No description provided for @adminPinSecurityDesc.
  ///
  /// In en, this message translates to:
  /// **'Protect Console with PIN when session expires'**
  String get adminPinSecurityDesc;

  /// No description provided for @adminPinEnabled.
  ///
  /// In en, this message translates to:
  /// **'PIN enabled'**
  String get adminPinEnabled;

  /// No description provided for @adminPinEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'PIN required when session expires (30 min idle)'**
  String get adminPinEnabledDesc;

  /// No description provided for @adminPinNotSetup.
  ///
  /// In en, this message translates to:
  /// **'PIN not set up'**
  String get adminPinNotSetup;

  /// No description provided for @adminPinNotSetupDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable PIN to protect console'**
  String get adminPinNotSetupDesc;

  /// No description provided for @adminChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get adminChangePin;

  /// No description provided for @adminDisablePin.
  ///
  /// In en, this message translates to:
  /// **'Disable PIN'**
  String get adminDisablePin;

  /// No description provided for @adminSetupPin.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get adminSetupPin;

  /// No description provided for @adminSetupPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up PIN'**
  String get adminSetupPinTitle;

  /// No description provided for @adminChangePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get adminChangePinTitle;

  /// No description provided for @adminNewPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN (4-6 digits)'**
  String get adminNewPin;

  /// No description provided for @adminConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get adminConfirmPin;

  /// No description provided for @adminPinTooShort.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4-6 digits'**
  String get adminPinTooShort;

  /// No description provided for @adminPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get adminPinMismatch;

  /// No description provided for @adminPinSetupSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN set up successfully.'**
  String get adminPinSetupSuccess;

  /// No description provided for @adminPinSetupError.
  ///
  /// In en, this message translates to:
  /// **'Error setting up PIN.'**
  String get adminPinSetupError;

  /// No description provided for @adminDisablePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable PIN'**
  String get adminDisablePinTitle;

  /// No description provided for @adminCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get adminCurrentPin;

  /// No description provided for @adminEnterCurrentPinToDisable.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN to confirm disable:'**
  String get adminEnterCurrentPinToDisable;

  /// No description provided for @adminCurrentPinWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get adminCurrentPinWrong;

  /// No description provided for @adminPinDisabled.
  ///
  /// In en, this message translates to:
  /// **'PIN disabled.'**
  String get adminPinDisabled;

  /// No description provided for @adminDisablePinButton.
  ///
  /// In en, this message translates to:
  /// **'Disable PIN'**
  String get adminDisablePinButton;

  /// No description provided for @adminSendSystemNotification.
  ///
  /// In en, this message translates to:
  /// **'Send System Notification'**
  String get adminSendSystemNotification;

  /// No description provided for @adminSendToAllUsersDesc.
  ///
  /// In en, this message translates to:
  /// **'Send to ALL users via dialog + push.'**
  String get adminSendToAllUsersDesc;

  /// No description provided for @adminNotificationType.
  ///
  /// In en, this message translates to:
  /// **'Notification type'**
  String get adminNotificationType;

  /// No description provided for @adminNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminNotifTitle;

  /// No description provided for @adminNotifTitleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: New version update required'**
  String get adminNotifTitleHint;

  /// No description provided for @adminNotifContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get adminNotifContent;

  /// No description provided for @adminNotifContentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter detailed notification content...'**
  String get adminNotifContentHint;

  /// No description provided for @adminSendToAll.
  ///
  /// In en, this message translates to:
  /// **'Send to all users'**
  String get adminSendToAll;

  /// No description provided for @adminSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get adminSending;

  /// No description provided for @adminSendSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Sent successfully to all users!'**
  String get adminSendSuccess;

  /// No description provided for @adminNotifTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter title and content.'**
  String get adminNotifTitleRequired;

  /// No description provided for @adminNotificationHistory.
  ///
  /// In en, this message translates to:
  /// **'Notification history'**
  String get adminNotificationHistory;

  /// No description provided for @adminNoNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get adminNoNotificationsYet;

  /// No description provided for @adminExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get adminExpired;

  /// No description provided for @adminDangerZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All operations here require PIN authentication and are logged in audit log.'**
  String get adminDangerZoneSubtitle;

  /// No description provided for @adminSelectDataToDelete.
  ///
  /// In en, this message translates to:
  /// **'Select data to delete'**
  String get adminSelectDataToDelete;

  /// No description provided for @adminSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items selected'**
  String adminSelectedCount(int count);

  /// No description provided for @adminDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete ({count} items)'**
  String adminDeleteSelected(int count);

  /// No description provided for @adminIsOwnerWarning.
  ///
  /// In en, this message translates to:
  /// **'This is the SHOP OWNER. Be careful when deleting!'**
  String get adminIsOwnerWarning;

  /// No description provided for @adminDeleteUserAndData.
  ///
  /// In en, this message translates to:
  /// **'Delete user + data'**
  String get adminDeleteUserAndData;

  /// No description provided for @adminDeleteUserDocOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete user doc'**
  String get adminDeleteUserDocOnly;

  /// No description provided for @adminWillDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Will DELETE PERMANENTLY:'**
  String get adminWillDeletePermanently;

  /// No description provided for @adminDeleteFirebaseAuth.
  ///
  /// In en, this message translates to:
  /// **'• Firebase Auth account (loses login access)'**
  String get adminDeleteFirebaseAuth;

  /// No description provided for @adminDeleteUserProfile.
  ///
  /// In en, this message translates to:
  /// **'• User profile in Firestore'**
  String get adminDeleteUserProfile;

  /// No description provided for @adminDeleteUserOrders.
  ///
  /// In en, this message translates to:
  /// **'• Repair, sale orders, expenses created by user'**
  String get adminDeleteUserOrders;

  /// No description provided for @adminDeleteUserAttendance.
  ///
  /// In en, this message translates to:
  /// **'• User attendance data and notifications'**
  String get adminDeleteUserAttendance;

  /// No description provided for @adminShopDataNotDeleted.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Shop data (inventory, customers...) will NOT be deleted.'**
  String get adminShopDataNotDeleted;

  /// No description provided for @adminOnlyDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Only deletes user profile in Firestore.'**
  String get adminOnlyDeleteProfile;

  /// No description provided for @adminAuthStillExists.
  ///
  /// In en, this message translates to:
  /// **'Firebase Auth account remains — user can still login but loses shop link.'**
  String get adminAuthStillExists;

  /// No description provided for @adminDeletingData.
  ///
  /// In en, this message translates to:
  /// **'Deleting data...'**
  String get adminDeletingData;

  /// No description provided for @adminResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted selected data of shop {shopName}'**
  String adminResetSuccess(String shopName);

  /// No description provided for @adminResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String adminResetFailed(String error);

  /// No description provided for @adminSoftDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Soft-deleted shop {shopName}'**
  String adminSoftDeleteSuccess(String shopName);

  /// No description provided for @adminDeletedUserWithData.
  ///
  /// In en, this message translates to:
  /// **'Deleted user + data: {email}'**
  String adminDeletedUserWithData(String email);

  /// No description provided for @adminDeletedUserDoc.
  ///
  /// In en, this message translates to:
  /// **'Deleted user doc: {email}'**
  String adminDeletedUserDoc(String email);

  /// No description provided for @adminLockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Locked {label}'**
  String adminLockedLabel(String label);

  /// No description provided for @adminUnlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unlocked {label}'**
  String adminUnlockedLabel(String label);

  /// No description provided for @adminLockFinance.
  ///
  /// In en, this message translates to:
  /// **'Lock admin finance'**
  String get adminLockFinance;

  /// No description provided for @adminLockInventory.
  ///
  /// In en, this message translates to:
  /// **'Lock inventory for staff'**
  String get adminLockInventory;

  /// No description provided for @adminLockSales.
  ///
  /// In en, this message translates to:
  /// **'Lock sales for staff'**
  String get adminLockSales;

  /// No description provided for @adminLockDebt.
  ///
  /// In en, this message translates to:
  /// **'Lock debts for staff'**
  String get adminLockDebt;

  /// No description provided for @permissionManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'PERMISSION MANAGEMENT'**
  String get permissionManagementTitle;

  /// No description provided for @noPermissionManagementScreen.
  ///
  /// In en, this message translates to:
  /// **'You do not have access\nto the permission management screen'**
  String get noPermissionManagementScreen;

  /// No description provided for @noStaffInShop.
  ///
  /// In en, this message translates to:
  /// **'No staff in this shop yet\nInvite staff via QR code first'**
  String get noStaffInShop;

  /// No description provided for @noEmailYet.
  ///
  /// In en, this message translates to:
  /// **'No email yet'**
  String get noEmailYet;

  /// No description provided for @noPhoneYet.
  ///
  /// In en, this message translates to:
  /// **'No phone yet'**
  String get noPhoneYet;

  /// No description provided for @phoneWithColon.
  ///
  /// In en, this message translates to:
  /// **'Phone:'**
  String get phoneWithColon;

  /// No description provided for @roleWithColon.
  ///
  /// In en, this message translates to:
  /// **'Role:'**
  String get roleWithColon;

  /// No description provided for @systemRoleSection.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM ROLE'**
  String get systemRoleSection;

  /// No description provided for @businessPermissionsSection.
  ///
  /// In en, this message translates to:
  /// **'BUSINESS CONTENT PERMISSIONS'**
  String get businessPermissionsSection;

  /// No description provided for @financePermissionsSection.
  ///
  /// In en, this message translates to:
  /// **'FINANCIAL CONTENT PERMISSIONS'**
  String get financePermissionsSection;

  /// No description provided for @systemPermissionsSection.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM MANAGEMENT PERMISSIONS'**
  String get systemPermissionsSection;

  /// No description provided for @permRowSales.
  ///
  /// In en, this message translates to:
  /// **'SALES'**
  String get permRowSales;

  /// No description provided for @permRowRepairs.
  ///
  /// In en, this message translates to:
  /// **'REPAIRS'**
  String get permRowRepairs;

  /// No description provided for @permRowInventory.
  ///
  /// In en, this message translates to:
  /// **'INVENTORY'**
  String get permRowInventory;

  /// No description provided for @permRowParts.
  ///
  /// In en, this message translates to:
  /// **'REPAIR PARTS'**
  String get permRowParts;

  /// No description provided for @permRowSuppliers.
  ///
  /// In en, this message translates to:
  /// **'SUPPLIERS'**
  String get permRowSuppliers;

  /// No description provided for @permRowCustomers.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMERS'**
  String get permRowCustomers;

  /// No description provided for @permRowWarranty.
  ///
  /// In en, this message translates to:
  /// **'WARRANTY'**
  String get permRowWarranty;

  /// No description provided for @permRowChat.
  ///
  /// In en, this message translates to:
  /// **'INTERNAL CHAT'**
  String get permRowChat;

  /// No description provided for @permRowAttendance.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE'**
  String get permRowAttendance;

  /// No description provided for @permRowPrinter.
  ///
  /// In en, this message translates to:
  /// **'PRINTER CONFIG'**
  String get permRowPrinter;

  /// No description provided for @permRowRevenue.
  ///
  /// In en, this message translates to:
  /// **'REVENUE & PROFIT/LOSS'**
  String get permRowRevenue;

  /// No description provided for @permRowExpenses.
  ///
  /// In en, this message translates to:
  /// **'SHOP EXPENSES'**
  String get permRowExpenses;

  /// No description provided for @permRowDebts.
  ///
  /// In en, this message translates to:
  /// **'DEBT LEDGER'**
  String get permRowDebts;

  /// No description provided for @permRowCostPrice.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT COST PRICE'**
  String get permRowCostPrice;

  /// No description provided for @permRowManageStaff.
  ///
  /// In en, this message translates to:
  /// **'MANAGE STAFF'**
  String get permRowManageStaff;

  /// No description provided for @permRowSettings.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM SETTINGS'**
  String get permRowSettings;

  /// No description provided for @updatedPermissionMsg.
  ///
  /// In en, this message translates to:
  /// **'Updated permission: {permission}'**
  String updatedPermissionMsg(String permission);

  /// No description provided for @errorUpdatingPermission.
  ///
  /// In en, this message translates to:
  /// **'Error updating permission: {error}'**
  String errorUpdatingPermission(String error);

  /// No description provided for @updatedRoleMsg.
  ///
  /// In en, this message translates to:
  /// **'Updated role to {role}'**
  String updatedRoleMsg(String role);

  /// No description provided for @errorUpdatingRole.
  ///
  /// In en, this message translates to:
  /// **'Error updating role: {error}'**
  String errorUpdatingRole(String error);

  /// No description provided for @notifSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notifSettingsTitle;

  /// No description provided for @importantNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'IMPORTANT NOTIFICATIONS'**
  String get importantNotificationsSection;

  /// No description provided for @otherNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'OTHER NOTIFICATIONS'**
  String get otherNotificationsSection;

  /// No description provided for @newOrderNotif.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get newOrderNotif;

  /// No description provided for @newOrderNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify when a customer creates a new order'**
  String get newOrderNotifDesc;

  /// No description provided for @paymentNotif.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentNotif;

  /// No description provided for @paymentNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify when a payment is successful'**
  String get paymentNotifDesc;

  /// No description provided for @inventoryNotif.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryNotif;

  /// No description provided for @inventoryNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Alert when a product is running low'**
  String get inventoryNotifDesc;

  /// No description provided for @staffNotif.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffNotif;

  /// No description provided for @staffNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Notifications about staff activity'**
  String get staffNotifDesc;

  /// No description provided for @systemNotif.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemNotif;

  /// No description provided for @systemNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'System update and maintenance notifications'**
  String get systemNotifDesc;

  /// No description provided for @notifPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get notifPermissionTitle;

  /// No description provided for @notifPermissionOk.
  ///
  /// In en, this message translates to:
  /// **'Permission OK'**
  String get notifPermissionOk;

  /// No description provided for @notifPermissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Not granted'**
  String get notifPermissionNotGranted;

  /// No description provided for @notifTokenOk.
  ///
  /// In en, this message translates to:
  /// **'Token OK'**
  String get notifTokenOk;

  /// No description provided for @notifTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'No token'**
  String get notifTokenMissing;

  /// No description provided for @notifFullyWorking.
  ///
  /// In en, this message translates to:
  /// **'Notification permission granted. You will receive push notifications.'**
  String get notifFullyWorking;

  /// No description provided for @notifNeedPermission.
  ///
  /// In en, this message translates to:
  /// **'Notification permission required to receive push notifications.'**
  String get notifNeedPermission;

  /// No description provided for @notifNeedPermissionIos.
  ///
  /// In en, this message translates to:
  /// **'Notification permission required to receive push notifications.\nIf already enabled in iOS Settings, tap \"Refresh FCM Token\".'**
  String get notifNeedPermissionIos;

  /// No description provided for @notifPermissionButNoToken.
  ///
  /// In en, this message translates to:
  /// **'Permission granted but no FCM Token. Tap \"Refresh FCM Token\" below.'**
  String get notifPermissionButNoToken;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get grantPermission;

  /// No description provided for @yourRoleColon.
  ///
  /// In en, this message translates to:
  /// **'Your role:'**
  String get yourRoleColon;

  /// No description provided for @roleBasedNotifNote.
  ///
  /// In en, this message translates to:
  /// **'Some notification types are only available for specific roles to ensure security and avoid spam.'**
  String get roleBasedNotifNote;

  /// No description provided for @notifUnavailableForRole.
  ///
  /// In en, this message translates to:
  /// **'Not available for current role'**
  String get notifUnavailableForRole;

  /// No description provided for @refreshFcmTokenBtn.
  ///
  /// In en, this message translates to:
  /// **'REFRESH FCM TOKEN'**
  String get refreshFcmTokenBtn;

  /// No description provided for @sendTestNotifBtn.
  ///
  /// In en, this message translates to:
  /// **'SEND TEST NOTIFICATION'**
  String get sendTestNotifBtn;

  /// No description provided for @notifGrantPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant notification permission'**
  String get notifGrantPermissionTitle;

  /// No description provided for @notifGrantPermissionContent.
  ///
  /// In en, this message translates to:
  /// **'The app needs notification permission to send important notifications. Please enable permission in system settings.'**
  String get notifGrantPermissionContent;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @notifEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get notifEnabled;

  /// No description provided for @notifDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled'**
  String get notifDisabled;

  /// No description provided for @notifPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Notification permission granted!'**
  String get notifPermissionGranted;

  /// No description provided for @notifPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permission required to receive notifications'**
  String get notifPermissionNeeded;

  /// No description provided for @testNotifContent.
  ///
  /// In en, this message translates to:
  /// **'This is a test notification from the push notification system. If you see this notification, the system is working normally!'**
  String get testNotifContent;

  /// No description provided for @testNotifSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent!'**
  String get testNotifSent;

  /// No description provided for @notifSendError.
  ///
  /// In en, this message translates to:
  /// **'Error sending notification: {error}'**
  String notifSendError(String error);

  /// No description provided for @refreshingFcmTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Refreshing FCM token...'**
  String get refreshingFcmTokenLabel;

  /// No description provided for @refreshTokenSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ FCM token refreshed successfully!'**
  String get refreshTokenSuccess;

  /// No description provided for @refreshTokenFailed.
  ///
  /// In en, this message translates to:
  /// **'❌ Unable to refresh FCM token. Try again later.'**
  String get refreshTokenFailed;

  /// No description provided for @refreshTokenError.
  ///
  /// In en, this message translates to:
  /// **'Error refreshing token: {error}'**
  String refreshTokenError(String error);

  /// No description provided for @notifInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATION INFO'**
  String get notifInfoTitle;

  /// No description provided for @notifInfoContent.
  ///
  /// In en, this message translates to:
  /// **'• Notifications are sent based on your role\n• Admin & Owner receive all notifications\n• Manager & Technician receive important notifications\n• Employee receives personal notifications only'**
  String get notifInfoContent;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestoreTitle;

  /// No description provided for @sqliteTabLabel.
  ///
  /// In en, this message translates to:
  /// **'SQLite (.db file)'**
  String get sqliteTabLabel;

  /// No description provided for @firestoreTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Firestore (cloud)'**
  String get firestoreTabLabel;

  /// No description provided for @backupSqliteSection.
  ///
  /// In en, this message translates to:
  /// **'Backup SQLite'**
  String get backupSqliteSection;

  /// No description provided for @shareOrSaveLocal.
  ///
  /// In en, this message translates to:
  /// **'Share / Save to device'**
  String get shareOrSaveLocal;

  /// No description provided for @backupToCloudLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup to Cloud'**
  String get backupToCloudLabel;

  /// No description provided for @cloudSqliteBackupsSection.
  ///
  /// In en, this message translates to:
  /// **'SQLite Cloud Backups'**
  String get cloudSqliteBackupsSection;

  /// No description provided for @noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No backups yet.'**
  String get noBackupsYet;

  /// No description provided for @restoreFromFileSection.
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get restoreFromFileSection;

  /// No description provided for @selectDbFileDesc.
  ///
  /// In en, this message translates to:
  /// **'Select a previously backed-up .db file to restore.'**
  String get selectDbFileDesc;

  /// No description provided for @selectDbFile.
  ///
  /// In en, this message translates to:
  /// **'Select .db file'**
  String get selectDbFile;

  /// No description provided for @backupSqliteSuccess.
  ///
  /// In en, this message translates to:
  /// **'SQLite backup to Cloud successful!'**
  String get backupSqliteSuccess;

  /// No description provided for @restoreSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore successful'**
  String get restoreSuccessTitle;

  /// No description provided for @restoreSuccessContent.
  ///
  /// In en, this message translates to:
  /// **'Data restored. Please restart the app to apply changes.'**
  String get restoreSuccessContent;

  /// No description provided for @firestoreInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Firestore backup saves each collection as a separate JSON file. You can choose which items to backup or restore.'**
  String get firestoreInfoCard;

  /// No description provided for @backupFirestoreSection.
  ///
  /// In en, this message translates to:
  /// **'Backup Firestore'**
  String get backupFirestoreSection;

  /// No description provided for @selectAndBackupToCloud.
  ///
  /// In en, this message translates to:
  /// **'Select items & Backup to Cloud'**
  String get selectAndBackupToCloud;

  /// No description provided for @firestoreBackupsSection.
  ///
  /// In en, this message translates to:
  /// **'Firestore Backups'**
  String get firestoreBackupsSection;

  /// No description provided for @noFirestoreBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No Firestore backups yet.'**
  String get noFirestoreBackupsYet;

  /// No description provided for @preparingBackup.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparingBackup;

  /// No description provided for @backupFirestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Firestore backup successful ({count} items)!'**
  String backupFirestoreSuccess(int count);

  /// No description provided for @restoreFirestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore successful ({count} items)!'**
  String restoreFirestoreSuccess(int count);

  /// No description provided for @deleteBackupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup deleted.'**
  String get deleteBackupSuccess;

  /// No description provided for @confirmRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm restore'**
  String get confirmRestoreTitle;

  /// No description provided for @confirmRestoreContent.
  ///
  /// In en, this message translates to:
  /// **'Current data of {count} items will be overwritten by the backup from {date}.\n\nContinue?'**
  String confirmRestoreContent(int count, String date);

  /// No description provided for @deleteBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete backup?'**
  String get deleteBackupTitle;

  /// No description provided for @deleteBackupContent.
  ///
  /// In en, this message translates to:
  /// **'Delete backup from {date}?'**
  String deleteBackupContent(String date);

  /// No description provided for @restoringSqliteFromCloud.
  ///
  /// In en, this message translates to:
  /// **'SQLite cloud restore is under development.'**
  String get restoringSqliteFromCloud;

  /// No description provided for @notInBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Not in this backup'**
  String get notInBackupLabel;

  /// No description provided for @storageRulesNeeded.
  ///
  /// In en, this message translates to:
  /// **'Firebase Storage Rules configuration required'**
  String get storageRulesNeeded;

  /// No description provided for @restoreBtn.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreBtn;

  /// No description provided for @selectDataToBackup.
  ///
  /// In en, this message translates to:
  /// **'Select data to backup'**
  String get selectDataToBackup;

  /// No description provided for @selectDataToRestore.
  ///
  /// In en, this message translates to:
  /// **'Select data to restore'**
  String get selectDataToRestore;

  /// No description provided for @backupConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupConfirmLabel;

  /// No description provided for @restoreConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreConfirmLabel;

  /// No description provided for @selectedCountItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items selected'**
  String selectedCountItems(int count);

  /// No description provided for @backupLabelWithCount.
  ///
  /// In en, this message translates to:
  /// **'Backup ({count})'**
  String backupLabelWithCount(int count);

  /// No description provided for @restoreLabelWithCount.
  ///
  /// In en, this message translates to:
  /// **'Restore ({count})'**
  String restoreLabelWithCount(int count);

  /// Search hint in sale list with dynamic product and code labels
  ///
  /// In en, this message translates to:
  /// **'Search by customer, {productLabel} or {codeLabel}...'**
  String saleListSearchHint(String productLabel, String codeLabel);

  /// Title for the first-time guide on the sale list screen
  ///
  /// In en, this message translates to:
  /// **'Sales History'**
  String get saleListGuideTitle;

  /// Step 1 title in sale list guide
  ///
  /// In en, this message translates to:
  /// **'🛒 Invoice list'**
  String get saleListGuide1Title;

  /// Step 1 description in sale list guide
  ///
  /// In en, this message translates to:
  /// **'View all sale invoices by day/week/month. Total revenue is shown at the top.'**
  String get saleListGuide1Desc;

  /// Step 2 title in sale list guide
  ///
  /// In en, this message translates to:
  /// **'🔍 Search'**
  String get saleListGuide2Title;

  /// Step 2 description in sale list guide
  ///
  /// In en, this message translates to:
  /// **'Find invoices by customer name, product name or invoice code.'**
  String get saleListGuide2Desc;

  /// Step 3 title in sale list guide
  ///
  /// In en, this message translates to:
  /// **'📄 View details & reprint'**
  String get saleListGuide3Title;

  /// Step 3 description in sale list guide
  ///
  /// In en, this message translates to:
  /// **'Tap an invoice to view details, reprint the receipt or create a return.'**
  String get saleListGuide3Desc;

  /// Step 4 title in sale list guide
  ///
  /// In en, this message translates to:
  /// **'💳 Payment status'**
  String get saleListGuide4Title;

  /// Step 4 description in sale list guide
  ///
  /// In en, this message translates to:
  /// **'Instantly see which invoices are paid, pending or on credit.'**
  String get saleListGuide4Desc;

  /// Title of the filter bottom sheet on the sale list screen
  ///
  /// In en, this message translates to:
  /// **'FILTER'**
  String get saleListFilterTitle;

  /// Section header for time filter in sale list
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get saleListTimeSection;

  /// Section header for payment status filter in sale list
  ///
  /// In en, this message translates to:
  /// **'PAYMENT STATUS'**
  String get saleListPaymentStatusSection;

  /// Filter chip label for last 7 days in sale list
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get saleListLast7Days;

  /// Filter chip label for custom date range in sale list
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get saleListCustomDate;

  /// Payment status filter chip: paid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get saleListFilterPaid;

  /// Payment status filter chip: has debt
  ///
  /// In en, this message translates to:
  /// **'Has debt'**
  String get saleListFilterDebt;

  /// Payment status filter chip: installment pending bank settlement
  ///
  /// In en, this message translates to:
  /// **'Install. pending'**
  String get saleListFilterBankPending;

  /// Payment status filter chip: installment bank settlement received
  ///
  /// In en, this message translates to:
  /// **'Install. received'**
  String get saleListFilterBankReceived;

  /// Label for yesterday in date group header
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get saleListDayYesterday;

  /// Title for the export date filter dialog on sale list
  ///
  /// In en, this message translates to:
  /// **'Export sale orders'**
  String get saleListExportOrders;

  /// Tooltip for the sort button on sale list
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get saleListSortTooltip;

  /// Sort option: newest first
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get saleListSortNewest;

  /// Sort option: highest sale value first
  ///
  /// In en, this message translates to:
  /// **'Highest value'**
  String get saleListSortHighestValue;

  /// Sort option: most debt first
  ///
  /// In en, this message translates to:
  /// **'Most debt'**
  String get saleListSortMostDebt;

  /// Revenue label in summary bar
  ///
  /// In en, this message translates to:
  /// **'Rev: {amount}'**
  String saleListRevenueShort(String amount);

  /// Debt label in summary bar
  ///
  /// In en, this message translates to:
  /// **'Debt: {amount}'**
  String saleListDebtShort(String amount);

  /// Profit label in summary bar
  ///
  /// In en, this message translates to:
  /// **'Profit: {amount}'**
  String saleListProfitShort(String amount);

  /// Status badge text when sale is fully returned
  ///
  /// In en, this message translates to:
  /// **'RETURNED'**
  String get saleListStatusReturned;

  /// Status badge text when installment is pending bank settlement
  ///
  /// In en, this message translates to:
  /// **'BANK PENDING'**
  String get saleListStatusBankPending;

  /// Status badge text when payment is fully collected
  ///
  /// In en, this message translates to:
  /// **'COLLECTED'**
  String get saleListStatusCollected;

  /// Status badge text when sale still has remaining debt
  ///
  /// In en, this message translates to:
  /// **'HAS DEBT'**
  String get saleListStatusHasDebt;

  /// Label for collected amount chip in sale card
  ///
  /// In en, this message translates to:
  /// **'💰 Collected'**
  String get saleListChipPaid;

  /// Label for remaining debt chip in sale card
  ///
  /// In en, this message translates to:
  /// **'⚠️ Has debt'**
  String get saleListChipDebt;

  /// Label for sale price chip in sale card
  ///
  /// In en, this message translates to:
  /// **'🏷 Sale'**
  String get saleListChipSale;

  /// Label for cost price chip in sale card
  ///
  /// In en, this message translates to:
  /// **'📦 Cost'**
  String get saleListChipCost;

  /// Label for profit chip in sale card
  ///
  /// In en, this message translates to:
  /// **'📈 Profit'**
  String get saleListChipProfit;

  /// Label for loss chip in sale card
  ///
  /// In en, this message translates to:
  /// **'📉 Loss'**
  String get saleListChipLoss;

  /// Label when sale order is fully returned
  ///
  /// In en, this message translates to:
  /// **'↩ Fully returned'**
  String get saleListReturnFull;

  /// Label when sale order is partially returned
  ///
  /// In en, this message translates to:
  /// **'↩ Partial return'**
  String get saleListReturnPartial;

  /// Label for installment chip in sale card
  ///
  /// In en, this message translates to:
  /// **'🏦 Installment'**
  String get saleListInstallmentLabel;

  /// Text shown when bank installment settlement has been received
  ///
  /// In en, this message translates to:
  /// **'Bank received {amount}'**
  String saleListBankReceivedAmount(String amount);

  /// Text shown when bank installment settlement has not been received
  ///
  /// In en, this message translates to:
  /// **'Bank not received yet'**
  String get saleListBankNotReceived;

  /// Hint text to long-press a sale card to create a return
  ///
  /// In en, this message translates to:
  /// **'Hold to create return'**
  String get saleListHoldToReturn;

  /// Empty state title when no sale orders match the current filter
  ///
  /// In en, this message translates to:
  /// **'No orders found'**
  String get saleListNoOrders;

  /// Empty state subtitle suggesting to clear filters
  ///
  /// In en, this message translates to:
  /// **'Try clearing filters to see all'**
  String get saleListClearFilterHint;

  /// Action button label to clear all active filters
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get saleListClearFilter;

  /// Footer text showing total number of displayed sale orders
  ///
  /// In en, this message translates to:
  /// **'Showing {count} sale orders'**
  String saleListDisplayedOrders(int count);

  /// Snackbar message when trying to return an already fully-returned order
  ///
  /// In en, this message translates to:
  /// **'This order has been fully returned'**
  String get saleListOrderFullyReturned;

  /// Return amount with count for partial returns
  ///
  /// In en, this message translates to:
  /// **'{amount} ({count} times)'**
  String saleListReturnTimesCount(String amount, int count);

  /// Day group header showing label and order count
  ///
  /// In en, this message translates to:
  /// **'{label} · {count} orders'**
  String saleListGroupOrdersCount(String label, int count);

  /// AppBar title for sale detail screen
  ///
  /// In en, this message translates to:
  /// **'SALE DETAILS'**
  String get saleDetailTitle;

  /// Snackbar when manager auth fails - not logged in
  ///
  /// In en, this message translates to:
  /// **'PLEASE LOGIN WITH MANAGER ACCOUNT'**
  String get needManagerLogin;

  /// Snackbar when user lacks manager permission
  ///
  /// In en, this message translates to:
  /// **'Only manager accounts can edit/delete'**
  String get onlyManagerCanEdit;

  /// Title for manager password dialog
  ///
  /// In en, this message translates to:
  /// **'MANAGER AUTHENTICATION'**
  String get managerAuthTitle;

  /// Label for manager password field
  ///
  /// In en, this message translates to:
  /// **'Manager password'**
  String get managerPasswordLabel;

  /// Snackbar after manager successfully reauthenticated
  ///
  /// In en, this message translates to:
  /// **'EDIT UNLOCKED'**
  String get editUnlocked;

  /// Snackbar when manager password is incorrect
  ///
  /// In en, this message translates to:
  /// **'Wrong manager password'**
  String get wrongManagerPassword;

  /// Snackbar when receipt print succeeds
  ///
  /// In en, this message translates to:
  /// **'Invoice printed successfully!'**
  String get printInvoiceSuccess;

  /// Snackbar when receipt print fails
  ///
  /// In en, this message translates to:
  /// **'Print failed! Please check printer settings.'**
  String get printInvoiceFailed;

  /// Snackbar when print throws an exception
  ///
  /// In en, this message translates to:
  /// **'Print error: {error}'**
  String printErrorMsg(String error);

  /// Title for settlement/bank-receive bottom sheet
  ///
  /// In en, this message translates to:
  /// **'RECEIVE BANK PAYMENT'**
  String get receiveBankTitle;

  /// Label for settlement amount field
  ///
  /// In en, this message translates to:
  /// **'Amount received (VND)'**
  String get receivedAmountLabel;

  /// fieldName used in validateAmount for settlement
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get receivedAmountField;

  /// Label for bank fee field in settlement sheet
  ///
  /// In en, this message translates to:
  /// **'Bank fee withheld (VND)'**
  String get bankFeeLabel;

  /// fieldName used in validateAmount for bank fee
  ///
  /// In en, this message translates to:
  /// **'Bank fee'**
  String get bankFeeField;

  /// Snackbar after bank settlement is saved
  ///
  /// In en, this message translates to:
  /// **'BANK PAYMENT RECORDED'**
  String get bankReceivedConfirmed;

  /// Title for edit sale dialog
  ///
  /// In en, this message translates to:
  /// **'EDIT SALE ORDER'**
  String get editSaleTitle;

  /// Label for customer name in edit sale dialog
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerNameFieldLabel;

  /// Validation message when customer name is empty
  ///
  /// In en, this message translates to:
  /// **'Enter customer name'**
  String get enterCustomerNameHint;

  /// Label for phone field in edit sale dialog
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneFieldLabel;

  /// Label for address field in edit sale dialog
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressFieldLabel;

  /// Label for payment method dropdown
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodFieldLabel;

  /// Label for notes text field
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesFieldLabel;

  /// Save button label in dialogs
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get saveLabel;

  /// Snackbar after sale is edited and saved
  ///
  /// In en, this message translates to:
  /// **'Sale order updated successfully'**
  String get saleUpdated;

  /// Title for delete-sale confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'DELETE SALE ORDER'**
  String get deleteSaleTitle;

  /// Shows product names of the sale order being deleted
  ///
  /// In en, this message translates to:
  /// **'Order: {name}'**
  String saleOrderItem(String name);

  /// Shows sale order value in delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Value: {amount}đ'**
  String saleOrderValue(String amount);

  /// Header for auto-action list in delete confirmation
  ///
  /// In en, this message translates to:
  /// **'The system will automatically:'**
  String get systemWillAutoLabel;

  /// Auto-action: restore inventory when sale deleted
  ///
  /// In en, this message translates to:
  /// **'Restore stock quantity'**
  String get restoreStockQty;

  /// Auto-action: remove linked debt record
  ///
  /// In en, this message translates to:
  /// **'Delete related debt'**
  String get deleteLinkedDebt;

  /// Auto-action: remove payment intent
  ///
  /// In en, this message translates to:
  /// **'Delete payment record'**
  String get deletePaymentRecord;

  /// Auto-action: revert customer total spent
  ///
  /// In en, this message translates to:
  /// **'Update customer spending'**
  String get updateCustomerSpend;

  /// Warning text in delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'⚠️ This action cannot be undone!'**
  String get cannotUndoWarning;

  /// Confirm delete button in delete sale dialog
  ///
  /// In en, this message translates to:
  /// **'DELETE ORDER'**
  String get deleteSaleButton;

  /// Snackbar after sale deleted with optional inventory/debt info appended
  ///
  /// In en, this message translates to:
  /// **'Sale deleted{inventoryInfo}{debtInfo}'**
  String saleDeletedMsg(String inventoryInfo, String debtInfo);

  /// Snackbar when deleting sale fails
  ///
  /// In en, this message translates to:
  /// **'Error deleting sale order: {error}'**
  String saleDeleteError(String error);

  /// Tooltip for the edit icon button in AppBar
  ///
  /// In en, this message translates to:
  /// **'Edit order info'**
  String get editSaleTooltip;

  /// Bottom action label for invoice preview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewInvoiceLabel;

  /// Bottom action label for print button
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printInvoiceLabel;

  /// Bottom action label when all items are returned
  ///
  /// In en, this message translates to:
  /// **'Fully returned'**
  String get returnAllLabel;

  /// Bottom action label to initiate a return
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnGoodsLabel;

  /// Snackbar after sales return is created
  ///
  /// In en, this message translates to:
  /// **'Return processed successfully!'**
  String get returnSuccessMsg;

  /// Bottom action label for invoice template
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get printTemplateLabel;

  /// Button label when settlement has been partially received
  ///
  /// In en, this message translates to:
  /// **'UPDATE SETTLEMENT (remaining {amount})'**
  String updateSettlementBtn(String amount);

  /// Return indicator when all items returned
  ///
  /// In en, this message translates to:
  /// **'FULLY RETURNED — {amount}'**
  String returnedFullLabel(String amount);

  /// Return indicator when partially returned
  ///
  /// In en, this message translates to:
  /// **'PARTIALLY RETURNED — {amount} ({count} times)'**
  String returnedPartialLabel(String amount, int count);

  /// Card header for the main transaction section
  ///
  /// In en, this message translates to:
  /// **'TRANSACTION'**
  String get sectionTransaction;

  /// Row label: customer address
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get itemAddress;

  /// Tooltip on clickable product list
  ///
  /// In en, this message translates to:
  /// **'Open product detail from sale'**
  String get openProductDetailTooltip;

  /// Row label: warranty period
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get itemWarranty;

  /// Row label: sale date and time
  ///
  /// In en, this message translates to:
  /// **'Date/Time'**
  String get itemTime;

  /// Row label: payment method
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get itemPaymentMethod;

  /// Row label: cash portion in combined payment
  ///
  /// In en, this message translates to:
  /// **'💵 Cash'**
  String get itemCash;

  /// Row label: bank transfer portion in combined payment
  ///
  /// In en, this message translates to:
  /// **'🏦 Transfer'**
  String get itemTransfer;

  /// Row label: order notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get itemNotes;

  /// Row label: discount amount
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get itemDiscount;

  /// Row label: total (final price)
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get itemTotal;

  /// Row label: product cost (visible to managers)
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get itemCostPrice;

  /// Row label: profit (final - cost)
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get itemProfit;

  /// Card header for bank installment section
  ///
  /// In en, this message translates to:
  /// **'INSTALLMENT - BANK'**
  String get sectionInstallment;

  /// Row label: down payment
  ///
  /// In en, this message translates to:
  /// **'Down payment'**
  String get installmentDownPayment;

  /// Row label: bank 1 name
  ///
  /// In en, this message translates to:
  /// **'Bank 1 disbursement'**
  String get installmentBank1;

  /// Row label: bank 1 loan amount
  ///
  /// In en, this message translates to:
  /// **'Bank 1 amount'**
  String get installmentAmount1;

  /// Row label: bank 2 name
  ///
  /// In en, this message translates to:
  /// **'Bank 2 disbursement'**
  String get installmentBank2;

  /// Row label: bank 2 loan amount
  ///
  /// In en, this message translates to:
  /// **'Bank 2 amount'**
  String get installmentAmount2;

  /// Row label: total loan from all banks
  ///
  /// In en, this message translates to:
  /// **'Total bank loan'**
  String get installmentTotalLoan;

  /// Row label: planned settlement date
  ///
  /// In en, this message translates to:
  /// **'Expected date'**
  String get installmentExpectedDate;

  /// Row label: settlement code/file number
  ///
  /// In en, this message translates to:
  /// **'File code'**
  String get installmentFileCode;

  /// Row label: settlement notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get installmentNotes;

  /// Row label: settlement status
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get installmentSettlement;

  /// Settlement status when nothing received yet
  ///
  /// In en, this message translates to:
  /// **'Not received'**
  String get settlementNotReceived;

  /// Settlement status when fully received
  ///
  /// In en, this message translates to:
  /// **'Received in full {date}'**
  String settlementFullyReceived(String date);

  /// Settlement status when partially received
  ///
  /// In en, this message translates to:
  /// **'Received {received} / {total}'**
  String settlementPartialReceived(String received, String total);

  /// Row label: bank fee deducted from settlement
  ///
  /// In en, this message translates to:
  /// **'Bank fee'**
  String get installmentBankFee;

  /// Row label: seller/staff name
  ///
  /// In en, this message translates to:
  /// **'Staff member'**
  String get staffItemLabel;

  /// Snackbar after sale is shared to group chat
  ///
  /// In en, this message translates to:
  /// **'SALE ORDER PINNED TO INTERNAL CHAT'**
  String get chatPinnedSale;

  /// Snackbar when trying to SMS but customer has no phone
  ///
  /// In en, this message translates to:
  /// **'NO CUSTOMER PHONE NUMBER'**
  String get noCustomerPhone;

  /// Snackbar after SMS app is launched successfully
  ///
  /// In en, this message translates to:
  /// **'SMS app opened (message already copied).'**
  String get smsAppOpened;

  /// Snackbar when SMS app cannot be launched
  ///
  /// In en, this message translates to:
  /// **'Cannot open SMS app. Please paste the message into Zalo/SMS.'**
  String get smsAppCannotOpen;

  /// Snackbar when SMS launch throws an exception
  ///
  /// In en, this message translates to:
  /// **'Error sending message, but content has been copied.'**
  String get smsSendError;

  /// Title for debt management screen
  ///
  /// In en, this message translates to:
  /// **'DEBT MANAGEMENT'**
  String get debtManagementTitle;

  /// Subtitle showing count of active debts
  ///
  /// In en, this message translates to:
  /// **'{count} active debts'**
  String activeDebtsCount(int count);

  /// Tab label for customer debts
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER'**
  String get tabCustomer;

  /// Tab label for supplier debts
  ///
  /// In en, this message translates to:
  /// **'SUPPLIER'**
  String get tabSupplier;

  /// Tab label for repair partner debts
  ///
  /// In en, this message translates to:
  /// **'PARTNER'**
  String get tabPartner;

  /// Tab label for other debts
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get tabOther;

  /// Tooltip for sync button
  ///
  /// In en, this message translates to:
  /// **'Sync with Firebase'**
  String get syncWithFirebase;

  /// Tooltip for export debt excel button
  ///
  /// In en, this message translates to:
  /// **'Export debt Excel'**
  String get exportExcelDebt;

  /// Title for export debt dialog
  ///
  /// In en, this message translates to:
  /// **'Export debts'**
  String get exportDebtTitle;

  /// Sync status: synced
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedStatus;

  /// Sync status: syncing
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncingStatus;

  /// Sync status: error
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get syncErrorStatus;

  /// Hint text for debt search field
  ///
  /// In en, this message translates to:
  /// **'Search name, phone...'**
  String get searchNamePhone;

  /// Filter chip label to show paid debts
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get filterPaid;

  /// Label for receivable debt (customer owes)
  ///
  /// In en, this message translates to:
  /// **'Receivable'**
  String get debtReceivable;

  /// Label for payable debt (shop owes)
  ///
  /// In en, this message translates to:
  /// **'Payable'**
  String get debtPayable;

  /// KPI chip label for overdue debts
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueDebts;

  /// KPI chip label for debts needing attention
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsHandling;

  /// Empty state when search finds nothing
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noDebtFound;

  /// Empty state when no debts exist
  ///
  /// In en, this message translates to:
  /// **'No debts yet'**
  String get noDebtYet;

  /// Hint when search has no results
  ///
  /// In en, this message translates to:
  /// **'Try searching by other name or phone'**
  String get trySearchOther;

  /// Hint to enable paid filter
  ///
  /// In en, this message translates to:
  /// **'Enable \"Paid\" to see history'**
  String get showPaidToSeeHistory;

  /// Summary header for total remaining debt
  ///
  /// In en, this message translates to:
  /// **'TOTAL REMAINING DEBT'**
  String get totalRemainingDebt;

  /// Empty state for partner debts tab
  ///
  /// In en, this message translates to:
  /// **'No partner debts'**
  String get noPartnerDebt;

  /// Guide for managing partners
  ///
  /// In en, this message translates to:
  /// **'Manage partners at: Settings › Partner Management'**
  String get partnerDebtManageGuide;

  /// Summary header for partner repair debt
  ///
  /// In en, this message translates to:
  /// **'TOTAL REPAIR PARTNER DEBT'**
  String get totalPartnerRepairDebt;

  /// Title of payment history bottom sheet
  ///
  /// In en, this message translates to:
  /// **'PAYMENT HISTORY'**
  String get paymentHistoryTitle;

  /// Empty state for payment history
  ///
  /// In en, this message translates to:
  /// **'No payment history yet'**
  String get noPaymentHistory;

  /// Button label to pay debt
  ///
  /// In en, this message translates to:
  /// **'PAY DEBT'**
  String get payDebtButton;

  /// Title for collecting customer debt
  ///
  /// In en, this message translates to:
  /// **'COLLECT CUSTOMER DEBT'**
  String get collectDebtTitle;

  /// Title for paying a debt
  ///
  /// In en, this message translates to:
  /// **'PAY DEBT'**
  String get payDebtTitle;

  /// Label for total debt amount
  ///
  /// In en, this message translates to:
  /// **'Total debt'**
  String get totalDebtLabel;

  /// Label for paid amount
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidAmountLabel;

  /// Label for remaining amount
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingLabel;

  /// Label for collect amount input
  ///
  /// In en, this message translates to:
  /// **'AMOUNT TO COLLECT (VND)'**
  String get collectAmountVnd;

  /// Label for pay amount input
  ///
  /// In en, this message translates to:
  /// **'AMOUNT TO PAY (VND)'**
  String get payAmountVnd;

  /// Label for payment method selection
  ///
  /// In en, this message translates to:
  /// **'PAY WITH'**
  String get payWithLabel;

  /// Confirm payment button
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get confirmPayButton;

  /// Title for creating other debt
  ///
  /// In en, this message translates to:
  /// **'CREATE OTHER DEBT'**
  String get createOtherDebtTitle;

  /// Label for debtor name field
  ///
  /// In en, this message translates to:
  /// **'Debtor name'**
  String get debtorNameLabel;

  /// Validation message for debtor name
  ///
  /// In en, this message translates to:
  /// **'Please enter debtor name'**
  String get pleaseEnterDebtorName;

  /// Label for debt amount field
  ///
  /// In en, this message translates to:
  /// **'Debt amount (VND)'**
  String get debtAmountVnd;

  /// Label for debt type selection
  ///
  /// In en, this message translates to:
  /// **'Debt type:'**
  String get debtFormTypeLabel;

  /// Debt type: receivable
  ///
  /// In en, this message translates to:
  /// **'RECEIVABLE'**
  String get receivableDebt;

  /// Debt type: payable
  ///
  /// In en, this message translates to:
  /// **'PAYABLE'**
  String get payableDebt;

  /// Subtitle for receivable debt type
  ///
  /// In en, this message translates to:
  /// **'(Customer owes shop)'**
  String get customerOwesShop;

  /// Subtitle for payable debt type
  ///
  /// In en, this message translates to:
  /// **'(Shop owes others)'**
  String get shopOwesOther;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get createButton;

  /// Snackbar after creating a debt
  ///
  /// In en, this message translates to:
  /// **'New debt created'**
  String get debtCreated;

  /// Title for creating receivable debt
  ///
  /// In en, this message translates to:
  /// **'CREATE RECEIVABLE DEBT'**
  String get createReceivableDebtTitle;

  /// Validation for customer name in debt form
  ///
  /// In en, this message translates to:
  /// **'Please enter customer name'**
  String get pleaseEnterCustomerNameDebt;

  /// Snackbar after creating customer debt
  ///
  /// In en, this message translates to:
  /// **'Customer debt created!'**
  String get customerDebtCreated;

  /// Error message when creating debt fails
  ///
  /// In en, this message translates to:
  /// **'Error creating debt: {error}'**
  String createDebtError(String error);

  /// Title for creating payable debt
  ///
  /// In en, this message translates to:
  /// **'CREATE PAYABLE DEBT'**
  String get createPayableDebtTitle;

  /// Label for supplier name field
  ///
  /// In en, this message translates to:
  /// **'Supplier name'**
  String get supplierNameLabel;

  /// Validation for supplier name in debt form
  ///
  /// In en, this message translates to:
  /// **'Please enter supplier name'**
  String get pleaseEnterSupplierNameDebt;

  /// Snackbar after creating supplier debt
  ///
  /// In en, this message translates to:
  /// **'Supplier debt created!'**
  String get supplierDebtCreated;

  /// Empty state when no other debts
  ///
  /// In en, this message translates to:
  /// **'No debts'**
  String get noDebtAnywhere;

  /// Button to collect customer debt
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get collectDebtAction;

  /// Button to pay a debt
  ///
  /// In en, this message translates to:
  /// **'Pay debt'**
  String get payDebtAction;

  /// Button to view debt history
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyButton;

  /// Button to repay a debt
  ///
  /// In en, this message translates to:
  /// **'Repay'**
  String get returnDebtAction;

  /// Chip label for repair partner debt type
  ///
  /// In en, this message translates to:
  /// **'Repair partner'**
  String get partnerRepairType;

  /// Source label: manual
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualSource;

  /// Source label: automatic
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get autoSource;

  /// Label for total fee amount
  ///
  /// In en, this message translates to:
  /// **'Total fee'**
  String get totalFeeLabel;

  /// Label for remaining debt amount
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingDebtLabel;

  /// Action button label to make payment
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get paymentAction;

  /// Urgency chip: very overdue count
  ///
  /// In en, this message translates to:
  /// **'{count} overdue >60 days'**
  String overdueCountDays(int count);

  /// Urgency chip: urgent count
  ///
  /// In en, this message translates to:
  /// **'{count} need attention >30 days'**
  String urgentCountDays(int count);

  /// Message when partner is missing but debt remains
  ///
  /// In en, this message translates to:
  /// **'Partner \"{name}\" is no longer in the system but the debt is kept.'**
  String partnerNotInSystem(String name);

  /// Message when partner cannot be found
  ///
  /// In en, this message translates to:
  /// **'Cannot find partner \"{name}\". Debt still appears in list.'**
  String partnerDebtNotFound(String name);

  /// Error when trying to pay debt on closed day
  ///
  /// In en, this message translates to:
  /// **'❌ Today is closed! Cannot collect debt payment.'**
  String get closedTodayDebt;

  /// Error when trying to create debt on closed day
  ///
  /// In en, this message translates to:
  /// **'❌ Today is closed! Cannot create new debt.'**
  String get closedTodayCreateDebt;

  /// FAB tooltip for customer tab
  ///
  /// In en, this message translates to:
  /// **'Create customer debt'**
  String get createCustomerDebtTooltip;

  /// FAB tooltip for supplier tab
  ///
  /// In en, this message translates to:
  /// **'Create supplier debt'**
  String get createSupplierDebtTooltip;

  /// FAB tooltip for other tab
  ///
  /// In en, this message translates to:
  /// **'Create other debt'**
  String get createOtherDebtTooltip;

  /// Tooltip for missing partner icon
  ///
  /// In en, this message translates to:
  /// **'Partner no longer in system'**
  String get partnerNotInSystemTooltip;

  /// Chip label for very overdue debt
  ///
  /// In en, this message translates to:
  /// **'Overdue {days} days'**
  String overdueDaysLabel(int days);

  /// Chip label for urgent debt days count
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String daysLabel(int days);

  /// Chip label when debt is fully paid
  ///
  /// In en, this message translates to:
  /// **'✓ Fully paid'**
  String get paidFullLabel;

  /// Badge showing number of repair orders
  ///
  /// In en, this message translates to:
  /// **'{count} orders'**
  String ordersCountLabel(int count);

  /// Title for expense management screen
  ///
  /// In en, this message translates to:
  /// **'EXPENSE MANAGEMENT'**
  String get expenseManagementTitle;

  /// Title for income management screen
  ///
  /// In en, this message translates to:
  /// **'INCOME'**
  String get incomeManagementTitle;

  /// Subtitle showing expense count
  ///
  /// In en, this message translates to:
  /// **'{count} expenses'**
  String expenseCountSubtitle(int count);

  /// Subtitle showing income count
  ///
  /// In en, this message translates to:
  /// **'{count} incomes'**
  String incomeCountSubtitle(int count);

  /// Tooltip for export income/expense excel
  ///
  /// In en, this message translates to:
  /// **'Export income/expense Excel'**
  String get exportExcelIncomeExpense;

  /// Title for export income/expense dialog
  ///
  /// In en, this message translates to:
  /// **'Export income/expense'**
  String get exportIncomeExpenseTitle;

  /// Title for delete income dialog
  ///
  /// In en, this message translates to:
  /// **'CONFIRM DELETE INCOME'**
  String get confirmDeleteIncome;

  /// Title for delete expense dialog
  ///
  /// In en, this message translates to:
  /// **'CONFIRM DELETE EXPENSE'**
  String get confirmDeleteExpenseTitle;

  /// Content for delete income confirmation
  ///
  /// In en, this message translates to:
  /// **'You are deleting income: {title}\nAmount: {amount}'**
  String deleteIncomeContent(String title, String amount);

  /// Content for delete expense confirmation
  ///
  /// In en, this message translates to:
  /// **'You are deleting expense: {title}\nAmount: {amount}'**
  String deleteExpenseContent(String title, String amount);

  /// Label for password field in delete dialog
  ///
  /// In en, this message translates to:
  /// **'Enter account password to delete'**
  String get enterPasswordToDeleteLabel;

  /// Button to confirm deletion
  ///
  /// In en, this message translates to:
  /// **'CONFIRM DELETE'**
  String get confirmDeleteButton;

  /// Error when trying to delete purchase expense
  ///
  /// In en, this message translates to:
  /// **'Cannot delete expense from purchase order!'**
  String get cannotDeletePurchaseExpense;

  /// Error when password is wrong during delete
  ///
  /// In en, this message translates to:
  /// **'Wrong password! Cannot delete.'**
  String get wrongPasswordCannotDelete;

  /// Snackbar after deleting income
  ///
  /// In en, this message translates to:
  /// **'Income deleted successfully'**
  String get deletedIncomeSuccess;

  /// Snackbar after deleting expense
  ///
  /// In en, this message translates to:
  /// **'Expense deleted successfully'**
  String get deletedExpenseSuccess;

  /// Error when adding expense on closed day
  ///
  /// In en, this message translates to:
  /// **'❌ Today is closed! Cannot add new expense.'**
  String get closedTodayExpense;

  /// Error when adding income on closed day
  ///
  /// In en, this message translates to:
  /// **'❌ Today is closed! Cannot add new income.'**
  String get closedTodayIncome;

  /// Title of add expense bottom sheet
  ///
  /// In en, this message translates to:
  /// **'RECORD EXPENSE'**
  String get writeExpensesTitle;

  /// Section label for expense category
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get categoryLabel;

  /// Label for expense content field
  ///
  /// In en, this message translates to:
  /// **'Expense description *'**
  String get expenseContentRequired;

  /// Validation message for expense content
  ///
  /// In en, this message translates to:
  /// **'Please enter expense description'**
  String get pleaseEnterExpenseContent;

  /// Label for amount field
  ///
  /// In en, this message translates to:
  /// **'Amount (VND) *'**
  String get amountVndRequired;

  /// Label for extra note field
  ///
  /// In en, this message translates to:
  /// **'Additional note'**
  String get extraNoteLabel;

  /// Section label for expense scope
  ///
  /// In en, this message translates to:
  /// **'EXPENSE SCOPE'**
  String get expenseScopeLabel;

  /// Button label to save expense
  ///
  /// In en, this message translates to:
  /// **'SAVE EXPENSE'**
  String get saveExpenseButton;

  /// Snackbar after saving expense
  ///
  /// In en, this message translates to:
  /// **'Expense saved!'**
  String get savedExpense;

  /// Title of add income bottom sheet
  ///
  /// In en, this message translates to:
  /// **'RECORD INCOME'**
  String get writeIncomeTitle;

  /// Label for income content field
  ///
  /// In en, this message translates to:
  /// **'Income description *'**
  String get incomeContentRequired;

  /// Validation message for income content
  ///
  /// In en, this message translates to:
  /// **'Please enter income description'**
  String get pleaseEnterIncomeContent;

  /// Section label for income scope
  ///
  /// In en, this message translates to:
  /// **'SCOPE'**
  String get incomeScopeLabel;

  /// Button label to save income
  ///
  /// In en, this message translates to:
  /// **'SAVE INCOME'**
  String get saveIncomeButton;

  /// Snackbar after saving income
  ///
  /// In en, this message translates to:
  /// **'Income saved!'**
  String get savedIncome;

  /// FAB label for adding expense
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get newExpenseFab;

  /// FAB label for adding income
  ///
  /// In en, this message translates to:
  /// **'New income'**
  String get newIncomeFab;

  /// Label for total income amount
  ///
  /// In en, this message translates to:
  /// **'Total income'**
  String get totalIncomeLabel;

  /// Label for total expense amount
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get totalExpenseLabel;

  /// Period label for today
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get todayPeriod;

  /// Period label for this week
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get thisWeekPeriod;

  /// Period label for this month
  ///
  /// In en, this message translates to:
  /// **'THIS MONTH'**
  String get thisMonthPeriod;

  /// Empty state for no expenses in period
  ///
  /// In en, this message translates to:
  /// **'No expenses in this {period}'**
  String noExpenseInPeriod(String period);

  /// Empty state for no income in period
  ///
  /// In en, this message translates to:
  /// **'No income in this {period}'**
  String noIncomeInPeriod(String period);

  /// Message when feature not available on web
  ///
  /// In en, this message translates to:
  /// **'This feature is not available on web browser.\nPlease use the mobile app.'**
  String get webNotAvailableMessage;

  /// Fallback label when no name available
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get noNameLabel;

  /// Error when trying to delete on a closed day
  ///
  /// In en, this message translates to:
  /// **'❌ Day {date} is closed! Cannot delete {label}.'**
  String closedDayCannotDelete(String date, String label);

  /// Label for income type (used in delete messages)
  ///
  /// In en, this message translates to:
  /// **'income'**
  String get incomeTypeLabel;

  /// Label for expense type (used in delete messages)
  ///
  /// In en, this message translates to:
  /// **'expense'**
  String get expenseTypeLabel;

  /// Generic no-permission message for a feature
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to access this feature.'**
  String get noPermissionFeature;

  /// Guide step 1 title for expense view
  ///
  /// In en, this message translates to:
  /// **'💸 Record Income & Expense'**
  String get expenseGuideStep1Title;

  /// Guide step 1 description for expense view
  ///
  /// In en, this message translates to:
  /// **'Record income beyond sales (INCOME) and operating expenses (EXPENSE) of the shop.'**
  String get expenseGuideStep1Desc;

  /// Guide step 2 title for expense view
  ///
  /// In en, this message translates to:
  /// **'📂 Categorize expenses'**
  String get expenseGuideStep2Title;

  /// Guide step 2 description for expense view
  ///
  /// In en, this message translates to:
  /// **'Distinguish shop expenses (electricity, water, rent) and personal expenses for accurate reporting.'**
  String get expenseGuideStep2Desc;

  /// Guide step 3 title for expense view
  ///
  /// In en, this message translates to:
  /// **'📅 Filter by time'**
  String get expenseGuideStep3Title;

  /// Guide step 3 description for expense view
  ///
  /// In en, this message translates to:
  /// **'View income/expense by day, week, or month to effectively control cash flow.'**
  String get expenseGuideStep3Desc;

  /// Guide step 4 title for expense view
  ///
  /// In en, this message translates to:
  /// **'📊 Summary chart'**
  String get expenseGuideStep4Title;

  /// Guide step 4 description for expense view
  ///
  /// In en, this message translates to:
  /// **'Track income/expense trends with visual charts, detect unusual expenses.'**
  String get expenseGuideStep4Desc;

  /// Category label: incidental expense/income
  ///
  /// In en, this message translates to:
  /// **'Incidental'**
  String get expenseCatIncidental;

  /// Category label: service income
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get expenseCatService;

  /// Category label: refund income
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get expenseCatRefund;

  /// Category label: fixed expense
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get expenseCatFixed;

  /// Category label: stock-in expense
  ///
  /// In en, this message translates to:
  /// **'Stock in'**
  String get expenseCatStockIn;

  /// Scope chip label: personal
  ///
  /// In en, this message translates to:
  /// **'PERSONAL'**
  String get expenseScopePersonal;

  /// Scope filter chip label: all
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get expenseScopeAll;

  /// Default partner name when actual name is unavailable
  ///
  /// In en, this message translates to:
  /// **'Partner {index}'**
  String debtPartnerDefaultName(int index);

  /// Generic error with message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String debtGenericError(String error);

  /// Generic error message for payment failure
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get debtPaymentGenericError;

  /// Title for debt management first-time guide
  ///
  /// In en, this message translates to:
  /// **'Debt Management'**
  String get debtGuideTitle;

  /// Guide step 1 title: 3 debt types
  ///
  /// In en, this message translates to:
  /// **'📊 3 debt types'**
  String get debtGuideStep1Title3Types;

  /// Guide step 1 title: 2 debt types
  ///
  /// In en, this message translates to:
  /// **'📊 2 debt types'**
  String get debtGuideStep1Title2Types;

  /// Guide step 1 description: 3 debt types
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER OWES (unpaid customers), SUPPLIER DEBT (owed to suppliers), PARTNER DEBT (external repair partners).'**
  String get debtGuideStep1Desc3Types;

  /// Guide step 1 description: 2 debt types
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER OWES (unpaid customers), SUPPLIER DEBT (owed to suppliers).'**
  String get debtGuideStep1Desc2Types;

  /// Guide step 2 title: record payment
  ///
  /// In en, this message translates to:
  /// **'💰 Record payment'**
  String get debtGuideStep2Title;

  /// Guide step 2 description
  ///
  /// In en, this message translates to:
  /// **'Tap on a debt to view details and record partial or full payment.'**
  String get debtGuideStep2Desc;

  /// Guide step 3 title: track due dates
  ///
  /// In en, this message translates to:
  /// **'📅 Track due dates'**
  String get debtGuideStep3Title;

  /// Guide step 3 description
  ///
  /// In en, this message translates to:
  /// **'Overdue debts are highlighted in red. Summary reports help track cash flow.'**
  String get debtGuideStep3Desc;

  /// Guide step 4 title: auto-create debts
  ///
  /// In en, this message translates to:
  /// **'🔄 Auto-create debts'**
  String get debtGuideStep4Title;

  /// Guide step 4 description
  ///
  /// In en, this message translates to:
  /// **'When selling/stocking and selecting "DEBT", the system automatically creates a corresponding debt record.'**
  String get debtGuideStep4Desc;

  /// Field name for collection amount validator
  ///
  /// In en, this message translates to:
  /// **'Collection amount'**
  String get debtCollectFieldName;

  /// Field name for payment amount validator
  ///
  /// In en, this message translates to:
  /// **'Payment amount'**
  String get debtPayFieldName;

  /// Field name for debt amount validator
  ///
  /// In en, this message translates to:
  /// **'Debt amount'**
  String get debtAmountFieldName;

  String get backupGroupOperations;
  String get backupGroupWarehouse;
  String get backupGroupFinance;
  String get backupGroupHr;
  String get backupGroupCrm;
  String get backupGroupSystem;
  String get backupColRepairs;
  String get backupColRepairParts;
  String get backupColRepairPartners;
  String get backupColPartnerHistory;
  String get backupColSales;
  String get backupColInventoryChecks;
  String get backupColCashClosings;
  String get backupColProducts;
  String get backupColSalvagePhones;
  String get backupColStorageLocations;
  String get backupColSuppliers;
  String get backupColPurchaseOrders;
  String get backupColImportOrders;
  String get backupColSupplierImportHistory;
  String get backupColQuickInputCodes;
  String get backupColDebts;
  String get backupColDebtPayments;
  String get backupColExpenses;
  String get backupColPaymentIntents;
  String get backupColPaymentRequests;
  String get backupColSupplierPayments;
  String get backupColRepairPartnerPayments;
  String get backupColAttendance;
  String get backupColPayrollSettings;
  String get backupColWorkSchedules;
  String get backupColCustomers;
  String get backupColChats;
  String get backupColAuditLogs;
  String get backupOptionsTooltip;
  String get backupOpenSqliteTab;
  String get backupOpenFirestoreTab;
  String get backupSqliteTabLabel;
  String get backupFirestoreTabLabel;
  String get backupGuideTitle;
  String get backupGuideStep1;
  String get backupGuideStep2;
  String get backupGuideStep3;
  String get backupGuideStep4;
  String get backupGuideStep5;
  String get backupRestoreBtn;
  String get backupRestoreOriginalBtn;
  String get backupTransferToCurrentShop;
  String get backupSaveToDevice;
  String get backupShareLatest;
  String get backupSelectAndBackup;
  String get backupSelectFile;
  String get backupSelectCustomItems;
  String get backupCleanOldBtn;
  String get backupUploadToCloud;
  String get backupBackupLabel;
  String get backupSqliteSectionTitle;
  String get backupLocalListTitle;
  String get backupQuickGuideTitle;
  String get backupCloudListTitle;
  String get backupRestoreFromFileTitle;
  String get backupDeleteSelectiveTitle;
  String get backupCleanOldTitle;
  String get backupFirestoreInfoText;
  String get backupRestoreByItemTitle;
  String get backupRestoreByItemDesc1;
  String get backupRestoreByItemDesc2;
  String get backupFirestoreSectionTitle;
  String get backupFirestoreListTitle;
  String get backupNoFirestoreBackups;
  String get backupProcessing;
  String backupSavedPathLabel(String fileName);
  String get backupNoLocalBackupsHint;
  String get backupNoCloudBackups;
  String get backupRestoreFileHint;
  String get backupDeleteSelectiveHint;
  String get backupCleanOldHint;
  String get backupQuickGuideOffline;
  String get backupQuickGuideShare;
  String get backupQuickGuideRestoreOffline;
  String get backupQuickGuideRestoreOnline;
  String backupCannotLoad(String error);
  String get backupSavedLocally;
  String backupExportError(String error);
  String backupShareFileError(String error);
  String backupDeletedLocalName(String name);
  String backupDeleteLocalError(String error);
  String get backupCloudSuccess;
  String get backupDeletedCloud;
  String backupRestoreErrorMsg(String error);
  String backupRestoreLocalErrorMsg(String error);
  String backupDeleteSuccessWithCloud(int localRows, int cloudRows, String label);
  String backupDeleteSuccessLocalOnly(int localRows, String label);
  String backupDeleteErrorMsg(String error);
  String backupFirestoreError(String error);
  String backupRestoreSuccessMsg(int count);
  String backupRestoreFirestoreError(String error);
  String get backupDeletedSet;
  String backupDeleteSetErrorMsg(String error);
  String backupNoOldFiles(int days);
  String backupDeletedOldFiles(int count, int days);
  String backupCleanError(String error);
  String get backupDeleteLocalTitle;
  String backupDeleteLocalContent(String name);
  String get backupDeleteCloudTitle;
  String get backupChooseRestoreType;
  String get backupRestoreOriginalDesc;
  String get backupRestoreCloudTitle;
  String backupRestoreCloudContent(String fileName);
  String get backupChooseRestoreTypeTip;
  String get backupSelectDataSqlite;
  String get backupRestoreSuccessTitle;
  String backupRestoredWithTransfer(int count);
  String backupRestoredNoTransfer(int count);
  String backupRestoredCloudWithTransfer(int count);
  String backupRestoredCloudNoTransfer(int count);
  String backupDeleteWarningTitle(String label);
  String get backupDeleteWarningContent;
  String get backupDeleteCloudTooLabel;
  String get backupDeleteCloudTooSubtitle;
  String get backupDeleteForever;
  String get backupSelectDataToDelete;
  String get backupKeepDaysTitle;
  String get backupKeep30Days;
  String get backupKeep60Days;
  String get backupKeep90Days;
  String get backupKeep180Days;
  String get backupLocalRestoreTitle;
  String get backupLocalRestoreContent;
  String backupRestoredLocalWithTransfer(int count);
  String backupRestoredLocalNoTransfer(int count);
  String backupConfirmRestoreContent(int count, String date);
  String get backupDeleteSetTitle;
  String backupDeleteSetContent(String date);
  String get backupPreparingMsg;
  String backupBackingUpItem(String item, int done, int total);
  String get backupRestoringMsg;
  String get backupSelectDataBackup;
  String backupSelectedCountLabel(int count);
  String get backupNotAvailable;
  String get backupStorageRulesTitle;
  String backupCloudPermissionError(String action);
  String backupCloudNotFoundError(String action);
  String backupCloudAuthError(String action);
  String backupCloudGenericError(String action, String error);
  String get backupPresetInventoryCash;
  String get backupPresetAccessoriesProducts;
  String get backupPresetRepairParts;
  String get backupPresetSupplierImport;
  String get backupPresetPayments;
  String get backupPresetOther;
  String get backupPresetHr;
  String get backupPresetSystemLog;

  /// Title for the confirm-restore dialog in backup/restore view
  ///
  /// In en, this message translates to:
  /// **'Confirm restore'**
  String get backupConfirmRestoreTitle;

  // Inventory view keys
  String get inventoryManageTitle;
  String get inventoryManageTotalTitle;
  String get inventoryNoAccessMsg;
  String inventoryUnsyncedNote(int count);
  String get inventoryInStockLabel;
  String get inventoryTempStockLabel;
  String get inventoryTempStockBanner;
  String inventoryExpectedSupplier(String supplier);
  String get inventoryStockQty;
  String get inventoryPurchasePrice;
  String get inventorySalePriceItem;
  String get inventoryLoss;
  String get inventoryCapacityLabel;
  String get inventorySizeLabel;
  String get inventorySupplierLabel;
  String get inventoryPendingConfirm;
  String get inventoryWaitingConfirm;
  String get inventoryWarehouseLocation;
  String get inventoryLastUpdated;
  String get inventoryRepairHistorySection;
  String get inventoryConfirmPriceBtn;
  String get inventoryPrintingLabelMsg;
  String get inventoryPrintLabelSuccess;
  String get inventoryPrintLabelError;
  String get inventoryPrintLabelAction;
  String get inventoryEditAction;
  String get inventorySellAction;
  String inventoryStockMoreAction(int count);
  String get inventoryDeleteAction;
  String get inventoryRestockTitle;
  String inventoryCurrentStockNote(int qty);
  String inventoryCurrentCostNote(String price);
  String get inventoryRestockQtyLabel;
  String get inventoryRestockPriceLabel;
  String inventoryWeightedCostNote(String price);
  String get inventoryPaymentMethodLabel;
  String get inventoryCashOption;
  String get inventoryBankTransferOption;
  String get inventoryDebtOption;
  String get inventoryStockInAction;
  String get inventoryValidQtyError;
  String get inventoryValidPriceError;
  String get inventoryStockingIn;
  String get inventoryNoSupplierFoundError;
  String get inventoryCreateEntryError;
  String inventoryStockInSuccess(int qty, String name);
  String get inventoryConfirmEntryError;
  String inventoryErrorMsg(String error);
  String get inventoryEditOption;
  String get inventoryHideOption;
  String inventoryCostPriceNote(String price);
  String get inventorySoftDeleteWarning;
  String get inventorySoftDeleteDesc;
  String get inventoryDeleteReasonLabel;
  String get inventoryDeleteReasonHint;
  String get inventoryAccountPassword;
  String get inventoryEnterPasswordError;
  String get inventoryWrongPasswordError;
  String get inventoryHideFromWarehouse;
  String inventoryHideSuccess(String product, String name);
  String inventoryHideError(String product, String error);
  String get inventoryEmptyFiltered;
  String get inventoryEmptyAll;
  String get inventoryEmptyFilteredSub;
  String get inventoryEmptyOutOfStockSub;
  String get inventoryConfirmDeleteTitle;
  String inventoryConfirmDeleteContent(int count);
  String get inventoryEnterPasswordToDelete;
  String get inventoryAccountPasswordLabel;
  String get inventoryDeleteNow;
  String get inventoryAddPartTooltip;
  String get inventoryStockInAITooltip;
  String get inventoryStockInTooltip;
  String inventorySearchWithQuery(String query);
  String get inventoryMoreTooltip;
  String get inventoryStorageLocationMenu;
  String get inventoryPrintLabelsMenu;
  String inventorySelectedCount(int count);
  String inventoryShownCount(int count, String product);
  String get inventoryDisplayOrTotal;
  String get inventoryTotalLabel;
  String get inventoryCapitalLabel;
  String get inventoryLocationFilter;
  String get inventoryOutOfStockFilter;
  String get inventoryNoLocationMsg;
  String get inventoryFilterByLocation;
  String get inventoryAllFilter;
  String get inventoryStatusPending;
  String get inventoryStatusLowStock;
  String get inventoryWaitingPrice;
  String get inventoryRemainingLabel;
  String get inventoryConfirmCostTitle;
  String get inventoryValidCostError;
  String get inventorySelectSupplierError;
  String get inventoryConfirmCostSuccess;
  String get inventorySelectSupplierFirst;
  String get inventoryCostChangeTitle;
  String get inventoryCostChangeMessage;
  String get inventoryUpdateSuccess;
  String get inventoryProductTypeLocked;
  String get inventoryBrandField;
  String get inventoryModelField;
  String get inventoryCapacityField;
  String get inventorySizeField;
  String get inventoryColorField;
  String get inventoryConditionField;
  String get inventoryLabelInfoField;
  String get inventoryNoteHint;
  String get inventoryCostLockedField;
  String get inventoryCostField;
  String get inventoryPriceField;
  String get inventoryExpiry;
  String get inventoryChooseExpiry;
  String get inventoryExpiryLabel;
  String get inventoryNotChosen;
  String get inventoryBatchField;
  String get inventoryPhotoSection;
  String get inventoryQtyLockedField;
  String get inventorySupplierLockedField;
  String get inventoryNoSupplier;
  String get inventoryRestockBtn;
  String get inventoryUpdateAction;
  String get inventoryStatusReceived;
  String get inventoryStatusRepairing;
  String get inventoryStatusCompleted;
  String get inventoryStatusDelivered;
  String get inventoryStatusUnknown;
  String inventorySearchProduct(String product);
  String get inventoryExportParts;
  String get inventoryExportProducts;
  String inventorySearchHint(String product, String category, String field);
  String inventoryHideProductTitle(String product);
  String get inventorySearchTooltip;
  String get inventoryExportExcelMenu;
  String inventoryCapitalChip(String price);
  String inventoryEditProductTitle(String label);
  String inventoryProductNameLabel(String label);
  String get inventoryConfirmBtn;
  String get inventoryCostPriceRequired;
  String get inventorySalePriceOptional;
  String get inventorySupplierRequired;
  String get inventoryPaymentLabel;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'vi': return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
