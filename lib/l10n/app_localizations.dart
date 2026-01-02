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
  /// **'Repair Shop Management'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
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
  /// **'Change Language'**
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
  /// **'Forgot Password?'**
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
  /// **'INVENTORY'**
  String get inventory;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'SUPPLIERS'**
  String get suppliers;

  /// No description provided for @parts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get parts;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'SALES'**
  String get sales;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMERS'**
  String get customers;

  /// No description provided for @debts.
  ///
  /// In en, this message translates to:
  /// **'DEBTS'**
  String get debts;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
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
  /// **'Invalid email or password'**
  String get loginError;

  /// No description provided for @shopManagement.
  ///
  /// In en, this message translates to:
  /// **'SHOP MANAGEMENT'**
  String get shopManagement;

  /// No description provided for @storeIcon.
  ///
  /// In en, this message translates to:
  /// **'Store Icon'**
  String get storeIcon;

  /// No description provided for @manageStaff.
  ///
  /// In en, this message translates to:
  /// **'Manage Staff'**
  String get manageStaff;

  /// No description provided for @createInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Create Invite Code'**
  String get createInviteCode;

  /// No description provided for @shareQR.
  ///
  /// In en, this message translates to:
  /// **'Share QR Code'**
  String get shareQR;

  /// No description provided for @staffList.
  ///
  /// In en, this message translates to:
  /// **'Staff List'**
  String get staffList;

  /// No description provided for @addEditDeleteStaff.
  ///
  /// In en, this message translates to:
  /// **'Add/Edit/Delete Staff, Create Invite Code'**
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
  /// **'REVENUE'**
  String get revenue;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'EXPENSES'**
  String get expenses;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'DASHBOARD'**
  String get dashboard;

  /// No description provided for @repair.
  ///
  /// In en, this message translates to:
  /// **'REPAIR'**
  String get repair;

  /// No description provided for @warranty.
  ///
  /// In en, this message translates to:
  /// **'WARRANTY'**
  String get warranty;

  /// No description provided for @printer.
  ///
  /// In en, this message translates to:
  /// **'PRINTER'**
  String get printer;

  /// No description provided for @auditLog.
  ///
  /// In en, this message translates to:
  /// **'AUDIT LOG'**
  String get auditLog;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
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

  /// No description provided for @debt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get debt;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @checkInventory.
  ///
  /// In en, this message translates to:
  /// **'Check Inventory'**
  String get checkInventory;

  /// No description provided for @manageInventory.
  ///
  /// In en, this message translates to:
  /// **'Manage Inventory'**
  String get manageInventory;

  /// No description provided for @viewPrintLabels.
  ///
  /// In en, this message translates to:
  /// **'View & Print Labels'**
  String get viewPrintLabels;

  /// No description provided for @accountInfo.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT INFORMATION'**
  String get accountInfo;

  /// No description provided for @viewPermissions.
  ///
  /// In en, this message translates to:
  /// **'View Permissions & Account Info'**
  String get viewPermissions;

  /// No description provided for @syncData.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get syncData;

  /// No description provided for @syncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Data sync completed'**
  String get syncCompleted;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get syncError;

  /// No description provided for @accountInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT INFO'**
  String get accountInfoTitle;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @viewInventory.
  ///
  /// In en, this message translates to:
  /// **'View Inventory'**
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
  /// **'CLOSE'**
  String get close;

  /// No description provided for @otherPermissions.
  ///
  /// In en, this message translates to:
  /// **'Other permissions'**
  String get otherPermissions;

  /// No description provided for @viewSales.
  ///
  /// In en, this message translates to:
  /// **'View Sales'**
  String get viewSales;

  /// No description provided for @viewRepairs.
  ///
  /// In en, this message translates to:
  /// **'View Repairs'**
  String get viewRepairs;

  /// No description provided for @viewPrinter.
  ///
  /// In en, this message translates to:
  /// **'View Printer'**
  String get viewPrinter;

  /// No description provided for @viewRevenue.
  ///
  /// In en, this message translates to:
  /// **'View Revenue'**
  String get viewRevenue;

  /// No description provided for @viewExpenses.
  ///
  /// In en, this message translates to:
  /// **'View Expenses'**
  String get viewExpenses;

  /// No description provided for @viewDebts.
  ///
  /// In en, this message translates to:
  /// **'View Debts'**
  String get viewDebts;

  /// No description provided for @viewSettings.
  ///
  /// In en, this message translates to:
  /// **'View Settings'**
  String get viewSettings;

  /// No description provided for @shopLocked.
  ///
  /// In en, this message translates to:
  /// **'Shop Locked'**
  String get shopLocked;

  /// No description provided for @shopLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'The shop has been temporarily locked by Super Admin. All functions are limited until unlocked.'**
  String get shopLockedMessage;

  /// No description provided for @searchCustomerByPhone.
  ///
  /// In en, this message translates to:
  /// **'Search customer by phone'**
  String get searchCustomerByPhone;

  /// No description provided for @arrowForward.
  ///
  /// In en, this message translates to:
  /// **'Arrow Forward'**
  String get arrowForward;

  /// No description provided for @perpetualCalendar.
  ///
  /// In en, this message translates to:
  /// **'Perpetual Calendar'**
  String get perpetualCalendar;

  /// No description provided for @quickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick Stats'**
  String get quickStats;

  /// No description provided for @pendingRepairs.
  ///
  /// In en, this message translates to:
  /// **'Pending Repairs'**
  String get pendingRepairs;

  /// No description provided for @completedToday.
  ///
  /// In en, this message translates to:
  /// **'Completed Today'**
  String get completedToday;

  /// No description provided for @soldToday.
  ///
  /// In en, this message translates to:
  /// **'Sold Today'**
  String get soldToday;

  /// No description provided for @todaySummary.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S WORK'**
  String get todaySummary;

  /// No description provided for @newRepairsToday.
  ///
  /// In en, this message translates to:
  /// **'New repairs today'**
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
  /// **'Grid Menu'**
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

  /// No description provided for @revenueReport.
  ///
  /// In en, this message translates to:
  /// **'REVENUE REPORT'**
  String get revenueReport;

  /// No description provided for @profitLoss.
  ///
  /// In en, this message translates to:
  /// **'PROFIT & LOSS'**
  String get profitLoss;

  /// No description provided for @netProfit.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get netProfit;

  /// No description provided for @inventorySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Inventory Snapshot'**
  String get inventorySnapshot;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total items'**
  String get totalItems;

  /// No description provided for @inventoryValue.
  ///
  /// In en, this message translates to:
  /// **'Inventory value'**
  String get inventoryValue;

  /// No description provided for @noItemsInStock.
  ///
  /// In en, this message translates to:
  /// **'No items in stock'**
  String get noItemsInStock;

  /// No description provided for @closingCard.
  ///
  /// In en, this message translates to:
  /// **'CLOSING CARD'**
  String get closingCard;

  /// No description provided for @cashStart.
  ///
  /// In en, this message translates to:
  /// **'Cash Start'**
  String get cashStart;

  /// No description provided for @bankStart.
  ///
  /// In en, this message translates to:
  /// **'Bank Start'**
  String get bankStart;

  /// No description provided for @cashEnd.
  ///
  /// In en, this message translates to:
  /// **'Cash End'**
  String get cashEnd;

  /// No description provided for @bankEnd.
  ///
  /// In en, this message translates to:
  /// **'Bank End'**
  String get bankEnd;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @saveClosing.
  ///
  /// In en, this message translates to:
  /// **'Save Closing'**
  String get saveClosing;

  /// No description provided for @revenueDistribution.
  ///
  /// In en, this message translates to:
  /// **'REVENUE DISTRIBUTION'**
  String get revenueDistribution;

  /// No description provided for @salesProfit.
  ///
  /// In en, this message translates to:
  /// **'Sales Profit'**
  String get salesProfit;

  /// No description provided for @repairProfit.
  ///
  /// In en, this message translates to:
  /// **'Repair Profit'**
  String get repairProfit;

  /// No description provided for @totalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses'**
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
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @quickActionButton.
  ///
  /// In en, this message translates to:
  /// **'Quick Action Button'**
  String get quickActionButton;

  /// No description provided for @reportCard.
  ///
  /// In en, this message translates to:
  /// **'Report Card'**
  String get reportCard;

  /// No description provided for @summaryRow.
  ///
  /// In en, this message translates to:
  /// **'Summary Row'**
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
  /// **'BRAND INFORMATION'**
  String get brandInfoSection;

  /// No description provided for @shopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Name (UPPERCASE)'**
  String get shopNameLabel;

  /// No description provided for @shopPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone Number'**
  String get shopPhoneLabel;

  /// No description provided for @shopAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Address'**
  String get shopAddressLabel;

  /// No description provided for @invoiceConfigSection.
  ///
  /// In en, this message translates to:
  /// **'INVOICE CONFIGURATION'**
  String get invoiceConfigSection;

  /// No description provided for @invoiceFooterLabel.
  ///
  /// In en, this message translates to:
  /// **'Footer Message'**
  String get invoiceFooterLabel;

  /// No description provided for @createInvoiceTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice Template'**
  String get createInvoiceTemplate;

  /// No description provided for @joinShopCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Invite Code to Join Shop'**
  String get joinShopCode;

  /// No description provided for @cleanupManagement.
  ///
  /// In en, this message translates to:
  /// **'Cleanup Management: Delete Old Repair Records (Optional)'**
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
  /// **'Phone Repair Shop Management'**
  String get appDescription;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @versionNumber.
  ///
  /// In en, this message translates to:
  /// **'2.1.0'**
  String get versionNumber;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
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
  /// **'Mobile App Development Expert'**
  String get developerRole;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone/Zalo: 0964 095 979'**
  String get contactPhone;

  /// No description provided for @technicalSupport.
  ///
  /// In en, this message translates to:
  /// **'Technical Support & App Development'**
  String get technicalSupport;

  /// No description provided for @businessSolutions.
  ///
  /// In en, this message translates to:
  /// **'Business Management Solutions Development'**
  String get businessSolutions;

  /// No description provided for @saveAllSettings.
  ///
  /// In en, this message translates to:
  /// **'SAVE ALL SETTINGS'**
  String get saveAllSettings;

  /// No description provided for @enterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Invite Code'**
  String get enterInviteCode;

  /// No description provided for @inviteCode8Chars.
  ///
  /// In en, this message translates to:
  /// **'Invite Code (8 characters)'**
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
  /// **'Successfully joined shop!'**
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
  /// **'Cleanup Configuration (opt-in)'**
  String get cleanupConfigOptIn;

  /// No description provided for @enableCleanup.
  ///
  /// In en, this message translates to:
  /// **'Enable cleanup'**
  String get enableCleanup;

  /// No description provided for @daysToDeleteAfter.
  ///
  /// In en, this message translates to:
  /// **'Number of days (delete after N days)'**
  String get daysToDeleteAfter;

  /// No description provided for @noPermissionToConfigure.
  ///
  /// In en, this message translates to:
  /// **'Account does not have permission to configure'**
  String get noPermissionToConfigure;

  /// No description provided for @shopInfoSaved.
  ///
  /// In en, this message translates to:
  /// **'SHOP INFORMATION SAVED!'**
  String get shopInfoSaved;

  /// No description provided for @cleanupConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Cleanup configuration saved'**
  String get cleanupConfigSaved;

  /// No description provided for @scanQRCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQRCode;

  /// No description provided for @createRepairOrder.
  ///
  /// In en, this message translates to:
  /// **'CREATE REPAIR ORDER'**
  String get createRepairOrder;

  /// No description provided for @noPermissionRepair.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to access REPAIR section. Contact shop owner to grant permission.'**
  String get noPermissionRepair;

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// No description provided for @notAllowed.
  ///
  /// In en, this message translates to:
  /// **'Not Allowed'**
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
  /// **'This account does not have permission to view REVENUE screen. Contact shop owner to grant permission.'**
  String get noPermissionRevenue;

  /// No description provided for @noPermissionRevenueReport.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to view REVENUE REPORT screen. Contact shop owner to grant permission.'**
  String get noPermissionRevenueReport;

  /// No description provided for @noPermissionSales.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to access SALES section. Contact shop owner to grant permission.'**
  String get noPermissionSales;

  /// No description provided for @noPermissionInventory.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to access INVENTORY section. Contact shop owner to grant permission.'**
  String get noPermissionInventory;

  /// No description provided for @noPermissionCustomers.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to view CUSTOMER SYSTEM. Contact shop owner to grant permission.'**
  String get noPermissionCustomers;

  /// No description provided for @noPermissionWarranty.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to access WARRANTY section. Contact shop owner to grant permission.'**
  String get noPermissionWarranty;

  /// No description provided for @noPermissionChat.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to use internal CHAT. Contact shop owner to grant permission.'**
  String get noPermissionChat;

  /// No description provided for @noPermissionPrinter.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to configure PRINTER. Contact shop owner to grant permission.'**
  String get noPermissionPrinter;

  /// No description provided for @noPermissionCreateRepair.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to create repair receipt. Contact shop owner to grant permission.'**
  String get noPermissionCreateRepair;

  /// No description provided for @viewInventoryPermission.
  ///
  /// In en, this message translates to:
  /// **'View inventory permission'**
  String get viewInventoryPermission;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEE'**
  String get employee;

  /// No description provided for @inventoryCheck.
  ///
  /// In en, this message translates to:
  /// **'INVENTORY CHECK'**
  String get inventoryCheck;

  /// No description provided for @checkInventoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Check phone and accessory stock'**
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
  /// **'Create repair receipt'**
  String get createRepairReceiptDesc;

  /// No description provided for @thermalPrinter.
  ///
  /// In en, this message translates to:
  /// **'THERMAL PRINTER'**
  String get thermalPrinter;

  /// No description provided for @printLabelsDesc.
  ///
  /// In en, this message translates to:
  /// **'Print device information labels'**
  String get printLabelsDesc;

  /// No description provided for @quickMenu.
  ///
  /// In en, this message translates to:
  /// **'Quick Menu'**
  String get quickMenu;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER NAME'**
  String get customerName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'PHONE NUMBER'**
  String get phoneNumber;

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

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'DEVICE MODEL'**
  String get deviceModel;

  /// No description provided for @deviceIssue.
  ///
  /// In en, this message translates to:
  /// **'DEVICE ISSUE'**
  String get deviceIssue;

  /// No description provided for @appearanceCondition.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE CONDITION'**
  String get appearanceCondition;

  /// No description provided for @appearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Example: SCRATCHED, BROKEN, BENT...'**
  String get appearanceHint;

  /// No description provided for @accessoriesIncluded.
  ///
  /// In en, this message translates to:
  /// **'ACCESSORIES INCLUDED'**
  String get accessoriesIncluded;

  /// No description provided for @accessoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Example: CHARGER, EARPHONES...'**
  String get accessoriesHint;

  /// No description provided for @screenPassword.
  ///
  /// In en, this message translates to:
  /// **'SCREEN PASSWORD'**
  String get screenPassword;

  /// No description provided for @estimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'ESTIMATED PRICE'**
  String get estimatedPrice;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHOD'**
  String get paymentMethod;

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

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'CREDIT'**
  String get credit;

  /// No description provided for @installment.
  ///
  /// In en, this message translates to:
  /// **'INSTALLMENT (NH)'**
  String get installment;

  /// No description provided for @t86.
  ///
  /// In en, this message translates to:
  /// **'T86'**
  String get t86;

  /// No description provided for @bankT86.
  ///
  /// In en, this message translates to:
  /// **'T86 BANK'**
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
  /// **'RECEIVED DEVICE'**
  String get receivedDevice;

  /// No description provided for @addProductToInventory.
  ///
  /// In en, this message translates to:
  /// **'ADD PRODUCT TO INVENTORY'**
  String get addProductToInventory;

  /// No description provided for @productType.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT TYPE'**
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
  /// **'PRODUCT NAME'**
  String get productName;

  /// No description provided for @imeiNumber.
  ///
  /// In en, this message translates to:
  /// **'IMEI NUMBER (IF ANY)'**
  String get imeiNumber;

  /// No description provided for @costPrice.
  ///
  /// In en, this message translates to:
  /// **'COST PRICE'**
  String get costPrice;

<<<<<<< HEAD
=======
  /// No description provided for @kpkPrice.
  ///
  /// In en, this message translates to:
  /// **'KPK PRICE'**
  String get kpkPrice;

  /// No description provided for @pkPrice.
  ///
  /// In en, this message translates to:
  /// **'PK PRICE'**
  String get pkPrice;

>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'CAPACITY (e.g. 64GB, 128GB)'**
  String get capacity;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'QUANTITY'**
  String get quantity;

  /// No description provided for @supplierRequired.
  ///
  /// In en, this message translates to:
  /// **'SUPPLIER (REQUIRED)'**
  String get supplierRequired;

  /// No description provided for @addSupplierQuick.
  ///
  /// In en, this message translates to:
  /// **'ADD SUPPLIER QUICK'**
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
  String confirmDeleteSelectedProducts(Object count);

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
  /// **'Only ADMIN accounts can delete products from inventory'**
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

  /// No description provided for @repairs.
  ///
  /// In en, this message translates to:
  /// **'REPAIRS'**
  String get repairs;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'STAFF'**
  String get staff;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

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
  /// **'Save Repair Order'**
  String get saveRepairOrder;

  /// No description provided for @noPermissionSuppliers.
  ///
  /// In en, this message translates to:
  /// **'This account is not allowed to view SUPPLIERS. Contact shop owner to grant permission.'**
  String get noPermissionSuppliers;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(Object count);

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
  /// **'SUP'**
  String get supplierShort;

  /// No description provided for @imei.
  ///
  /// In en, this message translates to:
  /// **'IMEI'**
  String get imei;

  /// No description provided for @quantityShort.
  ///
  /// In en, this message translates to:
  /// **'QTY'**
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

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @saveOrderError.
  ///
  /// In en, this message translates to:
  /// **'Error saving order: {error}'**
  String saveOrderError(Object error);

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
  String confirmDeleteProduct(Object name);

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
  String confirmDeleteMultipleProducts(Object count);

  /// No description provided for @multipleProductsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} PRODUCTS DELETED'**
  String multipleProductsDeleted(Object count);

  /// No description provided for @imeiOptional.
  ///
  /// In en, this message translates to:
  /// **'IMEI (Optional)'**
  String get imeiOptional;

  /// No description provided for @capacityExample.
  ///
  /// In en, this message translates to:
  /// **'Capacity (e.g. 64GB, 128GB)'**
  String get capacityExample;

  /// No description provided for @addSupplierQuickly.
  ///
  /// In en, this message translates to:
  /// **'Add supplier quickly'**
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

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

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
  String labelPrintError(Object error);

  /// No description provided for @cashClosingSaved.
  ///
  /// In en, this message translates to:
  /// **'CASH CLOSING SAVED'**
  String get cashClosingSaved;

  /// No description provided for @netProfitAfterExpenses.
  ///
  /// In en, this message translates to:
  /// **'NET PROFIT AFTER EXPENSES'**
  String get netProfitAfterExpenses;

  /// No description provided for @timePeriod.
  ///
  /// In en, this message translates to:
  /// **'Time Period'**
  String get timePeriod;

  /// No description provided for @todayCashFlow.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S CASH FLOW'**
  String get todayCashFlow;

  /// No description provided for @saveCashClosing.
  ///
  /// In en, this message translates to:
  /// **'Save Cash Closing'**
  String get saveCashClosing;
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
